import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'cloud_store_test.dart' show snapshot, completedResources, cloudTestTime;
import 'support/provider_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  late LedgerStore store;
  late ProviderRecord other;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('provider-relations-');
    path = '${directory.path}/ledger.sqlite3';
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => cloudTestTime,
    );
    await addTestProvider(store);
    other = ProviderRecord(
      id: 'other-provider',
      name: 'Other provider',
      createdAt: cloudTestTime,
    );
    await store.saveProvider(other, isNew: true);
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });
  Future<Database> raw() => databaseFactoryFfiNoIsolate.openDatabase(path);
  Future<ServerRecord> device(
    String id, {
    String? provider,
    String vendor = 'Local vendor',
  }) async {
    final record = ServerRecord(
      id: id,
      name: 'Device $id',
      vendor: vendor,
      providerId: provider ?? testProvider.id,
      resources: completedResources(),
      billing: BillingKind.prepaid,
      amountMinor: 1999,
      startDate: const LedgerDate(2026, 1, 1),
      dueDate: const LedgerDate(2027, 1, 1),
      notes: 'Synthetic local note',
      createdAt: cloudTestTime,
      updatedAt: cloudTestTime,
    );
    await store.saveServer(record, isNew: true);
    return (await store.servers()).singleWhere((s) => s.id == id);
  }

  Future<CloudAccount> adapter(
    String id, {
    bool v1 = false,
    String? provider,
    bool import = false,
    int remoteServer = 3,
  }) async {
    final data = snapshot(
      v1: v1,
      server: remoteServer,
      uuid: 'uuid-$remoteServer',
    );
    final account = CloudAccount(
      id: id,
      provider: data.provider,
      businessProviderId: provider ?? testProvider.id,
      authScope: adapterScope(data.provider),
      alias: 'Adapter $id',
      endpoint: 'https://panel.example',
      secretRef: 'opaque-$id',
      remoteAccountId: data.remoteAccountId,
      createdAt: cloudTestTime,
    );
    await store.reserveSecret(account.secretRef);
    await store.saveCloudAccount(
      account: account,
      snapshot: data,
      expected: null,
      selectedInstanceKeys: import
          ? data.instances.map((i) => cloudInstanceKey(data, i)).toSet()
          : {},
      v1Resources: v1 ? completedResources() : null,
    );
    return (await store.cloudAccounts()).singleWhere((a) => a.id == id);
  }

  Future<void> bind(String serverId, String adapterId) async {
    final options = await store.serverCloudBindingOptions(serverId);
    await store.setServerCloudBinding(
      options,
      choice: options.choices.singleWhere((c) => c.accountId == adapterId),
    );
  }

  test(
    'business providers are independent of adapter implementation and endpoint',
    () async {
      await adapter('one', v1: true);
      await adapter('two', v1: true);
      await adapter('three');
      final accounts = await store.cloudAccounts();
      expect(accounts, hasLength(3));
      expect(accounts.map((a) => a.businessProviderId).toSet(), {
        testProvider.id,
      });
      expect(accounts.map((a) => a.secretRef).toSet(), hasLength(3));
      expect(
        accounts.where((a) => a.adapterType == AdapterType.solusVm1),
        hasLength(2),
      );
      expect(
        accounts.last.authScope,
        AdapterAuthScope.singleDevice,
      ); // Sorted aliases: one, three, two.
    },
  );

  test('cross-provider binding is rejected by store and raw SQL', () async {
    await device('local', provider: other.id);
    await adapter('one');
    await expectLater(
      bind('local', 'one'),
      throwsA(isA<CloudAccountFailure>()),
    );
    final db = await raw();
    await expectLater(
      db.insert('cloud_bindings', {
        'server_id': 'local',
        'account_id': 'one',
        'instance_key': '7/2/3',
      }),
      throwsA(isA<DatabaseException>()),
    );
    expect(await store.cloudBindings(), isEmpty);
  });

  test('scope cannot be expanded by a caller or by inventory length', () async {
    final a = await adapter('v2');
    expect(a.authScope, AdapterAuthScope.account);
    final db = await raw();
    await expectLater(
      db.update(
        'cloud_accounts',
        {'auth_scope': 'singleDevice'},
        where: 'id = ?',
        whereArgs: [a.id],
      ),
      throwsA(isA<DatabaseException>()),
    );
    await db.update(
      'cloud_accounts',
      {'auth_scope': 'unknown'},
      where: 'id = ?',
      whereArgs: [a.id],
    );
    await device('local');
    await expectLater(bind('local', a.id), throwsA(isA<CloudAccountFailure>()));
    expect(await store.cloudBindings(), isEmpty);
  });

  test('V1 pin survives unlink, archive, and reopening and rejects a second device', () async {
    final first = await device('first');
    await device('second');
    await adapter('single', v1: true);
    await bind('first', 'single');
    await store.setServerCloudBinding(
      await store.serverCloudBindingOptions('first'),
    );
    await store.archive(first);
    await store.close();
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
    );
    final a = (await store.cloudAccounts()).single;
    expect(a.pinnedServerId, 'first');
    expect(await store.cloudBindings(), isEmpty);
    await expectLater(
      bind('second', 'single'),
      throwsA(isA<CloudAccountFailure>()),
    );
    final db = await raw();
    await expectLater(
      db.update(
        'cloud_accounts',
        {'pinned_server_id': null},
        where: 'id = ?',
        whereArgs: [a.id],
      ),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('V1 may relink the original device but cannot reimport a second local record', () async {
    await device('original');
    await adapter('single', v1: true);
    await bind('original', 'single');
    await store.setServerCloudBinding(
      await store.serverCloudBindingOptions('original'),
    );
    final current = (await store.cloudAccounts()).single;
    await expectLater(
      store.importCloudInstances(
        CloudInventory(account: current, snapshot: snapshot(v1: true)),
        selectedInstanceKeys: {'single'},
        v1Resources: completedResources(),
      ),
      throwsA(isA<CloudAccountFailure>()),
    );
    expect(await store.servers(), hasLength(1));
    await bind('original', 'single');
    expect((await store.cloudBindings()).single.serverId, 'original');
  });

  test('changing provider requires explicit unlink and preserves all local payloads', () async {
    final server = await device('local');
    await adapter('single', v1: true);
    await bind(server.id, 'single');
    await store.saveSshConfiguration(
      SshConfiguration(
        serverId: server.id,
        host: 'ssh.example.test',
        port: 2222,
        username: 'fixture',
        revision: -1,
      ),
    );
    final db = await raw();
    final periods = await db.query('service_periods');
    final ssh = await db.query('ssh_configurations');
    final before = (await store.servers()).single.toMap();
    final options = await store.serverCloudBindingOptions(server.id);
    await expectLater(
      store.setServerProvider(options, other.id),
      throwsA(isA<CloudAccountFailure>()),
    );
    expect(await store.cloudBindings(), hasLength(1));
    await store.setServerProvider(options, other.id, confirmUnlink: true);
    final after = (await store.servers()).single.toMap();
    expect(after['provider_id'], other.id);
    for (final key in ['provider_id', 'revision', 'updated_at']) {
      before.remove(key);
      after.remove(key);
    }
    expect(after, before);
    expect(await db.query('service_periods'), periods);
    expect(await db.query('ssh_configurations'), ssh);
    expect(await store.cloudBindings(), isEmpty);
    expect((await store.cloudAccounts()).single.pinnedServerId, server.id);
  });

  test(
    'old provider-change confirmation cannot unlink a newer adapter',
    () async {
      await device('local');
      await adapter('one');
      await adapter('two', remoteServer: 4);
      await bind('local', 'one');
      final old = await store.serverCloudBindingOptions('local');
      await bind('local', 'two');
      await expectLater(
        store.setServerProvider(old, other.id, confirmUnlink: true),
        throwsA(isA<LedgerConflict>()),
      );
      expect((await store.cloudBindings()).single.accountId, 'two');
      expect((await store.servers()).single.providerId, testProvider.id);
    },
  );

  test(
    'raw provider updates cannot silently transfer an existing binding',
    () async {
      final server = await device('local');
      await adapter('one');
      await bind('local', 'one');
      final db = await raw();
      await expectLater(
        db.update(
          'servers',
          {'provider_id': other.id},
          where: 'id = ?',
          whereArgs: [server.id],
        ),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        db.update('cloud_accounts', {'business_provider_id': other.id}),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        store.saveServer(
          ServerRecord.fromMap({...server.toMap(), 'provider_id': other.id}),
          isNew: false,
        ),
        throwsA(isA<CloudAccountFailure>()),
      );
      expect((await store.cloudBindings()).single.accountId, 'one');
    },
  );

  test(
    'v9 migration preserves every old row and conservatively groups providers',
    () async {
      await device('consistent', vendor: 'Known vendor');
      await device('mixed-a', vendor: 'Vendor A');
      await device('mixed-b', vendor: 'Vendor B');
      await device('manual', vendor: 'Known vendor');
      await device('unknown', vendor: '服务商待填写');
      await adapter('single', v1: true);
      await adapter('mixed');
      await adapter('unbound');
      await bind('consistent', 'single');
      await bind('mixed-a', 'mixed');
      final db = await raw();
      final mixed = (await store.cloudAccounts()).singleWhere(
        (a) => a.id == 'mixed',
      );
      final read = await store.beginCloudRead(mixed);
      final two = snapshot(server: 4, uuid: 'uuid-4');
      await store.commitCloudSnapshot(
        read,
        CloudSnapshot(
          provider: CloudProvider.solusVm2,
          remoteAccountId: 7,
          completedAt: cloudTestTime,
          instances: [
            ...snapshot(uuid: 'uuid-3').instances,
            ...two.instances,
          ],
        ),
      );
      final options = await store.serverCloudBindingOptions('mixed-b');
      await store.setServerCloudBinding(
        options,
        choice: options.choices.singleWhere(
          (c) => c.accountId == 'mixed' && c.instanceKey == '7/2/4',
        ),
      );
      await store.saveSshConfiguration(
        const SshConfiguration(
          serverId: 'consistent',
          host: 'ssh.example.test',
          port: 2222,
          username: 'fixture',
          revision: -1,
        ),
      );
      await removeProviderSchema(db);
      await db.setVersion(9);
      final tableNames = (await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
      )).map((r) => r['name'] as String).toList();
      final before = {
        for (final name in tableNames) name: await db.query(name),
      };
      await store.close();
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      final upgraded = await raw();
      expect(await upgraded.getVersion(), 10);
      for (final name in tableNames) {
        expect(
          (await upgraded.query(name)).map(legacyProviderProjection).toList(),
          before[name],
          reason: name,
        );
      }
      final providers = await store.providers();
      expect(providers.where((p) => !p.needsReview).map((p) => p.name), [
        'Known vendor',
      ]);
      expect(providers.where((p) => p.needsReview), hasLength(2));
      final accounts = await store.cloudAccounts();
      final migratedMixed = accounts.singleWhere((a) => a.id == 'mixed');
      final migratedUnbound = accounts.singleWhere((a) => a.id == 'unbound');
      expect(
        migratedMixed.businessProviderId,
        isNot(migratedUnbound.businessProviderId),
      );
      final records = await store.servers();
      expect(records.singleWhere((s) => s.id == 'unknown').providerId, isNull);
      expect(
        records.singleWhere((s) => s.id == 'consistent').providerId,
        records.singleWhere((s) => s.id == 'manual').providerId,
      );
      expect(
        accounts.singleWhere((a) => a.id == 'single').pinnedServerId,
        'consistent',
      );
      expect(
        records
            .where((s) => s.id.startsWith('mixed'))
            .every((s) => s.providerId == migratedMixed.businessProviderId),
        isTrue,
      );
      await expectLater(
        store.importCloudInstances(
          CloudInventory(account: migratedMixed, snapshot: snapshot()),
          selectedInstanceKeys: {'7/2/3'},
        ),
        throwsA(isA<CloudAccountFailure>()),
      );
      final target = providers.singleWhere((p) => !p.needsReview);
      final stale = await store.serverCloudBindingOptions('mixed-a');
      await store.confirmAdapterProvider(migratedMixed, target);
      expect(
        (await store.cloudAccounts())
            .singleWhere((a) => a.id == 'mixed')
            .businessProviderId,
        target.id,
      );
      expect(
        (await store.cloudBindings()).where((b) => b.accountId == 'mixed'),
        hasLength(2),
      );
      await expectLater(
        store.setServerCloudBinding(stale),
        throwsA(isA<LedgerConflict>()),
      );
    },
  );

  test('ambiguous legacy V1 migration rolls back schema and retains every relationship', () async {
    await device('a');
    await device('b');
    await adapter('single', v1: true);
    await bind('a', 'single');
    final db = await raw();
    await removeProviderSchema(db);
    final observation = (await db.query('cloud_observations')).single;
    await db.insert('cloud_observations', {
      ...observation,
      'instance_key': 'ambiguous',
    });
    await db.insert('cloud_bindings', {
      'server_id': 'b',
      'account_id': 'single',
      'instance_key': 'ambiguous',
    });
    await db.setVersion(9);
    final original = await db.query('cloud_bindings');
    await store.close();
    await expectLater(
      LedgerStore.open(factory: databaseFactoryFfiNoIsolate, path: path),
      throwsA(anything),
    );
    final unchanged = await databaseFactoryFfiNoIsolate.openDatabase(path);
    expect(await unchanged.getVersion(), 9);
    expect(await unchanged.query('cloud_bindings'), original);
    expect(
      await unchanged.rawQuery(
        "SELECT name FROM sqlite_master WHERE name='providers'",
      ),
      isEmpty,
    );
    expect(
      (await unchanged.rawQuery('PRAGMA table_info(servers)'))
          .any((c) => c['name'] == 'provider_id'),
      isFalse,
    );
    // Remove only the synthetic corrupt row to allow ordinary teardown.
    await unchanged.delete(
      'cloud_bindings',
      where: 'server_id = ?',
      whereArgs: ['b'],
    );
    await unchanged.delete(
      'cloud_observations',
      where: 'instance_key = ?',
      whereArgs: ['ambiguous'],
    );
    await unchanged.close();
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
    );
  });

  test(
    'ledger-only restore cannot recreate provider or adapter associations',
    () async {
      await device('local');
      final backup = await store.exportLedgerBackup();
      final encoded = backup.encode();
      expect(encoded, isNot(contains('provider_id')));
      expect(encoded, isNot(contains('secret_ref')));
      final target = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${directory.path}/restore.sqlite',
      );
      try {
        await target.saveProvider(testProvider, isNew: true);
        final data = snapshot();
        final account = CloudAccount(
          id: 'target-adapter',
          provider: data.provider,
          businessProviderId: testProvider.id,
          authScope: AdapterAuthScope.account,
          alias: 'Saved adapter',
          endpoint: 'https://panel.example',
          secretRef: 'opaque-target',
          remoteAccountId: 7,
          createdAt: cloudTestTime,
        );
        await target.reserveSecret(account.secretRef);
        await target.saveCloudAccount(
          account: account,
          snapshot: data,
          expected: null,
        );
        await target.restoreLedgerBackup(LedgerBackupSnapshot.decode(encoded));
        expect((await target.servers()).single.providerId, isNull);
        expect((await target.servers()).single.vendor, testProvider.name);
        expect(await target.cloudAccounts(), hasLength(1));
        expect(await target.cloudBindings(), isEmpty);
      } finally {
        await target.close();
      }
    },
  );
}
