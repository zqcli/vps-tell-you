import '../core/net_address.dart';

/// Wire protocol spoken to the proxy server. The target is always reached with
/// a TCP tunnel (SOCKS5 CONNECT or HTTP CONNECT); `https` only means the hop to
/// the proxy itself is wrapped in TLS.
enum ProxyKind {
  socks5('SOCKS5', 1080),
  http('HTTP', 8080),
  https('HTTPS', 443);

  const ProxyKind(this.label, this.defaultPort);

  /// Protocol token, not translated.
  final String label;
  final int defaultPort;
}

/// Longest user name / password the proxy protocols can carry: RFC 1929 stores
/// each in one length byte. The same limit is used for HTTP Basic.
const proxyCredentialMaxBytes = 255;

/// Public proxy metadata. The password is never here: [secretRef] is an opaque
/// secure-storage key, present only when [username] is set.
class ProxyRecord {
  const ProxyRecord({
    required this.id,
    required this.name,
    required this.kind,
    required this.host,
    required this.port,
    required this.createdAt,
    required this.updatedAt,
    this.username,
    this.secretRef,
    this.revision = 0,
  });
  final String id, name, host;
  final ProxyKind kind;
  final int port, revision;
  final String? username, secretRef;
  final DateTime createdAt, updatedAt;

  bool get hasCredentials => username != null && username!.isNotEmpty;
  String get address => formatHostPort(host, port);

  factory ProxyRecord.fromMap(Map<String, Object?> row) => ProxyRecord(
    id: row['id'] as String,
    name: row['name'] as String,
    kind: ProxyKind.values.byName(row['kind'] as String),
    host: row['host'] as String,
    port: row['port'] as int,
    username: row['username'] as String?,
    secretRef: row['secret_ref'] as String?,
    revision: row['revision'] as int,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'host': host,
    'port': port,
    'username': username,
    'secret_ref': secretRef,
    'revision': revision,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

/// Everything the transport needs to dial one proxy. In memory only; the
/// password is read from secure storage right before connecting (or typed
/// into the temporary TCP-test form) and is never persisted from here.
class ProxyEndpoint {
  const ProxyEndpoint({
    required this.kind,
    required this.host,
    required this.port,
    this.username,
    this.password,
  });
  final ProxyKind kind;
  final String host;
  final int port;
  final String? username, password;

  bool get hasCredentials => username != null && username!.isNotEmpty;
  String get address => formatHostPort(host, port);

  /// `SOCKS5 127.0.0.1:1080`; safe to display and log.
  String get label => '${kind.label} $address';

  @override
  String toString() => 'ProxyEndpoint($label)';
}

/// Local validation shared by the form, the controller and the store.
bool validProxyCredential(String value, {required bool allowColon}) {
  if (value.isEmpty ||
      value.codeUnits.length > 4096 ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    return false;
  }
  if (!allowColon && value.contains(':')) return false;
  return _utf8Length(value) <= proxyCredentialMaxBytes;
}

int _utf8Length(String value) {
  var length = 0;
  for (final rune in value.runes) {
    length += rune < 0x80
        ? 1
        : rune < 0x800
        ? 2
        : rune < 0x10000
        ? 3
        : 4;
  }
  return length;
}
