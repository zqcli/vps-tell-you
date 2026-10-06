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

  @override
  Future<String?> read(String reference) async => values[reference];
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

class _ReviewSecurity extends SecurityController {
  _ReviewSecurity({
    required super.store,
    required super.secrets,
    required super.authenticator,
  });
  int currentChecks = 0;
  Completer<void>? holdCurrent;
  @override
  Future<bool> isCredentialCurrent(CredentialMetadata record) async {
    currentChecks++;
    final valid = await super.isCredentialCurrent(record);
    if (currentChecks == 3) await holdCurrent?.future;
    return valid;
  }
}

/// Corrupt only the server's initial KEX signature on a loopback fixture.
/// The public-key blob remains intact, so capture alone cannot reject it.
class _SignatureTamperProxy {
  _SignatureTamperProxy(this.listener);
  final ServerSocket listener;
  final sockets = <Socket>[];
  bool tampered = false;
  int get port => listener.port;

  static Future<_SignatureTamperProxy> start(int destination) async {
    final proxy = _SignatureTamperProxy(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    );
    proxy.listener.listen((client) async {
      proxy.sockets.add(client);
      unawaited(client.done.catchError((Object _) {}));
      final remote = await Socket.connect(
        InternetAddress.loopbackIPv4,
        destination,
      );
      proxy.sockets.add(remote);
      unawaited(remote.done.catchError((Object _) {}));
      client.listen(
        remote.add,
        onDone: remote.destroy,
        onError: (Object _) => remote.destroy(),
      );
      final buffer = <int>[];
      var versionSeen = false;
      remote.listen(
        (bytes) {
          if (proxy.tampered) {
            client.add(bytes);
            return;
          }
          buffer.addAll(bytes);
          while (buffer.isNotEmpty) {
            if (!versionSeen) {
              final newline = buffer.indexOf(10);
              if (newline < 0) return;
              final line = buffer.sublist(0, newline + 1);
              client.add(line);
              versionSeen = ascii.decode(line).startsWith('SSH-');
              buffer.removeRange(0, newline + 1);
              continue;
            }
            if (buffer.length < 5) return;
            final size =
                (buffer[0] << 24) |
                (buffer[1] << 16) |
                (buffer[2] << 8) |
                buffer[3];
            if (buffer.length < size + 4) return;
            final packet = buffer.sublist(0, size + 4);
            buffer.removeRange(0, size + 4);
            if (packet[5] == 31 || packet[5] == 33) {
              // Curve25519 is preferred by both fixture and dartssh2. Its
              // KEX reply ends with a string containing the host signature.
              final lastPayloadByte = size + 3 - packet[4];
              packet[lastPayloadByte] ^= 1;
              proxy.tampered = true;
            }
            client.add(packet);
            if (proxy.tampered) {
              if (buffer.isNotEmpty) client.add(buffer);
              buffer.clear();
              return;
            }
          }
        },
        onDone: client.destroy,
        onError: (Object _) => client.destroy(),
      );
    });
    return proxy;
  }

  Future<void> close() async {
    for (final socket in sockets) {
      socket.destroy();
    }
    await listener.close();
  }
}

