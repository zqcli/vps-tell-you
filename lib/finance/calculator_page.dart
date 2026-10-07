import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../core/app_theme.dart';
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
    final s = await showModalBottomSheet<ServerRecord>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                context.l10n.financeReferenceTitle,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              InfoNote(context.l10n.financeReferenceNote),
              ...widget.controller.active
                  .where((s) => s.billing == BillingKind.prepaid)
                  .map(
                    (s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.name),
                      subtitle: Text(
                        context.l10n.financeReferenceServerSubtitle(
                          s.billingLabelFor(context.l10n),
                          s.dueDate?.toString() ?? context.l10n.financeUnknown,
                        ),
                      ),
                      onTap: () => Navigator.pop(context, s),
                    ),
                  ),
              if (!widget.controller.active.any(
                (s) => s.billing == BillingKind.prepaid,
              ))
                InfoNote(context.l10n.financeNoPrepaid),
            ],
          ),
        ),
      ),
    );
    if (s != null && mounted) setState(() => reference(s));
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.financeCalculatorTitle)),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              LedgerBadge(context.l10n.financeEstimatedOnly),
              TextButton(
                onPressed: chooseReference,
                child: Text(context.l10n.financeReferenceServer),
              ),
            ],
          ),
          InfoNote(
            referencedPeriods != null
                ? context.l10n.financeReferenceBasis(sourceName ?? '')
                : rebuilt
                ? context.l10n.financeIndependentRebuilt
                : context.l10n.financeIndependentNote,
          ),
          TextFormField(
            key: const ValueKey('calc-price'),
            controller: price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              errorMaxLines: 5,
              labelText: context.l10n.financeRenewalAmount,
            ),
            validator: (v) => Money.parseMinor(v!) == null
                ? context.l10n.financeAmountError
                : null,
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            key: ValueKey('calc-currency-$currency'),
            initialValue: currency,
            isExpanded: true,
            itemHeight: null,
            decoration: InputDecoration(
              errorMaxLines: 5,
              labelText: context.l10n.financeOriginalCurrency,
            ),
            items: Money.currencies
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => currency = v!),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<int>(
            key: ValueKey('calc-cycle-$cycle'),
            initialValue: cycle,
            isExpanded: true,
            itemHeight: null,
            decoration: InputDecoration(
              errorMaxLines: 5,
              labelText: context.l10n.financeCycle,
            ),
            items: [1, 3, 6, 12, 24, 36]
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Builder(
                      builder: (context) =>
                          Text(context.l10n.financeEveryMonths(c)),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != cycle) {
                changePeriod();
                setState(() => cycle = v!);
              }
            },
          ),
          const SizedBox(height: 18),
          TextFormField(
            key: const ValueKey('calc-asof'),
            controller: asOf,
            decoration: InputDecoration(
              errorMaxLines: 5,
              labelText: context.l10n.financeValuationDate,
              hintText: 'YYYY-MM-DD',
            ),
            validator: (v) => LedgerDate.tryParse(v!.trim()) == null
                ? context.l10n.financeValuationDateError
                : null,
          ),
          const SizedBox(height: 18),
          TextFormField(
            key: const ValueKey('calc-due'),
            controller: due,
            onChanged: (_) => changePeriod(),
            decoration: InputDecoration(
              errorMaxLines: 5,
              labelText: context.l10n.financeServiceDue,
              hintText: 'YYYY-MM-DD',
            ),
            validator: (v) => LedgerDate.tryParse(v!.trim()) == null
                ? context.l10n.financeDueError
                : null,
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(context.l10n.financeAlgorithmTitle),
            children: [InfoNote(context.l10n.financeAlgorithmNote)],
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('calculate-value'),
            onPressed: calculate,
            child: Text(context.l10n.financeCalculateValue),
          ),
          InfoNote(context.l10n.financeEstimateNoWrite),
        ],
      ),
    ),
  );
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.financeResultTitle)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        LedgerBadge(context.l10n.financeEstimatedOnly),
        const SizedBox(height: 16),
        ValuationCard(
          value: widget.value,
          renewal: widget.renewal,
          cycleMonths: widget.cycleMonths,
          due: widget.due,
          asOf: widget.asOf,
          fx: widget.fx,
        ),
        InfoNote(shareData.periodBasis),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.edit_outlined),
              label: Text(context.l10n.financeEditInputs),
            ),
            OutlinedButton.icon(
              onPressed: copy,
              icon: const Icon(Icons.copy_outlined),
              label: Text(context.l10n.financeCopyResult),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('preview-png'),
          onPressed: () {
            final snapshot = shareData;
            Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => CalculationPreview(data: snapshot),
              ),
            );
          },
          icon: const Icon(Icons.image_outlined),
          label: Text(context.l10n.financePreviewPng),
        ),
        const SizedBox(height: 20),
        LedgerCard(
          child: ExpansionTile(
            key: const ValueKey('quote-panel'),
            maintainState: true,
            tilePadding: EdgeInsets.zero,
            title: Text(context.l10n.financeQuoteTitle),
            children: [
              Form(
                key: quoteForm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InfoNote(context.l10n.financeQuoteNote),
                    TextFormField(
                      key: const ValueKey('quote-offer'),
                      controller: offer,
                      onChanged: (_) => clearQuote(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        errorMaxLines: 5,
                        labelText: context.l10n.financeSellerQuote(
                          widget.fx.displayCurrency,
                        ),
                      ),
                      validator: (v) => Money.parseMinor(v!) == null
                          ? context.l10n.financeQuoteAmountError
                          : null,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      key: const ValueKey('quote-fee'),
                      controller: fee,
                      onChanged: (_) => clearQuote(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        errorMaxLines: 5,
                        labelText: context.l10n.financeTransferFee,
                      ),
                      validator: (v) => Money.parseMinor(v!) == null
                          ? context.l10n.financeQuoteFeeError
                          : null,
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: feeCurrency,
                      isExpanded: true,
                      itemHeight: null,
                      decoration: InputDecoration(
                        errorMaxLines: 5,
                        labelText: context.l10n.financeFeeCurrency,
                      ),
                      items: Money.currencies
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) {
                        clearQuote();
                        setState(() => feeCurrency = v!);
                      },
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<FeePayer>(
                      initialValue: payer,
                      isExpanded: true,
                      itemHeight: null,
                      decoration: InputDecoration(
                        errorMaxLines: 5,
                        labelText: context.l10n.financeFeePayer,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: FeePayer.buyer,
                          child: Builder(
                            builder: (context) =>
                                Text(context.l10n.financeBuyerPays),
                          ),
                        ),
                        DropdownMenuItem(
                          value: FeePayer.seller,
                          child: Builder(
                            builder: (context) =>
                                Text(context.l10n.financeSellerPays),
                          ),
                        ),
                        DropdownMenuItem(
                          value: FeePayer.split,
                          child: Builder(
                            builder: (context) =>
                                Text(context.l10n.financeSplitFee),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        clearQuote();
                        setState(() => payer = v!);
                      },
                    ),
                    InfoNote(context.l10n.financeSplitFeeNote),
                    OutlinedButton(
                      onPressed: settle,
                      child: Text(context.l10n.financeCalculateQuote),
                    ),
                    if (quoteError != null)
                      InfoNote(quoteError!.messageFor(context.l10n)),
                    if (quote != null) ...[
                      FinanceLine(
                        context.l10n.financePremiumLabel,
                        '${quote!.premium} ${quote!.currency}',
                      ),
                      FinanceLine(
                        context.l10n.financeBuyerSellerFee,
                        '${quote!.buyerFee} / ${quote!.sellerFee} ${quote!.currency}',
                      ),
                      FinanceLine(
                        context.l10n.financeBuyerEstimate,
                        '${quote!.buyerTotal} ${quote!.currency}',
                      ),
                      FinanceLine(
                        context.l10n.financeSellerEstimate,
                        '${quote!.sellerNet} ${quote!.currency}',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        InfoNote(
          context.l10n.financeRoundingNote(shareData.fx, shareData.fxSource),
        ),
      ],
    ),
  );
}
