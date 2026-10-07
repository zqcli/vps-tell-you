import 'dart:ui' show SemanticsValidationResult;

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
    this.defaultTrafficPeriodMonths,
  });
  final ServerResources? initial;
  final Map<String, Object?> observed;
  final bool enabled, importing;

  /// Only used for new configurations; existing unknown periods stay unknown.
  final int? defaultTrafficPeriodMonths;
  @override
  State<ServerResourceFields> createState() => ServerResourceFieldsState();
}

class ServerResourceFieldsState extends State<ServerResourceFields> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  final _units = <String, int>{};
  late bool _unlimited;
  int? _trafficPeriodMonths;
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
    _trafficPeriodMonths = initial == null
        ? widget.defaultTrafficPeriodMonths
        : initial.trafficPeriodMonths;
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

  String? _source(String key) {
    if (!widget.importing && !_apiSource(key)) {
      return _fields[key]!.text.trim().isEmpty &&
              !(key == 'trafficBytes' && _unlimited)
          ? null
          : '来源：手动填写';
    }
    if (_apiSource(key)) return '来源：API';
    if (widget.initial != null) return '来源：手动填写';
    if (key == 'trafficBytes' && _unlimited) return '来源：手动确认不限量';
    if (_fields[key]!.text.trim().isEmpty) return '待补填：API 未提供有效值';
    return widget.observed[key] == null ? '来源：手动补填' : '来源：手动修改 API 预填值';
  }

  ServerResources? validateAndRead({
    Set<FormFieldState<Object?>>? invalidFields,
  }) {
    final invalid = _form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      invalidFields?.addAll(invalid);
      return null;
    }
    final result = ServerResources(
      ip: _fields['ip']!.text.trim(),
      hostname: _fields['hostname']!.text.trim(),
      vcpu: _value('vcpu') as int?,
      ramBytes: _bytes('ramBytes'),
      diskBytes: _bytes('diskBytes'),
      trafficBytes: _unlimited ? null : _bytes('trafficBytes'),
      trafficUnlimited: _unlimited,
      trafficPeriodMonths: _trafficPeriodMonths,
      apiFields: {
        for (final key in _fields.keys)
          if (_apiSource(key)) key,
      },
    );
    return result.validate(requireComplete: widget.importing) == null
        ? result
        : null;
  }

  String? _validate(String key) {
    final value = _value(key);
    if (key == 'trafficBytes' && _unlimited) return null;
    if (!widget.importing && _fields[key]!.text.trim().isEmpty) return null;
    if (key == 'ip') {
      return ServerResources.validIp(value as String)
          ? null
          : '请填写有效 IPv4 或 IPv6，不能为全零地址';
    }
    if (key == 'hostname') {
      return ServerResources.validHostname(value as String)
          ? null
          : '请填写有效主机名，不含协议、端口或路径';
    }
    return value is int &&
            value > 0 &&
            value <= (key == 'vcpu' ? ServerResources.maxVcpu : maxValue)
        ? null
        : key == 'vcpu'
        ? '请填写 1–65536 的整数核数'
        : '请填写大于 0 的容量，精确到整字节';
  }

  Widget _field(String key, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      key: ValueKey('resource-$key'),
      controller: _fields[key],
      enabled: widget.enabled,
      maxLength: key == 'hostname'
          ? 253
          : key == 'ip'
          ? 45
          : 32,
      keyboardType: key == 'vcpu' ? TextInputType.number : TextInputType.text,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        helperText: _source(key),
        helperMaxLines: 3,
        errorMaxLines: 4,
      ),
      validator: (_) => _validate(key),
      onChanged: (_) => setState(() {}),
    ),
  );

  InputDecoration _compactDecoration(String label) => InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
    counterText: '',
  );

  Widget _capacityField(String key, String label, {bool traffic = false}) {
    final enabled = widget.enabled && !(traffic && _unlimited);
    final style = Theme.of(context).textTheme.bodyMedium;
    // Reserve the complete unit word at the user's text size. The remaining
    // space is shared by the editable number and period; unknown periods can
    // wrap instead of clipping at narrow widths or with enlarged text.
    var unitWidth = 64.0;
    for (final unit in units.keys) {
      final painter = TextPainter(
        text: TextSpan(text: unit, style: style),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout();
      if (painter.width + 48 > unitWidth) unitWidth = painter.width + 48;
      painter.dispose();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: FormField<void>(
        validator: (_) => _validate(key),
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Keep long labels, provenance and help outside the narrow controls.
            // Only the capacity, unit and optional quota period share this row.
            Text(label),
            const SizedBox(height: 8),
            Row(
              key: ValueKey('resource-row-$key'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Semantics(
                    label: label,
                    hint: field.errorText,
                    validationResult: field.hasError
                        ? SemanticsValidationResult.invalid
                        : SemanticsValidationResult.valid,
                    child: TextFormField(
                      key: ValueKey('resource-$key'),
                      controller: _fields[key],
                      enabled: enabled,
                      maxLength: 32,
                      textInputAction: TextInputAction.next,
                      style: style,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _compactDecoration('容量').copyWith(
                        // The shared row owns validation so its message can use
                        // the full width below all three controls.
                        error: field.hasError ? const SizedBox.shrink() : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: unitWidth,
                  child: Semantics(
                    label: '$label单位，1024 进制',
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('resource-unit-$key'),
                      initialValue: _units[key],
                      isExpanded: true,
                      isDense: false,
                      itemHeight: null,
                      selectedItemBuilder: (context) => [
                        for (final unit in units.keys) Text(unit),
                      ],
                      style: style,
                      iconSize: 16,
                      decoration: _compactDecoration('单位'),
                      items: [
                        for (final unit in units.entries)
                          DropdownMenuItem(
                            value: unit.value,
                            child: Text(unit.key),
                          ),
                      ],
                      onChanged: enabled
                          ? (unit) => setState(() => _units[key] = unit!)
                          : null,
                    ),
                  ),
                ),
                if (traffic) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 1,
                    child: Semantics(
                      label: '流量周期',
                      child: DropdownButtonFormField<int>(
                        key: const ValueKey('resource-traffic-period'),
                        initialValue: _trafficPeriodMonths ?? 0,
                        isExpanded: true,
                        isDense: false,
                        itemHeight: null,
                        selectedItemBuilder: (context) => [
                          if (_trafficPeriodMonths == null)
                            const Text('未设置')
                          else
                            const SizedBox.shrink(),
                          for (final period
                              in ServerResources.trafficPeriods.entries)
                            if (period.key == _trafficPeriodMonths)
                              Text(period.value)
                            else
                              const SizedBox.shrink(),
                        ],
                        style: style,
                        iconSize: 16,
                        decoration: _compactDecoration('周期'),
                        items: [
                          const DropdownMenuItem(value: 0, child: Text('未设置')),
                          for (final period
                              in ServerResources.trafficPeriods.entries)
                            DropdownMenuItem(
                              value: period.key,
                              child: Text(period.value),
                            ),
                        ],
                        onChanged: widget.enabled
                            ? (value) => setState(
                                () => _trafficPeriodMonths = value == 0
                                    ? null
                                    : value,
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (field.hasError) ...[
              const SizedBox(height: 6),
              Semantics(
                liveRegion: true,
                child: Text(
                  field.errorText!,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            if (_source(key) case final source?) ...[
              const SizedBox(height: 6),
              Text(source, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (traffic) ...[
              const SizedBox(height: 6),
              Text(
                widget.defaultTrafficPeriodMonths == 1 && widget.initial == null
                    ? '新建默认按月，请按套餐确认；也可选“未设置”。'
                    : '周期独立于容量单位；未知选“未设置”。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(widget.importing ? '硬件信息 · 六项必填' : '硬件信息'),
        InfoNote(
          widget.importing
              ? '核对并补齐六项后导入；容量按 1024 进制，0 不代表不限量。资料不全时可暂不选择此实例，待补齐后再导入。'
              : '未知可留空，容量按 1024 进制。仅维护本地硬件，API 刷新不会覆盖，也不更改远端配置或 SSH 地址。',
        ),
        _field('ip', 'IP 地址'),
        _field('hostname', '主机名'),
        _capacityField('diskBytes', '磁盘容量'),
        _capacityField('trafficBytes', '流量额度', traffic: true),
        SwitchListTile(
          key: const ValueKey('resource-traffic-unlimited'),
          contentPadding: EdgeInsets.zero,
          value: _unlimited,
          onChanged: widget.enabled
              ? (value) => setState(() => _unlimited = value)
              : null,
          title: const Text('流量不限量'),
        ),
        Text(
          '仅在套餐明确不限量时开启；未知或 API 返回 0 请保持关闭。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        _capacityField('ramBytes', '内存容量'),
        _field('vcpu', 'vCPU 核数'),
      ],
    ),
  );
}
