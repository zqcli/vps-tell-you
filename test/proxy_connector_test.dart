import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/connections/proxy_connector.dart';
import 'package:vps_tell_you/security/proxy_models.dart';

import 'support/fake_proxy.dart';
import 'support/proxy_tls.dart';

/// Echoes everything after an optional banner.
Future<ServerSocket> echoServer({String address = '127.0.0.1'}) async {
  final server = await ServerSocket.bind(address, 0);
  server.listen((client) {
    client.listen(client.add, onError: (Object _) {}, onDone: client.destroy);
  });
  return server;
}

Future<ProxyException> failure(ProxyDial dial) async {
  try {
    await dial.tunnel;
  } on ProxyException catch (error) {
    return error;
  }
  fail('expected a ProxyException');
}

Future<void> expectEcho(ProxyTunnel tunnel) async {
  final received = <int>[];
  final done = Completer<void>();
  final sub = tunnel.incoming.listen((chunk) {
    received.addAll(chunk);
    if (received.length >= 5 && !done.isCompleted) done.complete();
  });
  tunnel.socket.add(utf8.encode('hello'));
  await done.future.timeout(const Duration(seconds: 5));
  expect(utf8.decode(received), 'hello');
  await sub.cancel();
  tunnel.destroy();
}

void main() {
  late ServerSocket echo;
  late ProxyTls tls;
  final proxies = <FakeProxy>[];

  setUpAll(() async => tls = await ProxyTls.load());
  setUp(() async => echo = await echoServer());
  tearDown(() async {
    await echo.close();
    for (final p in proxies) {
      await p.close();
    }
    proxies.clear();
  });

  Future<FakeProxy> start(
    ProxyKind kind, [
    FakeProxyOptions options = const FakeProxyOptions(),
  ]) async {
    final proxy = await FakeProxy.start(
      kind,
      options: options,
      serverContext: kind == ProxyKind.https ? tls.serverContext : null,
    );
    proxies.add(proxy);
    return proxy;
  }

  ProxyDial dial(
    FakeProxy proxy, {
    String host = '127.0.0.1',
    int? port,
    String? user,
    String? pass,
    SecurityContext? context,
    Duration? timeout,
  }) => ProxyDial(
    proxy: proxy.endpoint(username: user, password: pass),
    host: host,
    port: port ?? echo.port,
    tlsContext:
        context ?? (proxy.kind == ProxyKind.https ? tls.trustTestCa() : null),
    timeout: timeout,
  );

  group('SOCKS5', () {
    test('no authentication, IPv4 address type', () async {
      final proxy = await start(ProxyKind.socks5);
      final tunnel = await dial(proxy).tunnel;
      await expectEcho(tunnel);
      expect(proxy.requests.single.atyp, 1);
      expect(proxy.requests.single.host, '127.0.0.1');
      expect(proxy.requests.single.port, echo.port);
    });

    test('a name is sent to the proxy, never resolved locally', () async {
      final proxy = await start(
        ProxyKind.socks5,
        FakeProxyOptions(
          hosts: {'only-the-proxy-knows.test': '127.0.0.1:${echo.port}'},
        ),
      );
      final tunnel = await dial(
        proxy,
        host: 'only-the-proxy-knows.test',
      ).tunnel;
      await expectEcho(tunnel);
      expect(proxy.requests.single.atyp, 3);
      expect(proxy.requests.single.host, 'only-the-proxy-knows.test');
    });

    test('IPv6 address type', () async {
      ServerSocket? v6;
      try {
        v6 = await echoServer(address: '::1');
      } on SocketException {
        return; // no IPv6 loopback on this machine
      }
      addTearDown(v6.close);
      final proxy = await start(ProxyKind.socks5);
      final tunnel = await dial(proxy, host: '::1', port: v6.port).tunnel;
      await expectEcho(tunnel);
      expect(proxy.requests.single.atyp, 4);
      expect(proxy.requests.single.host, '::1');
    });

    test('username and password (RFC 1929)', () async {
      final proxy = await start(
        ProxyKind.socks5,
        const FakeProxyOptions(username: 'üser', password: 'pässword'),
      );
      final tunnel = await dial(proxy, user: 'üser', pass: 'pässword').tunnel;
      await expectEcho(tunnel);
      expect(proxy.requests.single.username, 'üser');
    });

    test('wrong password is reported as rejected credentials', () async {
      final proxy = await start(
        ProxyKind.socks5,
        const FakeProxyOptions(username: 'u', password: 'right'),
      );
      final error = await failure(dial(proxy, user: 'u', pass: 'wrong'));
      expect(error.failure, ProxyFailure.authRejected);
      expect(proxy.authFailures, 1);
    });

    test('a proxy demanding authentication without credentials', () async {
      final proxy = await start(
        ProxyKind.socks5,
        const FakeProxyOptions(username: 'u', password: 'p'),
      );
      expect((await failure(dial(proxy))).failure, ProxyFailure.authRequired);
    });

    test('every reply code maps to its own failure', () async {
      const expected = {
        1: ProxyFailure.socksGeneral,
        2: ProxyFailure.socksNotAllowed,
        3: ProxyFailure.socksNetworkUnreachable,
        4: ProxyFailure.socksHostUnreachable,
        5: ProxyFailure.socksRefused,
        6: ProxyFailure.socksTtlExpired,
        7: ProxyFailure.socksCommandUnsupported,
        8: ProxyFailure.socksAddressUnsupported,
        99: ProxyFailure.socksGeneral,
      };
      for (final entry in expected.entries) {
        final proxy = await start(
          ProxyKind.socks5,
          FakeProxyOptions(socksReply: entry.key),
        );
        expect(
          (await failure(dial(proxy))).failure,
          entry.value,
          reason: '${entry.key}',
        );
      }
    });

    test('the target refusing is a refused failure (proxy dials it)', () async {
      final closed = await ServerSocket.bind('127.0.0.1', 0);
      final port = closed.port;
      await closed.close();
      final proxy = await start(ProxyKind.socks5);
      final error = await failure(dial(proxy, port: port));
      expect(error.targetRefused, isTrue);
    });

    test(
      'bytes behind the reply belong to the tunnel; split replies work',
      () async {
        final banner = utf8.encode('SSH-2.0-early\r\n');
        for (final split in [false, true]) {
          final proxy = await start(
            ProxyKind.socks5,
            FakeProxyOptions(earlyData: banner, splitReply: split),
          );
          final tunnel = await dial(proxy).tunnel;
          final first = await tunnel.incoming.first.timeout(
            const Duration(seconds: 5),
          );
          expect(first, banner, reason: 'split=$split');
          tunnel.destroy();
        }
      },
    );

    test('a proxy that answers nothing times out', () async {
      final proxy = await start(
        ProxyKind.socks5,
        const FakeProxyOptions(silent: true),
      );
      final error = await failure(
        dial(proxy, timeout: const Duration(milliseconds: 200)),
      );
      expect(error.failure, ProxyFailure.timeout);
    });

    test('cancel stops the attempt and closes the proxy connection', () async {
      final proxy = await start(
        ProxyKind.socks5,
        const FakeProxyOptions(silent: true),
      );
      final attempt = dial(proxy);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      attempt.cancel();
      expect((await failure(attempt)).failure, ProxyFailure.cancelled);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // The proxy's end sees EOF: nothing is left open on our side.
      expect(proxy.eofs, 1);
    });

    test('cancel before the connection exists leaves nothing behind', () async {
      final proxy = await start(ProxyKind.socks5);
      final attempt = dial(proxy)..cancel();
      expect((await failure(attempt)).failure, ProxyFailure.cancelled);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(proxy.eofs, proxy.accepted);
    });

    test('a refused connection to the proxy itself', () async {
      final closed = await ServerSocket.bind('127.0.0.1', 0);
      final port = closed.port;
      await closed.close();
      final attempt = ProxyDial(
        proxy: ProxyEndpoint(
          kind: ProxyKind.socks5,
          host: '127.0.0.1',
          port: port,
        ),
        host: '127.0.0.1',
        port: 22,
      );
      expect((await failure(attempt)).failure, ProxyFailure.unreachable);
    });

    test(
      'invalid targets and credentials are refused before any I/O',
      () async {
        final proxy = await start(ProxyKind.socks5);
        expect(
          (await failure(dial(proxy, host: 'fe80::1%en0'))).failure,
          ProxyFailure.invalidTarget,
        );
        expect(
          (await failure(dial(proxy, host: 'bad host'))).failure,
          ProxyFailure.invalidTarget,
        );
        expect(
          (await failure(dial(proxy, user: 'u', pass: ''))).failure,
          ProxyFailure.invalidProxy,
        );
        expect(proxy.accepted, 0);
      },
    );
  });

  group('HTTP CONNECT', () {
    test('200 with Basic authentication', () async {
      final proxy = await start(
        ProxyKind.http,
        const FakeProxyOptions(username: 'üser', password: 'p:ass'),
      );
      final tunnel = await dial(proxy, user: 'üser', pass: 'p:ass').tunnel;
      await expectEcho(tunnel);
      final request = proxy.requests.single;
      expect(request.authority, '127.0.0.1:${echo.port}');
      expect(
        request.rawHeader,
        startsWith('CONNECT 127.0.0.1:${echo.port} HTTP/1.1'),
      );
      expect(request.rawHeader, contains('Host: 127.0.0.1:${echo.port}'));
      expect(
        request.rawHeader,
        contains(
          'Proxy-Authorization: Basic ${base64.encode(utf8.encode('üser:p:ass'))}',
        ),
      );
    });

    test('no credentials are sent unless configured', () async {
      final proxy = await start(ProxyKind.http);
      await expectEcho(await dial(proxy).tunnel);
      expect(
        proxy.requests.single.rawHeader!.toLowerCase(),
        isNot(contains('authorization')),
      );
    });

    test('407 means credentials are required or were rejected', () async {
      final proxy = await start(
        ProxyKind.http,
        const FakeProxyOptions(username: 'u', password: 'p'),
      );
      final none = await failure(dial(proxy));
      expect(none.failure, ProxyFailure.authRequired);
      expect(none.httpStatus, 407);
      final wrong = await failure(dial(proxy, user: 'u', pass: 'nope'));
      expect(wrong.failure, ProxyFailure.authRejected);
    });

    test('502 and other statuses carry the status number', () async {
      for (final status in [502, 403, 503]) {
        final proxy = await start(
          ProxyKind.http,
          FakeProxyOptions(httpStatus: status),
        );
        final error = await failure(dial(proxy));
        expect(error.failure, ProxyFailure.httpStatus);
        expect(error.httpStatus, status);
      }
    });

    test('a header split into single bytes and early tunnel data', () async {
      final banner = utf8.encode('SSH-2.0-early\r\n');
      final proxy = await start(
        ProxyKind.http,
        FakeProxyOptions(splitReply: true, earlyData: banner),
      );
      final tunnel = await dial(proxy).tunnel;
      expect(
        await tunnel.incoming.first.timeout(const Duration(seconds: 5)),
        banner,
      );
      tunnel.destroy();
      final together = await start(
        ProxyKind.http,
        FakeProxyOptions(earlyData: banner),
      );
      final second = await dial(together).tunnel;
      expect(
        await second.incoming.first.timeout(const Duration(seconds: 5)),
        banner,
      );
      second.destroy();
    });

    test('IPv6 literals are bracketed in the CONNECT authority', () async {
      ServerSocket? v6;
      try {
        v6 = await echoServer(address: '::1');
      } on SocketException {
        return;
      }
      addTearDown(v6.close);
      final proxy = await start(ProxyKind.http);
      await expectEcho(await dial(proxy, host: '::1', port: v6.port).tunnel);
      expect(proxy.requests.single.authority, '[::1]:${v6.port}');
    });

    test('a name is sent as host:port', () async {
      final proxy = await start(
        ProxyKind.http,
        FakeProxyOptions(
          hosts: {'only-the-proxy-knows.test': '127.0.0.1:${echo.port}'},
        ),
      );
      await expectEcho(
        await dial(proxy, host: 'only-the-proxy-knows.test').tunnel,
      );
      expect(
        proxy.requests.single.authority,
        'only-the-proxy-knows.test:${echo.port}',
      );
    });

    test('a response header over 16 KiB is refused', () async {
      final proxy = await start(
        ProxyKind.http,
        const FakeProxyOptions(oversizedHeader: true),
      );
      expect((await failure(dial(proxy))).failure, ProxyFailure.protocol);
    });

    test('a non-HTTP answer is a protocol error', () async {
      final junk = await ServerSocket.bind('127.0.0.1', 0);
      addTearDown(junk.close);
      junk.listen((c) {
        c.add(utf8.encode('SSH-2.0-not-a-proxy\r\n\r\n'));
        c.listen((_) {}, onError: (Object _) {});
      });
      final attempt = ProxyDial(
        proxy: ProxyEndpoint(
          kind: ProxyKind.http,
          host: '127.0.0.1',
          port: junk.port,
        ),
        host: '127.0.0.1',
        port: 22,
      );
      expect((await failure(attempt)).failure, ProxyFailure.protocol);
    });

    test('the proxy closing early is reported as closed', () async {
      final closing = await ServerSocket.bind('127.0.0.1', 0);
      addTearDown(closing.close);
      closing.listen((c) => c.destroy());
      final attempt = ProxyDial(
        proxy: ProxyEndpoint(
          kind: ProxyKind.http,
          host: '127.0.0.1',
          port: closing.port,
        ),
        host: '127.0.0.1',
        port: 22,
      );
      expect((await failure(attempt)).failure, ProxyFailure.closed);
    });

    test('a username with a colon cannot be sent as Basic', () async {
      final proxy = await start(ProxyKind.http);
      expect(
        (await failure(dial(proxy, user: 'a:b', pass: 'p'))).failure,
        ProxyFailure.invalidProxy,
      );
    });
  });

  group('HTTPS proxy', () {
    test('TLS to the proxy, then CONNECT, with the test CA trusted', () async {
      final proxy = await start(
        ProxyKind.https,
        const FakeProxyOptions(username: 'u', password: 'p'),
      );
      final tunnel = await dial(proxy, user: 'u', pass: 'p').tunnel;
      await expectEcho(tunnel);
      expect(proxy.requests.single.authority, '127.0.0.1:${echo.port}');
    });

    test('a certificate from another CA is refused', () async {
      final proxy = await start(ProxyKind.https);
      final error = await failure(dial(proxy, context: tls.trustOtherCa()));
      expect(error.failure, ProxyFailure.tlsFailed);
      expect(proxy.requests, isEmpty, reason: 'no CONNECT over a failed TLS');
    });

    test('the system trust store does not know the test CA', () async {
      final proxy = await start(ProxyKind.https);
      final attempt = ProxyDial(
        proxy: proxy.endpoint(),
        host: '127.0.0.1',
        port: echo.port,
      );
      expect((await failure(attempt)).failure, ProxyFailure.tlsFailed);
    });

    test('the proxy may be dialled by any name in its certificate', () async {
      final proxy = await start(ProxyKind.https);
      final attempt = ProxyDial(
        proxy: proxy.endpoint(host: 'localhost'),
        host: '127.0.0.1',
        port: echo.port,
        tlsContext: tls.trustTestCa(),
      );
      await expectEcho(await attempt.tunnel); // SAN has localhost
    });

    test('cancel during the TLS handshake', () async {
      final stall = await ServerSocket.bind('127.0.0.1', 0);
      addTearDown(stall.close);
      stall.listen((c) => c.listen((_) {}, onError: (Object _) {}));
      final attempt = ProxyDial(
        proxy: ProxyEndpoint(
          kind: ProxyKind.https,
          host: '127.0.0.1',
          port: stall.port,
        ),
        host: '127.0.0.1',
        port: 22,
        tlsContext: tls.trustTestCa(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      attempt.cancel();
      expect((await failure(attempt)).failure, ProxyFailure.cancelled);
    });
  });

  test('error text never contains host names or credentials', () {
    for (final failure in ProxyFailure.values) {
      final text = ProxyException(failure, httpStatus: 502).toString();
      expect(text, isNot(contains('127.0.0.1')));
      expect(text, startsWith('ProxyException('));
    }
  });

  test('the tunnel stream keeps data order under pause/resume', () async {
    final big = Uint8List.fromList(List.generate(300000, (i) => i % 251));
    final server = await ServerSocket.bind('127.0.0.1', 0);
    addTearDown(server.close);
    server.listen((c) {
      c.listen((_) {}, onError: (Object _) {});
      c.add(big);
      c.close();
    });
    final proxy = await start(ProxyKind.socks5);
    final tunnel = await dial(proxy, port: server.port).tunnel;
    final received = BytesBuilder();
    final done = Completer<void>();
    late StreamSubscription<Uint8List> sub;
    sub = tunnel.incoming.listen((chunk) {
      received.add(chunk);
      sub.pause(Future<void>.delayed(const Duration(milliseconds: 1)));
    }, onDone: done.complete);
    await done.future.timeout(const Duration(seconds: 20));
    expect(received.takeBytes(), big);
  });
}
