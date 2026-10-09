import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';

enum CloudProvider {
  solusVm1,
  solusVm2,
  rackNerd;

  /// Anonymous client credentials identify one VPS, not a remote account.
  bool get isSingleInstance => switch (this) {
    CloudProvider.solusVm1 || CloudProvider.rackNerd => true,
    CloudProvider.solusVm2 => false,
  };
}

/// Compatibility name for the protocol implementation, never a business
/// provider. Existing persisted protocol values remain unchanged.
typedef AdapterType = CloudProvider;

enum AdapterAuthScope { unknown, singleDevice, account }

AdapterAuthScope adapterScope(CloudProvider type) => switch (type) {
  CloudProvider.solusVm1 ||
  CloudProvider.rackNerd => AdapterAuthScope.singleDevice,
  CloudProvider.solusVm2 => AdapterAuthScope.account,
};

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
class CloudFailure implements Exception, LocalizedMessage {
  const CloudFailure(this.kind);
  final CloudFailureKind kind;
  String get message => messageFor(defaultLocalizations);
  @override
  String messageFor(AppLocalizations l10n) => switch (kind) {
    CloudFailureKind.invalidEndpoint => l10n.cloudFailureInvalidEndpoint,
    CloudFailureKind.invalidCredentials => l10n.cloudFailureInvalidCredentials,
    CloudFailureKind.unauthorized => l10n.cloudFailureUnauthorized,
    CloudFailureKind.apiRejected => l10n.cloudFailureApiRejected,
    CloudFailureKind.forbidden => l10n.cloudFailureForbidden,
    CloudFailureKind.rateLimited => l10n.cloudFailureRateLimited,
    CloudFailureKind.unavailable => l10n.cloudFailureUnavailable,
    CloudFailureKind.connection => l10n.cloudFailureConnection,
    CloudFailureKind.timeout => l10n.cloudFailureTimeout,
    CloudFailureKind.cancelled => l10n.cloudFailureCancelled,
    CloudFailureKind.redirect => l10n.cloudFailureRedirect,
    CloudFailureKind.invalidResponse => l10n.cloudFailureInvalidResponse,
    CloudFailureKind.responseTooLarge => l10n.cloudFailureResponseTooLarge,
    CloudFailureKind.inventoryTooLarge => l10n.cloudFailureInventoryTooLarge,
    CloudFailureKind.unsupportedPlatform =>
      l10n.cloudFailureUnsupportedPlatform,
  };
  @override
  String toString() => message;
}

/// An origin, never an arbitrary API URL. Provider-specific, exact known paths
/// expose normalization so the form can show the address before using secrets.
class CloudEndpoint {
  const CloudEndpoint._(
    this.origin,
    this.normalizedConsolePath,
    this.normalizedApiPath,
  );
  factory CloudEndpoint.parse(
    String value, {
    bool allowSolusVm1ConsolePath = false,
    bool allowRackNerdApiPath = false,
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
          !(allowSolusVm1ConsolePath && rawPath == '/home.php') &&
          !(allowRackNerdApiPath && rawPath == '/api/client/command.php')) {
        throw const CloudFailure(CloudFailureKind.invalidEndpoint);
      }
      final uri = Uri.parse(text);
      final console = allowSolusVm1ConsolePath && uri.path == '/home.php';
      final api = allowRackNerdApiPath && uri.path == '/api/client/command.php';
      if (uri.scheme != 'https' ||
          !uri.hasAuthority ||
          uri.host.isEmpty ||
          uri.authority.contains('@') ||
          uri.hasQuery ||
          uri.hasFragment ||
          (uri.path.isNotEmpty && uri.path != '/' && !console && !api) ||
          uri.port < 1 ||
          uri.port > 65535 ||
          uri.host.contains('%')) {
        throw const CloudFailure(CloudFailureKind.invalidEndpoint);
      }
      return CloudEndpoint._(
        Uri(scheme: 'https', host: uri.host.toLowerCase(), port: uri.port),
        console,
        api,
      );
    } catch (_) {
      throw const CloudFailure(CloudFailureKind.invalidEndpoint);
    }
  }
  final Uri origin;
  final bool normalizedConsolePath, normalizedApiPath;
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

class RackNerdCredentials extends CloudCredentials {
  RackNerdCredentials({required this.key, required this.hash}) {
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
  // Null for single-instance APIs: they provide no stable remote identity.
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
/// failure. Single-instance snapshots contain exactly one anonymous VPS.
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
