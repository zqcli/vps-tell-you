import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/cloud/solusvm_adapter.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

import 'cloud_controller_test.dart' show CloudTestSecrets, CallbackCloudAdapter;
import 'support/provider_fixture.dart';

const _key = 'SYNTHETIC+KEY/&=';
const _hash = 'SYNTHETIC+HASH/&=';
final _at = DateTime.utc(2026, 10, 6);

ServerResources _resources(CloudInstance i, {int? vcpu}) => ServerResources(
  ip: i.ipv4 ?? i.ipv6 ?? '',
  hostname: i.hostname ?? '',
  vcpu: vcpu,
  ramBytes: i.ramBytes,
  diskBytes: i.diskBytes,
  trafficBytes: i.trafficBytes,
  trafficPeriodMonths: 1,
  apiFields: {'ip', 'hostname', 'ramBytes', 'diskBytes', 'trafficBytes'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory temporary;
  late LedgerStore store;
  late CloudTestSecrets secrets;
  late CloudController controller;
  late String body;
  var calls = 0;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('racknerd-controller-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${temporary.path}/ledger.sqlite',
      clock: () => _at,
    );
    await addTestProvider(store);
    body = File('test/fixtures/solusvm/racknerd-info.json').readAsStringSync();
    secrets = CloudTestSecrets();
    calls = 0;
    controller = CloudController(
      store: store,
      secrets: secrets,
      adapterFactory: (provider, endpoint, credentials) {
        expect(provider, CloudProvider.rackNerd);
        expect(endpoint.toString(), 'https://panel.example.test:8443');
        expect(credentials, isA<RackNerdCredentials>());
        return RackNerdAdapter(
          endpoint: endpoint,
          credentials: credentials as RackNerdCredentials,
          clock: () => _at,
          clientFactory: () => MockClient((request) async {
            calls++;
            expect(request.bodyFields['key'], _key);
            expect(request.bodyFields['hash'], _hash);
            expect(request.bodyFields['action'], 'info');
            return http.Response(
              body,
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
      },
    );
    expect(await controller.initialize(), isTrue);
  });
  tearDown(() async {
    controller.dispose();
    await store.close();
    await temporary.delete(recursive: true);
  });

  Future<CloudVerification?> verify({
    CloudAccount? existing,
    ProviderRecord? businessProvider,
  }) => controller.verifyConnection(
    provider: CloudProvider.rackNerd,
    businessProvider: businessProvider ?? testProvider,
    endpoint: 'https://panel.example.test:8443/api/client/command.php',
    credentials: RackNerdCredentials(key: _key, hash: _hash),
    existing: existing,
  );

  test('real RackNerd adapter -> verify -> manual CPU completion -> persistent import -> refresh', () async {
    final verification = (await verify())!;
    expect(calls, 1);
    expect(verification.endpoint.normalizedApiPath, isTrue);
    expect(verification.businessProvider.id, testProvider.id);
    expect(
      verification.keyFor(verification.snapshot.instances.single),
      'single',
    );
    expect(secrets.writes, 0);
    final instance = verification.snapshot.instances.single;
    expect(instance.vcpu, isNull);
    expect(
      await controller.saveAccount(
        verification,
        alias: 'Synthetic ctrl',
        selectedInstanceKeys: {'single'},
        v1Resources: _resources(instance),
      ),
      isFalse,
    );
    expect(secrets.writes, 0);
    expect(await store.cloudAccounts(), isEmpty);
    expect(await store.servers(), isEmpty);
    expect(
      await controller.saveAccount(
        verification,
        alias: 'Synthetic ctrl',
        selectedInstanceKeys: {'single'},
        v1DisplayName: 'Reviewed local VPS',
        v1Resources: _resources(instance, vcpu: 2),
      ),
      isTrue,
    );
    expect(secrets.writes, 1);
    final secret = jsonDecode(secrets.values.values.single) as Map;
    expect(secret, {
      'version': 1,
      'provider': 'rackNerd',
      'key': _key,
      'hash': _hash,
    });
    final account = controller.accounts.single;
    expect(account.provider, CloudProvider.rackNerd);
    expect(account.businessProviderId, testProvider.id);
    expect(account.authScope, AdapterAuthScope.singleDevice);
    expect(account.endpoint, 'https://panel.example.test:8443');
    expect(account.remoteAccountId, isNull);
    expect(controller.bindings.single.instanceKey, 'single');
    final server = (await store.servers()).single;
    expect(server.providerId, testProvider.id);
    expect(server.vendor, testProvider.name);
    expect(account.pinnedServerId, server.id);
    expect(server.name, 'Reviewed local VPS');
    expect(server.resources!.vcpu, 2);
    expect(server.resources!.apiFields, isNot(contains('vcpu')));
    expect(server.resources!.ramBytes, instance.ramBytes);
    expect(server.resources!.trafficPeriodMonths, 1);
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      '${temporary.path}/ledger.sqlite',
    );
    for (final table in [
      'cloud_accounts',
      'cloud_observations',
      'cloud_bindings',
      'servers',
      'secret_cleanup',
    ]) {
      final rows = jsonEncode(await db.query(table));
      expect(rows, isNot(contains(_key)));
      expect(rows, isNot(contains(_hash)));
    }
    final prior = server.toMap();
    body = jsonEncode({
      'status': 'success',
      'statusmsg': '',
      'vmstat': 'offline',
      'ipaddress': '192.0.2.99',
      'hostname': 'updated.example.test',
      'mem': '1073741824,0,1073741824,0',
    });
    final inventory = (await controller.refreshAccount(account))!;
    expect(calls, 2);
    expect(inventory.snapshot.provider, CloudProvider.rackNerd);
    expect(controller.bindings.single.power, CloudPower.stopped);
    expect(controller.bindings.single.observation.ipv4, '192.0.2.99');
    expect((await store.servers()).single.toMap(), prior);
  });

  test('account-only save supports later resource completion import', () async {
    final verification = (await verify())!;
    expect(
      await controller.saveAccount(verification, alias: 'Only connection'),
      isTrue,
    );
    expect(await store.servers(), isEmpty);
    expect(controller.accounts.single.businessProviderId, testProvider.id);
    expect(controller.accounts.single.authScope, AdapterAuthScope.singleDevice);
    expect(controller.accounts.single.pinnedServerId, isNull);
    final inventory = (await controller.refreshAccount(
      controller.accounts.single,
    ))!;
    final resources = _resources(inventory.snapshot.instances.single, vcpu: 4);
    expect(
      await controller.importInstances(
        inventory,
        selectedInstanceKeys: {'single'},
      ),
      isFalse,
    );
    expect(await store.servers(), isEmpty);
    expect(
      await controller.importInstances(
        inventory,
        selectedInstanceKeys: {'single'},
        v1DisplayName: 'Manual CPU VPS',
        v1Resources: resources,
      ),
      isTrue,
    );
    expect((await store.servers()).single.resources!.vcpu, 4);
    expect(controller.bindings.single.instanceKey, 'single');
  });

  test(
    'reauthorization requires explicit singleton detach before vault write',
    () async {
      final verification = (await verify())!;
      expect(
        await controller.saveAccount(
          verification,
          alias: 'Synthetic ctrl',
          selectedInstanceKeys: {'single'},
          v1Resources: _resources(
            verification.snapshot.instances.single,
            vcpu: 2,
          ),
        ),
        isTrue,
      );
      final account = controller.accounts.single;
      final prior = (await store.servers()).single.toMap();
      expect(account.authScope, AdapterAuthScope.singleDevice);
      expect(account.pinnedServerId, prior['id']);
      final reauthorization = (await verify(existing: account))!;
      final writes = secrets.writes;
      expect(
        await controller.saveAccount(reauthorization, alias: 'Reauthorized'),
        isFalse,
      );
      expect(secrets.writes, writes);
      expect(controller.error, CloudAccountFailure.v1Rebind.message);
      expect(
        await controller.saveAccount(
          reauthorization,
          alias: 'Reauthorized',
          confirmV1Rebind: true,
        ),
        isTrue,
      );
      expect(await store.cloudBindings(), isEmpty);
      expect(controller.accounts.single.businessProviderId, testProvider.id);
      expect(
        controller.accounts.single.authScope,
        AdapterAuthScope.singleDevice,
      );
      expect(controller.accounts.single.pinnedServerId, isNull);
      expect((await store.servers()).single.toMap(), prior);
      expect(secrets.values.keys, [controller.accounts.single.secretRef]);
    },
  );

  test(
    'API/HTML failure preserves prior observation and safe failure metadata',
    () async {
      final verification = (await verify())!;
      expect(
        await controller.saveAccount(
          verification,
          alias: 'Synthetic ctrl',
          selectedInstanceKeys: {'single'},
          v1Resources: _resources(
            verification.snapshot.instances.single,
            vcpu: 2,
          ),
        ),
        isTrue,
      );
      final observation = controller.bindings.single.observation;
      for (final (response, failure) in [
        (
          jsonEncode({'status': 'error', 'statusmsg': '$_key $_hash'}),
          CloudFailureKind.apiRejected,
        ),
        ('<html>$_key $_hash</html>', CloudFailureKind.invalidResponse),
      ]) {
        body = response;
        expect(
          await controller.refreshAccount(controller.accounts.single),
          isNull,
        );
        expect(controller.accounts.single.lastFailure, failure);
        expect(controller.bindings.single.stale, isTrue);
        expect(
          controller.bindings.single.observation.observedAt,
          observation.observedAt,
        );
        expect(controller.bindings.single.power, observation.power);
        expect(controller.error, isNot(contains(_key)));
        expect(controller.error, isNot(contains(_hash)));
      }
    },
  );

  test(
    'credential classes cannot cross providers before adapter creation',
    () async {
      for (final (provider, credentials) in [
        (CloudProvider.rackNerd, SolusVm1Credentials(key: _key, hash: _hash)),
        (CloudProvider.solusVm1, RackNerdCredentials(key: _key, hash: _hash)),
        (CloudProvider.rackNerd, SolusVm2Credentials('SYNTHETIC_TOKEN')),
      ]) {
        expect(
          await controller.verifyConnection(
            provider: provider,
            businessProvider: testProvider,
            endpoint: 'https://panel.example.test:8443',
            credentials: credentials,
          ),
          isNull,
        );
        expect(
          controller.error,
          const CloudFailure(CloudFailureKind.invalidCredentials).message,
        );
      }
      expect(calls, 0);
      expect(secrets.writes, 0);
    },
  );

  test(
    'invalid anonymous identities/counts cannot authorize or write secrets',
    () async {
      controller.dispose();
      CloudSnapshot? response;
      controller = CloudController(
        store: store,
        secrets: secrets,
        adapterFactory: (_, _, _) =>
            CallbackCloudAdapter((_) async => response!),
      );
      for (final (remoteId, instances) in [
        (null, <CloudInstance>[]),
        (
          null,
          List.filled(
            2,
            CloudInstance(observedAt: _at, power: CloudPower.running),
          ),
        ),
        (12, [CloudInstance(observedAt: _at, power: CloudPower.running)]),
        (
          null,
          [
            CloudInstance(
              observedAt: _at,
              power: CloudPower.running,
              serverId: 12,
            ),
          ],
        ),
        (
          null,
          [
            CloudInstance(
              observedAt: _at,
              power: CloudPower.running,
              projectId: 12,
            ),
          ],
        ),
        (
          null,
          [
            CloudInstance(
              observedAt: _at,
              power: CloudPower.running,
              uuid: 'synthetic-uuid',
            ),
          ],
        ),
      ]) {
        response = CloudSnapshot(
          provider: CloudProvider.rackNerd,
          completedAt: _at,
          remoteAccountId: remoteId,
          instances: instances,
        );
        expect(await verify(), isNull);
        expect(
          controller.error,
          const CloudFailure(CloudFailureKind.invalidResponse).message,
        );
      }
      expect(secrets.writes, 0);
      expect(await store.cloudAccounts(), isEmpty);
    },
  );

  test(
    'RackNerd requires a current confirmed business provider before API access',
    () async {
      final missing = ProviderRecord(
        id: 'missing-provider',
        name: 'Missing vendor',
        createdAt: _at,
      );
      expect(await verify(businessProvider: missing), isNull);
      expect(calls, 0);
      expect(secrets.writes, 0);

      await store.saveProvider(
        ProviderRecord(
          id: testProvider.id,
          name: 'Renamed vendor',
          createdAt: testProvider.createdAt,
          revision: testProvider.revision,
        ),
        isNew: false,
      );
      expect(await verify(), isNull);
      expect(calls, 0);
      expect(secrets.writes, 0);

      final current = (await store.providers()).single;
      final db = await databaseFactoryFfiNoIsolate.openDatabase(
        '${temporary.path}/ledger.sqlite',
      );
      await db.update(
        'providers',
        {'needs_review': 1},
        where: 'id = ?',
        whereArgs: [current.id],
      );
      expect(await verify(businessProvider: current), isNull);
      expect(calls, 0);
      expect(secrets.writes, 0);
      expect(await store.cloudAccounts(), isEmpty);
      expect(await store.servers(), isEmpty);
    },
  );

  test('provider rename after RackNerd verification fences save before vault write', () async {
    final verification = (await verify())!;
    expect(calls, 1);
    await store.saveProvider(
      ProviderRecord(
        id: testProvider.id,
        name: 'Renamed vendor',
        createdAt: testProvider.createdAt,
        revision: testProvider.revision,
      ),
      isNew: false,
    );
    expect(
      await controller.saveAccount(verification, alias: 'Stale provider'),
      isFalse,
    );
    expect(secrets.writes, 0);
    expect(secrets.values, isEmpty);
    expect(await store.cloudAccounts(), isEmpty);
    expect(await store.cloudBindings(), isEmpty);
  });

  test('RackNerd reauthorization cannot silently move to another business provider', () async {
    final verification = (await verify())!;
    expect(
      await controller.saveAccount(
        verification,
        alias: 'Owned by local vendor',
        selectedInstanceKeys: {'single'},
        v1Resources: _resources(
          verification.snapshot.instances.single,
          vcpu: 2,
        ),
      ),
      isTrue,
    );
    final account = controller.accounts.single;
    final server = (await store.servers()).single.toMap();
    final secretValues = Map<String, String>.of(secrets.values);
    final writes = secrets.writes;
    final requests = calls;
    final other = ProviderRecord(
      id: 'other-provider',
      name: 'Other local vendor',
      createdAt: _at,
    );
    await store.saveProvider(other, isNew: true);
    expect(await verify(existing: account, businessProvider: other), isNull);
    expect(calls, requests);
    expect(secrets.writes, writes);
    expect(secrets.values, secretValues);
    expect((await store.cloudAccounts()).single.toMap(), account.toMap());
    expect((await store.servers()).single.toMap(), server);
    expect((await store.cloudBindings()).single.serverId, server['id']);
  });
}
