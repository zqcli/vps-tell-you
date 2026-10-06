import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_account.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/connections/snippet.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/servers/server_record.dart';

final cloudTestTime = DateTime.utc(2026, 10, 6);
CloudSnapshot snapshot({
  int user = 7,
  int project = 2,
  int server = 3,
  String? uuid = 'uuid-one',
  String name = 'Remote',
  String ip = '192.0.2.10',
  DateTime? at,
  CloudPower power = CloudPower.running,
  bool empty = false,
  bool v1 = false,
}) => CloudSnapshot(
  provider: v1 ? CloudProvider.solusVm1 : CloudProvider.solusVm2,
  completedAt: at ?? cloudTestTime,
  remoteAccountId: v1 ? null : user,
  instances: empty
      ? []
      : [
          CloudInstance(
            observedAt: at ?? cloudTestTime,
            power: power,
            projectId: v1 ? null : project,
            serverId: v1 ? null : server,
            uuid: v1 ? null : uuid,
            name: v1 ? null : name,
            ipv4: v1 ? null : ip,
          ),
        ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  late LedgerStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cloud-store-');
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
  Future<CloudAccount> add(
    String id, {
    CloudSnapshot? data,
    bool import = true,
  }) async {
    data ??= snapshot();
    final account = CloudAccount(
      id: id,
      provider: data.provider,
      alias: 'Panel $id',
      endpoint: 'https://panel.example:8443',
      secretRef: 'opaque-$id',
      createdAt: cloudTestTime,
      remoteAccountId: data.remoteAccountId,
    );
    await store.reserveSecret(account.secretRef);
    await store.saveCloudAccount(
      account: account,
      snapshot: data,
      expected: null,
      selectedInstanceKeys: import
          ? data.instances.map((i) => cloudInstanceKey(data!, i)).toSet()
          : {},
    );
    return (await store.cloudAccounts()).singleWhere((a) => a.id == id);
  }

  test(
    'schema 4 upgrade preserves ledger, finance, SSH and snippets',
    () async {
      final record = ServerRecord(
        id: 'local',
        name: 'Manual',
        vendor: 'Manual',
        createdAt: cloudTestTime,
        updatedAt: cloudTestTime,
      );
      await store.saveServer(record, isNew: true);
      await store.saveSshConfiguration(
        const SshConfiguration(
          serverId: 'local',
          host: 'example.test',
          port: 22,
          username: 'admin',
          revision: -1,
        ),
      );
      await store.saveSnippet(
        const CommandSnippet(id: 'cmd', name: 'Read', content: 'uname -a'),
        isNew: true,
      );
      await store.recordAccountPayment(
        id: 'bill',
        accountLabel: 'Separate bill',
        amount: Money('USD', 100),
        paidDate: const LedgerDate(2026, 10, 6),
      );
      final db = await raw();
      final tables = [
        'servers',
        'payments',
        'ssh_configurations',
        'snippets',
        'finance_settings',
      ];
      final before = <String, List<Map<String, Object?>>>{};
      for (final table in tables) {
        before[table] = await db.query(table);
      }
      for (final table in [
        'cloud_bindings',
        'cloud_observations',
        'cloud_accounts',
      ]) {
        await db.execute('DROP TABLE $table');
      }
      await db.setVersion(4);
      await store.close();
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      final upgraded = await raw();
      expect(await upgraded.getVersion(), 5);
      for (final table in tables) {
        expect(await upgraded.query(table), before[table]);
      }
      expect(await store.cloudAccounts(), isEmpty);
    },
  );
  test(
    'same endpoint and same remote ID remain scoped by local connection',
    () async {
      await add('a');
      await add('b');
      expect(await store.servers(), hasLength(2));
      expect(await store.cloudBindings(), hasLength(2));
      expect(
        (await store.cloudAccounts()).map((a) => a.endpoint).toSet(),
        hasLength(1),
      );
      await store.close();
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      expect(await store.cloudBindings(), hasLength(2));
    },
  );
  test(
    'save without importing, continue import and duplicate import are atomic',
    () async {
      final account = await add('a', import: false);
      expect(await store.servers(), isEmpty);
      final inventory = CloudInventory(account: account, snapshot: snapshot());
      expect(
        await store.importCloudInstances(
          inventory,
          selectedInstanceKeys: {'7/2/3'},
        ),
        1,
      );
      expect(
        await store.importCloudInstances(
          inventory,
          selectedInstanceKeys: {'7/2/3'},
        ),
        0,
      );
      expect(await store.servers(), hasLength(1));
      await expectLater(
        store.importCloudInstances(
          inventory,
          selectedInstanceKeys: {'7/2/3', 'not-present'},
        ),
        throwsA(isA<CloudAccountFailure>()),
      );
      expect(await store.servers(), hasLength(1));
    },
  );
  test(
    'invalid new selection rolls back account, ledger and reservation removal',
    () async {
      const ref = 'reserved';
      await store.reserveSecret(ref);
      final account = CloudAccount(
        id: 'a',
        provider: CloudProvider.solusVm2,
        alias: 'Panel',
        endpoint: 'https://panel.example',
        secretRef: ref,
        remoteAccountId: 7,
        createdAt: cloudTestTime,
      );
      await expectLater(
        store.saveCloudAccount(
          account: account,
          snapshot: snapshot(),
          expected: null,
          selectedInstanceKeys: {'7/2/3', 'invalid'},
        ),
        throwsA(isA<CloudAccountFailure>()),
      );
      expect(await store.cloudAccounts(), isEmpty);
      expect(await store.servers(), isEmpty);
      expect(await store.pendingSecretCleanup(), [ref]);
    },
  );
  test(
    'refresh changes only observations, preserves manual finance and SSH',
    () async {
      final account = await add('a');
      final original = (await store.servers()).single;
      final manual = ServerRecord(
        id: original.id,
        name: 'My name',
        vendor: 'My vendor',
        host: 'manual.example',
        notes: 'Private local notes',
        createdAt: original.createdAt,
        updatedAt: original.updatedAt,
        favorite: true,
        billing: BillingKind.metered,
        amountMinor: 1234,
      );
      await store.saveServer(manual, isNew: false);
      await store.saveSshConfiguration(
        SshConfiguration(
          serverId: manual.id,
          host: 'ssh.example',
          port: 2222,
          username: 'mine',
          revision: -1,
        ),
      );
      final before = (await store.servers()).single.toMap();
      final ssh = (await store.sshConfigurations()).single.toMap();
      final read = await store.beginCloudRead(account);
      final later = cloudTestTime.add(const Duration(hours: 1));
      await store.commitCloudSnapshot(
        read,
        snapshot(
          name: 'Renamed remotely',
          ip: '192.0.2.11',
          at: later,
          power: CloudPower.stopped,
        ),
      );
      expect((await store.servers()).single.toMap(), before);
      expect((await store.sshConfigurations()).single.toMap(), ssh);
      final binding = (await store.cloudBindings()).single;
      expect(binding.observation.name, 'Renamed remotely');
      expect(binding.observedAt, later);
      expect(binding.stale, false);
      expect(binding.power, CloudPower.stopped);
    },
  );
  test('failed read preserves observedAt, missing instance is stale not fresh stopped', () async {
    var account = await add('a');
    account = await store.beginCloudRead(account);
    await store.recordCloudFailure(account, CloudFailureKind.unauthorized);
    var binding = (await store.cloudBindings()).single;
    expect(binding.observedAt, cloudTestTime);
    expect(binding.stale, true);
    expect(binding.power, CloudPower.running);
    account = await store.beginCloudRead(account);
    await store.commitCloudSnapshot(
      account,
      snapshot(empty: true, at: cloudTestTime.add(const Duration(days: 1))),
    );
    binding = (await store.cloudBindings()).single;
    expect(binding.stale, true);
    expect(binding.missing, true);
    expect(binding.observedAt, cloudTestTime);
    expect(binding.power, CloudPower.running);
    await expectLater(
      store.importCloudInstances(
        CloudInventory(account: account, snapshot: snapshot()),
        selectedInstanceKeys: {'7/2/3'},
      ),
      throwsA(isA<CloudAccountFailure>()),
    );
  });
  test('UUID guard persists across responses which omit UUID', () async {
    var account = await add('a');
    account = await store.beginCloudRead(account);
    await store.commitCloudSnapshot(account, snapshot(uuid: null));
    account = await store.beginCloudRead(account);
    await expectLater(
      store.commitCloudSnapshot(account, snapshot(uuid: 'different')),
      throwsA(isA<CloudAccountFailure>()),
    );
    expect((await store.cloudBindings()).single.observation.uuid, isNull);
  });
  test(
    'remote account/project identity does not match by IP or display name',
    () async {
      var account = await add('a');
      account = await store.beginCloudRead(account);
      await expectLater(
        store.commitCloudSnapshot(account, snapshot(user: 8)),
        throwsA(isA<CloudAccountFailure>()),
      );
      final committed = await store.commitCloudSnapshot(
        account,
        snapshot(project: 5),
      );
      final inventory = CloudInventory(
        account: committed,
        snapshot: snapshot(project: 5),
      );
      await store.importCloudInstances(
        inventory,
        selectedInstanceKeys: {'7/5/3'},
      );
      expect(await store.servers(), hasLength(2));
      expect(
        (await store.cloudBindings()).where((b) => b.missing),
        hasLength(1),
      );
    },
  );
  test(
    'newer generation rejects old success, old failure and old import',
    () async {
      final account = await add('a');
      final old = await store.beginCloudRead(account);
      final current = await store.beginCloudRead(account);
      await store.commitCloudSnapshot(
        current,
        snapshot(power: CloudPower.stopped),
      );
      await expectLater(
        store.commitCloudSnapshot(old, snapshot()),
        throwsA(isA<LedgerConflict>()),
      );
      await expectLater(
        store.recordCloudFailure(old, CloudFailureKind.timeout),
        throwsA(isA<LedgerConflict>()),
      );
      await expectLater(
        store.importCloudInstances(
          CloudInventory(account: old, snapshot: snapshot()),
          selectedInstanceKeys: {'7/2/3'},
        ),
        throwsA(isA<LedgerConflict>()),
      );
      expect((await store.cloudBindings()).single.power, CloudPower.stopped);
    },
  );
  test(
    'transaction cancellation rolls back and unlink fences late results',
    () async {
      final account = await add('a');
      final read = await store.beginCloudRead(account);
      var checks = 0;
      await expectLater(
        store.commitCloudSnapshot(
          read,
          snapshot(power: CloudPower.stopped),
          isCancelled: () => ++checks > 1,
        ),
        throwsA(isA<CloudFailure>()),
      );
      expect((await store.cloudBindings()).single.power, CloudPower.running);
      await store.unbindCloudAccount(read);
      await expectLater(
        store.commitCloudSnapshot(read, snapshot()),
        throwsA(isA<LedgerConflict>()),
      );
      expect(await store.servers(), hasLength(1));
      expect(await store.cloudBindings(), isEmpty);
      expect(await store.pendingSecretCleanup(), [account.secretRef]);
    },
  );
  test('V1 connections are distinct, reauth requires explicit detach and preserves old ledger', () async {
    var account = await add('a', data: snapshot(v1: true));
    await add('b', data: snapshot(v1: true));
    expect(await store.servers(), hasLength(2));
    final oldServer = (await store.cloudBindings())
        .singleWhere((b) => b.accountId == 'a')
        .serverId;
    account = await store.beginCloudRead(account);
    final replacement = CloudAccount(
      id: 'a',
      provider: CloudProvider.solusVm1,
      alias: 'Rebound',
      endpoint: account.endpoint,
      secretRef: 'replacement',
      createdAt: account.createdAt,
    );
    await store.reserveSecret('replacement');
    await expectLater(
      store.saveCloudAccount(
        account: replacement,
        snapshot: snapshot(v1: true),
        expected: account,
      ),
      throwsA(isA<CloudAccountFailure>()),
    );
    await store.saveCloudAccount(
      account: replacement,
      snapshot: snapshot(v1: true),
      expected: account,
      confirmV1Rebind: true,
      selectedInstanceKeys: {'single'},
      v1DisplayName: 'New explicit name',
    );
    expect(await store.servers(), hasLength(3));
    expect((await store.servers()).any((s) => s.id == oldServer), true);
    expect(
      (await store.cloudBindings()).any((b) => b.serverId == oldServer),
      false,
    );
    expect(
      (await store.cloudBindings()).where((b) => b.accountId == 'a'),
      hasLength(1),
    );
  });
  test(
    'shared reference query protects live cloud secrets from cleanup',
    () async {
      final account = await add('a');
      expect(await store.secretIsReferenced(account.secretRef), true);
      await expectLater(
        store.reserveSecret(account.secretRef),
        throwsA(isA<LedgerConflict>()),
      );
      final db = await raw();
      for (final table in [
        'cloud_accounts',
        'cloud_observations',
        'cloud_bindings',
      ]) {
        expect(
          (await db.query(table)).toString(),
          isNot(contains('synthetic-token')),
        );
      }
    },
  );
  test(
    'long Unicode import remains valid and alias is not vendor identity',
    () async {
      await add('a', data: snapshot(name: '😀' * 70));
      final server = (await store.servers()).single;
      expect(server.name.length, 80);
      expect(server.validate(), isNull);
      expect(server.vendor, '服务商待填写');
      await store.saveServer(server, isNew: false);
    },
  );
}
