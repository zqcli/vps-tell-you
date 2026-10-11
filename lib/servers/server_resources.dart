import '../core/net_address.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../l10n/generated/app_localizations.dart';

import 'dart:convert';

/// Local resource configuration, including explicitly unknown values. Provider
/// observations remain in cloud inventory; refreshes must never overwrite these
/// user-reviewed values.
class ServerResources {
  ServerResources({
    this.ip = '',
    this.ipv6 = '',
    this.hostname = '',
    this.vcpu,
    this.ramBytes,
    this.diskBytes,
    this.trafficBytes,
    this.trafficUnlimited = false,
    this.trafficPeriodMonths,
    Set<String> apiFields = const {},
  }) : apiFields = Set.unmodifiable(apiFields);

  /// [ip] is the IPv4 address (the JSON key predates IPv6); [ipv6] is the
  /// optional IPv6 address. Both are hardware addresses, independent of the
  /// connection address in `ServerRecord.host`.
  final String ip, ipv6, hostname;
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

  /// `apiFields` may also mark the optional IPv6 address.
  static const _sourceKeys = {...fieldKeys, 'ipv6'};

  static bool _validAddress(String value, NetHostKind kind) {
    final address = NetAddress.tryParse(value, allowBrackets: false);
    return address != null &&
        address.kind == kind &&
        address.zone == null &&
        !address.isUnspecified;
  }

  /// Dotted-quad IPv4, not `0.0.0.0`.
  static bool validIpv4(String value) => _validAddress(value, NetHostKind.ipv4);

  /// Bare IPv6 (any spelling, no brackets or zone), not `::` or its mapped form.
  static bool validIpv6(String value) => _validAddress(value, NetHostKind.ipv6);

  /// Either family.
  static bool validIp(String value) => validIpv4(value) || validIpv6(value);

  static bool validHostname(String value) {
    final name = value.endsWith('.')
        ? value.substring(0, value.length - 1)
        : value;
    return name.isNotEmpty &&
        name != '0' &&
        value.length <= 253 &&
        NetAddress.tryParse(name, allowBrackets: false)?.isIp != true &&
        RegExp(
          r'^(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.?$',
        ).hasMatch(value);
  }

  /// Local editing permits unknown values; import must require all six fields.
  String? validate({bool requireComplete = false, AppLocalizations? l10n}) {
    l10n ??= defaultLocalizations;
    // A complete record needs at least one address; IPv6-only machines exist.
    if (ip.isNotEmpty ? !validIpv4(ip) : requireComplete && ipv6.isEmpty) {
      return l10n.r6IpValidIpv4;
    }
    if (ipv6.isNotEmpty && !validIpv6(ipv6)) {
      return l10n.r6IpValidIpv6;
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
    if (!_sourceKeys.containsAll(apiFields)) {
      return l10n.resourceInvalidSources;
    }
    final values = {
      'ip': ip.isEmpty ? null : ip,
      'ipv6': ipv6.isEmpty ? null : ipv6,
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
    // Optional key: absent when unset, so older records and exports are
    // byte-for-byte unchanged and older readers keep working on them.
    if (ipv6.isNotEmpty) 'ipv6': ipv6,
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
    final hasIpv6 = value.containsKey('ipv6');
    if (value.length != keys.length + (hasIpv6 ? 1 : 0) ||
        !keys.every(value.containsKey) ||
        value['ip'] is! String ||
        (hasIpv6 && value['ipv6'] is! String) ||
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
    var ip = value['ip'] as String;
    var ipv6 = hasIpv6 ? value['ipv6'] as String : '';
    var markers = sources.cast<String>().toSet();
    // Before IPv6 had its own field `ip` could hold either family. Move an
    // IPv6 found there (and its API marker) so old data and backups stay valid.
    if (ipv6.isEmpty && validIpv6(ip)) {
      ipv6 = ip;
      ip = '';
      if (markers.remove('ip')) markers.add('ipv6');
    }
    final result = ServerResources(
      ip: ip,
      ipv6: ipv6,
      hostname: value['hostname'] as String,
      vcpu: value['vcpu'] as int?,
      ramBytes: value['ramBytes'] as int?,
      diskBytes: value['diskBytes'] as int?,
      trafficBytes: value['trafficBytes'] as int?,
      trafficUnlimited: value['trafficUnlimited'] as bool,
      trafficPeriodMonths: value['trafficPeriodMonths'] as int?,
      apiFields: markers,
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
      ipv6.isEmpty &&
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

  /// Language-neutral hardware summary such as `2 vCPU · 2 GiB · 40 GiB`
  /// (vCPU, memory, disk). Empty when none of the three is known. Traffic is
  /// shown separately because it also needs its period.
  String get specSummary => specSummaryFor(defaultLocalizations);
  String specSummaryFor(AppLocalizations l10n) => [
    if (vcpu != null) '$vcpu vCPU',
    if (ramBytes != null) formatBytes(ramBytes!),
    if (diskBytes != null) formatBytes(diskBytes!),
  ].join(' · ');

  static const _units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'];

  /// Decimal text with at most [digits] fraction digits, no trailing zeros.
  static String _decimal(double value, int digits) => value
      .toStringAsFixed(digits)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');

  /// Human readable binary size: the largest unit that keeps the number at or
  /// above 1, rounded to two decimals (`1.86 GiB`, `2 GiB`, `512 MiB`).
  /// Raw bytes are only used below 1 KiB. Providers that sell decimal sizes
  /// (e.g. 2 000 000 000 B = "2 GB") therefore appear as `1.86 GiB`, which is
  /// the true binary size; the stored exact byte count is never altered.
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    var unit = 0;
    var divisor = 1;
    while (unit < _units.length - 1 && bytes >= divisor * 1024) {
      divisor *= 1024;
      unit++;
    }
    var amount = double.parse((bytes / divisor).toStringAsFixed(2));
    if (amount >= 1024 && unit < _units.length - 1) {
      // 1023.999 MiB rounds to 1024: present it in the next unit instead.
      unit++;
      amount = double.parse((bytes / (divisor * 1024)).toStringAsFixed(2));
    }
    return '${_decimal(amount, 2)} ${_units[unit]}';
  }

  /// Unit and number used to *edit* a stored byte count in the form: the
  /// largest of MiB / GiB / TiB that keeps the value at or above 1 (plain
  /// bytes below 1 MiB), with at most two decimals. The text can be rounded,
  /// so the form keeps the exact stored value until the user edits it.
  static ({int factor, String text}) editableAmount(int bytes) {
    const mib = 1048576, gib = 1073741824, tib = 1099511627776;
    var factor = bytes >= tib
        ? tib
        : bytes >= gib
        ? gib
        : bytes >= mib
        ? mib
        : 1;
    var amount = factor == 1 ? bytes.toDouble() : bytes / factor;
    if (factor != 1) {
      amount = double.parse(amount.toStringAsFixed(2));
      if (amount >= 1024 && factor != tib) {
        factor *= 1024;
        amount = double.parse((bytes / factor).toStringAsFixed(2));
      }
    }
    return (factor: factor, text: factor == 1 ? '$bytes' : _decimal(amount, 2));
  }
}
