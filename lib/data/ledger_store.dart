import 'package:sqflite/sqflite.dart';

import '../core/value_types.dart';
import '../servers/server_record.dart';

class LedgerConflict implements Exception {
  const LedgerConflict();
  @override
  String toString() => '记录已发生变化，请返回后重试';
}

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
  static const schemaVersion = 1;

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
          throw StateError('Unsupported ledger migration');
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
  }

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
    if (error != null) throw ArgumentError(error);
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
        if (count != 1) throw const LedgerConflict();
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
    if (count != 1) throw const LedgerConflict();
  }

  Future<ArchiveUndo> archive(ServerRecord record) async {
    final now = clock().toUtc().toIso8601String();
    final count = await _db.update(
      'servers',
      {'archived_at': now, 'updated_at': now, 'revision': record.revision + 1},
      where: 'id = ? AND revision = ? AND archived_at IS NULL',
      whereArgs: [record.id, record.revision],
    );
    if (count != 1) throw const LedgerConflict();
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
    if (count != 1) throw const LedgerConflict();
  }

  Future<void> saveGroup(String name, {String? id}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 40 || trimmed == '未分组') {
      throw ArgumentError('请输入 1–40 字的分组名，不能使用“未分组”');
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
        if (count != 1) throw const LedgerConflict();
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
      if (index < 0 || target < 0 || target >= rows.length) return;
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
        throw StateError('演示数据仅能载入空台账');
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
        await txn.insert('servers', record.toMap());
      }
    });
  }

  Future<void> close() => _db.close();
}
