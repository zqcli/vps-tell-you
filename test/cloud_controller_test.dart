import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/security/secret_store.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';

import 'cloud_store_test.dart' show snapshot, cloudTestTime, completedResources;

class CloudTestSecrets implements SecretStore {
  final values = <String, String>{};
  int reads = 0, writes = 0, deletes = 0;
  bool failWrite = false,
      partialWrite = false,
      failRead = false,
      failDelete = false,
      wrongRead = false;
  Completer<void>? writeStarted, writeRelease, readStarted, readRelease;
  @override
  Future<String?> read(String reference) async {
    reads++;
    if (!(readStarted?.isCompleted ?? true)) readStarted!.complete();
    await readRelease?.future;
    if (failRead) throw StateError('DO-NOT-LEAK synthetic-secret');
    return wrongRead ? 'bad payload' : values[reference];
  }

  @override
  Future<void> write(String reference, String value) async {
    writes++;
    if (!(writeStarted?.isCompleted ?? true)) writeStarted!.complete();
    await writeRelease?.future;
    if (partialWrite) values[reference] = value;
    if (failWrite) throw StateError('DO-NOT-LEAK $value');
    values[reference] = value;
  }

  @override
  Future<void> delete(String reference) async {
    deletes++;
    if (failDelete) throw StateError('DO-NOT-LEAK synthetic-secret');
    values.remove(reference);
  }
}

class CallbackCloudAdapter implements CloudAdapter {
  CallbackCloudAdapter(this.callback);
  final Future<CloudSnapshot> Function(CloudCancellation) callback;
  @override
  Future<CloudSnapshot> read({required CloudCancellation cancellation}) =>
      callback(cancellation);
}

