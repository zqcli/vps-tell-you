import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:vps_tell_you/security/proxy_models.dart';

/// What a client asked a [FakeProxy] for (no secrets other than the synthetic
/// test ones the fixture itself was configured with).
class ProxyRequest {
  ProxyRequest({
    required this.host,
    required this.port,
    this.atyp,
    this.authority,
    this.username,
    this.rawHeader,
  });
  final String host;
  final int port;

  /// SOCKS5 address type (1 IPv4, 3 domain, 4 IPv6).
  final int? atyp;

  /// HTTP CONNECT request target, exactly as sent.
  final String? authority;
  final String? username;
  final String? rawHeader;
}

/// A loopback, in-process proxy speaking SOCKS5, HTTP CONNECT or CONNECT over
/// TLS, with switches to misbehave on purpose. Test-only.
class FakeProxy {
  FakeProxy._(this.kind, this._opts);

  final ProxyKind kind;
  final FakeProxyOptions _opts;
  ServerSocket? _plain;
  SecureServerSocket? _secure;
  final requests = <ProxyRequest>[];
  final connections = <Socket>[];
  int accepted = 0;
  int authFailures = 0;

  /// Client connections whose peer has closed (EOF seen).
  int eofs = 0;
  int get port => _plain?.port ?? _secure!.port;

  static Future<FakeProxy> start(
    ProxyKind kind, {
    FakeProxyOptions options = const FakeProxyOptions(),
    SecurityContext? serverContext,
    String address = '127.0.0.1',
  }) async {
    final proxy = FakeProxy._(kind, options);
    if (kind == ProxyKind.https) {
      proxy._secure = await SecureServerSocket.bind(address, 0, serverContext!);
      proxy._secure!.listen(
        proxy._handle,
        onError: (Object _) {}, // failed TLS handshakes are expected
      );
    } else {
      proxy._plain = await ServerSocket.bind(address, 0);
      proxy._plain!.listen(proxy._handle);
    }
    return proxy;
  }

  ProxyEndpoint endpoint({
    String? username,
    String? password,
    String host = '127.0.0.1',
  }) => ProxyEndpoint(
    kind: kind,
    host: host,
    port: port,
    username: username,
    password: password,
  );

  Future<void> close() async {
    await _plain?.close();
    await _secure?.close();
    for (final c in connections) {
      c.destroy();
    }
  }

  void _handle(Socket client) {
    accepted++;
    connections.add(client);
    final conn = _Conn(client, () => eofs++);
    unawaited(
      (kind == ProxyKind.socks5 ? _socks(conn) : _http(conn)).catchError((
        Object _,
      ) {
        client.destroy();
      }),
    );
  }

  Future<Socket?> _dial(String host, int port) async {
    final mapped = _opts.hosts[host];
    final target = mapped == null ? (host, port) : _split(mapped);
    try {
      return await Socket.connect(target.$1, target.$2);
    } catch (_) {
      return null;
    }
  }

  (String, int) _split(String value) {
    final i = value.lastIndexOf(':');
    return (value.substring(0, i), int.parse(value.substring(i + 1)));
  }

  Future<void> _pipe(_Conn client, Socket target, List<int> early) async {
    if (early.isNotEmpty) client.socket.add(early);
    final rest = client.takeRest();
    if (rest.isNotEmpty) target.add(rest);
    client.pipeTo(target);
    target.listen(
      client.socket.add,
      onDone: () => client.socket.close(),
      onError: (Object _) => client.socket.destroy(),
    );
  }

  // ---- SOCKS5 -------------------------------------------------------------

