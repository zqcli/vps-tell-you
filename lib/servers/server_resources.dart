import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../l10n/generated/app_localizations.dart';

import 'dart:convert';
import 'dart:io';

/// Local resource configuration, including explicitly unknown values. Provider
/// observations remain in cloud inventory; refreshes must never overwrite these
/// user-reviewed values.
class ServerResources {
  ServerResources({
    this.ip = '',
    this.hostname = '',
    this.vcpu,
    this.ramBytes,
    this.diskBytes,
    this.trafficBytes,
    this.trafficUnlimited = false,
    this.trafficPeriodMonths,
    Set<String> apiFields = const {},
  }) : apiFields = Set.unmodifiable(apiFields);

  final String ip, hostname;
  final int? vcpu, ramBytes, diskBytes;
  final int? trafficBytes;
  final bool trafficUnlimited;

  /// Quota period is independent from its capacity. Null means not confirmed.
  final int? trafficPeriodMonths;
  static Map<int, String> get trafficPeriods =>
      trafficPeriodsFor(defaultLocalizations);
  static Map<int, String> trafficPeriodsFor(AppLocalizations l10n) => {
    1: l10n.resourceMonth,
    3: l10n.resourceQuarter,
    12: l10n.resourceYear,
  };

  /// The six allowed keys mark reviewed values originally supplied by the API.
  /// A manually completed or overridden value must not retain its API marker.
  final Set<String> apiFields;

  static const maxVcpu = 65536;
  // JSON stays exact even when a backup is handled by a JavaScript consumer.
  static const maxBytes = 9007199254740991;
  static const fieldKeys = {
    'ip',
    'hostname',
    'vcpu',
    'ramBytes',
    'diskBytes',
    'trafficBytes',
  };
  static const _legacyJsonKeys = {
    ...fieldKeys,
    'trafficUnlimited',
    'apiFields',
  };
  static const _jsonKeys = {..._legacyJsonKeys, 'trafficPeriodMonths'};

  static bool validIp(String value) {
    if (value.isEmpty || value != value.trim() || value.contains('%')) {
      return false;
    }
    final address = InternetAddress.tryParse(value);
    if (address == null || address.rawAddress.every((byte) => byte == 0)) {
      return false;
    }
    // An IPv4-mapped unspecified address is still an unspecified destination.
    final bytes = address.rawAddress;
    if (bytes.length == 16 &&
        bytes.take(10).every((byte) => byte == 0) &&
        bytes[10] == 255 &&
        bytes[11] == 255 &&
        bytes.skip(12).every((byte) => byte == 0)) {
      return false;
    }
    return true;
  }

  static bool validHostname(String value) {
    final name = value.endsWith('.')
        ? value.substring(0, value.length - 1)
        : value;
    return name.isNotEmpty &&
        name != '0' &&
        value.length <= 253 &&
        InternetAddress.tryParse(name) == null &&
        RegExp(
          r'^(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.?$',
        ).hasMatch(value);
  }

