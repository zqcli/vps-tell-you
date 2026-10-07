import '../l10n/locale_preference.dart';

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
  bool _hasValidated = false;
  String? _validationLocale;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.l10n.localeName;
    if (_validationLocale != null &&
        _validationLocale != next &&
        _hasValidated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _form.currentState?.validate();
        }
      });
    }
    _validationLocale = next;
  }

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
    if (amount % scale != BigInt.zero) {
      return null;
    }
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
          : context.l10n.resourceSourceManual;
    }
    if (_apiSource(key)) {
      return context.l10n.resourceSourceApi;
    }
    if (widget.initial != null) {
      return context.l10n.resourceSourceManual;
    }
    if (key == 'trafficBytes' && _unlimited) {
      return context.l10n.resourceSourceUnlimited;
    }
    if (_fields[key]!.text.trim().isEmpty) {
      return context.l10n.resourceSourceMissing;
    }
    return widget.observed[key] == null
        ? context.l10n.resourceSourceCompleted
        : context.l10n.resourceSourceEditedApi;
  }

  ServerResources? validateAndRead({
    Set<FormFieldState<Object?>>? invalidFields,
  }) {
    _hasValidated = true;
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
    if (key == 'trafficBytes' && _unlimited) {
      return null;
    }
    if (!widget.importing && _fields[key]!.text.trim().isEmpty) {
      return null;
    }
    if (key == 'ip') {
      return ServerResources.validIp(value as String)
          ? null
          : context.l10n.resourceFieldValidIp;
    }
    if (key == 'hostname') {
      return ServerResources.validHostname(value as String)
          ? null
          : context.l10n.resourceValidHostname;
    }
    return value is int &&
            value > 0 &&
            value <= (key == 'vcpu' ? ServerResources.maxVcpu : maxValue)
        ? null
        : key == 'vcpu'
        ? context.l10n.resourceFieldValidVcpu
        : context.l10n.resourceFieldValidBytes;
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

  Widget _trafficPeriodValue(int months) {
    final l10n = context.l10n;
    final fullLabel = months == 0
        ? l10n.notSet
        : ServerResources.trafficPeriodsFor(l10n)[months]!;
    final compactLabel = switch (months) {
      0 => l10n.resourceTrafficPeriodUnsetShort,
      1 => l10n.resourceTrafficPeriodMonthShort,
      3 => l10n.resourceTrafficPeriodQuarterShort,
      12 => l10n.resourceTrafficPeriodYearShort,
      _ => fullLabel,
    };
    return Tooltip(
      message: fullLabel,
      child: Semantics(
        label: fullLabel,
        excludeSemantics: true,
        child: Text(compactLabel),
      ),
    );
  }

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
      if (painter.width + 48 > unitWidth) {
        unitWidth = painter.width + 48;
      }
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
                      decoration:
                          _compactDecoration(context.l10n.resourceCapacity)
                              .copyWith(
                                // The shared row owns validation so its message can use
                                // the full width below all three controls.
                                error: field.hasError
                                    ? const SizedBox.shrink()
                                    : null,
                              ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: unitWidth,
                  child: Semantics(
                    label: context.l10n.resourceUnitSemantics(
                      (label).toString(),
                    ),
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
                      decoration: _compactDecoration(context.l10n.resourceUnit),
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
                      label: context.l10n.resourceTrafficPeriod,
                      child: DropdownButtonFormField<int>(
                        key: const ValueKey('resource-traffic-period'),
                        initialValue: _trafficPeriodMonths ?? 0,
                        isExpanded: true,
                        isDense: false,
                        itemHeight: null,
                        selectedItemBuilder: (context) => [
                          if (_trafficPeriodMonths == null)
                            _trafficPeriodValue(0)
                          else
                            const SizedBox.shrink(),
                          for (final period
                              in ServerResources.trafficPeriodsFor(context.l10n)
                                  .keys)
                            if (period == _trafficPeriodMonths)
                              _trafficPeriodValue(period)
                            else
                              const SizedBox.shrink(),
                        ],
                        style: style,
                        iconSize: 16,
                        decoration: _compactDecoration(
                          context.l10n.resourcePeriod,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 0,
                            child: Builder(
                              builder: (context) => Text(context.l10n.notSet),
                            ),
                          ),
                          for (final period
                              in ServerResources.trafficPeriodsFor(context.l10n)
                                  .keys)
                            DropdownMenuItem(
                              value: period,
                              child: Builder(
                                builder: (context) => Text(
                                  ServerResources.trafficPeriodsFor(
                                    context.l10n,
                                  )[period]!,
                                ),
                              ),
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
                    ? context.l10n.resourceNewPeriodHelp
                    : context.l10n.resourcePeriodHelp,
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
        SectionTitle(
          widget.importing
              ? context.l10n.resourceSixRequired
              : context.l10n.resourceHardware,
        ),
        InfoNote(
          widget.importing
              ? context.l10n.resourceImportHelp
              : context.l10n.resourceLocalHelp,
        ),
        _field('ip', context.l10n.resourceIpAddress),
        _field('hostname', context.l10n.resourceHostname),
        _capacityField('diskBytes', context.l10n.resourceDiskCapacity),
        _capacityField(
          'trafficBytes',
          context.l10n.resourceTrafficQuotaLabel,
          traffic: true,
        ),
        SwitchListTile(
          key: const ValueKey('resource-traffic-unlimited'),
          contentPadding: EdgeInsets.zero,
          value: _unlimited,
          onChanged: widget.enabled
              ? (value) => setState(() => _unlimited = value)
              : null,
          title: Text(context.l10n.resourceUnlimitedTraffic),
        ),
        Text(
          context.l10n.resourceUnlimitedHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        _capacityField('ramBytes', context.l10n.resourceMemoryCapacity),
        _field('vcpu', context.l10n.resourceVcpuCount),
      ],
    ),
  );
}
