import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/value_types.dart';
import '../l10n/locale_preference.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/localized_message.dart';
import '../cloud/cloud_account.dart';
import '../cloud/cloud_models.dart';
import '../cloud/provider_record.dart';
import '../cloud/cloud_import.dart';
import '../connections/snippet.dart';
import '../servers/server_record.dart';
import '../servers/server_resources.dart';
import '../finance/finance_models.dart';
import '../finance/finance_math.dart';
import '../security/security_models.dart';
import '../settings/reminder_rule.dart';

part 'ledger_settings.dart';
part 'ledger_backup.dart';
part 'ledger_providers.dart';

class LedgerConflict implements Exception, LocalizedMessage {
  const LedgerConflict();
  @override
  String toString() => messageFor(defaultLocalizations);
  @override
  String messageFor(AppLocalizations l10n) => l10n.recordChanged;
}

// Historical user-input constraint, never a translated group/state identity.
const legacyReservedGroupName = '未分组';
// Legacy persisted placeholder, also required by the unchanged backup v1 label contract.
const legacyUnknownVendor = '服务商待填写';

class ArchiveUndo {
  const ArchiveUndo(this.id, this.revision);
  final String id;
  final int revision;
}

/// SQLite is the source of truth. All public mutations commit before returning.
/// No delete/recreate or destructive downgrade fallback is permitted.
class LedgerStore {
  LedgerStore._(this._db, this.clock);
  final Database _db;
  final DateTime Function() clock;
  static const schemaVersion = 11;
  // Shared by both credential controllers using this store. A durable journal
  // reservation is not an orphan while its native write/DB commit is active.
  final Set<String> _activeSecretReservations = {};

