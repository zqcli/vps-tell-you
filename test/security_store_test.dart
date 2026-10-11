import 'support/provider_fixture.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/finance/finance_models.dart';
import 'package:vps_tell_you/security/host_trust.dart';
import 'package:vps_tell_you/security/secret_store.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/servers/server_record.dart';

/// Synthetic application contract only, never a native-security verification.
class FakeSecretStore implements SecretStore {
  final values = <String, String>{};
  int reads = 0, writes = 0, deletes = 0;
  bool failWrite = false,
      partialWrite = false,
      failDelete = false,
      wrongRead = false;
  Completer<void>? blockRead;
  @override
  Future<String?> read(String reference) async {
    reads++;
    await blockRead?.future;
    return wrongRead ? 'incorrect synthetic payload' : values[reference];
  }

  @override
  Future<void> write(String reference, String value) async {
    writes++;
    if (partialWrite) values[reference] = value;
    if (failWrite) throw StateError('DO-NOT-LEAK-$value');
    values[reference] = value;
  }

  @override
  Future<void> delete(String reference) async {
    deletes++;
    if (failDelete) throw StateError('DO-NOT-LEAK-secret');
    values.remove(reference);
  }
}

class FakeDeviceAuth implements DeviceAuthenticator {
  bool allowed = true;
  int calls = 0, cancellations = 0;
  Completer<bool>? pending;
  @override
  Future<bool> authenticate() async {
    calls++;
    return pending == null ? allowed : await pending!.future;
  }

  @override
  Future<void> cancel() async {
    cancellations++;
  }
}

HostKeyIdentity hostKey({
  int seed = 1,
  String host = ' Example.TEST. ',
  int port = 22,
}) {
  final algorithm = utf8.encode('ssh-ed25519');
  final blob = BytesBuilder()
    ..add((ByteData(4)..setUint32(0, algorithm.length)).buffer.asUint8List())
    ..add(algorithm)
    ..add((ByteData(4)..setUint32(0, 32)).buffer.asUint8List())
    ..add(List.filled(32, seed));
  return HostKeyIdentity.validated(
    host: host,
    port: port,
    algorithm: 'ssh-ed25519',
    publicKey: base64Encode(blob.toBytes()),
  );
}

