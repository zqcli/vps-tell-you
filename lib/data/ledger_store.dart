import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/net_address.dart';
import '../core/value_types.dart';
import '../l10n/locale_preference.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/localized_message.dart';
import '../providers/provider_record.dart';
import '../connections/snippet.dart';
import '../servers/server_record.dart';
import '../finance/finance_models.dart';
import '../finance/finance_math.dart';
import '../security/proxy_models.dart';
import '../security/security_models.dart';
import '../settings/reminder_rule.dart';

part 'ledger_settings.dart';
part 'ledger_backup.dart';
part 'ledger_providers.dart';
part 'ledger_schema.dart';

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
  static const schemaVersion = 14;
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
        onUpgrade: (db, oldVersion, newVersion) =>
            _upgradeLedgerSchema(db, oldVersion, newVersion, clock),
        onDowngrade: (db, oldVersion, newVersion) async {
          throw StateError('Newer ledger version; upgrade the app');
        },
      ),
    );
    return LedgerStore._(db, clock ?? DateTime.now);
  }

  /// Creates the current schema in an empty database.
  static Future<void> createSchema(DatabaseExecutor db) =>
      _createLedgerSchema(db);

  Future<List<ServerRecord>> servers() async =>
      (await _db.query('servers'))
          .map(ServerRecord.fromMap)
          .toList(growable: false);
  Future<List<ServerGroup>> groups() async => (await _db.query(
    'server_groups',
    orderBy: 'position, name',
  )).map(ServerGroup.fromMap).toList(growable: false);

  /// [catalogProvider] makes the server belong to that catalog provider's local
  /// provider, created in the same transaction when it does not exist yet (so
  /// cancelling the form leaves nothing behind). It overrides `providerId`.
  /// [newProvider] likewise creates a user provider (no catalog link) together
  /// with the server; the two options exclude each other.
  Future<void> saveServer(
    ServerRecord record, {
    required bool isNew,
    CatalogProviderRef? catalogProvider,
    ProviderRecord? newProvider,
  }) async {
    final error = record.validate();
    if (error != null) {
      throw LocalizedArgumentError((l10n) => record.validate(l10n: l10n)!);
    }
    await _db.transaction((txn) async {
      final map = record.toMap();
      var providerId = record.providerId;
      if (catalogProvider != null) {
        providerId = (await _ensureCatalogProvider(
          txn,
          catalogProvider,
          clock(),
        )).id;
        map['provider_id'] = providerId;
      } else if (newProvider != null) {
        providerId = (await _insertNewProvider(txn, newProvider)).id;
        map['provider_id'] = providerId;
      }
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
      if (providerId != null) {
        await _providerRow(txn, providerId);
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
          '2001:db8:0:22::1',
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
  /// With [rollbackRenewal] the term is rolled back as well (see
  /// [_rollbackTail]). Without it the periods stay linked to the (voided)
  /// payment so the term history is unchanged; the backup validator accepts
  /// that shape and [rollbackOrphanTerm] can still remove them later.
  Future<void> _voidPayment(
    Transaction txn,
    PaymentRecord payment, {
    required bool rollbackRenewal,
    int? expectedServerRevision,
  }) async {
    final now = clock().toUtc().toIso8601String();
    if (rollbackRenewal && !payment.isAccount) {
      await _rollbackTail(
        txn,
        serverId: payment.serverId!,
        expectedRevision: expectedServerRevision,
        paymentId: payment.id,
        now: now,
      );
    }
    await txn.update(
      'payments',
      {'voided_at': now},
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  /// Removes the tail of a server's term and restores the due date to the
  /// start of the removed span, in the caller's transaction.
  ///
  /// The rule is about the **term**, not the whole record: the server must be
  /// active and prepaid, its last period must end at the due date and belong to
  /// [paymentId] (for a live payment: be exactly the periods that payment
  /// created; for a deleted one: be periods still linked to the voided
  /// payment), and the run must follow the cycle from the renewal anchor. Edits
  /// unrelated to the term (name, favourite, notes, hardware …) bump the
  /// revision but never block it. [expectedRevision] is the revision the caller
  /// displayed; any difference is a [LedgerConflict], as is every failed term
  /// condition. The renewal anchor is left alone: the restored due date is the
  /// anchor plus whole cycles, so `renewalDate()` keeps working.
  Future<LedgerDate> _rollbackTail(
    Transaction txn, {
    required String serverId,
    required int? expectedRevision,
    required String paymentId,
    required String now,
  }) async {
    final rows = await txn.query(
      'servers',
      where: 'id = ?',
      whereArgs: [serverId],
    );
    if (rows.isEmpty) throw const LedgerConflict();
    final server = ServerRecord.fromMap(rows.single);
    if (expectedRevision != null && server.revision != expectedRevision) {
      throw const LedgerConflict();
    }
    final periods = (await txn.query(
      'service_periods',
      where: 'server_id = ?',
      whereArgs: [serverId],
    )).map(ServicePeriod.fromMap).toList();
    final tail = tailTerm(server, periods);
    if (tail == null || tail.paymentId != paymentId) {
      throw const LedgerConflict();
    }
    // A live payment must own exactly the tail; the periods are the proof.
    final paymentRows = await txn.query(
      'payments',
      where: 'id = ?',
      whereArgs: [paymentId],
    );
    if (paymentRows.isEmpty) throw const LedgerConflict();
    final payment = PaymentRecord.fromMap(paymentRows.single);
    if (!payment.voided &&
        (tail.periods.length != payment.cycleCount ||
            tail.start != payment.from ||
            tail.end != payment.until ||
            payment.previousDue != payment.from)) {
      throw const LedgerConflict();
    }
    final restored = tail.start;
    final count = await txn.update(
      'servers',
      {
        'due_date': restored.toString(),
        'revision': server.revision + 1,
        'updated_at': now,
      },
      where: 'id = ? AND revision = ? AND due_date = ? AND archived_at IS NULL',
      whereArgs: [serverId, server.revision, server.dueDate.toString()],
    );
    if (count != 1) throw const LedgerConflict();
    await txn.delete(
      'service_periods',
      where: 'payment_id = ? AND server_id = ?',
      whereArgs: [paymentId, serverId],
    );
    return restored;
  }

  /// Repairs a term left behind by a deleted payment: when the tail of the
  /// server's term still belongs to a voided payment (delete-record-only, or
  /// data from before rollbacks followed the term rule), removes that payment's
  /// periods and restores the due date to their start. One payment per call;
  /// call again for older ones. Never touches periods of live payments or the
  /// initial / inferred period. Returns the restored due date.
  /// [expectedRevision] is the revision the user saw; any difference, or no
  /// such tail, is a [LedgerConflict].
  Future<LedgerDate> rollbackOrphanTerm({
    required String serverId,
    required int expectedRevision,
  }) => _db.transaction((txn) async {
    final rows = await txn.query(
      'servers',
      where: 'id = ?',
      whereArgs: [serverId],
    );
    if (rows.isEmpty) throw const LedgerConflict();
    final server = ServerRecord.fromMap(rows.single);
    final periods = (await txn.query(
      'service_periods',
      where: 'server_id = ?',
      whereArgs: [serverId],
    )).map(ServicePeriod.fromMap).toList();
    final tail = tailTerm(server, periods);
    if (tail == null) throw const LedgerConflict();
    final owner = await txn.query(
      'payments',
      where: 'id = ? AND voided_at IS NOT NULL',
      whereArgs: [tail.paymentId],
    );
    if (owner.isEmpty) throw const LedgerConflict();
    return _rollbackTail(
      txn,
      serverId: serverId,
      expectedRevision: expectedRevision,
      paymentId: tail.paymentId,
      now: clock().toUtc().toIso8601String(),
    );
  });

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
  /// removes the periods this payment added. That requires the payment to be
  /// the tail of the server's term (see [_rollbackTail]); unrelated server
  /// edits do not matter. [expectedServerRevision] is the server revision shown
  /// to the user; a different revision is a [LedgerConflict]. Without
  /// [rollbackRenewal] the term stays as it is. Deleting an already deleted
  /// payment is a no-op.
  Future<void> deletePayment({
    required PaymentRecord original,
    bool rollbackRenewal = false,
    int? expectedServerRevision,
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
      await _voidPayment(
        txn,
        current,
        rollbackRenewal: rollbackRenewal,
        expectedServerRevision: expectedServerRevision,
      );
    });
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
    return (await db.query(
          'credentials',
          where: 'secret_ref = ?',
          whereArgs: [ref],
          limit: 1,
        )).isNotEmpty ||
        (await db.query(
          'proxies',
          where: 'secret_ref = ?',
          whereArgs: [ref],
          limit: 1,
        )).isNotEmpty;
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
              )).isEmpty) ||
          (config.proxyId != null &&
              (await txn.query(
                'proxies',
                where: 'id = ?',
                whereArgs: [config.proxyId],
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

  Future<List<ProxyRecord>> proxies() async => (await _db.query(
    'proxies',
    orderBy: 'name COLLATE NOCASE, id',
  )).map(ProxyRecord.fromMap).toList(growable: false);

  static bool validProxyRecord(ProxyRecord record) {
    final host = NetAddress.tryParse(record.host, allowBrackets: false);
    return record.name.trim().isNotEmpty &&
        record.name.length <= 80 &&
        host != null &&
        host.host == record.host &&
        host.zone == null &&
        record.port >= 1 &&
        record.port <= 65535 &&
        (record.username == null
            ? record.secretRef == null
            : validProxyCredential(
                    record.username!,
                    allowColon: record.kind == ProxyKind.socks5,
                  ) &&
                  record.secretRef != null);
  }

  /// Same contract as [saveCredential]: a changed [ProxyRecord.secretRef] must
  /// have been reserved first; the superseded reference is queued for cleanup
  /// in the same transaction.
  Future<void> saveProxy(
    ProxyRecord record, {
    required int? expectedRevision,
  }) async {
    if (!validProxyRecord(record)) {
      throw SecurityFailure(LocalizedText((l10n) => l10n.r13ProxyInvalid));
    }
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'proxies',
        where: 'id = ?',
        whereArgs: [record.id],
      );
      final previous = rows.isEmpty ? null : ProxyRecord.fromMap(rows.single);
      if ((expectedRevision == null && previous != null) ||
          (expectedRevision != null &&
              previous?.revision != expectedRevision)) {
        throw const LedgerConflict();
      }
      final newRef = record.secretRef;
      final changedRef = previous?.secretRef != newRef;
      if (changedRef &&
          newRef != null &&
          (await txn.query(
            'secret_cleanup',
            where: 'secret_ref = ?',
            whereArgs: [newRef],
          )).isEmpty) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.secretWriteNotPrepared),
        );
      }
      final map = record.toMap();
      map['revision'] = expectedRevision == null ? 0 : expectedRevision + 1;
      map['updated_at'] = clock().toUtc().toIso8601String();
      if (previous == null) {
        await txn.insert('proxies', map);
      } else {
        map.remove('id');
        map.remove('created_at');
        final count = await txn.update(
          'proxies',
          map,
          where: 'id = ? AND revision = ?',
          whereArgs: [record.id, expectedRevision],
        );
        if (count != 1) {
          throw const LedgerConflict();
        }
      }
      if (changedRef) {
        if (newRef != null) {
          await txn.delete(
            'secret_cleanup',
            where: 'secret_ref = ?',
            whereArgs: [newRef],
          );
        }
        final old = previous?.secretRef;
        if (old != null) {
          await txn.insert('secret_cleanup', {
            'secret_ref': old,
            'created_at': clock().toUtc().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    });
  }

  /// Refused while any SSH configuration uses the proxy. The password
  /// reference is queued for cleanup in the same transaction.
  Future<void> deleteProxy(ProxyRecord record) async {
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'proxies',
        where: 'id = ? AND revision = ?',
        whereArgs: [record.id, record.revision],
      );
      if (rows.length != 1) {
        throw const LedgerConflict();
      }
      if ((await txn.query(
        'ssh_configurations',
        where: 'proxy_id = ?',
        whereArgs: [record.id],
        limit: 1,
      )).isNotEmpty) {
        throw SecurityFailure(LocalizedText((l10n) => l10n.r13ProxyInUse));
      }
      final current = ProxyRecord.fromMap(rows.single);
      await txn.delete(
        'proxies',
        where: 'id = ? AND revision = ?',
        whereArgs: [record.id, record.revision],
      );
      final ref = current.secretRef;
      if (ref != null) {
        await txn.insert('secret_cleanup', {
          'secret_ref': ref,
          'created_at': clock().toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
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

  Future<void> close() => _db.close();
}
