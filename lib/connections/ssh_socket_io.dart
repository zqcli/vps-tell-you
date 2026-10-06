import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

const supportsNativeSsh = true;

/// Cancellation owns both DNS/connect task and any late-arriving socket.
class SshSocketConnection {
  SshSocketConnection(String host, int port) {
    socket = _connect(host, port);
  }
  late final Future<SSHSocket> socket;
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
    _task?.cancel();
    _socket?.destroy();
  }
}

/// Native transport boundary. The library observes [done] for write errors;
/// close is cleanup and must not rethrow the same terminal write failure.
class NativeSshSocket implements SSHSocket {
  NativeSshSocket(this.socket);
  final Socket socket;
  @override
  Stream<Uint8List> get stream => socket;
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