class FailingMetadataController extends SecurityController {
  FailingMetadataController({
    required super.store,
    required super.secrets,
    required super.authenticator,
  });
  bool fail = false;
  @override
  Future<void> readMetadata() async {
    if (fail) throw StateError('synthetic metadata reload failure');
    await super.readMetadata();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 6);
  late Directory directory;
  late String path;
  late LedgerStore store;
  late SecurityController controller;
  late FakeSecretStore secrets;
  late FakeDeviceAuth auth;
  Future<Database> raw() => databaseFactoryFfiNoIsolate.openDatabase(path);
  SecurityController makeController({
    Duration duration = const Duration(seconds: 20),
  }) => SecurityController(
    store: store,
    secrets: secrets,
    authenticator: auth,
    revealDuration: duration,
  );
  Future<bool> save({
    CredentialMetadata? existing,
    String name = 'Example password',
    String username = 'root',
    String? secret = 'synthetic-password',
  }) => controller.saveCredential(
    existing: existing,
    name: name,
    kind: CredentialKind.password,
    defaultUsername: username,
    secret: secret,
  );
  Future<void> reopen() async {
    controller.dispose();
    await store.close();
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => now,
    );
    controller = makeController();
    await controller.initialize();
  }

  Future<ServerRecord> addServer(String id) async {
    final record = ServerRecord(
      id: id,
      name: id,
      vendor: 'Synthetic',
      createdAt: now,
      updatedAt: now,
      host: '192.0.2.1',
      billing: BillingKind.prepaid,
      amountMinor: 1200,
      startDate: const LedgerDate(2026, 1, 1),
      dueDate: const LedgerDate(2027, 1, 1),
    );
    await store.saveServer(record, isNew: true);
    return (await store.servers()).singleWhere((s) => s.id == id);
  }

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('security-synthetic-');
    path = '${directory.path}/ledger.sqlite3';
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => now,
    );
    secrets = FakeSecretStore();
    auth = FakeDeviceAuth();
    controller = makeController();
    await controller.initialize();
  });
  tearDown(() async {
    controller.dispose();
    await store.close();
    await directory.delete(recursive: true);
    debugDefaultTargetPlatformOverride = null;
  });

  test('committed save with failed reload remains successful and blocks duplicates until reload', () async {
    controller.dispose();
    final failing = FailingMetadataController(
      store: store,
      secrets: secrets,
      authenticator: auth,
    );
    controller = failing;
    await controller.initialize();
    failing.fail = true;
    expect(await save(), isTrue);
    expect(controller.needsReload, isTrue);
    expect((await store.credentials()), hasLength(1));
    expect(await save(), isFalse);
    expect(secrets.writes, 1);
    failing.fail = false;
    expect(await controller.reload(), isTrue);
    expect(controller.needsReload, isFalse);
    expect(controller.credentials, hasLength(1));
  });

  test('encrypted key import keeps key and passphrase out of SQLite and rejects passphrase-only edit', () async {
    final key = await File('test/fixtures/security/ed25519_encrypted.fixture')
        .readAsString();
    expect(
      await controller.saveCredential(
        name: 'Synthetic key',
        kind: CredentialKind.privateKey,
        defaultUsername: 'root',
        secret: key,
        passphrase: 'fixture-passphrase-only',
        savePassphrase: true,
      ),
      isTrue,
    );
    final original = controller.credentials.single;
    final writes = secrets.writes;
    expect(
      await controller.saveCredential(
        existing: original,
        name: original.name,
        kind: original.kind,
        defaultUsername: 'root',
        passphrase: 'ignored-secret',
      ),
      isFalse,
    );
    expect(controller.error, contains('重新导入'));
    expect(controller.error, isNot(contains('ignored-secret')));
    expect(secrets.writes, writes);
    expect((await store.credentials()).single.revision, 0);
    final sqliteBytes = latin1.decode(await File(path).readAsBytes());
    expect(sqliteBytes, isNot(contains('fixture-passphrase-only')));
    expect(sqliteBytes, isNot(contains('PRIVATE KEY')));
    expect(await controller.reveal(original), isTrue);
    expect(controller.revealedSecret, key);
    expect(controller.revealedPassphrase, 'fixture-passphrase-only');
    controller.hideSensitive();
  });

  test('cancelled unresolved auth permits another request; late old success cannot unlock newer pending request', () async {
    await save();
    final record = controller.credentials.single;
    final oldAuth = Completer<bool>();
    auth.pending = oldAuth;
    final oldReveal = controller.reveal(record);
    await Future<void>.delayed(Duration.zero);
    controller.hideSensitive();
    expect(controller.busy, isFalse);
    final newAuth = Completer<bool>();
    auth.pending = newAuth;
    final newReveal = controller.reveal(record);
    await Future<void>.delayed(Duration.zero);
    oldAuth.complete(true);
    expect(await oldReveal, isFalse);
    expect(controller.authenticating, isTrue);
    expect(controller.revealedSecret, isNull);
    newAuth.complete(true);
    expect(await newReveal, isTrue);
    expect(controller.revealedSecret, 'synthetic-password');
    expect(controller.busy, isFalse);
  });

  test('cancel while trust transaction queued prevents pin write and authentication', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final held = (await raw()).transaction((txn) async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    final attempt = controller.beginHostVerification(hostKey());
    final pending = attempt.confirm();
    attempt.cancel();
    release.complete();
    await held;
    expect(await pending, isFalse);
    expect(await store.hostTrusts(), isEmpty);
    var calls = 0;
    expect(
      await attempt.authenticate(() async {
        calls++;
      }),
      isFalse,
    );
    expect(calls, 0);
  });

  test('ABA same key and fixed clock cannot revive a stale delete or replacement snapshot', () async {
    final key = hostKey();
    await controller.verifyHost(key);
    final old = controller.hostTrusts.single;
    await controller.removeHostTrust(old);
    await controller.verifyHost(key);
    expect(controller.hostTrusts.single.generation, isNot(old.generation));
    expect(await controller.removeHostTrust(old), isFalse);
    expect(
      await controller.verifyHost(hostKey(seed: 2), expected: old),
      isFalse,
    );
    expect((await store.hostTrusts()).single.publicKey, key.publicKey);
  });

  test(
    'cancel while credential metadata read is pending starts no secret read',
    () async {
      await save();
      final record = controller.credentials.single;
      final baseline = secrets.reads;
      final entered = Completer<void>();
      final release = Completer<void>();
      final held = (await raw()).transaction((txn) async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final pending = controller.reveal(record);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.hideSensitive();
      release.complete();
      await held;
      expect(await pending, isFalse);
      expect(secrets.reads, baseline);
      expect(controller.revealedSecret, isNull);
    },
  );

  test('native-only metadata storage and search survive restart; SQLite has no secret payload', () async {
    expect(await save(), isTrue);
    final first = controller.credentials.single;
    expect(secrets.values[first.secretRef], contains('synthetic-password'));
    expect(controller.searchCredentials('ROOT').single.id, first.id);
    expect(controller.searchCredentials('synthetic-password'), isEmpty);
    expect(controller.cleanupPending, isFalse);
    await reopen();
    expect(controller.credentials.single.id, first.id);
    expect(await (await raw()).getVersion(), LedgerStore.schemaVersion);
    expect(
      latin1.decode(await File(path).readAsBytes()),
      isNot(contains('synthetic-password')),
    );
    expect((await raw()).isOpen, isTrue);
  });

  test('write and partial write failures preserve original; orphan journal recovers after restart', () async {
    expect(await save(), isTrue);
    final old = controller.credentials.single;
    secrets.failWrite = true;
    secrets.partialWrite = true;
    expect(await save(existing: old, secret: 'synthetic-new-secret'), isFalse);
    expect(controller.error, isNot(contains('synthetic-new-secret')));
    expect(controller.credentials.single.secretRef, old.secretRef);
    expect(secrets.values, hasLength(2));
    expect(controller.cleanupPending, isTrue);
    final deletes = secrets.deletes;
    await reopen();
    expect(secrets.deletes, deletes, reason: 'startup is read-only');
    secrets.failWrite = false;
    expect(await controller.retryCleanup(), isTrue);
    expect(secrets.values.keys, [old.secretRef]);
    expect((await store.credentials()).single.secretRef, old.secretRef);
  });

  test('write read-back mismatch never commits metadata and cleanup is recoverable', () async {
    secrets.wrongRead = true;
    expect(await save(), isFalse);
    expect(await store.credentials(), isEmpty);
    expect(await store.pendingSecretCleanup(), hasLength(1));
    expect(secrets.values, hasLength(1));
    secrets.wrongRead = false;
    expect(await controller.retryCleanup(), isTrue);
    expect(secrets.values, isEmpty);
  });

  test('reservation failure performs zero native writes', () async {
    await (await raw()).execute(
      "CREATE TRIGGER fail_reserve BEFORE INSERT ON secret_cleanup BEGIN SELECT RAISE(FAIL, 'synthetic failure'); END",
    );
    expect(await save(), isFalse);
    expect(secrets.writes, 0);
    expect(await store.credentials(), isEmpty);
  });

  test('metadata final step failure rolls back update and old cleanup; new secret remains journaled', () async {
    expect(await save(), isTrue);
    final old = controller.credentials.single;
    await (await raw()).execute(
      "CREATE TRIGGER fail_cleanup BEFORE INSERT ON secret_cleanup WHEN NEW.secret_ref = '${old.secretRef}' BEGIN SELECT RAISE(FAIL, 'synthetic failure'); END",
    );
    expect(await save(existing: old, secret: 'synthetic-next'), isFalse);
    expect((await store.credentials()).single.secretRef, old.secretRef);
    expect((await store.credentials()).single.revision, old.revision);
    expect(await store.pendingSecretCleanup(), hasLength(1));
    expect(secrets.values, hasLength(2));
    await (await raw()).execute('DROP TRIGGER fail_cleanup');
    await reopen();
    expect(await controller.retryCleanup(), isTrue);
    expect(secrets.values.keys, [old.secretRef]);
  });

  test('cleanup failure is successful save with durable pending cleanup; restart retry safe', () async {
    expect(await save(), isTrue);
    final old = controller.credentials.single;
    secrets.failDelete = true;
    expect(await save(existing: old, secret: 'synthetic-next'), isTrue);
    final updated = controller.credentials.single;
    expect(updated.secretRef, isNot(old.secretRef));
    expect(updated.revision, 1);
    expect(controller.cleanupPending, isTrue);
    await reopen();
    expect(await controller.retryCleanup(), isFalse);
    secrets.failDelete = false;
    expect(await controller.retryCleanup(), isTrue);
    expect(secrets.values.keys, [updated.secretRef]);
  });

  test('cleanup journal completion failure and stale referenced entry never remove live secret', () async {
    expect(await save(), isTrue);
    final live = controller.credentials.single;
    await (await raw()).insert('secret_cleanup', {
      'secret_ref': live.secretRef,
      'created_at': now.toIso8601String(),
    });
    await store.reserveSecret('synthetic-orphan');
    secrets.values['synthetic-orphan'] = 'synthetic orphan';
    await (await raw()).execute(
      "CREATE TRIGGER fail_finish BEFORE DELETE ON secret_cleanup BEGIN SELECT RAISE(FAIL, 'synthetic failure'); END",
    );
    expect(await controller.retryCleanup(), isFalse);
    expect(secrets.values.keys, [live.secretRef]);
    expect(await store.pendingSecretCleanup(), hasLength(2));
    await (await raw()).execute('DROP TRIGGER fail_finish');
    expect(await controller.retryCleanup(), isTrue);
    expect(secrets.values.keys, [live.secretRef]);
  });

  test('metadata revision, delete conflict, replacement and detach preserve every explicit username', () async {
    await addServer('a');
    await addServer('b');
    expect(await save(), isTrue);
    final old = controller.credentials.single;
    expect(
      await save(
        name: 'Other',
        username: 'different',
        secret: 'synthetic-other',
      ),
      isTrue,
    );
    final replacement = controller.credentials.singleWhere(
      (c) => c.id != old.id,
    );
    for (final id in ['a', 'b']) {
      expect(
        await controller.saveSshConfiguration(
          SshConfiguration(
            serverId: id,
            host: ' EXAMPLE.TEST. ',
            username: id == 'a' ? 'root' : 'custom',
            credentialId: old.id,
          ),
        ),
        isTrue,
      );
    }
    final a = controller.configFor('a')!;
    expect(
      await save(existing: old, secret: null, username: 'new-default'),
      isTrue,
    );
    expect(controller.configFor('a')!.username, 'root');
    expect(
      await controller.deleteCredential(old),
      isFalse,
      reason: 'stale revision',
    );
    expect(controller.referencesTo(old.id), hasLength(2));
    final current = controller.credentials.singleWhere((c) => c.id == old.id);
    expect(
      await controller.deleteCredential(current, replacementId: replacement.id),
      isTrue,
    );
    expect(controller.configFor('a')!.username, 'root');
    expect(controller.configFor('b')!.username, 'custom');
    expect(controller.referencesTo(replacement.id), hasLength(2));
    expect(
      await controller.saveSshConfiguration(a),
      isFalse,
      reason: 'stale config cannot restore deleted credential',
    );
    expect(await controller.deleteCredential(replacement), isTrue);
    expect(
      controller.sshConfigurations.every((c) => c.credentialId == null),
      isTrue,
    );
    expect(controller.configFor('a')!.username, 'root');
    expect((await store.servers()).every((s) => s.revision == 0), isTrue);
    expect((await store.servicePeriods()), hasLength(2));
  });

  test('invalid SSH inputs fail without adopting a default username or modifying ledger host', () async {
    await addServer('a');
    await save();
    final credential = controller.credentials.single;
    expect(
      await controller.saveSshConfiguration(
        SshConfiguration(
          serverId: 'a',
          host: 'example.test',
          username: '',
          credentialId: credential.id,
        ),
      ),
      isFalse,
    );
    expect(
      await controller.saveSshConfiguration(
        const SshConfiguration(
          serverId: 'a',
          host: 'ssh://example.test',
          username: 'root',
        ),
      ),
      isFalse,
    );
    expect(controller.sshConfigurations, isEmpty);
    expect((await store.servers()).single.host, '192.0.2.1');
  });

  test('delete transaction rollback preserves all credential references and stored secrets', () async {
    await addServer('a');
    await save();
    final credential = controller.credentials.single;
    await controller.saveSshConfiguration(
      SshConfiguration(
        serverId: 'a',
        host: 'example.test',
        username: 'root',
        credentialId: credential.id,
      ),
    );
    await (await raw()).execute(
      "CREATE TRIGGER fail_delete BEFORE DELETE ON credentials BEGIN SELECT RAISE(FAIL, 'synthetic failure'); END",
    );
    expect(await controller.deleteCredential(credential), isFalse);
    expect(
      (await store.sshConfigurations()).single.credentialId,
      credential.id,
    );
    expect((await store.sshConfigurations()).single.revision, 0);
    expect(secrets.values.keys, [credential.secretRef]);
    expect(await store.pendingSecretCleanup(), isEmpty);
  });

  test('v2 to v3 preserves finance and ledger; v1 sequential migration covered in finance regression', () async {
    final server = await addServer('a');
    final before = (await store.servicePeriods()).single.toMap();
    final payment = await store.recordAccountPayment(
      id: 'historic',
      accountLabel: 'Synthetic account',
      amount: const Money('EUR', 1234),
      paidDate: const LedgerDate(2026, 10, 1),
    );
    const fx = FxSettings(
      displayCurrency: 'EUR',
      usdToCny: '7.12',
      eurToCny: '7.80',
      rateDate: LedgerDate(2026, 10, 1),
    );
    await store.saveFx(fx);
    final db = await raw();
    await removeProviderSchema(db);
    for (final table in [
      'ssh_configurations',
      'credentials',
      'host_trust',
      'secret_cleanup',
      'snippets',
    ]) {
      await db.execute('DROP TABLE $table');
    }
    await db.execute('DROP TRIGGER server_reminder');
    await db.execute('DROP TABLE reminder_rules');
    await db.execute('DROP TABLE app_settings');
    await db.execute('ALTER TABLE servers DROP COLUMN resources_json');
    await db.setVersion(2);
    await reopen();
    expect(
      legacyProviderProjection((await store.servers()).single.toMap()),
      legacyProviderProjection(server.toMap()),
    );
    expect((await store.servicePeriods()).single.toMap(), before);
    expect((await store.payments()).single.toMap(), payment.toMap());
    expect((await store.fxSettings()).toMap(), fx.toMap());
    expect(await store.credentials(), isEmpty);
    expect(await (await raw()).getVersion(), LedgerStore.schemaVersion);
  });

  test('device reject or unsupported Linux never reads a secret', () async {
    await save();
    final baseline = secrets.reads;
    auth.allowed = false;
    expect(await controller.reveal(controller.credentials.single), isFalse);
    expect(secrets.reads, baseline);
    controller.dispose();
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    controller = SecurityController(store: store, secrets: secrets);
    await controller.initialize();
    expect(await controller.reveal(controller.credentials.single), isFalse);
    expect(secrets.reads, baseline);
    expect(controller.revealedSecret, isNull);
    expect(controller.error, contains('不支持'));
  });

  test(
    'cancel/background/dispose invalidate pending auth and late storage reads',
    () async {
      await save();
      final record = controller.credentials.single;
      final baseline = secrets.reads;
      auth.pending = Completer<bool>();
      final pending = controller.reveal(record);
      await Future<void>.delayed(Duration.zero);
      controller.hideSensitive();
      auth.pending!.complete(true);
      expect(await pending, isFalse);
      expect(secrets.reads, baseline);
      auth.pending = null;
      secrets.blockRead = Completer<void>();
      final reading = controller.reveal(record);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.hideSensitive();
      secrets.blockRead!.complete();
      expect(await reading, isFalse);
      expect(controller.revealedSecret, isNull);
      secrets.blockRead = null;
      auth.pending = Completer<bool>();
      final disposing = controller.reveal(record);
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      auth.pending!.complete(true);
      expect(await disposing, isFalse);
      controller = makeController();
    },
  );

  test('reveal expires; transient inactive only hides display without cancelling OS authentication', () async {
    await save();
    final record = controller.credentials.single;
    controller.dispose();
    controller = makeController(duration: const Duration(milliseconds: 20));
    await controller.initialize();
    auth.pending = Completer<bool>();
    final pending = controller.reveal(record);
    await Future<void>.delayed(Duration.zero);
    controller.hideDisplayedSensitive();
    auth.pending!.complete(true);
    expect(await pending, isTrue);
    expect(controller.revealedSecret, 'synthetic-password');
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(controller.revealedSecret, isNull);
    expect(controller.revealedPassphrase, isNull);
  });

  test('first-use rejection and cancel prevent authentication; trusted full-key match alone permits callback', () async {
    final key = hostKey();
    var calls = 0;
    Future<void> authenticate() async {
      calls++;
    }

    expect(await controller.checkHost(key), HostTrustStatus.firstUse);
    final unknown = controller.beginHostVerification(key);
    expect(await unknown.authenticate(authenticate), isFalse);
    final rejected = controller.beginHostVerification(key)..reject();
    expect(await rejected.confirm(), isFalse);
    expect(await rejected.authenticate(authenticate), isFalse);
    final accepted = controller.beginHostVerification(key);
    expect(await accepted.confirm(), isTrue);
    expect(await accepted.authenticate(authenticate), isTrue);
    expect(
      await accepted.authenticate(authenticate),
      isFalse,
      reason: 'single use',
    );
    expect(calls, 1);
    final cancelled = controller.beginHostVerification(key);
    final pending = cancelled.authenticate(authenticate);
    cancelled.cancel();
    expect(await pending, isFalse);
    expect(calls, 1);
    final background = controller.beginHostVerification(key);
    controller.hideSensitive();
    expect(await background.authenticate(authenticate), isFalse);
  });

  test('changed host key and separate port block until explicit revision guarded reverify', () async {
    final key = hostKey();
    final changed = hostKey(seed: 2);
    var calls = 0;
    Future<void> authenticate() async {
      calls++;
    }

    expect(await controller.verifyHost(key), isTrue);
    final old = controller.hostTrusts.single;
    expect(await controller.checkHost(changed), HostTrustStatus.changed);
    expect(
      await controller
          .beginHostVerification(changed)
          .authenticate(authenticate),
      isFalse,
    );
    expect(
      await controller.checkHost(hostKey(port: 2222)),
      HostTrustStatus.firstUse,
    );
    expect(
      await controller.verifyHost(changed),
      isFalse,
      reason: 'no expected revision cannot overwrite',
    );
    final accepted = controller.beginHostVerification(changed);
    expect(await accepted.confirm(expected: old), isTrue);
    expect(await accepted.authenticate(authenticate), isTrue);
    expect(
      await controller.verifyHost(key, expected: old),
      isFalse,
      reason: 'stale reverify',
    );
    expect(await controller.checkHost(key), HostTrustStatus.changed);
    expect(calls, 1);
    await reopen();
    expect(controller.hostTrusts.single.publicKey, changed.publicKey);
    expect(await controller.removeHostTrust(old), isFalse);
  });
}
