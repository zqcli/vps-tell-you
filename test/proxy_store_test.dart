import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/security/proxy_models.dart';
import 'package:vps_tell_you/security/secret_store.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'support/legacy_ledger_fixture.dart';

class FakeSecrets implements SecretStore {
  final values = <String, String>{};
  bool failWrite = false, failDelete = false, wrongRead = false;
  @override
  Future<String?> read(String reference) async =>
      wrongRead ? 'different payload' : values[reference];
  @override
  Future<void> write(String reference, String value) async {
    if (failWrite) throw StateError('DO-NOT-LEAK-$value');
    values[reference] = value;
  }

  @override
  Future<void> delete(String reference) async {
    if (failDelete) throw StateError('DO-NOT-LEAK');
    values.remove(reference);
  }
}

class FakeAuth implements DeviceAuthenticator {
  bool allowed = true;
  int calls = 0;
  @override
  Future<bool> authenticate() async {
    calls++;
    return allowed;
  }

  @override
  Future<void> cancel() async {}
}

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late LedgerStore store;
  late FakeSecrets secrets;
  late FakeAuth auth;
  late SecurityController security;
  final en = AppLocalizationsEn();

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('proxy-store-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.db',
    );
    secrets = FakeSecrets();
    auth = FakeAuth();
    security = SecurityController(
      store: store,
      secrets: secrets,
      authenticator: auth,
      revealDuration: const Duration(milliseconds: 200),
    );
    await security.initialize();
    await store.saveServer(
      ServerRecord(
        id: 's1',
        name: 'Server',
        vendor: 'V',
        host: '192.0.2.1',
        createdAt: fixtureTime,
        updatedAt: fixtureTime,
      ),
      isNew: true,
    );
  });
  tearDown(() async {
    security.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<String> add({
    String name = 'Office',
    ProxyKind kind = ProxyKind.socks5,
    String host = 'proxy.example.com',
    int port = 1080,
    String? user,
    String? pass,
  }) async {
    final id = await security.saveProxy(
      name: name,
      kind: kind,
      host: host,
      port: port,
      username: user,
      password: pass,
    );
    expect(id, isNotNull, reason: security.error);
    return id!;
  }

  List<String> proxySecrets() =>
      secrets.values.keys.where((k) => k.startsWith('vps_proxy_')).toList();

  test('password goes to secure storage only; metadata is plain', () async {
    final id = await add(user: 'alice', pass: 'p4ss-w0rd');
    final proxy = security.proxyById(id)!;
    expect(proxy.username, 'alice');
    expect(proxy.secretRef, startsWith('vps_proxy_'));
    expect(secrets.values[proxy.secretRef], contains('p4ss-w0rd'));
    final raw = await openRawLedger('${directory.path}/ledger.db');
    addTearDown(raw.close);
    for (final table in ['proxies', 'secret_cleanup', 'ssh_configurations']) {
      expect((await raw.query(table)).toString(), isNot(contains('p4ss-w0rd')));
    }
    expect(await store.pendingSecretCleanup(), isEmpty);
  });

  test('no username means no secret at all', () async {
    final id = await add();
    expect(security.proxyById(id)!.secretRef, isNull);
    expect(proxySecrets(), isEmpty);
  });

  test(
    'editing: blank password keeps it, a new one replaces and cleans up',
    () async {
      final id = await add(user: 'alice', pass: 'one');
      final first = security.proxyById(id)!;
      await security.saveProxy(
        existing: first,
        name: 'Renamed',
        kind: ProxyKind.socks5,
        host: 'proxy.example.com',
        port: 1081,
        username: 'alice',
      );
      final kept = security.proxyById(id)!;
      expect(kept.secretRef, first.secretRef);
      expect(kept.port, 1081);
      expect(kept.revision, first.revision + 1);

      await security.saveProxy(
        existing: kept,
        name: 'Renamed',
        kind: ProxyKind.socks5,
        host: 'proxy.example.com',
        port: 1081,
        username: 'alice',
        password: 'two',
      );
      final replaced = security.proxyById(id)!;
      expect(replaced.secretRef, isNot(first.secretRef));
      expect(proxySecrets(), [replaced.secretRef]);
      expect(await store.pendingSecretCleanup(), isEmpty);
    },
  );

  test('clearing the username removes the stored password', () async {
    final id = await add(user: 'alice', pass: 'one');
    await security.saveProxy(
      existing: security.proxyById(id),
      name: 'Office',
      kind: ProxyKind.socks5,
      host: 'proxy.example.com',
      port: 1080,
    );
    expect(security.proxyById(id)!.secretRef, isNull);
    expect(proxySecrets(), isEmpty);
  });

  test('validation: nothing is written for bad input', () async {
    Future<void> bad(
      String message, {
      String name = 'x',
      ProxyKind kind = ProxyKind.socks5,
      String host = 'h.example',
      int port = 1080,
      String? user,
      String? pass,
    }) async {
      expect(
        await security.saveProxy(
          name: name,
          kind: kind,
          host: host,
          port: port,
          username: user,
          password: pass,
        ),
        isNull,
        reason: message,
      );
      expect(security.error, isNotNull, reason: message);
    }

    await bad('empty name', name: ' ');
    await bad('bad host', host: 'not a host');
    await bad('zone id', host: 'fe80::1%en0');
    await bad('port', port: 0);
    await bad('port high', port: 70000);
    await bad('user without password', user: 'u');
    await bad('password without user', pass: 'p');
    await bad(
      'colon in http user',
      kind: ProxyKind.http,
      user: 'a:b',
      pass: 'p',
    );
    await bad('long password', user: 'u', pass: 'x' * 256);
    expect(await store.proxies(), isEmpty);
    expect(secrets.values, isEmpty);
    expect(await store.pendingSecretCleanup(), isEmpty);
  });

  test('IPv6 literal hosts are stored bare and canonical', () async {
    final id = await add(host: '[2001:DB8:0::1]');
    expect(security.proxyById(id)!.host, '2001:db8::1');
    expect(security.proxyById(id)!.address, '[2001:db8::1]:1080');
  });

  test(
    'a failed secret write leaves no proxy and a recoverable journal',
    () async {
      secrets.failWrite = true;
      final id = await security.saveProxy(
        name: 'x',
        kind: ProxyKind.socks5,
        host: 'h.example',
        port: 1080,
        username: 'u',
        password: 'secret',
      );
      expect(id, isNull);
      expect(security.error, isNot(contains('DO-NOT-LEAK')));
      expect(security.error, isNot(contains('secret')));
      expect(await store.proxies(), isEmpty);
      expect(await store.pendingSecretCleanup(), hasLength(1));
      secrets.failWrite = false;
      expect(await security.retryCleanup(), isTrue);
      expect(await store.pendingSecretCleanup(), isEmpty);
    },
  );

  test('an unverifiable write is not accepted', () async {
    secrets.wrongRead = true;
    expect(
      await security.saveProxy(
        name: 'x',
        kind: ProxyKind.socks5,
        host: 'h.example',
        port: 1080,
        username: 'u',
        password: 'secret',
      ),
      isNull,
    );
    expect(await store.proxies(), isEmpty);
  });

  test('deleting queues the secret and cleans it', () async {
    final id = await add(user: 'alice', pass: 'one');
    expect(await security.deleteProxy(security.proxyById(id)!), isTrue);
    expect(security.proxies, isEmpty);
    expect(proxySecrets(), isEmpty);
    expect(await store.pendingSecretCleanup(), isEmpty);
  });

  test('a failed secret delete stays queued and retries', () async {
    final id = await add(user: 'alice', pass: 'one');
    secrets.failDelete = true;
    expect(await security.deleteProxy(security.proxyById(id)!), isTrue);
    expect(security.cleanupPending, isTrue);
    expect(proxySecrets(), hasLength(1));
    secrets.failDelete = false;
    expect(await security.retryCleanup(), isTrue);
    expect(proxySecrets(), isEmpty);
  });

  test(
    'a live proxy secret is never deleted by a stale cleanup entry',
    () async {
      final id = await add(user: 'alice', pass: 'one');
      final ref = security.proxyById(id)!.secretRef!;
      expect(await store.secretIsReferenced(ref), isTrue);
    },
  );

  test('deleting a proxy that SSH settings use is refused', () async {
    final id = await add(user: 'alice', pass: 'one');
    await store.saveSshConfiguration(
      SshConfiguration(
        serverId: 's1',
        host: 'ssh.example.com',
        username: 'root',
        proxyId: id,
      ),
    );
    await security.reload();
    expect(security.proxyReferences(id), hasLength(1));
    expect(await security.deleteProxy(security.proxyById(id)!), isFalse);
    expect(security.errorFor(en), en.r13ProxyInUse);
    expect(security.proxyById(id), isNotNull);
    expect(proxySecrets(), hasLength(1), reason: 'secret untouched');

    final config = security.configFor('s1')!;
    expect(
      await security.saveSshConfiguration(
        SshConfiguration(
          serverId: 's1',
          host: config.host,
          username: config.username,
          revision: config.revision,
        ),
      ),
      isTrue,
    );
    expect(security.configFor('s1')!.proxyId, isNull);
    expect(await security.deleteProxy(security.proxyById(id)!), isTrue);
  });

  test('SSH settings cannot point at a proxy that does not exist', () async {
    await expectLater(
      store.saveSshConfiguration(
        SshConfiguration(
          serverId: 's1',
          host: 'ssh.example.com',
          username: 'root',
          proxyId: 'ghost',
        ),
      ),
      throwsA(isA<LedgerConflict>()),
    );
  });

  test('stale revisions conflict instead of overwriting', () async {
    final id = await add();
    final stale = security.proxyById(id)!;
    await security.saveProxy(
      existing: stale,
      name: 'A',
      kind: ProxyKind.socks5,
      host: 'proxy.example.com',
      port: 1080,
    );
    expect(
      await security.saveProxy(
        existing: stale,
        name: 'B',
        kind: ProxyKind.socks5,
        host: 'proxy.example.com',
        port: 1080,
      ),
      isNull,
    );
    expect(security.proxyById(id)!.name, 'A');
  });

  group('reveal requires device authentication', () {
    test('denied: nothing is shown', () async {
      final id = await add(user: 'alice', pass: 'visible-secret');
      auth.allowed = false;
      expect(await security.revealProxy(security.proxyById(id)!), isFalse);
      expect(security.revealedProxyPassword, isNull);
      expect(auth.calls, 1);
    });

    test('allowed: shown briefly, then hidden', () async {
      final id = await add(user: 'alice', pass: 'visible-secret');
      expect(await security.revealProxy(security.proxyById(id)!), isTrue);
      expect(security.revealedProxyPassword, 'visible-secret');
      expect(security.revealedProxyId, id);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(security.revealedProxyPassword, isNull);
    });

    test('nothing to reveal without a password', () async {
      final id = await add();
      expect(await security.revealProxy(security.proxyById(id)!), isFalse);
      expect(auth.calls, 0);
    });

    test('hideSensitive clears it', () async {
      final id = await add(user: 'alice', pass: 'visible-secret');
      await security.revealProxy(security.proxyById(id)!);
      security.hideSensitive();
      expect(security.revealedProxyPassword, isNull);
    });
  });

  test(
    'loadProxyEndpoint returns the password for the connection only',
    () async {
      final id = await add(
        kind: ProxyKind.http,
        user: 'alice',
        pass: 'conn-secret',
      );
      final endpoint = await security.loadProxyEndpoint(
        id,
        isCancelled: () => false,
      );
      expect(endpoint.kind, ProxyKind.http);
      expect(endpoint.password, 'conn-secret');
      expect(endpoint.toString(), isNot(contains('conn-secret')));
      expect(endpoint.toString(), isNot(contains('alice')));
      expect(auth.calls, 0, reason: 'connecting is not a reveal');
    },
  );
}
