import 'package:dartssh2/dartssh2.dart';

const supportsNativeSsh = false;

class SshSocketConnection {
  SshSocketConnection(String host, int port);
  Future<SSHSocket> get socket =>
      Future.error(UnsupportedError('浏览器没有原生 TCP；请使用原生应用'));
  void cancel() {}
}
