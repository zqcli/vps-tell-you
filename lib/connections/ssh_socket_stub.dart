import '../l10n/localized_message.dart';

import 'package:dartssh2/dartssh2.dart';

import '../security/proxy_models.dart';

const supportsNativeSsh = false;

class SshSocketConnection {
  SshSocketConnection(
    String host,
    int port, {
    ProxyEndpoint? proxy,
    Object? proxyTls,
  });
  Future<SSHSocket> get socket => Future.error(
    LocalizedUnsupportedError((l10n) => l10n.connectionBrowserTcpUnsupported),
  );
  void cancel() {}
}
