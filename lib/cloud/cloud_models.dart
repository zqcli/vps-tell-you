enum CloudProvider { solusVm1, solusVm2 }

enum CloudPower { running, stopped, unknown }

enum CloudFailureKind {
  invalidEndpoint,
  invalidCredentials,
  unauthorized,
  apiRejected,
  forbidden,
  rateLimited,
  unavailable,
  connection,
  timeout,
  cancelled,
  redirect,
  invalidResponse,
  responseTooLarge,
  inventoryTooLarge,
  unsupportedPlatform,
}

/// Never includes request URLs, credentials, remote bodies or transport errors.
class CloudFailure implements Exception {
  const CloudFailure(this.kind);
  final CloudFailureKind kind;
  String get message => switch (kind) {
    CloudFailureKind.invalidEndpoint => '请输入 HTTPS 面板首页地址，不含登录信息、查询参数或 API 路径',
    CloudFailureKind.invalidCredentials => '请填写该模板对应的有效 API 凭据',
    CloudFailureKind.unauthorized => 'API 凭据未通过验证，请检查凭据或重新授权',
    CloudFailureKind.apiRejected => '面板拒绝 API 读取，请检查凭据、API 开放情况与服务状态',
    CloudFailureKind.forbidden => '面板拒绝读取，请检查 API 权限与服务商设置',
    CloudFailureKind.rateLimited => '面板请求过于频繁，请稍后手动重试',
    CloudFailureKind.unavailable => '面板暂时无法提供 API 读取服务',
    CloudFailureKind.connection => '连接失败，请检查网络、面板地址与 HTTPS 证书',
    CloudFailureKind.timeout => '读取超时，保留上次读取的信息；请稍后重试',
    CloudFailureKind.cancelled => '读取已取消',
    CloudFailureKind.redirect => '面板返回重定向，已停止以保护凭据；请核对面板地址',
    CloudFailureKind.invalidResponse => '面板响应不符合读取协议，未更新本地资料',
    CloudFailureKind.responseTooLarge => '面板响应超过安全大小限制',
    CloudFailureKind.inventoryTooLarge => '实例或分页数量超过本次读取限制，未导入不完整列表',
    CloudFailureKind.unsupportedPlatform => '此预览平台不接受真实 API 凭据，请使用原生应用',
  };
  @override
  String toString() => message;
}

/// An origin, never an arbitrary API URL. Known V1 console normalization is
/// exposed so the form can show the final address before using credentials.
class CloudEndpoint {
  const CloudEndpoint._(this.origin, this.normalizedConsolePath);
  factory CloudEndpoint.parse(
    String value, {
    bool allowSolusVm1ConsolePath = false,
  }) {
    try {
      final text = value.trim();
      if (text.length > 2048 || RegExp(r'[\s\\\x00-\x1f\x7f]').hasMatch(text)) {
        throw const CloudFailure(CloudFailureKind.invalidEndpoint);
      }
      final authorityStart = text.indexOf('://') + 3;
      final rawPathStart = text.indexOf('/', authorityStart);
      final rawPath = rawPathStart < 0 ? '' : text.substring(rawPathStart);
      if (rawPath.isNotEmpty &&
          rawPath != '/' &&
          !(allowSolusVm1ConsolePath && rawPath == '/home.php')) {
        throw const CloudFailure(CloudFailureKind.invalidEndpoint);
      }
      final uri = Uri.parse(text);
      final console = allowSolusVm1ConsolePath && uri.path == '/home.php';
      if (uri.scheme != 'https' ||
          !uri.hasAuthority ||
          uri.host.isEmpty ||
          uri.authority.contains('@') ||
          uri.hasQuery ||
          uri.hasFragment ||
          (uri.path.isNotEmpty && uri.path != '/' && !console) ||
          uri.port < 1 ||
          uri.port > 65535 ||
          uri.host.contains('%')) {
        throw const CloudFailure(CloudFailureKind.invalidEndpoint);
      }
      return CloudEndpoint._(
        Uri(scheme: 'https', host: uri.host.toLowerCase(), port: uri.port),
        console,
      );
    } catch (_) {
      throw const CloudFailure(CloudFailureKind.invalidEndpoint);
    }
  }
  final Uri origin;
  final bool normalizedConsolePath;
  Uri uri(String path, {int? page}) => origin.replace(
    path: path,
    queryParameters: page == null ? null : {'page': '$page'},
  );
  @override
  String toString() => origin.toString();
}

