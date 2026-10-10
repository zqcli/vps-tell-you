import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';

import 'dart:math' as math;
import 'dart:ui' show SemanticsValidationResult;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ui/ui.dart';
import 'server_resources.dart';

/// Single-line width of [text] at the user's text scale, used to decide
/// whether a label and its control still fit on one form row.
double measureFormText(
  BuildContext context,
  String text,
  double size, [
  FontWeight? weight,
]) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: size, fontWeight: weight),
    ),
    textScaler: MediaQuery.textScalerOf(context),
    textDirection: Directionality.of(context),
    locale: Localizations.maybeLocaleOf(context),
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// Width of a compact [AppSegmented]: Cupertino gives every segment the width
/// of the widest label plus 40 px of padding, separators and inset.
double compactSegmentWidth(BuildContext context, Iterable<String> labels) {
  var widest = 0.0;
  for (final label in labels) {
    widest = math.max(
      widest,
      measureFormText(context, label, 13, FontWeight.w600),
    );
  }
  return labels.length * (widest.ceilToDouble() + 40) + 4;
}

/// Single-choice bottom sheet whose rows are built from the *current* locale,
/// so an open picker follows a live language change. Returns the chosen value
/// or `null` when dismissed.
Future<T?> showFormPicker<T>(
  BuildContext context, {
  required String title,
  required List<AppPickerOption<T>> Function(AppLocalizations l10n) options,
  T? selected,
  String Function(AppLocalizations l10n)? footnote,
}) => showAppSheet<T>(
  context,
  title: title,
  builder: (sheetContext) {
    final l10n = sheetContext.l10n;
    final p = sheetContext.palette;
    return AppSection(
      topSpacing: 4,
      footer: footnote?.call(l10n),
      children: [
        for (final option in options(l10n))
          AppRow(
            key: option.key,
            title: option.title,
            subtitle: option.subtitle,
            trailing: option.value == selected
                ? Icon(Icons.check_rounded, size: 22, color: p.primary)
                : null,
            onTap: () => Navigator.pop(sheetContext, option.value),
          ),
      ],
    );
  },
);

/// An explicit local completion form. Merely editing it never starts a request
/// or establishes SSH configuration/trust.
///
/// Renders one grouped inset section (label left, control right) with an
/// optional collapsible header. The section brings its own horizontal [margin];
/// pass [EdgeInsets.zero] when the surrounding container already pads.
class ServerResourceFields extends StatefulWidget {
  const ServerResourceFields({
    super.key,
    this.initial,
    this.observed = const {},
    this.enabled = true,
    this.importing = true,
    this.defaultTrafficPeriodMonths,
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.hideIp = false,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });
  final ServerResources? initial;
  final Map<String, Object?> observed;
  final bool enabled, importing;

  /// Only used for new configurations; existing unknown periods stay unknown.
  final int? defaultTrafficPeriodMonths;

  /// Header toggles the group. Collapsed fields stay mounted, so their drafts
  /// are kept and still validated by [ServerResourceFieldsState.validateAndRead].
  final bool collapsible, initiallyExpanded;

  /// Outer margin of the grouped section.
  final EdgeInsets margin;

  /// Leave the IP row out (the surrounding form already asks for an address
  /// that is the IP). The stored value is kept and can be set through
  /// [ServerResourceFieldsState.ip].
  final bool hideIp;
  @override
  State<ServerResourceFields> createState() => ServerResourceFieldsState();
}

class ServerResourceFieldsState extends State<ServerResourceFields> {
  final _form = GlobalKey<FormState>();
  bool _hasValidated = false;
  String? _validationLocale;
  late bool _expanded = widget.initiallyExpanded || !widget.collapsible;
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

