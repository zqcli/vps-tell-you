import '../l10n/localized_message.dart';
import '../servers/server_resources.dart';
import 'cloud_account.dart';
import 'cloud_models.dart';

/// A reviewed local import draft. It cannot alter authorization or observations.
class CloudImportDraft {
  const CloudImportDraft({
    required this.instanceKey,
    required this.resources,
    this.displayName,
  });
  final String instanceKey;
  final ServerResources resources;
  final String? displayName;
}

class CloudImportDraftFailure extends CloudAccountFailure {
  const CloudImportDraftFailure(super.message);
}

class CloudImportItemResult {
  CloudImportItemResult({
    required this.instanceKey,
    required this.imported,
    required List<String> serverIds,
  }) : serverIds = List.unmodifiable(serverIds);
  final String instanceKey;
  final bool imported;

  /// Includes every legacy duplicate instead of choosing an arbitrary owner.
  final List<String> serverIds;
}

class CloudImportBatchResult {
  CloudImportBatchResult({
    required List<CloudImportItemResult> items,
    required Map<String, LocalizedMessage> failures,
    required Set<String> unprocessed,
    this.interruption,
  }) : items = List.unmodifiable(items),
       failures = Map.unmodifiable(failures),
       unprocessed = Set.unmodifiable(unprocessed);
  final List<CloudImportItemResult> items;
  final Map<String, LocalizedMessage> failures;
  final Set<String> unprocessed;
  final LocalizedMessage? interruption;
  int get importedCount => items.where((item) => item.imported).length;
  int get existingCount => items.where((item) => !item.imported).length;
  Set<String> get retryKeys => {...failures.keys, ...unprocessed};
  bool get complete => retryKeys.isEmpty;
}

/// Only resource values actually supplied by the adapter are offered as API
/// data. Empty/zero values stay unknown; diskGiB is converted only if exact.
Map<String, Object?> observedCloudResources(CloudInstance instance) {
  int? positive(int? value) =>
      value != null && value > 0 && value <= ServerResources.maxBytes
      ? value
      : null;
  final gib = instance.diskGiB;
  // Bound before multiplying: a valid JSON integer can overflow native int64
  // when expressed in GiB, and wrapping would fabricate a small API quota.
  final scaledDisk =
      gib != null &&
          gib.isFinite &&
          gib > 0 &&
          gib <= ServerResources.maxBytes / 1073741824
      ? gib * 1073741824
      : null;
  final diskBytes =
      positive(instance.diskBytes) ??
      (scaledDisk != null &&
              scaledDisk.isFinite &&
              scaledDisk > 0 &&
              scaledDisk <= ServerResources.maxBytes &&
              scaledDisk == scaledDisk.roundToDouble()
          ? scaledDisk.toInt()
          : null);
  final ip = instance.ipv4 != null && ServerResources.validIpv4(instance.ipv4!)
      ? instance.ipv4
      : null;
  final ipv6 =
      instance.ipv6 != null && ServerResources.validIpv6(instance.ipv6!)
      ? instance.ipv6
      : null;
  final hostname =
      instance.hostname != null &&
          ServerResources.validHostname(instance.hostname!)
      ? instance.hostname
      : null;
  return {
    'ip': ip,
    'ipv6': ipv6,
    'hostname': hostname,
    'vcpu': instance.vcpu != null && instance.vcpu! <= ServerResources.maxVcpu
        ? positive(instance.vcpu)
        : null,
    'ramBytes': positive(instance.ramBytes),
    'diskBytes': diskBytes,
    'trafficBytes': instance.trafficUnlimited
        ? null
        : positive(instance.trafficBytes),
    'trafficUnlimited': instance.trafficUnlimited,
  };
}

ServerResources resourcesFromCloud(CloudInstance instance) {
  final values = observedCloudResources(instance);
  return ServerResources(
    ip: values['ip'] as String? ?? '',
    ipv6: values['ipv6'] as String? ?? '',
    hostname: values['hostname'] as String? ?? '',
    vcpu: values['vcpu'] as int?,
    ramBytes: values['ramBytes'] as int?,
    diskBytes: values['diskBytes'] as int?,
    trafficBytes: values['trafficBytes'] as int?,
    trafficUnlimited: instance.trafficUnlimited,
    apiFields: {
      for (final key in [...ServerResources.fieldKeys, 'ipv6'])
        if (values[key] != null ||
            key == 'trafficBytes' && instance.trafficUnlimited)
          key,
    },
  );
}

ServerResources verifiedResourceSources(
  ServerResources resources,
  CloudInstance instance,
) {
  final observed = observedCloudResources(instance);
  final local = resources.toJson();
  return ServerResources(
    ip: resources.ip,
    ipv6: resources.ipv6,
    hostname: resources.hostname,
    vcpu: resources.vcpu,
    ramBytes: resources.ramBytes,
    diskBytes: resources.diskBytes,
    trafficBytes: resources.trafficBytes,
    trafficUnlimited: resources.trafficUnlimited,
    trafficPeriodMonths: resources.trafficPeriodMonths,
    apiFields: {
      for (final key in resources.apiFields)
        if (key == 'trafficBytes' && resources.trafficUnlimited
            ? observed['trafficUnlimited'] == true
            : observed[key] != null && observed[key] == local[key])
          key,
    },
  );
}
