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
  static const trafficPeriods = {1: '月', 3: '季', 12: '年'};

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
  String? validate({bool requireComplete = false}) {
    if ((requireComplete || ip.isNotEmpty) && !validIp(ip)) {
      return '请填写有效的 IPv4 或 IPv6 地址，不能使用未指定地址';
    }
    if ((requireComplete || hostname.isNotEmpty) && !validHostname(hostname)) {
      return '请填写有效主机名，不含协议、端口或路径';
    }
    if (vcpu == null ? requireComplete : vcpu! < 1 || vcpu! > maxVcpu) {
      return 'vCPU 需为 1–65536 的整数';
    }
    bool invalidBytes(int? value) =>
        value == null ? requireComplete : value < 1 || value > maxBytes;
    if (invalidBytes(ramBytes)) return '内存配额需为有效正数';
    if (invalidBytes(diskBytes)) return '硬盘配额需为有效正数';
    if (trafficUnlimited ? trafficBytes != null : invalidBytes(trafficBytes)) {
      return '流量需填写有效正数配额，或明确选择不限量';
    }
    if (trafficPeriodMonths != null &&
        !trafficPeriods.containsKey(trafficPeriodMonths)) {
      return '流量周期需选择月、季、年或未设置';
    }
    if (!fieldKeys.containsAll(apiFields)) return '资源来源字段无效';
    final values = {
      'ip': ip.isEmpty ? null : ip,
      'hostname': hostname.isEmpty ? null : hostname,
      'vcpu': vcpu,
      'ramBytes': ramBytes,
      'diskBytes': diskBytes,
      'trafficBytes': trafficUnlimited ? true : trafficBytes,
    };
    if (apiFields.any((key) => values[key] == null)) {
      return '未知资源不能标记为 API 来源';
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
      throw const FormatException('本地资源配置过大');
    }
    return ServerResources.fromJson(jsonDecode(source));
  }

  factory ServerResources.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('本地资源配置字段无效');
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
      throw const FormatException('本地资源配置字段无效');
    }
    final sources = value['apiFields'] as List;
    if (sources.any((field) => field is! String) ||
        sources.toSet().length != sources.length) {
      throw const FormatException('本地资源来源字段无效');
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
    if (error != null) throw FormatException(error);
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

  String get trafficPeriodLabel => trafficPeriods[trafficPeriodMonths] ?? '未设置';

  String get trafficSummary {
    final quota = trafficUnlimited
        ? '流量不限量'
        : trafficBytes == null
        ? '流量未知'
        : '${formatBytes(trafficBytes!)} 流量';
    return '$quota · ${trafficPeriodMonths == null ? '周期未设置' : '每$trafficPeriodLabel'}';
  }

  String get specSummary => [
    if (vcpu != null) '$vcpu vCPU',
    if (ramBytes != null) '${formatBytes(ramBytes!)} RAM',
    if (diskBytes != null) '${formatBytes(diskBytes!)} 硬盘',
    // Keep the established automatic summary stable for existing records.
    // The separately stored period is shown in the hardware section.
    if (trafficUnlimited)
      '流量不限量'
    else if (trafficBytes != null)
      '${formatBytes(trafficBytes!)} 流量',
  ].join(' · ');

  static String formatBytes(int bytes, {bool exact = false}) {
    const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'];
    var divisor = 1;
    var unit = 0;
    while (unit < units.length - 1 && bytes >= divisor * 1024) {
      divisor *= 1024;
      unit++;
    }
    if (exact && bytes % divisor != 0) return '$bytes B';
    final amount = bytes % divisor == 0
        ? (bytes ~/ divisor).toString()
        : (bytes / divisor)
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
    return '$amount ${units[unit]}';
  }
}
