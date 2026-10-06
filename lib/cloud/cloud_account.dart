import 'dart:convert';

import 'cloud_models.dart';

/// Local connection identity. Neither the endpoint nor a remote name/IP is a
/// uniqueness key. Secret contents never belong in this metadata object.
class CloudAccount {
  const CloudAccount({
    required this.id,
    required this.provider,
    required this.alias,
    required this.endpoint,
    required this.secretRef,
    required this.createdAt,
    this.remoteAccountId,
    this.revision = 0,
    this.generation = 0,
    this.lastAttemptAt,
    this.lastFailure,
  });
  final String id, alias, endpoint, secretRef;
  final CloudProvider provider;
  final int? remoteAccountId;
  final int revision, generation;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final CloudFailureKind? lastFailure;

  Map<String, Object?> toMap() => {
    'id': id,
    'provider': provider.name,
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
  });
  final String serverId, accountId, instanceKey;
  final CloudInstance observation;
  final bool stale, missing;
  DateTime get observedAt => observation.observedAt;
  CloudPower get power => observation.power;
  factory CloudBinding.fromMap(Map<String, Object?> row) => CloudBinding(
    serverId: row['server_id'] as String,
    accountId: row['account_id'] as String,
    instanceKey: row['instance_key'] as String,
    observation: decodeCloudInstance(row['observation'] as String),
    stale: row['stale'] == 1,
    missing: row['missing'] == 1,
  );
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
class CloudAccountFailure implements Exception {
  const CloudAccountFailure(this.message);
  final String message;
  @override
  String toString() => message;
  static const identity = CloudAccountFailure('远端账户或实例身份变化，原关联未更改；请另建账户连接');
  static const v1Rebind = CloudAccountFailure(
    'SolusVM 1 无法证明新凭据仍属于原实例；请明确确认解除旧关联并重新选择导入，旧台账会保留',
  );
  static const selection = CloudAccountFailure('导入列表已变化或选择无效，请重新读取');
  static const alias = CloudAccountFailure('账户别名需为 1–80 个字符');
  static const secret = CloudAccountFailure('原生安全存储未完成，原授权保持不变；请检查设备后重试');
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
    vcpu: row['vcpu'] as int?,
    ramBytes: row['ram_bytes'] as int?,
    diskGiB: row['disk_gib'] as num?,
    location: row['location'] as String?,
    osImage: row['os_image'] as String?,
    suspended: row['suspended'] as bool?,
  );
}
