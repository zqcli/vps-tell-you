import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';
import '../l10n/generated/app_localizations.dart';

import 'dart:math' as math;
import 'dart:ui' show SemanticsValidationResult;

import 'package:flutter/material.dart';

import '../cloud/provider_pages.dart';
import '../cloud/provider_record.dart';
import '../core/app_theme.dart';
import '../core/form_feedback.dart';
import '../core/value_types.dart';
import 'ledger_controller.dart';
import 'server_record.dart';
import 'server_resource_fields.dart';

class ServerForm extends StatefulWidget {
  const ServerForm({
    super.key,
    required this.controller,
    this.record,
    this.businessProvider,
    this.focusHardware = false,
  });
  final LedgerController controller;
  final ServerRecord? record;
  final ProviderRecord? businessProvider;
  final bool focusHardware;
  @override
  State<ServerForm> createState() => _ServerFormState();
}

class _ServerFormState extends State<ServerForm> {
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

  final _resources = GlobalKey<ServerResourceFieldsState>();
  final _cycleFocus = FocusNode();
  late final Map<String, TextEditingController> fields;
  late BillingKind billing;
  late String currency;
  late int cycle;
  String? groupId;
  ProviderRecord? selectedProvider;
  bool choosingProvider = false;
  bool saving = false;
  bool get termsLocked =>
      widget.record != null &&
      widget.controller.hasPaymentPeriods(widget.record!.id);
  @override
  void initState() {
    super.initState();
    _cycleFocus.addListener(_refreshCycleFocus);
    final s = widget.record;
    selectedProvider = widget.businessProvider;
    fields = {
      'name': TextEditingController(text: s?.name),
      'host': TextEditingController(text: s?.host),
      'region': TextEditingController(text: s?.region),
      'purpose': TextEditingController(text: s?.purpose),
      'os': TextEditingController(text: s?.os),
      'spec': TextEditingController(text: s?.spec),
      'notes': TextEditingController(text: s?.notes),
      'amount': TextEditingController(text: s?.money?.decimal),
      'start': TextEditingController(text: s?.startDate?.toString()),
      'due': TextEditingController(text: s?.dueDate?.toString()),
    };
    billing = s?.billing ?? BillingKind.unknown;
    currency = s?.currency ?? 'USD';
    cycle = s?.cycleMonths ?? 12;
    groupId = s?.groupId;
    if (widget.focusHardware) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final hardwareContext = _resources.currentContext;
        if (hardwareContext != null) {
          Scrollable.ensureVisible(hardwareContext);
        }
      });
    }
  }

  void _refreshCycleFocus() => setState(() {});

  @override
  void dispose() {
    _cycleFocus.removeListener(_refreshCycleFocus);
    _cycleFocus.dispose();
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  String? _validateField(
    String id,
    String label,
    String? value, {
    bool required = false,
  }) {
    final text = value?.trim() ?? '';
    if (required && text.isEmpty) {
      return context.l10n.serverRequiredField((label).toString());
    }
    if (id == 'amount' &&
        billing != BillingKind.unknown &&
        Money.parseMinor(text) == null) {
      return context.l10n.serverAmountPrecision;
    }
    if ((id == 'start' || id == 'due') &&
        text.isNotEmpty &&
        LedgerDate.tryParse(text) == null) {
      return context.l10n.serverDateExample;
    }
    if (id == 'due' && billing == BillingKind.prepaid) {
      final start = LedgerDate.tryParse(fields['start']!.text.trim());
      final due = LedgerDate.tryParse(text);
      if (start != null && due != null && start.compareTo(due) >= 0) {
        return context.l10n.serverDueAfterStart;
      }
    }
    if (id == 'host' && !ServerRecord.validHost(text)) {
      return context.l10n.serverPlainHost;
    }
    return null;
  }

  Widget field(
    String id,
    String label, {
    String? hint,
    bool required = false,
    int max = 80,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      key: ValueKey('field-$id'),
      controller: fields[id],
      enabled: !saving && !(termsLocked && (id == 'start' || id == 'due')),
      maxLines: lines,
      maxLength: max,
      keyboardType: lines > 1 ? TextInputType.multiline : TextInputType.text,
      textInputAction: lines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      autocorrect: id != 'host',
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        errorMaxLines: 4,
      ),
      validator: (value) =>
          _validateField(id, label, value, required: required),
    ),
  );

  Widget select<T>(
    String label,
    T value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?> changed, {
    String? id,
    Map<T, String>? selectedLabels,
    bool compact = false,
    String? shortLabel,
  }) {
    final enabled =
        !saving && !(termsLocked && (id == 'billing' || id == 'cycle'));
    final dropdown = Semantics(
      label: compact ? label : null,
      child: DropdownButtonFormField<T>(
        key: id == null ? null : ValueKey('field-$id'),
        initialValue: value,
        isExpanded: true,
        iconSize: compact ? 16 : 24,
        isDense: id == null,
        itemHeight: null,
        style: id == null ? null : Theme.of(context).textTheme.bodyMedium,
        selectedItemBuilder: id == null
            ? null
            : (context) => [
                for (final item in items)
                  item.value == value
                      ? selectedLabels == null
                            ? item.child
                            : Semantics(
                                label: compact && item.child is Text
                                    ? (item.child as Text).data
                                    : null,
                                excludeSemantics: compact,
                                child: Text(selectedLabels[value]!),
                              )
                      : const SizedBox.shrink(),
              ],
        decoration: compact
            ? InputDecoration(
                labelText: shortLabel ?? label,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 14,
                ),
                constraints: const BoxConstraints(minHeight: 48),
              )
            : InputDecoration(labelText: label),
        items: items,
        onChanged: enabled ? changed : null,
      ),
    );
    return Padding(
      key: id == null ? null : ValueKey('row-$id'),
      padding: EdgeInsets.only(bottom: compact ? 0 : 18),
      child: dropdown,
    );
  }

  Widget _compactInput(
    String id,
    String label,
    String semanticLabel,
    String? error, {
    bool date = false,
  }) => Semantics(
    label: semanticLabel,
    hint: error,
    validationResult: error == null
        ? SemanticsValidationResult.valid
        : SemanticsValidationResult.invalid,
    child: TextFormField(
      key: ValueKey('field-$id'),
      controller: fields[id],
      enabled: !saving && !(termsLocked && date),
      maxLength: date ? 10 : 13,
      minLines: date ? 1 : null,
      // Soft wrapping preserves the complete date at enlarged text sizes. It
      // never inserts a newline into the stored ISO date or changes parsing.
      maxLines: date ? null : 1,
      style: Theme.of(context).textTheme.bodyMedium,
      keyboardType: date
          ? TextInputType.datetime
          : const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        hintText: date ? 'YYYY-MM-DD' : null,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        counterText: '',
        error: error == null ? null : const SizedBox.shrink(),
      ),
    ),
  );

  Widget _rowError(String error, {String? label}) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null)
            Text(
              '$label：',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          Text(
            error,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ),
    ),
  );

  double _textWidth(String text, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  double _floatingLabelWidth(String label) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyLarge?.merge(
      WidgetStateProperty.resolveAs(
        theme.inputDecorationTheme.floatingLabelStyle ??
            theme.inputDecorationTheme.labelStyle,
        const <WidgetState>{},
      ),
    );
    // Material scales the floating label after applying the text scaler.
    return (_textWidth(label, style) * .75).ceilToDouble();
  }

  String _cycleDescription(int months, AppLocalizations l10n) =>
      months == 12 ? l10n.serverEveryYear : l10n.serverEveryMonths(months);

  Widget _cycleSelect(Map<int, String> labels) {
    final enabled = !saving && !termsLocked;
    final style = Theme.of(context).textTheme.bodyMedium;
    var menuWidth = 128.0;
    for (final months in labels.keys) {
      menuWidth = math.max(
        menuWidth,
        (_textWidth(_cycleDescription(months, context.l10n), style) + 40)
            .ceilToDouble(),
      );
    }
    return Padding(
      key: const ValueKey('row-cycle'),
      padding: EdgeInsets.zero,
      child: Semantics(
        label: context.l10n.serverRenewalCycle,
        child: InputDecorator(
          key: const ValueKey('field-cycle'),
          isFocused: enabled && _cycleFocus.hasFocus,
          decoration: InputDecoration(
            labelText: context.l10n.resourcePeriod,
            enabled: enabled,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            // Put vertical padding inside the button so tapping above or
            // below the selected text still opens the menu. Keep the label
            // inset aligned with the adjacent amount and currency fields.
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minHeight: 48),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: cycle,
                focusNode: _cycleFocus,
                isExpanded: true,
                itemHeight: null,
                style: style,
                iconSize: 16,
                icon: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.arrow_drop_down),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                // The closed field follows the short selected value. The popup
                // independently fits the full period names at the text scale;
                // Flutter bounds it to the available viewport for legacy values.
                menuWidth: menuWidth,
                borderRadius: BorderRadius.circular(12),
                selectedItemBuilder: (context) => [
                  for (final months in labels.keys)
                    months == cycle
                        ? Semantics(
                            label: _cycleDescription(months, context.l10n),
                            excludeSemantics: true,
                            child: Text(labels[months]!),
                          )
                        : const SizedBox.shrink(),
                ],
                items: [
                  for (final months in labels.keys)
                    DropdownMenuItem(
                      value: months,
                      child: Builder(
                        builder: (context) =>
                            Text(_cycleDescription(months, context.l10n)),
                      ),
                    ),
                ],
                onChanged: enabled
                    ? (months) => setState(() => cycle = months!)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _feeRow() {
    final amountLabel = billing == BillingKind.metered
        ? context.l10n.serverMonthlyEstimate
        : context.l10n.serverRenewalAmount;
    final standardCycleLabels = {
      1: context.l10n.resourceMonth,
      3: context.l10n.resourceQuarter,
      6: context.l10n.serverHalfYear,
      12: context.l10n.resourceYear,
      24: context.l10n.serverTwoYears,
      36: context.l10n.serverThreeYears,
    };
    final cycleLabels = {
      ...standardCycleLabels,
      // Keep an unexpected legacy value visible until the user changes it;
      // building the form must not assert or silently normalize stored data.
      if (!standardCycleLabels.containsKey(cycle))
        cycle: context.l10n.serverCompactMonths(cycle),
    };
    final valueStyle = Theme.of(context).textTheme.bodyMedium;
    var currencyWidth = 64.0;
    for (final currency in Money.currencies) {
      currencyWidth = math.max(
        currencyWidth,
        _textWidth(currency, valueStyle) + 44,
      );
    }
    // Padding and outline gaps keep 8 px on each side outside the cycle's
    // 48 px hit target. The floating labels must also remain fully visible.
    final cycleMinWidth = math.max(
      64.0,
      _floatingLabelWidth(context.l10n.resourcePeriod) + 16,
    );
    final amountMinWidth = math.max(
      48.0,
      _floatingLabelWidth(context.l10n.serverAmount) + 16,
    );
    // Include the compact dropdown's icon, padded hit target and outline
    // gaps, rounding up fractional text widths. The selected value, not the
    // longest menu item or free row space, determines the closed width.
    final cyclePreferredWidth = math.max(
      cycleMinWidth,
      (_textWidth(cycleLabels[cycle]!, valueStyle) + 44).ceilToDouble(),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: FormField<void>(
        validator: (_) => _validateField(
          'amount',
          amountLabel,
          fields['amount']!.text,
          required: true,
        ),
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Leave the amount label and a usable editor visible at
                // narrow widths. Longer cycle values can soft-wrap; their
                // complete meaning also remains in the menu and summary.
                final cycleWidth = math.max(
                  cycleMinWidth,
                  math.min(
                    cyclePreferredWidth,
                    constraints.maxWidth - currencyWidth - 12 - amountMinWidth,
                  ),
                );
                return Row(
                  key: const ValueKey('row-fees'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _compactInput(
                        'amount',
                        context.l10n.serverAmount,
                        amountLabel,
                        field.errorText,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: currencyWidth,
                      child: select<String>(
                        context.l10n.serverOriginalCurrency,
                        currency,
                        Money.currencies
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        (v) => setState(() => currency = v!),
                        id: 'currency',
                        compact: true,
                        shortLabel: context.l10n.serverCurrency,
                      ),
                    ),
                    if (billing == BillingKind.prepaid) ...[
                      const SizedBox(width: 6),
                      SizedBox(
                        width: cycleWidth,
                        child: _cycleSelect(cycleLabels),
                      ),
                    ],
                  ],
                );
              },
            ),
            if (field.errorText case final error?) _rowError(error),
            const SizedBox(height: 6),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: fields['amount']!,
              builder: (context, value, _) {
                final minor = Money.parseMinor(value.text);
                final amount = minor == null
                    ? ''
                    : '${Money(currency, minor).decimal} $currency · ';
                final period = billing == BillingKind.metered
                    ? context.l10n.serverMonthlyCostEstimate
                    : context.l10n.serverRenewalPriceHelp(
                        (cycle == 12
                                ? context.l10n.serverEveryYear
                                : context.l10n.serverEveryMonths(cycle))
                            .toString(),
                      );
                // Keep the complete amount readable even while a narrow
                // single-line editor scrolls its digits at larger text sizes.
                return Text(
                  '$amount$period',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Map<String, String> _dateErrors() {
    final errors = <String, String>{};
    for (final id in ['start', 'due']) {
      final error = _validateField(
        id,
        id == 'start'
            ? context.l10n.serverStartDate
            : context.l10n.serverDueDate,
        fields[id]!.text,
      );
      if (error != null) {
        errors[id] = error;
      }
    }
    return errors;
  }

  Widget _dateRow() => FormField<void>(
    validator: (_) => _dateErrors().values.firstOrNull,
    builder: (field) {
      final errors = field.hasError ? _dateErrors() : const <String, String>{};
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            key: const ValueKey('row-dates'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _compactInput(
                  'start',
                  context.l10n.serverStartDate,
                  context.l10n.serverOptionalStart,
                  errors['start'],
                  date: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _compactInput(
                  'due',
                  context.l10n.serverDueDate,
                  context.l10n.serverOptionalDue,
                  errors['due'],
                  date: true,
                ),
              ),
            ],
          ),
          for (final error in errors.entries)
            _rowError(
              error.value,
              label: error.key == 'start'
                  ? context.l10n.serverStartDate
                  : context.l10n.serverDueDate,
            ),
        ],
      );
    },
  );

  Future<void> chooseProvider() async {
    if (choosingProvider || saving || widget.record != null) return;
    setState(() => choosingProvider = true);
    try {
      final selected = await Navigator.push<ProviderSelection>(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderPickerPage(
            ledger: widget.controller,
            allowUnspecified: true,
          ),
        ),
      );
      if (mounted && selected != null) {
        setState(() => selectedProvider = selected.provider);
      }
    } finally {
      if (mounted) setState(() => choosingProvider = false);
    }
  }

  Future<void> save() async {
    if (saving ||
        !widget.controller.canMutate ||
        widget.controller.cloud.needsReload) {
      return;
    }
    _hasValidated = true;
    final invalid = _form.currentState!.validateGranularly();
    final resources = _resources.currentState?.validateAndRead(
      invalidFields: invalid,
    );
    if (invalid.isNotEmpty) {
      revealFirstInvalidField(invalid);
      return;
    }
    if (resources == null) {
      return;
    }
    final old = widget.record;
    final now = widget.controller.clock();
    String text(String key) => fields[key]!.text.trim();
    final s = ServerRecord(
      id: old?.id ?? newLocalId(),
      name: text('name'),
      // Legacy vendor text stays historical; providerId is current ownership.
      vendor: old?.vendor ?? selectedProvider?.name ?? '',
      providerId: old == null ? selectedProvider?.id : old.providerId,
      host: old == null && text('host').isEmpty
          ? (resources.ip.isNotEmpty ? resources.ip : resources.hostname)
          : text('host'),
      region: text('region'),
      purpose: text('purpose'),
      os: text('os'),
      spec: text('spec') == old?.resources?.specSummary
          ? resources.specSummary
          : text('spec'),
      notes: text('notes'),
      resources: resources,
      groupId: groupId,
      favorite: old?.favorite ?? false,
      billing: billing,
      currency: currency,
      amountMinor: billing == BillingKind.unknown
          ? null
          : Money.parseMinor(text('amount')),
      cycleMonths: cycle,
      startDate: billing == BillingKind.prepaid
          ? LedgerDate.tryParse(text('start'))
          : null,
      dueDate: billing == BillingKind.prepaid
          ? LedgerDate.tryParse(text('due'))
          : null,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
      revision: old?.revision ?? 0,
      isDemo: old?.isDemo ?? false,
      renewalAnchorDate: old?.renewalAnchorDate,
    );
    final error = s.validate(l10n: context.l10n);
    if (error != null) {
      showFailure(
        context,
        LocalizedArgumentError((l10n) => s.validate(l10n: l10n)!),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await widget.controller.mutate(
        () => widget.controller.store.saveServer(s, isNew: old == null),
      );
      if (mounted) {
        Navigator.pop(context, s.id);
      }
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        showFailure(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.record == null
                ? context.l10n.serverManualAdd
                : context.l10n.serverEditTitle,
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
          ],
        ),
        body: Form(
          key: _form,
          // This bounded form owns nested resource state. Keep every field
          // mounted so scrolling cannot discard edits or prevent validation.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoNote(context.l10n.serverFormHelp),
                SectionTitle(context.l10n.serverBasicData),
                field('name', context.l10n.serverName, required: true),
                LedgerCard(
                  padding: EdgeInsets.zero,
                  child: SettingRow(
                    key: const ValueKey('form-provider'),
                    icon: Icons.business_outlined,
                    title: widget.record == null
                        ? widget.controller.cloud.providers
                                  .where((p) => p.id == selectedProvider?.id)
                                  .firstOrNull
                                  ?.name ??
                              selectedProvider?.name ??
                              context.l10n.providerUiUnspecified
                        : serverProviderLabel(
                            context,
                            widget.controller,
                            widget.record!,
                          ),
                    subtitle: widget.record == null
                        ? context.l10n.providerUiChooseAnother
                        : context.l10n.providerUiChangeFromDetails,
                    onTap:
                        widget.record != null ||
                            saving ||
                            choosingProvider ||
                            !widget.controller.canMutate
                        ? null
                        : chooseProvider,
                  ),
                ),
                const SizedBox(height: 18),
                field(
                  'host',
                  context.l10n.serverOptionalHost,
                  hint: context.l10n.serverHostExample,
                  max: 253,
                ),
                InfoNote(
                  widget.record == null
                      ? context.l10n.serverNewHostHelp
                      : context.l10n.serverSavedHostHelp,
                ),
                select<String>(context.l10n.serverGroup, groupId ?? '', [
                  DropdownMenuItem(
                    value: '',
                    child: Builder(
                      builder: (context) => Text(context.l10n.ungrouped),
                    ),
                  ),
                  ...widget.controller.groups.map(
                    (g) => DropdownMenuItem(value: g.id, child: Text(g.name)),
                  ),
                ], (v) => setState(() => groupId = v == '' ? null : v)),
                field('purpose', context.l10n.serverOptionalPurpose),
                field('region', context.l10n.serverOptionalRegion),
                field('os', context.l10n.serverOptionalOs),
                field(
                  'spec',
                  context.l10n.serverOptionalSpec,
                  hint: context.l10n.serverSpecExample,
                  max: 200,
                ),
                ServerResourceFields(
                  key: _resources,
                  initial: widget.record?.resources,
                  enabled: !saving,
                  importing: false,
                  defaultTrafficPeriodMonths: widget.record == null ? 1 : null,
                ),
                SectionTitle(context.l10n.serverCostDetails),
                if (termsLocked) InfoNote(context.l10n.serverPaymentLockHelp),
                select<BillingKind>(
                  context.l10n.serverBillingType,
                  billing,
                  [
                    DropdownMenuItem(
                      value: BillingKind.unknown,
                      child: Builder(
                        builder: (context) =>
                            Text(context.l10n.serverCostUnknownOption),
                      ),
                    ),
                    DropdownMenuItem(
                      value: BillingKind.prepaid,
                      child: Builder(
                        builder: (context) =>
                            Text(context.l10n.serverPrepaidOption),
                      ),
                    ),
                    DropdownMenuItem(
                      value: BillingKind.metered,
                      child: Builder(
                        builder: (context) =>
                            Text(context.l10n.serverMeteredOption),
                      ),
                    ),
                  ],
                  (v) => setState(() => billing = v!),
                  id: 'billing',
                  selectedLabels: {
                    BillingKind.unknown: context.l10n.billingCostUnknown,
                    BillingKind.prepaid: context.l10n.serverPrepaid,
                    BillingKind.metered: context.l10n.serverMetered,
                  },
                ),
                if (billing != BillingKind.unknown) ...[
                  _feeRow(),
                  if (billing == BillingKind.prepaid) ...[
                    _dateRow(),
                    InfoNote(context.l10n.serverDatesHelp),
                  ],
                  InfoNote(context.l10n.serverAmountHelp),
                ],
                field(
                  'notes',
                  context.l10n.serverOptionalNotes,
                  max: 4000,
                  lines: 4,
                ),
                InfoNote(context.l10n.serverNotesSafety),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed:
                  saving ||
                      !widget.controller.canMutate ||
                      widget.controller.cloud.needsReload
                  ? null
                  : save,
              child: Text(
                saving ? context.l10n.saving : context.l10n.serverSave,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
