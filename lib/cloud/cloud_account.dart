import 'dart:convert';

import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../servers/server_record.dart';
import 'cloud_models.dart';

/// Local connection identity. Neither the endpoint nor a remote name/IP is a
/// uniqueness key. Secret contents never belong in this metadata object.
class CloudAccount {
  const CloudAccount({
    required this.id,
    required this.provider,
    required this.businessProviderId,
    required this.authScope,
    required this.alias,
    required this.endpoint,
    required this.secretRef,
    required this.createdAt,
    this.remoteAccountId,
    this.revision = 0,
    this.generation = 0,
    this.lastAttemptAt,
    this.lastFailure,
    this.pinnedServerId,
  });
  final String id, alias, endpoint, secretRef;
  final CloudProvider provider;
  CloudProvider get adapterType => provider;
  final String businessProviderId;
  final AdapterAuthScope authScope;

  /// A V1 credential has no stable remote ID. Its first local device remains
  /// pinned for this authorization epoch, including after a local unlink.
  final String? pinnedServerId;
  final int? remoteAccountId;
  final int revision, generation;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final CloudFailureKind? lastFailure;

  Map<String, Object?> toMap() => {
    'id': id,
    'provider': provider.name,
    'business_provider_id': businessProviderId,
    'auth_scope': authScope.name,
    'pinned_server_id': pinnedServerId,
    'alias': alias,
    'endpoint': endpoint,
    'secret_ref': secretRef,
    'remote_account_id': remoteAccountId,
    'revision': revision,
    'generation': generation,
    'created_at': createdAt.toUtc().toIso8601String(),
    'last_attempt_at': lastAttemptAt?.toUtc().toIso8601String(),
    'last_failure': lastFailure?.name,
  };
  factory CloudAccount.fromMap(Map<String, Object?> row) => CloudAccount(
    id: row['id'] as String,
    provider: CloudProvider.values.byName(row['provider'] as String),
    businessProviderId: row['business_provider_id'] as String,
    authScope: AdapterAuthScope.values.byName(row['auth_scope'] as String),
    pinnedServerId: row['pinned_server_id'] as String?,
    alias: row['alias'] as String,
    endpoint: row['endpoint'] as String,
    secretRef: row['secret_ref'] as String,
    remoteAccountId: row['remote_account_id'] as int?,
    revision: row['revision'] as int,
    generation: row['generation'] as int,
    createdAt: DateTime.parse(row['created_at'] as String),
    lastAttemptAt: row['last_attempt_at'] == null
        ? null
        : DateTime.parse(row['last_attempt_at'] as String),
    lastFailure: row['last_failure'] == null
        ? null
        : CloudFailureKind.values.byName(row['last_failure'] as String),
  );
}

/// One credential instance under a business provider. Retain the old Dart and
/// SQLite names at the persistence boundary to avoid changing stored identity.
typedef AdapterInstance = CloudAccount;

/// An immutable read result plus the DB generation which authorized it. An old
/// inventory cannot be used to import after a newer read, reauthorization or
/// unlink, even if its remote IDs happen to match.
class CloudInventory {
  const CloudInventory({required this.account, required this.snapshot});
  final CloudAccount account;
  final CloudSnapshot snapshot;
  String keyFor(CloudInstance instance) => cloudInstanceKey(snapshot, instance);
}

class CloudBinding {
  const CloudBinding({
    required this.serverId,
    required this.accountId,
    required this.instanceKey,
    required this.observation,
    required this.stale,
    required this.missing,
    this.identityUuid,
  });
  final String serverId, accountId, instanceKey;
  final CloudInstance observation;

  /// Retained independently of a later API response which omits UUID.
  final String? identityUuid;
  String? get stableUuid => identityUuid ?? observation.uuid;
  final bool stale, missing;
  DateTime get observedAt => observation.observedAt;
  CloudPower get power => observation.power;
  factory CloudBinding.fromMap(Map<String, Object?> row) => CloudBinding(
    serverId: row['server_id'] as String,
    accountId: row['account_id'] as String,
    instanceKey: row['instance_key'] as String,
    identityUuid: row['identity_uuid'] as String?,
    observation: decodeCloudInstance(row['observation'] as String),
    stale: row['stale'] == 1,
    missing: row['missing'] == 1,
  );
}

/// A saved observation, including whether another local record already owns it.
/// Reading this value never reads a secret or contacts a cloud provider.
class CloudBindingChoice {
  const CloudBindingChoice({
    required this.accountId,
    required this.instanceKey,
    required this.observation,
    required this.stale,
    required this.missing,
    this.serverId,
  });
  final String accountId, instanceKey;
  final String? serverId;
  final CloudInstance observation;
  final bool stale, missing;

  factory CloudBindingChoice.fromMap(Map<String, Object?> row) =>
      CloudBindingChoice(
        accountId: row['account_id'] as String,
        instanceKey: row['instance_key'] as String,
        observation: decodeCloudInstance(row['observation'] as String),
        stale: row['stale'] == 1,
        missing: row['missing'] == 1,
        serverId: row['server_id'] as String?,
      );
}

/// One transactional local snapshot. All account generations fence binding
/// edits, including an unbound → bound → unbound ABA on a different account.
/// This avoids changing server revisions or invalidating payment undo merely
/// because the user changed a local cloud association.
class ServerCloudBindingOptions {
  ServerCloudBindingOptions({
    required this.server,
    required List<CloudAccount> accounts,
    required List<CloudBindingChoice> choices,
  }) : accounts = List.unmodifiable(accounts),
       choices = List.unmodifiable(choices);
  final ServerRecord server;
  final List<CloudAccount> accounts;
  final List<CloudBindingChoice> choices;
  CloudBindingChoice? get current =>
      choices.where((choice) => choice.serverId == server.id).firstOrNull;
}

