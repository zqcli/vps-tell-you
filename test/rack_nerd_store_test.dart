import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_account.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

import 'cloud_store_test.dart' show cloudTestTime, completedResources;

CloudSnapshot _rackSnapshot({
  DateTime? at,
  CloudPower power = CloudPower.running,
  List<CloudInstance>? instances,
  int? remoteAccountId,
}) => CloudSnapshot(
  provider: CloudProvider.rackNerd,
  completedAt: at ?? cloudTestTime,
  remoteAccountId: remoteAccountId,
  instances:
      instances ??
      [
        CloudInstance(
          observedAt: at ?? cloudTestTime,
          power: power,
          hostname: 'vps.synthetic.example',
          ipv4: '192.0.2.40',
          ramBytes: 2147483648,
          diskBytes: 32212254720,
          trafficBytes: 1099511627776,
          trafficUsedBytes: 1024,
        ),
      ],
);

ServerResources _missingResource(String field) {
  final complete = completedResources();
  return ServerResources(
    ip: field == 'ip' ? '' : complete.ip,
    hostname: field == 'hostname' ? '' : complete.hostname,
    vcpu: field == 'vcpu' ? null : complete.vcpu,
    ramBytes: field == 'ramBytes' ? null : complete.ramBytes,
    diskBytes: field == 'diskBytes' ? null : complete.diskBytes,
    trafficBytes: field == 'trafficBytes' ? null : complete.trafficBytes,
    apiFields: complete.apiFields.difference({field}),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  late LedgerStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('rack-store-synthetic-');
    path = '${directory.path}/ledger.sqlite';
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => cloudTestTime,
    );
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });
  Future<Database> raw() => databaseFactoryFfiNoIsolate.openDatabase(path);
  CloudAccount account(String id, {String? secretRef}) => CloudAccount(
    id: id,
    provider: CloudProvider.rackNerd,
    alias: 'Synthetic panel $id',
    endpoint: 'https://panel.synthetic.example',
    secretRef: secretRef ?? 'opaque-synthetic-$id-reference',
    createdAt: cloudTestTime,
  );
  Future<CloudAccount> add(String id, {bool import = true}) async {
    final connection = account(id);
    await store.reserveSecret(connection.secretRef);
    await store.saveCloudAccount(
      account: connection,
      snapshot: _rackSnapshot(),
      expected: null,
      selectedInstanceKeys: import ? {'single'} : {},
      v1DisplayName: 'Synthetic local VPS',
      v1Resources: import ? completedResources() : null,
    );
    return (await store.cloudAccounts()).singleWhere((row) => row.id == id);
  }

  Future<Map<String, List<Map<String, Object?>>>> rows(
    List<String> tables,
  ) async {
    final db = await raw();
    return {
      for (final table in tables)
        table: await db.query(table, orderBy: 'rowid'),
    };
  }

  test('RackNerd account-only save retains anonymous identity and defers completion', () async {
    final connection = await add('account-only', import: false);
    expect(connection.provider.name, 'rackNerd');
    expect(connection.provider.isSingleInstance, isTrue);
    expect(connection.remoteAccountId, isNull);
    expect(await store.servers(), isEmpty);
    final db = await raw();
    final observation = (await db.query('cloud_observations')).single;
    expect(observation['instance_key'], 'single');
    expect(observation['identity_uuid'], isNull);
    final instance = decodeCloudInstance(observation['observation']! as String);
    expect(instance.projectId, isNull);
    expect(instance.serverId, isNull);
    expect(instance.uuid, isNull);
    expect(instance.vcpu, isNull);
    final inventory = CloudInventory(
      account: connection,
      snapshot: _rackSnapshot(),
    );
    await expectLater(
      store.importCloudInstances(inventory, selectedInstanceKeys: {'single'}),
      throwsA(isA<CloudAccountFailure>()),
    );
    expect(await store.servers(), isEmpty);
    expect(
      await store.importCloudInstances(
        inventory,
        selectedInstanceKeys: {'single'},
        v1DisplayName: 'Reviewed name',
        v1Resources: completedResources(unlimited: true),
      ),
      1,
    );
    final server = (await store.servers()).single;
    expect(server.name, 'Reviewed name');
    expect(server.resources!.trafficUnlimited, isTrue);
    expect(
      server.resources!.toJson(),
      completedResources(unlimited: true).toJson(),
    );
    expect(server.vendor, '服务商待填写');
    expect(server.billing, BillingKind.unknown);
    expect(server.amountMinor, isNull);
    expect(
      await store.importCloudInstances(
        inventory,
        selectedInstanceKeys: {'single'},
      ),
      0,
    );
    expect((await store.servers()).single.toMap(), server.toMap());
    await store.close();
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => cloudTestTime,
    );
    expect((await store.cloudAccounts()).single.toMap(), connection.toMap());
    expect((await store.servers()).single.toMap(), server.toMap());
    expect((await store.cloudBindings()).single.instanceKey, 'single');
  });

  for (final field in ServerResources.fieldKeys) {
    test(
      'fresh and deferred RackNerd import require completed $field',
      () async {
        final connection = account('incomplete');
        await store.reserveSecret(connection.secretRef);
        await expectLater(
          store.saveCloudAccount(
            account: connection,
            snapshot: _rackSnapshot(),
            expected: null,
            selectedInstanceKeys: {'single'},
            v1Resources: _missingResource(field),
          ),
          throwsA(isA<CloudAccountFailure>()),
        );
        expect(await store.cloudAccounts(), isEmpty);
        expect(await store.servers(), isEmpty);
        expect(await store.cloudBindings(), isEmpty);
        expect(await store.pendingSecretCleanup(), [connection.secretRef]);
        await store.saveCloudAccount(
          account: connection,
          snapshot: _rackSnapshot(),
          expected: null,
        );
        final saved = (await store.cloudAccounts()).single;
        await expectLater(
          store.importCloudInstances(
            CloudInventory(account: saved, snapshot: _rackSnapshot()),
            selectedInstanceKeys: {'single'},
            v1Resources: _missingResource(field),
          ),
          throwsA(isA<CloudAccountFailure>()),
        );
        expect(await store.servers(), isEmpty);
        expect(await store.cloudBindings(), isEmpty);
        expect(await store.pendingSecretCleanup(), isEmpty);
      },
    );
  }

  test('empty, duplicate and fabricated stable RackNerd identities are rejected atomically', () async {
    final connection = account('identity');
    await store.reserveSecret(connection.secretRef);
    final anonymous = _rackSnapshot().instances.single;
    for (final invalid in [
      _rackSnapshot(instances: []),
      _rackSnapshot(instances: [anonymous, anonymous]),
      _rackSnapshot(remoteAccountId: 7),
      _rackSnapshot(
        instances: [
          CloudInstance(
            observedAt: cloudTestTime,
            power: CloudPower.running,
            projectId: 2,
          ),
        ],
      ),
      _rackSnapshot(
        instances: [
          CloudInstance(
            observedAt: cloudTestTime,
            power: CloudPower.running,
            serverId: 3,
          ),
        ],
      ),
      _rackSnapshot(
        instances: [
          CloudInstance(
            observedAt: cloudTestTime,
            power: CloudPower.running,
            uuid: 'fabricated-synthetic-uuid',
          ),
        ],
      ),
    ]) {
      await expectLater(
        store.saveCloudAccount(
          account: connection,
          snapshot: invalid,
          expected: null,
        ),
        throwsA(anyOf(isA<CloudFailure>(), isA<CloudAccountFailure>())),
      );
      expect(await store.cloudAccounts(), isEmpty);
      expect(await store.servers(), isEmpty);
      expect(await (await raw()).query('cloud_observations'), isEmpty);
      expect(await store.pendingSecretCleanup(), [connection.secretRef]);
    }
  });

  test('explicit RackNerd reauthorization detaches only cloud links and preserves ledger, costs and SSH', () async {
    var connection = await add('first');
    await add('second');
    expect(await store.servers(), hasLength(2));
    expect(await store.cloudBindings(), hasLength(2));
    final oldServerId = (await store.cloudBindings())
        .singleWhere((binding) => binding.accountId == connection.id)
        .serverId;
    final original = (await store.servers()).singleWhere(
      (s) => s.id == oldServerId,
    );
    await store.saveServer(
      ServerRecord.fromMap({
        ...original.toMap(),
        'name': 'User reviewed name',
        'notes': 'Local synthetic notes',
        'billing': 'prepaid',
        'amount_minor': 1200,
        'cycle_months': 1,
        'start_date': '2026-10-01',
        'due_date': '2026-11-01',
      }),
      isNew: false,
    );
    await store.recordPayment(
      id: 'synthetic-server-payment',
      server: (await store.servers()).singleWhere((s) => s.id == oldServerId),
      amount: const Money('USD', 1200),
      paidDate: const LedgerDate(2026, 10, 6),
      cycleCount: 1,
      until: const LedgerDate(2026, 12, 1),
      confirmed: true,
      note: 'Local synthetic payment note',
    );
    await store.saveSshConfiguration(
      SshConfiguration(
        serverId: oldServerId,
        host: 'ssh.synthetic.example',
        port: 2222,
        username: 'local',
        revision: -1,
      ),
    );
    connection = await store.beginCloudRead(connection);
    final replacement = account(
      'first',
      secretRef: 'opaque-synthetic-replacement',
    );
    await store.reserveSecret(replacement.secretRef);
    const protectedTables = [
      'servers',
      'payments',
      'service_periods',
      'ssh_configurations',
      'credentials',
      'reminder_rules',
    ];
    final localBefore = await rows(protectedTables);
    final allBefore = await rows([
      ...protectedTables,
      'cloud_accounts',
      'cloud_observations',
      'cloud_bindings',
      'secret_cleanup',
    ]);
    await expectLater(
      store.saveCloudAccount(
        account: replacement,
        snapshot: _rackSnapshot(),
        expected: connection,
      ),
      throwsA(same(CloudAccountFailure.v1Rebind)),
    );
    expect(await rows(allBefore.keys.toList()), allBefore);
    await expectLater(
      store.saveCloudAccount(
        account: replacement,
        snapshot: _rackSnapshot(),
        expected: connection,
        confirmV1Rebind: true,
        selectedInstanceKeys: {'not-present'},
      ),
      throwsA(same(CloudAccountFailure.selection)),
    );
    expect(await rows(allBefore.keys.toList()), allBefore);
    var checks = 0;
    await expectLater(
      store.saveCloudAccount(
        account: replacement,
        snapshot: _rackSnapshot(),
        expected: connection,
        confirmV1Rebind: true,
        isCancelled: () => ++checks > 1,
      ),
      throwsA(isA<CloudFailure>()),
    );
    expect(await rows(allBefore.keys.toList()), allBefore);
    expect(
      await store.saveCloudAccount(
        account: replacement,
        snapshot: _rackSnapshot(),
        expected: connection,
        confirmV1Rebind: true,
      ),
      0,
    );
    expect(await rows(protectedTables), localBefore);
    expect(await store.cloudBindings(), hasLength(1));
    expect((await store.cloudBindings()).single.accountId, 'second');
    expect(await store.pendingSecretCleanup(), [connection.secretRef]);
    expect(await store.secretIsReferenced(connection.secretRef), isFalse);
    expect(await store.secretIsReferenced(replacement.secretRef), isTrue);
    await expectLater(
      store.importCloudInstances(
        CloudInventory(account: connection, snapshot: _rackSnapshot()),
        selectedInstanceKeys: {'single'},
        v1Resources: completedResources(),
      ),
      throwsA(isA<LedgerConflict>()),
    );
    await store.close();
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => cloudTestTime,
    );
    expect(await rows(protectedTables), localBefore);
    final reauthorized = (await store.cloudAccounts()).singleWhere(
      (a) => a.id == 'first',
    );
    expect(reauthorized.remoteAccountId, isNull);
    expect(reauthorized.secretRef, replacement.secretRef);
    expect(reauthorized.revision, connection.revision + 1);
    expect(reauthorized.generation, connection.generation + 1);
    expect(
      await store.importCloudInstances(
        CloudInventory(account: reauthorized, snapshot: _rackSnapshot()),
        selectedInstanceKeys: {'single'},
        v1DisplayName: 'New reviewed record',
        v1Resources: completedResources(unlimited: true),
      ),
      1,
    );
    final newServerId = (await store.cloudBindings())
        .singleWhere((binding) => binding.accountId == 'first')
        .serverId;
    expect(newServerId, isNot(oldServerId));
    expect(
      (await store.servers()).singleWhere((s) => s.id == oldServerId).toMap(),
      localBefore['servers']!.singleWhere((row) => row['id'] == oldServerId),
    );
    for (final table in [
      'payments',
      'service_periods',
      'ssh_configurations',
      'credentials',
    ]) {
      expect((await rows([table]))[table], localBefore[table], reason: table);
    }
  });

  test('RackNerd refresh, failure, local association and unlink never overwrite local resources', () async {
    var connection = await add('read-only');
    final server = (await store.servers()).single;
    final before = server.toMap();
    connection = await store.beginCloudRead(connection);
    await store.commitCloudSnapshot(
      connection,
      _rackSnapshot(
        at: cloudTestTime.add(const Duration(hours: 1)),
        power: CloudPower.stopped,
      ),
    );
    expect((await store.servers()).single.toMap(), before);
    expect((await store.cloudBindings()).single.power, CloudPower.stopped);
    connection = await store.beginCloudRead(connection);
    await store.recordCloudFailure(connection, CloudFailureKind.timeout);
    expect((await store.cloudBindings()).single.stale, isTrue);
    expect((await store.servers()).single.toMap(), before);
    connection = await store.beginCloudRead(connection);
    await store.commitCloudSnapshot(connection, _rackSnapshot());
    final options = await store.serverCloudBindingOptions(server.id);
    await store.setServerCloudBinding(options);
    expect(await store.cloudBindings(), isEmpty);
    final unbound = await store.serverCloudBindingOptions(server.id);
    expect(unbound.accounts.single.provider, CloudProvider.rackNerd);
    expect(unbound.choices.single.instanceKey, 'single');
    await store.setServerCloudBinding(unbound, choice: unbound.choices.single);
    expect((await store.cloudBindings()).single.instanceKey, 'single');
    expect((await store.servers()).single.toMap(), before);
    await store.unbindCloudAccount((await store.cloudAccounts()).single);
    expect(await store.cloudBindings(), isEmpty);
    expect((await store.servers()).single.toMap(), before);
  });

  test(
    'RackNerd remains excluded from ledger-only JSON backup format v1',
    () async {
      final connection = await add('not-a-backup-account');
      final source = (await store.exportLedgerBackup()).encode();
      final decoded = jsonDecode(source) as Map<String, dynamic>;
      expect(decoded['format'], 'vps-tell-you-ledger');
      expect(decoded['version'], 1);
      expect(decoded.keys.toSet(), {
        'format',
        'version',
        'exported_at',
        'groups',
        'servers',
        'payments',
        'service_periods',
        'fx',
      });
      for (final excluded in [
        connection.id,
        connection.secretRef,
        connection.endpoint,
        'rackNerd',
        'cloud_accounts',
        'cloud_observations',
        'cloud_bindings',
        'secret_ref',
      ]) {
        expect(source, isNot(contains(excluded)), reason: excluded);
      }
      final backup = LedgerBackupSnapshot.decode(source);
      expect(backup.counts['servers'], 1);
      expect(
        backup.servers.single['resources_json'],
        completedResources().encode(),
      );
    },
  );
}
