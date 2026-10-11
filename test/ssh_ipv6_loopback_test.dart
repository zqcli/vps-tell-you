import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/connections/sftp_session.dart';
import 'package:vps_tell_you/connections/ssh_service.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/security/host_trust.dart';
import 'package:vps_tell_you/security/secret_store.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';

import 'support/ssh_fixture.dart';

/// SSH and SFTP against the loopback-only fixture bound to `::1`.
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

Future<bool> _hasIpv6Loopback() async {
  try {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv6, 0);
    await probe.close();
    return true;
  } on SocketException {
    return false;
  }
}

Future<void> main() async {
  final skip = await _hasIpv6Loopback()
      ? null
      : 'This host has no IPv6 loopback (::1): cannot bind a listener';

  late Directory work, root;
  late LedgerStore store;
  late SecurityController security;
  late String credentialId;
  final services = <NativeSshService>[];
  final fixtures = <SshFixture>[];
  final sessions = <SftpSession>[];

  setUp(() async {
    sqfliteFfiInit();
    work = await Directory.systemTemp.createTemp('ssh-ipv6-test-');
    root = await Directory('${work.path}/root').create();
    await File('${root.path}/hello.txt').writeAsString('hello over ipv6');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${work.path}/ledger.db',
    );
    security = SecurityController(
      store: store,
      secrets: _Secrets(),
      authenticator: _NoDeviceAuth(),
    );
    await security.initialize();
    expect(
      await security.saveCredential(
        name: 'Synthetic SSH fixture',
        kind: CredentialKind.password,
        defaultUsername: 'fixture',
        secret: 'synthetic-password-only',
        passphrase: null,
        savePassphrase: false,
      ),
      isTrue,
    );
    credentialId = security.credentials.last.id;
  });

  tearDown(() async {
    for (final session in sessions) {
      await session.close();
    }
    sessions.clear();
    for (final service in services) {
      service.dispose();
    }
    services.clear();
    for (final fixture in fixtures) {
      await fixture.close();
    }
    fixtures.clear();
    security.dispose();
    await store.close();
    await work.delete(recursive: true);
  });

  Future<SshFixture> fixture() async {
    final result = await SshFixture.start(
      sftpRoot: root.path,
      bindAddress: '::1',
    );
    fixtures.add(result);
    return result;
  }

  NativeSshService newService() {
    final service = NativeSshService(
      security: security,
      sessionTimeout: const Duration(seconds: 2),
    );
    services.add(service);
    return service;
  }

  SshTarget target(SshFixture remote, String host) => SshTarget(
    name: 'IPv6 loopback fixture',
    host: host,
    port: remote.port,
    username: 'fixture',
    credentialId: credentialId,
  );

  Future<bool> accept(HostVerificationRequest request) async => true;

  test('the fixture refuses anything but loopback', () async {
    for (final bind in ['0.0.0.0', '::', '192.0.2.1']) {
      await expectLater(
        SshFixture.start(bindAddress: bind),
        throwsA(isA<StateError>()),
        reason: bind,
      );
    }
  });

  test(
    'SSH terminal connects to ::1 and the pin is keyed by canonical form',
    () async {
      final remote = await fixture();
      expect(remote.host, '::1');
      final service = newService();
      final output = StringBuffer();
      final sub = service.output.listen(output.write);
      addTearDown(sub.cancel);
      HostVerificationRequest? first;
      // Typed the way a user would paste it from a URL.
      await service.connect(
        target(remote, '[::1]'),
        verifyHost: (request) async {
          first = request;
          return true;
        },
      );
      expect(service.connected, isTrue, reason: service.error);
      expect(service.target!.host, '::1', reason: 'no brackets reach connect');
      expect(service.target!.label, 'fixture@[::1]:${remote.port}');
      expect(first!.status, HostTrustStatus.firstUse);
      expect(first!.identity.host, '::1');
      await remote.waitFor('authenticated');
      service.write('v6-input\r');
      final input = await remote.waitFor('input');
      expect(utf8.decode(base64Decode(input['data'] as String)), 'v6-input\r');
      await eventually(() => output.toString().contains('echo:v6-input'));
      expect((await store.hostTrusts()).single.host, '::1');
      service.dispose();

      // A different spelling of the same address is already trusted.
      var prompts = 0;
      final second = newService();
      await second.connect(
        target(remote, '0:0:0:0:0:0:0:1'),
        verifyHost: (_) async {
          prompts++;
          return false;
        },
      );
      expect(second.connected, isTrue, reason: second.error);
      expect(prompts, 0);
      expect(await store.hostTrusts(), hasLength(1));
      expect(remote.of('authenticated'), hasLength(2));
    },
    skip: skip,
  );

  test(
    'standalone SFTP and an SFTP channel on the shell connection use ::1',
    () async {
      final remote = await fixture();
      final session = await newService().connectSftp(
        target(remote, '::1'),
        verifyHost: accept,
      );
      sessions.add(session);
      expect(await session.home(), '/');
      final names = (await session.list('/')).map((e) => e.name);
      expect(names, contains('hello.txt'));
      expect(remote.of('shell'), isEmpty);

      final shell = newService();
      await shell.connect(target(remote, '[0::1]'), verifyHost: accept);
      expect(shell.connected, isTrue, reason: shell.error);
      final second = await shell.openSftpOnClient();
      sessions.add(second);
      expect(await second.list('/'), isNotEmpty);
      expect((await store.hostTrusts()).single.host, '::1');
    },
    skip: skip,
  );

  test('an unreachable IPv6 literal fails cleanly', () async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv6, 0);
    final port = probe.port;
    await probe.close();
    final service = newService();
    await service.connect(
      SshTarget(
        name: 'closed',
        host: '::1',
        port: port,
        username: 'fixture',
        credentialId: credentialId,
      ),
      verifyHost: accept,
    );
    expect(service.connected, isFalse);
    expect(service.status, SshStatus.failed);
  }, skip: skip);
}
