import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../core/app_theme.dart' show showFailure;
import '../core/ui/ui.dart';
import '../core/value_types.dart';
import '../servers/ledger_controller.dart';
import '../servers/server_record.dart';
import 'calculation_share.dart';
import 'finance_math.dart';
import 'finance_models.dart';
import 'finance_widgets.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key, required this.controller, this.server});
  final LedgerController controller;
  final ServerRecord? server;
  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  bool validationAttempted = false;
  String? validationLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = context.l10n.localeName;
    if (validationLocale != null &&
        validationLocale != locale &&
        validationAttempted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) form.currentState?.validate();
      });
    }
    validationLocale = locale;
  }

  final form = GlobalKey<FormState>();
  late final TextEditingController price, asOf, due;
  late String currency;
  late int cycle;
  List<ServicePeriod>? referencedPeriods;
  String? sourceName;
  bool rebuilt = false;
  @override
  void initState() {
    super.initState();
    price = TextEditingController();
    asOf = TextEditingController(text: widget.controller.today.toString());
    due = TextEditingController(
      text: widget.controller.today.addMonths(12).toString(),
    );
    currency = 'USD';
    cycle = 12;
    if (widget.server != null) reference(widget.server!);
  }

  void reference(ServerRecord s) {
    price.text = s.money?.decimal ?? '';
    due.text = s.dueDate?.toString() ?? '';
    currency = s.currency;
    cycle = s.cycleMonths;
    referencedPeriods = List.unmodifiable(widget.controller.periodsFor(s.id));
    sourceName = s.name;
    rebuilt = false;
  }

  @override
  void dispose() {
    price.dispose();
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
      changePeriod();
      setState(() => cycle = picked);
    }
  }

  void changePeriod() {
    if (referencedPeriods != null) {
      setState(() {
        referencedPeriods = null;
        rebuilt = true;
      });
    }
  }

  void calculate() {
    validationAttempted = true;
    if (!form.currentState!.validate()) return;
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
          key: form,
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
                  FinanceFieldRow(
                    key: const ValueKey('calc-asof'),
                    controller: asOf,
                    label: l10n.financeValuationDate,
                    hint: 'YYYY-MM-DD',
                    check: (v) => LedgerDate.tryParse(v.trim()) == null
                        ? l10n.financeValuationDateError
                        : null,
                  ),
                  FinanceFieldRow(
                    key: const ValueKey('calc-due'),
                    controller: due,
                    label: l10n.financeServiceDue,
                    hint: 'YYYY-MM-DD',
                    onChanged: (_) => changePeriod(),
                    check: (v) => LedgerDate.tryParse(v.trim()) == null
                        ? l10n.financeDueError
                        : null,
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

class CalculationResultPage extends StatefulWidget {
  const CalculationResultPage({
    super.key,
    required this.renewal,
    required this.cycleMonths,
    required this.asOf,
    required this.due,
    required this.value,
    required this.fx,
    required this.usesKnownPeriods,
  });
  final Money renewal;
  final int cycleMonths;
  final LedgerDate asOf, due;
  final Valuation value;
  final FxSettings fx;
  final bool usesKnownPeriods;
  @override
  State<CalculationResultPage> createState() => _CalculationResultPageState();
}

class _CalculationResultPageState extends State<CalculationResultPage> {
  bool validationAttempted = false;
  String? validationLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = context.l10n.localeName;
    if (validationLocale != null &&
        validationLocale != locale &&
        validationAttempted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) quoteForm.currentState?.validate();
      });
    }
    validationLocale = locale;
  }

  final quoteForm = GlobalKey<FormState>();
  final offer = TextEditingController();
  final fee = TextEditingController(text: '0');
  late String feeCurrency = widget.fx.displayCurrency;
  FeePayer payer = FeePayer.buyer;
  QuoteResult? quote;
  LocalizedText? quoteError;
  @override
  void dispose() {
    offer.dispose();
    fee.dispose();
    super.dispose();
  }

  CalculationShareData get shareData {
    final v = widget.value, fx = widget.fx;
    final rate = fx.convert(Rational.of(100), widget.renewal.currency);
    return CalculationShareData(
      localizations: context.l10n,
      amount: v.amount.formatted,
      currency: widget.renewal.currency,
      converted: convertedAmount(v.amount, fx, l10n: context.l10n),
      asOf: widget.asOf,
      start: v.activePeriod.start,
      end: v.activePeriod.end,
      due: widget.due,
      ratio: v.ratio.toDouble(),
      activeRemaining: v.activeRemaining,
      days: v.days,
      remaining: v.remainingDays,
      renewal: context.l10n.financeRenewalValue(
        widget.renewal.formatted,
        widget.renewal.currency,
        widget.cycleMonths,
      ),
      daily:
          '${formatRational(v.dailyMinor, digits: 4)} ${widget.renewal.currency}',
      futurePeriods: v.futurePeriods,
      fx: rate == null
          ? context.l10n.financeReferenceRateMissing
          : '1 ${widget.renewal.currency} = ${formatRational(rate, digits: 8)} ${fx.displayCurrency}',
      fxSource: context.l10n.financeFxSource(
        fx.rateDate?.toString() ?? context.l10n.financeDateNotSet,
      ),
      periodBasis: widget.usesKnownPeriods
          ? context.l10n.financeKnownPeriodsBasis(v.inferred ? 'yes' : 'no')
          : context.l10n.financeIndependentBasis,
    );
  }

  void clearQuote() => setState(() {
    quote = null;
    quoteError = null;
  });
  void settle() {
    validationAttempted = true;
    if (!quoteForm.currentState!.validate()) return;
    final result = calculateQuote(
      offer: Money(widget.fx.displayCurrency, Money.parseMinor(offer.text)!),
      fee: Money(feeCurrency, Money.parseMinor(fee.text)!),
      payer: payer,
      reference: widget.value.amount,
      fx: widget.fx,
    );
    setState(() {
      quote = result;
      quoteError = result == null
          ? LocalizedText((l10n) => l10n.financeQuoteFxError)
          : null;
    });
  }

  Future<void> copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: shareData.plainText));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) => Text(context.l10n.financeCopied),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) => Text(context.l10n.financeCopyError),
            ),
          ),
        );
      }
    }
  }

  bool quoteOpen = false;

  Future<void> choosePayer() async {
    final picked = await showAppPicker<FeePayer>(
      context,
      title: context.l10n.financeFeePayer,
      selected: payer,
      options: [
        AppPickerOption(
          key: const ValueKey('quote-payer-buyer'),
          value: FeePayer.buyer,
          title: context.l10n.financeBuyerPays,
        ),
        AppPickerOption(
          key: const ValueKey('quote-payer-seller'),
          value: FeePayer.seller,
          title: context.l10n.financeSellerPays,
        ),
        AppPickerOption(
          key: const ValueKey('quote-payer-split'),
          value: FeePayer.split,
          title: context.l10n.financeSplitFee,
        ),
      ],
    );
    if (picked != null && mounted) {
      clearQuote();
      setState(() => payer = picked);
    }
  }

  String _payerLabel(FeePayer value) => switch (value) {
    FeePayer.buyer => context.l10n.financeBuyerPays,
    FeePayer.seller => context.l10n.financeSellerPays,
    FeePayer.split => context.l10n.financeSplitFee,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final share = shareData;
    return AppScaffold(
      largeTitle: false,
      title: l10n.financeResultTitle,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusPill(l10n.financeEstimatedOnly),
          ),
        ),
        ValuationCard(
          value: widget.value,
          renewal: widget.renewal,
          cycleMonths: widget.cycleMonths,
          due: widget.due,
          asOf: widget.asOf,
          fx: widget.fx,
        ),
        FinanceNote(share.periodBasis),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: AppButton(
            key: const ValueKey('preview-png'),
            label: l10n.financePreviewPng,
            icon: Icons.image_outlined,
            expand: true,
            onPressed: () {
              final snapshot = shareData;
              Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => CalculationPreview(data: snapshot),
                ),
              );
            },
          ),
        ),
        AppSection(
          children: [
            AppRow(
              key: const ValueKey('result-edit'),
              icon: Icons.edit_outlined,
              iconColor: AppTints.slate,
              title: l10n.financeEditInputs,
              onTap: () => Navigator.pop(context),
            ),
            AppRow(
              key: const ValueKey('result-copy'),
              icon: Icons.copy_outlined,
              iconColor: AppTints.teal,
              title: l10n.financeCopyResult,
              onTap: copy,
            ),
          ],
        ),
        AppSection(
          key: const ValueKey('quote-panel'),
          children: [
            AppRow(
              title: l10n.financeQuoteTitle,
              trailing: Icon(
                quoteOpen
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: p.text3,
              ),
              onTap: () => setState(() => quoteOpen = !quoteOpen),
            ),
          ],
        ),
        Visibility(
          visible: quoteOpen,
          maintainState: true,
          child: Form(
            key: quoteForm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FinanceNote(l10n.financeQuoteNote),
                AppSection(
                  footer: l10n.financeSplitFeeNote,
                  children: [
                    FinanceFieldRow(
                      key: const ValueKey('quote-offer'),
                      controller: offer,
                      label: l10n.financeSellerQuote(widget.fx.displayCurrency),
                      onChanged: (_) => clearQuote(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      check: (v) => Money.parseMinor(v) == null
                          ? l10n.financeQuoteAmountError
                          : null,
                    ),
                    FinanceFieldRow(
                      key: const ValueKey('quote-fee'),
                      controller: fee,
                      label: l10n.financeTransferFee,
                      onChanged: (_) => clearQuote(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      check: (v) => Money.parseMinor(v) == null
                          ? l10n.financeQuoteFeeError
                          : null,
                    ),
                    AppFormRow(
                      label: l10n.financeFeeCurrency,
                      child: AppSegmented<String>(
                        key: const ValueKey('quote-fee-currency'),
                        compact: true,
                        options: {for (final c in Money.currencies) c: c},
                        value: feeCurrency,
                        onChanged: (v) {
                          clearQuote();
                          setState(() => feeCurrency = v);
                        },
                      ),
                    ),
                    AppFormRow.pick(
                      key: const ValueKey('quote-payer'),
                      label: l10n.financeFeePayer,
                      value: _payerLabel(payer),
                      onTap: choosePayer,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: AppButton(
                    key: const ValueKey('calculate-quote'),
                    label: l10n.financeCalculateQuote,
                    kind: AppButtonKind.tonal,
                    expand: true,
                    onPressed: settle,
                  ),
                ),
                if (quoteError != null)
                  AppBanner(
                    tone: AppTone.red,
                    icon: Icons.error_outline_rounded,
                    text: quoteError!.messageFor(l10n),
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  ),
                if (quote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FinanceLine(
                            l10n.financePremiumLabel,
                            '${quote!.premium} ${quote!.currency}',
                          ),
                          FinanceLine(
                            l10n.financeBuyerSellerFee,
                            '${quote!.buyerFee} / ${quote!.sellerFee} ${quote!.currency}',
                          ),
                          FinanceLine(
                            l10n.financeBuyerEstimate,
                            '${quote!.buyerTotal} ${quote!.currency}',
                          ),
                          FinanceLine(
                            l10n.financeSellerEstimate,
                            '${quote!.sellerNet} ${quote!.currency}',
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        FinanceNote(
          l10n.financeRoundingNote(share.fx, share.fxSource),
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
        ),
      ],
    );
  }
}
