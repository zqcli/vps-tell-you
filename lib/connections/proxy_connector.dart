import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/net_address.dart';
import '../l10n/generated/app_localizations.dart';
import '../security/proxy_models.dart';
import 'error_details.dart';

/// Why a proxied connection could not be made. The user-facing message only
/// uses these fixed categories (plus an HTTP status number); the wire-level
/// text lives in `ProxyException.technical` for the redacted error details.
enum ProxyFailure {
  /// TCP connection to the proxy itself failed.
  unreachable,

  /// TLS to an HTTPS proxy failed (untrusted/invalid certificate, handshake).
  tlsFailed,
  timeout,
  cancelled,

  /// The proxy closed the connection or sent something that is not its protocol.
  closed,
  protocol,
  authRequired,
  authRejected,
  invalidTarget,
  invalidProxy,
  socksGeneral,
  socksNotAllowed,
  socksNetworkUnreachable,
  socksHostUnreachable,
  socksRefused,
  socksTtlExpired,
  socksCommandUnsupported,
  socksAddressUnsupported,

  /// HTTP CONNECT answered with another status; see [ProxyException.httpStatus].
  httpStatus,
}

class ProxyException implements Exception {
  const ProxyException(this.failure, {this.httpStatus, this.technical});
  final ProxyFailure failure;
  final int? httpStatus;

  /// What actually happened on the wire (SOCKS5 reply code, HTTP status line,
  /// the underlying socket or TLS error). Never shown as the message; it only
  /// feeds the redacted "Error Details" sheet.
  final String? technical;

  /// Stage for the error details: TLS to the proxy, or the proxy exchange.
  ErrorStage get stage => failure == ProxyFailure.tlsFailed
      ? ErrorStage.proxyTls
      : ErrorStage.proxy;

  /// Type, failure kind and the wire-level [technical] text.
  String get detail =>
      '${toString()}${technical == null ? '' : ': $technical'}';

  /// The target (not the proxy) is what refused or was not found.
  bool get targetRefused => failure == ProxyFailure.socksRefused;

  String messageFor(AppLocalizations l10n) => switch (failure) {
    ProxyFailure.unreachable => l10n.r13ProxyUnreachable,
    ProxyFailure.tlsFailed => l10n.r13ProxyTlsFailed,
    ProxyFailure.timeout => l10n.r13ProxyTimeout,
    ProxyFailure.cancelled => l10n.sshConnectionCancelled,
    ProxyFailure.closed => l10n.r13ProxyClosed,
    ProxyFailure.protocol => l10n.r13ProxyProtocol,
    ProxyFailure.authRequired => l10n.r13ProxyAuthRequired,
    ProxyFailure.authRejected => l10n.r13ProxyAuthRejected,
    ProxyFailure.invalidTarget => l10n.r13ProxyInvalidTarget,
    ProxyFailure.invalidProxy => l10n.r13ProxyInvalidSettings,
    ProxyFailure.socksGeneral => l10n.r13ProxySocksGeneral,
    ProxyFailure.socksNotAllowed => l10n.r13ProxySocksNotAllowed,
    ProxyFailure.socksNetworkUnreachable => l10n.r13ProxySocksNetwork,
    ProxyFailure.socksHostUnreachable => l10n.r13ProxySocksHost,
    ProxyFailure.socksRefused => l10n.r13ProxySocksRefused,
    ProxyFailure.socksTtlExpired => l10n.r13ProxySocksTtl,
    ProxyFailure.socksCommandUnsupported => l10n.r13ProxySocksCommand,
    ProxyFailure.socksAddressUnsupported => l10n.r13ProxySocksAddress,
    ProxyFailure.httpStatus => l10n.r13ProxyHttpStatus(httpStatus ?? 0),
  };

  @override
  String toString() =>
      'ProxyException(${failure.name}'
      '${httpStatus == null ? '' : ' $httpStatus'})';
}

/// An established tunnel. [incoming] carries the target's bytes, starting with
/// anything the proxy sent behind its final reply; writes go to [socket].
class ProxyTunnel {
  ProxyTunnel(this.socket, this.incoming);
  final Socket socket;
  final Stream<Uint8List> incoming;

  /// The proxy's address: this is what the TCP stack reached, not the target.
  InternetAddress get proxyAddress => socket.remoteAddress;
  void destroy() => socket.destroy();
}

/// Caps the HTTP response header (status line included).
const proxyMaxHeaderBytes = 16 * 1024;

