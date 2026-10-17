import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'support/legacy_ledger_fixture.dart';
import 'support/schema12_fixture.dart';

/// A package snapshot exactly as the schema-12 app wrote it.
const _snapshot =
    '{"snapshotVersion":1,"catalogVersion":1,"id":"example-cloud-small",'
    '"providerId":"example-cloud","name":"Small","vcpu":2,'
    '"ramBytes":2147483648,"diskBytes":42949672960,"trafficBytes":null,'
    '"trafficUnlimited":false,"trafficPeriodMonths":null,'
    '"price":{"amountMinor":1200,"currency":"USD","cycleMonths":1},'
    '"region":"","notes":"Sample"}';

const _resources =
    '{"ip":"192.0.2.40","ipv6":"2001:db8::40","hostname":"vps.example",'
    '"vcpu":2,"ramBytes":2147483648,"diskBytes":42949672960,'
    '"trafficBytes":1099511627776,"trafficUnlimited":false,'
    '"trafficPeriodMonths":1}';

Future<void> _populate(Database db) async {
  final now = fixtureTime.toIso8601String();
  await db.insert('server_groups', {
    'id': 'group',
    'name': 'Synthetic group',
    'position': 3,
  });
  for (final (id, name, catalogId) in [
    ('p-example', 'Example Cloud', 'example-cloud'),
    ('p-demo', 'Demo VPS', 'demo-vps'),
    ('p-real', 'Aliyun', 'aliyun'),
    ('p-custom', 'My own host', null),
  ]) {
    await db.insert('providers', {
      'id': id,
      'name': name,
      'catalog_id': catalogId,
      'revision': 4,
      'created_at': now,
    });
  }
  // Servers 1 and 2 chose a package, 3 has a real directory provider and no
  // package, 4 is custom, 5 has no provider and is archived.
  for (final (id, provider, packaged) in [
    ('s1', 'p-example', true),
    ('s2', 'p-demo', true),
    ('s3', 'p-real', false),
    ('s4', 'p-custom', false),
    ('s5', null, false),
  ]) {
    await db.insert('servers', {
      ...ServerRecord(
        id: id,
        name: 'Synthetic $id',
        vendor: 'Vendor text $id',
        host: '192.0.2.40',
        groupId: 'group',
        providerId: provider,
        notes: 'Local note\r\nkept byte-for-byte',
        favorite: id == 's1',
        createdAt: fixtureTime,
        updatedAt: fixtureTime,
        revision: 6,
      ).toMap(),
      'resources_json': _resources,
      'package_id': packaged ? 'example-cloud-small' : null,
      'package_snapshot': packaged ? _snapshot : null,
      if (id == 's5') 'archived_at': now,
    });
  }
  await db.insert('payments', {
    'id': 'payment',
    'server_id': 's1',
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
    'id': 'period',
    'server_id': 's1',
    'start_date': '2026-10-01',
    'end_date': '2026-11-01',
    'inferred': 0,
    'payment_id': 'payment',
  });
  await db.update('finance_settings', {
    'display_currency': 'EUR',
    'usd_to_cny': '7.1',
    'eur_to_cny': '8.2',
    'rate_date': '2026-10-01',
  });
  await db.insert('credentials', {
    'id': 'credential',
    'name': 'Synthetic credential',
    'kind': 'password',
    'default_username': 'local',
    'secret_ref': 'opaque-synthetic-reference',
    'created_at': now,
    'updated_at': now,
    'revision': 5,
  });
  await db.insert('ssh_configurations', {
    'server_id': 's1',
    'host': 'ssh.synthetic.example',
    'port': 2222,
    'username': 'local',
    'credential_id': 'credential',
    'revision': 2,
  });
  await db.insert('secret_cleanup', {
    'secret_ref': 'opaque-pending-reference',
    'created_at': now,
  });
  await db.insert('host_trust', {
    'generation': 'generation',
    'host': 'ssh.synthetic.example',
    'port': 2222,
    'algorithm': 'ssh-ed25519',
    'public_key': 'synthetic-public-key',
    'fingerprint': 'synthetic-fingerprint',
    'verified_at': now,
    'revision': 6,
  });
  await db.insert('snippets', {
    'id': 'snippet',
    'name': 'Synthetic snippet',
    'content': 'uname -a\r\n',
    'revision': 3,
  });
  await db.update('app_settings', {'theme_mode': 'dark', 'language': 'en'});
  await db.update('reminder_rules', {
    'enabled': 0,
    'lead_days': '[5]',
    'minute_of_day': 600,
  }, where: "server_id = 's1'");
}

const _kept = [
  'server_groups',
  'payments',
  'service_periods',
  'finance_settings',
  'credentials',
  'ssh_configurations',
  'host_trust',
  'snippets',
  'secret_cleanup',
  'reminder_rules',
];

Future<Map<String, List<Map<String, Object?>>>> _rows(
  Database db,
  Iterable<String> tables,
) async => {
  // v14 adds the nullable proxy_id; every other value must be unchanged.
  for (final table in tables)
    table: [
      for (final row in await db.query(table, orderBy: '1'))
        {...row}..removeWhere((k, v) => k == 'proxy_id' && v == null),
    ],
};

