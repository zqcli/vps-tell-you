import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'support/legacy_ledger_fixture.dart';
import 'support/provider_fixture.dart' show legacyProviderProjection;
import 'support/schema11_fixture.dart';

const _retiredTriggers = [
  'adapter_provider_insert',
  'binding_provider_insert',
  'server_provider_update',
  'singleton_pin_insert',
];

String _resources({bool api = true}) => jsonEncode({
  'ip': '192.0.2.40',
  'ipv6': '2001:db8::40',
  'hostname': 'vps.synthetic.example',
  'vcpu': 2,
  'ramBytes': 2147483648,
  'diskBytes': 32212254720,
  'trafficBytes': 1099511627776,
  'trafficUnlimited': false,
  'trafficPeriodMonths': 1,
  if (api) 'apiFields': ['ip', 'hostname', 'ramBytes'],
});

Future<void> _populate(Database db, List<(String, String)> servers) async {
  final now = fixtureTime.toIso8601String();
  await db.insert('server_groups', {
    'id': 'legacy-group',
    'name': 'Synthetic legacy group',
    'position': 4,
  });
  for (final (id, vendor) in servers) {
    await db.insert(
      'servers',
      legacyProviderProjection(
        ServerRecord(
          id: id,
          name: 'Synthetic $id',
          vendor: vendor,
          host: '192.0.2.40',
          groupId: 'legacy-group',
          notes: 'Local synthetic note\r\nkept byte-for-byte',
          createdAt: fixtureTime,
          updatedAt: fixtureTime,
        ).toMap(),
      )..['resources_json'] = _resources(),
    );
  }
  await db.insert('payments', {
    'id': 'legacy-payment',
    'server_id': servers.first.$1,
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
    'server_id': servers.first.$1,
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
    'server_id': servers.first.$1,
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
    'name': 'Synthetic snippet',
    'content': 'uname -a\r\n',
    'revision': 3,
  });
  await db.insert('app_settings', {
    'id': 1,
    'theme_mode': 'dark',
    'language': 'en',
  });
}

Future<void> _addAdapters(
  Database db, {
  required List<String> secretRefs,
  required List<String> boundServers,
  String provider = 'solusVm1',
  List<String>? businessProviders,
}) async {
  for (var i = 0; i < secretRefs.length; i++) {
    await db.insert('cloud_accounts', {
      'id': 'account-$i',
      'provider': provider,
      'alias': 'Synthetic panel $i',
      'endpoint': 'https://panel.synthetic.example',
      'secret_ref': secretRefs[i],
      'created_at': fixtureTime.toIso8601String(),
      if (businessProviders != null) ...{
        'business_provider_id': businessProviders[i],
        'auth_scope': 'singleDevice',
      },
    });
    await db.insert('cloud_observations', {
      'account_id': 'account-$i',
      'instance_key': 'single',
      'observation': '{}',
    });
  }
  for (var i = 0; i < boundServers.length; i++) {
    await db.insert('cloud_bindings', {
      'server_id': boundServers[i],
      'account_id': 'account-$i',
      'instance_key': 'single',
    });
  }
}

Future<Map<String, List<Map<String, Object?>>>> _rows(
  Database db,
  Iterable<String> tables,
) async => {
  for (final table in tables) table: await db.query(table, orderBy: '1'),
};

const _keptTables = [
  'server_groups',
  'payments',
  'service_periods',
  'finance_settings',
  'credentials',
  'ssh_configurations',
  'host_trust',
  'snippets',
  'app_settings',
  'reminder_rules',
];