/// Dials a proxy and opens a TCP tunnel to [host]:[port] through it.
///
/// Like `SshSocketConnection`, one object owns the connect task and any
/// late-arriving socket: [cancel] stops the attempt at whatever stage it is
/// in, and nothing that arrives afterwards is left open. [timeout] bounds the
/// whole dial (connect, TLS and protocol); callers with their own phase timer
/// may leave it null.
///
/// SOCKS5 resolves names at the proxy (the domain is sent, never resolved
/// here); HTTP/HTTPS send `host:port` in CONNECT, IPv6 literals bracketed.
/// HTTPS validates the proxy certificate normally; [tlsContext] only replaces
/// the trust roots (tests).
class ProxyDial {
  ProxyDial({
    required this.proxy,
    required this.host,
    required this.port,
    this.tlsContext,
    this.timeout,
  }) {
    _abortSignal.future.ignore();
    tunnel = _run();
    // The owner decides how to report; never an unhandled async error.
    tunnel.ignore();
  }
  final ProxyEndpoint proxy;
  final String host;
  final int port;
  final SecurityContext? tlsContext;
  final Duration? timeout;
  late final Future<ProxyTunnel> tunnel;

  ConnectionTask<Socket>? _task;
  Socket? _raw, _transport;
  _Reader? _reader;
  Timer? _timer;
  ProxyException? _abortError;
  final _abortSignal = Completer<Never>();
  var _phase = _Phase.connect;

  void cancel() => _abort(const ProxyException(ProxyFailure.cancelled));

  void _abort(ProxyException error) {
    _abortError ??= error;
    if (!_abortSignal.isCompleted) _abortSignal.completeError(error);
    _timer?.cancel();
    _task?.cancel();
    _reader?.fail(error);
    _transport?.destroy();
    _raw?.destroy();
  }

  void _check() {
    final error = _abortError;
    if (error != null) throw error;
  }

  Future<ProxyTunnel> _run() async {
    final limit = timeout;
    if (limit != null) {
      _timer = Timer(
        limit,
        () => _abort(
          ProxyException(
            ProxyFailure.timeout,
            technical:
                'TimeoutException after $limit: no completion while ${_phase.name}',
          ),
        ),
      );
    }
    try {
      final target = _validatedTarget();
      if (proxy.hasCredentials &&
          (proxy.password == null ||
              !validProxyCredential(proxy.password!, allowColon: true) ||
              !validProxyCredential(
                proxy.username!,
                allowColon: proxy.kind == ProxyKind.socks5,
              ))) {
        throw const ProxyException(ProxyFailure.invalidProxy);
      }
      final task = await Socket.startConnect(proxy.host, proxy.port);
      _task = task;
      if (_abortError != null) task.cancel();
      final raw = await task.socket;
      _raw = raw;
      // Write failures on a reset socket surface here; the handshake already
      // reports them as a failed read, so they must not escape unhandled.
      raw.done.ignore();
      _check();
      var transport = raw;
      if (proxy.kind == ProxyKind.https) {
        _phase = _Phase.tls;
        // A destroyed raw socket may never complete the handshake future, so
        // the abort signal races it; a socket it yields late is destroyed.
        final handshake = SecureSocket.secure(
          raw,
          host: proxy.host,
          context: tlsContext,
        );
        unawaited(
          handshake.then((socket) {
            if (_abortError != null) socket.destroy();
          }, onError: (Object _) {}),
        );
        transport = await Future.any([handshake, _abortSignal.future]);
        _transport = transport;
        transport.done.ignore();
        _check();
      }
      _phase = _Phase.protocol;
      final reader = _Reader(transport);
      _reader = reader;
      if (_abortError != null) reader.fail(_abortError!);
      switch (proxy.kind) {
        case ProxyKind.socks5:
          await _socks5(transport, reader, target);
        case ProxyKind.http || ProxyKind.https:
          await _httpConnect(transport, reader, target);
      }
      _check();
      _timer?.cancel();
      return ProxyTunnel(transport, reader.detach());
    } catch (error) {
      _timer?.cancel();
      final failure = _abortError ?? _classify(error);
      // Make sure nothing outlives a failed attempt.
      _task?.cancel();
      _reader?.dispose();
      _transport?.destroy();
      _raw?.destroy();
      throw failure;
    }
  }

  ProxyException _classify(Object error) {
    if (error is ProxyException) return error;
    final raw = describeError(error);
    if (error is HandshakeException || error is TlsException) {
      return ProxyException(ProxyFailure.tlsFailed, technical: raw);
    }
    return switch (_phase) {
      _Phase.connect => ProxyException(
        ProxyFailure.unreachable,
        technical: raw,
      ),
      _Phase.tls => ProxyException(ProxyFailure.tlsFailed, technical: raw),
      _Phase.protocol => ProxyException(ProxyFailure.closed, technical: raw),
    };
  }

  /// Host as the proxy must see it: no brackets, no zone (a zone id means
  /// nothing on another machine).
  NetAddress _validatedTarget() {
    final address = NetAddress.tryParse(host, allowBrackets: false);
    if (address == null ||
        address.zone != null ||
        port < 1 ||
        port > 65535 ||
        (address.kind == NetHostKind.domain &&
            utf8.encode(host).length > 255)) {
      throw const ProxyException(ProxyFailure.invalidTarget);
    }
    return address;
  }

