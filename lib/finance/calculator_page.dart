import 'package:flutter/material.dart';

import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../core/app_theme.dart' show showFailure;
import '../core/ui/ui.dart';
import '../core/value_types.dart';
import '../servers/ledger_controller.dart';
import '../servers/server_record.dart';
import 'finance_math.dart';
import 'finance_models.dart';
import 'calculation_result_page.dart';
import 'finance_widgets.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key, required this.controller, this.server});
  final LedgerController controller;
  final ServerRecord? server;
  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage>
    with LocaleRevalidatingForm<CalculatorPage> {
  late final TextEditingController price, start, asOf, due;
  late String currency;
  late int cycle;

  /// True while the due date is derived from start + cycle; a different due
  /// date picked by the user turns it off until they pick the derived date
  /// again or clear it.
  late bool dueAuto;
  List<ServicePeriod>? referencedPeriods;
  String? sourceName;
  bool rebuilt = false;
  @override
  void initState() {
    super.initState();
    price = TextEditingController();
    start = TextEditingController(text: widget.controller.today.toString());
    asOf = TextEditingController(text: widget.controller.today.toString());
    due = TextEditingController(
      text: widget.controller.today.addMonths(12).toString(),
    );
    currency = 'USD';
    cycle = 12;
    dueAuto = true;
    if (widget.server != null) reference(widget.server!);
  }

  void reference(ServerRecord s) {
    price.text = s.money?.decimal ?? '';
    start.text = s.startDate?.toString() ?? '';
    due.text = s.dueDate?.toString() ?? '';
    currency = s.currency;
    cycle = s.cycleMonths;
    // A server renewed more than once has a due date beyond start + cycle;
    // that one stays as it is unless the user clears it.
    final from = s.startDate;
    dueAuto =
        s.dueDate == null ||
        (from != null && from.addMonths(cycle) == s.dueDate);
    referencedPeriods = List.unmodifiable(widget.controller.periodsFor(s.id));
    sourceName = s.name;
    rebuilt = false;
  }

  @override
  void dispose() {
    price.dispose();
    start.dispose();
    asOf.dispose();
    due.dispose();
    super.dispose();
  }

  Future<void> chooseReference() async {
    final s = await showAppSheet<ServerRecord>(
      context,
      title: context.l10n.financeReferenceTitle,
      builder: (context) {
        final prepaid = widget.controller.active
            .where((s) => s.billing == BillingKind.prepaid)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSection(
              topSpacing: 0,
              footer: context.l10n.financeReferenceNote,
              children: [
                if (prepaid.isEmpty)
                  AppRow(title: context.l10n.financeNoPrepaid),
                for (final s in prepaid)
                  AppRow(
                    key: ValueKey('calc-reference-${s.id}'),
                    title: s.name,
                    subtitle: context.l10n.financeReferenceServerSubtitle(
                      s.billingLabelFor(context.l10n),
                      s.dueDate?.toString() ?? context.l10n.financeUnknown,
                    ),
                    onTap: () => Navigator.pop(context, s),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
    if (s != null && mounted) setState(() => reference(s));
  }

  Future<void> chooseCycle() async {
    final picked = await showAppPicker<int>(
      context,
      title: context.l10n.financeCycle,
      selected: cycle,
      options: [
        for (final c in [1, 3, 6, 12, 24, 36])
          AppPickerOption(
            key: ValueKey('calc-cycle-option-$c'),
            value: c,
            title: context.l10n.financeEveryMonths(c),
          ),
      ],
    );
    if (picked != null && picked != cycle && mounted) {
      setState(() {
        cycle = picked;
        dropReference();
        applyAutoDue();
      });
    }
  }

  /// Known periods no longer match the inputs: switch to the independent
  /// estimate. Call inside `setState`.
  void dropReference() {
    if (referencedPeriods != null) {
      referencedPeriods = null;
      rebuilt = true;
    }
  }

  /// Due = start + cycle with the renewal month-anchor rules (`addMonths`
  /// clamps month ends and leap days from the original start day). Returns
  /// whether the due date changed. Call inside `setState`.
  bool applyAutoDue() {
    final from = LedgerDate.tryParse(start.text.trim());
    if (from == null || !dueAuto) return false;
    final derived = from.addMonths(cycle).toString();
    if (due.text == derived) return false;
    due.text = derived;
    dropReference();
    return true;
  }

  Future<void> pickDate(
    TextEditingController target,
    String title,
    LedgerDate fallback,
    void Function(String result) apply, {
    bool allowUnknown = true,
  }) async {
    final result = await showAppDateSheet(
      context,
      title: title,
      initial: LedgerDate.tryParse(target.text.trim()) ?? fallback,
      allowUnknown: allowUnknown,
    );
    if (result == null || !mounted) return;
    setState(() => apply(result));
    // Clear a shown error once the field has a valid date.
    if (validationAttempted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) formKey.currentState?.validate();
      });
    }
  }

  void pickStart(String title) =>
      pickDate(start, title, widget.controller.today, (result) {
        start.text = result;
        // An emptied due date counts as "not set by the user".
        if (due.text.isEmpty) dueAuto = true;
        applyAutoDue();
      });

  void pickDue(String title) {
    final from = LedgerDate.tryParse(start.text.trim());
    pickDate(due, title, from?.addMonths(cycle) ?? widget.controller.today, (
      result,
    ) {
      if (result != due.text) dropReference();
      due.text = result;
      dueAuto =
          result.isEmpty ||
          (from != null && from.addMonths(cycle).toString() == result);
    });
  }

  void calculate() {
    if (!validateForm()) return;
    final estimateDate = LedgerDate.tryParse(asOf.text.trim())!;
    final end = LedgerDate.tryParse(due.text.trim())!;
    if (estimateDate.daysUntil(end).abs() > 36600) {
      showFailure(
        context,
        LocalizedArgumentError((l10n) => l10n.financeDateRangeError),
      );
      return;
    }
    try {
      final periods =
          referencedPeriods ?? calculatorPeriods(estimateDate, end, cycle);
      final money = Money(currency, Money.parseMinor(price.text)!);
      final value = valueOfPeriods(
        renewal: money,
        periods: periods,
        asOf: estimateDate,
      );
      if (value == null) {
        showFailure(
          context,
          LocalizedArgumentError((l10n) => l10n.financeMissingPeriodsError),
        );
        return;
      }
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CalculationResultPage(
            renewal: money,
            cycleMonths: cycle,
            asOf: estimateDate,
            due: end,
            value: value,
            fx: widget.controller.fx,
            usesKnownPeriods: referencedPeriods != null,
          ),
        ),
      );
    } catch (error) {
      showFailure(context, error);
    }
  }

  bool algorithmOpen = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return AppScaffold(
      largeTitle: false,
      title: l10n.financeCalculatorTitle,
      bottomBar: AppButton(
        key: const ValueKey('calculate-value'),
        label: l10n.financeCalculateValue,
        expand: true,
        onPressed: calculate,
      ),
      children: [
        Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: StatusPill(l10n.financeEstimatedOnly),
                ),
              ),
              AppSection(
                footer: referencedPeriods != null
                    ? l10n.financeReferenceBasis(sourceName ?? '')
                    : rebuilt
                    ? l10n.financeIndependentRebuilt
                    : l10n.financeIndependentNote,
                children: [
                  AppRow(
                    key: const ValueKey('calc-reference'),
                    icon: Icons.dns_outlined,
                    iconColor: AppTints.slate,
                    title: l10n.financeReferenceServer,
                    value: referencedPeriods != null ? sourceName : null,
                    chevron: true,
                    onTap: chooseReference,
                  ),
                ],
              ),
              AppSection(
                children: [
                  FinanceFieldRow(
                    key: const ValueKey('calc-price'),
                    controller: price,
                    label: l10n.financeRenewalAmount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    check: (v) => Money.parseMinor(v) == null
                        ? l10n.financeAmountError
                        : null,
                  ),
                  AppFormRow(
                    label: l10n.financeOriginalCurrency,
                    child: AppSegmented<String>(
                      key: ValueKey('calc-currency-$currency'),
                      compact: true,
                      options: {for (final c in Money.currencies) c: c},
                      value: currency,
                      onChanged: (v) => setState(() => currency = v),
                    ),
                  ),
                  AppFormRow.pick(
                    key: ValueKey('calc-cycle-$cycle'),
                    label: l10n.financeCycle,
                    value: l10n.financeEveryMonths(cycle),
                    onTap: chooseCycle,
                  ),
                ],
              ),
              AppSection(
                footer: l10n.r6CalcDueAutoNote,
                children: [
                  FinanceDateRow(
                    key: const ValueKey('calc-start'),
                    controller: start,
                    label: l10n.r6CalcServiceStart,
                    onTap: () => pickStart(l10n.r6CalcServiceStart),
                  ),
                  FinanceDateRow(
                    key: const ValueKey('calc-asof'),
                    controller: asOf,
                    label: l10n.financeValuationDate,
                    check: (v) => LedgerDate.tryParse(v.trim()) == null
                        ? l10n.financeValuationDateError
                        : null,
                    onTap: () => pickDate(
                      asOf,
                      l10n.financeValuationDate,
                      widget.controller.today,
                      (result) => asOf.text = result,
                      allowUnknown: false,
                    ),
                  ),
                  FinanceDateRow(
                    key: const ValueKey('calc-due'),
                    controller: due,
                    label: l10n.financeServiceDue,
                    check: (v) => LedgerDate.tryParse(v.trim()) == null
                        ? l10n.financeDueError
                        : null,
                    onTap: () => pickDue(l10n.financeServiceDue),
                  ),
                ],
              ),
              AppSection(
                footer: l10n.financeEstimateNoWrite,
                children: [
                  AppRow(
                    key: const ValueKey('calc-algorithm'),
                    title: l10n.financeAlgorithmTitle,
                    trailing: Icon(
                      algorithmOpen
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: p.text3,
                    ),
                    onTap: () => setState(() => algorithmOpen = !algorithmOpen),
                  ),
                  if (algorithmOpen)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                      child: Text(
                        l10n.financeAlgorithmNote,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.55,
                          color: p.text2,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
