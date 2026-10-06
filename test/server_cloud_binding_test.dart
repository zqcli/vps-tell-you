import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'cloud_controller_test.dart'
    show CloudTestSecrets, ReloadFailCloudController;
import 'cloud_store_test.dart' show cloudTestTime, completedResources, snapshot;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  late LedgerStore store;
  late CloudTestSecrets secrets;
  late ReloadFailCloudController cloud;
  var adapterCalls = 0;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('server-cloud-binding-');
    path = '${directory.path}/ledger.sqlite3';
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => cloudTestTime,
    );
    secrets = CloudTestSecrets();
    adapterCalls = 0;
    cloud = ReloadFailCloudController(
      store: store,
      secrets: secrets,
      adapterFactory: (_, _, _) {
        adapterCalls++;
        throw StateError('Local binding must never request an adapter');
      },
    );
    await cloud.initialize();
  });
  tearDown(() async {
    expect(adapterCalls, 0);
    expect(secrets.reads, 0);
    expect(secrets.writes, 0);
    expect(secrets.deletes, 0);
    cloud.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<ServerRecord> addServer(String id, {bool paid = false}) async {
    final server = ServerRecord(
      id: id,
      name: 'Local $id',
      vendor: 'Local vendor',
      host: '192.0.2.99',
      notes: 'Local note',
      resources: completedResources(),
      billing: paid ? BillingKind.prepaid : BillingKind.unknown,
      amountMinor: paid ? 1200 : null,
      startDate: paid ? const LedgerDate(2026, 1, 1) : null,
      dueDate: paid ? const LedgerDate(2027, 1, 1) : null,
      createdAt: cloudTestTime,
      updatedAt: cloudTestTime,
    );
    await store.saveServer(server, isNew: true);
    return (await store.servers()).singleWhere((s) => s.id == id);
  }

  Future<CloudAccount> addAccount(String id, {bool v1 = false}) async {
    final data = snapshot(v1: v1);
    final account = CloudAccount(
      id: id,
      provider: data.provider,
      alias: 'Panel $id',
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
    );
    return (await store.cloudAccounts()).singleWhere((a) => a.id == id);
  }

  Future<void> bind(String serverId, String accountId) async {
    final options = await store.serverCloudBindingOptions(serverId);
    await store.setServerCloudBinding(
      options,
      choice: options.choices.singleWhere((c) => c.accountId == accountId),
    );
  }

  test(
    'bind, replace, unlink preserve every local field and secret reference',
    () async {
      await addServer('local', paid: true);
      await addAccount('one');
      await addAccount('two', v1: true);
      await store.saveSshConfiguration(
        const SshConfiguration(
          serverId: 'local',
          host: 'ssh.local.fixture',
          port: 2222,
          username: 'admin',
          revision: -1,
        ),
      );
      await store.recordAccountPayment(
        id: 'bill',
        accountLabel: 'Local bill',
        amount: const Money('USD', 999),
        paidDate: const LedgerDate(2026, 10, 1),
      );
      final db = await databaseFactoryFfiNoIsolate.openDatabase(path);
      final tables = [
        'servers',
        'payments',
        'service_periods',
        'ssh_configurations',
        'credentials',
        'secret_cleanup',
        'cloud_observations',
        'reminder_rules',
      ];
      final before = <String, List<Map<String, Object?>>>{};
      for (final table in tables) {
        before[table] = await db.query(table);
      }
      final options = await store.serverCloudBindingOptions('local');
      expect(options.current, isNull);
      expect(options.choices, hasLength(2));
      await bind('local', 'one');
      expect((await store.cloudBindings()).single.accountId, 'one');
      await bind('local', 'two');
      expect((await store.cloudBindings()).single.accountId, 'two');
      await store.setServerCloudBinding(
        await store.serverCloudBindingOptions('local'),
      );
      expect(await store.cloudBindings(), isEmpty);
      for (final table in tables) {
        expect(await db.query(table), before[table], reason: table);
      }
      final accounts = await store.cloudAccounts();
      expect(accounts.map((a) => a.secretRef), ['opaque-one', 'opaque-two']);
      expect(accounts.map((a) => a.generation), [3, 3]);
      expect(accounts.every((a) => a.revision == 0), isTrue);
    },
  );

  test('an occupied instance cannot replace the current link', () async {
    await addServer('one');
    await addServer('two');
    await addAccount('a');
    await addAccount('b');
    await bind('one', 'a');
    await bind('two', 'b');
    final options = await store.serverCloudBindingOptions('one');
    final taken = options.choices.singleWhere((c) => c.accountId == 'b');
    expect(taken.serverId, 'two');
    await expectLater(
      store.setServerCloudBinding(options, choice: taken),
      throwsA(same(CloudAccountFailure.bindingTaken)),
    );
    expect(
      (await store.cloudBindings())
          .singleWhere((b) => b.serverId == 'one')
          .accountId,
      'a',
    );
  });

  test(
    'stale concurrent selection and unbound ABA across accounts are fenced',
    () async {
      await addServer('one');
      await addServer('two');
      await addAccount('a');
      await addAccount('b');
      final first = await store.serverCloudBindingOptions('one');
      final concurrent = await store.serverCloudBindingOptions('two');
      await bind('one', 'a');
      await expectLater(
        store.setServerCloudBinding(
          concurrent,
          choice: concurrent.choices.first,
        ),
        throwsA(isA<LedgerConflict>()),
      );
      await store.setServerCloudBinding(
        await store.serverCloudBindingOptions('one'),
      );
      await expectLater(
        store.setServerCloudBinding(
          first,
          choice: first.choices.singleWhere((c) => c.accountId == 'b'),
        ),
        throwsA(isA<LedgerConflict>()),
      );
      expect(await store.cloudBindings(), isEmpty);
    },
  );

  test('an old unlink cannot delete a newer replacement', () async {
    await addServer('local');
    await addAccount('a');
    await addAccount('b');
    await bind('local', 'a');
    final old = await store.serverCloudBindingOptions('local');
    await bind('local', 'b');
    await expectLater(
      store.setServerCloudBinding(old),
      throwsA(isA<LedgerConflict>()),
    );
    expect((await store.cloudBindings()).single.accountId, 'b');
  });

  test('temporary account removal cannot erase the stale-page fence', () async {
    await addServer('local');
    await addAccount('a');
    final old = await store.serverCloudBindingOptions('local');
    await addAccount('temporary');
    await bind('local', 'temporary');
    final temporary = (await store.cloudAccounts()).singleWhere(
      (account) => account.id == 'temporary',
    );
    await store.unbindCloudAccount(temporary);
    expect((await store.cloudAccounts()).single.id, 'a');
    expect(await store.cloudBindings(), isEmpty);
    await expectLater(
      store.setServerCloudBinding(old, choice: old.choices.single),
      throwsA(isA<LedgerConflict>()),
    );
  });

  for (final operation in [
    'rename account',
    'remove account',
    'begin refresh',
    'edit server',
    'archive server',
  ]) {
    test('$operation invalidates an already open binding page', () async {
      final server = await addServer('local');
      final account = await addAccount('a');
      final old = await store.serverCloudBindingOptions('local');
      switch (operation) {
        case 'rename account':
          await store.renameCloudAccount(account, 'Renamed');
        case 'remove account':
          await store.unbindCloudAccount(account);
        case 'begin refresh':
          await store.beginCloudRead(account);
        case 'edit server':
          await store.setFavorite(server, true);
        case 'archive server':
          await store.archive(server);
      }
      await expectLater(
        store.setServerCloudBinding(old, choice: old.choices.single),
        throwsA(isA<LedgerConflict>()),
      );
      expect(await store.cloudBindings(), isEmpty);
    });
  }

  test(
    'cancellation after link replacement rolls back both link and generations',
    () async {
      await addServer('local');
      await addAccount('a');
      await addAccount('b');
      await bind('local', 'a');
      final options = await store.serverCloudBindingOptions('local');
      var checks = 0;
      await expectLater(
        store.setServerCloudBinding(
          options,
          choice: options.choices.singleWhere((c) => c.accountId == 'b'),
          isCancelled: () => ++checks == 3,
        ),
        throwsA(
          isA<CloudFailure>().having(
            (f) => f.kind,
            'kind',
            CloudFailureKind.cancelled,
          ),
        ),
      );
      expect(checks, 3);
      final after = await store.serverCloudBindingOptions('local');
      expect(after.current!.accountId, 'a');
      expect(
        after.accounts.map((a) => a.generation),
        options.accounts.map((a) => a.generation),
      );
    },
  );

  for (final missing in [false, true]) {
    test(
      '${missing ? 'missing' : 'failed'} observations cannot bind, but can unlink',
      () async {
        await addServer('local');
        await addAccount('a');
        await bind('local', 'a');
        var account = (await store.cloudAccounts()).single;
        if (missing) {
          account = await store.beginCloudRead(account);
          await store.commitCloudSnapshot(account, snapshot(empty: true));
        } else {
          await store.recordCloudFailure(account, CloudFailureKind.timeout);
        }
        await addServer('other');
        final unavailable = await store.serverCloudBindingOptions('other');
        await expectLater(
          store.setServerCloudBinding(
            unavailable,
            choice: unavailable.choices.single,
          ),
          throwsA(same(CloudAccountFailure.bindingUnavailable)),
        );
        await store.setServerCloudBinding(
          await store.serverCloudBindingOptions('local'),
        );
        expect(await store.cloudBindings(), isEmpty);
      },
    );
  }

  test(
    'binding leaves payment undo valid and does not replace local hardware',
    () async {
      final server = await addServer('local', paid: true);
      await addAccount('a');
      final payment = await store.recordPayment(
        id: 'renewal',
        server: server,
        amount: const Money('USD', 1200),
        paidDate: const LedgerDate(2026, 10, 6),
        cycleCount: 1,
        until: const LedgerDate(2028, 1, 1),
        confirmed: true,
      );
      await bind('local', 'a');
      expect(
        (await store.servers()).single.revision,
        payment.appliedServerRevision,
      );
      await store.undoPayment(payment.id);
      final current = (await store.servers()).single;
      expect(current.dueDate, server.dueDate);
      expect(current.resources!.toJson(), server.resources!.toJson());
      expect((await store.payments()).single.voided, isTrue);
      expect((await store.cloudBindings()).single.serverId, 'local');
    },
  );

  test(
    'existing account import respects the server-side association',
    () async {
      await addServer('local');
      final account = await addAccount('a');
      await bind('local', 'a');
      final oldInventory = CloudInventory(
        account: account,
        snapshot: snapshot(),
      );
      await expectLater(
        store.importCloudInstances(
          oldInventory,
          selectedInstanceKeys: {'7/2/3'},
        ),
        throwsA(isA<LedgerConflict>()),
      );
      final currentInventory = CloudInventory(
        account: (await store.cloudAccounts()).single,
        snapshot: snapshot(),
      );
      expect(
        await store.importCloudInstances(
          currentInventory,
          selectedInstanceKeys: {'7/2/3'},
        ),
        0,
      );
      expect(await store.servers(), hasLength(1));
    },
  );

  test(
    'controller double save is blocked without credentials or network',
    () async {
      await addServer('local');
      await addAccount('a');
      final options = (await cloud.serverBindingOptions('local'))!;
      final first = cloud.setServerBinding(
        options,
        choice: options.choices.single,
      );
      final second = cloud.setServerBinding(
        options,
        choice: options.choices.single,
      );
      expect(await second, isFalse);
      expect(await first, isTrue);
      expect(cloud.bindingFor('local')!.accountId, 'a');
      expect(
        await cloud.setServerBinding(options, choice: options.choices.single),
        isFalse,
      );
      expect(await store.cloudBindings(), hasLength(1));
    },
  );

  test(
    'committed read failure returns success and blocks writes until reload',
    () async {
      await addServer('local');
      await addAccount('a');
      final options = (await cloud.serverBindingOptions('local'))!;
      cloud.failReload = true;
      expect(
        await cloud.setServerBinding(options, choice: options.choices.single),
        isTrue,
      );
      expect(cloud.needsReload, isTrue);
      expect(cloud.error, contains('已保存'));
      expect(await cloud.serverBindingOptions('local'), isNull);
      expect(await cloud.setServerBinding(options), isFalse);
      expect(await store.cloudBindings(), hasLength(1));
      cloud.failReload = false;
      expect(await cloud.reload(), isTrue);
      expect(cloud.bindingFor('local')!.accountId, 'a');
      final refreshed = (await cloud.serverBindingOptions('local'))!;
      expect(await cloud.setServerBinding(refreshed), isTrue);
      expect(await store.cloudBindings(), isEmpty);
    },
  );
}