/// Credentials are intentionally separate from account metadata and DTOs.
/// No serialization, equality, debug dump or persistence is provided here.
sealed class CloudCredentials {
  const CloudCredentials();
}

class SolusVm1Credentials extends CloudCredentials {
  SolusVm1Credentials({required this.key, required this.hash}) {
    if (!_validSecret(key) || !_validSecret(hash)) {
      throw const CloudFailure(CloudFailureKind.invalidCredentials);
    }
  }
  final String key, hash;
}

class SolusVm2Credentials extends CloudCredentials {
  SolusVm2Credentials(this.token) {
    if (!_validSecret(token) || token.contains(' ')) {
      throw const CloudFailure(CloudFailureKind.invalidCredentials);
    }
  }
  final String token;
}

bool _validSecret(String value) =>
    value.isNotEmpty &&
    value.length <= 8192 &&
    value == value.trim() &&
    !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value);

/// One cancellation object per user operation, shared across all its pages.
class CloudCancellation {
  final _listeners = <void Function()>{};
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void throwIfCancelled() {
    if (_cancelled) throw const CloudFailure(CloudFailureKind.cancelled);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in List.of(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  void Function() onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
    return () => _listeners.remove(listener);
  }
}

class CloudProject {
  const CloudProject({required this.id, this.name});
  final int id;
  final String? name;
}

/// Explicit read-only projection. No prices, passwords, login links, owner
/// details, SSH config or raw API maps can be retained by this object.
class CloudInstance {
  const CloudInstance({
    required this.observedAt,
    required this.power,
    this.projectId,
    this.serverId,
    this.uuid,
    this.name,
    this.projectName,
    this.ipv4,
    this.ipv6,
    this.hostname,
    this.diskBytes,
    this.trafficBytes,
    this.trafficUsedBytes,
    this.trafficUnlimited = false,
    this.vcpu,
    this.ramBytes,
    this.diskGiB,
    this.location,
    this.osImage,
    this.suspended,
  });
  final DateTime observedAt;
  final CloudPower power;
  // Null for V1: its documented client API provides no stable remote ID.
  final int? projectId, serverId;
  final String? uuid, name, projectName, ipv4, ipv6, location, osImage;
  final String? hostname;
  final int? vcpu, ramBytes, diskBytes, trafficBytes, trafficUsedBytes;
  final bool trafficUnlimited;
  final num? diskGiB;
  final bool? suspended;
}

/// Returned only after all pages succeed. Consumers must separately fence late
/// results against account generation/unlink and preserve prior observations on
/// failure. A successful V1 snapshot always contains exactly one anonymous VPS.
class CloudSnapshot {
  CloudSnapshot({
    required this.provider,
    required this.completedAt,
    required List<CloudInstance> instances,
    List<CloudProject> projects = const [],
    this.remoteAccountId,
  }) : instances = List.unmodifiable(instances),
       projects = List.unmodifiable(projects);
  final CloudProvider provider;
  final DateTime completedAt;
  final int? remoteAccountId;
  final List<CloudInstance> instances;
  final List<CloudProject> projects;
}

/// Verification and refresh use the same bounded read-only inventory operation.
/// It deliberately offers no arbitrary request, power or write method.
abstract interface class CloudAdapter {
  Future<CloudSnapshot> read({required CloudCancellation cancellation});
}
