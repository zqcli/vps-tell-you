import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../core/ui/ui.dart';
import '../core/value_types.dart';
import 'calculation_share.dart';
import 'calculation_widgets.dart';
import 'finance_math.dart';
import 'finance_models.dart';
import 'finance_widgets.dart';

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
    var copied = true;
    try {
      await Clipboard.setData(ClipboardData(text: shareData.plainText));
    } catch (_) {
      copied = false;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Builder(
          builder: (context) => Text(
            copied ? context.l10n.financeCopied : context.l10n.financeCopyError,
          ),
        ),
      ),
    );
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
