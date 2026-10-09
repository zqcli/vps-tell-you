import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_account.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/data/ledger_store.dart';

import 'cloud_store_test.dart' show cloudTestTime, completedResources;
import 'rack_nerd_store_migration_test.dart'
    show createLegacyLedgerV9, legacyLedgerRows, legacyLedgerSchema;
import 'support/provider_fixture.dart' show legacyProviderProjection;

// Literal upstream eaf80db v10 additions to the real baseline v9 DDL. These
// intentionally contain the OLD SolusVM1-only guards. Never invoke production
// createSchema/_addProviderSchema to manufacture either conflicting v10 shape.
const _upstreamV10Schema = [
  '''CREATE TABLE providers (
    id TEXT PRIMARY KEY, name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 80),
    revision INTEGER NOT NULL DEFAULT 0,
    needs_review INTEGER NOT NULL DEFAULT 0 CHECK(needs_review IN (0,1)),
    created_at TEXT NOT NULL)''',
  '''CREATE UNIQUE INDEX confirmed_provider_name
    ON providers(name COLLATE NOCASE) WHERE needs_review = 0''',
  'ALTER TABLE servers ADD COLUMN provider_id TEXT REFERENCES providers(id)',
  '''ALTER TABLE cloud_accounts ADD COLUMN
    business_provider_id TEXT REFERENCES providers(id)''',
  '''ALTER TABLE cloud_accounts ADD COLUMN auth_scope TEXT
    NOT NULL DEFAULT 'unknown'
    CHECK(auth_scope IN ('unknown','singleDevice','account'))''',
  'ALTER TABLE cloud_accounts ADD COLUMN pinned_server_id TEXT',
];

List<String> get _upstreamV10Guards => [
  for (final operation in ['INSERT', 'UPDATE']) ...[
    '''CREATE TRIGGER adapter_provider_${operation.toLowerCase()}
      BEFORE $operation ON cloud_accounts BEGIN
      SELECT CASE WHEN NEW.business_provider_id IS NULL OR NOT EXISTS(
        SELECT 1 FROM providers WHERE id = NEW.business_provider_id)
        THEN RAISE(ABORT, 'adapter provider required') END;
      SELECT CASE WHEN NOT (
        NEW.auth_scope = 'unknown' OR
        (NEW.provider = 'solusVm1' AND NEW.auth_scope = 'singleDevice') OR
        (NEW.provider = 'solusVm2' AND NEW.auth_scope = 'account'
          AND NEW.remote_account_id IS NOT NULL AND NEW.remote_account_id > 0))
        THEN RAISE(ABORT, 'invalid adapter scope') END;
      SELECT CASE WHEN EXISTS(
        SELECT 1 FROM cloud_bindings b JOIN servers s ON s.id = b.server_id
        WHERE b.account_id = NEW.id AND
          (s.provider_id IS NULL OR s.provider_id != NEW.business_provider_id))
        THEN RAISE(ABORT, 'provider relationship mismatch') END;
      END''',
    '''CREATE TRIGGER binding_provider_${operation.toLowerCase()}
      BEFORE $operation ON cloud_bindings BEGIN
      SELECT CASE WHEN NOT EXISTS(
        SELECT 1 FROM cloud_accounts a JOIN servers s ON s.id = NEW.server_id
        JOIN providers p ON p.id = a.business_provider_id
        WHERE a.id = NEW.account_id AND s.provider_id = a.business_provider_id
          AND p.needs_review = 0 AND a.auth_scope != 'unknown'
          AND (a.auth_scope != 'singleDevice' OR
            (NEW.instance_key = 'single' AND
             (a.pinned_server_id IS NULL OR a.pinned_server_id = NEW.server_id))))
        THEN RAISE(ABORT, 'binding outside adapter authority') END;
      END''',
  ],
  '''CREATE TRIGGER server_provider_update BEFORE UPDATE OF provider_id ON servers
    WHEN EXISTS(SELECT 1 FROM cloud_bindings b JOIN cloud_accounts a ON a.id = b.account_id
      WHERE b.server_id = NEW.id AND
        (NEW.provider_id IS NULL OR NEW.provider_id != a.business_provider_id))
    BEGIN SELECT RAISE(ABORT, 'unlink before changing provider'); END''',
  '''CREATE TRIGGER singleton_pin_update
    BEFORE UPDATE OF pinned_server_id ON cloud_accounts
    WHEN OLD.pinned_server_id IS NOT NULL
      AND NEW.secret_ref = OLD.secret_ref
      AND (NEW.pinned_server_id IS NULL OR NEW.pinned_server_id != OLD.pinned_server_id)
    BEGIN SELECT RAISE(ABORT, 'singleton authority is pinned'); END''',
  '''CREATE TRIGGER singleton_pin_insert AFTER INSERT ON cloud_bindings
    BEGIN UPDATE cloud_accounts SET pinned_server_id = NEW.server_id
      WHERE id = NEW.account_id AND auth_scope = 'singleDevice'; END''',
  '''CREATE TRIGGER singleton_pin_binding_update
    AFTER UPDATE OF server_id, account_id, instance_key ON cloud_bindings
    BEGIN UPDATE cloud_accounts SET pinned_server_id = NEW.server_id
      WHERE id = NEW.account_id AND auth_scope = 'singleDevice'; END''',
];