  /// Local editing permits unknown values; import must require all six fields.
  String? validate({bool requireComplete = false, AppLocalizations? l10n}) {
    l10n ??= defaultLocalizations;
    if ((requireComplete || ip.isNotEmpty) && !validIp(ip)) {
      return l10n.resourceValidIp;
    }
    if ((requireComplete || hostname.isNotEmpty) && !validHostname(hostname)) {
      return l10n.resourceValidHostname;
    }
    if (vcpu == null ? requireComplete : vcpu! < 1 || vcpu! > maxVcpu) {
      return l10n.resourceValidVcpu;
    }
    bool invalidBytes(int? value) =>
        value == null ? requireComplete : value < 1 || value > maxBytes;
    if (invalidBytes(ramBytes)) {
      return l10n.resourceValidRam;
    }
    if (invalidBytes(diskBytes)) {
      return l10n.resourceValidDisk;
    }
    if (trafficUnlimited ? trafficBytes != null : invalidBytes(trafficBytes)) {
      return l10n.resourceValidTraffic;
    }
    if (trafficPeriodMonths != null &&
        !trafficPeriods.containsKey(trafficPeriodMonths)) {
      return l10n.resourceValidPeriod;
    }
    if (!fieldKeys.containsAll(apiFields)) {
      return l10n.resourceInvalidSources;
    }
    final values = {
      'ip': ip.isEmpty ? null : ip,
      'hostname': hostname.isEmpty ? null : hostname,
      'vcpu': vcpu,
      'ramBytes': ramBytes,
      'diskBytes': diskBytes,
      'trafficBytes': trafficUnlimited ? true : trafficBytes,
    };
    if (apiFields.any((key) => values[key] == null)) {
      return l10n.resourceUnknownApiSource;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'ip': ip,
    'hostname': hostname,
    'vcpu': vcpu,
    'ramBytes': ramBytes,
    'diskBytes': diskBytes,
    'trafficBytes': trafficBytes,
    'trafficUnlimited': trafficUnlimited,
    'trafficPeriodMonths': trafficPeriodMonths,
    'apiFields': apiFields.toList()..sort(),
  };

  String encode() => jsonEncode(toJson());

  factory ServerResources.decode(String source) {
    if (source.length > 4096) {
      throw LocalizedFormatException((l10n) => l10n.resourceTooLarge);
    }
    return ServerResources.fromJson(jsonDecode(source));
  }

  factory ServerResources.fromJson(Object? value) {
    if (value is! Map) {
      throw LocalizedFormatException((l10n) => l10n.resourceInvalidFields);
    }
    final legacy = !value.containsKey('trafficPeriodMonths');
    final keys = legacy ? _legacyJsonKeys : _jsonKeys;
    if (value.length != keys.length ||
        !keys.every(value.containsKey) ||
        value['ip'] is! String ||
        value['hostname'] is! String ||
        (value['vcpu'] != null && value['vcpu'] is! int) ||
        (value['ramBytes'] != null && value['ramBytes'] is! int) ||
        (value['diskBytes'] != null && value['diskBytes'] is! int) ||
        (value['trafficBytes'] != null && value['trafficBytes'] is! int) ||
        (value['trafficPeriodMonths'] != null &&
            value['trafficPeriodMonths'] is! int) ||
        value['trafficUnlimited'] is! bool ||
        value['apiFields'] is! List) {
      throw LocalizedFormatException((l10n) => l10n.resourceInvalidFields);
    }
    final sources = value['apiFields'] as List;
    if (sources.any((field) => field is! String) ||
        sources.toSet().length != sources.length) {
      throw LocalizedFormatException(
        (l10n) => l10n.resourceInvalidSourceFields,
      );
    }
    final result = ServerResources(
      ip: value['ip'] as String,
      hostname: value['hostname'] as String,
      vcpu: value['vcpu'] as int?,
      ramBytes: value['ramBytes'] as int?,
      diskBytes: value['diskBytes'] as int?,
      trafficBytes: value['trafficBytes'] as int?,
      trafficUnlimited: value['trafficUnlimited'] as bool,
      trafficPeriodMonths: value['trafficPeriodMonths'] as int?,
      apiFields: sources.cast<String>().toSet(),
    );
    final error = result.validate(requireComplete: legacy);
    if (error != null) {
      throw LocalizedFormatException(
        (l10n) => result.validate(requireComplete: legacy, l10n: l10n)!,
      );
    }
    return result;
  }

  bool get isEmpty =>
      ip.isEmpty &&
      hostname.isEmpty &&
      vcpu == null &&
      ramBytes == null &&
      diskBytes == null &&
      trafficBytes == null &&
      !trafficUnlimited;

  String get trafficPeriodLabel => trafficPeriodLabelFor(defaultLocalizations);
  String trafficPeriodLabelFor(AppLocalizations l10n) =>
      trafficPeriodsFor(l10n)[trafficPeriodMonths] ?? l10n.notSet;

  String get trafficSummary => trafficSummaryFor(defaultLocalizations);
  String trafficSummaryFor(AppLocalizations l10n) {
    final quota = trafficUnlimited
        ? l10n.resourceUnlimitedTraffic
        : trafficBytes == null
        ? l10n.resourceUnknownTraffic
        : l10n.resourceTrafficQuota((formatBytes(trafficBytes!)).toString());
    return '$quota · ${trafficPeriodMonths == null ? l10n.resourcePeriodNotSet : l10n.resourceEveryPeriod(trafficPeriodLabelFor(l10n).toLowerCase())}';
  }

  String get specSummary => specSummaryFor(defaultLocalizations);
  String specSummaryFor(AppLocalizations l10n) => [
    if (vcpu != null) '$vcpu vCPU',
    if (ramBytes != null) '${formatBytes(ramBytes!)} RAM',
    if (diskBytes != null)
      l10n.resourceDiskQuota((formatBytes(diskBytes!)).toString()),
    // Keep the established automatic summary stable for existing records.
    // The separately stored period is shown in the hardware section.
    if (trafficUnlimited)
      l10n.resourceUnlimitedTraffic
    else if (trafficBytes != null)
      l10n.resourceTrafficQuota((formatBytes(trafficBytes!)).toString()),
  ].join(' · ');

  static String formatBytes(int bytes, {bool exact = false}) {
    const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'];
    var divisor = 1;
    var unit = 0;
    while (unit < units.length - 1 && bytes >= divisor * 1024) {
      divisor *= 1024;
      unit++;
    }
    if (exact && bytes % divisor != 0) {
      return '$bytes B';
    }
    final amount = bytes % divisor == 0
        ? (bytes ~/ divisor).toString()
        : (bytes / divisor)
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
    return '$amount ${units[unit]}';
  }
}