class ReloadFailCloudController extends CloudController {
  ReloadFailCloudController({
    required super.store,
    required super.secrets,
    required super.adapterFactory,
  });
  bool failReload = false;
  @override
  Future<void> readMetadata() async {
    if (failReload) throw StateError('fixture reload error');
    await super.readMetadata();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  late LedgerStore store;
  late CloudTestSecrets secrets;
  late CloudController controller;
  late Future<CloudSnapshot> Function(CloudCancellation) reader;
  var adapterCalls = 0;
  CloudAdapter adapterFactory(
    CloudProvider provider,
    CloudEndpoint endpoint,
    CloudCredentials credentials,
  ) {
    adapterCalls++;
    return CallbackCloudAdapter(reader);
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cloud-controller-');
    path = '${directory.path}/ledger.sqlite';
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => cloudTestTime,
    );
    secrets = CloudTestSecrets();
    reader = (_) async => snapshot();
    adapterCalls = 0;
    controller = CloudController(
      store: store,
      secrets: secrets,
      adapterFactory: adapterFactory,
    );
    await controller.initialize();
  });
  tearDown(() async {
    controller.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });
  Future<CloudVerification?> verify({
    CloudAccount? existing,
    bool v1 = false,
    String token = 'synthetic-token',
  }) => controller.verifyConnection(
    provider: v1 ? CloudProvider.solusVm1 : CloudProvider.solusVm2,
    endpoint: 'https://panel.example',
    credentials: v1
        ? SolusVm1Credentials(key: 'synthetic-key', hash: 'synthetic-hash')
        : SolusVm2Credentials(token),
    existing: existing,
  );
  Future<CloudAccount> add({bool import = true, bool v1 = false}) async {
    reader = (_) async => snapshot(v1: v1);
    final verification = (await verify(v1: v1))!;
    expect(
      await controller.saveAccount(
        verification,
        alias: 'Panel',
        v1Resources: v1 ? completedResources() : null,
        selectedInstanceKeys: import
            ? verification.snapshot.instances.map(verification.keyFor).toSet()
            : {},
      ),
      true,
    );
    return controller.accounts.last;
  }

  Future<Database> raw() => databaseFactoryFfiNoIsolate.openDatabase(path);
  test('startup metadata only; verification writes nothing; save stores only opaque metadata', () async {
    expect(secrets.reads, 0);
    expect(adapterCalls, 0);
    final verification = (await verify())!;
    expect(secrets.writes, 0);
    expect(controller.accounts, isEmpty);
    expect(
      await controller.saveAccount(
        verification,
        alias: 'Panel',
        selectedInstanceKeys: {'7/2/3'},
      ),
      true,
    );
    expect(secrets.values, hasLength(1));
    expect(secrets.values.values.single, contains('synthetic-token'));
    final db = await raw();
    for (final table in [
      'cloud_accounts',
      'cloud_bindings',
      'cloud_observations',
      'servers',
      'secret_cleanup',
    ]) {
      expect(
        jsonEncode(await db.query(table)),
        isNot(contains('synthetic-token')),
      );
    }
    expect(
      await controller.saveAccount(verification, alias: 'Duplicate'),
      false,
    );
    expect(controller.accounts, hasLength(1));
  });
  test(
    'save zero imports then refresh and continue import skips linked duplicate',
    () async {
      var account = await add(import: false);
      expect(await store.servers(), isEmpty);
      final inventory = (await controller.refreshAccount(account))!;
      expect(
        await controller.importInstances(
          inventory,
          selectedInstanceKeys: {'7/2/3'},
        ),
        true,
      );
      expect(
        await controller.importInstances(
          inventory,
          selectedInstanceKeys: {'7/2/3'},
        ),
        true,
      );
      expect(await store.servers(), hasLength(1));
      account = controller.accounts.single;
      expect(account.lastFailure, isNull);
    },
  );
  test('failed verify and different remote account cannot damage existing authorization', () async {
    final account = await add();
    final prior = secrets.values[account.secretRef];
    final writes = secrets.writes;
    reader = (_) async =>
        throw const CloudFailure(CloudFailureKind.unauthorized);
    expect(await verify(existing: account, token: 'replacement-token'), isNull);
    expect(secrets.writes, writes);
    reader = (_) async => snapshot(user: 999);
    expect(await verify(existing: account, token: 'replacement-token'), isNull);
    expect(controller.error, contains('身份变化'));
    expect(secrets.values[account.secretRef], prior);
    expect(secrets.writes, writes);
    expect((await store.cloudAccounts()).single.secretRef, account.secretRef);
  });
  test('partial vault write failure keeps original and durable cleanup recovers after reopen', () async {
    final account = await add();
    final original = secrets.values[account.secretRef];
    final verification = (await verify(
      existing: account,
      token: 'replacement-token',
    ))!;
    secrets.failWrite = true;
    secrets.partialWrite = true;
    expect(
      await controller.saveAccount(verification, alias: 'Replacement'),
      false,
    );
    expect(controller.error, isNot(contains('replacement-token')));
    expect((await store.cloudAccounts()).single.secretRef, account.secretRef);
    expect(secrets.values[account.secretRef], original);
    expect(await store.pendingSecretCleanup(), hasLength(1));
    controller.dispose();
    await store.close();
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
    );
    controller = CloudController(
      store: store,
      secrets: secrets,
      adapterFactory: adapterFactory,
    );
    expect(await controller.initialize(), true);
    expect(await controller.retryCleanup(), true);
    expect(secrets.values, {account.secretRef: original});
  });
  test('read-back mismatch never commits account or imports', () async {
    final verification = (await verify())!;
    secrets.wrongRead = true;
    expect(
      await controller.saveAccount(
        verification,
        alias: 'Panel',
        selectedInstanceKeys: {'7/2/3'},
      ),
      false,
    );
    expect(await store.cloudAccounts(), isEmpty);
    expect(await store.servers(), isEmpty);
    expect(await store.pendingSecretCleanup(), hasLength(1));
  });
  test('successful reauth commits new secret then cleanup failure remains recoverable', () async {
    final account = await add();
    final verification = (await verify(
      existing: account,
      token: 'replacement-token',
    ))!;
    secrets.failDelete = true;
    expect(
      await controller.saveAccount(verification, alias: 'New alias'),
      true,
    );
    expect(controller.accounts.single.secretRef, isNot(account.secretRef));
    expect(secrets.values, hasLength(2));
    expect(controller.cleanupPending, true);
    expect(await store.servers(), hasLength(1));
    secrets.failDelete = false;
    expect(await controller.retryCleanup(), true);
    expect(secrets.values.keys, [controller.accounts.single.secretRef]);
    expect(
      jsonDecode(secrets.values.values.single)['token'],
      'replacement-token',
    );
  });
  test('SQLite commit failure preserves original and does not queue live old secret', () async {
    final account = await add();
    final verification = (await verify(
      existing: account,
      token: 'replacement-token',
    ))!;
    final db = await raw();
    await db.execute(
      "CREATE TRIGGER fail_cloud BEFORE UPDATE ON cloud_accounts BEGIN SELECT RAISE(ABORT, 'DO-NOT-LEAK'); END",
    );
    expect(
      await controller.saveAccount(verification, alias: 'New alias'),
      false,
    );
    expect((await store.cloudAccounts()).single.secretRef, account.secretRef);
    expect(
      await store.pendingSecretCleanup(),
      isNot(contains(account.secretRef)),
    );
    expect(secrets.values.containsKey(account.secretRef), true);
    expect(controller.error, isNot(contains('DO-NOT-LEAK')));
  });
  test('V1 incomplete resources fail before touching secure storage and can save account only', () async {
    reader = (_) async => snapshot(v1: true);
    final verification = (await verify(v1: true))!;
    expect(
      await controller.saveAccount(
        verification,
        alias: 'Panel',
        selectedInstanceKeys: {'single'},
      ),
      isFalse,
    );
    expect(secrets.writes, 0);
    expect(await store.cloudAccounts(), isEmpty);
    expect(await store.servers(), isEmpty);
    expect(await controller.saveAccount(verification, alias: 'Panel'), isTrue);
    expect(secrets.writes, 1);
    expect(await store.servers(), isEmpty);
  });

  test('V1 reauth requires explicit detach; save without selection leaves old ledger unbound', () async {
    final account = await add(v1: true);
    final server = (await store.servers()).single;
    final verification = (await verify(existing: account, v1: true))!;
    final writes = secrets.writes;
    expect(await controller.saveAccount(verification, alias: 'New V1'), false);
    expect(controller.error, contains('无法证明'));
    expect(secrets.writes, writes);
    expect(
      await controller.saveAccount(
        verification,
        alias: 'New V1',
        confirmV1Rebind: true,
      ),
      true,
    );
    expect(await store.cloudBindings(), isEmpty);
    expect((await store.servers()).single.id, server.id);
    final inventory = (await controller.refreshAccount(
      controller.accounts.single,
    ))!;
    expect(
      await controller.importInstances(
        inventory,
        selectedInstanceKeys: {'single'},
        v1DisplayName: 'Explicit VPS',
        v1Resources: completedResources(),
      ),
      true,
    );
    expect(await store.servers(), hasLength(2));
  });
  test('failed refresh preserves old observation with stale flag and sanitized failure', () async {
    final account = await add();
    reader = (_) async => throw const CloudFailure(CloudFailureKind.timeout);
    expect(await controller.refreshAccount(account), isNull);
    expect(controller.accounts.single.lastFailure, CloudFailureKind.timeout);
    expect(controller.bindings.single.stale, true);
    expect(controller.bindings.single.observedAt, cloudTestTime);
    expect(controller.bindings.single.power, CloudPower.running);
    reader = (_) async => snapshot();
    expect(
      await controller.refreshAccount(controller.accounts.single),
      isNotNull,
    );
    expect(controller.bindings.single.stale, false);
  });
  test(
    'newer refresh wins even when previous adapter ignores cancellation',
    () async {
      final account = await add();
      final firstStarted = Completer<void>(),
          firstResult = Completer<CloudSnapshot>();
      reader = (_) {
        firstStarted.complete();
        return firstResult.future;
      };
      final old = controller.refreshAccount(account);
      await firstStarted.future;
      reader = (_) async => snapshot(
        power: CloudPower.stopped,
        at: cloudTestTime.add(const Duration(hours: 1)),
      );
      expect(await controller.refreshAccount(account), isNotNull);
      firstResult.complete(snapshot());
      expect(await old, isNull);
      expect(controller.bindings.single.power, CloudPower.stopped);
      expect(controller.accounts.single.lastFailure, isNull);
    },
  );
  test('late refresh cannot resurrect unlink, which preserves ledger, payments and SSH', () async {
    final account = await add();
    final server = (await store.servers()).single;
    await store.saveSshConfiguration(
      SshConfiguration(
        serverId: server.id,
        host: 'ssh.example',
        port: 22,
        username: 'admin',
        revision: -1,
      ),
    );
    await store.recordAccountPayment(
      id: 'bill',
      accountLabel: 'Still owed',
      amount: Money('USD', 100),
      paidDate: const LedgerDate(2026, 10, 6),
    );
    final started = Completer<void>(), result = Completer<CloudSnapshot>();
    reader = (_) {
      started.complete();
      return result.future;
    };
    final refresh = controller.refreshAccount(account);
    await started.future;
    expect(controller.busy, true);
    expect(await controller.unbindAccount(account), true);
    result.complete(snapshot());
    expect(await refresh, isNull);
    expect(await store.cloudAccounts(), isEmpty);
    expect(await store.cloudBindings(), isEmpty);
    expect(await store.servers(), hasLength(1));
    expect(await store.payments(), hasLength(1));
    expect(await store.sshConfigurations(), hasLength(1));
    expect(secrets.values, isEmpty);
  });
  test(
    'cancel verification and ignore late success without writing secrets',
    () async {
      final started = Completer<void>(), result = Completer<CloudSnapshot>();
      reader = (_) {
        started.complete();
        return result.future;
      };
      final verification = verify();
      await started.future;
      controller.cancelVerification();
      result.complete(snapshot());
      expect(await verification, isNull);
      expect(secrets.writes, 0);
      expect(await store.cloudAccounts(), isEmpty);
      expect(controller.busy, false);
    },
  );
  test('cancel while vault write pending prevents commit and recovery deletes orphan', () async {
    final verification = (await verify())!;
    secrets.writeStarted = Completer<void>();
    secrets.writeRelease = Completer<void>();
    final save = controller.saveAccount(
      verification,
      alias: 'Panel',
      selectedInstanceKeys: {'7/2/3'},
    );
    await secrets.writeStarted!.future;
    controller.cancelVerification();
    secrets.writeRelease!.complete();
    expect(await save, false);
    expect(await store.cloudAccounts(), isEmpty);
    expect(await store.servers(), isEmpty);
    expect(await store.pendingSecretCleanup(), hasLength(1));
    expect(await controller.retryCleanup(), true);
    expect(secrets.values, isEmpty);
  });
  test(
    'stale verified reauthorization cannot overwrite a newer account revision',
    () async {
      final account = await add();
      final verification = (await verify(
        existing: account,
        token: 'replacement-token',
      ))!;
      await store.renameCloudAccount(account, 'Newer alias');
      expect(
        await controller.saveAccount(verification, alias: 'Old draft'),
        false,
      );
      expect((await store.cloudAccounts()).single.alias, 'Newer alias');
      expect((await store.cloudAccounts()).single.secretRef, account.secretRef);
      expect(secrets.values.containsKey(account.secretRef), true);
    },
  );
  test('committed save reports success despite failed reload and blocks duplicate submission', () async {
    controller.dispose();
    final failing = ReloadFailCloudController(
      store: store,
      secrets: secrets,
      adapterFactory: adapterFactory,
    );
    controller = failing;
    await controller.initialize();
    final verification = (await verify())!;
    failing.failReload = true;
    expect(await controller.saveAccount(verification, alias: 'Panel'), true);
    expect(controller.needsReload, true);
    expect(await store.cloudAccounts(), hasLength(1));
    expect(
      await controller.saveAccount(verification, alias: 'Duplicate'),
      false,
    );
    failing.failReload = false;
    expect(await controller.reload(), true);
    expect(controller.accounts, hasLength(1));
    expect(controller.error, isNull);
  });
  test(
    'successful metadata retry clears the resolved failure notice',
    () async {
      controller.dispose();
      final failing = ReloadFailCloudController(
        store: store,
        secrets: secrets,
        adapterFactory: adapterFactory,
      )..failReload = true;
      controller = failing;
      expect(await controller.initialize(), false);
      expect(controller.needsReload, true);
      expect(controller.error, isNotNull);
      failing.failReload = false;
      expect(await controller.reload(), true);
      expect(controller.needsReload, false);
      expect(controller.error, isNull);
    },
  );
  test('existing security cleanup cannot delete a live cloud secret', () async {
    final account = await add();
    final db = await raw();
    await db.insert('secret_cleanup', {
      'secret_ref': account.secretRef,
      'created_at': cloudTestTime.toIso8601String(),
    });
    final security = SecurityController(store: store, secrets: secrets);
    expect(await security.retryCleanup(), true);
    expect(secrets.values.containsKey(account.secretRef), true);
    security.dispose();
  });
  test(
    'vault unavailable does not invoke adapter and never exposes raw exception',
    () async {
      final account = await add();
      final calls = adapterCalls;
      secrets.failRead = true;
      expect(await controller.refreshAccount(account), isNull);
      expect(adapterCalls, calls);
      expect(controller.error, contains('安全存储'));
      expect(controller.error, isNot(contains('DO-NOT-LEAK')));
      expect(secrets.values.containsKey(account.secretRef), true);
    },
  );
  test(
    'account rename preserves local server and refuses stale second edit',
    () async {
      final account = await add();
      final before = (await store.servers()).single.toMap();
      expect(await controller.renameAccount(account, 'Personal panel'), true);
      expect(controller.accounts.single.alias, 'Personal panel');
      expect((await store.servers()).single.toMap(), before);
      expect(await controller.renameAccount(account, 'Stale alias'), false);
    },
  );
  test(
    'security cleanup skips active cloud vault write until commit',
    () async {
      final verification = (await verify())!;
      secrets.writeStarted = Completer<void>();
      secrets.writeRelease = Completer<void>();
      final save = controller.saveAccount(verification, alias: 'Panel');
      await secrets.writeStarted!.future;
      final security = SecurityController(store: store, secrets: secrets);
      expect(await security.retryCleanup(), true);
      expect(secrets.deletes, 0);
      secrets.writeRelease!.complete();
      expect(await save, true);
      expect(
        secrets.values.containsKey(controller.accounts.single.secretRef),
        true,
      );
      security.dispose();
    },
  );
  test(
    'cloud cleanup skips active SSH credential write until commit',
    () async {
      final security = SecurityController(store: store, secrets: secrets);
      secrets.writeStarted = Completer<void>();
      secrets.writeRelease = Completer<void>();
      final save = security.saveCredential(
        name: 'SSH',
        kind: CredentialKind.password,
        defaultUsername: 'admin',
        secret: 'synthetic-ssh-secret',
      );
      await secrets.writeStarted!.future;
      expect(await controller.retryCleanup(), true);
      expect(secrets.deletes, 0);
      secrets.writeRelease!.complete();
      expect(await save, true);
      expect(
        secrets.values.containsKey(security.credentials.single.secretRef),
        true,
      );
      security.dispose();
    },
  );
}