Future<Database> _raw(String path) => databaseFactoryFfiNoIsolate.openDatabase(
  path,
  options: OpenDatabaseOptions(
    onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
  ),
);

Future<Database> _createV10(String path, {required bool upstream}) async {
  final db = await createLegacyLedgerV9(path, rackV10: !upstream);
  await db.transaction((txn) async {
    if (upstream) {
      for (final sql in _upstreamV10Schema) {
        await txn.execute(sql);
      }
      for (final review in [false, true]) {
        await txn.insert('providers', {
          'id': review ? 'upstream-review' : 'upstream-business',
          'name': review ? 'Review this synthetic provider' : 'Local vendor',
          'revision': review ? 4 : 8,
          'needs_review': review ? 1 : 0,
          'created_at': cloudTestTime.toIso8601String(),
        });
      }
      await txn.update('servers', {'provider_id': 'upstream-business'});
      await txn.update(
        'cloud_accounts',
        {'business_provider_id': 'upstream-business', 'auth_scope': 'account'},
        where: 'id=?',
        whereArgs: ['v2'],
      );
      await txn.update(
        'cloud_accounts',
        {
          'business_provider_id': 'upstream-business',
          'auth_scope': 'singleDevice',
          'pinned_server_id': 'legacy-v1',
        },
        where: 'id=?',
        whereArgs: ['v1'],
      );
      final v1 = (await txn.query(
        'cloud_accounts',
        where: 'id=?',
        whereArgs: ['v1'],
      )).single;
      await txn.insert('cloud_accounts', {
        ...v1,
        'id': 'detached',
        'alias': 'Synthetic detached adapter',
        'secret_ref': 'opaque-synthetic-detached-reference',
        // Pin intentionally outlives deletion of the original local device.
        'pinned_server_id': 'deleted-synthetic-device',
      });
      final v2 = (await txn.query(
        'cloud_accounts',
        where: 'id=?',
        whereArgs: ['v2'],
      )).single;
      await txn.insert('cloud_accounts', {
        ...v2,
        'id': 'unknown-scope',
        'alias': 'Synthetic unresolved adapter',
        'secret_ref': 'opaque-synthetic-unknown-reference',
        'remote_account_id': 18,
        'business_provider_id': 'upstream-review',
        'auth_scope': 'unknown',
      });
      for (final sql in _upstreamV10Guards) {
        await txn.execute(sql);
      }
    } else {
      final server = (await txn.query(
        'servers',
        where: 'id=?',
        whereArgs: ['manual'],
      )).single;
      await txn.insert('servers', {...server, 'id': 'legacy-rack'});
      final v1 = (await txn.query(
        'cloud_accounts',
        where: 'id=?',
        whereArgs: ['v1'],
      )).single;
      await txn.insert('cloud_accounts', {
        ...v1,
        'id': 'rack',
        'provider': 'rackNerd',
        'alias': 'Synthetic RackNerd panel',
        'secret_ref': 'opaque-synthetic-rack-reference',
      });
      final observation = (await txn.query(
        'cloud_observations',
        where: 'account_id=?',
        whereArgs: ['v1'],
      )).single;
      await txn.insert('cloud_observations', {
        ...observation,
        'account_id': 'rack',
      });
      await txn.insert('cloud_bindings', {
        'server_id': 'legacy-rack',
        'account_id': 'rack',
        'instance_key': 'single',
      });
      await txn.insert('cloud_accounts', {
        ...v1,
        'id': 'unbound-rack',
        'provider': 'rackNerd',
        'alias': 'Synthetic unbound panel',
        'secret_ref': 'opaque-synthetic-unbound-rack-reference',
      });
    }
    await txn.execute(
      'CREATE INDEX legacy_observation_stale ON cloud_observations(stale)',
    );
    await txn.execute('''CREATE TRIGGER legacy_observation_guard
      BEFORE UPDATE OF stale ON cloud_observations WHEN NEW.stale NOT IN (0,1)
      BEGIN SELECT RAISE(ABORT, 'invalid synthetic state'); END''');
    await txn.execute('PRAGMA user_version=10');
  });
  return db;
}

