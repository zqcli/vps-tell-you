import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/connections/error_details.dart';
import 'package:vps_tell_you/connections/ssh_service.dart';
import 'package:vps_tell_you/connections/tcp_test.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/security/host_trust.dart';
import 'package:vps_tell_you/security/proxy_models.dart';
import 'package:vps_tell_you/security/secret_store.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';

import 'support/fake_proxy.dart';
import 'support/ssh_fixture.dart';

class _Secrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String reference) async => values[reference];
  @override
  Future<void> write(String reference, String value) async =>
      values[reference] = value;
  @override
  Future<void> delete(String reference) async => values.remove(reference);
}

class _NoDeviceAuth implements DeviceAuthenticator {
  @override
  Future<bool> authenticate() async => false;
  @override
  Future<void> cancel() async {}
}

const _password = 'synthetic-password-only';
const _proxyPassword = 'synthetic-proxy-password';

void main() {
  final en = AppLocalizationsEn();
  late Directory dir;
  late LedgerStore store;
  late SecurityController security;
  late String credentialId;
  final closers = <Future<void> Function()>[];
  NativeSshService? service;

  setUp(() async {
    sqfliteFfiInit();
    dir = await Directory.systemTemp.createTemp('error-details-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${dir.path}/ledger.db',
    );
    security = SecurityController(
      store: store,
      secrets: _Secrets(),
      authenticator: _NoDeviceAuth(),
    );
    await security.initialize();
    await security.saveCredential(
      name: 'Fixture',
      kind: CredentialKind.password,
      defaultUsername: 'fixture',
      secret: _password,
    );
    credentialId = security.credentials.single.id;
  });

  tearDown(() async {
    service?.dispose();
    for (final close in closers) {
      await close();
    }
    closers.clear();
    security.dispose();
    await store.close();
    await dir.delete(recursive: true);
  });

  Future<SshFixture> ssh() async {
    final fixture = await SshFixture.start();
    closers.add(fixture.close);
    return fixture;
  }

  Future<FakeProxy> proxy(
    ProxyKind kind, {
    FakeProxyOptions options = const FakeProxyOptions(),
  }) async {
    final fake = await FakeProxy.start(kind, options: options);
    closers.add(fake.close);
    return fake;
  }

  SshTarget target(int port, {String? proxyId, String host = '127.0.0.1'}) =>
      SshTarget(
        name: 'Loopback',
        host: host,
        port: port,
        username: 'fixture',
        credentialId: credentialId,
        proxyId: proxyId,
      );

  Future<bool> accept(HostVerificationRequest request) async => true;

  NativeSshService make({
    Duration handshakeTimeout = const Duration(seconds: 15),
    Duration authTimeout = const Duration(seconds: 20),
  }) => service = NativeSshService(
    security: security,
    handshakeTimeout: handshakeTimeout,
    authTimeout: authTimeout,
  );

  Future<int> closedPort() async {
    final socket = await ServerSocket.bind('127.0.0.1', 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  test(
    'connection refused: stage, target and the raw SocketException',
    () async {
      final port = await closedPort();
      final svc = make();
      await svc.connect(target(port), verifyHost: accept);
      expect(svc.status, SshStatus.failed);
      final d = svc.errorDetails!;
      expect(d.stage, ErrorStage.connect);
      expect(d.target, 'fixture@127.0.0.1:$port');
      expect(d.proxy, isNull);
      expect(d.technical, contains('SocketException'));
      expect(d.technical, contains('Connection refused'));
      expect(d.technical, contains('address = 127.0.0.1'));
      // The friendly headline is unchanged.
      expect(svc.errorFor(en), en.sshConnectionIncomplete);
      expect(d.report(en), contains('fixture@127.0.0.1:$port'));
    },
  );

  test('IPv6 targets are bracketed', () async {
    final svc = make();
    await svc.connect(
      SshTarget(
        name: 'v6',
        host: '::1',
        port: await closedPort(),
        username: 'fixture',
        credentialId: credentialId,
      ),
      verifyHost: accept,
    );
    expect(svc.errorDetails!.target, startsWith('fixture@[::1]:'));
  });

  test('handshake timeout is reported as a TimeoutException', () async {
    final silent = await ServerSocket.bind('127.0.0.1', 0);
    closers.add(silent.close);
    silent.listen((socket) => closers.add(() async => socket.destroy()));
    final svc = make(handshakeTimeout: const Duration(milliseconds: 300));
    await svc.connect(target(silent.port), verifyHost: accept);
    expect(svc.status, SshStatus.failed);
    final d = svc.errorDetails!;
    expect(d.stage, ErrorStage.handshake);
    expect(d.technical, contains('TimeoutException after 0:00:00.300000'));
    expect(svc.errorFor(en), en.sshHandshakeTimeout);
  });

  test(
    'authentication failure shows SSHAuthFailError, never the password',
    () async {
      final remote = await ssh();
      await security.saveCredential(
        name: 'Wrong',
        kind: CredentialKind.password,
        defaultUsername: 'fixture',
        secret: 'synthetic-wrong-password',
      );
      credentialId = security.credentials.last.id;
      final svc = make();
      await svc.connect(target(remote.port), verifyHost: accept);
      await remote.waitFor('closed');
      expect(svc.status, SshStatus.failed);
      final d = svc.errorDetails!;
      expect(d.stage, ErrorStage.authentication);
      expect(d.technical, contains('SSHAuthFailError'));
      expect(d.technical, isNot(contains('synthetic-wrong-password')));
      expect(d.report(en), isNot(contains('synthetic-wrong-password')));
      expect(svc.errorFor(en), en.sshAuthenticationFailed);
    },
  );

  test('changed host key: stage, pinned and presented fingerprints', () async {
    final remote = await ssh();
    final old = HostKeyIdentity.validated(
      host: '127.0.0.1',
      port: remote.port,
      algorithm: 'ssh-rsa',
      publicKey: File('test/fixtures/security/rsa.fixture.pub')
          .readAsStringSync()
          .trim(),
    );
    expect(await security.verifyHost(old), isTrue);
    final svc = make();
    await svc.connect(target(remote.port), verifyHost: (_) async => false);
    await remote.waitFor('closed');
    final d = svc.errorDetails!;
    expect(d.stage, ErrorStage.hostKey);
    expect(d.technical, contains('SSHAuthAbortError'));
    expect(d.technical, contains('Host key changed'));
    expect(d.technical, contains(remote.identity.fingerprint));
    expect(
      d.technical,
      contains('Pinned host key: ssh-rsa ${old.fingerprint}'),
    );
    expect(svc.errorFor(en), en.sshHostNotTrusted);
  });

  group('through a proxy', () {
    Future<String> save(FakeProxy fake, {String? user, String? pass}) async =>
        (await security.saveProxy(
          name: 'Office proxy',
          kind: fake.kind,
          host: '127.0.0.1',
          port: fake.port,
          username: user,
          password: pass,
        ))!;

    test('SOCKS5 reply code and the proxy name / type', () async {
      final fake = await proxy(
        ProxyKind.socks5,
        options: const FakeProxyOptions(socksReply: 5),
      );
      final svc = make();
      await svc.connect(
        target(22, proxyId: await save(fake), host: 'ssh.target.test'),
        verifyHost: accept,
      );
      final d = svc.errorDetails!;
      expect(d.stage, ErrorStage.proxy);
      expect(d.technical, contains('SOCKS5 reply 0x05: connection refused'));
      expect(d.technical, contains('socksRefused'));
      expect(d.proxy, 'Office proxy · SOCKS5 127.0.0.1:${fake.port}');
      expect(d.target, 'fixture@ssh.target.test:22');
      expect(svc.errorFor(en), en.r13ProxySocksRefused);
    });

    test('HTTP status line, and the proxy password stays out', () async {
      final fake = await proxy(
        ProxyKind.http,
        options: const FakeProxyOptions(httpStatus: 502),
      );
      final svc = make();
      await svc.connect(
        target(
          22,
          proxyId: await save(fake, user: 'alice', pass: _proxyPassword),
          host: 'ssh.target.test',
        ),
        verifyHost: accept,
      );
      final d = svc.errorDetails!;
      expect(d.stage, ErrorStage.proxy);
      expect(d.technical, contains('HTTP/1.1 502'));
      expect(d.report(en), isNot(contains(_proxyPassword)));
      expect(d.report(en), isNot(contains('Proxy-Authorization')));
    });

    test('a wrong SOCKS5 password is reported without the password', () async {
      final fake = await proxy(
        ProxyKind.socks5,
        options: const FakeProxyOptions(username: 'alice', password: 'right'),
      );
      final svc = make();
      await svc.connect(
        target(
          22,
          proxyId: await save(fake, user: 'alice', pass: _proxyPassword),
          host: 'ssh.target.test',
        ),
        verifyHost: accept,
      );
      final d = svc.errorDetails!;
      expect(d.technical, contains('SOCKS5 username/password rejected'));
      expect(d.report(en), isNot(contains(_proxyPassword)));
    });

    test('proxy down: the underlying SocketException', () async {
      final fake = await proxy(ProxyKind.socks5);
      final id = await save(fake);
      await fake.close();
      final svc = make();
      await svc.connect(
        target(22, proxyId: id, host: 'ssh.target.test'),
        verifyHost: accept,
      );
      final d = svc.errorDetails!;
      expect(d.stage, ErrorStage.proxy);
      expect(d.technical, contains('SocketException'));
    });
  });

  group('no details for cancellations', () {
    test('disconnect while connecting', () async {
      final remote = await SshFixture.start(
        delayAuth: const Duration(seconds: 3),
      );
      closers.add(remote.close);
      final svc = make();
      final pending = svc.connect(
        target(remote.port),
        verifyHost: (_) async {
          // Hold the prompt open, then cancel as the user would.
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return true;
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      svc.disconnect();
      await pending;
      expect(svc.errorDetails, isNull);
      expect(svc.error, isNull);
    });

    test('cancelled key passphrase', () async {
      await security.saveCredential(
        name: 'Key',
        kind: CredentialKind.privateKey,
        defaultUsername: 'fixture',
        secret: File('test/fixtures/security/ed25519_encrypted.fixture')
            .readAsStringSync(),
        passphrase: 'fixture-passphrase-only',
        savePassphrase: false,
      );
      credentialId = security.credentials.last.id;
      final remote = await ssh();
      final svc = make();
      await svc.connect(
        target(remote.port),
        verifyHost: accept,
        requestKeyPassphrase: (_) async => null,
      );
      expect(svc.status, SshStatus.failed);
      expect(svc.errorFor(en), en.sshPassphraseCancelled);
      expect(svc.errorDetails, isNull);
    });

    test('a cancelled TCP test', () async {
      final controller = TcpTestController();
      addTearDown(controller.dispose);
      final silent = await ServerSocket.bind('127.0.0.1', 0);
      closers.add(silent.close);
      final pending = controller.test(
        TcpTarget(host: '127.0.0.1', port: silent.port),
        proxy: const ProxyEndpoint(
          kind: ProxyKind.socks5,
          host: '127.0.0.1',
          port: 1,
        ),
      );
      controller.cancel();
      await pending;
      expect(controller.result?.outcome, TcpOutcome.cancelled);
      expect(controller.result?.errorDetails, isNull);
    });
  });

  test('remote close reports the server side, not an error to hide', () async {
    final remote = await ssh();
    final svc = make();
    await svc.connect(target(remote.port), verifyHost: accept);
    expect(svc.connected, isTrue, reason: svc.error);
    await remote.disconnectClients();
    await _eventually(() => svc.status == SshStatus.disconnected);
    final d = svc.errorDetails!;
    expect(d.stage, ErrorStage.session);
    expect(d.technical, anyOf(contains('closed'), contains('Exit status')));
    expect(svc.errorFor(en), en.sshSessionEnded);
    // A deliberate disconnect later clears it.
    svc.disconnect();
    expect(svc.errorDetails, isNull);
  });

  group('TCP test', () {
    test('refused', () async {
      final port = await closedPort();
      final controller = TcpTestController();
      addTearDown(controller.dispose);
      await controller.test(TcpTarget(host: '127.0.0.1', port: port));
      final d = controller.result!.errorDetails!;
      expect(controller.result!.outcome, TcpOutcome.refused);
      expect(d.stage, ErrorStage.connect);
      expect(d.target, '127.0.0.1:$port');
      expect(d.technical, contains('SocketException'));
    });

    test('timeout', () async {
      final controller = TcpTestController(
        timeout: const Duration(milliseconds: 200),
        connector: (host, port) => Completer<ConnectionTask<Socket>>().future,
      );
      addTearDown(controller.dispose);
      await controller.test(TcpTarget(host: '127.0.0.1', port: 9));
      expect(controller.result!.outcome, TcpOutcome.timedOut);
      expect(
        controller.result!.errorDetails!.technical,
        contains('TimeoutException after 0:00:00.200000'),
      );
    });

    test('through a SOCKS5 proxy that refuses the target', () async {
      final fake = await proxy(
        ProxyKind.socks5,
        options: const FakeProxyOptions(socksReply: 5),
      );
      final controller = TcpTestController();
      addTearDown(controller.dispose);
      await controller.test(
        TcpTarget(host: '203.0.113.10', port: 22),
        proxy: ProxyEndpoint(
          kind: ProxyKind.socks5,
          host: '127.0.0.1',
          port: fake.port,
          username: 'u',
          password: _proxyPassword,
        ),
        proxyName: 'Office proxy',
      );
      final d = controller.result!.errorDetails!;
      expect(d.stage, ErrorStage.proxy);
      expect(d.proxy, 'Office proxy · SOCKS5 127.0.0.1:${fake.port}');
      expect(d.technical, contains('SOCKS5 reply 0x05'));
      expect(d.report(en), isNot(contains(_proxyPassword)));
    });

    test('a successful test has no details', () async {
      final listener = await ServerSocket.bind('127.0.0.1', 0);
      closers.add(listener.close);
      final controller = TcpTestController();
      addTearDown(controller.dispose);
      await controller.test(TcpTarget(host: '127.0.0.1', port: listener.port));
      expect(controller.result!.outcome, TcpOutcome.connected);
      expect(controller.result!.errorDetails, isNull);
    });
  });
}

Future<void> _eventually(bool Function() test) async {
  for (var i = 0; i < 100; i++) {
    if (test()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('condition not reached');
}
