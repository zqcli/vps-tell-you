import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

Matcher _fails(SftpErrorKind kind) =>
    throwsA(isA<SftpException>().having((e) => e.kind, 'kind', kind));

void main() {
  late Directory work, root, outside;
  late LedgerStore store;
  late SecurityController security;
  late _Secrets secrets;
  late String credentialId;
  final services = <NativeSshService>[];
  final fixtures = <SshFixture>[];
  final sessions = <SftpSession>[];

  setUp(() async {
    sqfliteFfiInit();
    work = await Directory.systemTemp.createTemp('sftp-test-');
    root = await Directory('${work.path}/root').create();
    outside = await Directory('${work.path}/outside').create();
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
    // Permission tests leave unreadable directories behind.
    await Process.run('chmod', ['-R', 'u+rwx', work.path]);
    await work.delete(recursive: true);
  });

  Future<SshFixture> fixture({bool sftp = true}) async {
    final result = await SshFixture.start(sftpRoot: sftp ? root.path : null);
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

  SshTarget target(SshFixture remote) => SshTarget(
    name: 'Loopback fixture',
    host: '127.0.0.1',
    port: remote.port,
    username: 'fixture',
    credentialId: credentialId,
  );

  Future<bool> accept(HostVerificationRequest request) async => true;

  /// A standalone SFTP connection through the full verification path.
  Future<SftpSession> connect([SshFixture? remote]) async {
    remote ??= await fixture();
    final session = await newService().connectSftp(
      target(remote),
      verifyHost: accept,
    );
    sessions.add(session);
    return session;
  }

  File local(String name) => File('${work.path}/$name');
  File inRoot(String path) => File('${root.path}/$path');
  List<String> rootNames([String sub = '']) =>
      Directory('${root.path}/$sub')
          .listSync()
          .map((e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last)
          .toList()
        ..sort();

  Uint8List pattern(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = (i * 31 + (i >> 8)) & 0xff;
    }
    return bytes;
  }

  group('connection paths', () {
    test('standalone connect gates every auth byte on host trust', () async {
      final remote = await fixture();
      final permission = Completer<bool>();
      HostVerificationRequest? request;
      final service = newService();
      final connecting = service.connectSftp(
        target(remote),
        verifyHost: (value) {
          request = value;
          return permission.future;
        },
      );
      await eventually(() => request != null);
      expect(request!.status, HostTrustStatus.firstUse);
      expect(remote.of('auth_begin'), isEmpty);
      expect(remote.of('password'), isEmpty);
      expect(remote.of('sftp_open'), isEmpty);
      permission.complete(true);
      final session = await connecting;
      sessions.add(session);
      expect(service.status, SshStatus.connected);
      expect(await session.home(), '/');
      expect(
        await security.checkHost(remote.identity),
        HostTrustStatus.trusted,
      );
      expect(remote.of('shell'), isEmpty);
      expect(remote.of('pty'), isEmpty);
    });

    test('rejected host never authenticates or opens sftp', () async {
      final remote = await fixture();
      final service = newService();
      await expectLater(
        service.connectSftp(target(remote), verifyHost: (_) async => false),
        throwsA(isA<SecurityFailure>()),
      );
      await remote.waitFor('closed');
      expect(service.status, SshStatus.failed);
      expect(remote.of('auth_begin'), isEmpty);
      expect(remote.of('sftp_open'), isEmpty);
      expect(await store.hostTrusts(), isEmpty);
    });

    test('encrypted key goes through the passphrase prompt', () async {
      final remote = await fixture();
      expect(
        await security.saveCredential(
          name: 'Encrypted',
          kind: CredentialKind.privateKey,
          defaultUsername: 'fixture',
          secret: File('test/fixtures/security/ed25519_encrypted.fixture')
              .readAsStringSync(),
          passphrase: 'fixture-passphrase-only',
          savePassphrase: false,
        ),
        isTrue,
        reason: security.error,
      );
      var prompts = 0;
      final session = await newService().connectSftp(
        SshTarget(
          name: 'key',
          host: '127.0.0.1',
          port: remote.port,
          username: 'fixture',
          credentialId: security.credentials
              .firstWhere((c) => c.name == 'Encrypted')
              .id,
        ),
        verifyHost: accept,
        requestKeyPassphrase: (_) async {
          prompts++;
          return 'fixture-passphrase-only';
        },
      );
      sessions.add(session);
      expect(prompts, 1);
      expect(await session.list('/'), isEmpty);
    });

    test('closing a standalone session closes its connection', () async {
      final remote = await fixture();
      final service = newService();
      final session = await service.connectSftp(
        target(remote),
        verifyHost: accept,
      );
      expect(session.isAlive, isTrue);
      await session.close();
      await remote.waitFor('closed');
      expect(session.isAlive, isFalse);
      expect(service.status, SshStatus.disconnected);
      expect(service.error, isNull);
      await expectLater(
        session.list('/'),
        _fails(SftpErrorKind.connectionLost),
      );
      await session.close(); // idempotent
    });

    test('server without the subsystem reports it as unavailable', () async {
      final remote = await fixture(sftp: false);
      final service = newService();
      await expectLater(
        service.connectSftp(target(remote), verifyHost: accept),
        throwsA(isA<SecurityFailure>()),
      );
      expect(service.status, SshStatus.failed);
      expect(remote.of('sftp_open'), isEmpty);
    });

    test('sftp on the shell client leaves the shell undisturbed', () async {
      final remote = await fixture();
      final service = newService();
      final output = StringBuffer();
      final sub = service.output.listen(output.write);
      addTearDown(sub.cancel);
      await service.connect(target(remote), verifyHost: accept);
      expect(service.connected, isTrue, reason: service.error);
      await eventually(() => output.toString().contains('fixture-stderr'));
      service.write('a');
      await eventually(() => output.toString().contains('echo:a'));
      final generation = service.generation;
      final authBefore = remote.of('auth_begin').length;
      final inputsBefore = remote.of('input').length;

      final sftp = await service.openSftpOnClient();
      sessions.add(sftp);
      await remote.waitFor('sftp_open');
      File('${root.path}/hello.txt').writeAsStringSync('hi');
      expect((await sftp.list('/')).single.name, 'hello.txt');
      await sftp.writeText('/note.txt', 'x', overwrite: false);

      service.write('b');
      await eventually(() => output.toString().contains('echo:b'));
      expect(remote.of('connection'), hasLength(1));
      expect(remote.of('auth_begin'), hasLength(authBefore));
      expect(remote.of('shell'), hasLength(1));
      expect(service.generation, generation);
      // Only the two typed bytes ever reached the shell channel.
      final inputs = remote
          .of('input')
          .skip(inputsBefore - 1)
          .map((e) => utf8.decode(base64Decode(e['data'] as String)))
          .join();
      expect(inputs, 'ab');
      expect(output.toString(), isNot(contains('hello')));

      // Closing the subsystem channel only ends that channel.
      await sftp.close();
      expect(service.connected, isTrue);
      service.write('c');
      await eventually(() => output.toString().contains('echo:c'));
      expect(remote.of('closed'), isEmpty);

      // Ending the shell connection ends later sftp sessions on it.
      final second = await service.openSftpOnClient();
      sessions.add(second);
      expect(second.isAlive, isTrue);
      service.disconnect();
      await eventually(() => !second.isAlive);
      await expectLater(second.list('/'), _fails(SftpErrorKind.connectionLost));
    });

    test(
      'shell fixture without sftp: open fails, shell keeps working',
      () async {
        final remote = await fixture(sftp: false);
        final service = newService();
        final output = StringBuffer();
        final sub = service.output.listen(output.write);
        addTearDown(sub.cancel);
        await service.connect(target(remote), verifyHost: accept);
        await expectLater(
          service.openSftpOnClient(),
          _fails(SftpErrorKind.unavailable),
        );
        expect(service.connected, isTrue);
        service.write('z');
        await eventually(() => output.toString().contains('echo:z'));
      },
    );

    test('openSftpOnClient before connecting is connectionLost', () async {
      await expectLater(
        newService().openSftpOnClient(),
        _fails(SftpErrorKind.connectionLost),
      );
    });

    test('connection loss surfaces as connectionLost', () async {
      final remote = await fixture();
      final session = await connect(remote);
      expect(await session.list('/'), isEmpty);
      await remote.disconnectClients();
      await eventually(() => !session.isAlive);
      await expectLater(
        session.stat('/'),
        _fails(SftpErrorKind.connectionLost),
      );
    });
  });

  group('browse and mutate', () {
    test('list sorts directories first and describes entries', () async {
      File('${root.path}/b.txt').writeAsBytesSync(List.filled(1234, 65));
      File('${root.path}/A.txt').writeAsStringSync('a');
      File('${root.path}/.hidden').writeAsStringSync('h');
      Directory('${root.path}/zdir').createSync();
      Directory('${root.path}/Adir').createSync();
      Link('${root.path}/link-to-dir').createSync('zdir');
      Link('${root.path}/link-to-file').createSync('A.txt');
      Link('${root.path}/broken').createSync('nowhere');
      Process.runSync('chmod', ['640', '${root.path}/b.txt']);
      final session = await connect();
      final entries = await session.list('/');
      expect(entries.map((e) => e.name), [
        'Adir',
        'link-to-dir',
        'zdir',
        '.hidden',
        'A.txt',
        'b.txt',
        'broken',
        'link-to-file',
      ]);
      final byName = {for (final e in entries) e.name: e};
      expect(byName['Adir']!.isDir, isTrue);
      expect(byName['Adir']!.isLink, isFalse);
      expect(byName['Adir']!.path, '/Adir');
      expect(byName['link-to-dir']!.isDir, isTrue);
      expect(byName['link-to-dir']!.isLink, isTrue);
      expect(byName['link-to-file']!.isFile, isTrue);
      expect(byName['link-to-file']!.isLink, isTrue);
      expect(byName['broken']!.isLink, isTrue);
      expect(byName['broken']!.isDir, isFalse);
      expect(byName['broken']!.isFile, isFalse);
      expect(byName['b.txt']!.size, 1234);
      expect(byName['b.txt']!.mode, '-rw-r-----');
      expect(byName['Adir']!.mode, startsWith('d'));
      expect(
        byName['b.txt']!.mtime!.difference(DateTime.now()).abs().inMinutes,
        lessThan(2),
      );
      expect((await session.stat('/b.txt')).size, 1234);
      expect((await session.stat('/link-to-dir')).isDir, isTrue);
      await expectLater(
        session.list('/missing'),
        _fails(SftpErrorKind.notFound),
      );
      await expectLater(session.list('/b.txt'), throwsA(isA<SftpException>()));
    });

    test('mkdir, createEmptyFile and rename refuse to clobber', () async {
      final session = await connect();
      await session.mkdir('/docs');
      expect(Directory('${root.path}/docs').existsSync(), isTrue);
      await expectLater(session.mkdir('/docs'), _fails(SftpErrorKind.exists));
      await expectLater(
        session.mkdir('/no/such/parent'),
        _fails(SftpErrorKind.notFound),
      );
      await session.createEmptyFile('/docs/a.txt');
      expect(inRoot('docs/a.txt').lengthSync(), 0);
      inRoot('docs/a.txt').writeAsStringSync('keep');
      await expectLater(
        session.createEmptyFile('/docs/a.txt'),
        _fails(SftpErrorKind.exists),
      );
      expect(inRoot('docs/a.txt').readAsStringSync(), 'keep');
      await expectLater(
        session.createEmptyFile('/docs'),
        _fails(SftpErrorKind.exists),
      );

      inRoot('docs/b.txt').writeAsStringSync('other');
      await expectLater(
        session.rename('/docs/a.txt', '/docs/b.txt'),
        _fails(SftpErrorKind.exists),
      );
      expect(inRoot('docs/b.txt').readAsStringSync(), 'other');
      await session.rename('/docs/a.txt', '/docs/c.txt');
      expect(rootNames('docs'), ['b.txt', 'c.txt']);
      await session.mkdir('/other');
      await session.rename('/docs/c.txt', '/other/c.txt'); // move
      expect(inRoot('other/c.txt').readAsStringSync(), 'keep');
      await expectLater(
        session.rename('/docs/ghost', '/docs/x'),
        _fails(SftpErrorKind.notFound),
      );
    });

    test('delete file and empty directory with refined errors', () async {
      Directory('${root.path}/full').createSync();
      File('${root.path}/full/x').writeAsStringSync('x');
      Directory('${root.path}/empty').createSync();
      File('${root.path}/f').writeAsStringSync('f');
      final session = await connect();
      await expectLater(
        session.deleteEmptyDirectory('/full'),
        _fails(SftpErrorKind.notEmpty),
      );
      await expectLater(
        session.deleteFile('/full'),
        _fails(SftpErrorKind.wrongType),
      );
      await expectLater(
        session.deleteEmptyDirectory('/f'),
        _fails(SftpErrorKind.wrongType),
      );
      await session.deleteEmptyDirectory('/empty');
      await session.deleteFile('/f');
      expect(rootNames(), ['full']);
      await expectLater(
        session.deleteFile('/f'),
        _fails(SftpErrorKind.notFound),
      );
      await expectLater(
        session.deleteEmptyDirectory('/empty'),
        _fails(SftpErrorKind.notFound),
      );
    });

    test('deleteRecursive removes a tree and never follows links', () async {
      Directory('${root.path}/keep').createSync();
      File('${root.path}/keep/precious').writeAsStringSync('p');
      Directory('${root.path}/tree/a/b').createSync(recursive: true);
      Directory('${root.path}/tree/empty').createSync();
      File('${root.path}/tree/a/b/f1').writeAsStringSync('1');
      File('${root.path}/tree/f2').writeAsStringSync('2');
      Link('${root.path}/tree/a/link').createSync('../../keep');
      final session = await connect();
      final removed = await session.deleteRecursive('/tree');
      expect(removed, 7); // tree, a, b, empty, f1, f2, link
      expect(rootNames(), ['keep']);
      expect(inRoot('keep/precious').readAsStringSync(), 'p');
      await expectLater(
        session.deleteRecursive('/tree'),
        _fails(SftpErrorKind.notFound),
      );
      // A plain file works too.
      File('${root.path}/solo').writeAsStringSync('s');
      expect(await session.deleteRecursive('/solo'), 1);
    });

    test('deleteRecursive guard deletes nothing when too large', () async {
      Directory('${root.path}/big').createSync();
      for (var i = 0; i < 12; i++) {
        File('${root.path}/big/f$i').writeAsStringSync('$i');
      }
      final session = await connect();
      await expectLater(
        session.deleteRecursive('/big', maxEntries: 10),
        _fails(SftpErrorKind.tooManyEntries),
      );
      expect(rootNames('big'), hasLength(12));
      expect(await session.deleteRecursive('/big', maxEntries: 13), 13);
      expect(rootNames(), isEmpty);
    });

    test('deleteRecursive refuses roots and relative escapes', () async {
      File('${root.path}/f').writeAsStringSync('f');
      final session = await connect();
      for (final path in ['/', '//', '.', '..', '/a/../b', '/a/.', '']) {
        await expectLater(
          session.deleteRecursive(path),
          _fails(SftpErrorKind.invalidPath),
          reason: path,
        );
      }
      expect(rootNames(), ['f']);
    });

    test('deleteRecursive can be cancelled between deletions', () async {
      Directory('${root.path}/t').createSync();
      for (var i = 0; i < 6; i++) {
        File('${root.path}/t/f$i').writeAsStringSync('$i');
      }
      final session = await connect();
      final cancel = SftpCancelToken()..cancel();
      await expectLater(
        session.deleteRecursive('/t', cancel: cancel),
        _fails(SftpErrorKind.cancelled),
      );
      expect(rootNames('t'), hasLength(6));
    });

    test('invalid paths are rejected locally', () async {
      final session = await connect();
      for (final path in ['', 'a\u0000b', 'x' * 5000]) {
        await expectLater(
          session.list(path),
          _fails(SftpErrorKind.invalidPath),
        );
      }
    });
  });

  group('text', () {
    test('readText decodes UTF-8 and reports size and mtime', () async {
      inRoot('t.txt').writeAsStringSync('héllo 你好 😀\r\nline2\n');
      final session = await connect();
      final file = await session.readText('/t.txt');
      expect(file.text, 'héllo 你好 😀\r\nline2\n');
      expect(file.size, utf8.encode(file.text).length);
      expect(file.mtime, isNotNull);
      inRoot('empty').writeAsBytesSync([]);
      expect((await session.readText('/empty')).text, '');
    });

    test('readText enforces size limits even when stat is wrong', () async {
      inRoot('exact').writeAsBytesSync(List.filled(100, 0x61));
      inRoot('over').writeAsBytesSync(List.filled(101, 0x61));
      final session = await connect();
      expect((await session.readText('/exact', maxBytes: 100)).size, 100);
      await expectLater(
        session.readText('/over', maxBytes: 100),
        _fails(SftpErrorKind.tooLarge),
      );
      inRoot('large').writeAsBytesSync(
        Uint8List(sftpDefaultTextLimit + 1)
          ..fillRange(0, sftpDefaultTextLimit + 1, 0x61),
      );
      await expectLater(
        session.readText('/large'),
        _fails(SftpErrorKind.tooLarge),
      );
    });

    test('readText rejects binary, invalid UTF-8, directories', () async {
      inRoot('bin').writeAsBytesSync([0x61, 0, 0x62]);
      inRoot('bad').writeAsBytesSync([0x61, 0xff, 0xfe]);
      inRoot('truncated').writeAsBytesSync([0xe4, 0xbd]);
      Directory('${root.path}/dir').createSync();
      final session = await connect();
      await expectLater(
        session.readText('/bin'),
        _fails(SftpErrorKind.notText),
      );
      await expectLater(
        session.readText('/bad'),
        _fails(SftpErrorKind.notText),
      );
      await expectLater(
        session.readText('/truncated'),
        _fails(SftpErrorKind.notText),
      );
      await expectLater(
        session.readText('/dir'),
        _fails(SftpErrorKind.wrongType),
      );
      await expectLater(
        session.readText('/absent'),
        _fails(SftpErrorKind.notFound),
      );
    });

    test(
      'writeText honours the overwrite rule and leaves no temp files',
      () async {
        final session = await connect();
        await session.writeText('/new.txt', '你好\n', overwrite: false);
        expect(inRoot('new.txt').readAsStringSync(), '你好\n');
        await expectLater(
          session.writeText('/new.txt', 'clobber', overwrite: false),
          _fails(SftpErrorKind.exists),
        );
        expect(inRoot('new.txt').readAsStringSync(), '你好\n');
        expect(rootNames(), ['new.txt']);

        Process.runSync('chmod', ['600', '${root.path}/new.txt']);
        await session.writeText('/new.txt', 'second', overwrite: true);
        expect(inRoot('new.txt').readAsStringSync(), 'second');
        expect(
          (inRoot('new.txt').statSync().mode & 0x1ff).toRadixString(8),
          '600',
          reason: 'permission bits of the replaced file are kept',
        );
        // Overwrite of a missing path simply creates it.
        await session.writeText('/fresh', 'f', overwrite: true);
        expect(rootNames(), ['fresh', 'new.txt']);
        // Directories are never replaced.
        Directory('${root.path}/d').createSync();
        await expectLater(
          session.writeText('/d', 'x', overwrite: true),
          _fails(SftpErrorKind.wrongType),
        );
        await expectLater(
          session.writeText('/d', 'x', overwrite: false),
          _fails(SftpErrorKind.exists),
        );
        await expectLater(
          session.writeText('/nodir/x', 'x', overwrite: false),
          _fails(SftpErrorKind.notFound),
        );
        expect(rootNames(), ['d', 'fresh', 'new.txt']);
        // Too large text is refused before anything is written.
        await expectLater(
          session.writeText('/big', 'abcdef', overwrite: false, maxBytes: 5),
          _fails(SftpErrorKind.tooLarge),
        );
        expect(rootNames(), ['d', 'fresh', 'new.txt']);
      },
    );

    test(
      'writeText through a symlink replaces the target, not the link',
      () async {
        inRoot('real.txt').writeAsStringSync('old');
        Link('${root.path}/alias.txt').createSync('real.txt');
        final session = await connect();
        await session.writeText('/alias.txt', 'new', overwrite: true);
        expect(Link('${root.path}/alias.txt').existsSync(), isTrue);
        expect(inRoot('real.txt').readAsStringSync(), 'new');
        expect(rootNames(), ['alias.txt', 'real.txt']);
      },
    );
  });

  group('transfers', () {
    test('upload and download round trip with progress', () async {
      final data = pattern(1024 * 1024 + 123);
      final source = local('source.bin')..writeAsBytesSync(data);
      final session = await connect();
      final up = <int>[];
      int? upTotal;
      await session.upload(
        source,
        '/uploaded.bin',
        onProgress: (done, total) {
          up.add(done);
          upTotal = total;
        },
      );
      expect(up, isNotEmpty);
      expect(up.last, data.length);
      expect(upTotal, data.length);
      for (var i = 1; i < up.length; i++) {
        expect(up[i], greaterThanOrEqualTo(up[i - 1]));
      }
      expect(inRoot('uploaded.bin').readAsBytesSync(), data);
      expect(rootNames(), ['uploaded.bin'], reason: 'no temp leftovers');

      final target = local('nested/dir/down.bin');
      final down = <int>[];
      await session.download(
        '/uploaded.bin',
        target,
        onProgress: (done, total) {
          down.add(done);
          expect(total, data.length);
        },
      );
      expect(down.last, data.length);
      expect(target.readAsBytesSync(), data);
      expect(
        Directory('${work.path}/nested/dir').listSync().map((e) => e.path),
        [target.path],
      );
    });

    test('zero-byte files transfer', () async {
      final empty = local('empty')..writeAsBytesSync([]);
      final session = await connect();
      await session.upload(empty, '/empty');
      expect(inRoot('empty').lengthSync(), 0);
      final copy = local('copy');
      await session.download('/empty', copy);
      expect(copy.lengthSync(), 0);
    });

    test('upload and download refuse to overwrite unless asked', () async {
      final source = local('s')..writeAsStringSync('new');
      inRoot('there').writeAsStringSync('old');
      final session = await connect();
      await expectLater(
        session.upload(source, '/there'),
        _fails(SftpErrorKind.exists),
      );
      expect(inRoot('there').readAsStringSync(), 'old');
      expect(rootNames(), ['there'], reason: 'existing file not removed');
      await session.upload(source, '/there', overwrite: true);
      expect(inRoot('there').readAsStringSync(), 'new');

      final dest = local('dest')..writeAsStringSync('local-old');
      await expectLater(
        session.download('/there', dest),
        _fails(SftpErrorKind.exists),
      );
      expect(dest.readAsStringSync(), 'local-old');
      await session.download('/there', dest, overwrite: true);
      expect(dest.readAsStringSync(), 'new');
      expect(
        work
            .listSync()
            .map((e) => e.path.split('/').last)
            .where((n) => n.endsWith('.part')),
        isEmpty,
      );
    });

    test('download rejects directories and missing files', () async {
      Directory('${root.path}/d').createSync();
      final session = await connect();
      await expectLater(
        session.download('/d', local('x')),
        _fails(SftpErrorKind.wrongType),
      );
      await expectLater(
        session.download('/nope', local('x')),
        _fails(SftpErrorKind.notFound),
      );
      expect(local('x').existsSync(), isFalse);
      await expectLater(
        session.upload(local('missing-local'), '/y'),
        _fails(SftpErrorKind.localFile),
      );
      expect(rootNames(), ['d']);
    });

    test('cancelled download removes the partial local file', () async {
      inRoot('big.bin').writeAsBytesSync(pattern(12 * 1024 * 1024));
      final session = await connect();
      final cancel = SftpCancelToken();
      final dest = local('out/big.bin');
      var calls = 0;
      await expectLater(
        session.download(
          '/big.bin',
          dest,
          cancel: cancel,
          onProgress: (done, total) {
            calls++;
            if (calls == 2) cancel.cancel();
          },
        ),
        _fails(SftpErrorKind.cancelled),
      );
      expect(calls, lessThan(40), reason: 'stops promptly, not at the end');
      expect(dest.existsSync(), isFalse);
      expect(Directory('${work.path}/out').listSync(), isEmpty);
      // The session is still usable after a cancel.
      expect((await session.stat('/big.bin')).size, 12 * 1024 * 1024);
    });

    test('pre-cancelled transfers do nothing', () async {
      final source = local('s')..writeAsStringSync('x');
      final session = await connect();
      final cancel = SftpCancelToken()..cancel();
      await expectLater(
        session.upload(source, '/u', cancel: cancel),
        _fails(SftpErrorKind.cancelled),
      );
      await expectLater(
        session.download('/u', local('d'), cancel: cancel),
        _fails(SftpErrorKind.cancelled),
      );
      expect(rootNames(), isEmpty);
    });

    test('cancelled upload cleans up and keeps an existing target', () async {
      final source = local('big.bin')..writeAsBytesSync(pattern(4 << 20));
      inRoot('target.bin').writeAsStringSync('original');
      final session = await connect();
      final cancel = SftpCancelToken();
      var calls = 0;
      await expectLater(
        session.upload(
          source,
          '/target.bin',
          overwrite: true,
          cancel: cancel,
          onProgress: (done, total) {
            calls++;
            if (calls == 2) cancel.cancel();
          },
        ),
        _fails(SftpErrorKind.cancelled),
      );
      expect(calls, lessThan(40));
      expect(inRoot('target.bin').readAsStringSync(), 'original');
      expect(rootNames(), ['target.bin']);

      // Without overwrite the reserved placeholder is removed again.
      final again = SftpCancelToken();
      calls = 0;
      await expectLater(
        session.upload(
          source,
          '/fresh.bin',
          cancel: again,
          onProgress: (done, total) {
            calls++;
            if (calls == 2) again.cancel();
          },
        ),
        _fails(SftpErrorKind.cancelled),
      );
      expect(rootNames(), ['target.bin']);
      // Still usable.
      await session.writeText('/ok.txt', 'ok', overwrite: false);
      expect(inRoot('ok.txt').readAsStringSync(), 'ok');
    });

    test('connection loss during upload leaves no completed target', () async {
      final remote = await fixture();
      final session = await connect(remote);
      final source = local('big.bin')..writeAsBytesSync(pattern(4 << 20));
      var calls = 0;
      await expectLater(
        session.upload(
          source,
          '/lost.bin',
          onProgress: (done, total) {
            if (++calls == 2) remote.abortClients();
          },
        ),
        _fails(SftpErrorKind.connectionLost),
      );
      expect(
        inRoot('lost.bin').lengthSync(),
        0,
        reason: 'only the placeholder',
      );
    });
  });

  group('permissions and confinement', () {
    final isRoot =
        Process.runSync('id', ['-u']).stdout.toString().trim() == '0';

    test('permission denied is reported precisely', () async {
      Directory('${root.path}/locked').createSync();
      File('${root.path}/locked/x').writeAsStringSync('x');
      Directory('${root.path}/readonly').createSync();
      File('${root.path}/secret').writeAsStringSync('s');
      Process.runSync('chmod', ['000', '${root.path}/locked']);
      Process.runSync('chmod', ['555', '${root.path}/readonly']);
      Process.runSync('chmod', ['000', '${root.path}/secret']);
      final session = await connect();
      await expectLater(
        session.list('/locked'),
        _fails(SftpErrorKind.permissionDenied),
      );
      await expectLater(
        session.readText('/locked/x'),
        _fails(SftpErrorKind.permissionDenied),
      );
      await expectLater(
        session.readText('/secret'),
        _fails(SftpErrorKind.permissionDenied),
      );
      await expectLater(
        session.download('/secret', local('s')),
        _fails(SftpErrorKind.permissionDenied),
      );
      expect(local('s').existsSync(), isFalse);
      await expectLater(
        session.mkdir('/readonly/sub'),
        _fails(SftpErrorKind.permissionDenied),
      );
      await expectLater(
        session.createEmptyFile('/readonly/f'),
        _fails(SftpErrorKind.permissionDenied),
      );
      await expectLater(
        session.writeText('/readonly/f', 'x', overwrite: false),
        _fails(SftpErrorKind.permissionDenied),
      );
      await expectLater(
        session.upload(local('s')..writeAsStringSync('x'), '/readonly/u'),
        _fails(SftpErrorKind.permissionDenied),
      );
      await expectLater(
        session.deleteFile('/readonly/../locked/x'),
        _fails(SftpErrorKind.permissionDenied),
      );
      Process.runSync('chmod', ['755', '${root.path}/readonly']);
      expect(rootNames('readonly'), isEmpty, reason: 'nothing leaked');
      // Metadata of a locked directory is still readable.
      expect((await session.stat('/locked')).isDir, isTrue);
    }, skip: isRoot ? 'permission bits do not apply to uid 0' : false);

    test('paths cannot escape the root', () async {
      File('${outside.path}/secret.txt').writeAsStringSync('top secret');
      File('${root.path}/inside.txt').writeAsStringSync('inside');
      final session = await connect();
      expect(await session.realpath('/../../..'), '/');
      expect(await session.realpath('/../outside'), '/outside');
      expect((await session.list('/../..')).map((e) => e.name), ['inside.txt']);
      await expectLater(
        session.readText('/../outside/secret.txt'),
        _fails(SftpErrorKind.notFound),
      );
      await expectLater(
        session.readText('../../../../etc/hosts'),
        _fails(SftpErrorKind.notFound),
      );
      await expectLater(
        session.download('/../outside/secret.txt', local('stolen')),
        _fails(SftpErrorKind.notFound),
      );
      await session.writeText('/../escaped.txt', 'x', overwrite: false);
      expect(File('${work.path}/escaped.txt').existsSync(), isFalse);
      expect(inRoot('escaped.txt').existsSync(), isTrue);
      await expectLater(
        session.deleteRecursive('/../outside'),
        _fails(SftpErrorKind.invalidPath),
      );
      expect(File('${outside.path}/secret.txt').existsSync(), isTrue);
    });
  });

  group('SftpPath', () {
    test('join, parent, basename and name validation', () {
      expect(SftpPath.join('/', 'a'), '/a');
      expect(SftpPath.join('/a', 'b'), '/a/b');
      expect(SftpPath.join('/a/', 'b'), '/a/b');
      expect(SftpPath.parent('/a/b'), '/a');
      expect(SftpPath.parent('/a'), '/');
      expect(SftpPath.parent('/'), '/');
      expect(SftpPath.parent('a'), '.');
      expect(SftpPath.parent('/a/b/'), '/a');
      expect(SftpPath.basename('/a/b'), 'b');
      expect(SftpPath.basename('/a/b/'), 'b');
      expect(SftpPath.basename('/'), '/');
      expect(SftpPath.basename('x'), 'x');
      for (final bad in ['', '.', '..', 'a/b', 'a\u0000']) {
        expect(SftpPath.isValidName(bad), isFalse, reason: bad);
      }
      expect(SftpPath.isValidName('名前 with space.txt'), isTrue);
    });
  });
}
