import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/generated/app_localizations_en.dart';
import '../l10n/generated/app_localizations_zh.dart';

import 'dart:math' as math;
import 'dart:ui' show SemanticsValidationResult;

import 'package:flutter/cupertino.dart'
    show
        CupertinoDatePicker,
        CupertinoDatePickerMode,
        CupertinoTextThemeData,
        CupertinoTheme,
        CupertinoThemeData;
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/form_feedback.dart';
import '../core/ui/ui.dart';
import '../core/value_types.dart';
import '../providers/provider_pickers.dart';
import '../providers/provider_record.dart';
import 'ledger_controller.dart';
import 'server_record.dart';
import 'server_resource_fields.dart';
import 'server_resources.dart';

class ServerForm extends StatefulWidget {
  const ServerForm({
    super.key,
    required this.controller,
    this.record,
    this.template,
    this.businessProvider,
    this.catalogProvider,
    this.focusHardware = false,
  });
  final LedgerController controller;
  final ServerRecord? record;

  /// Prefill for a NEW server (see `duplicateServerTemplate`). Only the fields
  /// carried by the template are shown; the form still creates a new record
  /// with a new id, and nothing is written before Save.
  final ServerRecord? template;

  /// Preselected provider for a new server (an existing local provider)...
  final ProviderRecord? businessProvider;

  /// ...or a catalog provider whose local provider is created on save.
  final CatalogProviderRef? catalogProvider;

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
  late final Map<String, TextEditingController> fields;
  late BillingKind billing;
  late String currency;
  late int cycle;
  String? groupId;
  ProviderRecord? selectedProvider;

  /// Catalog provider without a local provider yet (created on save).
  CatalogProviderRef? pendingCatalog;

  /// Provider named in the "New Provider…" prompt; written on save only, so
  /// leaving the form never leaves a provider behind.
  ProviderRecord? pendingNew;
  bool saving = false;