void main() {
  late Directory directory;
  late LedgerStore store;
  late _ReviewSecurity security;
  late _Secrets secrets;
  late NativeSshService service;
  late String credentialId;
  final fixtures = <SshFixture>[];

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('ssh-review-test-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.db',
    );
    secrets = _Secrets();
    security = _ReviewSecurity(
      store: store,
      secrets: secrets,
      authenticator: _NoDeviceAuth(),
    );
    await security.initialize();
    expect(
      await security.saveCredential(
        name: 'Review fixture',
        kind: CredentialKind.password,
        defaultUsername: 'fixture',
        secret: 'synthetic-password-only',
      ),
      isTrue,
    );
    credentialId = security.credentials.single.id;
    service = NativeSshService(security: security);
  });

  tearDown(() async {
    service.dispose();
    if (security.holdCurrent != null && !security.holdCurrent!.isCompleted) {
      security.holdCurrent!.complete();
    }
    for (final fixture in fixtures) {
      await fixture.close();
    }
    fixtures.clear();
    security.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<SshFixture> fixture({String hostKey = 'ed25519.fixture'}) async {
    final result = await SshFixture.start(hostKey: hostKey);
    fixtures.add(result);
    return result;
  }

  SshTarget target(int port) => SshTarget(
    name: 'Review loopback',
    host: '127.0.0.1',
    port: port,
    username: 'fixture',
    credentialId: credentialId,
  );

  void noAuthentication(SshFixture remote) {
    expect(remote.of('auth_begin'), isEmpty);
    expect(remote.of('password'), isEmpty);
    expect(remote.of('public_key'), isEmpty);
    expect(remote.of('authenticated'), isEmpty);
    expect(remote.of('shell'), isEmpty);
  }

  test('intact captured key cannot bypass a corrupted KEX signature', () async {
    final remote = await fixture();
    final proxy = await _SignatureTamperProxy.start(remote.port);
    addTearDown(proxy.close);
    var prompts = 0;
    await service.connect(
      target(proxy.port),
      verifyHost: (_) async {
        prompts++;
        return true;
      },
    );
    await remote.waitFor('closed');
    expect(proxy.tampered, isTrue);
    expect(prompts, 0);
    expect(service.status, SshStatus.failed);
    expect(await store.hostTrusts(), isEmpty);
    noAuthentication(remote);
  });

  test('newly stored pin wins over a stale first-use prompt', () async {
    final remote = await fixture();
    final permission = Completer<bool>();
    var prompted = false;
    final connecting = service.connect(
      target(remote.port),
      verifyHost: (_) {
        prompted = true;
        return permission.future;
      },
    );
    await eventually(() => prompted);
    final replacement = HostKeyIdentity.validated(
      host: '127.0.0.1',
      port: remote.port,
      algorithm: 'ssh-rsa',
      publicKey: File('test/fixtures/security/rsa.fixture.pub')
          .readAsStringSync(),
    );
    // Exercise the DB compare-and-swap even without controller invalidation.
    await store.saveHostTrust(
      HostTrustRecord(
        host: replacement.host,
        port: replacement.port,
        algorithm: replacement.algorithm,
        publicKey: replacement.publicKey,
        fingerprint: replacement.fingerprint,
        verifiedAt: DateTime.now().toUtc(),
      ),
      expected: null,
    );
    permission.complete(true);
    await connecting;
    await remote.waitFor('closed');
    expect(service.connected, isFalse);
    expect((await store.hostTrusts()).single.publicKey, replacement.publicKey);
    noAuthentication(remote);
  });
  for (final privateKey in [false, true]) {
    test(
      'cancel after awaited current check blocks ${privateKey ? 'signature' : 'password'}',
      () async {
        final remote = await fixture();
        if (privateKey) {
          expect(
            await security.saveCredential(
              name: 'Review synthetic key',
              kind: CredentialKind.privateKey,
              defaultUsername: 'fixture',
              secret: File('test/fixtures/security/ed25519_encrypted.fixture')
                  .readAsStringSync(),
              passphrase: 'fixture-passphrase-only',
            ),
            isTrue,
          );
          credentialId = security.credentials
              .firstWhere((c) => c.kind == CredentialKind.privateKey)
              .id;
        }
        security.holdCurrent = Completer<void>();
        final connecting = service.connect(
          target(remote.port),
          verifyHost: (_) async => true,
          requestKeyPassphrase: (_) async => 'fixture-passphrase-only',
        );
        await eventually(() => security.currentChecks == 3);
        service.disconnect();
        security.holdCurrent!.complete();
        await connecting.timeout(const Duration(seconds: 2));
        await remote.waitFor('closed');
        noAuthentication(remote);
        expect(service.connected, isFalse);
      },
    );
  }

  for (final envelope in [
    'synthetic-password-only INVALID JSON',
    jsonEncode({
      'version': 2,
      'kind': 'password',
      'secret': 'synthetic-password-only',
    }),
    jsonEncode({
      'version': 1,
      'kind': 'privateKey',
      'secret': 'synthetic-password-only',
    }),
    jsonEncode({
      'version': 1,
      'kind': 'password',
      'secret': ['synthetic-password-only'],
    }),
    jsonEncode({
      'version': 1,
      'kind': 'password',
      'secret': 'synthetic-password-only',
      'passphrase': 17,
    }),
  ].indexed) {
    test(
      'corrupt native envelope ${envelope.$1} fails before TCP with safe error',
      () async {
        final remote = await fixture();
        secrets.values[security.credentials.single.secretRef] = envelope.$2;
        await service.connect(
          target(remote.port),
          verifyHost: (_) async => true,
        );
        expect(service.status, SshStatus.failed);
        expect(remote.of('connection'), isEmpty);
        expect(service.error, isNot(contains('synthetic-password-only')));
        noAuthentication(remote);
      },
    );
  }

  test(
    'valid private key substituted behind metadata cannot authenticate',
    () async {
      final remote = await fixture();
      expect(
        await security.saveCredential(
          name: 'Review synthetic key',
          kind: CredentialKind.privateKey,
          defaultUsername: 'fixture',
          secret: File('test/fixtures/security/ed25519.fixture')
              .readAsStringSync(),
        ),
        isTrue,
      );
      final record = security.credentials.firstWhere(
        (c) => c.kind == CredentialKind.privateKey,
      );
      credentialId = record.id;
      secrets.values[record.secretRef] = jsonEncode({
        'version': 1,
        'kind': 'privateKey',
        'secret': File('test/fixtures/security/rsa.fixture').readAsStringSync(),
      });
      await service.connect(target(remote.port), verifyHost: (_) async => true);
      expect(service.status, SshStatus.failed);
      expect(remote.of('connection'), isEmpty);
      noAuthentication(remote);
    },
  );
}
