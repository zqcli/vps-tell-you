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
        if (mounted) form.currentState?.validate();
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

/// How the transfer trial's price is entered.
enum QuoteMode { offer, premium, percent }

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
  final premiumAmount = TextEditingController();
  final premiumPercent = TextEditingController();
  final fee = TextEditingController(text: '0');
  QuoteMode quoteMode = QuoteMode.offer;
  bool discount = false;
  late String feeCurrency = widget.fx.displayCurrency;
  FeePayer payer = FeePayer.buyer;
  QuoteResult? quote;
  LocalizedText? quoteError;
  @override
  void dispose() {
    offer.dispose();
    premiumAmount.dispose();
    premiumPercent.dispose();
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
    final fx = widget.fx;
    final feeMoney = Money(feeCurrency, Money.parseMinor(fee.text)!);
    QuoteResult? result;
    switch (quoteMode) {
      case QuoteMode.offer:
        result = calculateQuote(
          offer: Money(fx.displayCurrency, Money.parseMinor(offer.text)!),
          fee: feeMoney,
          payer: payer,
          reference: widget.value.amount,
          fx: fx,
        );
      case QuoteMode.premium:
        final minor = BigInt.from(Money.parseMinor(premiumAmount.text)!);
        result = calculateQuote(
          premiumMinor: discount ? -minor : minor,
          fee: feeMoney,
          payer: payer,
          reference: widget.value.amount,
          fx: fx,
        );
      case QuoteMode.percent:
        final percent = parseQuotePercent(premiumPercent.text)!;
        result = calculateQuote(
          premiumPercent: discount ? Rational.zero - percent : percent,
          fee: feeMoney,
          payer: payer,
          reference: widget.value.amount,
          fx: fx,
        );
    }
    // A missing rate (reference or fee currency) and an out-of-range price
    // both come back as null; tell them apart for the message.
    final ratesKnown =
        fx.convert(widget.value.amount.minor!, widget.value.amount.currency) !=
            null &&
        fx.convert(Rational.of(feeMoney.minor), feeMoney.currency) != null;
    setState(() {
      quote = result;
      quoteError = result != null
          ? null
          : ratesKnown
          ? LocalizedText((l10n) => l10n.r3FinanceQuoteRangeError)
          : LocalizedText((l10n) => l10n.financeQuoteFxError);
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

  String _modeLabel(QuoteMode value) => switch (value) {
    QuoteMode.offer => context.l10n.r3FinanceQuoteModeOffer,
    QuoteMode.premium => context.l10n.r3FinanceQuoteModePremium,
    QuoteMode.percent => context.l10n.r3FinanceQuoteModePercent,
  };

  Future<void> chooseMode() async {
    final picked = await showAppPicker<QuoteMode>(
      context,
      title: context.l10n.r3FinanceQuoteMode,
      selected: quoteMode,
      options: [
        for (final mode in QuoteMode.values)
          AppPickerOption(
            key: ValueKey('quote-mode-${mode.name}'),
            value: mode,
            title: _modeLabel(mode),
          ),
      ],
    );
    if (picked != null && mounted) {
      clearQuote();
      setState(() => quoteMode = picked);
    }
  }

  String _payerLabel(FeePayer value) => switch (value) {
    FeePayer.buyer => context.l10n.financeBuyerPays,
    FeePayer.seller => context.l10n.financeSellerPays,
    FeePayer.split => context.l10n.financeSplitFee,
  };

  /// Remaining value + premium = price, then fees, then what each side pays
  /// or receives.
  List<Widget> _settlement(QuoteResult q) {
    final l10n = context.l10n;
    final percent = q.premiumPercent;
    final signed = q.isDiscount || q.premiumMinor == BigInt.zero
        ? q.premium
        : '+${q.premium}';
    final signedPercent = percent == null
        ? ''
        : ' · ${q.isDiscount || q.premiumMinor == BigInt.zero ? '' : '+'}$percent%';
    return [
      AppSection(
        key: const ValueKey('quote-settlement'),
        header: '${l10n.r3FinanceQuoteSettlement} · ${q.currency}',
        children: [
          AppKeyValueRow(label: l10n.r3FinanceQuoteRef, value: q.reference),
          AppKeyValueRow(
            label: q.isDiscount
                ? l10n.r3FinanceQuoteDiscount
                : l10n.r3FinanceQuotePremium,
            value: '$signed$signedPercent',
          ),
          AppKeyValueRow(label: l10n.r3FinanceQuoteDeal, value: q.offer),
          AppKeyValueRow(
            label: l10n.financeBuyerSellerFee,
            value: '${q.buyerFee} / ${q.sellerFee}',
          ),
        ],
      ),
      const SizedBox(height: 12),
      AppCard(
        child: AppMetricStrip(
          metrics: [
            AppMetric(label: l10n.financeBuyerEstimate, value: q.buyerTotal),
            AppMetric(label: l10n.financeSellerEstimate, value: q.sellerNet),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final share = shareData;
    return AppScaffold(
      largeTitle: false,
      title: l10n.financeResultTitle,
      children: [
        const SizedBox(height: 14),
        CalculationHero(value: widget.value, fx: widget.fx, asOf: widget.asOf),
        const SizedBox(height: 12),
        CalculationDetails(
          value: widget.value,
          renewal: widget.renewal,
          cycleMonths: widget.cycleMonths,
          due: widget.due,
          asOf: widget.asOf,
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
                  children: [
                    AppFormRow.pick(
                      key: const ValueKey('quote-mode'),
                      label: l10n.r3FinanceQuoteMode,
                      value: _modeLabel(quoteMode),
                      onTap: chooseMode,
                    ),
                    if (quoteMode != QuoteMode.offer)
                      AppFormRow(
                        label: l10n.r3FinanceQuoteDirection,
                        child: AppSegmented<bool>(
                          key: const ValueKey('quote-direction'),
                          compact: true,
                          options: {
                            false: l10n.r3FinanceQuotePremium,
                            true: l10n.r3FinanceQuoteDiscount,
                          },
                          value: discount,
                          onChanged: (v) {
                            clearQuote();
                            setState(() => discount = v);
                          },
                        ),
                      ),
                    if (quoteMode == QuoteMode.offer)
                      FinanceFieldRow(
                        key: const ValueKey('quote-offer'),
                        controller: offer,
                        label: l10n.financeSellerQuote(
                          widget.fx.displayCurrency,
                        ),
                        onChanged: (_) => clearQuote(),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        check: (v) => Money.parseMinor(v) == null
                            ? l10n.financeQuoteAmountError
                            : null,
                      )
                    else if (quoteMode == QuoteMode.premium)
                      FinanceFieldRow(
                        key: const ValueKey('quote-premium'),
                        controller: premiumAmount,
                        label: l10n.r3FinanceQuotePremiumField(
                          widget.fx.displayCurrency,
                        ),
                        onChanged: (_) => clearQuote(),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        check: (v) => Money.parseMinor(v) == null
                            ? l10n.financeQuoteAmountError
                            : null,
                      )
                    else
                      FinanceFieldRow(
                        key: const ValueKey('quote-percent'),
                        controller: premiumPercent,
                        label: l10n.r3FinanceQuotePercentField,
                        onChanged: (_) => clearQuote(),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        check: (v) => parseQuotePercent(v) == null
                            ? l10n.r3FinanceQuotePercentError
                            : null,
                      ),
                  ],
                ),
                AppSection(
                  footer: l10n.financeSplitFeeNote,
                  children: [
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
                if (quote != null) ..._settlement(quote!),
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