void _expectOriginalRows(
  Map<String, List<Map<String, Object?>>> after,
  Map<String, List<Map<String, Object?>>> before, {
  required bool upstream,
}) {
  for (final table in before.entries) {
    expect(
      upstream
          ? after[table.key]
          : after[table.key]!.map(legacyProviderProjection).toList(),
      table.value,
      reason: table.key,
    );
  }
  if (upstream) expect(after.keys.toSet(), before.keys.toSet());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  LedgerStore? store;
  Database? db;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('schema11-true-v10-');
    path = '${directory.path}/ledger.sqlite';
  });
  tearDown(() async {
    await store?.close();
    await db?.close();
    store = null;
    db = null;
    await directory.delete(recursive: true);
  });

  for (final upstream in [false, true]) {
    final flavor = upstream ? 'upstream Provider-v10' : 'local RackNerd-v10';
    test(
      '$flavor upgrades without losing any row, ref, pin or custom schema object',
      () async {
        db = await _createV10(path, upstream: upstream);
        expect(await db!.getVersion(), 10);
        final oldSchema = await legacyLedgerSchema(db!);
        final accountSql =
            oldSchema.singleWhere(
                  (row) => row['name'] == 'cloud_accounts',
                )['sql']
                as String;
        expect(accountSql.contains('rackNerd'), !upstream);
        final columns = (await db!.rawQuery(
          'PRAGMA table_info(cloud_accounts)',
        )).map((row) => row['name']).toSet();
        expect(columns.contains('business_provider_id'), upstream);
        expect(columns.contains('auth_scope'), upstream);
        expect(columns.contains('pinned_server_id'), upstream);
        final before = await legacyLedgerRows(db!);
        expect(await db!.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        await db!.close();
        db = null;
        store = await LedgerStore.open(
          factory: databaseFactoryFfiNoIsolate,
          path: path,
          clock: () => cloudTestTime,
        );
        db = await _raw(path);
        expect(await db!.getVersion(), 11);
        final after = await legacyLedgerRows(db!);
        _expectOriginalRows(after, before, upstream: upstream);
        expect(await db!.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        final newSchema = await legacyLedgerSchema(db!);
        for (final object in oldSchema.where(
          (row) => [
            'legacy_observation_stale',
            'legacy_observation_guard',
          ].contains(row['name']),
        )) {
          expect(
            newSchema.singleWhere((row) => row['name'] == object['name']),
            object,
          );
        }
        expect(
          newSchema.where((row) => (row['name'] as String).contains('_v11')),
          isEmpty,
        );
        final accounts = await store!.cloudAccounts();
        if (upstream) {
          final detached = accounts.singleWhere((a) => a.id == 'detached');
          expect(detached.pinnedServerId, 'deleted-synthetic-device');
          expect(detached.businessProviderId, 'upstream-business');
          expect(
            accounts.singleWhere((a) => a.id == 'unknown-scope').authScope,
            AdapterAuthScope.unknown,
          );
          expect(
            (await store!.providers())
                .singleWhere((p) => p.id == 'upstream-review')
                .needsReview,
            isTrue,
          );
        } else {
          final rack = accounts.singleWhere((a) => a.id == 'rack');
          expect(rack.authScope, AdapterAuthScope.singleDevice);
          expect(rack.pinnedServerId, 'legacy-rack');
          expect(rack.remoteAccountId, isNull);
          final unbound = accounts.singleWhere((a) => a.id == 'unbound-rack');
          expect(unbound.authScope, AdapterAuthScope.singleDevice);
          expect(unbound.pinnedServerId, isNull);
          expect(
            (await store!.providers())
                .singleWhere((p) => p.id == unbound.businessProviderId)
                .needsReview,
            isTrue,
          );
        }
        await store!.close();
        store = null;
        db = null;
        store = await LedgerStore.open(
          factory: databaseFactoryFfiNoIsolate,
          path: path,
          clock: () => cloudTestTime,
        );
        db = await _raw(path);
        expect(await legacyLedgerRows(db!), after);
        final business = (await store!.providers()).firstWhere(
          (p) => !p.needsReview,
        );
        final resources = completedResources();
        final rackAccount = CloudAccount(
          id: 'new-rack',
          provider: CloudProvider.rackNerd,
          businessProviderId: business.id,
          authScope: AdapterAuthScope.singleDevice,
          alias: 'New synthetic RackNerd alias',
          endpoint: 'https://panel.synthetic.example',
          secretRef: 'opaque-synthetic-new-rack-reference',
          createdAt: cloudTestTime,
        );
        final snapshot = CloudSnapshot(
          provider: CloudProvider.rackNerd,
          completedAt: cloudTestTime,
          instances: [
            CloudInstance(
              observedAt: cloudTestTime,
              power: CloudPower.running,
              ipv4: resources.ip,
              hostname: resources.hostname,
              ramBytes: resources.ramBytes,
              diskBytes: resources.diskBytes,
              trafficBytes: resources.trafficBytes,
            ),
          ],
        );
        await store!.reserveSecret(rackAccount.secretRef);
        expect(
          await store!.saveCloudAccount(
            account: rackAccount,
            snapshot: snapshot,
            expected: null,
            selectedInstanceKeys: {'single'},
            v1Resources: resources,
          ),
          1,
        );
        final saved = (await store!.cloudAccounts()).singleWhere(
          (a) => a.id == 'new-rack',
        );
        final imported = (await store!.servers()).singleWhere(
          (s) => s.id == saved.pinnedServerId,
        );
        expect(imported.name, rackAccount.alias);
        expect(imported.providerId, business.id);
        expect(imported.vendor, business.name);
        expect(imported.resources!.toJson(), resources.toJson());
        expect(saved.authScope, AdapterAuthScope.singleDevice);
        expect(saved.remoteAccountId, isNull);
        await expectLater(
          db!.update(
            'cloud_accounts',
            {'auth_scope': 'account'},
            where: 'id=?',
            whereArgs: [saved.id],
          ),
          throwsA(isA<DatabaseException>()),
        );
        await expectLater(
          db!.update(
            'cloud_accounts',
            {'pinned_server_id': null},
            where: 'id=?',
            whereArgs: [saved.id],
          ),
          throwsA(isA<DatabaseException>()),
        );
        expect(await db!.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      },
    );

    test(
      '$flavor late failure restores schema, original rows, guards and version atomically',
      () async {
        db = await _createV10(path, upstream: upstream);
        await db!.execute(
          'CREATE VIEW migration_obstruction AS SELECT id FROM cloud_accounts',
        );
        final before = await legacyLedgerRows(db!);
        final schema = await legacyLedgerSchema(db!);
        await db!.close();
        db = null;
        await expectLater(
          LedgerStore.open(factory: databaseFactoryFfiNoIsolate, path: path),
          throwsA(isA<DatabaseException>()),
        );
        db = await _raw(path);
        expect(await db!.getVersion(), 10);
        expect(await legacyLedgerRows(db!), before);
        expect(await legacyLedgerSchema(db!), schema);
        expect(await db!.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        await db!.execute('DROP VIEW migration_obstruction');
        await db!.close();
        db = null;
        store = await LedgerStore.open(
          factory: databaseFactoryFfiNoIsolate,
          path: path,
        );
        db = await _raw(path);
        expect(await db!.getVersion(), 11);
        _expectOriginalRows(
          await legacyLedgerRows(db!),
          before,
          upstream: upstream,
        );
      },
    );
  }

  test(
    'unknown extension columns fail closed instead of losing data',
    () async {
      db = await _createV10(path, upstream: true);
      await db!.execute(
        'ALTER TABLE cloud_observations ADD COLUMN external_note TEXT',
      );
      await db!.update('cloud_observations', {
        'external_note': 'synthetic extension must survive',
      });
      final before = await legacyLedgerRows(db!);
      final schema = await legacyLedgerSchema(db!);
      await db!.close();
      db = null;
      await expectLater(
        LedgerStore.open(factory: databaseFactoryFfiNoIsolate, path: path),
        throwsStateError,
      );
      db = await _raw(path);
      expect(await db!.getVersion(), 10);
      expect(await legacyLedgerRows(db!), before);
      expect(await legacyLedgerSchema(db!), schema);
    },
  );

  test('partial relationship schema fails closed without adding or overwriting provider data', () async {
    db = await createLegacyLedgerV9(path, rackV10: true);
    await db!.execute(_upstreamV10Schema.first);
    final before = await legacyLedgerRows(db!);
    final schema = await legacyLedgerSchema(db!);
    await db!.close();
    db = null;
    await expectLater(
      LedgerStore.open(factory: databaseFactoryFfiNoIsolate, path: path),
      throwsStateError,
    );
    db = await _raw(path);
    expect(await db!.getVersion(), 10);
    expect(await legacyLedgerRows(db!), before);
    expect(await legacyLedgerSchema(db!), schema);
  });

  test('ambiguous legacy Rack singleton rolls back instead of gaining account scope', () async {
    db = await _createV10(path, upstream: false);
    final observation = (await db!.query(
      'cloud_observations',
      where: 'account_id=?',
      whereArgs: ['rack'],
    )).single;
    await db!.insert('cloud_observations', {
      ...observation,
      'instance_key': 'ambiguous',
    });
    await db!.insert('cloud_bindings', {
      'server_id': 'manual',
      'account_id': 'rack',
      'instance_key': 'ambiguous',
    });
    final before = await legacyLedgerRows(db!);
    final schema = await legacyLedgerSchema(db!);
    await db!.close();
    db = null;
    await expectLater(
      LedgerStore.open(factory: databaseFactoryFfiNoIsolate, path: path),
      throwsStateError,
    );
    db = await _raw(path);
    expect(await db!.getVersion(), 10);
    expect(await legacyLedgerRows(db!), before);
    expect(await legacyLedgerSchema(db!), schema);
  });
}
