import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/cloud/solusvm_adapter.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/security/secret_store.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

// Independent review coverage: only synthetic credentials, in-memory secrets,
// a temporary SQLite ledger and injected HTTP responses. No native vault/API.
const _key = 'SYNTHETIC_REVIEW_KEY+ /&=';
const _hash = 'SYNTHETIC_REVIEW_HASH+ /&=';
const _token = 'SYNTHETIC_REVIEW_TOKEN';
const _sshSecret = 'SYNTHETIC_REVIEW_SSH_SECRET';
final _at = DateTime.utc(2026, 10, 7);

class _MemorySecrets implements SecretStore {
  final values = <String, String>{};
  int reads = 0, writes = 0;
  @override
  Future<String?> read(String reference) async {
    reads++;
    return values[reference];
  }

  @override
  Future<void> write(String reference, String value) async {
    writes++;
    values[reference] = value;
  }

  @override
  Future<void> delete(String reference) async {
    values.remove(reference);
  }
}

CloudCredentials _credentials(
  CloudProvider provider, {
  bool replacement = false,
}) {
  final suffix = replacement ? '_REPLACEMENT' : '';
  return switch (provider) {
    CloudProvider.solusVm1 => SolusVm1Credentials(
      key: '$_key$suffix',
      hash: '$_hash$suffix',
    ),
    CloudProvider.solusVm2 => SolusVm2Credentials('$_token$suffix'),
    CloudProvider.rackNerd => RackNerdCredentials(
      key: '$_key$suffix',
      hash: '$_hash$suffix',
    ),
  };
}

