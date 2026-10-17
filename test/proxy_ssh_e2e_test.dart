import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/connections/proxy_connector.dart';
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
import 'support/proxy_tls.dart';
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

/// A name only the proxy can resolve: proves the target is never resolved or
/// dialled by this device, and that trust stays keyed by the target.
const _targetName = 'ssh.target.test';

void main() {
  late Directory work, root;
  late LedgerStore store;
  late _Secrets secrets;
  late SecurityController security;
  late SshFixture ssh;
  late ProxyTls tls;
  late String credentialId;
  late NativeSshService service;
  final proxies = <FakeProxy>[];

  setUpAll(() async => tls = await ProxyTls.load());

  setUp(() async {
    sqfliteFfiInit();
    work = await Directory.systemTemp.createTemp('proxy-e2e-');
    root = await Directory('${work.path}/root').create();
    File('${root.path}/hello.txt').writeAsStringSync('through the proxy');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${work.path}/ledger.db',
    );
    secrets = _Secrets();
    security = SecurityController(
      store: store,
      secrets: secrets,
      authenticator: _NoDeviceAuth(),
    );
    await security.initialize();
    await security.saveCredential(
      name: 'Fixture',
      kind: CredentialKind.password,
      defaultUsername: 'fixture',
      secret: 'synthetic-password-only',
    );
    credentialId = security.credentials.single.id;
    ssh = await SshFixture.start(sftpRoot: root.path);
    service = NativeSshService(
      security: security,
      proxyTlsContext: tls.trustTestCa(),
    );
  });

  tearDown(() async {
    service.dispose();
    for (final proxy in proxies) {
      await proxy.close();
    }
    proxies.clear();
    await ssh.close();
    security.dispose();
    await store.close();
    await work.delete(recursive: true);
  });

  Future<FakeProxy> startProxy(
    ProxyKind kind, {
    String? user,
    String? pass,
    FakeProxyOptions? options,
  }) async {
    final proxy = await FakeProxy.start(
      kind,
      options:
          options ??
          FakeProxyOptions(
            username: user,
            password: pass,
            hosts: {_targetName: '127.0.0.1:${ssh.port}'},
          ),
      serverContext: kind == ProxyKind.https ? tls.serverContext : null,
    );
    proxies.add(proxy);
    return proxy;
  }

  Future<String> saveProxy(
    FakeProxy proxy, {
    String? user,
    String? pass,
    String name = 'Test proxy',
  }) async {
    final id = await security.saveProxy(
      name: name,
      kind: proxy.kind,
      host: '127.0.0.1',
      port: proxy.port,
      username: user,
      password: pass,
    );
    expect(id, isNotNull, reason: security.error);
    return id!;
  }

  SshTarget target(String? proxyId, {String host = _targetName}) => SshTarget(
    name: 'Via proxy',
    host: host,
    port: ssh.port,
    username: 'fixture',
    credentialId: credentialId,
    proxyId: proxyId,
  );

  String errorText() => service.errorFor(AppLocalizationsEn())!;

  group('SSH through each proxy kind', () {
    for (final (kind, user, pass) in [
      (ProxyKind.socks5, null, null),
      (ProxyKind.socks5, 'proxy-user', 'proxy-pass'),
      (ProxyKind.http, 'proxy-user', 'proxy-pass'),
      (ProxyKind.https, 'proxy-user', 'proxy-pass'),
    ]) {
      test(
        '${kind.label}${user == null ? '' : ' with authentication'}',
        () async {
          final proxy = await startProxy(kind, user: user, pass: pass);
          final id = await saveProxy(proxy, user: user, pass: pass);
          HostVerificationRequest? asked;
          await service.connect(
            target(id),
            verifyHost: (request) async {
              asked = request;
              return true;
            },
          );
          expect(service.connected, isTrue, reason: service.error);
          await ssh.waitFor('authenticated');
          // The proxy was asked for the TARGET name and port, once.
          expect(proxy.requests.single.host, _targetName);
          expect(proxy.requests.single.port, ssh.port);
          expect(proxy.accepted, 1);
          expect(proxy.requests.single.username, user);
          // Host-key trust is about the target, never the proxy.
          expect(asked!.identity.host, _targetName);
          expect(asked!.identity.port, ssh.port);
          final pins = await store.hostTrusts();
          expect(pins.single.host, _targetName);
          expect(pins.single.port, ssh.port);
          // The proxy password is only in secure storage.
          if (pass != null) {
            final rows = await store.proxies();
            expect(rows.single.toMap().values.join(' '), isNot(contains(pass)));
            expect(
              secrets.values.values.where((v) => v.contains(pass)),
              hasLength(1),
            );
          }
        },
      );
    }
  });

  test('SFTP (standalone) rides the same SOCKS5 proxy', () async {
    final proxy = await startProxy(ProxyKind.socks5, user: 'u', pass: 'p');
    final id = await saveProxy(proxy, user: 'u', pass: 'p');
    expect(
      await security.verifyHost(
        HostKeyIdentity.validated(
          host: _targetName,
          port: ssh.port,
          algorithm: ssh.publicKey.split(' ').first,
          publicKey: ssh.publicKey,
        ),
      ),
      isTrue,
    );
    final session = await service.connectSftp(
      target(id),
      verifyHost: (_) async => fail('already trusted'),
    );
    addTearDown(session.close);
    final names = (await session.list('/')).map((e) => e.name);
    expect(names, contains('hello.txt'));
    expect(proxy.requests.single.host, _targetName);
    expect(proxy.accepted, 1);
  });

  test(
    'SFTP opened from the terminal connection adds no second dial',
    () async {
      final proxy = await startProxy(ProxyKind.http);
      final id = await saveProxy(proxy);
      await service.connect(target(id), verifyHost: (_) async => true);
      expect(service.connected, isTrue, reason: service.error);
      final sftp = await service.openSftpOnClient();
      addTearDown(sftp.close);
      expect((await sftp.list('/')).map((e) => e.name), contains('hello.txt'));
      expect(proxy.accepted, 1, reason: 'same SSH connection, same tunnel');
    },
  );

  group('fail closed: never a silent direct connection', () {
    Future<void> expectNoDirect() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(ssh.of('auth_begin'), isEmpty);
      expect(
        ssh.of('closed'),
        isEmpty,
        reason: 'no connection reached the server',
      );
    }

    test('unknown proxy id', () async {
      await service.connect(
        target('missing-proxy', host: '127.0.0.1'),
        verifyHost: (_) async => true,
      );
      expect(service.status, SshStatus.failed);
      expect(errorText(), AppLocalizationsEn().r13ProxyMissing);
      await expectNoDirect();
    });

    test('proxy password gone from secure storage', () async {
      final proxy = await startProxy(ProxyKind.socks5, user: 'u', pass: 'p');
      final id = await saveProxy(proxy, user: 'u', pass: 'p');
      secrets.values.removeWhere((key, _) => key.startsWith('vps_proxy_'));
      await service.connect(target(id), verifyHost: (_) async => true);
      expect(service.status, SshStatus.failed);
      expect(errorText(), AppLocalizationsEn().r13ProxyPasswordMissing);
      expect(proxy.accepted, 0);
      await expectNoDirect();
    });

    test('wrong proxy password is reported, SSH never starts', () async {
      final proxy = await startProxy(
        ProxyKind.socks5,
        user: 'u',
        pass: 'right',
      );
      final id = await saveProxy(proxy, user: 'u', pass: 'wrong');
      await service.connect(target(id), verifyHost: (_) async => true);
      expect(service.status, SshStatus.failed);
      expect(errorText(), AppLocalizationsEn().r13ProxyAuthRejected);
      await expectNoDirect();
    });

    test('proxy down', () async {
      final proxy = await startProxy(ProxyKind.socks5);
      final id = await saveProxy(proxy);
      await proxy.close();
      await service.connect(target(id), verifyHost: (_) async => true);
      expect(service.status, SshStatus.failed);
      expect(errorText(), AppLocalizationsEn().r13ProxyUnreachable);
      await expectNoDirect();
    });

    test('an HTTPS proxy with an untrusted certificate', () async {
      final proxy = await startProxy(ProxyKind.https);
      final id = await saveProxy(proxy);
      final strict = NativeSshService(
        security: security,
        proxyTlsContext: tls.trustOtherCa(),
      );
      addTearDown(strict.dispose);
      await strict.connect(target(id), verifyHost: (_) async => true);
      expect(strict.status, SshStatus.failed);
      expect(
        strict.errorFor(AppLocalizationsEn()),
        AppLocalizationsEn().r13ProxyTlsFailed,
      );
      expect(proxy.requests, isEmpty);
    });

    test('disconnect while the proxy is still answering', () async {
      final proxy = await startProxy(
        ProxyKind.socks5,
        options: const FakeProxyOptions(silent: true),
      );
      final id = await saveProxy(proxy);
      final connecting = service.connect(
        target(id),
        verifyHost: (_) async => true,
      );
      await eventually(() => proxy.requests.isNotEmpty);
      service.disconnect();
      await connecting;
      expect(service.status, SshStatus.disconnected);
      await eventually(() => proxy.eofs == 1);
    });
  });

  group('TCP test through a proxy', () {
    TcpTarget tcpTarget() => TcpTarget(host: _targetName, port: ssh.port);

    for (final kind in ProxyKind.values) {
      test('${kind.label}: connected, and what it proves', () async {
        final proxy = await startProxy(kind, user: 'u', pass: 'p');
        final controller = TcpTestController(
          proxyTlsContext: tls.trustTestCa(),
        );
        addTearDown(controller.dispose);
        await controller.test(
          tcpTarget(),
          proxy: proxy.endpoint(username: 'u', password: 'p'),
          proxyName: 'Office',
        );
        final result = controller.result!;
        expect(result.outcome, TcpOutcome.connected);
        expect(result.viaProxy, isTrue);
        expect(result.proxyName, 'Office');
        expect(result.proxy!.kind, kind);
        // The observed address is the proxy's, never the target's.
        expect(result.remoteAddress, '127.0.0.1');
        expect(proxy.requests.single.host, _targetName);
      });
    }

    test('direct stays direct', () async {
      final controller = TcpTestController();
      addTearDown(controller.dispose);
      await controller.test(TcpTarget(host: '127.0.0.1', port: ssh.port));
      expect(controller.result!.outcome, TcpOutcome.connected);
      expect(controller.result!.viaProxy, isFalse);
    });

    test(
      'target refusing is refused, with the proxy failure attached',
      () async {
        final closed = await ServerSocket.bind('127.0.0.1', 0);
        final port = closed.port;
        await closed.close();
        final proxy = await startProxy(
          ProxyKind.socks5,
          options: const FakeProxyOptions(),
        );
        final controller = TcpTestController();
        addTearDown(controller.dispose);
        await controller.test(
          TcpTarget(host: '127.0.0.1', port: port),
          proxy: proxy.endpoint(),
        );
        expect(controller.result!.outcome, TcpOutcome.refused);
        expect(
          controller.result!.proxyFailure!.failure,
          ProxyFailure.socksRefused,
        );
      },
    );

    test(
      'proxy errors are failures; a silent proxy times out; cancel works',
      () async {
        final bad = await startProxy(
          ProxyKind.http,
          options: const FakeProxyOptions(httpStatus: 502),
        );
        final controller = TcpTestController(
          timeout: const Duration(milliseconds: 300),
        );
        addTearDown(controller.dispose);
        await controller.test(tcpTarget(), proxy: bad.endpoint());
        expect(controller.result!.outcome, TcpOutcome.failed);
        expect(controller.result!.proxyFailure!.httpStatus, 502);

        final silent = await startProxy(
          ProxyKind.socks5,
          options: const FakeProxyOptions(silent: true),
        );
        await controller.test(tcpTarget(), proxy: silent.endpoint());
        expect(controller.result!.outcome, TcpOutcome.timedOut);
        await eventually(() => silent.eofs == 1);

        final pending = controller.test(tcpTarget(), proxy: silent.endpoint());
        await eventually(() => silent.requests.length == 2);
        controller.cancel();
        await pending;
        expect(controller.result!.outcome, TcpOutcome.cancelled);
        await eventually(() => silent.eofs == 2);
      },
    );

    test('the temporary password is only used for the attempt', () async {
      final proxy = await startProxy(ProxyKind.socks5, user: 'u', pass: 'p');
      final controller = TcpTestController();
      addTearDown(controller.dispose);
      await controller.test(
        tcpTarget(),
        proxy: proxy.endpoint(username: 'u', password: 'p'),
      );
      expect(
        secrets.values.keys.where((k) => k.startsWith('vps_proxy_')),
        isEmpty,
      );
      expect(await store.proxies(), isEmpty);
    });
  });
}