Future<Set<String>> _objects(Database db, String type) async =>
    (await db.rawQuery("SELECT name FROM sqlite_master WHERE type=?", [
      type,
    ])).map((r) => r['name'] as String).toSet();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  LedgerStore? store;
  Database? db;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('schema12-');
    path = '${directory.path}/ledger.sqlite';
  });
  tearDown(() async {
    await store?.close();
    await db?.close();
    store = null;
    db = null;
    await directory.delete(recursive: true);
  });

  Future<Database> v11() async {
    final raw = await createV9(path);
    await _populate(raw, [
      ('legacy-a', 'Local vendor'),
      ('legacy-b', 'Mixed vendor'),
      ('manual', 'Local vendor'),
    ]);
    await raw.transaction((txn) async {
      // v9 tables are replaced by their v11 shape (nothing in them yet).
      for (final table in [
        'cloud_bindings',
        'cloud_observations',
        'cloud_accounts',
      ]) {
        await txn.execute('DROP TABLE $table');
      }
      for (final sql in schema11Statements) {
        await txn.execute(sql);
      }
      final created = fixtureTime.toIso8601String();
      await txn.insert('providers', {
        'id': 'p-business',
        'name': 'Local vendor',
        'revision': 8,
        'created_at': created,
      });
      // Adapter-derived placeholders: one owns a server and collides with an
      // existing confirmed name, the other owns nothing.
      await txn.insert('providers', {
        'id': 'p-review',
        'name': 'LOCAL VENDOR',
        'needs_review': 1,
        'created_at': created,
      });
      await txn.insert('providers', {
        'id': 'p-empty-review',
        'name': 'Empty placeholder',
        'needs_review': 1,
        'created_at': created,
      });
      await txn.update('servers', {'provider_id': 'p-business'});
      await txn.update(
        'servers',
        {'provider_id': 'p-review'},
        where: 'id = ?',
        whereArgs: ['legacy-b'],
      );
    });
    await _addAdapters(
      raw,
      secretRefs: ['secret-account-0', 'secret-account-1'],
      boundServers: ['legacy-a', 'legacy-b'],
      businessProviders: ['p-business', 'p-review'],
    );
    await raw.setVersion(11);
    return raw;
  }

  test('v11 upgrades (through v12 to the current schema): adapters dropped, secrets queued, nothing else lost', () async {
    db = await v11();
    final before = await _rows(db!, _keptTables);
    final serversBefore = await db!.query('servers', orderBy: 'id');
    expect(await db!.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    await db!.close();
    db = null;

    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => fixtureTime,
    );
    db = await openRawLedger(path);
    expect(await db!.getVersion(), LedgerStore.schemaVersion);
    expect(await db!.rawQuery('PRAGMA foreign_key_check'), isEmpty);

    final tables = await _objects(db!, 'table');
    for (final gone in [
      'cloud_accounts',
      'cloud_observations',
      'cloud_bindings',
    ]) {
      expect(tables, isNot(contains(gone)));
    }
    final triggers = await _objects(db!, 'trigger');
    for (final gone in _retiredTriggers) {
      expect(triggers, isNot(contains(gone)));
    }
    expect(triggers, contains('server_reminder'));

    // Secret references join the existing cleanup journal; SSH credentials are
    // not touched and are still protected from cleanup.
    expect((await store!.pendingSecretCleanup()).toSet(), {
      'opaque-synthetic-pending-reference',
      'secret-account-0',
      'secret-account-1',
    });
    expect(await store!.secretIsReferenced('secret-account-0'), isFalse);
    expect(
      await store!.secretIsReferenced('opaque-synthetic-ssh-reference'),
      isTrue,
    );

    final after = {
      for (final e in (await _rows(db!, _keptTables)).entries)
        e.key: [for (final r in e.value) Map<String, Object?>.of(r)],
    };
    // The only difference: v13 adds the directory preference column.
    for (final row in after['app_settings']!) {
      expect(row.remove('provider_directory_auto'), 1);
    }
    expect(after, before);
    final serversAfter = await db!.query('servers', orderBy: 'id');
    expect(serversAfter, hasLength(serversBefore.length));
    for (var i = 0; i < serversAfter.length; i++) {
      final old = Map.of(serversBefore[i]);
      final now = Map.of(serversAfter[i]);
      expect(now.remove('package_id'), isNull);
      expect(now.remove('package_snapshot'), isNull);
      final oldResources = jsonDecode(
        old.remove('resources_json') as String,
      ) as Map<String, dynamic>;
      final newResources = jsonDecode(
        now.remove('resources_json') as String,
      ) as Map<String, dynamic>;
      expect(oldResources.remove('apiFields'), isNotNull);
      expect(newResources, oldResources, reason: 'values are kept');
      expect(newResources['ipv6'], '2001:db8::40');
      // provider_id may only change through the neutralised providers below.
      expect(now, old);
    }
    expect((await store!.servers()).every((s) => s.resources != null), isTrue);

    final providers = {for (final p in await store!.providers()) p.id: p};
    expect(providers.keys.toSet(), {'p-business', 'p-review'});
    expect(providers['p-business']!.name, 'Local vendor');
    expect(providers['p-business']!.revision, 8);
    expect(providers['p-review']!.name, 'LOCAL VENDOR (2)');
    expect(providers.values.every((p) => p.catalogId == null), isTrue);
    expect(
      (await store!.servers())
          .singleWhere((s) => s.id == 'legacy-b')
          .providerId,
      'p-review',
    );
    final indexes = await _objects(db!, 'index');
    expect(indexes, containsAll(['providers_name', 'providers_catalog_id']));
    expect(indexes, isNot(contains('confirmed_provider_name')));

    // Reopening is a no-op.
    await store!.close();
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
    );
    expect(await store!.pendingSecretCleanup(), hasLength(3));
  });

  test('v9 without providers derives them from vendor text only', () async {
    final raw = await createV9(path);
    await _populate(raw, [
      ('a', 'Alpha Host'),
      ('b', 'alpha host '),
      ('c', legacyUnknownVendor),
      ('d', ''),
    ]);
    await _addAdapters(raw, secretRefs: ['secret-v9'], boundServers: ['a']);
    await raw.close();
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
    );
    final servers = {for (final s in await store!.servers()) s.id: s};
    final providers = await store!.providers();
    expect(providers.map((p) => p.name), ['Alpha Host']);
    expect(servers['a']!.providerId, providers.single.id);
    expect(servers['b']!.providerId, providers.single.id);
    expect(servers['c']!.providerId, isNull);
    expect(servers['d']!.providerId, isNull);
    expect(servers['b']!.vendor, 'alpha host ', reason: 'legacy text kept');
    expect(await store!.pendingSecretCleanup(), contains('secret-v9'));
    db = await openRawLedger(path);
    expect(await db!.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    expect(await _objects(db!, 'table'), isNot(contains('cloud_accounts')));
  });

  test('a failing migration rolls back and never wipes', () async {
    db = await v11();
    // An unusable secret reference must abort rather than be skipped.
    await db!.execute(
      "UPDATE cloud_accounts SET secret_ref = '' WHERE id = 'account-1'",
    );
    final before = await _rows(db!, [
      ..._keptTables,
      'servers',
      'cloud_accounts',
      'cloud_bindings',
      'providers',
    ]);
    await db!.close();
    db = null;
    await expectLater(
      LedgerStore.open(factory: databaseFactoryFfiNoIsolate, path: path),
      throwsA(anything),
    );
    db = await openRawLedger(path);
    expect(await db!.getVersion(), 11);
    expect(
      await _rows(db!, [
        ..._keptTables,
        'servers',
        'cloud_accounts',
        'cloud_bindings',
        'providers',
      ]),
      before,
    );
    expect(await _objects(db!, 'table'), contains('cloud_accounts'));
    expect(await _objects(db!, 'trigger'), contains('server_provider_update'));
  });

  test(
    'a fresh database has the current shape and no adapter tables',
    () async {
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      db = await openRawLedger(path);
      expect(await db!.getVersion(), LedgerStore.schemaVersion);
      final tables = await _objects(db!, 'table');
      expect(tables.where((t) => t.startsWith('cloud_')), isEmpty);
      final columns = (await db!.rawQuery('PRAGMA table_info(servers)'))
          .map((r) => r['name'])
          .toSet();
      expect(columns, contains('provider_id'));
      final providerColumns = (await db!.rawQuery(
        'PRAGMA table_info(providers)',
      )).map((r) => r['name']).toSet();
      expect(
        providerColumns,
        containsAll(['id', 'name', 'revision', 'catalog_id']),
      );
    },
  );
}