ServerResources _completed() => ServerResources(
  ip: '192.0.2.77',
  hostname: 'synthetic-review.example.test',
  vcpu: 2,
  ramBytes: 2147483648,
  diskBytes: 32212254720,
  trafficBytes: 1099511627776,
  trafficPeriodMonths: 1,
  apiFields: {'ip', 'hostname', 'ramBytes', 'diskBytes', 'trafficBytes'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory temporary;
  late String path;
  late LedgerStore store;
  late _MemorySecrets secrets;
  late CloudController controller;
  var adapterCalls = 0, requests = 0;

  CloudController makeController() => CloudController(
    store: store,
    secrets: secrets,
    adapterFactory: (provider, endpoint, credentials) {
      adapterCalls++;
      http.Client client() => MockClient((request) async {
        requests++;
        if (provider == CloudProvider.solusVm1) {
          return http.Response(
            '<status>success</status><statusmsg>online</statusmsg>',
            200,
          );
        }
        if (provider == CloudProvider.rackNerd) {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'statusmsg': '',
              'vmstat': 'online',
              'hostname': 'synthetic-review.example.test',
              'ipaddress': '192.0.2.77',
              'ipaddr': '192.0.2.77,2001:db8::77',
              'bw': '1099511627776,0,1099511627776,0',
              'hdd': '32212254720,0,32212254720,0',
              'mem': '2147483648,0,2147483648,0',
              'password': _sshSecret,
              'id': 999,
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode(switch (request.url.path) {
            '/api/v1/account' => {
              'data': {'id': 7},
            },
            '/api/v1/projects' => {
              'data': [
                {'id': 2},
              ],
            },
            '/api/v1/projects/2/servers' => {
              'data': [
                {'id': 3, 'name': 'Synthetic V2'},
              ],
            },
            _ => throw StateError('Unexpected synthetic request'),
          }),
          200,
        );
      });
      return switch (provider) {
        CloudProvider.solusVm1 => SolusVm1Adapter(
          endpoint: endpoint,
          credentials: credentials as SolusVm1Credentials,
          clientFactory: client,
          clock: () => _at,
        ),
        CloudProvider.solusVm2 => SolusVm2Adapter(
          endpoint: endpoint,
          credentials: credentials as SolusVm2Credentials,
          clientFactory: client,
          clock: () => _at,
        ),
        CloudProvider.rackNerd => RackNerdAdapter(
          endpoint: endpoint,
          credentials: credentials as RackNerdCredentials,
          clientFactory: client,
          clock: () => _at,
        ),
      };
    },
  );

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('racknerd-review-');
    path = '${temporary.path}/ledger.sqlite';
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => _at,
    );
    secrets = _MemorySecrets();
    adapterCalls = 0;
    requests = 0;
    controller = makeController();
    expect(await controller.initialize(), isTrue);
  });
  tearDown(() async {
    controller.dispose();
    await store.close();
    await temporary.delete(recursive: true);
  });

  Future<CloudVerification> verify(
    CloudProvider provider, {
    CloudAccount? existing,
    bool replacement = false,
  }) async => (await controller.verifyConnection(
    provider: provider,
    endpoint: 'https://synthetic-review.example.test:8443',
    credentials: _credentials(provider, replacement: replacement),
    existing: existing,
  ))!;

  Future<CloudAccount> add(CloudProvider provider) async {
    final verification = await verify(provider);
    expect(
      await controller.saveAccount(
        verification,
        alias: 'Synthetic ${provider.name} account',
        selectedInstanceKeys: verification.snapshot.instances
            .map(verification.keyFor)
            .toSet(),
        v1Resources: provider.isSingleInstance ? _completed() : null,
      ),
      isTrue,
    );
    return controller.accounts.single;
  }

  Future<void> reopen() async {
    controller.dispose();
    await store.close();
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => _at,
    );
    controller = makeController();
    expect(await controller.initialize(), isTrue);
  }

  for (final provider in CloudProvider.values) {
    test(
      '${provider.name}: saved secret envelope cannot switch protocol after reopen',
      () async {
        final account = await add(provider);
        final original = secrets.values[account.secretRef]!;
        final correct = jsonDecode(original) as Map<String, dynamic>;
        expect(correct['provider'], provider.name);
        final before = (await store.servers()).single.toMap();
        final observation = controller.bindings.single.observation;
        final reads = secrets.reads;
        final calls = adapterCalls;
        final writes = secrets.writes;
        final sent = requests;
        await reopen();
        expect(secrets.reads, reads);
        expect(adapterCalls, calls);
        for (final envelope in [
          jsonEncode({
            ...correct,
            'provider': provider == CloudProvider.solusVm1
                ? 'rackNerd'
                : 'solusVm1',
          }),
          jsonEncode({...correct, 'version': 2}),
          jsonEncode({...correct, 'provider': null}),
          jsonEncode({
            ...correct,
            provider.isSingleInstance ? 'hash' : 'token': null,
          }),
          '{"version":1,"provider":"${provider.name}"}',
          'not JSON $_key',
        ]) {
          secrets.values[account.secretRef] = envelope;
          expect(
            await controller.refreshAccount(controller.accounts.single),
            isNull,
          );
          expect(controller.error, CloudAccountFailure.secretRead.message);
          expect(controller.error, isNot(contains(_key)));
          expect(adapterCalls, calls);
          expect(requests, sent);
          expect(secrets.writes, writes);
          expect(controller.bindings.single.stale, isTrue);
          expect(controller.bindings.single.power, observation.power);
          expect(
            controller.bindings.single.observation.observedAt,
            observation.observedAt,
          );
          expect((await store.servers()).single.toMap(), before);
        }
        secrets.values[account.secretRef] = original;
        expect(
          await controller.refreshAccount(controller.accounts.single),
          isNotNull,
        );
        expect(adapterCalls, calls + 1);
        expect(controller.bindings.single.stale, isFalse);
        expect((await store.servers()).single.toMap(), before);
      },
    );
  }

  for (final provider in [CloudProvider.solusVm1, CloudProvider.rackNerd]) {
    test(
      '${provider.name}: explicit anonymous rebind preserves local finance/SSH and backup v1',
      () async {
        final account = await add(provider);
        final imported = (await store.servers()).single;
        await store.saveServer(
          ServerRecord.fromMap({
            ...imported.toMap(),
            'name': 'Synthetic local reviewed name',
            'notes': 'SYNTHETIC_LOCAL_NOTE_NOT_IN_BACKUP',
            'vendor': 'Synthetic local vendor',
            'billing': 'prepaid',
            'currency': 'EUR',
            'amount_minor': 1200,
            'cycle_months': 1,
            'start_date': '2026-10-01',
            'due_date': '2026-11-01',
          }),
          isNew: false,
        );
        final payable = (await store.servers()).single;
        await store.recordPayment(
          id: 'synthetic-review-payment',
          server: payable,
          amount: const Money('EUR', 1200),
          paidDate: const LedgerDate(2026, 10, 7),
          cycleCount: 1,
          until: const LedgerDate(2026, 12, 1),
          confirmed: true,
          note: 'SYNTHETIC_PAYMENT_NOTE_NOT_IN_BACKUP',
        );
        const sshRef = 'opaque-synthetic-review-ssh';
        await store.reserveSecret(sshRef);
        await secrets.write(sshRef, _sshSecret);
        await store.saveCredential(
          CredentialMetadata(
            id: 'synthetic-review-ssh',
            name: 'Synthetic local SSH credential',
            kind: CredentialKind.password,
            defaultUsername: 'synthetic-user',
            secretRef: sshRef,
            createdAt: _at,
            updatedAt: _at,
          ),
          expectedRevision: null,
        );
        await store.saveSshConfiguration(
          SshConfiguration(
            serverId: imported.id,
            host: 'ssh.synthetic-review.example.test',
            port: 2222,
            username: 'synthetic-user',
            credentialId: 'synthetic-review-ssh',
          ),
        );
        final db = await databaseFactoryFfiNoIsolate.openDatabase(path);
        final protectedRows = <String, List<Map<String, Object?>>>{};
        for (final table in [
          'servers',
          'payments',
          'service_periods',
          'credentials',
          'ssh_configurations',
          'reminder_rules',
        ]) {
          protectedRows[table] = await db.query(table, orderBy: 'rowid');
        }
        final backupBefore = (await store.exportLedgerBackup()).encode();
        final reauthorization = await verify(
          provider,
          existing: account,
          replacement: true,
        );
        final writes = secrets.writes;
        expect(
          await controller.saveAccount(
            reauthorization,
            alias: 'Synthetic reauthorized',
          ),
          isFalse,
        );
        expect(controller.error, CloudAccountFailure.v1Rebind.message);
        expect(secrets.writes, writes);
        expect(controller.bindings.single.serverId, imported.id);
        expect(
          await controller.saveAccount(
            reauthorization,
            alias: 'Synthetic reauthorized',
            confirmV1Rebind: true,
          ),
          isTrue,
        );
        expect(controller.bindings, isEmpty);
        expect(controller.accounts.single.remoteAccountId, isNull);
        expect(controller.accounts.single.secretRef, isNot(account.secretRef));
        expect(secrets.values.containsKey(account.secretRef), isFalse);
        expect(secrets.values[sshRef], _sshSecret);
        for (final entry in protectedRows.entries) {
          expect(
            await db.query(entry.key, orderBy: 'rowid'),
            entry.value,
            reason: entry.key,
          );
        }
        final backup = (await store.exportLedgerBackup()).encode();
        expect(backup, backupBefore);
        final decoded = jsonDecode(backup) as Map<String, dynamic>;
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
          _key,
          _hash,
          _sshSecret,
          account.secretRef,
          controller.accounts.single.secretRef,
          sshRef,
          'cloud_accounts',
          'cloud_observations',
          'cloud_bindings',
          'SYNTHETIC_LOCAL_NOTE_NOT_IN_BACKUP',
          'SYNTHETIC_PAYMENT_NOTE_NOT_IN_BACKUP',
        ]) {
          expect(
            backup,
            isNot(contains(excluded)),
            reason: 'private/excluded data',
          );
        }
        expect(LedgerBackupSnapshot.decode(backup).counts['payments'], 1);
        await reopen();
        expect(controller.bindings, isEmpty);
        final inventory = (await controller.refreshAccount(
          controller.accounts.single,
        ))!;
        expect(
          await controller.importInstances(
            inventory,
            selectedInstanceKeys: {'single'},
          ),
          isFalse,
        );
        expect(await store.servers(), hasLength(1));
        expect(
          await controller.importInstances(
            inventory,
            selectedInstanceKeys: {'single'},
            v1DisplayName: 'Synthetic newly authorized VPS',
            v1Resources: _completed(),
          ),
          isTrue,
        );
        expect(await store.servers(), hasLength(2));
        expect(controller.bindings.single.serverId, isNot(imported.id));
        expect(
          (await store.servers())
              .singleWhere((server) => server.id == imported.id)
              .toMap(),
          protectedRows['servers']!.single,
        );
        expect((await store.payments()).single.serverId, imported.id);
        expect((await store.sshConfigurations()).single.serverId, imported.id);
      },
    );
  }
}
