import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_account.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'cloud_store_test.dart' show cloudTestTime, completedResources;

// This is the real v9 DDL, including its original provider/remote-ID CHECKs.
// Never construct this fixture with LedgerStore.createSchema or by relabeling
// a newly created database: doing so would hide the required CHECK migration.
const _v9Schema = [
  '''CREATE TABLE server_groups (
    id TEXT PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE UNIQUE,
    position INTEGER NOT NULL)''',
  '''CREATE TABLE servers (
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
    is_demo INTEGER NOT NULL DEFAULT 0 CHECK(is_demo IN (0,1)),
    renewal_anchor_date TEXT, resources_json TEXT)''',
  'CREATE INDEX servers_group ON servers(group_id)',
  'CREATE INDEX servers_archive ON servers(archived_at)',
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
  '''CREATE UNIQUE INDEX payments_active_until
    ON payments(server_id,until_date) WHERE server_id IS NOT NULL AND voided_at IS NULL''',
  '''CREATE TABLE service_periods (
    id TEXT PRIMARY KEY, server_id TEXT NOT NULL REFERENCES servers(id),
    start_date TEXT NOT NULL, end_date TEXT NOT NULL CHECK(end_date > start_date),
    inferred INTEGER NOT NULL CHECK(inferred IN (0,1)),
    payment_id TEXT REFERENCES payments(id))''',
  'CREATE INDEX service_periods_server ON service_periods(server_id,start_date)',
  '''CREATE TABLE finance_settings (
    id INTEGER PRIMARY KEY CHECK(id=1), display_currency TEXT NOT NULL,
    usd_to_cny TEXT, eur_to_cny TEXT, rate_date TEXT)''',
  '''CREATE TABLE credentials (
    id TEXT PRIMARY KEY, name TEXT NOT NULL,
    kind TEXT NOT NULL CHECK(kind IN ('password','privateKey')),
    default_username TEXT NOT NULL DEFAULT '', secret_ref TEXT NOT NULL UNIQUE,
    key_algorithm TEXT, fingerprint TEXT,
    created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
    revision INTEGER NOT NULL DEFAULT 0)''',
  '''CREATE TABLE ssh_configurations (
    server_id TEXT PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
    host TEXT NOT NULL, port INTEGER NOT NULL CHECK(port BETWEEN 1 AND 65535),
    username TEXT NOT NULL, credential_id TEXT REFERENCES credentials(id),
    revision INTEGER NOT NULL DEFAULT 0)''',
  'CREATE INDEX ssh_credential ON ssh_configurations(credential_id)',
  '''CREATE TABLE secret_cleanup (
    secret_ref TEXT PRIMARY KEY, created_at TEXT NOT NULL)''',
  '''CREATE TABLE host_trust (
    generation TEXT NOT NULL UNIQUE, host TEXT NOT NULL,
    port INTEGER NOT NULL CHECK(port BETWEEN 1 AND 65535),
    algorithm TEXT NOT NULL, public_key TEXT NOT NULL, fingerprint TEXT NOT NULL,
    verified_at TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(host, port))''',
  '''CREATE TABLE snippets (
    id TEXT PRIMARY KEY, name TEXT NOT NULL, content TEXT NOT NULL,
    revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0))''',
  '''CREATE TABLE cloud_accounts (
    id TEXT PRIMARY KEY, provider TEXT NOT NULL CHECK(provider IN ('solusVm1','solusVm2')),
    alias TEXT NOT NULL, endpoint TEXT NOT NULL, secret_ref TEXT NOT NULL UNIQUE,
    remote_account_id INTEGER, revision INTEGER NOT NULL DEFAULT 0,
    generation INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL,
    last_attempt_at TEXT, last_failure TEXT,
    CHECK((provider = 'solusVm1' AND remote_account_id IS NULL) OR
          (provider = 'solusVm2' AND remote_account_id > 0)))''',
  '''CREATE TABLE cloud_observations (
    account_id TEXT NOT NULL REFERENCES cloud_accounts(id) ON DELETE CASCADE,
    instance_key TEXT NOT NULL, identity_uuid TEXT, observation TEXT NOT NULL,
    stale INTEGER NOT NULL DEFAULT 0 CHECK(stale IN (0,1)),
    missing INTEGER NOT NULL DEFAULT 0 CHECK(missing IN (0,1)),
    PRIMARY KEY(account_id, instance_key))''',
  '''CREATE TABLE cloud_bindings (
    server_id TEXT PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
    account_id TEXT NOT NULL, instance_key TEXT NOT NULL,
    UNIQUE(account_id, instance_key),
    FOREIGN KEY(account_id, instance_key)
      REFERENCES cloud_observations(account_id, instance_key) ON DELETE CASCADE)''',
  '''CREATE TABLE app_settings (
    id INTEGER PRIMARY KEY CHECK(id=1),
    theme_mode TEXT NOT NULL CHECK(theme_mode IN ('system','light','dark')),
    language TEXT NOT NULL DEFAULT 'zh' CHECK(language IN ('zh','en','system')))''',
  '''CREATE TABLE reminder_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT CHECK(id BETWEEN 1 AND 268435455),
    server_id TEXT NOT NULL UNIQUE REFERENCES servers(id) ON DELETE CASCADE,
    enabled INTEGER NOT NULL DEFAULT 1 CHECK(enabled IN (0,1)),
    lead_days TEXT NOT NULL DEFAULT '[7,3,1]',
    minute_of_day INTEGER NOT NULL DEFAULT 540 CHECK(minute_of_day BETWEEN 0 AND 1439),
    usage_plan TEXT NOT NULL DEFAULT 'continueUsing'
      CHECK(usage_plan IN ('continueUsing','undecided','stopAtExpiry')),
    revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0))''',
  '''CREATE TRIGGER server_reminder AFTER INSERT ON servers
    BEGIN INSERT INTO reminder_rules (server_id) VALUES (NEW.id); END''',
];

