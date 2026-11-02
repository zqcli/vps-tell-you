part of 'ledger_store.dart';

extension LedgerServers on LedgerStore {
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
}
