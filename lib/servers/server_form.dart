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
import '../providers/package_widgets.dart';
import '../providers/provider_catalog.dart';
import '../providers/provider_pages.dart';
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
    this.businessProvider,
    this.catalogProvider,
    this.initialPackage,
    this.focusHardware = false,
  });
  final LedgerController controller;
  final ServerRecord? record;

  /// Preselected provider for a new server (an existing local provider)...
  final ProviderRecord? businessProvider;

  /// ...or a catalog provider whose local provider is created on save.
  final CatalogProvider? catalogProvider;

  /// Package chosen in the add flow: pre-fills hardware and price.
  final CatalogPackage? initialPackage;
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
  CatalogProvider? pendingCatalog;

  /// Provider named in the "New Provider…" prompt; written on save only, so
  /// leaving the form never leaves a provider behind.
  ProviderRecord? pendingNew;

  /// The chosen package (as it will be saved) and, for an existing server,
  /// the one it had when the form opened.
  CatalogPackage? package;
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
    // The package rows depend on the catalog; this build method reads it
    // outside the controller's ListenableBuilder, so rebuild explicitly.
    widget.controller.loadCatalog().then((_) {
      if (mounted) setState(() {});
    });
    final s = widget.record;
    selectedProvider =
        widget.businessProvider ??
        (s == null ? null : widget.controller.providerFor(s));
    if (selectedProvider == null) pendingCatalog = widget.catalogProvider;
    // A new server of a catalog provider starts with its default package.
    final prefill = s != null
        ? null
        : widget.initialPackage ??
              _catalogOf(selectedProvider, pendingCatalog)?.defaultPackage;
    _seedPackage = prefill;
    package = s == null ? prefill : widget.controller.packageSnapshotFor(s);
    fields = {
      'name': TextEditingController(text: s?.name),
      'region': TextEditingController(text: s?.region ?? prefill?.region),
      'purpose': TextEditingController(text: s?.purpose),
      'os': TextEditingController(text: s?.os),
      'notes': TextEditingController(text: s?.notes),
      'amount': TextEditingController(
        text: s?.money?.decimal ?? prefill?.price?.money.decimal,
      ),
      'start': TextEditingController(text: s?.startDate?.toString()),
      'due': TextEditingController(text: s?.dueDate?.toString()),
    };
    billing =
        s?.billing ??
        (prefill?.price != null ? BillingKind.prepaid : BillingKind.unknown);
    currency = s?.currency ?? prefill?.price?.currency ?? 'USD';
    cycle = s?.cycleMonths ?? prefill?.price?.cycleMonths ?? 12;
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

  /// Package whose hardware and price the new form opened with.
  late final CatalogPackage? _seedPackage;

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

  /// Catalog entry behind a (local or pending) provider choice.
  CatalogProvider? _catalogOf(ProviderRecord? local, CatalogProvider? pending) {
    final id = local?.catalogId ?? pending?.id;
    return id == null ? null : widget.controller.catalog.provider(id);
  }

  /// The catalog provider of the current selection, if any.
  CatalogProvider? get _catalogOfSelection =>
      _catalogOf(selectedProvider, pendingCatalog);

  /// Fills hardware and price from [chosen]; addresses and dates stay.
  void _applyPackage(CatalogPackage chosen) {
    _resources.currentState?.applyResources(chosen.resources);
    final price = chosen.price;
    if (price != null) {
      billing = BillingKind.prepaid;
      currency = price.currency;
      cycle = price.cycleMonths;
      fields['amount']!.text = price.money.decimal;
      _autoDue();
    }
    if (fields['region']!.text.trim().isEmpty && chosen.region.isNotEmpty) {
      fields['region']!.text = chosen.region;
    }
  }

  Future<bool> _confirmReplace() => showAppConfirm(
    context,
    title: LocalizedText((l10n) => l10n.r6CatReplaceTitle),
    message: LocalizedText((l10n) => l10n.r6CatReplaceMessage),
    action: LocalizedText((l10n) => l10n.r6CatReplaceAction),
  );

  // ---- provider and package dropdowns ------------------------------------

  static const _noneKey = 'none', _newKey = 'new', _draftKey = 'draft';
  String get _providerKey => selectedProvider != null
      ? 'local:${selectedProvider!.id}'
      : pendingCatalog != null
      ? 'catalog:${pendingCatalog!.id}'
      : pendingNew != null
      ? _draftKey
      : _noneKey;

  List<AppDropdownGroup<String>> _providerGroups(AppLocalizations l10n) {
    final controller = widget.controller;
    String? packages(ProviderRecord provider) {
      final count = controller.catalogProviderFor(provider)?.packages.length;
      return count == null || count == 0 ? null : l10n.r6CatPackageCount(count);
    }

    final added = {for (final p in controller.providers) ?p.catalogId};
    final mine = [
      if (pendingNew != null)
        AppDropdownItem(
          key: const ValueKey('form-provider-draft'),
          value: _draftKey,
          title: pendingNew!.name,
        ),
      for (final provider in controller.providers)
        AppDropdownItem(
          key: ValueKey('form-provider-${provider.id}'),
          value: 'local:${provider.id}',
          title: provider.name,
          subtitle: packages(provider),
        ),
    ];
    final catalog = [
      for (final provider in controller.catalog.providers)
        if (!added.contains(provider.id))
          AppDropdownItem(
            key: ValueKey('form-provider-catalog-${provider.id}'),
            value: 'catalog:${provider.id}',
            title: provider.name,
            subtitle: provider.packages.isEmpty
                ? null
                : l10n.r6CatPackageCount(provider.packages.length),
          ),
    ];
    return [
      AppDropdownGroup(
        items: [
          AppDropdownItem(
            key: const ValueKey('form-provider-none'),
            value: _noneKey,
            title: l10n.r7FormProviderNone,
          ),
        ],
      ),
      AppDropdownGroup(header: l10n.r6CatMineSection, items: mine),
      AppDropdownGroup(header: l10n.r6CatCatalogSection, items: catalog),
      AppDropdownGroup(
        items: [
          AppDropdownItem(
            key: const ValueKey('form-provider-new'),
            value: _newKey,
            title: l10n.r7FormProviderNew,
          ),
        ],
      ),
    ];
  }

  Future<void> _chooseProvider(String key) async {
    if (saving || key == _providerKey || key == _draftKey) return;
    final controller = widget.controller;
    ProviderRecord? local;
    CatalogProvider? catalog;
    ProviderRecord? draft;
    if (key == _newKey) {
      draft = await draftProvider(context, controller);
      if (draft == null || !mounted) return;
    } else if (key.startsWith('local:')) {
      local = controller.providers
          .where((p) => 'local:${p.id}' == key)
          .firstOrNull;
      if (local == null) return;
    } else if (key.startsWith('catalog:')) {
      catalog = controller.catalog.provider(key.substring(8));
      if (catalog == null) return;
    }
    final target = _catalogOf(local, catalog);
    final hadPackage = package != null;
    setState(() {
      selectedProvider = local;
      pendingCatalog = catalog;
      pendingNew = draft;
      // A package belongs to its own catalog provider.
      if (package != null && package!.providerId != target?.id) package = null;
    });
    // Only a new server starts from the provider's default package; an
    // existing one keeps its values until a package is picked explicitly.
    final fallback = target?.defaultPackage;
    if (widget.record != null || package != null || fallback == null) return;
    final manual =
        !hadPackage &&
        (_resources.currentState?.hasHardwareInput == true ||
            billing != BillingKind.unknown ||
            fields['amount']!.text.trim().isNotEmpty);
    if (manual && !await _confirmReplace()) return;
    if (!mounted) return;
    setState(() {
      package = fallback;
      _applyPackage(fallback);
    });
  }

  List<AppDropdownGroup<String>> _packageGroups(
    AppLocalizations l10n,
    CatalogProvider? catalog,
  ) => [
    AppDropdownGroup(
      items: [
        AppDropdownItem(
          key: const ValueKey('form-package-none'),
          value: '',
          title: l10n.r6CatNoPackage,
        ),
        for (final option in catalog?.packages ?? const <CatalogPackage>[])
          AppDropdownItem(
            key: ValueKey('form-package-${option.id}'),
            value: option.id,
            title: option.name,
            subtitle: packageSummaryLine(l10n, option),
          ),
      ],
    ),
  ];

  Future<void> _choosePackage(String id) async {
    final catalog = _catalogOfSelection;
    if (saving || id == (package?.id ?? '')) return;
    final chosen = catalog?.package(id);
    if (chosen == null) {
      setState(() => package = null);
      return;
    }
    if (widget.record != null && !await _confirmReplace()) return;
    if (!mounted) return;
    setState(() {
      package = chosen;
      _applyPackage(chosen);
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
          '',
      providerId: selectedProvider?.id,
      packageId: package?.id,
      packageSnapshot: package?.encodeSnapshot(),
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
          catalogProvider: selectedProvider == null && pendingCatalog != null
              ? CatalogProviderRef(
                  catalogId: pendingCatalog!.id,
                  name: pendingCatalog!.name,
                )
              : null,
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
    final catalog = _catalogOfSelection;
    final packageList = catalog?.packages ?? const <CatalogPackage>[];
    // Also shown for a saved package whose catalog entry is gone, so that it
    // can still be cleared.
    final showPackage = packageList.isNotEmpty || package != null;
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
                      footer: showPackage ? l10n.r6CatFormPackageFooter : null,
                      children: [
                        _textRow(
                          'name',
                          l10n.serverName,
                          semanticLabel: l10n.serverName,
                          hint: l10n.uiFormNameHint,
                          required: true,
                        ),
                        AppDropdownRow<String>(
                          key: const ValueKey('form-provider'),
                          label: l10n.uiFormProvider,
                          value: providerName,
                          placeholder: l10n.r7FormProviderNone,
                          selected: _providerKey,
                          enabled: canChooseProvider,
                          groups: _providerGroups(l10n),
                          onSelected: _chooseProvider,
                        ),
                        if (showPackage)
                          AppDropdownRow<String>(
                            key: const ValueKey('form-package'),
                            label: l10n.r6CatFormPackage,
                            value: package?.name,
                            placeholder: l10n.r6CatNoPackage,
                            selected: package?.id ?? '',
                            enabled: !saving,
                            groups: _packageGroups(l10n, catalog),
                            onSelected: _choosePackage,
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
                      initial: _initialResources ?? _seedPackage?.resources,
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