  // ---- SOCKS5 (RFC 1928, RFC 1929) ---------------------------------------

  Future<void> _socks5(Socket out, _Reader reader, NetAddress target) async {
    final withAuth = proxy.hasCredentials;
    out.add([5, withAuth ? 2 : 1, 0, if (withAuth) 2]);
    final choice = await reader.exactly(2);
    if (choice[0] != 5) {
      throw ProxyException(
        ProxyFailure.protocol,
        technical: 'SOCKS5 method reply began with version ${choice[0]}',
      );
    }
    switch (choice[1]) {
      case 0:
        break;
      case 2 when withAuth:
        final user = utf8.encode(proxy.username!);
        final pass = utf8.encode(proxy.password!);
        out.add([1, user.length, ...user, pass.length, ...pass]);
        final status = await reader.exactly(2);
        if (status[0] != 1) {
          throw ProxyException(
            ProxyFailure.protocol,
            technical: 'SOCKS5 auth reply began with version ${status[0]}',
          );
        }
        if (status[1] != 0) {
          throw ProxyException(
            ProxyFailure.authRejected,
            technical:
                'SOCKS5 username/password rejected (status 0x${_hex(status[1])})',
          );
        }
      case 0xff:
        throw ProxyException(
          withAuth ? ProxyFailure.authRejected : ProxyFailure.authRequired,
          technical: 'SOCKS5 no acceptable authentication method (0xff)',
        );
      default:
        throw ProxyException(
          ProxyFailure.protocol,
          technical: 'SOCKS5 selected unsupported method 0x${_hex(choice[1])}',
        );
    }
    final Uint8List address;
    final int type;
    switch (target.kind) {
      case NetHostKind.ipv4:
        type = 1;
        address = Uint8List.fromList(
          InternetAddress(target.address).rawAddress,
        );
      case NetHostKind.ipv6:
        type = 4;
        address = Uint8List.fromList(
          InternetAddress(target.address).rawAddress,
        );
      case NetHostKind.domain:
        type = 3;
        final name = utf8.encode(target.address);
        address = Uint8List.fromList([name.length, ...name]);
    }
    out.add([5, 1, 0, type, ...address, port >> 8, port & 0xff]);
    final head = await reader.exactly(4);
    if (head[0] != 5) {
      throw ProxyException(
        ProxyFailure.protocol,
        technical: 'SOCKS5 reply began with version ${head[0]}',
      );
    }
    if (head[1] != 0) {
      throw ProxyException(
        _socksReply(head[1]),
        technical:
            'SOCKS5 reply 0x${_hex(head[1])}: ${_socksReplyText(head[1])}',
      );
    }
    final int rest;
    switch (head[3]) {
      case 1:
        rest = 4;
      case 4:
        rest = 16;
      case 3:
        rest = (await reader.exactly(1))[0];
      default:
        throw ProxyException(
          ProxyFailure.protocol,
          technical: 'SOCKS5 unknown address type ${head[3]} in reply',
        );
    }
    await reader.exactly(rest + 2); // bound address and port: unused
  }

  static String _hex(int value) => value.toRadixString(16).padLeft(2, '0');

  static String _socksReplyText(int code) => switch (code) {
    1 => 'general SOCKS server failure',
    2 => 'connection not allowed by ruleset',
    3 => 'network unreachable',
    4 => 'host unreachable',
    5 => 'connection refused',
    6 => 'TTL expired',
    7 => 'command not supported',
    8 => 'address type not supported',
    _ => 'unassigned reply code',
  };

  static ProxyFailure _socksReply(int code) => switch (code) {
    2 => ProxyFailure.socksNotAllowed,
    3 => ProxyFailure.socksNetworkUnreachable,
    4 => ProxyFailure.socksHostUnreachable,
    5 => ProxyFailure.socksRefused,
    6 => ProxyFailure.socksTtlExpired,
    7 => ProxyFailure.socksCommandUnsupported,
    8 => ProxyFailure.socksAddressUnsupported,
    _ => ProxyFailure.socksGeneral,
  };

  // ---- HTTP CONNECT ------------------------------------------------------