Future<Database> _openRaw(String path) =>
    databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
      ),
    );

Future<Database> _createV9(String path) =>
    databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 9,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: (db, _) async {
          for (final statement in _v9Schema) {
            await db.execute(statement);
          }
          await _populateV9(db);
        },
      ),
    );

Future<void> _populateV9(DatabaseExecutor db) async {
  final now = cloudTestTime.toIso8601String();
  await db.insert('server_groups', {
    'id': 'legacy-group',
    'name': 'Synthetic legacy group',
    'position': 4,
  });
  for (final id in ['legacy-v1', 'legacy-v2', 'manual']) {
    await db.insert(
      'servers',
      ServerRecord(
        id: id,
        name: 'Synthetic $id',
        vendor: 'Local vendor',
        host: '192.0.2.40',
        groupId: 'legacy-group',
        notes: 'Local synthetic note\r\nkept byte-for-byte',
        resources: completedResources(),
        createdAt: cloudTestTime,
        updatedAt: cloudTestTime,
      ).toMap(),
    );
  }
  await db.insert('payments', {
    'id': 'legacy-payment',
    'server_id': 'legacy-v2',
    'target_name': 'Synthetic ledger label',
    'account_label': null,
    'amount_minor': 1234,
    'currency': 'EUR',
    'paid_date': '2026-10-01',
    'from_date': '2026-10-01',
    'until_date': '2026-11-01',
    'cycle_count': 1,
    'note': 'Synthetic payment note',
    'previous_due': '2026-10-01',
    'applied_server_revision': 3,
    'created_at': now,
    'voided_at': null,
    'request_fingerprint': 'synthetic-fingerprint',
  });
  await db.insert('service_periods', {
    'id': 'legacy-period',
    'server_id': 'legacy-v2',
    'start_date': '2026-10-01',
    'end_date': '2026-11-01',
    'inferred': 0,
    'payment_id': 'legacy-payment',
  });
  await db.insert('finance_settings', {
    'id': 1,
    'display_currency': 'EUR',
    'usd_to_cny': '7.1',
    'eur_to_cny': '8.2',
    'rate_date': '2026-10-01',
  });
  await db.insert('credentials', {
    'id': 'legacy-ssh-credential',
    'name': 'Synthetic local credential',
    'kind': 'password',
    'default_username': 'local',
    'secret_ref': 'opaque-synthetic-ssh-reference',
    'created_at': now,
    'updated_at': now,
    'revision': 5,
  });
  await db.insert('ssh_configurations', {
    'server_id': 'legacy-v1',
    'host': 'ssh.synthetic.example',
    'port': 2222,
    'username': 'local',
    'credential_id': 'legacy-ssh-credential',
    'revision': 2,
  });
  await db.insert('secret_cleanup', {
    'secret_ref': 'opaque-synthetic-pending-reference',
    'created_at': now,
  });
  await db.insert('host_trust', {
    'generation': 'synthetic-generation',
    'host': 'ssh.synthetic.example',
    'port': 2222,
    'algorithm': 'ssh-ed25519',
    'public_key': 'synthetic-public-key',
    'fingerprint': 'synthetic-public-fingerprint',
    'verified_at': now,
    'revision': 6,
  });
  await db.insert('snippets', {
    'id': 'legacy-snippet',
    'name': 'Synthetic read-only snippet',
    'content': 'uname -a\r\n',
    'revision': 3,
  });
  await db.insert('app_settings', {
    'id': 1,
    'theme_mode': 'dark',
    'language': 'en',
  });
  await db.update('reminder_rules', {
    'enabled': 0,
    'lead_days': '[14,2]',
    'minute_of_day': 601,
    'usage_plan': 'undecided',
    'revision': 8,
  });
  for (final v1 in [true, false]) {
    final account = CloudAccount(
      id: v1 ? 'v1' : 'v2',
      provider: v1 ? CloudProvider.solusVm1 : CloudProvider.solusVm2,
      alias: v1 ? 'Synthetic V1 account' : 'Synthetic V2 account',
      endpoint: 'https://panel.synthetic.example:8443',
      secretRef: 'opaque-synthetic-${v1 ? 'v1' : 'v2'}-reference',
      remoteAccountId: v1 ? null : 7,
      createdAt: cloudTestTime,
      revision: v1 ? 4 : 6,
      generation: v1 ? 9 : 12,
      lastAttemptAt: cloudTestTime,
      lastFailure: v1 ? CloudFailureKind.timeout : null,
    );
    await db.insert('cloud_accounts', account.toMap());
    await db.insert('cloud_observations', {
      'account_id': account.id,
      'instance_key': v1 ? 'single' : '7/2/3',
      'identity_uuid': v1 ? null : 'synthetic-v2-uuid',
      'observation': encodeCloudInstance(
        CloudInstance(
          observedAt: cloudTestTime,
          power: CloudPower.running,
          projectId: v1 ? null : 2,
          serverId: v1 ? null : 3,
          uuid: v1 ? null : 'synthetic-v2-uuid',
          hostname: 'vps.synthetic.example',
          ipv4: '192.0.2.40',
          ramBytes: 2147483648,
          diskBytes: 32212254720,
          trafficBytes: 1099511627776,
        ),
      ),
      'stale': v1 ? 1 : 0,
      'missing': 0,
    });
    await db.insert('cloud_bindings', {
      'server_id': 'legacy-${account.id}',
      'account_id': account.id,
      'instance_key': v1 ? 'single' : '7/2/3',
    });
  }
  await db.insert('cloud_observations', {
    'account_id': 'v2',
    'instance_key': '7/2/4',
    'identity_uuid': 'synthetic-missing-uuid',
    'observation': encodeCloudInstance(
      CloudInstance(
        observedAt: cloudTestTime,
        power: CloudPower.stopped,
        projectId: 2,
        serverId: 4,
        uuid: 'synthetic-missing-uuid',
      ),
    ),
    'stale': 1,
    'missing': 1,
  });
}