  Future<void> _socks(_Conn c) async {
    final head = await c.exactly(2);
    final methods = await c.exactly(head[1]);
    final wantAuth = _opts.username != null;
    String? user;
    if (wantAuth) {
      if (!methods.contains(2)) {
        c.socket.add([5, 0xff]);
        await c.socket.flush();
        c.socket.destroy();
        return;
      }
      c.socket.add([5, 2]);
      final ver = (await c.exactly(1))[0];
      final ulen = (await c.exactly(1))[0];
      user = utf8.decode(await c.exactly(ulen));
      final plen = (await c.exactly(1))[0];
      final pass = utf8.decode(await c.exactly(plen));
      final ok = ver == 1 && user == _opts.username && pass == _opts.password;
      c.socket.add([1, ok ? 0 : 1]);
      if (!ok) {
        authFailures++;
        await c.socket.flush();
        c.socket.destroy();
        return;
      }
    } else {
      c.socket.add([5, 0]);
    }
    final req = await c.exactly(4);
    late String host;
    switch (req[3]) {
      case 1:
        host = (await c.exactly(4)).join('.');
      case 3:
        final n = (await c.exactly(1))[0];
        host = utf8.decode(await c.exactly(n));
      case 4:
        host = InternetAddress.fromRawAddress(
          Uint8List.fromList(await c.exactly(16)),
        ).address;
    }
    final portBytes = await c.exactly(2);
    final port = (portBytes[0] << 8) | portBytes[1];
    requests.add(
      ProxyRequest(host: host, port: port, atyp: req[3], username: user),
    );
    if (_opts.silent) return;
    if (_opts.socksReply != 0) {
      c.socket.add([5, _opts.socksReply, 0, 1, 0, 0, 0, 0, 0, 0]);
      await c.socket.flush();
      c.socket.destroy();
      return;
    }
    final target = await _dial(host, port);
    if (target == null) {
      c.socket.add([5, 5, 0, 1, 0, 0, 0, 0, 0, 0]);
      await c.socket.flush();
      c.socket.destroy();
      return;
    }
    final reply = <int>[5, 0, 0, 1, 127, 0, 0, 1, 0, 0];
    if (_opts.splitReply) {
      for (final b in reply) {
        c.socket.add([b]);
        await c.socket.flush();
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      await _pipe(c, target, _opts.earlyData);
    } else {
      await _pipe(c, target, [...reply, ..._opts.earlyData]);
    }
  }

  // ---- HTTP CONNECT -------------------------------------------------------

  Future<void> _http(_Conn c) async {
    final header = await c.header();
    final lines = header.split('\r\n');
    final parts = lines.first.split(' ');
    final authority = parts.length > 1 ? parts[1] : '';
    String? auth;
    for (final line in lines.skip(1)) {
      if (line.toLowerCase().startsWith('proxy-authorization:')) {
        auth = line.substring(line.indexOf(':') + 1).trim();
      }
    }
    final sep = authority.lastIndexOf(':');
    var host = authority.substring(0, sep);
    if (host.startsWith('[')) host = host.substring(1, host.length - 1);
    final port = int.parse(authority.substring(sep + 1));
    String? user;
    var ok = true;
    if (_opts.username != null) {
      ok = false;
      if (auth != null && auth.startsWith('Basic ')) {
        final decoded = utf8.decode(base64.decode(auth.substring(6)));
        final i = decoded.indexOf(':');
        user = decoded.substring(0, i);
        ok =
            user == _opts.username &&
            decoded.substring(i + 1) == _opts.password;
      }
    }
    requests.add(
      ProxyRequest(
        host: host,
        port: port,
        authority: authority,
        username: user,
        rawHeader: header,
      ),
    );
    if (_opts.silent) return;
    Future<void> reply(String text) async {
      final bytes = ascii.encode(text);
      if (_opts.splitReply) {
        for (final b in bytes) {
          c.socket.add([b]);
          await c.socket.flush();
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      } else {
        c.socket.add(bytes);
      }
    }

    if (!ok) {
      authFailures++;
      await reply(
        'HTTP/1.1 407 Proxy Authentication Required\r\n'
        'Proxy-Authenticate: Basic realm="test"\r\n'
        'Content-Length: 0\r\n\r\n',
      );
      await c.socket.flush();
      c.socket.destroy();
      return;
    }
    if (_opts.httpStatus != 200) {
      await reply(
        'HTTP/1.1 ${_opts.httpStatus} Synthetic\r\nContent-Length: 0\r\n\r\n',
      );
      await c.socket.flush();
      c.socket.destroy();
      return;
    }
    if (_opts.oversizedHeader) {
      c.socket.add(
        ascii.encode('HTTP/1.1 200 OK\r\nX-Pad: ${'a' * 20000}\r\n\r\n'),
      );
      await c.socket.flush();
      return;
    }
    final target = await _dial(host, port);
    if (target == null) {
      await reply('HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n\r\n');
      await c.socket.flush();
      c.socket.destroy();
      return;
    }
    if (_opts.splitReply) {
      await reply('HTTP/1.1 200 Connection Established\r\n\r\n');
      await _pipe(c, target, _opts.earlyData);
    } else {
      await _pipe(c, target, [
        ...ascii.encode('HTTP/1.1 200 Connection Established\r\n\r\n'),
        ..._opts.earlyData,
      ]);
    }
  }
}

class FakeProxyOptions {
  const FakeProxyOptions({
    this.username,
    this.password,
    this.socksReply = 0,
    this.httpStatus = 200,
    this.splitReply = false,
    this.earlyData = const [],
    this.silent = false,
    this.oversizedHeader = false,
    this.hosts = const {},
  });

  /// Requires authentication when set.
  final String? username, password;

  /// SOCKS5 REP code to answer with instead of connecting (0 = connect).
  final int socksReply;
  final int httpStatus;

  /// Send the reply one byte per write.
  final bool splitReply;

  /// Bytes written in the same chunk as the final reply (e.g. SSH banner).
  final List<int> earlyData;

  /// Accept the request and then never answer.
  final bool silent;
  final bool oversizedHeader;

  /// Remote "DNS": name → `host:port` the proxy actually connects to.
  final Map<String, String> hosts;
}

class _Conn {
  _Conn(this.socket, this._onEof) {
    _sub = socket.listen(
      (d) {
        if (_piped != null) {
          _piped!.add(d);
          return;
        }
        _buf = [..._buf, ...d];
        _wake?.complete();
        _wake = null;
      },
      onDone: () {
        _done = true;
        _onEof();
        _wake?.complete();
        _wake = null;
        _piped?.close();
      },
      onError: (Object _) {
        _done = true;
        _onEof();
        _wake?.complete();
        _wake = null;
      },
    );
  }
  final Socket socket;
  final void Function() _onEof;
  late final StreamSubscription<Uint8List> _sub;
  List<int> _buf = [];
  Completer<void>? _wake;
  bool _done = false;
  Socket? _piped;

  Future<void> _more() async {
    if (_done) throw StateError('closed');
    _wake = Completer<void>();
    await _wake!.future;
  }

  Future<List<int>> exactly(int n) async {
    while (_buf.length < n) {
      await _more();
    }
    final out = _buf.sublist(0, n);
    _buf = _buf.sublist(n);
    return out;
  }

  Future<String> header() async {
    while (true) {
      final text = latin1.decode(_buf);
      final i = text.indexOf('\r\n\r\n');
      if (i >= 0) {
        _buf = _buf.sublist(i + 4);
        return text.substring(0, i);
      }
      await _more();
    }
  }

  List<int> takeRest() {
    final out = _buf;
    _buf = [];
    return out;
  }

  void pipeTo(Socket target) => _piped = target;
  Future<void> cancel() => _sub.cancel();
}
