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
    return _NativeSocket(socket);
  }

  void cancel() {
    _cancelled = true;
    _task?.cancel();
    _socket?.destroy();
  }
}

class _NativeSocket implements SSHSocket {
  _NativeSocket(this.socket);
  final Socket socket;
  @override
  Stream<Uint8List> get stream => socket;
  @override
  StreamSink<List<int>> get sink => socket;
  @override
  Future<void> get done => socket.done;
  @override
  Future<void> close() async {
    await socket.close();
  }

  @override
  void destroy() => socket.destroy();
  @override
  Future<void> flush() => socket.flush();
}