Future<Map<String, List<Map<String, Object?>>>> _rows(Database db) async {
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
  );
  return {
    for (final table in tables)
      table['name']! as String: await db.query(
        table['name']! as String,
        orderBy: 'rowid',
      ),
  };
}

Future<List<Map<String, Object?>>> _schema(Database db) => db.rawQuery(
  'SELECT type, name, tbl_name, sql FROM sqlite_master ORDER BY type, name',
);

Map<String, Object?> _accountRow(
  String id,
  String provider,
  int? remoteAccountId,
) => {
  'id': id,
  'provider': provider,
  'alias': 'Synthetic $id',
  'endpoint': 'https://panel.synthetic.example',
  'secret_ref': 'opaque-synthetic-$id-reference',
  'remote_account_id': remoteAccountId,
  'created_at': cloudTestTime.toIso8601String(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  LedgerStore? store;
  Database? raw;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'real-v9-rack-migration-',
    );
    path = '${directory.path}/ledger.sqlite';
  });
  tearDown(() async {
    await store?.close();
    await raw?.close();
    store = null;
    raw = null;
    await directory.delete(recursive: true);
  });

  test(
    'real v9 migration preserves every table and reopens unchanged',
    () async {
      raw = await _createV9(path);
      expect(await raw!.getVersion(), 9);
      final originalSchema = await _schema(raw!);
      final oldCheck =
          originalSchema.singleWhere(
                (row) => row['name'] == 'cloud_accounts',
              )['sql']!
              as String;
      expect(oldCheck, contains("provider IN ('solusVm1','solusVm2')"));
      expect(oldCheck, isNot(contains('rackNerd')));
      await expectLater(
        raw!.insert('cloud_accounts', _accountRow('rack', 'rackNerd', null)),
        throwsA(isA<DatabaseException>()),
      );
      final before = await _rows(raw!);
      expect(await raw!.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await raw!.close();
      raw = null;

      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      raw = await _openRaw(path);
      expect(await raw!.getVersion(), 10);
      expect(await _rows(raw!), before);
      expect(await raw!.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        (await store!.cloudAccounts()).map((account) => account.provider),
        [CloudProvider.solusVm1, CloudProvider.solusVm2],
      );
      expect(await store!.cloudBindings(), hasLength(2));
      final newSchema = await _schema(raw!);
      for (final original in originalSchema.where(
        (row) => !(row['tbl_name']! as String).startsWith('cloud_'),
      )) {
        expect(
          newSchema.singleWhere(
            (row) =>
                row['type'] == original['type'] &&
                row['name'] == original['name'],
          ),
          original,
          reason: original['name']! as String,
        );
      }
      await store!.close();
      store = null;
      raw = null;
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      raw = await _openRaw(path);
      expect(await _rows(raw!), before);
      expect(await raw!.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  for (final migrated in [false, true]) {
    test(
      '${migrated ? 'migrated' : 'fresh'} v10 enforces provider and remote identity CHECKs',
      () async {
        if (migrated) {
          raw = await _createV9(path);
          await raw!.close();
          raw = null;
        }
        store = await LedgerStore.open(
          factory: databaseFactoryFfiNoIsolate,
          path: path,
        );
        raw = await _openRaw(path);
        var id = 0;
        for (final invalid in [
          ('rackNerd', 7),
          ('solusVm1', 7),
          ('solusVm2', null),
          ('solusVm2', 0),
          ('solusVm2', -1),
          ('unknown', null),
        ]) {
          await expectLater(
            raw!.insert(
              'cloud_accounts',
              _accountRow('invalid-${id++}', invalid.$1, invalid.$2),
            ),
            throwsA(isA<DatabaseException>()),
          );
        }
        for (final valid in [
          ('rackNerd', null),
          ('solusVm1', null),
          ('solusVm2', 11),
        ]) {
          await raw!.insert(
            'cloud_accounts',
            _accountRow('valid-${id++}', valid.$1, valid.$2),
          );
        }
        expect(await raw!.query('cloud_accounts'), hasLength(migrated ? 5 : 3));
        expect(await raw!.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      },
    );
  }

  test('late migration failure rolls back dropped tables, rows and version', () async {
    raw = await _createV9(path);
    // The view becomes invalid only after the old account table is dropped;
    // SQLite rejects the subsequent replacement rename. This injects failure
    // after copying and dropping the entire old graph, not merely before work.
    await raw!.execute(
      'CREATE VIEW migration_obstruction AS SELECT id FROM cloud_accounts',
    );
    final before = await _rows(raw!);
    final schemaBefore = await _schema(raw!);
    await raw!.close();
    raw = null;
    await expectLater(
      LedgerStore.open(factory: databaseFactoryFfiNoIsolate, path: path),
      throwsA(isA<DatabaseException>()),
    );
    raw = await _openRaw(path);
    expect(await raw!.getVersion(), 9);
    expect(await _rows(raw!), before);
    expect(await _schema(raw!), schemaBefore);
    expect(await raw!.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    expect(
      (await raw!.rawQuery('PRAGMA foreign_keys')).single.values.single,
      1,
    );
    await raw!.execute('DROP VIEW migration_obstruction');
    await raw!.close();
    raw = null;
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
    );
    raw = await _openRaw(path);
    expect(await raw!.getVersion(), 10);
    expect(await _rows(raw!), before);
  });

  test('invalid legacy V2 identity fails without inventing an ID or losing data', () async {
    raw = await _createV9(path);
    // SQLite CHECK(NULL) passes in v9; app-created V2 accounts already require
    // positive IDs. An invalid legacy row must fail closed, not be rewritten.
    await raw!.insert(
      'cloud_accounts',
      _accountRow('invalid-legacy', 'solusVm2', null),
    );
    final before = await _rows(raw!);
    final schemaBefore = await _schema(raw!);
    await raw!.close();
    raw = null;
    await expectLater(
      LedgerStore.open(factory: databaseFactoryFfiNoIsolate, path: path),
      throwsA(isA<DatabaseException>()),
    );
    raw = await _openRaw(path);
    expect(await raw!.getVersion(), 9);
    expect(await _rows(raw!), before);
    expect(await _schema(raw!), schemaBefore);
  });

  test(
    'migrated foreign keys retain CASCADE and uniqueness without server loss',
    () async {
      raw = await _createV9(path);
      final before = await _rows(raw!);
      await raw!.close();
      raw = null;
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      raw = await _openRaw(path);
      expect(
        (await raw!.rawQuery('PRAGMA foreign_key_list(cloud_observations)'))
            .map((row) => row['table']),
        ['cloud_accounts'],
      );
      expect(
        (await raw!.rawQuery('PRAGMA foreign_key_list(cloud_bindings)'))
            .map((row) => row['table'])
            .toSet(),
        {'servers', 'cloud_observations'},
      );
      await expectLater(
        raw!.insert('cloud_bindings', {
          'server_id': 'manual',
          'account_id': 'v1',
          'instance_key': 'single',
        }),
        throwsA(isA<DatabaseException>()),
      );
      await raw!.delete('cloud_accounts', where: 'id=?', whereArgs: ['v1']);
      expect(await raw!.query('cloud_bindings'), hasLength(1));
      expect(await raw!.query('cloud_observations'), hasLength(2));
      await raw!.delete(
        'cloud_observations',
        where: 'account_id=? AND instance_key=?',
        whereArgs: ['v2', '7/2/3'],
      );
      expect(await raw!.query('cloud_bindings'), isEmpty);
      await raw!.insert('cloud_bindings', {
        'server_id': 'manual',
        'account_id': 'v2',
        'instance_key': '7/2/4',
      });
      await raw!.delete('servers', where: 'id=?', whereArgs: ['manual']);
      expect(await raw!.query('cloud_bindings'), isEmpty);
      expect(await raw!.query('cloud_observations'), hasLength(1));
      for (final table in [
        'payments',
        'service_periods',
        'ssh_configurations',
        'credentials',
        'finance_settings',
        'host_trust',
        'secret_cleanup',
        'snippets',
        'app_settings',
      ]) {
        expect(
          await raw!.query(table, orderBy: 'rowid'),
          before[table],
          reason: table,
        );
      }
      expect(
        await raw!.query('servers', orderBy: 'rowid'),
        before['servers']!.where((row) => row['id'] != 'manual').toList(),
      );
      expect(await raw!.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );
}
