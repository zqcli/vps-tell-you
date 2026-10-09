import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

import 'cloud_controller_test.dart'
    show CloudTestSecrets, CallbackCloudAdapter, ReloadFailCloudController;
import 'cloud_store_test.dart' show snapshot, cloudTestTime, completedResources;
import 'support/provider_fixture.dart';

class HookImportController extends ReloadFailCloudController {
  HookImportController({
    required super.store,
    required super.secrets,
    required super.adapterFactory,
  });
  Future<void> Function(CloudImportItemResult)? afterItem;
  @override
  Future<CloudImportItemResult> importDraft(
    CloudInventory inventory,
    CloudImportDraft draft,
    CloudCancellation cancellation,
  ) async {
    final result = await super.importDraft(inventory, draft, cancellation);
    await afterItem?.call(result);
    return result;
  }
}

CloudSnapshot inventoryData({
  List<int> ids = const [1, 2, 3],
  int user = 7,
  String uuidPrefix = 'uuid',
}) => CloudSnapshot(
  provider: CloudProvider.solusVm2,
  remoteAccountId: user,
  completedAt: cloudTestTime,
  instances: [
    for (final id in ids)
      snapshot(
        user: user,
        server: id,
        uuid: '$uuidPrefix-$id',
      ).instances.single,
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  late LedgerStore store;
  late HookImportController cloud;
  late CloudTestSecrets secrets;
  late CloudSnapshot data;
  var reads = 0;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('adapter-batch-');
    path = '${directory.path}/ledger.sqlite';
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => cloudTestTime,
    );
    await addTestProvider(store);
    secrets = CloudTestSecrets();
    data = inventoryData();
    reads = 0;
    cloud = HookImportController(
      store: store,
      secrets: secrets,
      adapterFactory: (_, _, _) => CallbackCloudAdapter((_) async {
        reads++;
        return data;
      }),
    );
    await cloud.initialize();
  });
  tearDown(() async {
    cloud.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });
  Future<Database> raw() => databaseFactoryFfiNoIsolate.openDatabase(path);
  Future<CloudInventory> save({
    String endpoint = 'https://panel.example',
    ProviderRecord? provider,
  }) async {
    final verified = (await cloud.verifyConnection(
      provider: CloudProvider.solusVm2,
      businessProvider: provider ?? testProvider,
      endpoint: endpoint,
      credentials: SolusVm2Credentials('synthetic-token'),
    ))!;
    expect(await cloud.saveAccount(verified, alias: 'Fixture adapter'), isTrue);
    expect(verified.isCommitted, isTrue);
    return cloud.lastSavedInventory!;
  }

  List<CloudImportDraft> drafts(CloudInventory inventory) => [
    for (final item in inventory.snapshot.instances)
      CloudImportDraft(
        instanceKey: inventory.keyFor(item),
        resources: resourcesFromCloud(item),
      ),
  ];

  Future<CloudVerification> verifyAnonymous(
    CloudProvider type, {
    CloudAccount? existing,
    ProviderRecord? provider,
  }) async {
    final resources = completedResources();
    data = CloudSnapshot(
      provider: type,
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
    final verified = await cloud.verifyConnection(
      provider: type,
      businessProvider: provider ?? testProvider,
      endpoint: 'https://single-panel.example',
      credentials: type == CloudProvider.solusVm1
          ? SolusVm1Credentials(key: 'synthetic-key', hash: 'synthetic-hash')
          : RackNerdCredentials(key: 'synthetic-key', hash: 'synthetic-hash'),
      existing: existing,
    );
    expect(verified, isNotNull);
    return verified!;
  }

  Future<CloudInventory> saveAnonymous(
    CloudProvider type, {
    ProviderRecord? provider,
  }) async {
    final verified = await verifyAnonymous(type, provider: provider);
    expect(
      await cloud.saveAccount(verified, alias: 'Anonymous ${type.name}'),
      isTrue,
    );
    return cloud.lastSavedInventory!;
  }

  List<CloudImportDraft> completedAnonymousDrafts(CloudInventory inventory) => [
    CloudImportDraft(
      instanceKey: inventory.keyFor(inventory.snapshot.instances.single),
      resources: completedResources(),
    ),
  ];

  for (final type in [CloudProvider.solusVm1, CloudProvider.rackNerd]) {
    test(
      '${type.name}: single-device scope and incomplete CPU batch retry retain one authority',
      () async {
        final inventory = await saveAnonymous(type);
        expect(inventory.account.businessProviderId, testProvider.id);
        expect(inventory.account.authScope, AdapterAuthScope.singleDevice);
        expect(inventory.account.remoteAccountId, isNull);
        expect(inventory.account.pinnedServerId, isNull);
        final item = inventory.snapshot.instances.single;
        expect(item.projectId, isNull);
        expect(item.serverId, isNull);
        expect(item.uuid, isNull);
        expect(inventory.keyFor(item), 'single');
        expect(resourcesFromCloud(item).vcpu, isNull);
        final db = await raw();
        final observations = await db.query('cloud_observations');
        final incomplete = (await cloud.importBatch(
          inventory,
          drafts(inventory),
        ))!;
        expect(incomplete.importedCount, 0);
        expect(incomplete.failures.keys, ['single']);
        expect(incomplete.retryKeys, {'single'});
        expect(incomplete.unprocessed, isEmpty);
        expect(incomplete.interruption, isNull);
        expect(await store.servers(), isEmpty);
        expect(cloud.accounts.single.pinnedServerId, isNull);

        final completed = completedAnonymousDrafts(inventory);
        final result = (await cloud.importBatch(inventory, completed))!;
        expect(result.importedCount, 1);
        expect(result.complete, isTrue);
        final server = (await store.servers()).single;
        expect(server.providerId, testProvider.id);
        expect(server.vendor, testProvider.name);
        expect(server.name, 'Anonymous ${type.name}');
        expect(server.resources!.vcpu, 2);
        expect(server.resources!.apiFields, {
          'ip',
          'hostname',
          'ramBytes',
          'diskBytes',
          'trafficBytes',
        });
        expect(cloud.accounts.single.pinnedServerId, server.id);
        expect(cloud.bindings.single.instanceKey, 'single');
        expect(await db.query('cloud_observations'), observations);
        expect(
          (await cloud.importBatch(inventory, completed))!.existingCount,
          1,
        );
        expect(await store.servers(), hasLength(1));
        expect(await store.cloudAccounts(), hasLength(1));
        expect(secrets.writes, 1);
        expect(reads, 1);
      },
    );

    test(
      '${type.name}: unlink and restart do not free the anonymous pin for another device',
      () async {
        final inventory = await saveAnonymous(type);
        expect(
          (await cloud.importBatch(
            inventory,
            completedAnonymousDrafts(inventory),
          ))!.importedCount,
          1,
        );
        final first = (await store.servers()).single;
        final firstMap = first.toMap();
        expect(
          await cloud.setServerBinding(
            await store.serverCloudBindingOptions(first.id),
          ),
          isTrue,
        );
        expect(cloud.bindings, isEmpty);
        expect(cloud.accounts.single.pinnedServerId, first.id);

        cloud.dispose();
        await store.close();
        store = await LedgerStore.open(
          factory: databaseFactoryFfiNoIsolate,
          path: path,
          clock: () => cloudTestTime,
        );
        cloud = HookImportController(
          store: store,
          secrets: secrets,
          adapterFactory: (_, _, _) => CallbackCloudAdapter((_) async {
            reads++;
            return data;
          }),
        );
        expect(await cloud.initialize(), isTrue);
        expect(reads, 1);
        expect(cloud.accounts.single.pinnedServerId, first.id);
        final refreshed = (await cloud.refreshAccount(cloud.accounts.single))!;
        final rejected = (await cloud.importBatch(
          refreshed,
          completedAnonymousDrafts(refreshed),
        ))!;
        expect(rejected.importedCount, 0);
        expect(rejected.failures.keys, ['single']);
        expect(rejected.interruption, isNotNull);
        expect(await store.servers(), hasLength(1));
        expect(cloud.accounts.single.pinnedServerId, first.id);

        final other = ServerRecord(
          id: 'other-device',
          name: 'Same address is not identity',
          vendor: testProvider.name,
          providerId: testProvider.id,
          host: first.host,
          createdAt: cloudTestTime,
          updatedAt: cloudTestTime,
        );
        await store.saveServer(other, isNew: true);
        final options = await store.serverCloudBindingOptions(other.id);
        expect(
          await cloud.setServerBinding(options, choice: options.choices.single),
          isFalse,
        );
        expect(await store.cloudBindings(), isEmpty);
        expect((await store.cloudAccounts()).single.pinnedServerId, first.id);
        expect(
          (await store.servers()).singleWhere((s) => s.id == first.id).toMap(),
          firstMap,
        );
        expect(reads, 2);
        expect(secrets.writes, 1);
      },
    );

    test(
      '${type.name}: distinct anonymous instances never share V2-style duplicate identity',
      () async {
        final first = await saveAnonymous(type);
        await cloud.importBatch(first, completedAnonymousDrafts(first));
        final firstServer = (await store.servers()).single;
        final second = await saveAnonymous(type);
        expect(second.account.id, isNot(first.account.id));
        expect(
          cloud.matchingDevices(
            type: type,
            endpoint: second.account.endpoint,
            remoteAccountId: null,
            instanceKey: 'single',
            accountId: second.account.id,
          ),
          isEmpty,
        );
        expect(
          (await cloud.importBatch(
            second,
            completedAnonymousDrafts(second),
          ))!.importedCount,
          1,
        );
        expect(await store.servers(), hasLength(2));
        expect(cloud.bindings, hasLength(2));
        expect((await store.servers()).map((s) => s.host).toSet(), {
          firstServer.host,
        });
        expect(
          cloud.accounts
              .singleWhere((a) => a.id == first.account.id)
              .pinnedServerId,
          firstServer.id,
        );
        expect(
          cloud.accounts
              .singleWhere((a) => a.id == second.account.id)
              .pinnedServerId,
          cloud.bindings
              .singleWhere((b) => b.accountId == second.account.id)
              .serverId,
        );
        expect(secrets.writes, 2);
        expect(reads, 2);
      },
    );

    test(
      '${type.name}: anonymous instances retain separate business-provider ownership',
      () async {
        final first = await saveAnonymous(type);
        await cloud.importBatch(first, completedAnonymousDrafts(first));
        final original = (await store.servers()).single.toMap();
        final other = ProviderRecord(
          id: 'other-vendor',
          name: 'Other local vendor',
          createdAt: cloudTestTime,
        );
        await store.saveProvider(other, isNew: true);
        final second = await saveAnonymous(type, provider: other);
        final result = (await cloud.importBatch(
          second,
          completedAnonymousDrafts(second),
        ))!;
        expect(result.importedCount, 1);
        expect(result.existingCount, 0);
        expect(await store.servers(), hasLength(2));
        expect(
          (await store.servers())
              .singleWhere((s) => s.id == original['id'])
              .toMap(),
          original,
        );
        final created = (await store.servers()).singleWhere(
          (s) => s.id == result.items.single.serverIds.single,
        );
        expect(created.providerId, other.id);
        expect(created.vendor, other.name);
        expect(
          cloud.accounts
              .singleWhere((a) => a.id == first.account.id)
              .businessProviderId,
          testProvider.id,
        );
        expect(
          cloud.accounts
              .singleWhere((a) => a.id == second.account.id)
              .businessProviderId,
          other.id,
        );
      },
    );

    test(
      '${type.name}: explicit reauthorization resets only its pin and fences the old batch',
      () async {
        final first = await saveAnonymous(type);
        await cloud.importBatch(first, completedAnonymousDrafts(first));
        final original = (await store.servers()).single.toMap();
        final account = cloud.accounts.single;
        final oldSecret = account.secretRef;
        final verified = await verifyAnonymous(type, existing: account);
        expect(await cloud.saveAccount(verified, alias: 'New epoch'), isFalse);
        expect(cloud.error, CloudAccountFailure.v1Rebind.message);
        expect(secrets.writes, 1);
        expect(
          (await store.cloudAccounts()).single.pinnedServerId,
          original['id'],
        );
        expect((await store.cloudBindings()).single.serverId, original['id']);
        expect(
          await cloud.saveAccount(
            verified,
            alias: 'New epoch',
            confirmV1Rebind: true,
          ),
          isTrue,
        );
        final replacement = cloud.lastSavedInventory!;
        expect(replacement.account.authScope, AdapterAuthScope.singleDevice);
        expect(replacement.account.businessProviderId, testProvider.id);
        expect(cloud.accounts.single.pinnedServerId, isNull);
        expect(cloud.bindings, isEmpty);
        expect(cloud.accounts.single.secretRef, isNot(oldSecret));
        expect(secrets.values.containsKey(oldSecret), isFalse);
        expect((await store.servers()).single.toMap(), original);

        final stale = (await cloud.importBatch(
          first,
          completedAnonymousDrafts(first),
        ))!;
        expect(stale.importedCount, 0);
        expect(stale.interruption, isNotNull);
        expect(await store.servers(), hasLength(1));
        final current = (await cloud.importBatch(
          replacement,
          completedAnonymousDrafts(replacement),
        ))!;
        expect(current.importedCount, 1);
        expect(await store.servers(), hasLength(2));
        expect(
          cloud.accounts.single.pinnedServerId,
          current.items.single.serverIds.single,
        );
        expect(cloud.accounts.single.pinnedServerId, isNot(original['id']));
        expect(
          (await store.servers())
              .singleWhere((s) => s.id == original['id'])
              .toMap(),
          original,
        );
        expect(secrets.writes, 2);
        expect(reads, 2);
      },
    );

    test(
      '${type.name}: duplicate and forged anonymous selections cannot create rows or pins',
      () async {
        final inventory = await saveAnonymous(type);
        final selected = completedAnonymousDrafts(inventory).single;
        expect(
          await cloud.importBatch(inventory, [selected, selected]),
          isNull,
        );
        expect(await store.servers(), isEmpty);
        final invalid = (await cloud.importBatch(inventory, [
          CloudImportDraft(
            instanceKey: '7/2/1',
            resources: completedResources(),
          ),
        ]))!;
        expect(invalid.importedCount, 0);
        expect(invalid.failures.keys, ['7/2/1']);
        expect(invalid.interruption, isNotNull);
        expect(await store.servers(), isEmpty);
        expect(await store.cloudBindings(), isEmpty);
        expect(await store.reminderRules(), isEmpty);
        expect(cloud.accounts.single.pinnedServerId, isNull);
        expect(secrets.writes, 1);
        expect(reads, 1);
      },
    );
  }

  test('save instance once, import two valid rows, complete only failed draft on retry', () async {
    final inventory = await save();
    final original = drafts(inventory);
    final selected = [
      original[0],
      CloudImportDraft(
        instanceKey: original[1].instanceKey,
        resources: ServerResources(),
      ),
      original[2],
    ];
    final result = (await cloud.importBatch(inventory, selected))!;
    expect(result.importedCount, 2);
    expect(result.failures.keys, [original[1].instanceKey]);
    expect(result.unprocessed, isEmpty);
    expect(result.interruption, isNull);
    expect(await store.servers(), hasLength(2));
    final retry = (await cloud.importBatch(inventory, [original[1]]))!;
    expect(retry.importedCount, 1);
    expect(retry.complete, isTrue);
    expect(await store.servers(), hasLength(3));
    expect(await store.cloudAccounts(), hasLength(1));
    expect(secrets.writes, 1);
    expect(reads, 1);
    expect((await cloud.importBatch(inventory, original))!.existingCount, 3);
    expect(await store.servers(), hasLength(3));
  });

  test('storage failure rolls back only its row and returns exact unfinished selection', () async {
    final inventory = await save();
    final selected = drafts(inventory);
    final chosen = [
      selected[0],
      CloudImportDraft(
        instanceKey: selected[1].instanceKey,
        resources: selected[1].resources,
        displayName: 'Fail this row',
      ),
      selected[2],
    ];
    final db = await raw();
    final observations = await db.query('cloud_observations');
    await db.execute(
      "CREATE TRIGGER abort_import BEFORE INSERT ON servers WHEN NEW.name='Fail this row' BEGIN SELECT RAISE(ABORT, 'synthetic storage failure'); END",
    );
    final result = (await cloud.importBatch(inventory, chosen))!;
    expect(result.importedCount, 1);
    expect(result.failures.keys, [selected[1].instanceKey]);
    expect(result.unprocessed, {selected[2].instanceKey});
    expect(result.interruption, isNotNull);
    expect(await store.servers(), hasLength(1));
    expect(await store.cloudBindings(), hasLength(1));
    expect(await store.reminderRules(), hasLength(1));
    final first = (await store.servers()).single.toMap();
    await db.execute('DROP TRIGGER abort_import');
    final retry = (await cloud.importBatch(
      inventory,
      chosen.where((d) => result.retryKeys.contains(d.instanceKey)).toList(),
    ))!;
    expect(retry.importedCount, 2);
    expect(retry.complete, isTrue);
    expect(await store.servers(), hasLength(3));
    expect(
      (await store.servers()).singleWhere((s) => s.id == first['id']).toMap(),
      first,
    );
    expect(await db.query('cloud_observations'), observations);
    expect(await store.reminderRules(), hasLength(3));
    expect(secrets.writes, 1);
    expect(reads, 1);
  });

  test('all imports may fail while instance stays saved and verification cannot be reused', () async {
    final verification = (await cloud.verifyConnection(
      provider: CloudProvider.solusVm2,
      businessProvider: testProvider,
      endpoint: 'https://panel.example',
      credentials: SolusVm2Credentials('synthetic-token'),
    ))!;
    expect(
      await cloud.saveAccount(verification, alias: 'Only instance'),
      isTrue,
    );
    final inventory = cloud.lastSavedInventory!;
    final result = (await cloud.importBatch(inventory, [
      for (final d in drafts(inventory))
        CloudImportDraft(
          instanceKey: d.instanceKey,
          resources: ServerResources(),
        ),
    ]))!;
    expect(result.importedCount, 0);
    expect(result.failures, hasLength(3));
    expect(await store.servers(), isEmpty);
    expect(await store.cloudAccounts(), hasLength(1));
    expect(verification.isCommitted, isTrue);
    expect(await cloud.saveAccount(verification, alias: 'Duplicate'), isFalse);
    expect(secrets.writes, 1);
  });

  test('cancellation between items keeps committed result and stops the remaining rows', () async {
    final inventory = await save();
    cloud.afterItem = (result) async {
      if (result.imported) cloud.cancelAccount(inventory.account.id);
    };
    final result = (await cloud.importBatch(inventory, drafts(inventory)))!;
    expect(result.importedCount, 1);
    expect(result.failures, hasLength(1));
    expect(result.unprocessed, hasLength(1));
    expect(result.retryKeys, hasLength(2));
    expect(await store.servers(), hasLength(1));
    expect(reads, 1);
    cloud.afterItem = null;
    expect(
      (await cloud.importBatch(
        inventory,
        drafts(inventory)
            .where((d) => result.retryKeys.contains(d.instanceKey))
            .toList(),
      ))!.importedCount,
      2,
    );
    expect(await store.servers(), hasLength(3));
  });

  test('newer authorization generation stops batch and cannot be bypassed by retry', () async {
    final inventory = await save();
    var changed = false;
    cloud.afterItem = (result) async {
      if (!changed) {
        changed = true;
        await store.beginCloudRead(inventory.account);
      }
    };
    final result = (await cloud.importBatch(inventory, drafts(inventory)))!;
    expect(result.importedCount, 1);
    expect(result.interruption, isNotNull);
    expect(result.retryKeys, hasLength(2));
    cloud.afterItem = null;
    final retry = (await cloud.importBatch(
      inventory,
      drafts(inventory)
          .where((d) => result.retryKeys.contains(d.instanceKey))
          .toList(),
    ))!;
    expect(retry.importedCount, 0);
    expect(retry.interruption, isNotNull);
    expect(await store.servers(), hasLength(1));
    expect(reads, 1);
  });

  test('changing provider during import cannot silently restore a removed association', () async {
    final inventory = await save();
    final other = ProviderRecord(
      id: 'other',
      name: 'Other',
      createdAt: cloudTestTime,
    );
    await store.saveProvider(other, isNew: true);
    cloud.afterItem = (result) async {
      final options = await store.serverCloudBindingOptions(
        result.serverIds.single,
      );
      await store.setServerProvider(options, other.id, confirmUnlink: true);
    };
    final result = (await cloud.importBatch(inventory, drafts(inventory)))!;
    expect(result.importedCount, 1);
    expect(result.interruption, isNotNull);
    expect(await store.cloudBindings(), isEmpty);
    expect((await store.servers()).single.providerId, other.id);
    expect(reads, 1);
  });

  test('same stable V2 identities across credentials include archived duplicates without relinking', () async {
    final first = await save();
    expect((await cloud.importBatch(first, drafts(first)))!.importedCount, 3);
    await store.archive((await store.servers()).first);
    final before = (await store.cloudBindings())
        .map((b) => (b.accountId, b.instanceKey, b.serverId))
        .toList();
    final second = await save();
    final result = (await cloud.importBatch(second, drafts(second)))!;
    expect(result.existingCount, 3);
    expect(result.importedCount, 0);
    expect(await store.servers(), hasLength(3));
    expect(await store.cloudAccounts(), hasLength(2));
    expect(
      (await store.cloudBindings())
          .map((b) => (b.accountId, b.instanceKey, b.serverId))
          .toList(),
      before,
    );
    expect(
      (await store.cloudAccounts()).map((a) => a.secretRef).toSet(),
      hasLength(2),
    );
  });

  test('conflicting nonempty remote UUID is rejected instead of falling back to IP', () async {
    data = inventoryData(ids: [1]);
    final first = await save();
    await cloud.importBatch(first, drafts(first));
    data = inventoryData(ids: [1], uuidPrefix: 'changed');
    final second = await save();
    final result = (await cloud.importBatch(second, drafts(second)))!;
    expect(result.importedCount, 0);
    expect(result.existingCount, 0);
    expect(result.interruption, isNotNull);
    expect(await store.servers(), hasLength(1));
    expect((await store.cloudBindings()).single.accountId, first.account.id);
  });

  test('same IP and name do not identify devices and separate authority namespaces stay distinct', () async {
    data = inventoryData(ids: [1, 2]);
    final first = await save();
    expect((await cloud.importBatch(first, drafts(first)))!.importedCount, 2);
    data = inventoryData(ids: [1], user: 8);
    final second = await save();
    expect((await cloud.importBatch(second, drafts(second)))!.importedCount, 1);
    data = inventoryData(ids: [1]);
    final third = await save(endpoint: 'https://different-panel.example');
    expect((await cloud.importBatch(third, drafts(third)))!.importedCount, 1);
    expect(await store.servers(), hasLength(4));
    expect((await store.servers()).map((s) => s.host).toSet(), hasLength(1));
  });

  test('cross-provider duplicate is reported without transferring device ownership', () async {
    data = inventoryData(ids: [1]);
    final first = await save();
    await cloud.importBatch(first, drafts(first));
    final original = (await store.servers()).single;
    final other = ProviderRecord(
      id: 'other',
      name: 'Other',
      createdAt: cloudTestTime,
    );
    await store.saveProvider(other, isNew: true);
    final second = await save(provider: other);
    final result = (await cloud.importBatch(second, drafts(second)))!;
    expect(result.existingCount, 1);
    expect(result.items.single.serverIds, [original.id]);
    expect((await store.servers()).single.providerId, testProvider.id);
    expect((await store.cloudBindings()).single.accountId, first.account.id);
  });

  test('legacy duplicate owners are all returned rather than silently choosing one', () async {
    data = inventoryData(ids: [1]);
    final first = await save();
    await cloud.importBatch(first, drafts(first));
    final second = await save();
    final db = await raw();
    final old = (await store.servers()).single;
    await db.insert('servers', {...old.toMap(), 'id': 'legacy-second'});
    await db.insert('cloud_bindings', {
      'server_id': 'legacy-second',
      'account_id': second.account.id,
      'instance_key': '7/2/1',
    });
    final third = await save();
    final result = (await cloud.importBatch(third, drafts(third)))!;
    expect(result.existingCount, 1);
    expect(result.items.single.serverIds.toSet(), {old.id, 'legacy-second'});
    expect(await store.servers(), hasLength(2));
  });

  test('UI display duplicate hints use stable identity, include all owners and preserve instance isolation', () async {
    data = inventoryData(ids: [1]);
    final first = await save();
    await cloud.importBatch(first, drafts(first));
    final second = await save();
    final matches = cloud.matchingDevices(
      type: second.account.provider,
      endpoint: second.account.endpoint,
      remoteAccountId: second.account.remoteAccountId,
      instanceKey: '7/2/1',
      accountId: second.account.id,
    );
    expect(matches, hasLength(1));
    expect(matches.single.accountId, first.account.id);
    expect(
      cloud.matchingDevices(
        type: CloudProvider.solusVm1,
        endpoint: second.account.endpoint,
        remoteAccountId: null,
        instanceKey: 'single',
      ),
      isEmpty,
    );
  });

  test('metadata reload failure retains exact import counts and blocks duplicate work until local reload', () async {
    final inventory = await save();
    cloud.failReload = true;
    final result = (await cloud.importBatch(inventory, drafts(inventory)))!;
    expect(result.importedCount, 3);
    expect(result.complete, isTrue);
    expect(cloud.needsReload, isTrue);
    expect(await cloud.importBatch(inventory, drafts(inventory)), isNull);
    expect(await store.servers(), hasLength(3));
    cloud.failReload = false;
    expect(await cloud.reload(), isTrue);
    expect(
      (await cloud.importBatch(inventory, drafts(inventory)))!.existingCount,
      3,
    );
  });

  test('saving an instance survives metadata reload failure without losing its resumable snapshot', () async {
    final verified = (await cloud.verifyConnection(
      provider: CloudProvider.solusVm2,
      businessProvider: testProvider,
      endpoint: 'https://panel.example',
      credentials: SolusVm2Credentials('synthetic-token'),
    ))!;
    cloud.failReload = true;
    expect(await cloud.saveAccount(verified, alias: 'Saved'), isTrue);
    expect(verified.isCommitted, isTrue);
    expect(cloud.lastSavedInventory, isNotNull);
    expect(cloud.needsReload, isTrue);
    expect(
      await cloud.importBatch(
        cloud.lastSavedInventory!,
        drafts(cloud.lastSavedInventory!),
      ),
      isNull,
    );
    expect(await store.servers(), isEmpty);
    cloud.failReload = false;
    await cloud.reload();
    expect(
      (await cloud.importBatch(
        cloud.lastSavedInventory!,
        drafts(cloud.lastSavedInventory!),
      ))!.importedCount,
      3,
    );
    expect(secrets.writes, 1);
  });

  test('duplicate keys and stale selections cannot create orphan rows or reminders', () async {
    final inventory = await save();
    final selected = drafts(inventory);
    expect(
      await cloud.importBatch(inventory, [selected[0], selected[0]]),
      isNull,
    );
    expect(await store.servers(), isEmpty);
    final result = (await cloud.importBatch(inventory, [
      CloudImportDraft(
        instanceKey: '7/2/999',
        resources: selected[0].resources,
      ),
    ]))!;
    expect(result.interruption, isNotNull);
    expect(await store.servers(), isEmpty);
    expect(await store.reminderRules(), isEmpty);
  });

  test('local completion persists accurate sources and never changes observations or finances', () async {
    data = CloudSnapshot(
      provider: CloudProvider.solusVm2,
      remoteAccountId: 7,
      completedAt: cloudTestTime,
      instances: [
        CloudInstance(
          observedAt: cloudTestTime,
          power: CloudPower.unknown,
          projectId: 2,
          serverId: 1,
          ipv4: '192.0.2.40',
          vcpu: 2,
          ramBytes: 0,
          diskBytes: 0,
          trafficBytes: 0,
        ),
      ],
    );
    final inventory = await save();
    final db = await raw();
    final before = await db.query('cloud_observations');
    final completion = completedResources();
    expect(
      (await cloud.importBatch(inventory, [
        CloudImportDraft(instanceKey: '7/2/1', resources: completion),
      ]))!.importedCount,
      1,
    );
    final server = (await store.servers()).single;
    expect(server.resources!.apiFields, {'ip'});
    expect(server.resources!.ramBytes, completion.ramBytes);
    expect(server.billing, BillingKind.unknown);
    expect(server.amountMinor, isNull);
    expect(await store.payments(), isEmpty);
    expect(await store.sshConfigurations(), isEmpty);
    expect(await db.query('cloud_observations'), before);
  });

  test('resource projection treats zeros, invalid IP/hostname and missing quotas as unknown', () {
    final item = CloudInstance(
      observedAt: cloudTestTime,
      power: CloudPower.unknown,
      ipv4: '0.0.0.0',
      hostname: '0',
      vcpu: 0,
      ramBytes: 0,
      diskBytes: 0,
      trafficBytes: 0,
      diskGiB: 2.5,
    );
    final resource = resourcesFromCloud(item);
    expect(resource.ip, isEmpty);
    expect(resource.hostname, isEmpty);
    expect(resource.vcpu, isNull);
    expect(resource.ramBytes, isNull);
    expect(resource.diskBytes, 2684354560);
    expect(resource.trafficBytes, isNull);
    expect(resource.trafficUnlimited, isFalse);
    expect(resource.validate(requireComplete: true), isNotNull);
    expect(resource.apiFields, {'diskBytes'});
  });
}