  static Future<LedgerStore> open({
    required DatabaseFactory factory,
    required String path,
    DateTime Function()? clock,
  }) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => createSchema(db),
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 1 ||
              oldVersion > schemaVersion ||
              newVersion != schemaVersion) {
            throw StateError('Unsupported ledger migration');
          }
          if (oldVersion < 2) {
            await _addFinanceSchema(db);
          }
          if (oldVersion < 3) {
            await _addSecuritySchema(db);
          }
          if (oldVersion < 4) {
            await _addSnippetSchema(db);
          }
          if (oldVersion < 5) {
            await _addCloudSchema(db);
          }
          if (oldVersion < 6) {
            await _addSettingsSchema(db);
          }
          if (oldVersion < 7) {
            await _addResourcesSchema(db);
          }
          // v8 permits partial local resources and a traffic period in JSON.
          // Existing v7 rows are already valid and must not be rewritten; the
          // version fence prevents older readers from accepting the new shape.
          if (oldVersion < 9) {
            await _addLanguageSchema(db);
          }
          if (oldVersion < 11) {
            await _migrateCloudProviderSchema(db);
          }
        },
        onDowngrade: (db, oldVersion, newVersion) async {
          throw StateError('Newer ledger version; upgrade the app');
        },
      ),
    );
    return LedgerStore._(db, clock ?? DateTime.now);
  }

  /// Add explicit, transactional migrations only when a real schema changes.
  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE server_groups (
      id TEXT PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE UNIQUE,
      position INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE servers (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, vendor TEXT NOT NULL,
      host TEXT NOT NULL DEFAULT '', region TEXT NOT NULL DEFAULT '',
      purpose TEXT NOT NULL DEFAULT '', os TEXT NOT NULL DEFAULT '',
      spec TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '',
      group_id TEXT REFERENCES server_groups(id) ON DELETE SET NULL,
      favorite INTEGER NOT NULL DEFAULT 0 CHECK(favorite IN (0,1)),
      billing TEXT NOT NULL CHECK(billing IN ('unknown','prepaid','metered')),
      currency TEXT NOT NULL CHECK(currency IN ('USD','CNY','EUR')),
      amount_minor INTEGER CHECK(amount_minor >= 0), cycle_months INTEGER NOT NULL,
      start_date TEXT, due_date TEXT, archived_at TEXT,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      revision INTEGER NOT NULL DEFAULT 0,
      is_demo INTEGER NOT NULL DEFAULT 0 CHECK(is_demo IN (0,1)))''');
    await db.execute('CREATE INDEX servers_group ON servers(group_id)');
    await db.execute('CREATE INDEX servers_archive ON servers(archived_at)');
    await _addFinanceSchema(db);
    await _addSecuritySchema(db);
    await _addSnippetSchema(db);
    await _addCloudSchema(db);
    await _addSettingsSchema(db);
    await _addResourcesSchema(db);
    await _addLanguageSchema(db);
    await _addProviderSchema(db);
  }

  /// Nullable by design: old/manual records are not populated with fabricated
  /// resource values, and this migration touches no finance or SSH fields.
  static Future<void> _addResourcesSchema(DatabaseExecutor db) =>
      db.execute('ALTER TABLE servers ADD COLUMN resources_json TEXT');

  Future<List<ServerRecord>> servers() async =>
      (await _db.query('servers'))
          .map(ServerRecord.fromMap)
          .toList(growable: false);
  Future<List<ServerGroup>> groups() async => (await _db.query(
    'server_groups',
    orderBy: 'position, name',
  )).map(ServerGroup.fromMap).toList(growable: false);

  Future<void> saveServer(ServerRecord record, {required bool isNew}) async {
    final error = record.validate();
    if (error != null) {
      throw LocalizedArgumentError((l10n) => record.validate(l10n: l10n)!);
    }
    await _db.transaction((txn) async {
      final map = record.toMap();
      if (record.groupId != null &&
          (await txn.query(
            'server_groups',
            where: 'id = ?',
            whereArgs: [record.groupId],
          )).isEmpty) {
        throw const LedgerConflict();
      }
      ServerRecord? previous;
      if (!isNew) {
        final rows = await txn.query(
          'servers',
          where: 'id = ?',
          whereArgs: [record.id],
        );
        if (rows.isEmpty) {
          throw const LedgerConflict();
        }
        previous = ServerRecord.fromMap(rows.single);
        if (previous.archived || previous.revision != record.revision) {
          throw const LedgerConflict();
        }
      }
      if (record.providerId != null) {
        await _providerRow(
          txn,
          record.providerId!,
          confirmed: previous?.providerId != record.providerId,
        );
      }
      if (previous != null &&
          previous.providerId != record.providerId &&
          (await txn.query(
            'cloud_bindings',
            where: 'server_id = ?',
            whereArgs: [record.id],
          )).isNotEmpty) {
        throw CloudAccountFailure(
          LocalizedText((l10n) => l10n.providerChangeNeedsUnlink),
        );
      }
      final termsChanged =
          previous == null ||
          previous.billing != record.billing ||
          previous.startDate != record.startDate ||
          previous.dueDate != record.dueDate ||
          previous.cycleMonths != record.cycleMonths;
      if (previous != null &&
          termsChanged &&
          (await txn.query(
            'service_periods',
            where: 'server_id = ? AND payment_id IS NOT NULL',
            whereArgs: [record.id],
            limit: 1,
          )).isNotEmpty) {
        throw LocalizedArgumentError((l10n) => l10n.paymentPeriodsLockFields);
      }
      map['renewal_anchor_date'] = termsChanged
          ? (record.billing == BillingKind.prepaid
                ? record.dueDate?.toString()
                : null)
          : previous.renewalAnchorDate?.toString();
      map['updated_at'] = clock().toUtc().toIso8601String();
      if (isNew) {
        map['revision'] = 0;
        await txn.insert('servers', map);
      } else {
        map.remove('id');
        map.remove('created_at');
        map.remove('is_demo');
        map.remove('archived_at');
        map['revision'] = record.revision + 1;
        final count = await txn.update(
          'servers',
          map,
          where: 'id = ? AND revision = ? AND archived_at IS NULL',
          whereArgs: [record.id, record.revision],
        );
        if (count != 1) {
          throw const LedgerConflict();
        }
      }
      if (termsChanged) {
        await _replaceInitialPeriod(txn, record);
      }
    });
  }

  Future<void> setFavorite(ServerRecord record, bool favorite) async {
    final count = await _db.update(
      'servers',
      {
        'favorite': favorite ? 1 : 0,
        'revision': record.revision + 1,
        'updated_at': clock().toUtc().toIso8601String(),
      },
      where: 'id = ? AND revision = ? AND archived_at IS NULL',
      whereArgs: [record.id, record.revision],
    );
    if (count != 1) {
      throw const LedgerConflict();
    }
  }

  Future<ArchiveUndo> archive(ServerRecord record) async {
    final now = clock().toUtc().toIso8601String();
    final count = await _db.update(
      'servers',
      {'archived_at': now, 'updated_at': now, 'revision': record.revision + 1},
      where: 'id = ? AND revision = ? AND archived_at IS NULL',
      whereArgs: [record.id, record.revision],
    );
    if (count != 1) {
      throw const LedgerConflict();
    }
    return ArchiveUndo(record.id, record.revision + 1);
  }

  Future<void> undoArchive(ArchiveUndo undo) async {
    final count = await _db.update(
      'servers',
      {
        'archived_at': null,
        'updated_at': clock().toUtc().toIso8601String(),
        'revision': undo.revision + 1,
      },
      where: 'id = ? AND revision = ? AND archived_at IS NOT NULL',
      whereArgs: [undo.id, undo.revision],
    );
    if (count != 1) {
      throw const LedgerConflict();
    }
  }

  Future<void> saveGroup(String name, {String? id}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty ||
        trimmed.length > 40 ||
        trimmed == legacyReservedGroupName) {
      throw LocalizedArgumentError((l10n) => l10n.invalidGroupName);
    }
    await _db.transaction((txn) async {
      if (id == null) {
        final rows = await txn.rawQuery(
          'SELECT COALESCE(MAX(position), -1) + 1 AS next FROM server_groups',
        );
        await txn.insert('server_groups', {
          'id': newLocalId(),
          'name': trimmed,
          'position': rows.first['next'],
        });
      } else {
        final count = await txn.update(
          'server_groups',
          {'name': trimmed},
          where: 'id = ?',
          whereArgs: [id],
        );
        if (count != 1) {
          throw const LedgerConflict();
        }
      }
    });
  }

  Future<void> deleteGroup(String id) async {
    await _db.transaction((txn) async {
      // Preserve server IDs and every other field, including archived records.
      await txn.rawUpdate(
        'UPDATE servers SET group_id = NULL, revision = CASE WHEN archived_at IS NULL THEN revision + 1 ELSE revision END, updated_at = ? WHERE group_id = ?',
        [clock().toUtc().toIso8601String(), id],
      );
      await txn.delete('server_groups', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> moveGroup(String id, int delta) async {
    await _db.transaction((txn) async {
      final rows = await txn.query('server_groups', orderBy: 'position, name');
      final index = rows.indexWhere((g) => g['id'] == id);
      final target = index + delta;
      if (index < 0 || target < 0 || target >= rows.length) {
        return;
      }
      final ordered = [...rows];
      final item = ordered.removeAt(index);
      ordered.insert(target, item);
      for (var i = 0; i < ordered.length; i++) {
        await txn.update(
          'server_groups',
          {'position': i},
          where: 'id = ?',
          whereArgs: [ordered[i]['id']],
        );
      }
    });
  }

  Future<void> loadDemo() async {
    await _db.transaction((txn) async {
      if ((await txn.query('servers', limit: 1)).isNotEmpty) {
        throw LocalizedStateError((l10n) => l10n.demoRequiresEmptyLedger);
      }
      final existing = await txn.query(
        'server_groups',
        where: 'name = ?',
        whereArgs: ['演示'],
      );
      final groupId = existing.isEmpty
          ? newLocalId()
          : existing.first['id'] as String;
      if (existing.isEmpty) {
        final rows = await txn.rawQuery(
          'SELECT COALESCE(MAX(position), -1) + 1 AS next FROM server_groups',
        );
        await txn.insert('server_groups', {
          'id': groupId,
          'name': '演示',
          'position': rows.first['next'],
        });
      }
      final now = clock();
      final today = LedgerDate.today(now);
      final fixtures = [
        (
          'HK-01',
          '搬瓦工',
          '香港',
          '192.0.2.18',
          '生产主站',
          BillingKind.prepaid,
          4999,
          7,
          true,
        ),
        (
          'US-01',
          'DigitalOcean',
          '美国',
          '198.51.100.10',
          'API 服务',
          BillingKind.metered,
          1200,
          0,
          true,
        ),
        (
          'JP-01',
          'GreenCloud',
          '日本',
          '203.0.113.22',
          '开发环境',
          BillingKind.prepaid,
          4500,
          -2,
          false,
        ),
        (
          'SG-01',
          '自定义厂商',
          '新加坡',
          'example.invalid',
          '备用',
          BillingKind.unknown,
          0,
          0,
          false,
        ),
      ];
      for (final f in fixtures) {
        final record = ServerRecord(
          id: newLocalId(),
          name: f.$1,
          vendor: f.$2,
          region: f.$3,
          host: f.$4,
          purpose: f.$5,
          billing: f.$6,
          amountMinor: f.$6 == BillingKind.unknown ? null : f.$7,
          dueDate: f.$6 == BillingKind.prepaid ? today.addDays(f.$8) : null,
          startDate: f.$6 == BillingKind.prepaid
              ? today.addDays(f.$8).addMonths(-12)
              : null,
          favorite: f.$9,
          groupId: groupId,
          os: 'Debian 12',
          spec: '2 vCPU · 2 GB · 40 GB',
          notes: '仅演示：地址使用文档保留地址，不连接真实服务器。',
          createdAt: now,
          updatedAt: now,
          isDemo: true,
        );
        await txn.insert('servers', {
          ...record.toMap(),
          'renewal_anchor_date': record.dueDate?.toString(),
        });
        await _replaceInitialPeriod(txn, record);
      }
    });
  }

  static Future<void> _addFinanceSchema(DatabaseExecutor db) async {
    await db.execute('ALTER TABLE servers ADD COLUMN renewal_anchor_date TEXT');
    await db.execute(
      '''CREATE TABLE payments (
      id TEXT PRIMARY KEY,
      server_id TEXT REFERENCES servers(id), target_name TEXT NOT NULL,
      account_label TEXT, amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0),
      currency TEXT NOT NULL CHECK(currency IN ('USD','CNY','EUR')),
      paid_date TEXT NOT NULL, from_date TEXT, until_date TEXT,
      cycle_count INTEGER NOT NULL, note TEXT NOT NULL,
      previous_due TEXT, applied_server_revision INTEGER,
      created_at TEXT NOT NULL, voided_at TEXT, request_fingerprint TEXT NOT NULL,
      CHECK((server_id IS NULL AND account_label IS NOT NULL AND cycle_count=0)
        OR (server_id IS NOT NULL AND account_label IS NULL AND cycle_count BETWEEN 1 AND 3)))''',
    );
    await db.execute(
      '''CREATE UNIQUE INDEX payments_active_until
      ON payments(server_id,until_date) WHERE server_id IS NOT NULL AND voided_at IS NULL''',
    );
    await db.execute('''CREATE TABLE service_periods (
      id TEXT PRIMARY KEY, server_id TEXT NOT NULL REFERENCES servers(id),
      start_date TEXT NOT NULL, end_date TEXT NOT NULL CHECK(end_date > start_date),
      inferred INTEGER NOT NULL CHECK(inferred IN (0,1)),
      payment_id TEXT REFERENCES payments(id))''');
    await db.execute(
      'CREATE INDEX service_periods_server ON service_periods(server_id,start_date)',
    );
    await db.execute('''CREATE TABLE finance_settings (
      id INTEGER PRIMARY KEY CHECK(id=1), display_currency TEXT NOT NULL,
      usd_to_cny TEXT, eur_to_cny TEXT, rate_date TEXT)''');
    await db.insert('finance_settings', const FxSettings().toMap());
    final records = (await db.query('servers')).map(ServerRecord.fromMap);
    for (final record in records) {
      if (record.billing == BillingKind.prepaid && record.dueDate != null) {
        await db.update(
          'servers',
          {'renewal_anchor_date': record.dueDate.toString()},
          where: 'id = ?',
          whereArgs: [record.id],
        );
      }
      await _replaceInitialPeriod(db, record);
    }
  }

  static Future<void> _replaceInitialPeriod(
    DatabaseExecutor db,
    ServerRecord record,
  ) async {
    await db.delete(
      'service_periods',
      where: 'server_id = ? AND payment_id IS NULL',
      whereArgs: [record.id],
    );
    final due = record.dueDate;
    if (record.billing != BillingKind.prepaid ||
        due == null ||
        !due.isValid ||
        !validCycle(record.cycleMonths)) {
      return;
    }
    final knownStart = record.startDate;
    final hasStart =
        knownStart != null &&
        knownStart.isValid &&
        knownStart.compareTo(due) < 0;
    final start = hasStart ? knownStart : due.addMonths(-record.cycleMonths);
    if (!start.isValid || start.compareTo(due) >= 0) {
      return;
    }
    await db.insert(
      'service_periods',
      ServicePeriod(
        id: 'initial-${record.id}',
        serverId: record.id,
        start: start,
        end: due,
        inferred: !hasStart,
      ).toMap(),
    );
  }

  Future<List<ServicePeriod>> servicePeriods() async => (await _db.query(
    'service_periods',
    orderBy: 'start_date, end_date, id',
  )).map(ServicePeriod.fromMap).toList(growable: false);
  Future<List<PaymentRecord>> payments() async => (await _db.query(
    'payments',
    orderBy: 'paid_date DESC, created_at DESC, id',
  )).map(PaymentRecord.fromMap).toList(growable: false);
  Future<FxSettings> fxSettings() async => FxSettings.fromMap(
    (await _db.query('finance_settings', where: 'id = 1')).single,
  );
  Future<void> saveFx(FxSettings settings) async {
    final error = settings.validate();
    if (error != null) {
      throw LocalizedArgumentError((l10n) => settings.validate(l10n: l10n)!);
    }
    if (settings.rateDate != null &&
        settings.rateDate!.compareTo(LedgerDate.today(clock())) > 0) {
      throw LocalizedArgumentError((l10n) => l10n.futureRateDate);
    }
    await _db.update('finance_settings', settings.toMap(), where: 'id = 1');
  }

  void _validatePayment(
    String id,
    Money amount,
    LedgerDate paidDate,
    String note,
  ) {
    if (id.isEmpty || id.length > 128) {
      throw LocalizedArgumentError((l10n) => l10n.invalidPaymentId);
    }
    if (!Money.currencies.contains(amount.currency) ||
        amount.minor < 0 ||
        amount.minor > Money.maxMinor) {
      throw LocalizedArgumentError((l10n) => l10n.invalidPaidAmount);
    }
    if (!paidDate.isValid ||
        paidDate.compareTo(LedgerDate.today(clock())) > 0) {
      throw LocalizedArgumentError((l10n) => l10n.futurePaymentDate);
    }
    if (note.length > 4000) {
      throw LocalizedArgumentError((l10n) => l10n.notesTooLong);
    }
  }

  Future<PaymentRecord?> _existingPayment(
    Transaction txn,
    String id,
    String fingerprint,
  ) async {
    final rows = await txn.query('payments', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) {
      return null;
    }
    final existing = PaymentRecord.fromMap(rows.single);
    if (existing.voided) {
      throw LocalizedArgumentError((l10n) => l10n.paymentAlreadyVoided);
    }
    if (existing.requestFingerprint != fingerprint) {
      throw LocalizedArgumentError((l10n) => l10n.paymentIdContentMismatch);
    }
    return existing;
  }

  Future<PaymentRecord> recordPayment({
    required String id,
    required ServerRecord server,
    required Money amount,
    required LedgerDate paidDate,
    required int cycleCount,
    required LedgerDate until,
    required bool confirmed,
    String note = '',
  }) async {
    if (!confirmed) {
      throw LocalizedArgumentError((l10n) => l10n.confirmProviderPayment);
    }
    final fingerprint = jsonEncode([
      'server',
      server.id,
      amount.currency,
      amount.minor,
      paidDate.toString(),
      cycleCount,
      until.toString(),
      note,
    ]);
    return _db.transaction((txn) async {
      final existing = await _existingPayment(txn, id, fingerprint);
      if (existing != null) {
        return existing;
      }
      _validatePayment(id, amount, paidDate, note);
      if (!const [1, 2, 3].contains(cycleCount) || !until.isValid) {
        throw LocalizedArgumentError((l10n) => l10n.invalidRenewalCycleCount);
      }
      final rows = await txn.query(
        'servers',
        where: 'id = ?',
        whereArgs: [server.id],
      );
      if (rows.isEmpty) {
        throw const LedgerConflict();
      }
      final current = ServerRecord.fromMap(rows.single);
      if (current.archived || current.revision != server.revision) {
        throw const LedgerConflict();
      }
      if (current.billing != BillingKind.prepaid || current.dueDate == null) {
        throw LocalizedArgumentError((l10n) => l10n.renewalNeedsPrepaidDate);
      }
      if (renewalDate(current, cycleCount) != until) {
        throw LocalizedArgumentError((l10n) => l10n.renewalDateMismatch);
      }
      if ((await txn.query(
        'payments',
        where: 'server_id = ? AND until_date = ? AND voided_at IS NULL',
        whereArgs: [current.id, until.toString()],
      )).isNotEmpty) {
        throw LocalizedArgumentError((l10n) => l10n.duplicateExpiryPayment);
      }
      final now = clock().toUtc();
      final payment = PaymentRecord(
        id: id,
        serverId: current.id,
        targetName: current.name,
        amount: amount,
        paidDate: paidDate,
        from: current.dueDate,
        until: until,
        cycleCount: cycleCount,
        note: note,
        previousDue: current.dueDate,
        appliedServerRevision: current.revision + 1,
        createdAt: now,
        requestFingerprint: fingerprint,
      );
      await txn.insert('payments', payment.toMap());
      for (var i = 0; i < cycleCount; i++) {
        await txn.insert(
          'service_periods',
          ServicePeriod(
            id: '$id-$i',
            serverId: current.id,
            start: renewalDate(current, i),
            end: renewalDate(current, i + 1),
            paymentId: id,
          ).toMap(),
        );
      }
      final count = await txn.update(
        'servers',
        {
          'due_date': until.toString(),
          'revision': current.revision + 1,
          'renewal_anchor_date': (current.renewalAnchorDate ?? current.dueDate)
              .toString(),
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ? AND revision = ? AND archived_at IS NULL',
        whereArgs: [current.id, current.revision],
      );
      if (count != 1) {
        throw const LedgerConflict();
      }
      return payment;
    });
  }

  Future<PaymentRecord> recordAccountPayment({
    required String id,
    required String accountLabel,
    required Money amount,
    required LedgerDate paidDate,
    LedgerDate? from,
    LedgerDate? until,
    String note = '',
  }) async {
    final label = accountLabel.trim();
    final fingerprint = jsonEncode([
      'account',
      label,
      amount.currency,
      amount.minor,
      paidDate.toString(),
      from?.toString(),
      until?.toString(),
      note,
    ]);
    return _db.transaction((txn) async {
      final existing = await _existingPayment(txn, id, fingerprint);
      if (existing != null) {
        return existing;
      }
      _validatePayment(id, amount, paidDate, note);
      if (label.isEmpty || label.length > 80) {
        throw LocalizedArgumentError((l10n) => l10n.invalidAccountName);
      }
      if ((from == null) != (until == null) ||
          (from != null &&
              (!from.isValid ||
                  !until!.isValid ||
                  from.compareTo(until) >= 0))) {
        throw LocalizedArgumentError(
          (l10n) => l10n.invalidOptionalBillingPeriod,
        );
      }
      final payment = PaymentRecord(
        id: id,
        targetName: label,
        accountLabel: label,
        amount: amount,
        paidDate: paidDate,
        from: from,
        until: until,
        note: note,
        createdAt: clock().toUtc(),
        requestFingerprint: fingerprint,
      );
      await txn.insert('payments', payment.toMap());
      return payment;
    });
  }

  Future<void> undoPayment(String id) async {
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'payments',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) {
        throw const LedgerConflict();
      }
      final payment = PaymentRecord.fromMap(rows.single);
      if (payment.voided) {
        return;
      }
      await _voidPayment(txn, payment, rollbackRenewal: !payment.isAccount);
    });
  }

  /// Marks [payment] voided (a tombstone: the row and its idempotency key stay,
  /// so neither an old undo nor a repeated request can revive it; every total
  /// already excludes voided rows).
  ///
  /// With [rollbackRenewal] the server due date and the periods this payment
  /// added are restored, guarded by the server revision it produced. Without
  /// it the periods stay linked to the (voided) payment so the term history is
  /// unchanged; the backup validator accepts that shape.
  Future<void> _voidPayment(
    Transaction txn,
    PaymentRecord payment, {
    required bool rollbackRenewal,
  }) async {
    final now = clock().toUtc().toIso8601String();
    if (rollbackRenewal && !payment.isAccount) {
      final count = await txn.update(
        'servers',
        {
          'due_date': payment.previousDue.toString(),
          'revision': payment.appliedServerRevision! + 1,
          'updated_at': now,
        },
        where:
            'id = ? AND revision = ? AND due_date = ? AND archived_at IS NULL',
        whereArgs: [
          payment.serverId,
          payment.appliedServerRevision,
          payment.until.toString(),
        ],
      );
      if (count != 1) {
        throw const LedgerConflict();
      }
      await txn.delete(
        'service_periods',
        where: 'payment_id = ?',
        whereArgs: [payment.id],
      );
    }
    await txn.update(
      'payments',
      {'voided_at': now},
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  /// Loads the stored row of [original] and requires it to be unchanged.
  /// Payments have no revision column, so the whole row is the version token.
  Future<PaymentRecord> _currentPayment(
    Transaction txn,
    PaymentRecord original,
  ) async {
    final rows = await txn.query(
      'payments',
      where: 'id = ?',
      whereArgs: [original.id],
    );
    if (rows.isEmpty) {
      throw const LedgerConflict();
    }
    final current = PaymentRecord.fromMap(rows.single);
    if (jsonEncode(current.toMap()) != jsonEncode(original.toMap())) {
      throw const LedgerConflict();
    }
    return current;
  }

  /// Edits the bookkeeping fields of a payment: amount, currency, paid date,
  /// note and (account bills) the account name. Never touches the due date,
  /// cycle count, from/until or service periods. [original] is the row the
  /// caller loaded; any change since then raises [LedgerConflict].
  Future<PaymentRecord> editPayment({
    required PaymentRecord original,
    required Money amount,
    required LedgerDate paidDate,
    String note = '',
    String? accountLabel,
  }) async {
    final label = accountLabel?.trim();
    return _db.transaction((txn) async {
      final current = await _currentPayment(txn, original);
      if (current.voided) {
        throw LocalizedArgumentError((l10n) => l10n.paymentAlreadyVoided);
      }
      _validatePayment(current.id, amount, paidDate, note);
      final values = <String, Object?>{
        'amount_minor': amount.minor,
        'currency': amount.currency,
        'paid_date': paidDate.toString(),
        'note': note,
      };
      if (current.isAccount) {
        if (label == null || label.isEmpty || label.length > 80) {
          throw LocalizedArgumentError((l10n) => l10n.invalidAccountName);
        }
        // The backup format requires target_name == account_label.
        values['account_label'] = label;
        values['target_name'] = label;
      }
      final count = await txn.update(
        'payments',
        values,
        where: 'id = ? AND voided_at IS NULL',
        whereArgs: [current.id],
      );
      if (count != 1) {
        throw const LedgerConflict();
      }
      return PaymentRecord.fromMap(
        (await txn.query(
          'payments',
          where: 'id = ?',
          whereArgs: [current.id],
        )).single,
      );
    });
  }

  /// Deletes a payment record (soft: a voided tombstone, see [_voidPayment]).
  ///
  /// [rollbackRenewal] additionally restores the server's previous due date and
  /// removes the periods this payment added; it requires the server to still
  /// be exactly as the payment left it, otherwise [LedgerConflict]. Without it
  /// the term stays as it is. Deleting an already deleted payment is a no-op.
  Future<void> deletePayment({
    required PaymentRecord original,
    bool rollbackRenewal = false,
  }) async {
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'payments',
        where: 'id = ?',
        whereArgs: [original.id],
      );
      if (rows.isEmpty) {
        throw const LedgerConflict();
      }
      if (PaymentRecord.fromMap(rows.single).voided) {
        return;
      }
      final current = await _currentPayment(txn, original);
      await _voidPayment(txn, current, rollbackRenewal: rollbackRenewal);
    });
  }

  static Future<void> _addSecuritySchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE credentials (
      id TEXT PRIMARY KEY, name TEXT NOT NULL,
      kind TEXT NOT NULL CHECK(kind IN ('password','privateKey')),
      default_username TEXT NOT NULL DEFAULT '', secret_ref TEXT NOT NULL UNIQUE,
      key_algorithm TEXT, fingerprint TEXT,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      revision INTEGER NOT NULL DEFAULT 0)''');
    await db.execute('''CREATE TABLE ssh_configurations (
      server_id TEXT PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
      host TEXT NOT NULL, port INTEGER NOT NULL CHECK(port BETWEEN 1 AND 65535),
      username TEXT NOT NULL, credential_id TEXT REFERENCES credentials(id),
      revision INTEGER NOT NULL DEFAULT 0)''');
    await db.execute(
      'CREATE INDEX ssh_credential ON ssh_configurations(credential_id)',
    );
    // Both pre-write reservations and superseded immutable references live here.
    // No secret data is ever written into this recovery journal.
    await db.execute('''CREATE TABLE secret_cleanup (
      secret_ref TEXT PRIMARY KEY, created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE host_trust (
      generation TEXT NOT NULL UNIQUE, host TEXT NOT NULL, port INTEGER NOT NULL CHECK(port BETWEEN 1 AND 65535),
      algorithm TEXT NOT NULL, public_key TEXT NOT NULL, fingerprint TEXT NOT NULL,
      verified_at TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(host, port))''');
  }

  Future<List<CredentialMetadata>> credentials() async => (await _db.query(
    'credentials',
    orderBy: 'name COLLATE NOCASE, id',
  )).map(CredentialMetadata.fromMap).toList(growable: false);

  Future<List<SshConfiguration>> sshConfigurations() async =>
      (await _db.query('ssh_configurations'))
          .map(SshConfiguration.fromMap)
          .toList(growable: false);

  Future<List<HostTrustRecord>> hostTrusts() async => (await _db.query(
    'host_trust',
    orderBy: 'host, port',
  )).map(HostTrustRecord.fromMap).toList(growable: false);

  Future<HostTrustRecord?> hostTrust(String host, int port) async {
    final rows = await _db.query(
      'host_trust',
      where: 'host = ? AND port = ?',
      whereArgs: [host, port],
    );
    return rows.isEmpty ? null : HostTrustRecord.fromMap(rows.single);
  }

  /// Must commit before native storage write. References are fresh and immutable.
  Future<void> reserveSecret(String ref, {bool active = false}) async {
    if (active && !_activeSecretReservations.add(ref)) {
      throw const LedgerConflict();
    }
    try {
      await _db.transaction((txn) async {
        if (await _secretIsReferenced(txn, ref)) {
          throw const LedgerConflict();
        }
        await txn.insert('secret_cleanup', {
          'secret_ref': ref,
          'created_at': clock().toUtc().toIso8601String(),
        });
      });
    } catch (_) {
      if (active) {
        _activeSecretReservations.remove(ref);
      }
      rethrow;
    }
  }

  void releaseSecretReservation(String ref) =>
      _activeSecretReservations.remove(ref);

  Future<List<String>> pendingSecretCleanup() async =>
      (await _db.query('secret_cleanup'))
          .map((row) => row['secret_ref'] as String)
          .where((ref) => !_activeSecretReservations.contains(ref))
          .toList(growable: false);

  Future<bool> secretIsReferenced(String ref) => _secretIsReferenced(_db, ref);

  static Future<bool> _secretIsReferenced(
    DatabaseExecutor db,
    String ref,
  ) async {
    for (final table in ['credentials', 'cloud_accounts']) {
      if ((await db.query(
        table,
        where: 'secret_ref = ?',
        whereArgs: [ref],
        limit: 1,
      )).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<void> finishSecretCleanup(String ref) async {
    await _db.delete(
      'secret_cleanup',
      where: 'secret_ref = ?',
      whereArgs: [ref],
    );
  }

  Future<void> saveCredential(
    CredentialMetadata record, {
    required int? expectedRevision,
  }) async {
    if (record.name.trim().isEmpty ||
        record.name.length > 80 ||
        record.defaultUsername.length > 128 ||
        (record.kind == CredentialKind.password &&
            record.defaultUsername.isEmpty) ||
        record.secretRef.isEmpty) {
      throw SecurityFailure(
        LocalizedText((l10n) => l10n.invalidCredentialDetails),
      );
    }
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'credentials',
        where: 'id = ?',
        whereArgs: [record.id],
      );
      final previous = rows.isEmpty
          ? null
          : CredentialMetadata.fromMap(rows.single);
      if ((expectedRevision == null && previous != null) ||
          (expectedRevision != null &&
              previous?.revision != expectedRevision)) {
        throw const LedgerConflict();
      }
      final changedRef = previous?.secretRef != record.secretRef;
      if (changedRef &&
          (await txn.query(
            'secret_cleanup',
            where: 'secret_ref = ?',
            whereArgs: [record.secretRef],
          )).isEmpty) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.secretWriteNotPrepared),
        );
      }
      final map = record.toMap();
      map['revision'] = expectedRevision == null ? 0 : expectedRevision + 1;
      map['updated_at'] = clock().toUtc().toIso8601String();
      if (previous == null) {
        await txn.insert('credentials', map);
      } else {
        map.remove('id');
        map.remove('created_at');
        final count = await txn.update(
          'credentials',
          map,
          where: 'id = ? AND revision = ?',
          whereArgs: [record.id, expectedRevision],
        );
        if (count != 1) {
          throw const LedgerConflict();
        }
      }
      if (changedRef) {
        await txn.delete(
          'secret_cleanup',
          where: 'secret_ref = ?',
          whereArgs: [record.secretRef],
        );
        if (previous != null) {
          await txn.insert('secret_cleanup', {
            'secret_ref': previous.secretRef,
            'created_at': clock().toUtc().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    });
  }

  /// Replace or detach all references in the same metadata transaction. Explicit
  /// usernames remain untouched, including those equal to an old default.
  Future<void> deleteCredential(
    CredentialMetadata record, {
    String? replacementId,
  }) async {
    if (replacementId == record.id) {
      throw SecurityFailure(
        LocalizedText((l10n) => l10n.chooseOtherCredential),
      );
    }
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'credentials',
        where: 'id = ? AND revision = ?',
        whereArgs: [record.id, record.revision],
      );
      if (rows.length != 1) {
        throw const LedgerConflict();
      }
      final current = CredentialMetadata.fromMap(rows.single);
      if (replacementId != null &&
          (await txn.query(
            'credentials',
            where: 'id = ?',
            whereArgs: [replacementId],
          )).isEmpty) {
        throw const LedgerConflict();
      }
      await txn.rawUpdate(
        '''UPDATE ssh_configurations
          SET credential_id = ?, revision = revision + 1 WHERE credential_id = ?''',
        [replacementId, record.id],
      );
      await txn.delete(
        'credentials',
        where: 'id = ? AND revision = ?',
        whereArgs: [record.id, record.revision],
      );
      await txn.insert('secret_cleanup', {
        'secret_ref': current.secretRef,
        'created_at': clock().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  Future<void> saveSshConfiguration(SshConfiguration config) async {
    if (config.host.isEmpty ||
        !ServerRecord.validHost(config.host) ||
        config.port < 1 ||
        config.port > 65535 ||
        config.username.trim().isEmpty ||
        config.username.length > 128 ||
        RegExp(r'[\x00-\x20\x7f]').hasMatch(config.username)) {
      throw SecurityFailure(
        LocalizedText((l10n) => l10n.invalidSshConfiguration),
      );
    }
    await _db.transaction((txn) async {
      if ((await txn.query(
            'servers',
            where: 'id = ?',
            whereArgs: [config.serverId],
          )).isEmpty ||
          (config.credentialId != null &&
              (await txn.query(
                'credentials',
                where: 'id = ?',
                whereArgs: [config.credentialId],
              )).isEmpty)) {
        throw const LedgerConflict();
      }
      final map = config.toMap();
      map['revision'] = config.revision + 1;
      if (config.revision < 0) {
        if ((await txn.query(
          'ssh_configurations',
          where: 'server_id = ?',
          whereArgs: [config.serverId],
        )).isNotEmpty) {
          throw const LedgerConflict();
        }
        await txn.insert('ssh_configurations', map);
      } else {
        map.remove('server_id');
        final count = await txn.update(
          'ssh_configurations',
          map,
          where: 'server_id = ? AND revision = ?',
          whereArgs: [config.serverId, config.revision],
        );
        if (count != 1) {
          throw const LedgerConflict();
        }
      }
    });
  }

  Future<void> saveHostTrust(
    HostTrustRecord record, {
    required HostTrustRecord? expected,
    bool Function()? isCancelled,
  }) async {
    await _db.transaction((txn) async {
      if (isCancelled?.call() ?? false) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.verificationCancelled),
        );
      }
      final rows = await txn.query(
        'host_trust',
        where: 'host = ? AND port = ?',
        whereArgs: [record.host, record.port],
      );
      final previous = rows.isEmpty
          ? null
          : HostTrustRecord.fromMap(rows.single);
      if ((expected == null && previous != null) ||
          (expected != null &&
              (previous == null || !_sameTrustSnapshot(previous, expected)))) {
        throw const LedgerConflict();
      }
      if (isCancelled?.call() ?? false) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.verificationCancelled),
        );
      }
      final map = record.toMap();
      map['generation'] = previous?.generation ?? newLocalId();
      map['revision'] = previous == null ? 0 : previous.revision + 1;
      if (previous == null) {
        await txn.insert('host_trust', map);
      } else {
        await txn.update(
          'host_trust',
          map,
          where: 'host = ? AND port = ?',
          whereArgs: [record.host, record.port],
        );
      }
      if (isCancelled?.call() ?? false) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.verificationCancelled),
        );
      }
    });
  }

  static bool _sameTrustSnapshot(HostTrustRecord a, HostTrustRecord b) =>
      a.host == b.host &&
      a.port == b.port &&
      a.generation == b.generation &&
      a.revision == b.revision &&
      a.algorithm == b.algorithm &&
      a.publicKey == b.publicKey &&
      a.fingerprint == b.fingerprint &&
      a.verifiedAt == b.verifiedAt;

  Future<void> deleteHostTrust(HostTrustRecord record) async {
    final count = await _db.delete(
      'host_trust',
      where:
          'host = ? AND port = ? AND revision = ? AND generation = ? '
          'AND algorithm = ? AND public_key = ? AND fingerprint = ? AND verified_at = ?',
      whereArgs: [
        record.host,
        record.port,
        record.revision,
        record.generation,
        record.algorithm,
        record.publicKey,
        record.fingerprint,
        record.verifiedAt.toUtc().toIso8601String(),
      ],
    );
    if (count != 1) {
      throw const LedgerConflict();
    }
  }

  static Future<void> _addSnippetSchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE snippets (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, content TEXT NOT NULL,
      revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0))''');
  }

  Future<List<CommandSnippet>> snippets() async => (await _db.query(
    'snippets',
    orderBy: 'name COLLATE NOCASE, id',
  )).map(CommandSnippet.fromMap).toList(growable: false);

  /// Returns the committed value without a fallible post-commit read. Content
  /// is stored byte-for-byte as supplied, including CR, whitespace and controls.
  Future<CommandSnippet> saveSnippet(
    CommandSnippet snippet, {
    required bool isNew,
  }) async {
    final error = snippet.validate();
    if (error != null) {
      throw LocalizedArgumentError((l10n) => snippet.validate(l10n: l10n)!);
    }
    final saved = CommandSnippet(
      id: snippet.id,
      name: snippet.name.trim(),
      content: snippet.content,
      revision: isNew ? 0 : snippet.revision + 1,
    );
    await _db.transaction((txn) async {
      if (isNew) {
        if ((await txn.query(
          'snippets',
          where: 'id = ?',
          whereArgs: [saved.id],
        )).isNotEmpty) {
          throw const LedgerConflict();
        }
        await txn.insert('snippets', saved.toMap());
      } else {
        final map = saved.toMap()..remove('id');
        final changed = await txn.update(
          'snippets',
          map,
          where: 'id = ? AND revision = ?',
          whereArgs: [saved.id, snippet.revision],
        );
        if (changed != 1) {
          throw const LedgerConflict();
        }
      }
    });
    return saved;
  }

  Future<void> deleteSnippet(CommandSnippet snippet) async {
    final changed = await _db.delete(
      'snippets',
      where: 'id = ? AND revision = ?',
      whereArgs: [snippet.id, snippet.revision],
    );
    if (changed != 1) {
      throw const LedgerConflict();
    }
  }

  static Future<void> _addCloudSchema(
    DatabaseExecutor db, {
    String suffix = '',
    bool withRelationships = false,
  }) async {
    final relationships = withRelationships
        ? '''business_provider_id TEXT REFERENCES providers(id),
      auth_scope TEXT NOT NULL DEFAULT 'unknown'
        CHECK(auth_scope IN ('unknown','singleDevice','account')),
      pinned_server_id TEXT,'''
        : '';
    await db.execute(
      '''CREATE TABLE cloud_accounts$suffix (
      id TEXT PRIMARY KEY, provider TEXT NOT NULL CHECK(provider IN ('solusVm1','solusVm2','rackNerd')),
      alias TEXT NOT NULL, endpoint TEXT NOT NULL, secret_ref TEXT NOT NULL UNIQUE,
      remote_account_id INTEGER, revision INTEGER NOT NULL DEFAULT 0,
      generation INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL,
      last_attempt_at TEXT, last_failure TEXT,
      $relationships
      CHECK((provider IN ('solusVm1','rackNerd') AND remote_account_id IS NULL) OR
            (provider = 'solusVm2' AND remote_account_id IS NOT NULL AND remote_account_id > 0)))''',
    );
    await db.execute('''CREATE TABLE cloud_observations$suffix (
      account_id TEXT NOT NULL REFERENCES cloud_accounts$suffix(id) ON DELETE CASCADE,
      instance_key TEXT NOT NULL, identity_uuid TEXT, observation TEXT NOT NULL,
      stale INTEGER NOT NULL DEFAULT 0 CHECK(stale IN (0,1)),
      missing INTEGER NOT NULL DEFAULT 0 CHECK(missing IN (0,1)),
      PRIMARY KEY(account_id, instance_key))''');
    await db.execute(
      '''CREATE TABLE cloud_bindings$suffix (
      server_id TEXT PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
      account_id TEXT NOT NULL, instance_key TEXT NOT NULL,
      UNIQUE(account_id, instance_key),
      FOREIGN KEY(account_id, instance_key)
        REFERENCES cloud_observations$suffix(account_id, instance_key) ON DELETE CASCADE)''',
    );
  }

  static Future<void> _migrateCloudProviderSchema(DatabaseExecutor db) async {
    // Two v10 shapes exist: RackNerd CHECKs without relationships, and
    // Provider relationships without RackNerd CHECKs. Detect columns, not just
    // user_version. onUpgrade supplies the transaction; foreign keys stay on.
    const suffix = '_v11';
    const relationshipColumns = {
      'business_provider_id',
      'auth_scope',
      'pinned_server_id',
    };
    const baseColumns = {
      'cloud_accounts': {
        'id',
        'provider',
        'alias',
        'endpoint',
        'secret_ref',
        'remote_account_id',
        'revision',
        'generation',
        'created_at',
        'last_attempt_at',
        'last_failure',
      },
      'cloud_observations': {
        'account_id',
        'instance_key',
        'identity_uuid',
        'observation',
        'stale',
        'missing',
      },
      'cloud_bindings': {'server_id', 'account_id', 'instance_key'},
    };
    final columns = <String, Set<String>>{};
    for (final table in baseColumns.keys) {
      columns[table] = (await db.rawQuery('PRAGMA table_info($table)'))
          .map((row) => row['name'] as String)
          .toSet();
    }
    final accountColumns = columns['cloud_accounts']!;
    final providersExist = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='providers'",
    )).isNotEmpty;
    final serverColumns = (await db.rawQuery('PRAGMA table_info(servers)'))
        .map((row) => row['name'] as String)
        .toSet();
    final withRelationships =
        providersExist &&
        serverColumns.contains('provider_id') &&
        accountColumns.containsAll(relationshipColumns);
    if (!withRelationships &&
        (providersExist ||
            serverColumns.contains('provider_id') ||
            accountColumns.intersection(relationshipColumns).isNotEmpty)) {
      throw StateError('Incomplete ledger provider schema');
    }
    // Refuse unknown columns instead of silently discarding a schema extension.
    for (final table in baseColumns.entries) {
      final expected = {
        ...table.value,
        if (table.key == 'cloud_accounts' && withRelationships)
          ...relationshipColumns,
      };
      if (columns[table.key]!.length != expected.length ||
          !columns[table.key]!.containsAll(expected)) {
        throw StateError('Unsupported ledger cloud schema');
      }
    }
    final extraObjects = await db.rawQuery(
      '''SELECT name, sql FROM sqlite_master
      WHERE tbl_name IN ('cloud_accounts','cloud_observations','cloud_bindings')
        AND type IN ('index','trigger') AND sql IS NOT NULL
        ORDER BY type, name''',
    );
    // Provider guards reference the old cloud graph (including a trigger on
    // servers). Remove them before dropping tables and recreate after renaming.
    if (withRelationships) await _removeProviderGuards(db);
    await _addCloudSchema(
      db,
      suffix: suffix,
      withRelationships: withRelationships,
    );
    for (final table in columns.entries) {
      final fields = table.value.join(', ');
      await db.execute(
        'INSERT INTO ${table.key}$suffix ($fields) '
        'SELECT $fields FROM ${table.key}',
      );
    }
    // Copy the whole FK graph first. Rebuilding only the account table would
    // cascade-delete observations and bindings, including historical UUIDs.
    for (final table in columns.keys.toList().reversed) {
      await db.execute('DROP TABLE $table');
    }
    for (final table in columns.keys) {
      await db.execute('ALTER TABLE $table$suffix RENAME TO $table');
    }
    for (final object in extraObjects) {
      final sql = object['sql'] as String;
      // The known authority guards are deliberately replaced with Rack-aware
      // definitions. Preserve any other cloud index/trigger byte-for-byte.
      if (!_providerGuardNames.contains(object['name'])) {
        await db.execute(sql);
      }
    }
    if (withRelationships) {
      await _addProviderGuards(db);
    } else {
      await _addProviderSchema(db);
    }
    if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
      throw StateError('Invalid ledger migration references');
    }
  }

  Future<List<CloudAccount>> cloudAccounts() async => (await _db.query(
    'cloud_accounts',
    orderBy: 'alias COLLATE NOCASE, id',
  )).map(CloudAccount.fromMap).toList(growable: false);

  /// Non-secret historical identity metadata, including observations which
  /// have never been linked to a local server. A later omitted UUID must not
  /// erase an earlier verified identity during preview.
  Future<Map<String, Map<String, String>>> cloudIdentityUuids() async {
    final result = <String, Map<String, String>>{};
    for (final row in await _db.query(
      'cloud_observations',
      columns: ['account_id', 'instance_key', 'identity_uuid'],
      where: 'identity_uuid IS NOT NULL',
    )) {
      (result[row['account_id'] as String] ??= {})[row['instance_key']
              as String] =
          row['identity_uuid'] as String;
    }
    return Map.unmodifiable({
      for (final entry in result.entries)
        entry.key: Map<String, String>.unmodifiable(entry.value),
    });
  }

  Future<List<CloudBinding>> cloudBindings() async => (await _db.rawQuery('''
    SELECT b.server_id, o.* FROM cloud_bindings b JOIN cloud_observations o
      ON b.account_id = o.account_id AND b.instance_key = o.instance_key
  ''')).map(CloudBinding.fromMap).toList(growable: false);

  Future<ServerCloudBindingOptions> serverCloudBindingOptions(
    String serverId,
  ) => _db.transaction((txn) async {
    final rows = await txn.query(
      'servers',
      where: 'id = ?',
      whereArgs: [serverId],
    );
    if (rows.length != 1) {
      throw const LedgerConflict();
    }
    return ServerCloudBindingOptions(
      server: ServerRecord.fromMap(rows.single),
      accounts: (await txn.query(
        'cloud_accounts',
        orderBy: 'alias COLLATE NOCASE, id',
      )).map(CloudAccount.fromMap).toList(),
      choices: (await txn.rawQuery('''
        SELECT o.*, b.server_id FROM cloud_observations o
        LEFT JOIN cloud_bindings b ON b.account_id = o.account_id
          AND b.instance_key = o.instance_key
        ORDER BY o.account_id, o.instance_key
      ''')).map(CloudBindingChoice.fromMap).toList(),
    );
  });

  /// Changes only the association. Every check and the replacement happen in
  /// one transaction; a conflict/cancellation cannot first remove the old link.
  Future<void> setServerCloudBinding(
    ServerCloudBindingOptions expected, {
    CloudBindingChoice? choice,
    bool Function()? isCancelled,
  }) => _db.transaction((txn) async {
    _checkCloudCancellation(isCancelled);
    final servers = await txn.query(
      'servers',
      where: 'id = ?',
      whereArgs: [expected.server.id],
    );
    if (servers.length != 1) {
      throw const LedgerConflict();
    }
    final server = ServerRecord.fromMap(servers.single);
    if (server.revision != expected.server.revision ||
        server.archived ||
        server.isDemo) {
      throw const LedgerConflict();
    }
    final accounts = await txn.query('cloud_accounts');
    if (accounts.length != expected.accounts.length) {
      throw const LedgerConflict();
    }
    for (final account in expected.accounts) {
      await _currentCloud(txn, account);
    }
    final oldRows = await txn.query(
      'cloud_bindings',
      where: 'server_id = ?',
      whereArgs: [server.id],
    );
    final old = oldRows.firstOrNull;
    final original = expected.current;
    if (old?['account_id'] != original?.accountId ||
        old?['instance_key'] != original?.instanceKey) {
      throw const LedgerConflict();
    }
    if (choice != null) {
      if (!expected.choices.any(
        (c) =>
            c.accountId == choice.accountId &&
            c.instanceKey == choice.instanceKey,
      )) {
        throw CloudAccountFailure.selection;
      }
      final account = accounts
          .where((a) => a['id'] == choice.accountId)
          .firstOrNull;
      if (account != null) {
        await _validateAdapterLink(txn, CloudAccount.fromMap(account), server);
      }
      final observations = await txn.query(
        'cloud_observations',
        where: 'account_id = ? AND instance_key = ?',
        whereArgs: [choice.accountId, choice.instanceKey],
      );
      if (account == null ||
          account['last_failure'] != null ||
          observations.length != 1 ||
          observations.single['stale'] != 0 ||
          observations.single['missing'] != 0) {
        throw CloudAccountFailure.bindingUnavailable;
      }
      final duplicates = await _existingCloudDevices(
        txn,
        CloudAccount.fromMap(account),
        choice.instanceKey,
        uuid: observations.single['identity_uuid'] as String?,
      );
      if (duplicates.any((id) => id != server.id)) {
        throw CloudAccountFailure.bindingTaken;
      }
      final claimed = await txn.query(
        'cloud_bindings',
        where: 'account_id = ? AND instance_key = ?',
        whereArgs: [choice.accountId, choice.instanceKey],
      );
      if (claimed.isNotEmpty && claimed.single['server_id'] != server.id) {
        throw CloudAccountFailure.bindingTaken;
      }
    }
    _checkCloudCancellation(isCancelled);
    if (original?.accountId == choice?.accountId &&
        original?.instanceKey == choice?.instanceKey) {
      return;
    }
    await txn.delete(
      'cloud_bindings',
      where: 'server_id = ?',
      whereArgs: [server.id],
    );
    if (choice != null) {
      await txn.insert('cloud_bindings', {
        'server_id': server.id,
        'account_id': choice.accountId,
        'instance_key': choice.instanceKey,
      });
    }
    // Fence every open local selection, including adding a temporary account,
    // binding/unbinding through it and then deleting it. Updating only that
    // temporary account would lose the fence when its row was removed.
    await txn.rawUpdate(
      'UPDATE cloud_accounts SET generation = generation + 1',
    );
    _checkCloudCancellation(isCancelled);
  });

  static Future<CloudAccount> _currentCloud(
    DatabaseExecutor txn,
    CloudAccount expected, {
    bool checkGeneration = true,
  }) async {
    final rows = await txn.query(
      'cloud_accounts',
      where: 'id = ?',
      whereArgs: [expected.id],
    );
    if (rows.length != 1) {
      throw const LedgerConflict();
    }
    final current = CloudAccount.fromMap(rows.single);
    if (current.revision != expected.revision ||
        (checkGeneration && current.generation != expected.generation) ||
        current.secretRef != expected.secretRef ||
        current.provider != expected.provider ||
        current.endpoint != expected.endpoint ||
        current.businessProviderId != expected.businessProviderId ||
        current.authScope != expected.authScope ||
        current.remoteAccountId != expected.remoteAccountId) {
      throw const LedgerConflict();
    }
    return current;
  }

  static void _checkCloudCancellation(bool Function()? isCancelled) {
    if (isCancelled?.call() ?? false) {
      throw const CloudFailure(CloudFailureKind.cancelled);
    }
  }

  /// Claims a monotonically newer read. Refresh does not modify user metadata
  /// revisions, so another read can supersede this one without an ABA window.
  Future<CloudAccount> beginCloudRead(
    CloudAccount expected, {
    bool Function()? isCancelled,
  }) => _db.transaction((txn) async {
    _checkCloudCancellation(isCancelled);
    final current = await _currentCloud(txn, expected, checkGeneration: false);
    final map = current.toMap()..['generation'] = current.generation + 1;
    await txn.update(
      'cloud_accounts',
      {'generation': current.generation + 1},
      where: 'id = ?',
      whereArgs: [current.id],
    );
    _checkCloudCancellation(isCancelled);
    return CloudAccount.fromMap(map);
  });

  static void _validateCloudSnapshot(
    CloudAccount account,
    CloudSnapshot snapshot,
  ) {
    if (account.authScope != adapterScope(account.provider)) {
      throw CloudAccountFailure(
        LocalizedText((l10n) => l10n.adapterScopeUnavailable),
      );
    }
    if (snapshot.provider != account.provider ||
        snapshot.remoteAccountId != account.remoteAccountId) {
      throw CloudAccountFailure.identity;
    }
    if (snapshot.provider.isSingleInstance && snapshot.instances.length != 1) {
      throw const CloudFailure(CloudFailureKind.invalidResponse);
    }
    if (snapshot.provider == CloudProvider.solusVm2 &&
        (snapshot.remoteAccountId ?? 0) <= 0) {
      throw const CloudFailure(CloudFailureKind.invalidResponse);
    }
    final keys = <String>{};
    for (final i in snapshot.instances) {
      if (!keys.add(cloudInstanceKey(snapshot, i))) {
        throw const CloudFailure(CloudFailureKind.invalidResponse);
      }
    }
  }

  Future<void> _applyCloudSnapshot(
    DatabaseExecutor txn,
    CloudAccount account,
    CloudSnapshot snapshot,
  ) async {
    _validateCloudSnapshot(account, snapshot);
    // Missing objects retain their last observation and timestamp; absence is
    // never converted to a fresh "stopped" observation.
    await txn.update(
      'cloud_observations',
      {'stale': 1, 'missing': 1},
      where: 'account_id = ?',
      whereArgs: [account.id],
    );
    for (final instance in snapshot.instances) {
      final key = cloudInstanceKey(snapshot, instance);
      final old = await txn.query(
        'cloud_observations',
        where: 'account_id = ? AND instance_key = ?',
        whereArgs: [account.id, key],
      );
      final uuid = old.isEmpty ? null : old.single['identity_uuid'] as String?;
      if (uuid != null && instance.uuid != null && uuid != instance.uuid) {
        throw CloudAccountFailure.identity;
      }
      final map = <String, Object?>{
        'account_id': account.id,
        'instance_key': key,
        'identity_uuid': uuid ?? instance.uuid,
        'observation': encodeCloudInstance(instance),
        'stale': 0,
        'missing': 0,
      };
      if (old.isEmpty) {
        await txn.insert('cloud_observations', map);
      } else {
        // Never use REPLACE: it would cascade-delete the server binding.
        await txn.update(
          'cloud_observations',
          map,
          where: 'account_id = ? AND instance_key = ?',
          whereArgs: [account.id, key],
        );
      }
    }
    await txn.update(
      'cloud_accounts',
      {
        'last_attempt_at': snapshot.completedAt.toUtc().toIso8601String(),
        'last_failure': null,
      },
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<CloudAccount> commitCloudSnapshot(
    CloudAccount expected,
    CloudSnapshot snapshot, {
    bool Function()? isCancelled,
  }) => _db.transaction((txn) async {
    _checkCloudCancellation(isCancelled);
    final current = await _currentCloud(txn, expected);
    await _applyCloudSnapshot(txn, current, snapshot);
    _checkCloudCancellation(isCancelled);
    return CloudAccount.fromMap(
      current.toMap()
        ..['last_attempt_at'] = snapshot.completedAt.toUtc().toIso8601String()
        ..['last_failure'] = null,
    );
  });

  Future<void> recordCloudFailure(
    CloudAccount expected,
    CloudFailureKind failure,
  ) => _db.transaction((txn) async {
    await _currentCloud(txn, expected);
    await txn.update(
      'cloud_accounts',
      {
        'last_attempt_at': clock().toUtc().toIso8601String(),
        'last_failure': failure.name,
      },
      where: 'id = ?',
      whereArgs: [expected.id],
    );
    await txn.update(
      'cloud_observations',
      {'stale': 1},
      where: 'account_id = ?',
      whereArgs: [expected.id],
    );
  });

  /// New account (possibly zero imports) or verified reauthorization and imports
  /// commit together. The vault reservation must already exist, and the old
  /// reference is journaled only after metadata points to the new secret.
  Future<int> saveCloudAccount({
    required CloudAccount account,
    required CloudSnapshot snapshot,
    required CloudAccount? expected,
    ProviderRecord? expectedProvider,
    Set<String> selectedInstanceKeys = const {},
    String? v1DisplayName,
    ServerResources? v1Resources,
    bool confirmV1Rebind = false,
    bool Function()? isCancelled,
  }) => _db.transaction((txn) async {
    _checkCloudCancellation(isCancelled);
    if (account.alias.trim().isEmpty || account.alias.length > 80) {
      throw CloudAccountFailure.alias;
    }
    if (CloudEndpoint.parse(account.endpoint).toString() != account.endpoint) {
      throw const CloudFailure(CloudFailureKind.invalidEndpoint);
    }
    _validateCloudSnapshot(account, snapshot);
    final businessProvider = await _providerRow(
      txn,
      account.businessProviderId,
    );
    if (expectedProvider != null &&
        (expectedProvider.id != businessProvider.id ||
            expectedProvider.revision != businessProvider.revision)) {
      throw const LedgerConflict();
    }
    if (expected == null) {
      if ((await txn.query(
        'cloud_accounts',
        where: 'id = ?',
        whereArgs: [account.id],
      )).isNotEmpty) {
        throw const LedgerConflict();
      }
    } else {
      await _currentCloud(txn, expected);
      if (account.id != expected.id ||
          account.provider != expected.provider ||
          account.endpoint != expected.endpoint ||
          account.businessProviderId != expected.businessProviderId ||
          account.remoteAccountId != expected.remoteAccountId) {
        throw CloudAccountFailure.identity;
      }
      if (account.provider.isSingleInstance && !confirmV1Rebind) {
        throw CloudAccountFailure.v1Rebind;
      }
    }
    if (account.secretRef == expected?.secretRef ||
        await _secretIsReferenced(txn, account.secretRef) ||
        (await txn.query(
          'secret_cleanup',
          where: 'secret_ref = ?',
          whereArgs: [account.secretRef],
        )).isEmpty) {
      throw CloudAccountFailure.secret;
    }
    final map = account.toMap()
      ..['revision'] = expected == null ? 0 : expected.revision + 1
      ..['generation'] = expected == null ? 0 : expected.generation + 1;
    if (expected == null) {
      await txn.insert('cloud_accounts', map);
    } else {
      map['created_at'] = expected.createdAt.toUtc().toIso8601String();
      await txn.update(
        'cloud_accounts',
        map,
        where: 'id = ?',
        whereArgs: [account.id],
      );
      if (account.provider.isSingleInstance) {
        // Cascades only local cloud links. The old server, payments and SSH stay.
        await txn.delete(
          'cloud_observations',
          where: 'account_id = ?',
          whereArgs: [account.id],
        );
      }
      await txn.insert('secret_cleanup', {
        'secret_ref': expected.secretRef,
        'created_at': clock().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await txn.delete(
      'secret_cleanup',
      where: 'secret_ref = ?',
      whereArgs: [account.secretRef],
    );
    final saved = CloudAccount.fromMap(map);
    await _applyCloudSnapshot(txn, saved, snapshot);
    final count = await _importCloud(
      txn,
      saved,
      selectedInstanceKeys,
      v1DisplayName: v1DisplayName,
      v1Resources: v1Resources,
    );
    _checkCloudCancellation(isCancelled);
    return count;
  });

  Future<int> importCloudInstances(
    CloudInventory inventory, {
    required Set<String> selectedInstanceKeys,
    String? v1DisplayName,
    ServerResources? v1Resources,
    bool Function()? isCancelled,
  }) => _db.transaction((txn) async {
    _checkCloudCancellation(isCancelled);
    final current = await _currentCloud(txn, inventory.account);
    if (current.lastFailure != null) {
      throw CloudAccountFailure.selection;
    }
    final count = await _importCloud(
      txn,
      current,
      selectedInstanceKeys,
      v1DisplayName: v1DisplayName,
      v1Resources: v1Resources,
    );
    _checkCloudCancellation(isCancelled);
    return count;
  });

  Future<int> _importCloud(
    DatabaseExecutor txn,
    CloudAccount account,
    Set<String> selected, {
    String? v1DisplayName,
    ServerResources? v1Resources,
  }) async {
    var count = 0;
    for (final key in selected) {
      final result = await _importCloudRecord(
        txn,
        account,
        key,
        displayName: v1DisplayName,
        completed: v1Resources,
      );
      if (result.imported) count++;
    }
    return count;
  }

  /// Each item is its own transaction. A failed row cannot leave an unbound
  /// local server or a half-written reminder; successful prior rows remain.
  Future<CloudImportItemResult> importCloudDraft(
    CloudInventory inventory,
    CloudImportDraft draft, {
    bool Function()? isCancelled,
  }) => _db.transaction((txn) async {
    _checkCloudCancellation(isCancelled);
    final current = await _currentCloud(txn, inventory.account);
    if (current.lastFailure != null ||
        !inventory.snapshot.instances.any(
          (instance) => inventory.keyFor(instance) == draft.instanceKey,
        )) {
      throw CloudAccountFailure.selection;
    }
    final result = await _importCloudRecord(
      txn,
      current,
      draft.instanceKey,
      displayName: draft.displayName,
      completed: draft.resources,
    );
    _checkCloudCancellation(isCancelled);
    return result;
  });

  Future<CloudImportItemResult> _importCloudRecord(
    DatabaseExecutor txn,
    CloudAccount account,
    String key, {
    String? displayName,
    ServerResources? completed,
  }) async {
    final businessProvider = await _providerRow(
      txn,
      account.businessProviderId,
    );
    if (account.authScope != adapterScope(account.provider)) {
      throw CloudAccountFailure(
        LocalizedText((l10n) => l10n.adapterScopeUnavailable),
      );
    }
    if (displayName != null &&
        (displayName.trim().isEmpty || displayName.length > 80)) {
      throw CloudImportDraftFailure(
        LocalizedText((l10n) => l10n.invalidServerName),
      );
    }
    final rows = await txn.query(
      'cloud_observations',
      where:
          'account_id = ? AND instance_key = ? AND stale = 0 AND missing = 0',
      whereArgs: [account.id, key],
    );
    if (rows.length != 1) throw CloudAccountFailure.selection;
    final existing = await _existingCloudDevices(
      txn,
      account,
      key,
      uuid: rows.single['identity_uuid'] as String?,
    );
    if (existing.isNotEmpty) {
      return CloudImportItemResult(
        instanceKey: key,
        imported: false,
        serverIds: existing,
      );
    }
    final observation = decodeCloudInstance(
      rows.single['observation'] as String,
    );
    final resources = completed ?? resourcesFromCloud(observation);
    if (resources.validate(requireComplete: true) != null) {
      throw CloudImportDraftFailure(
        LocalizedText(
          (l10n) => resources.validate(requireComplete: true, l10n: l10n)!,
        ),
      );
    }
    final reviewed = verifiedResourceSources(resources, observation);
    final now = clock().toUtc();
    final suggested = account.provider.isSingleInstance
        ? account.alias
        : (observation.name?.trim().isNotEmpty ?? false)
        ? observation.name!
        : 'VPS ${observation.serverId}';
    final server = ServerRecord(
      id: newLocalId(),
      name: _cloudImportName(displayName?.trim() ?? suggested),
      vendor: businessProvider.name,
      providerId: businessProvider.id,
      host: reviewed.ip,
      resources: reviewed,
      spec: reviewed.specSummary,
      createdAt: now,
      updatedAt: now,
    );
    if (server.validate() != null) throw CloudAccountFailure.selection;
    await _validateAdapterLink(txn, account, server);
    await txn.insert('servers', server.toMap());
    await txn.insert('cloud_bindings', {
      'server_id': server.id,
      'account_id': account.id,
      'instance_key': key,
    });
    return CloudImportItemResult(
      instanceKey: key,
      imported: true,
      serverIds: [server.id],
    );
  }

  static Future<List<String>> _existingCloudDevices(
    DatabaseExecutor txn,
    CloudAccount account,
    String key, {
    String? uuid,
  }) async {
    final rows = await txn.rawQuery(
      '''SELECT b.server_id, o.identity_uuid
      FROM cloud_bindings b JOIN cloud_accounts a ON a.id = b.account_id
      JOIN cloud_observations o ON o.account_id = b.account_id AND o.instance_key = b.instance_key
      WHERE b.instance_key = ? AND (a.id = ? OR
        (? = 'solusVm2' AND a.provider = 'solusVm2' AND a.endpoint = ? AND a.remote_account_id = ?))
      ORDER BY b.server_id''',
      [
        key,
        account.id,
        account.provider.name,
        account.endpoint,
        account.remoteAccountId,
      ],
    );
    if (uuid != null &&
        rows.any(
          (row) => row['identity_uuid'] != null && row['identity_uuid'] != uuid,
        )) {
      throw CloudAccountFailure.identity;
    }
    return rows.map((row) => row['server_id'] as String).toSet().toList();
  }

  static Future<void> _validateAdapterLink(
    DatabaseExecutor txn,
    CloudAccount account,
    ServerRecord server,
  ) async {
    await _providerRow(txn, account.businessProviderId);
    if (server.providerId != account.businessProviderId) {
      throw CloudAccountFailure(
        LocalizedText((l10n) => l10n.adapterProviderMismatch),
      );
    }
    if (account.authScope != adapterScope(account.provider)) {
      throw CloudAccountFailure(
        LocalizedText((l10n) => l10n.adapterScopeUnavailable),
      );
    }
    if (account.authScope == AdapterAuthScope.singleDevice &&
        account.pinnedServerId != null &&
        account.pinnedServerId != server.id) {
      throw CloudAccountFailure(
        LocalizedText((l10n) => l10n.adapterSingletonPinned),
      );
    }
  }

  static String _cloudImportName(String value) {
    final name = value.trim();
    if (name.length <= 80) {
      return name;
    }
    // ServerRecord bounds UTF-16 units. Keep surrogate pairs intact.
    final unit = name.codeUnitAt(79);
    return name.substring(0, unit >= 0xd800 && unit <= 0xdbff ? 79 : 80);
  }

  Future<void> renameCloudAccount(CloudAccount expected, String alias) =>
      _db.transaction((txn) async {
        final clean = alias.trim();
        if (clean.isEmpty || clean.length > 80) {
          throw CloudAccountFailure.alias;
        }
        final current = await _currentCloud(
          txn,
          expected,
          checkGeneration: false,
        );
        await txn.update(
          'cloud_accounts',
          {
            'alias': clean,
            'revision': current.revision + 1,
            'generation': current.generation + 1,
          },
          where: 'id = ?',
          whereArgs: [current.id],
        );
      });

  Future<void> unbindCloudAccount(CloudAccount expected) => _db.transaction((
    txn,
  ) async {
    final current = await _currentCloud(txn, expected, checkGeneration: false);
    await txn.delete(
      'cloud_accounts',
      where: 'id = ?',
      whereArgs: [current.id],
    );
    await txn.insert('secret_cleanup', {
      'secret_ref': current.secretRef,
      'created_at': clock().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  });

  Future<void> close() => _db.close();
}
