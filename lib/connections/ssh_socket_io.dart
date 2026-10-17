import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../security/proxy_models.dart';
import 'proxy_connector.dart';

const supportsNativeSsh = true;

/// Cancellation owns both DNS/connect task and any late-arriving socket.
///
/// With a [proxy] the target is reached through a SOCKS5/HTTP(S) tunnel; the
/// host and port stay those of the SSH target (host-key trust is keyed by
/// them, never by the proxy). [proxyTls] replaces the TLS trust roots for an
/// HTTPS proxy (tests only).
class SshSocketConnection {
  SshSocketConnection(
    String host,
    int port, {
    ProxyEndpoint? proxy,
    SecurityContext? proxyTls,
  }) {
    if (proxy != null) {
      final dial = _dial = ProxyDial(
        proxy: proxy,
        host: host,
        port: port,
        tlsContext: proxyTls,
      );
      socket = dial.tunnel.then(
        (tunnel) => NativeSshSocket(tunnel.socket, incoming: tunnel.incoming),
      );
      socket.ignore();
    } else {
      socket = _connect(host, port);
    }
  }
  late final Future<SSHSocket> socket;
  ProxyDial? _dial;
  ConnectionTask<Socket>? _task;
  Socket? _socket;
  bool _cancelled = false;

  Future<SSHSocket> _connect(String host, int port) async {
    final task = await Socket.startConnect(host, port);
    _task = task;
    if (_cancelled) task.cancel();
    final socket = await task.socket;
    _socket = socket;
    if (_cancelled) {
      socket.destroy();
      throw StateError('Cancelled');
    }
    return NativeSshSocket(socket);
  }

  void cancel() {
    _cancelled = true;
    _dial?.cancel();
    _task?.cancel();
    _socket?.destroy();
  }
}

/// Native transport boundary. The library observes [done] for write errors;
/// close is cleanup and must not rethrow the same terminal write failure.
class NativeSshSocket implements SSHSocket {
  NativeSshSocket(this.socket, {Stream<Uint8List>? incoming})
    : _source = incoming ?? socket;
  final Socket socket;

  /// The socket itself, or a proxy tunnel's stream (leftover bytes first).
  final Stream<Uint8List> _source;
  // dartssh2 4.1.0 awaits each buffered packet handler. Raw EOF can otherwise
  // close its transport before those queued packet microtasks finish. Give
  // ordinary buffered packets one event turn; this does not wait for another
  // read, asynchronous key exchange, or a user's host-verification decision.
  late final Stream<Uint8List> _incoming = _source.transform(
    StreamTransformer<Uint8List, Uint8List>.fromHandlers(
      handleDone: (sink) => Timer.run(sink.close),
    ),
  );
  @override
  Stream<Uint8List> get stream => _incoming;
  @override
  StreamSink<List<int>> get sink => socket;
  @override
  Future<void> get done => socket.done;
  @override
  Future<void> close() async {
    try {
      await socket.close();
    } on SocketException {
      // dartssh2 calls close unawaited on peer EOF. Socket.close can reject
      // with an earlier EPIPE even when its done error was already observed.
      // Preserve that original done error, but make terminal cleanup safe.
      socket.destroy();
    }
  }

  @override
  void destroy() => socket.destroy();
  @override
  Future<void> flush() => socket.flush();
}