Future<Set<String>> _columns(Database db, String table) async =>
    (await db.rawQuery('PRAGMA table_info($table)'))
        .map((r) => r['name'] as String)
        .toSet();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  LedgerStore? store;
  Database? db;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('schema13-');
    path = '${directory.path}/ledger.sqlite';
  });
  tearDown(() async {
    await store?.close();
    await db?.close();
    store = null;
    db = null;
    await directory.delete(recursive: true);
  });

  test(
    'v12 with package links upgrades: links cleared, nothing else lost',
    () async {
      final raw = await createV12(path);
      await _populate(raw);
      final linked = await raw.query(
        'servers',
        where: 'package_id IS NOT NULL',
      );
      expect(linked, hasLength(2), reason: 'the fixture really has links');
      final before = await _rows(raw, _kept);
      final serversBefore = await raw.query('servers', orderBy: 'id');
      final settingsBefore = await raw.query('app_settings');
      final providersBefore = await raw.query('providers', orderBy: 'id');
      expect(await raw.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await raw.close();

      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
        clock: () => fixtureTime,
      );
      db = await openRawLedger(path);
      expect(await db!.getVersion(), LedgerStore.schemaVersion);
      expect(LedgerStore.schemaVersion, 14);
      expect(await db!.rawQuery('PRAGMA foreign_key_check'), isEmpty);

      // Package links are gone; the retired columns stay but are never used.
      expect(
        await db!.query('servers', where: 'package_id IS NOT NULL'),
        isEmpty,
      );
      expect(
        await db!.query('servers', where: 'package_snapshot IS NOT NULL'),
        isEmpty,
      );
      expect(
        await _columns(db!, 'servers'),
        containsAll(['package_id', 'package_snapshot']),
      );

      // Every other server column is byte for byte what it was.
      final serversAfter = await db!.query('servers', orderBy: 'id');
      expect(serversAfter, hasLength(5));
      for (var i = 0; i < serversAfter.length; i++) {
        final old = Map.of(serversBefore[i])
          ..remove('package_id')
          ..remove('package_snapshot');
        final now = Map.of(serversAfter[i])
          ..remove('package_id')
          ..remove('package_snapshot');
        expect(now, old, reason: 'server ${old['id']}');
      }
      expect((await store!.servers()).map((s) => s.providerId), [
        'p-example',
        'p-demo',
        'p-real',
        'p-custom',
        null,
      ]);

      // Round-6 sample ids are unlinked; a real directory id and custom
      // providers are untouched; names and revisions never change.
      final providers = await db!.query('providers', orderBy: 'id');
      expect(
        {for (final p in providers) p['id']: p['catalog_id']},
        {
          'p-custom': null,
          'p-demo': null,
          'p-example': null,
          'p-real': 'aliyun',
        },
      );
      for (var i = 0; i < providers.length; i++) {
        expect(
          Map.of(providers[i])..remove('catalog_id'),
          Map.of(providersBefore[i])..remove('catalog_id'),
        );
      }

      // Payments, SSH, credentials, reminders, preferences: untouched.
      expect(await _rows(db!, _kept), before);
      final settings = await db!.query('app_settings');
      expect(
        settings.single['theme_mode'],
        settingsBefore.single['theme_mode'],
      );
      expect(settings.single['language'], 'en');
      expect(
        settings.single['provider_directory_auto'],
        1,
        reason: 'auto update defaults to on',
      );
      expect(await store!.providerDirectoryAuto(), isTrue);

      // The preference is persisted, and reopening is a no-op.
      await store!.saveProviderDirectoryAuto(false);
      await store!.close();
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      expect(await store!.providerDirectoryAuto(), isFalse);
      expect(await store!.providerDirectoryAuto(), isFalse);
      expect(await store!.servers(), hasLength(5));
      await store!.saveProviderDirectoryAuto(true);
      expect(await store!.providerDirectoryAuto(), isTrue);
    },
  );

  test('a failing v13 migration rolls everything back', () async {
    final raw = await createV12(path);
    await _populate(raw);
    // A guard which only fires on the sample-id step, after the package links
    // were already cleared inside the same transaction.
    await raw.execute('''CREATE TRIGGER block_unlink BEFORE UPDATE ON providers
      BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END''');
    final before = await _rows(raw, [..._kept, 'servers', 'providers']);
    final settingsColumns = await _columns(raw, 'app_settings');
    await raw.close();

    await expectLater(
      LedgerStore.open(factory: databaseFactoryFfiNoIsolate, path: path),
      throwsA(anything),
    );
    db = await openRawLedger(path);
    expect(await db!.getVersion(), 12, reason: 'still the old version');
    expect(await _rows(db!, [..._kept, 'servers', 'providers']), before);
    expect(
      await db!.query('servers', where: 'package_id IS NOT NULL'),
      hasLength(2),
      reason: 'links survive a failed migration',
    );
    expect(await _columns(db!, 'app_settings'), settingsColumns);
  });

  test('a fresh database has no retired columns', () async {
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
    );
    db = await openRawLedger(path);
    expect(await db!.getVersion(), LedgerStore.schemaVersion);
    final serverColumns = await _columns(db!, 'servers');
    expect(serverColumns, contains('provider_id'));
    expect(serverColumns, isNot(contains('package_id')));
    expect(serverColumns, isNot(contains('package_snapshot')));
    expect(
      (await db!.rawQuery(
        "SELECT name FROM sqlite_master WHERE name = 'servers_package'",
      )),
      isEmpty,
    );
    expect(await _columns(db!, 'providers'), contains('catalog_id'));
    expect(await store!.providerDirectoryAuto(), isTrue);
    await store!.saveProviderDirectoryAuto(false);
    expect(await store!.providerDirectoryAuto(), isFalse);
  });

  test('a newer database is refused, never downgraded', () async {
    final raw = await createV12(path);
    await raw.setVersion(99);
    await raw.close();
    await expectLater(
      LedgerStore.open(factory: databaseFactoryFfiNoIsolate, path: path),
      throwsA(anything),
    );
    db = await openRawLedger(path);
    expect(await db!.getVersion(), 99);
  });
}
