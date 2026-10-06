import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'server_resources.dart';

/// An explicit local completion form. Merely editing it never starts a request
/// or establishes SSH configuration/trust.
class ServerResourceFields extends StatefulWidget {
  const ServerResourceFields({
    super.key,
    this.initial,
    this.observed = const {},
    this.enabled = true,
    this.importing = true,
  });
  final ServerResources? initial;
  final Map<String, Object?> observed;
  final bool enabled, importing;
  @override
  State<ServerResourceFields> createState() => ServerResourceFieldsState();
}

class ServerResourceFieldsState extends State<ServerResourceFields> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  final _units = <String, int>{};
  late bool _unlimited;
  static const units = {
    'B': 1,
    'MiB': 1048576,
    'GiB': 1073741824,
    'TiB': 1099511627776,
  };
  static const maxValue = 9007199254740991;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final data = initial == null
        ? widget.observed
        : <String, Object?>{
            'ip': initial.ip,
            'hostname': initial.hostname,
            'vcpu': initial.vcpu,
            'ramBytes': initial.ramBytes,
            'diskBytes': initial.diskBytes,
            'trafficBytes': initial.trafficBytes,
          };
    _unlimited =
        initial?.trafficUnlimited ??
        widget.observed['trafficUnlimited'] == true;
    for (final key in ['ip', 'hostname', 'vcpu']) {
      _fields[key] = TextEditingController(text: data[key]?.toString() ?? '');
    }
    for (final key in ['ramBytes', 'diskBytes', 'trafficBytes']) {
      final bytes = data[key];
      final factor = bytes is int && bytes > 0
          ? units.values.toList().reversed.firstWhere((f) => bytes % f == 0)
          : key == 'ramBytes'
          ? units['MiB']!
          : units['GiB']!;
      _units[key] = factor;
      _fields[key] = TextEditingController(
        text: bytes is int && bytes > 0 ? (bytes ~/ factor).toString() : '',
      );
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  int? _bytes(String key) {
    final text = _fields[key]!.text.trim();
    if (!RegExp(r'^(?:0|[1-9][0-9]*)(?:\.[0-9]{1,9})?$').hasMatch(text)) {
      return null;
    }
    final parts = text.split('.');
    final scale = BigInt.from(10).pow(parts.length == 1 ? 0 : parts[1].length);
    final amount = BigInt.parse(parts.join()) * BigInt.from(_units[key]!);
    if (amount % scale != BigInt.zero) return null;
    final value = amount ~/ scale;
    return value > BigInt.zero && value <= BigInt.from(maxValue)
        ? value.toInt()
        : null;
  }

  Object? _value(String key) => switch (key) {
    'ramBytes' || 'diskBytes' || 'trafficBytes' => _bytes(key),
    'vcpu' =>
      RegExp(r'^[1-9][0-9]*$').hasMatch(_fields[key]!.text.trim())
          ? int.tryParse(_fields[key]!.text.trim())
          : null,
    _ => _fields[key]!.text.trim(),
  };

  bool _apiSource(String key) {
    if (widget.initial != null) {
      final initial = widget.initial!;
      final old = switch (key) {
        'ip' => initial.ip,
        'hostname' => initial.hostname,
        'vcpu' => initial.vcpu,
        'ramBytes' => initial.ramBytes,
        'diskBytes' => initial.diskBytes,
        _ => initial.trafficBytes,
      };
      return initial.apiFields.contains(key) &&
          old == _value(key) &&
          (key != 'trafficBytes' || initial.trafficUnlimited == _unlimited);
    }
    if (key == 'trafficBytes' && _unlimited) {
      return widget.observed['trafficUnlimited'] == true;
    }
    final observed = widget.observed[key];
    return observed != null && observed == _value(key);
  }

  String _source(String key) {
    if (_apiSource(key)) return '来源：API，导入后保留为本地资料';
    if (widget.initial != null) return '来源：手动填写';
    if (key == 'trafficBytes' && _unlimited) return '来源：手动确认无限流量';
    if (_fields[key]!.text.trim().isEmpty) return '待补填：API 未提供、为 0 或值无效';
    return widget.observed[key] == null ? '来源：手动补填' : '来源：手动覆盖 API';
  }

  ServerResources? validateAndRead() {
    if (!_form.currentState!.validate()) return null;
    final result = ServerResources(
      ip: _fields['ip']!.text.trim(),
      hostname: _fields['hostname']!.text.trim(),
      vcpu: _value('vcpu') as int,
      ramBytes: _bytes('ramBytes')!,
      diskBytes: _bytes('diskBytes')!,
      trafficBytes: _unlimited ? null : _bytes('trafficBytes'),
      trafficUnlimited: _unlimited,
      apiFields: {
        for (final key in _fields.keys)
          if (_apiSource(key)) key,
      },
    );
    return result.validate() == null ? result : null;
  }

  String? _validate(String key) {
    final value = _value(key);
    if (key == 'trafficBytes' && _unlimited) return null;
    if (key == 'ip') {
      return ServerResources.validIp(value as String)
          ? null
          : '请填写有效 IPv4 或 IPv6，不能为全零地址';
    }
    if (key == 'hostname') {
      return ServerResources.validHostname(value as String)
          ? null
          : '请填写有效 hostname，不含协议、端口或路径';
    }
    return value is int &&
            value > 0 &&
            value <= (key == 'vcpu' ? ServerResources.maxVcpu : maxValue)
        ? null
        : key == 'vcpu'
        ? '请填写 1–65536 的整数核数'
        : '请填写大于 0 的容量，精确到整字节';
  }

  Widget _field(String key, String label, {bool bytes = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: ValueKey('resource-$key'),
          controller: _fields[key],
          enabled: widget.enabled && !(key == 'trafficBytes' && _unlimited),
          maxLength: key == 'hostname'
              ? 253
              : key == 'ip'
              ? 45
              : 32,
          keyboardType: bytes
              ? const TextInputType.numberWithOptions(decimal: true)
              : key == 'vcpu'
              ? TextInputType.number
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            counterText: '',
            helperText: _source(key),
            helperMaxLines: 3,
          ),
          validator: (_) => _validate(key),
          onChanged: (_) => setState(() {}),
        ),
        if (bytes)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: DropdownButtonFormField<int>(
              key: ValueKey('resource-unit-$key'),
              initialValue: _units[key],
              decoration: const InputDecoration(labelText: '容量单位（1024 进制）'),
              items: [
                for (final unit in units.entries)
                  DropdownMenuItem(value: unit.value, child: Text(unit.key)),
              ],
              onChanged:
                  widget.enabled && !(key == 'trafficBytes' && _unlimited)
                  ? (unit) => setState(() => _units[key] = unit!)
                  : null,
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('资源资料 · 六项必填'),
        InfoNote(
          widget.importing
              ? '核对 API 已填值，补齐未知项。0 不代表容量或无限流量；若暂时不知道，可仅保存账户，稍后继续导入。'
              : '本地资源资料与 API 观测分别保存，修改这些值不会更改远端配置。',
        ),
        _field('ip', 'IP 地址'),
        _field('hostname', 'Hostname'),
        _field('diskBytes', '磁盘额度', bytes: true),
        _field('trafficBytes', '流量额度', bytes: true),
        CheckboxListTile(
          key: const ValueKey('resource-traffic-unlimited'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _unlimited,
          onChanged: widget.enabled
              ? (value) => setState(() => _unlimited = value ?? false)
              : null,
          title: const Text('已确认套餐流量不限量'),
          subtitle: const Text('仅在套餐确实不限量时选择，不按 API 的 0 推断'),
        ),
        const SizedBox(height: 18),
        _field('ramBytes', '内存容量', bytes: true),
        _field('vcpu', 'vCPU 核数'),
      ],
    ),
  );
}