  /// Untouched initial capacities keep their exact bytes (see initState).
  final _exact = <String, ({int bytes, String text, int factor})>{};
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
      if (bytes is int && bytes > 0) {
        // Show the best unit with a short number. The text may be rounded, so
        // the exact stored value is kept until the user changes text or unit.
        final shown = ServerResources.editableAmount(bytes);
        _units[key] = shown.factor;
        _fields[key] = TextEditingController(text: shown.text);
        _exact[key] = (bytes: bytes, text: shown.text, factor: shown.factor);
      } else {
        _units[key] = key == 'ramBytes' ? units['MiB']! : units['GiB']!;
        _fields[key] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  /// Current IP text, including while its row is hidden.
  String get ip => _fields['ip']!.text.trim();
  set ip(String value) => _fields['ip']!.text = value.trim();

  int? _bytes(String key) {
    final text = _fields[key]!.text.trim();
    final exact = _exact[key];
    if (exact != null && exact.text == text && exact.factor == _units[key]) {
      return exact.bytes;
    }
    if (!RegExp(r'^(?:0|[1-9][0-9]*)(?:\.[0-9]{1,9})?$').hasMatch(text)) {
      return null;
    }
    final parts = text.split('.');
    final scale = BigInt.from(10).pow(parts.length == 1 ? 0 : parts[1].length);
    final amount = BigInt.parse(parts.join()) * BigInt.from(_units[key]!);
    var value = amount ~/ scale;
    if (amount % scale != BigInt.zero) {
      // The form shows sizes with two decimals (`1.86 GiB`), so a value typed
      // with up to two decimals in MiB or larger is rounded to the nearest
      // byte. Anything finer must still be an exact whole number of bytes.
      final decimals = parts.length == 1 ? 0 : parts[1].length;
      if (decimals > 2 || _units[key]! < units['MiB']!) {
        return null;
      }
      value = (amount * BigInt.two + scale) ~/ (scale * BigInt.two);
    }
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
      // A collapsed group would hide the message the user must fix.
      if (!_expanded) setState(() => _expanded = true);
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

  double _textWidth(String text, double size, [FontWeight? weight]) =>
      measureFormText(context, text, size, weight);

  Widget _semantic(String label, String? error, Widget child) => Semantics(
    label: label,
    hint: error,
    validationResult: error == null
        ? SemanticsValidationResult.valid
        : SemanticsValidationResult.invalid,
    child: child,
  );

  /// Row plus the small provenance line under it.
  Widget _block(Widget row, String key) {
    final source = _source(key);
    // Plain manual entry is the default of this form and needs no caption;
    // API provenance (and every state of the import flow) stays visible.
    if (source == null ||
        (!widget.importing && source == context.l10n.resourceSourceManual)) {
      return row;
    }
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            source,
            style: TextStyle(fontSize: 12.5, height: 1.3, color: p.text3),
          ),
        ),
      ],
    );
  }

  Widget _textRow(String key, String label) => FormField<void>(
    validator: (_) => _validate(key),
    builder: (field) => _block(
      AppFormRow(
        label: label,
        errorText: field.errorText,
        child: _semantic(
          label,
          field.errorText,
          AppTextField(
            key: ValueKey('resource-$key'),
            controller: _fields[key],
            enabled: widget.enabled,
            maxLength: key == 'hostname' ? 253 : 45,
            hint: context.l10n.serverUnknown,
            label: label,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() {}),
          ),
        ),
      ),
      key,
    ),
  );

  void _setVcpu(int value) {
    setState(() => _fields['vcpu']!.text = value == 0 ? '' : '$value');
  }

  Future<void> _enterVcpu() async {
    final value = await showAppSheet<int>(
      context,
      title: context.l10n.resourceVcpuCount,
      builder: (_) => _VcpuEntry(initial: _fields['vcpu']!.text.trim()),
    );
    if (value != null && mounted) _setVcpu(value);
  }

  Widget _vcpuRow() {
    final l10n = context.l10n;
    return FormField<void>(
      validator: (_) => _validate('vcpu'),
      builder: (field) {
        final count = (int.tryParse(_fields['vcpu']!.text.trim()) ?? 0).clamp(
          0,
          ServerResources.maxVcpu,
        );
        return _block(
          AppFormRow(
            label: l10n.resourceVcpuCount,
            errorText: field.errorText,
            child: Opacity(
              opacity: widget.enabled ? 1 : .45,
              // Tapping the number (the gap between the two buttons) opens an
              // exact entry sheet, so large counts do not need many taps.
              child: GestureDetector(
                onTap: widget.enabled ? _enterVcpu : null,
                child: AppStepper(
                  key: const ValueKey('resource-vcpu'),
                  value: count,
                  min: 0,
                  max: ServerResources.maxVcpu,
                  // 0 is the explicit "unknown" state, never stored as 0.
                  format: (v) => v == 0 ? '—' : '$v',
                  onChanged: widget.enabled ? _setVcpu : null,
                  decrementLabel: l10n.uiFormVcpuDecrease,
                  incrementLabel: l10n.uiFormVcpuIncrease,
                  decrementKey: const ValueKey('resource-vcpu-decrease'),
                  incrementKey: const ValueKey('resource-vcpu-increase'),
                ),
              ),
            ),
          ),
          'vcpu',
        );
      },
    );
  }

  Widget _capacityRow(String key, String label, String semanticLabel) {
    final enabled = widget.enabled && !(key == 'trafficBytes' && _unlimited);
    return FormField<void>(
      validator: (_) => _validate(key),
      builder: (field) {
        final input = _semantic(
          semanticLabel,
          field.errorText,
          AppTextField(
            key: ValueKey('resource-$key'),
            controller: _fields[key],
            enabled: enabled,
            maxLength: 32,
            hint: context.l10n.serverUnknown,
            label: semanticLabel,
            textInputAction: TextInputAction.next,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
        );
        final unit = Semantics(
          label: context.l10n.resourceUnitSemantics(semanticLabel),
          child: IgnorePointer(
            ignoring: !enabled,
            child: Opacity(
              opacity: enabled ? 1 : .45,
              child: AppSegmented<int>(
                key: ValueKey('resource-unit-$key'),
                compact: true,
                options: {
                  for (final unit in units.entries) unit.value: unit.key,
                },
                value: _units[key]!,
                onChanged: (factor) => setState(() => _units[key] = factor),
              ),
            ),
          ),
        );
        return _block(
          LayoutBuilder(
            builder: (context, box) {
              // AppFormRow pads 16 px per side and gives its label at most 45%.
              final inner = box.maxWidth - 32;
              final labelWidth = math.min(
                _textWidth(label, 16).ceilToDouble() + 1,
                inner * .45,
              );
              final segment = compactSegmentWidth(context, units.keys);
              final inline = inner - labelWidth - 12 >= 64 + 8 + segment;
              if (inline) {
                return AppFormRow(
                  key: ValueKey('resource-row-$key'),
                  label: label,
                  errorText: field.errorText,
                  child: Row(
                    children: [
                      Expanded(child: input),
                      const SizedBox(width: 8),
                      unit,
                    ],
                  ),
                );
              }
              // Four unit choices do not fit beside the value on a phone, so
              // the selector sits right-aligned on its own line below it.
              return Column(
                key: ValueKey('resource-row-$key'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppFormRow(
                    label: label,
                    errorText: field.errorText,
                    child: input,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FittedBox(fit: BoxFit.scaleDown, child: unit),
                    ),
                  ),
                ],
              );
            },
          ),
          key,
        );
      },
    );
  }

  static String _periodText(AppLocalizations l10n, int? months) {
    final label = ServerResources.trafficPeriodsFor(l10n)[months];
    return label == null
        ? l10n.notSet
        : l10n.resourceEveryPeriod(label.toLowerCase());
  }

  Future<void> _pickPeriod() async {
    final newDefault =
        widget.defaultTrafficPeriodMonths == 1 && widget.initial == null;
    final result = await showFormPicker<int>(
      context,
      title: context.l10n.resourceTrafficPeriod,
      selected: _trafficPeriodMonths ?? 0,
      options: (l10n) => [
        for (final months in ServerResources.trafficPeriodsFor(l10n).keys)
          AppPickerOption(value: months, title: _periodText(l10n, months)),
        AppPickerOption(value: 0, title: l10n.notSet),
      ],
      footnote: (l10n) =>
          newDefault ? l10n.resourceNewPeriodHelp : l10n.resourcePeriodHelp,
    );
    if (result != null && mounted) {
      setState(() => _trafficPeriodMonths = result == 0 ? null : result);
    }
  }

  Widget _header() {
    final p = context.palette;
    final l10n = context.l10n;
    final title = Text(
      widget.importing ? l10n.resourceSixRequired : l10n.resourceHardware,
      style: TextStyle(fontSize: 13, color: p.text2),
    );
    final inset = widget.margin.horizontal / 2 + 16;
    if (!widget.collapsible) {
      return Padding(
        padding: EdgeInsets.fromLTRB(inset, 22, inset, 7),
        child: title,
      );
    }
    return Semantics(
      button: true,
      expanded: _expanded,
      label: _expanded ? l10n.uiFormCollapse : l10n.uiFormExpand,
      excludeSemantics: true,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const ValueKey('resource-toggle'),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: EdgeInsets.fromLTRB(inset, 22, inset, 7),
            child: Row(
              children: [
                Expanded(child: title),
                AnimatedRotation(
                  turns: _expanded ? .5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: p.text2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final footnote = widget.importing
        ? l10n.resourceImportHelp
        : l10n.resourceLocalHelp;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          Visibility(
            visible: _expanded,
            maintainState: true,
            child: AppSection(
              topSpacing: 0,
              margin: widget.margin,
              footerWidget: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(footnote, style: context.footnoteStyle),
                  const SizedBox(height: 6),
                  Text(
                    l10n.resourceUnlimitedHelp,
                    style: context.footnoteStyle,
                  ),
                ],
              ),
              children: [
                _vcpuRow(),
                _capacityRow(
                  'ramBytes',
                  l10n.uiFormMemory,
                  l10n.resourceMemoryCapacity,
                ),
                _capacityRow(
                  'diskBytes',
                  l10n.uiFormDisk,
                  l10n.resourceDiskCapacity,
                ),
                _capacityRow(
                  'trafficBytes',
                  l10n.uiFormTraffic,
                  l10n.resourceTrafficQuotaLabel,
                ),
                Opacity(
                  opacity: widget.enabled ? 1 : .45,
                  child: AppFormRow.pick(
                    key: const ValueKey('resource-traffic-period'),
                    label: l10n.resourceTrafficPeriod,
                    value: _periodText(l10n, _trafficPeriodMonths),
                    onTap: widget.enabled ? _pickPeriod : null,
                  ),
                ),
                Semantics(
                  toggled: _unlimited,
                  child: AppSwitchRow(
                    key: const ValueKey('resource-traffic-unlimited'),
                    title: l10n.resourceUnlimitedTraffic,
                    value: _unlimited,
                    onChanged: widget.enabled
                        ? (value) => setState(() => _unlimited = value)
                        : null,
                  ),
                ),
                if (!widget.hideIp) _textRow('ip', l10n.resourceIpAddress),
                _textRow('hostname', l10n.resourceHostname),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Exact vCPU entry used by the stepper's number. Empty means unknown.
class _VcpuEntry extends StatefulWidget {
  const _VcpuEntry({required this.initial});
  final String initial;
  @override
  State<_VcpuEntry> createState() => _VcpuEntryState();
}

class _VcpuEntryState extends State<_VcpuEntry> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() {
    final value = int.tryParse(_controller.text.trim()) ?? 0;
    Navigator.pop(context, value.clamp(0, ServerResources.maxVcpu));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSection(
          topSpacing: 4,
          children: [
            AppFormRow(
              label: l10n.resourceVcpuCount,
              child: AppTextField(
                key: const ValueKey('resource-vcpu-entry'),
                controller: _controller,
                autofocus: true,
                maxLength: 5,
                hint: l10n.serverUnknown,
                label: l10n.resourceVcpuCount,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (_) => _done(),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  key: const ValueKey('resource-vcpu-unknown'),
                  label: l10n.uiFormSetUnknown,
                  kind: AppButtonKind.tonal,
                  onPressed: () => Navigator.pop(context, 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  key: const ValueKey('resource-vcpu-done'),
                  label: l10n.uiFormDone,
                  onPressed: _done,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
