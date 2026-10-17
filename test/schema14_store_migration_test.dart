import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'support/legacy_ledger_fixture.dart';

/// Turns a fresh (v14) database into what the v13 app left on disk: no
/// `proxies` table and no `ssh_configurations.proxy_id`.
Future<void> _makeV13(Database db) async {
  await db.execute('PRAGMA foreign_keys=OFF');
  await db.execute('DROP INDEX ssh_proxy');
  await db.execute('ALTER TABLE ssh_configurations RENAME TO ssh_new');
  await db.execute('''CREATE TABLE ssh_configurations (
      server_id TEXT PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
      host TEXT NOT NULL, port INTEGER NOT NULL CHECK(port BETWEEN 1 AND 65535),
      username TEXT NOT NULL, credential_id TEXT REFERENCES credentials(id),
      revision INTEGER NOT NULL DEFAULT 0)''');
  await db.execute('''INSERT INTO ssh_configurations
      SELECT server_id, host, port, username, credential_id, revision
      FROM ssh_new''');
  await db.execute('DROP TABLE ssh_new');
  await db.execute(
    'CREATE INDEX ssh_credential ON ssh_configurations(credential_id)',
  );
  await db.execute('DROP TABLE proxies');
  await db.execute('PRAGMA user_version = 13');
  await db.execute('PRAGMA foreign_keys=ON');
}

Future<Set<String>> _columns(Database db, String table) async =>
    (await db.rawQuery('PRAGMA table_info($table)'))
        .map((r) => r['name'] as String)
        .toSet();

Future<bool> _hasTable(Database db, String name) async => (await db.rawQuery(
  "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
  [name],
)).isNotEmpty;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  LedgerStore? store;
  Database? db;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('schema14-');
    path = '${directory.path}/ledger.db';
  });
  tearDown(() async {
    await store?.close();
    await db?.close();
    store = null;
    db = null;
    await directory.delete(recursive: true);
  });

  Future<void> seedV13() async {
    final first = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
    );
    await first.close();
    final raw = await openRawLedger(path);
    await raw.insert(
      'servers',
      ServerRecord(
        id: 's1',
        name: 'Synthetic',
        vendor: 'Vendor',
        host: '192.0.2.40',
        createdAt: fixtureTime,
        updatedAt: fixtureTime,
      ).toMap(),
    );
    await raw.insert('credentials', {
      'id': 'c1',
      'name': 'Synthetic credential',
      'kind': 'password',
      'default_username': 'root',
      'secret_ref': 'ref-1',
      'created_at': fixtureTime.toIso8601String(),
      'updated_at': fixtureTime.toIso8601String(),
    });
    await raw.insert('ssh_configurations', {
      'server_id': 's1',
      'host': 'ssh.synthetic.example',
      'port': 2222,
      'username': 'root',
      'credential_id': 'c1',
      'revision': 3,
    });
    await _makeV13(raw);
    await raw.close();
  }

  test('v13 upgrades: proxies added, SSH configuration untouched', () async {
    await seedV13();
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
    );
    db = await openRawLedger(path);
    expect(await db!.getVersion(), 14);
    expect(await _columns(db!, 'proxies'), {
      'id',
      'name',
      'kind',
      'host',
      'port',
      'username',
      'secret_ref',
      'created_at',
      'updated_at',
      'revision',
    });
    expect(await _columns(db!, 'ssh_configurations'), contains('proxy_id'));
    final configs = await store!.sshConfigurations();
    expect(configs.single.host, 'ssh.synthetic.example');
    expect(configs.single.port, 2222);
    expect(configs.single.revision, 3);
    expect(configs.single.proxyId, isNull);
    expect(await store!.proxies(), isEmpty);
    expect(await store!.credentials(), hasLength(1));
  });

  test('a failing v14 migration rolls everything back', () async {
    await seedV13();
    final raw = await openRawLedger(path);
    // Collides with the last migration statement, after the table and the
    // column were already added inside the same transaction.
    await raw.execute('CREATE INDEX ssh_proxy ON snippets(name)');
    final before = await raw.query('ssh_configurations');
    await raw.close();

    await expectLater(
      LedgerStore.open(factory: databaseFactoryFfiNoIsolate, path: path),
      throwsA(anything),
    );
    db = await openRawLedger(path);
    expect(await db!.getVersion(), 13, reason: 'still the old version');
    expect(await _hasTable(db!, 'proxies'), isFalse);
    expect(
      await _columns(db!, 'ssh_configurations'),
      isNot(contains('proxy_id')),
    );
    expect(await db!.query('ssh_configurations'), before);
  });

  test('a fresh database has the proxy schema', () async {
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
    );
    db = await openRawLedger(path);
    expect(await db!.getVersion(), LedgerStore.schemaVersion);
    expect(await _hasTable(db!, 'proxies'), isTrue);
    expect(await _columns(db!, 'ssh_configurations'), contains('proxy_id'));
  });

  test(
    'the database refuses a proxy without a user name for its secret',
    () async {
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      db = await openRawLedger(path);
      await expectLater(
        db!.insert('proxies', {
          'id': 'p',
          'name': 'x',
          'kind': 'socks5',
          'host': 'h',
          'port': 1080,
          'secret_ref': 'orphan',
          'created_at': 'a',
          'updated_at': 'a',
        }),
        throwsA(anything),
      );
    },
  );
}
