import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/connections/ssh_service.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/security/host_trust.dart';
import 'package:vps_tell_you/security/secret_store.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';

import 'support/ssh_fixture.dart';

class _Secrets implements SecretStore {
  final values = <String, String>{};
  int reads = 0;
  Completer<void>? holdRead;
  bool failRead = false;

  @override
  Future<String?> read(String reference) async {
    reads++;
    await holdRead?.future;
    if (failRead) throw StateError('synthetic-password-only PRIVATE KEY');
    return values[reference];
  }

  @override
  Future<void> write(String reference, String value) async {
    values[reference] = value;
  }

  @override
  Future<void> delete(String reference) async {
    values.remove(reference);
  }
}

class _NoDeviceAuth implements DeviceAuthenticator {
  @override
  Future<bool> authenticate() async => false;
  @override
  Future<void> cancel() async {}
}

void main() {
  late Directory directory;
  late LedgerStore store;
  late SecurityController security;
  late NativeSshService service;
  late _Secrets secrets;
  final fixtures = <SshFixture>[];
  final output = StringBuffer();
  StreamSubscription<String>? outputSubscription;

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('ssh-protocol-test-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.db',
    );
    secrets = _Secrets();
    security = SecurityController(
      store: store,
      secrets: secrets,
      authenticator: _NoDeviceAuth(),
    );
    await security.initialize();
    service = NativeSshService(security: security);
    output.clear();
    outputSubscription = service.output.listen(output.write);
  });

  tearDown(() async {
    if (secrets.holdRead != null && !secrets.holdRead!.isCompleted) {
      secrets.holdRead!.complete();
    }
    service.dispose();
    await outputSubscription?.cancel();
    for (final fixture in fixtures) {
      await fixture.close();
    }
    fixtures.clear();
    security.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<SshFixture> fixture({
    Duration delayAuth = Duration.zero,
    String hostKey = 'ed25519.fixture',
  }) async {
    final result = await SshFixture.start(
      delayAuth: delayAuth,
      hostKey: hostKey,
    );
    fixtures.add(result);
    return result;
  }

  Future<String> credential({
    String password = 'synthetic-password-only',
    String? privateKey,
    String? passphrase,
    bool savePassphrase = false,
  }) async {
    expect(
      await security.saveCredential(
        name: 'Synthetic SSH fixture',
        kind: privateKey == null
            ? CredentialKind.password
            : CredentialKind.privateKey,
        defaultUsername: 'fixture',
        secret: privateKey == null
            ? password
            : File('test/fixtures/security/$privateKey').readAsStringSync(),
        passphrase: passphrase,
        savePassphrase: savePassphrase,
      ),
      isTrue,
      reason: security.error,
    );
    secrets.reads = 0;
    return security.credentials.last.id;
  }

  SshTarget target(SshFixture fixture, String credentialId) => SshTarget(
    name: 'Loopback fixture',
    host: '127.0.0.1',
    port: fixture.port,
    username: 'fixture',
    credentialId: credentialId,
  );

  Future<bool> accept(HostVerificationRequest request) async => true;

  test('first host gates every auth byte until accepted', () async {
    final remote = await fixture();
    final id = await credential();
    final permission = Completer<bool>();
    HostVerificationRequest? request;
    final connecting = service.connect(
      target(remote, id),
      verifyHost: (value) {
        request = value;
        return permission.future;
      },
      requestKeyPassphrase: (_) async =>
          fail('Password credentials must never request a key passphrase'),
    );
    await eventually(() => request != null);
    expect(request!.status, HostTrustStatus.firstUse);
    expect(request!.identity.publicKey, remote.identity.publicKey);
    expect(request!.identity.fingerprint, remote.identity.fingerprint);
    expect(request!.previous, isNull);
    expect(service.status, SshStatus.verifying);
    expect(secrets.reads, 1);
    expect(remote.of('auth_begin'), isEmpty);
    expect(remote.of('password'), isEmpty);
    permission.complete(true);
    await connecting;
    expect(service.status, SshStatus.connected, reason: service.error);
    await remote.waitFor('authenticated');
    expect(secrets.reads, 1);
    expect(await security.checkHost(remote.identity), HostTrustStatus.trusted);
  });

  test(
    'rejecting first host closes socket and never transmits credentials',
    () async {
      final remote = await fixture();
      final id = await credential();
      await service.connect(target(remote, id), verifyHost: (_) async => false);
      await remote.waitFor('closed');
      expect(service.connected, isFalse);
      expect(secrets.reads, 1);
      expect(remote.of('auth_begin'), isEmpty);
      expect(await store.hostTrusts(), isEmpty);
    },
  );

  test(
    'trusted host authenticates without another verification prompt',
    () async {
      final remote = await fixture();
      final id = await credential();
      expect(await security.verifyHost(remote.identity), isTrue);
      var prompts = 0;
      await service.connect(
        target(remote, id),
        verifyHost: (_) async {
          prompts++;
          return false;
        },
      );
      expect(service.connected, isTrue, reason: service.error);
      expect(prompts, 0);
      expect(remote.of('authenticated'), hasLength(1));
    },
  );

  test(
    'changed host rejected before auth preserves previously trusted key',
    () async {
      final remote = await fixture();
      final id = await credential();
      final oldKey = HostKeyIdentity.validated(
        host: '127.0.0.1',
        port: remote.port,
        algorithm: 'ssh-rsa',
        publicKey: File('test/fixtures/security/rsa.fixture.pub')
            .readAsStringSync()
            .trim(),
      );
      expect(await security.verifyHost(oldKey), isTrue);
      HostVerificationRequest? request;
      await service.connect(
        target(remote, id),
        verifyHost: (value) async {
          request = value;
          return false;
        },
      );
      await remote.waitFor('closed');
      expect(request!.status, HostTrustStatus.changed);
      expect(request!.previous!.publicKey, oldKey.publicKey);
      expect(request!.identity.publicKey, remote.identity.publicKey);
      expect(secrets.reads, 1);
      expect(remote.of('auth_begin'), isEmpty);
      expect((await store.hostTrusts()).single.publicKey, oldKey.publicKey);
    },
  );

  test(
    'wrong password fails cleanly without leaking secret or opening shell',
    () async {
      final remote = await fixture();
      final id = await credential(password: 'synthetic-wrong-password');
      await service.connect(target(remote, id), verifyHost: accept);
      await remote.waitFor('closed');
      expect(service.status, SshStatus.failed);
      expect(remote.of('password').every((e) => e['valid'] == false), isTrue);
      expect(remote.of('password'), isNotEmpty);
      expect(remote.of('authenticated'), isEmpty);
      expect(remote.of('shell'), isEmpty);
      expect(service.error, isNot(contains('synthetic-wrong-password')));
      expect(output.toString(), isNot(contains('synthetic-wrong-password')));
    },
  );

  test('encrypted private key authenticates over real SSH protocol', () async {
    final remote = await fixture();
    final id = await credential(
      privateKey: 'ed25519_encrypted.fixture',
      passphrase: 'fixture-passphrase-only',
      savePassphrase: true,
    );
    await service.connect(
      target(remote, id),
      verifyHost: accept,
      requestKeyPassphrase: (_) async =>
          fail('An explicitly stored passphrase must not prompt again'),
    );
    expect(service.connected, isTrue, reason: service.error);
    await remote.waitFor('authenticated');
    expect(remote.of('public_key'), isNotEmpty);
    expect(remote.of('public_key').every((e) => e['valid'] == true), isTrue);
    expect(remote.of('password'), isEmpty);
    expect(output.toString(), isNot(contains('PRIVATE KEY')));
    expect(output.toString(), isNot(contains('fixture-passphrase-only')));
  });

  test(
    'unrecognized private key is rejected with no password fallback',
    () async {
      final remote = await fixture();
      final id = await credential(privateKey: 'rsa.fixture');
      await service.connect(
        target(remote, id),
        verifyHost: accept,
        requestKeyPassphrase: (_) async =>
            fail('An unencrypted key must not request a passphrase'),
      );
      await remote.waitFor('closed');
      expect(service.status, SshStatus.failed);
      expect(remote.of('public_key'), isNotEmpty);
      expect(remote.of('public_key').every((e) => e['valid'] == false), isTrue);
      expect(remote.of('password'), isEmpty);
      expect(remote.of('authenticated'), isEmpty);
    },
  );

  test(
    'PTY resize, fragmented UTF8, stderr and input cross actual channel',
    () async {
      final remote = await fixture();
      final id = await credential();
      service.resize(91, 29);
      await service.connect(target(remote, id), verifyHost: accept);
      expect(service.connected, isTrue, reason: service.error);
      final pty = await remote.waitFor('pty');
      expect(pty['columns'], 91);
      expect(pty['rows'], 29);
      service.resize(117, 43);
      await remote.waitFor(
        'resize',
        where: (e) => e['columns'] == 117 && e['rows'] == 43,
      );
      await eventually(() => output.toString().contains('fixture-stderr'));
      service.write('synthetic-input-你好\r');
      final input = await remote.waitFor('input');
      expect(
        utf8.decode(base64Decode(input['data'] as String)),
        'synthetic-input-你好\r',
      );
      await eventually(() => output.toString().contains('fixture-stderr'));
      expect(output.toString(), contains('你好'));
      expect(output.toString(), isNot(contains('\uFFFD')));
      await eventually(
        () => output.toString().contains('echo:synthetic-input-你好\r'),
      );
    },
  );

  test(
    'cancel while host prompt is open invalidates its late acceptance',
    () async {
      final remote = await fixture();
      final id = await credential();
      final permission = Completer<bool>();
      var prompted = false;
      final connecting = service.connect(
        target(remote, id),
        verifyHost: (_) {
          prompted = true;
          return permission.future;
        },
      );
      await eventually(() => prompted);
      service.disconnect();
      permission.complete(true);
      await connecting.timeout(const Duration(seconds: 2));
      await remote.waitFor('closed');
      expect(service.connected, isFalse);
      expect(secrets.reads, 1);
      expect(remote.of('auth_begin'), isEmpty);
      expect(await store.hostTrusts(), isEmpty);
    },
  );

  test(
    'cancelling an outstanding secret read prevents late authentication',
    () async {
      final remote = await fixture();
      final id = await credential();
      secrets.holdRead = Completer<void>();
      final connecting = service.connect(
        target(remote, id),
        verifyHost: accept,
      );
      await eventually(() => secrets.reads == 1);
      service.disconnect();
      secrets.holdRead!.complete();
      secrets.holdRead = null;
      await connecting.timeout(const Duration(seconds: 2));
      expect(remote.of('connection'), isEmpty);
      expect(service.connected, isFalse);
      expect(remote.of('password'), isEmpty);
      expect(remote.of('public_key'), isEmpty);
      expect(remote.of('authenticated'), isEmpty);
    },
  );

  test(
    'authentication timeout terminates socket without opening a shell',
    () async {
      final remote = await fixture(delayAuth: const Duration(seconds: 2));
      final id = await credential();
      service.dispose();
      await outputSubscription?.cancel();
      service = NativeSshService(
        security: security,
        authTimeout: const Duration(milliseconds: 200),
      );
      outputSubscription = service.output.listen(output.write);
      await service.connect(target(remote, id), verifyHost: accept);
      expect(service.status, SshStatus.failed);
      await remote.waitFor('closed');
      expect(remote.of('shell'), isEmpty);
      expect(service.error, isNot(contains('synthetic-password-only')));
    },
  );

  test(
    'handshake timeout terminates silent peer without authenticating',
    () async {
      final silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final peers = <Socket>[];
      silent.listen(peers.add);
      addTearDown(() async {
        for (final peer in peers) {
          peer.destroy();
        }
        await silent.close();
      });
      final id = await credential();
      service.dispose();
      await outputSubscription?.cancel();
      service = NativeSshService(
        security: security,
        handshakeTimeout: const Duration(milliseconds: 150),
      );
      outputSubscription = service.output.listen(output.write);
      await service.connect(
        SshTarget(
          name: 'Silent loopback',
          host: '127.0.0.1',
          port: silent.port,
          username: 'fixture',
          credentialId: id,
        ),
        verifyHost: accept,
      );
      expect(service.status, SshStatus.failed);
      expect(secrets.reads, 1);
    },
  );

  test(
    'disconnect and reconnect do not replay prior input or auto-reconnect',
    () async {
      final remote = await fixture();
      final id = await credential();
      await service.connect(target(remote, id), verifyHost: accept);
      service.write('inert-marker-one\r');
      await remote.waitFor('input');
      final beforeGeneration = service.generation;
      await remote.disconnectClients();
      await eventually(() => !service.connected);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(remote.of('connection'), hasLength(1));
      service.write('must-not-queue\r');
      await service.connect(target(remote, id), verifyHost: accept);
      expect(service.connected, isTrue, reason: service.error);
      expect(service.generation, greaterThan(beforeGeneration));
      service.write('inert-marker-two\r');
      await remote.waitFor('input', where: (e) => e['connection'] == 2);
      final input = remote
          .of('input')
          .map((e) => utf8.decode(base64Decode(e['data'] as String)))
          .join();
      expect('inert-marker-one'.allMatches(input), hasLength(1));
      expect('inert-marker-two'.allMatches(input), hasLength(1));
      expect(input, isNot(contains('must-not-queue')));
      service.disconnect();
      await remote.waitFor('closed', where: (e) => e['connection'] == 2);
      expect(service.connected, isFalse);
    },
  );

  test(
    'secret-store failure is redacted and never emits authentication',
    () async {
      final remote = await fixture();
      final id = await credential();
      secrets.failRead = true;
      await service.connect(target(remote, id), verifyHost: accept);
      expect(remote.of('connection'), isEmpty);
      expect(service.status, SshStatus.failed);
      expect(service.error, isNot(contains('synthetic-password-only')));
      expect(service.error, isNot(contains('PRIVATE KEY')));
      expect(remote.of('password'), isEmpty);
      expect(remote.of('public_key'), isEmpty);
    },
  );

  for (final key in ['rsa.fixture', 'ecdsa.fixture']) {
    test('$key host signature binds to the displayed complete key', () async {
      final remote = await fixture(hostKey: key);
      final id = await credential();
      HostVerificationRequest? request;
      await service.connect(
        target(remote, id),
        verifyHost: (value) async {
          request = value;
          return true;
        },
      );
      expect(service.connected, isTrue, reason: service.error);
      expect(request!.identity.publicKey, remote.identity.publicKey);
      expect(request!.identity.algorithm, remote.identity.algorithm);
      expect(request!.identity.fingerprint, remote.identity.fingerprint);
      await remote.waitFor('authenticated');
    });
  }

  test(
    'replaced connection cannot authorize stale host prompt or replay',
    () async {
      final remote = await fixture();
      final id = await credential();
      final oldPermission = Completer<bool>();
      var prompted = false;
      final first = service.connect(
        target(remote, id),
        verifyHost: (_) {
          prompted = true;
          return oldPermission.future;
        },
      );
      await eventually(() => prompted);
      final firstGeneration = service.generation;
      service.write('must-not-queue-before-verification\r');
      await service.connect(target(remote, id), verifyHost: accept);
      expect(service.connected, isTrue, reason: service.error);
      final activeGeneration = service.generation;
      expect(activeGeneration, greaterThan(firstGeneration));
      oldPermission.complete(true);
      await first.timeout(const Duration(seconds: 2));
      expect(service.generation, activeGeneration);
      expect(service.connected, isTrue);
      expect(remote.of('authenticated'), hasLength(1));
      expect(remote.of('authenticated').single['connection'], 2);
      expect(
        remote.of('auth_begin').where((e) => e['connection'] == 1),
        isEmpty,
      );
      expect(remote.of('input'), isEmpty);
      expect(
        (await store.hostTrusts()).single.publicKey,
        remote.identity.publicKey,
      );
    },
  );

  test(
    'verification timeout ignores late approval without trusting host',
    () async {
      final remote = await fixture();
      final id = await credential();
      service.dispose();
      await outputSubscription?.cancel();
      service = NativeSshService(
        security: security,
        verificationTimeout: const Duration(milliseconds: 150),
      );
      outputSubscription = service.output.listen(output.write);
      final permission = Completer<bool>();
      var prompted = false;
      final connecting = service.connect(
        target(remote, id),
        verifyHost: (_) {
          prompted = true;
          return permission.future;
        },
      );
      await eventually(() => prompted);
      await eventually(() => service.status == SshStatus.failed);
      await remote.waitFor('closed');
      expect(remote.of('auth_begin'), isEmpty);
      permission.complete(true);
      await connecting.timeout(const Duration(seconds: 2));
      expect(await store.hostTrusts(), isEmpty);
      expect(service.status, SshStatus.failed);
    },
  );

  test(
    'dispose closes active session, output, and socket without replay',
    () async {
      final remote = await fixture();
      final id = await credential();
      await service.connect(target(remote, id), verifyHost: accept);
      expect(service.connected, isTrue, reason: service.error);
      final outputClosed = service.output.drain<void>();
      service.dispose();
      await outputClosed.timeout(const Duration(seconds: 2));
      await remote.waitFor('session_closed');
      await remote.waitFor('closed');
      service.write('must-not-write-after-dispose\r');
      service.resize(120, 40);
      await service.connect(target(remote, id), verifyHost: accept);
      expect(remote.of('connection'), hasLength(1));
      expect(remote.of('input'), isEmpty);
    },
  );

  test(
    'corrupt encrypted credential fails locally without opening socket',
    () async {
      final remote = await fixture();
      final id = await credential(
        privateKey: 'ed25519_encrypted.fixture',
        passphrase: 'fixture-passphrase-only',
        savePassphrase: true,
      );
      final reference = security.credentials.single.secretRef;
      final payload =
          jsonDecode(secrets.values[reference]!) as Map<String, dynamic>;
      payload['passphrase'] = 'synthetic-wrong-passphrase';
      secrets.values[reference] = jsonEncode(payload);
      await service.connect(target(remote, id), verifyHost: accept);
      expect(service.status, SshStatus.failed);
      expect(remote.of('connection'), isEmpty);
      expect(service.error, isNot(contains('synthetic-wrong-passphrase')));
      expect(service.error, isNot(contains('PRIVATE KEY')));
    },
  );

  test(
    'cancel during encrypted key preparation cannot later open socket',
    () async {
      final remote = await fixture();
      final id = await credential(
        privateKey: 'ed25519_encrypted.fixture',
        passphrase: 'fixture-passphrase-only',
        savePassphrase: true,
      );
      final connecting = service.connect(
        target(remote, id),
        verifyHost: accept,
      );
      await eventually(() => secrets.reads == 1);
      service.disconnect();
      await connecting.timeout(const Duration(seconds: 5));
      expect(service.connected, isFalse);
      expect(remote.of('connection'), isEmpty);
      expect(await store.hostTrusts(), isEmpty);
    },
  );

  test(
    'credential mutation cancels outstanding host approval before auth',
    () async {
      final remote = await fixture();
      final id = await credential();
      final permission = Completer<bool>();
      var prompted = false;
      final connecting = service.connect(
        target(remote, id),
        verifyHost: (_) {
          prompted = true;
          return permission.future;
        },
      );
      await eventually(() => prompted);
      expect(
        await security.saveCredential(
          existing: security.credentials.single,
          name: 'Changed synthetic credential',
          kind: CredentialKind.password,
          defaultUsername: 'fixture',
          secret: 'synthetic-replaced-password',
        ),
        isTrue,
      );
      permission.complete(true);
      await connecting;
      await remote.waitFor('closed');
      expect(service.connected, isFalse);
      expect(remote.of('auth_begin'), isEmpty);
      expect(await store.hostTrusts(), isEmpty);
    },
  );

  test(
    'transient key passphrase is never persisted and prompts on reconnect',
    () async {
      final remote = await fixture();
      final id = await credential(
        privateKey: 'ed25519_encrypted.fixture',
        passphrase: 'fixture-passphrase-only',
      );
      final reference = security.credentials.single.secretRef;
      final stored = secrets.values[reference]!;
      expect(
        (jsonDecode(stored) as Map<String, dynamic>)['passphrase'],
        isNull,
      );
      expect(stored, isNot(contains('fixture-passphrase-only')));
      var prompts = 0;
      Future<String?> passphrase(String name) async {
        expect(name, 'Synthetic SSH fixture');
        prompts++;
        return 'fixture-passphrase-only';
      }

      await service.connect(
        target(remote, id),
        verifyHost: accept,
        requestKeyPassphrase: passphrase,
      );
      expect(service.connected, isTrue, reason: service.error);
      expect(prompts, 1);
      expect(secrets.values[reference], stored);
      service.disconnect();
      await remote.waitFor('closed');
      await service.connect(
        target(remote, id),
        verifyHost: accept,
        requestKeyPassphrase: passphrase,
      );
      expect(service.connected, isTrue, reason: service.error);
      expect(prompts, 2);
      expect(secrets.values[reference], stored);
      expect(remote.of('authenticated'), hasLength(2));
      expect(remote.of('password'), isEmpty);
      expect(output.toString(), isNot(contains('fixture-passphrase-only')));
    },
  );

  test(
    'wrong transient key passphrase fails once without socket or auth',
    () async {
      final remote = await fixture();
      final id = await credential(
        privateKey: 'ed25519_encrypted.fixture',
        passphrase: 'fixture-passphrase-only',
      );
      var prompts = 0;
      await service.connect(
        target(remote, id),
        verifyHost: accept,
        requestKeyPassphrase: (_) async {
          prompts++;
          return 'synthetic-wrong-passphrase';
        },
      );
      expect(prompts, 1);
      expect(service.status, SshStatus.failed);
      expect(remote.of('connection'), isEmpty);
      expect(remote.of('auth_begin'), isEmpty);
      expect(service.error, isNot(contains('synthetic-wrong-passphrase')));
      expect(
        secrets.values.values.single,
        isNot(contains('synthetic-wrong-passphrase')),
      );
    },
  );

  for (final response in <String?>[null, '']) {
    test(
      'cancelled key passphrase (${response == null ? 'null' : 'empty'}) never connects',
      () async {
        final remote = await fixture();
        final id = await credential(
          privateKey: 'ed25519_encrypted.fixture',
          passphrase: 'fixture-passphrase-only',
        );
        var prompts = 0;
        await service.connect(
          target(remote, id),
          verifyHost: accept,
          requestKeyPassphrase: (_) async {
            prompts++;
            return response;
          },
        );
        expect(prompts, 1);
        expect(service.connected, isFalse);
        expect(remote.of('connection'), isEmpty);
        expect(remote.of('auth_begin'), isEmpty);
        expect(
          secrets.values.values.single,
          isNot(contains('fixture-passphrase-only')),
        );
      },
    );
  }

  test(
    'disconnect invalidates a pending transient passphrase and late result',
    () async {
      final remote = await fixture();
      final id = await credential(
        privateKey: 'ed25519_encrypted.fixture',
        passphrase: 'fixture-passphrase-only',
      );
      final permission = Completer<String?>();
      var prompted = false;
      final connecting = service.connect(
        target(remote, id),
        verifyHost: accept,
        requestKeyPassphrase: (_) {
          prompted = true;
          return permission.future;
        },
      );
      await eventually(() => prompted);
      expect(remote.of('connection'), isEmpty);
      service.disconnect();
      final cancelledGeneration = service.generation;
      permission.complete('fixture-passphrase-only');
      await connecting.timeout(const Duration(seconds: 3));
      expect(service.generation, cancelledGeneration);
      expect(service.connected, isFalse);
      expect(remote.of('connection'), isEmpty);
      expect(remote.of('auth_begin'), isEmpty);
      expect(
        secrets.values.values.single,
        isNot(contains('fixture-passphrase-only')),
      );
    },
  );

  test(
    'transient passphrase prompt timeout cannot connect after late return',
    () async {
      final remote = await fixture();
      final id = await credential(
        privateKey: 'ed25519_encrypted.fixture',
        passphrase: 'fixture-passphrase-only',
      );
      service.dispose();
      await outputSubscription?.cancel();
      service = NativeSshService(
        security: security,
        verificationTimeout: const Duration(milliseconds: 150),
      );
      outputSubscription = service.output.listen(output.write);
      final permission = Completer<String?>();
      var prompted = false;
      final connecting = service.connect(
        target(remote, id),
        verifyHost: accept,
        requestKeyPassphrase: (_) {
          prompted = true;
          return permission.future;
        },
      );
      await eventually(() => prompted);
      await eventually(() => service.status == SshStatus.failed);
      expect(remote.of('connection'), isEmpty);
      permission.complete('fixture-passphrase-only');
      await connecting.timeout(const Duration(seconds: 3));
      expect(service.status, SshStatus.failed);
      expect(remote.of('connection'), isEmpty);
      expect(
        secrets.values.values.single,
        isNot(contains('fixture-passphrase-only')),
      );
    },
  );

  test(
    'final stdout and stderr are drained before remote close is reported',
    () async {
      final remote = await fixture();
      final id = await credential();
      await service.connect(target(remote, id), verifyHost: accept);
      expect(service.connected, isTrue, reason: service.error);
      await eventually(() => output.toString().contains('fixture-stderr'));
      output.clear();
      await remote.finishWithOutput();
      await eventually(() => !service.connected);
      expect(
        output.toString().contains('${'f' * 65536}fixture-final-你好\r\n'),
        isTrue,
        reason: 'Final 64 KiB stdout and UTF-8 tail must survive remote close',
      );
      expect(output.toString(), contains('fixture-final-stderr\r\n'));
      expect(output.toString(), isNot(contains('\uFFFD')));
      await remote.waitFor('closed');
    },
  );
}