  Future<void> _httpConnect(
    Socket out,
    _Reader reader,
    NetAddress target,
  ) async {
    final authority = target.withPort(port);
    final lines = <String>[
      'CONNECT $authority HTTP/1.1',
      'Host: $authority',
      if (proxy.hasCredentials)
        'Proxy-Authorization: Basic '
            '${base64.encode(utf8.encode('${proxy.username}:${proxy.password}'))}',
      '',
      '',
    ];
    out.add(ascii.encode(lines.join('\r\n')));
    final header = await reader.header(proxyMaxHeaderBytes);
    final statusLine = ascii.decode(
      header.sublist(0, header.indexOf(13)),
      allowInvalid: true,
    );
    final match = RegExp(r'^HTTP/1\.[01] ([0-9]{3})(?: |$)')
        .firstMatch(statusLine);
    // The status line is the proxy's own text; only printable ASCII is kept.
    final shown = statusLine.replaceAll(RegExp(r'[^\x20-\x7e]'), '?');
    if (match == null) {
      throw ProxyException(
        ProxyFailure.protocol,
        technical: 'Not an HTTP status line: $shown',
      );
    }
    final status = int.parse(match.group(1)!);
    if (status >= 200 && status < 300) return;
    if (status == 407) {
      throw ProxyException(
        proxy.hasCredentials
            ? ProxyFailure.authRejected
            : ProxyFailure.authRequired,
        httpStatus: status,
        technical: shown,
      );
    }
    throw ProxyException(
      ProxyFailure.httpStatus,
      httpStatus: status,
      technical: shown,
    );
  }
}

enum _Phase { connect, tls, protocol }

/// Buffers the proxy's bytes for the handshake, then hands the same
/// subscription (and any bytes already read past the reply) to the tunnel.
class _Reader {
  _Reader(Stream<Uint8List> source) {
    _subscription = source.listen(
      _data,
      onError: (Object error, StackTrace stack) => _error(error),
      onDone: _done,
    );
  }
  late final StreamSubscription<Uint8List> _subscription;
  var _buffer = Uint8List(0);
  StreamController<Uint8List>? _tunnel;
  Object? _failure;
  var _ended = false;
  Completer<void>? _wake;

  void _data(Uint8List chunk) {
    final tunnel = _tunnel;
    if (tunnel != null) {
      tunnel.add(chunk);
      return;
    }
    _buffer = Uint8List(_buffer.length + chunk.length)
      ..setRange(0, _buffer.length, _buffer)
      ..setRange(_buffer.length, _buffer.length + chunk.length, chunk);
    _notify();
  }

  void _error(Object error) {
    final tunnel = _tunnel;
    if (tunnel != null) {
      tunnel.addError(error);
    } else {
      _failure ??= error;
      _notify();
    }
  }

  void _done() {
    _ended = true;
    final tunnel = _tunnel;
    if (tunnel != null) {
      unawaited(tunnel.close());
    } else {
      _notify();
    }
  }

  void _notify() {
    final wake = _wake;
    _wake = null;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  void fail(Object error) {
    _failure ??= error;
    _notify();
  }

  Future<void> _more() async {
    if (_failure != null) throw _failure!;
    if (_ended) {
      throw const ProxyException(
        ProxyFailure.closed,
        technical: 'The proxy closed the connection before replying',
      );
    }
    final wake = _wake = Completer<void>();
    await wake.future;
    if (_failure != null) throw _failure!;
  }

  Future<Uint8List> exactly(int length) async {
    while (_buffer.length < length) {
      await _more();
    }
    final out = Uint8List.sublistView(_buffer, 0, length);
    _buffer = Uint8List.sublistView(_buffer, length);
    return Uint8List.fromList(out);
  }

  /// Everything up to and including the blank line ending an HTTP header.
  Future<Uint8List> header(int limit) async {
    var from = 0;
    while (true) {
      for (var i = from; i + 3 < _buffer.length; i++) {
        if (_buffer[i] == 13 &&
            _buffer[i + 1] == 10 &&
            _buffer[i + 2] == 13 &&
            _buffer[i + 3] == 10) {
          if (i + 4 > limit) {
            throw const ProxyException(
              ProxyFailure.protocol,
              technical: 'HTTP response header exceeds 16 KiB',
            );
          }
          return exactly(i + 4);
        }
      }
      if (_buffer.length >= limit) {
        throw const ProxyException(
          ProxyFailure.protocol,
          technical: 'HTTP response header exceeds 16 KiB',
        );
      }
      from = _buffer.length < 3 ? 0 : _buffer.length - 3;
      await _more();
    }
  }

  /// Switches to tunnel mode. Leftover bytes come first; the subscription stays
  /// paused until the consumer listens and follows its pause/resume.
  Stream<Uint8List> detach() {
    final controller = StreamController<Uint8List>(
      onListen: () => _subscription.resume(),
      onPause: () => _subscription.pause(),
      onResume: () => _subscription.resume(),
      onCancel: () => _subscription.cancel(),
    );
    _subscription.pause();
    _tunnel = controller;
    if (_buffer.isNotEmpty) controller.add(_buffer);
    _buffer = Uint8List(0);
    final failure = _failure;
    if (failure != null) {
      controller.addError(failure);
    }
    if (_ended) unawaited(controller.close());
    return controller.stream;
  }

  void dispose() {
    unawaited(_subscription.cancel());
  }
}