  /// True while the due date is the value derived from start date + cycle (or
  /// still empty). A manual change of the due date turns it off, so later
  /// start/cycle edits never overwrite what the user typed.
  late bool _dueAuto;
  bool get termsLocked =>
      widget.record != null &&
      widget.controller.hasPaymentPeriods(widget.record!.id);
  @override
  void initState() {
    super.initState();
    assert(widget.record == null || widget.template == null);
    final s = widget.record ?? widget.template;
    selectedProvider =
        widget.businessProvider ??
        (s == null ? null : widget.controller.providerFor(s));
    if (selectedProvider == null) pendingCatalog = widget.catalogProvider;
    fields = {
      'name': TextEditingController(text: s?.name),
      'region': TextEditingController(text: s?.region),
      'purpose': TextEditingController(text: s?.purpose),
      'os': TextEditingController(text: s?.os),
      'notes': TextEditingController(text: s?.notes),
      'amount': TextEditingController(text: s?.money?.decimal),
      'start': TextEditingController(text: s?.startDate?.toString()),
      'due': TextEditingController(text: s?.dueDate?.toString()),
    };
    billing = s?.billing ?? BillingKind.unknown;
    currency = s?.currency ?? 'USD';
    cycle = s?.cycleMonths ?? 12;
    groupId = s?.groupId;
    final start = s?.startDate, due = s?.dueDate;
    _dueAuto = due == null || (start != null && start.addMonths(cycle) == due);
    _legacyHost = LegacyHost.of(s?.host ?? '');
    _initialResources = _legacyHost?.prefill(s?.resources) ?? s?.resources;
    _hostCarried = _legacyHost?.isStoredIn(_initialResources) ?? false;
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

  /// An older record's `host` value, prefilled into the address field it
  /// belongs to so that it is visible and moves there on save.
  late final LegacyHost? _legacyHost;
  late final ServerResources? _initialResources;

  /// The legacy value is stored in its address field as the form opens.
  late final bool _hostCarried;

  @override
  void dispose() {
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
    return null;
  }

  // ---- grouped form rows -------------------------------------------------

  Widget _semantic(String label, String? error, Widget child) => Semantics(
    label: label,
    hint: error,
    validationResult: error == null
        ? SemanticsValidationResult.valid
        : SemanticsValidationResult.invalid,
    child: child,
  );

  Widget _textRow(
    String id,
    String label, {
    required String semanticLabel,
    String? hint,
    bool required = false,
    int max = 80,
  }) => FormField<void>(
    validator: (_) =>
        _validateField(id, label, fields[id]!.text, required: required),
    builder: (state) => AppFormRow(
      label: label,
      required: required,
      errorText: state.errorText,
      child: _semantic(
        semanticLabel,
        state.errorText,
        AppTextField(
          key: ValueKey('field-$id'),
          controller: fields[id],
          enabled: !saving,
          maxLength: max,
          hint: hint ?? context.l10n.uiFormOptional,
          label: semanticLabel,
          textAlign: TextAlign.end,
          textInputAction: TextInputAction.next,
        ),
      ),
    ),
  );

  void _explainLock() => showAppToast(
    context,
    context.l10n.serverPaymentLockHelp,
    duration: const Duration(seconds: 6),
  );

  String _cycleDescription(int months, AppLocalizations l10n) =>
      months == 12 ? l10n.serverEveryYear : l10n.serverEveryMonths(months);

  Future<void> _pickGroup() async {
    final result = await showFormPicker<String>(
      context,
      title: context.l10n.serverGroup,
      selected: groupId ?? '',
      options: (l10n) => [
        AppPickerOption(value: '', title: l10n.ungrouped),
        for (final group in widget.controller.groups)
          AppPickerOption(value: group.id, title: group.name),
      ],
    );
    if (result != null && mounted) {
      setState(() => groupId = result == '' ? null : result);
    }
  }

  Future<void> _pickCurrency() async {
    final result = await showFormPicker<String>(
      context,
      title: context.l10n.serverOriginalCurrency,
      selected: currency,
      options: (_) => [
        for (final code in Money.currencies)
          AppPickerOption(value: code, title: code),
      ],
    );
    if (result != null && mounted) setState(() => currency = result);
  }

  Future<void> _pickCycle() async {
    final months = {1, 3, 6, 12, 24, 36, cycle}.toList()..sort();
    final result = await showFormPicker<int>(
      context,
      title: context.l10n.serverRenewalCycle,
      selected: cycle,
      options: (l10n) => [
        for (final m in months)
          AppPickerOption(value: m, title: _cycleDescription(m, l10n)),
      ],
    );
    if (result != null && mounted) {
      setState(() {
        cycle = result;
        _autoDue();
      });
    }
  }

  /// Due = start + cycle with the renewal month-anchor rules (`addMonths`
  /// clamps month ends and leap days from the original start day).
  void _autoDue() {
    final start = LedgerDate.tryParse(fields['start']!.text.trim());
    if (start == null || !_dueAuto) return;
    fields['due']!.text = start.addMonths(cycle).toString();
  }

  Future<void> _pickDate(String id, String label) async {
    final current = LedgerDate.tryParse(fields[id]!.text.trim());
    final start = LedgerDate.tryParse(fields['start']!.text.trim());
    final today = LedgerDate.today(widget.controller.clock());
    final suggestion = id == 'due' && start != null
        ? start.addMonths(cycle)
        : today;
    final result = await showAppSheet<String>(
      context,
      title: label,
      builder: (_) => _DateSheet(initial: current ?? suggestion),
    );
    if (result != null && mounted) {
      setState(() {
        fields[id]!.text = result;
        if (id == 'start') {
          // An emptied due date counts as "not set by the user".
          if (fields['due']!.text.isEmpty) _dueAuto = true;
          _autoDue();
        } else if (id == 'due') {
          final start = LedgerDate.tryParse(fields['start']!.text.trim());
          _dueAuto =
              result.isEmpty ||
              (start != null && start.addMonths(cycle).toString() == result);
        }
      });
    }
  }

  Widget _billingRow() {
    final l10n = context.l10n;
    final labels = {
      BillingKind.prepaid: l10n.uiFormBillingPrepaid,
      BillingKind.metered: l10n.uiFormBillingMetered,
      BillingKind.unknown: l10n.serverUnknown,
    };
    return LayoutBuilder(
      builder: (context, box) {
        final inner = box.maxWidth - 32;
        final segment = compactSegmentWidth(context, labels.values);
        final label = l10n.serverBillingType;
        final labelWidth = math.min(
          measureFormText(context, label, 16).ceilToDouble() + 1,
          inner * .45,
        );
        final inline = inner - labelWidth - 12 >= segment;
        final segmented = AppSegmented<BillingKind>(
          key: const ValueKey('field-billing'),
          compact: true,
          options: labels,
          value: billing,
          onChanged: (kind) => setState(() => billing = kind),
        );
        Widget control = Semantics(
          label: '$label ${labels[billing]}',
          child: segmented,
        );
        if (saving || termsLocked) {
          // The segmented control has no disabled state: absorb taps and, for
          // paid history, explain why the billing type cannot change.
          control = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: termsLocked && !saving ? _explainLock : null,
            child: Opacity(opacity: .45, child: IgnorePointer(child: control)),
          );
        }
        return AppFormRow(
          key: const ValueKey('row-billing'),
          label: label,
          stacked: !inline,
          child: inline
              ? control
              : Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 6),
                    child: FittedBox(fit: BoxFit.scaleDown, child: control),
                  ),
                ),
        );
      },
    );
  }

  Widget _currencyButton() {
    final l10n = context.l10n;
    final p = context.palette;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${l10n.serverOriginalCurrency} $currency',
      onTap: saving ? null : _pickCurrency,
      child: InkWell(
        key: const ValueKey('field-currency'),
        onTap: saving ? null : _pickCurrency,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  currency,
                  style: TextStyle(
                    fontSize: 16,
                    color: p.text,
                    fontFeatures: kTabularFigures,
                  ),
                ),
                Icon(Icons.expand_more_rounded, size: 18, color: p.text3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _amountRow(String amountLabel) {
    return FormField<void>(
      validator: (_) => _validateField(
        'amount',
        amountLabel,
        fields['amount']!.text,
        required: true,
      ),
      builder: (state) => LayoutBuilder(
        builder: (context, box) {
          // Label, a usable amount editor and the widest currency code must
          // share one line; otherwise the label moves above the editor.
          final inner = box.maxWidth - 32;
          var codeWidth = 0.0;
          for (final code in Money.currencies) {
            codeWidth = math.max(
              codeWidth,
              measureFormText(context, code, 16).ceilToDouble(),
            );
          }
          final currencyWidth = math.max(44.0, codeWidth + 12 + 18);
          final labelWidth = math.min(
            measureFormText(context, amountLabel, 16).ceilToDouble() + 1,
            inner * .45,
          );
          final inline = inner - labelWidth - 12 - 4 - currencyWidth >= 72;
          return AppFormRow(
            key: const ValueKey('row-fees'),
            label: amountLabel,
            stacked: !inline,
            errorText: state.errorText,
            child: Row(
              children: [
                Expanded(
                  child: _semantic(
                    amountLabel,
                    state.errorText,
                    AppTextField(
                      key: const ValueKey('field-amount'),
                      controller: fields['amount'],
                      enabled: !saving,
                      maxLength: 13,
                      hint: '0.00',
                      label: amountLabel,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      textAlign: inline ? TextAlign.end : TextAlign.start,
                      style: const TextStyle(fontFeatures: kTabularFigures),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _currencyButton(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _cycleRow() {
    final l10n = context.l10n;
    final onTap = saving ? null : (termsLocked ? _explainLock : _pickCycle);
    return Semantics(
      key: const ValueKey('field-cycle'),
      button: true,
      enabled: !termsLocked && !saving,
      excludeSemantics: true,
      label: '${l10n.serverRenewalCycle} ${_cycleDescription(cycle, l10n)}',
      onTap: onTap,
      child: Opacity(
        opacity: termsLocked || saving ? .45 : 1,
        child: AppFormRow.pick(
          label: l10n.serverRenewalCycle,
          value: _cycleDescription(cycle, l10n),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _dateRow(String id, String label, String semanticLabel) =>
      FormField<void>(
        validator: (_) => _validateField(id, label, fields[id]!.text),
        builder: (state) {
          final p = context.palette;
          final text = fields[id]!.text.trim();
          final locked = termsLocked;
          return _semantic(
            semanticLabel,
            state.errorText,
            AppFormRow(
              key: ValueKey('field-$id'),
              label: label,
              errorText: state.errorText,
              onTap: saving
                  ? null
                  : locked
                  ? _explainLock
                  : () => _pickDate(id, label),
              child: Opacity(
                opacity: locked || saving ? .45 : 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      // Never wrap an ISO date: shrink it instead.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(
                          text.isEmpty ? context.l10n.serverUnknown : text,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 16,
                            color: text.isEmpty ? p.text3 : p.text,
                            fontFeatures: kTabularFigures,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: p.text2,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

  Widget _costFootnote(String amountLabel) {
    final l10n = context.l10n;
    final style = context.footnoteStyle;
    final notes = <Widget>[
      if (termsLocked) Text(l10n.serverPaymentLockHelp, style: style),
      if (billing == BillingKind.unknown)
        Text(l10n.uiFormUnknownCostFootnote, style: style)
      else ...[
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: fields['amount']!,
          builder: (context, value, _) {
            final minor = Money.parseMinor(value.text);
            final amount = minor == null
                ? ''
                : '${Money(currency, minor).decimal} $currency · ';
            final period = billing == BillingKind.metered
                ? l10n.serverMonthlyCostEstimate
                : l10n.serverRenewalPriceHelp(
                    _cycleDescription(cycle, l10n).toString(),
                  );
            // Keep the complete amount readable even while a narrow
            // single-line editor scrolls its digits at larger text sizes.
            return Text('$amount$period', style: style);
          },
        ),
        if (billing == BillingKind.prepaid)
          Text(l10n.serverDatesHelp, style: style),
        Text(l10n.serverAmountHelp, style: style),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < notes.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          notes[i],
        ],
      ],
    );
  }

  // ---- provider picker ---------------------------------------------------

  bool _picking = false;

  Future<void> _pickProvider() async {
    if (saving || _picking || !widget.controller.canMutate) return;
    _picking = true;
    try {
      final choice = await pickProvider(
        context,
        ledger: widget.controller,
        selected: selectedProvider,
        pendingCatalog: pendingCatalog,
        pendingNew: pendingNew,
      );
      if (choice != null && mounted) _applyProvider(choice);
    } finally {
      _picking = false;
    }
  }

  void _applyProvider(ProviderChoice choice) {
    final local = choice.local, catalog = choice.catalog, draft = choice.draft;
    setState(() {
      selectedProvider = local;
      pendingCatalog = catalog;
      pendingNew = draft;
    });
  }

  /// Whether [spec] is something this app generated for the record's stored
  /// hardware (current short form or the older long forms in either language).
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

  /// A legacy `host` moves into its address field once it is stored there
  /// (the user may have changed the prefilled value, but not blanked it);
  /// otherwise it stays untouched so nothing is ever lost.
  String _hostAfterSave(ServerRecord? old, ServerResources resources) {
    final host = old?.host ?? '';
    final legacy = _legacyHost;
    if (legacy == null || !_hostCarried) return host;
    return legacy.fieldValue(resources).isEmpty ? host : '';
  }

  Future<void> save() async {
    if (saving || !widget.controller.canMutate) return;
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
    final l10n = context.l10n;
    // The specification is generated from the hardware. Free text written by
    // an older version is never dropped: with known hardware it moves to the
    // notes, without hardware it stays as the specification.
    final generated = resources.specSummaryFor(l10n);
    final legacy = old?.spec.trim() ?? '';
    final legacyIsCustom = legacy.isNotEmpty && !_isAutoSpec(old!, legacy);
    var notes = text('notes');
    if (generated.isNotEmpty && legacyIsCustom && !notes.contains(legacy)) {
      notes = notes.isEmpty
          ? '${l10n.serverSpecifications}: $legacy'
          : '$notes\n${l10n.serverSpecifications}: $legacy';
    }
    final s = ServerRecord(
      id: old?.id ?? newLocalId(),
      name: text('name'),
      // Legacy vendor text stays historical; providerId is current ownership.
      vendor:
          old?.vendor ??
          selectedProvider?.name ??
          pendingCatalog?.name ??
          pendingNew?.name ??
          widget.template?.vendor ??
          '',
      providerId: selectedProvider?.id,
      host: _hostAfterSave(old, resources),
      region: text('region'),
      purpose: text('purpose'),
      os: text('os'),
      spec: generated.isNotEmpty ? generated : legacy,
      notes: notes,
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
        () => widget.controller.store.saveServer(
          s,
          isNew: old == null,
          catalogProvider: selectedProvider == null ? pendingCatalog : null,
          newProvider: selectedProvider == null ? pendingNew : null,
        ),
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canSave = !saving && widget.controller.canMutate;
    final amountLabel = billing == BillingKind.metered
        ? l10n.serverMonthlyEstimate
        : l10n.serverRenewalAmount;
    final providerName =
        widget.controller.providers
            .where((p) => p.id == selectedProvider?.id)
            .firstOrNull
            ?.name ??
        selectedProvider?.name ??
        pendingCatalog?.name ??
        pendingNew?.name;
    final canChooseProvider = !saving && widget.controller.canMutate;
    final groupName =
        widget.controller.groups
            .where((g) => g.id == groupId)
            .firstOrNull
            ?.name ??
        l10n.ungrouped;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => PopScope(
        canPop: !saving,
        child: AppScaffold.modal(
          title: widget.record == null ? l10n.serverAdd : l10n.serverEditTitle,
          actionLabel: l10n.save,
          onAction: canSave ? save : null,
          actionBusy: saving,
          slivers: [
            // One non-lazy child keeps every field mounted, so scrolling can
            // neither discard edits nor prevent validation of off-screen rows.
            SliverToBoxAdapter(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSection(
                      header: l10n.serverBasicData,
                      topSpacing: 8,
                      children: [
                        _textRow(
                          'name',
                          l10n.serverName,
                          semanticLabel: l10n.serverName,
                          hint: l10n.uiFormNameHint,
                          required: true,
                        ),
                        AppFormRow.pick(
                          key: const ValueKey('form-provider'),
                          label: l10n.uiFormProvider,
                          value: providerName,
                          placeholder: l10n.r7FormProviderNone,
                          onTap: canChooseProvider ? _pickProvider : null,
                        ),
                        AppFormRow.pick(
                          key: const ValueKey('field-group'),
                          label: l10n.serverGroup,
                          value: groupName,
                          onTap: saving ? null : _pickGroup,
                        ),
                        _textRow(
                          'purpose',
                          l10n.uiFormPurpose,
                          semanticLabel: l10n.serverOptionalPurpose,
                        ),
                        _textRow(
                          'region',
                          l10n.uiFormRegion,
                          semanticLabel: l10n.serverOptionalRegion,
                        ),
                        _textRow(
                          'os',
                          l10n.serverOperatingSystem,
                          semanticLabel: l10n.serverOptionalOs,
                        ),
                      ],
                    ),
                    ServerResourceFields(
                      key: _resources,
                      initial: _initialResources,
                      enabled: !saving,
                      collapsible: true,
                      defaultTrafficPeriodMonths: widget.record == null
                          ? 1
                          : null,
                    ),
                    AppSection(
                      header: l10n.serverCostDetails,
                      footerWidget: _costFootnote(amountLabel),
                      children: [
                        _billingRow(),
                        if (billing != BillingKind.unknown)
                          _amountRow(amountLabel),
                        if (billing == BillingKind.prepaid) ...[
                          _cycleRow(),
                          _dateRow(
                            'start',
                            l10n.serverStartDate,
                            l10n.serverOptionalStart,
                          ),
                          _dateRow(
                            'due',
                            l10n.serverDueDate,
                            l10n.serverOptionalDue,
                          ),
                        ],
                      ],
                    ),
                    AppSection(
                      header: l10n.serverNotes,
                      footer: l10n.serverNotesSafety,
                      children: [
                        AppRow.custom(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: AppTextField(
                              key: const ValueKey('field-notes'),
                              controller: fields['notes'],
                              enabled: !saving,
                              maxLength: 4000,
                              minLines: 3,
                              maxLines: 8,
                              hint: l10n.uiFormOptional,
                              label: l10n.serverOptionalNotes,
                              textAlign: TextAlign.start,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Date wheel in a sheet. Pops an ISO date, or `''` for "set unknown"; closing
/// the sheet any other way leaves the draft unchanged.
class _DateSheet extends StatefulWidget {
  const _DateSheet({required this.initial});
  final LedgerDate initial;
  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _value = DateTime(
    widget.initial.year,
    widget.initial.month,
    widget.initial.day,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 216,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: p.isDark ? Brightness.dark : Brightness.light,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: TextStyle(fontSize: 21, color: p.text),
              ),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _value,
              minimumYear: 1,
              maximumYear: 9999,
              onDateTimeChanged: (value) => _value = value,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  key: const ValueKey('date-sheet-unknown'),
                  label: l10n.uiFormSetUnknown,
                  kind: AppButtonKind.tonal,
                  onPressed: () => Navigator.pop(context, ''),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  key: const ValueKey('date-sheet-done'),
                  label: l10n.uiFormDone,
                  onPressed: () => Navigator.pop(
                    context,
                    LedgerDate(
                      _value.year,
                      _value.month,
                      _value.day,
                    ).toString(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
