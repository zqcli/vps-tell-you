import '../l10n/generated/app_localizations.dart';
import '../l10n/generated/app_localizations_en.dart';
import '../l10n/generated/app_localizations_zh.dart';
import 'server_record.dart';
import 'server_resources.dart';

/// Resolves the legacy text fields when saving a hardware draft. An address
/// only leaves `host` after it has been carried into a nonempty address field;
/// custom specification text is retained in the specification or the notes.
({String host, String spec, String notes}) preserveLegacyServerFields({
  required ServerRecord? original,
  required ServerResources resources,
  required LegacyHost? legacyHost,
  required bool hostCarried,
  required String notes,
  required AppLocalizations l10n,
}) {
  final generated = resources.specSummaryFor(l10n);
  final legacy = original?.spec.trim() ?? '';
  final custom = legacy.isNotEmpty && !_isAutoSpec(original!, legacy);
  if (generated.isNotEmpty && custom && !notes.contains(legacy)) {
    notes = notes.isEmpty
        ? '${l10n.serverSpecifications}: $legacy'
        : '$notes\n${l10n.serverSpecifications}: $legacy';
  }
  final host =
      legacyHost != null &&
          hostCarried &&
          legacyHost.fieldValue(resources).isNotEmpty
      ? ''
      : original?.host ?? '';
  return (
    host: host,
    spec: generated.isNotEmpty ? generated : legacy,
    notes: notes,
  );
}

/// Recognizes current short and older long summaries in either language.
bool _isAutoSpec(ServerRecord record, String spec) {
  final resources = record.resources;
  if (resources == null) return false;
  if (spec == resources.specSummary) return true;
  for (final l10n in [AppLocalizationsZh(), AppLocalizationsEn()]) {
    final long = [
      if (resources.vcpu != null) '${resources.vcpu} vCPU',
      if (resources.ramBytes != null)
        '${ServerResources.formatBytes(resources.ramBytes!)} RAM',
      if (resources.diskBytes != null)
        l10n.resourceDiskQuota(
          ServerResources.formatBytes(resources.diskBytes!),
        ),
      if (resources.trafficUnlimited)
        l10n.resourceUnlimitedTraffic
      else if (resources.trafficBytes != null)
        l10n.resourceTrafficQuota(
          ServerResources.formatBytes(resources.trafficBytes!),
        ),
    ].join(' · ');
    if (spec == long) return true;
  }
  return false;
}