/// V1's anonymous singleton is scoped by the local connection ID in every DB
/// key. V2 additionally includes the verified remote user and project/server IDs.
String cloudInstanceKey(CloudSnapshot snapshot, CloudInstance instance) {
  if (snapshot.provider == CloudProvider.solusVm1) {
    if (snapshot.remoteAccountId != null ||
        snapshot.instances.length != 1 ||
        instance.projectId != null ||
        instance.serverId != null ||
        instance.uuid != null) {
      throw const CloudFailure(CloudFailureKind.invalidResponse);
    }
    return 'single';
  }
  if ((snapshot.remoteAccountId ?? 0) <= 0 ||
      (instance.projectId ?? 0) <= 0 ||
      (instance.serverId ?? 0) <= 0) {
    throw const CloudFailure(CloudFailureKind.invalidResponse);
  }
  return '${snapshot.remoteAccountId}/${instance.projectId}/${instance.serverId}';
}

/// A closed, non-sensitive error vocabulary; never stringify storage/transport
/// errors because they can contain credentials, URLs or provider response data.
enum _CloudAccountFailureCode {
  identity,
  v1Rebind,
  selection,
  alias,
  secret,
  secretRead,
  bindingTaken,
  bindingUnavailable,
}

class CloudAccountFailure implements Exception, LocalizedMessage {
  /// Only app-authored safe messages belong here, never raw external errors.
  const CloudAccountFailure(this._message);
  final Object _message;
  String get message => messageFor(defaultLocalizations);
  @override
  String messageFor(AppLocalizations l10n) => switch (_message) {
    _CloudAccountFailureCode.identity => l10n.cloudAccountFailureIdentity,
    _CloudAccountFailureCode.v1Rebind => l10n.cloudAccountFailureV1Rebind,
    _CloudAccountFailureCode.selection => l10n.cloudAccountFailureSelection,
    _CloudAccountFailureCode.alias => l10n.cloudAccountFailureAlias,
    _CloudAccountFailureCode.secret => l10n.cloudAccountFailureSecret,
    _CloudAccountFailureCode.secretRead => l10n.cloudAccountFailureSecretRead,
    _CloudAccountFailureCode.bindingTaken =>
      l10n.cloudAccountFailureBindingTaken,
    _CloudAccountFailureCode.bindingUnavailable =>
      l10n.cloudAccountFailureBindingUnavailable,
    LocalizedMessage message => message.messageFor(l10n),
    String message => message,
    _ => l10n.cloudOperationFailed,
  };
  @override
  String toString() => message;
  static const identity = CloudAccountFailure(
    _CloudAccountFailureCode.identity,
  );
  static const v1Rebind = CloudAccountFailure(
    _CloudAccountFailureCode.v1Rebind,
  );
  static const selection = CloudAccountFailure(
    _CloudAccountFailureCode.selection,
  );
  static const alias = CloudAccountFailure(_CloudAccountFailureCode.alias);
  static const secret = CloudAccountFailure(_CloudAccountFailureCode.secret);
  static const secretRead = CloudAccountFailure(
    _CloudAccountFailureCode.secretRead,
  );
  static const bindingTaken = CloudAccountFailure(
    _CloudAccountFailureCode.bindingTaken,
  );
  static const bindingUnavailable = CloudAccountFailure(
    _CloudAccountFailureCode.bindingUnavailable,
  );
}

// Explicit observation whitelist. No remote response map is serialized.
String encodeCloudInstance(CloudInstance i) => jsonEncode({
  'observed_at': i.observedAt.toUtc().toIso8601String(),
  'power': i.power.name,
  'project_id': i.projectId,
  'server_id': i.serverId,
  'uuid': i.uuid,
  'name': i.name,
  'project_name': i.projectName,
  'ipv4': i.ipv4,
  'ipv6': i.ipv6,
  'hostname': i.hostname,
  'disk_bytes': i.diskBytes,
  'traffic_bytes': i.trafficBytes,
  'traffic_used_bytes': i.trafficUsedBytes,
  'traffic_unlimited': i.trafficUnlimited,
  'vcpu': i.vcpu,
  'ram_bytes': i.ramBytes,
  'disk_gib': i.diskGiB,
  'location': i.location,
  'os_image': i.osImage,
  'suspended': i.suspended,
});
CloudInstance decodeCloudInstance(String value) {
  final row = jsonDecode(value) as Map<String, dynamic>;
  return CloudInstance(
    observedAt: DateTime.parse(row['observed_at'] as String),
    power: CloudPower.values.byName(row['power'] as String),
    projectId: row['project_id'] as int?,
    serverId: row['server_id'] as int?,
    uuid: row['uuid'] as String?,
    name: row['name'] as String?,
    projectName: row['project_name'] as String?,
    ipv4: row['ipv4'] as String?,
    ipv6: row['ipv6'] as String?,
    hostname: row['hostname'] as String?,
    diskBytes: row['disk_bytes'] as int?,
    trafficBytes: row['traffic_bytes'] as int?,
    trafficUsedBytes: row['traffic_used_bytes'] as int?,
    trafficUnlimited: row['traffic_unlimited'] == true,
    vcpu: row['vcpu'] as int?,
    ramBytes: row['ram_bytes'] as int?,
    diskGiB: row['disk_gib'] as num?,
    location: row['location'] as String?,
    osImage: row['os_image'] as String?,
    suspended: row['suspended'] as bool?,
  );
}
