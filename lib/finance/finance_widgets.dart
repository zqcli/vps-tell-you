import 'package:flutter/material.dart';

import '../l10n/locale_preference.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/ui/ui.dart';
import '../core/value_types.dart';
import 'finance_models.dart';
import 'valuation_copy.dart';

/// Short explanatory text under a group or card (12.5 px, secondary colour).
class FinanceNote extends StatelessWidget {
  const FinanceNote(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 0),
  });
  final String text;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Text(text, style: context.footnoteStyle),
  );
}

/// Keeps a page-sheet form below the status bar when it is pushed as an
/// ordinary route. Inside `showAppModal` the top padding is already removed,
/// so this is a no-op there.
class FinanceModalFrame extends StatelessWidget {
  const FinanceModalFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.palette.bg,
    child: SafeArea(bottom: false, child: child),
  );
}

/// A validated text input in a grouped form row.
///
/// The row itself is the [FormField] (so `Form.validate()` and
/// `FormFieldState.errorText` keep working with the key given here); the
/// error is drawn under the row instead of inside the field.
class FinanceFieldRow extends FormField<String> {
  FinanceFieldRow({
    super.key,
    required this.controller,
    required this.label,
    String? Function(String text)? check,
    String? hint,
    TextInputType? keyboardType,
    int? maxLength,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
    super.enabled,
    bool stacked = false,
  }) : super(
         validator: check == null ? null : (_) => check(controller.text),
         builder: (state) => AppFormRow(
           label: label,
           stacked: stacked,
           errorText: state.errorText,
           child: AppTextField(
             controller: controller,
             label: label,
             hint: hint,
             keyboardType: keyboardType,
             maxLength: maxLength,
             maxLines: maxLines,
             minLines: stacked ? maxLines : null,
             enabled: enabled,
             textAlign: stacked ? TextAlign.start : TextAlign.end,
             onChanged: (value) {
               state.didChange(value);
               onChanged?.call(value);
             },
           ),
         ),
       );
  final TextEditingController controller;
  final String label;
}

/// Label above a value, for read-only facts inside a card.
class FinanceLine extends StatelessWidget {
  const FinanceLine(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: p.text2, fontSize: 12.5)),
          const SizedBox(height: 3),
          SelectableText(
            value,
            style: TextStyle(
              color: p.text,
              fontSize: 15,
              fontFeatures: kTabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

enum FinanceTotalLayout {
  /// Amount with the full coverage explanation (detail pages, lists).
  detail,

  /// Large white amount on the gradient summary card.
  hero,

  /// Small amount inside a translucent tile of the summary card.
  tile,
}

class FinanceTotalView extends StatelessWidget {
  const FinanceTotalView({
    super.key,
    required this.total,
    this.emphasize = false,
    this.compact = false,
    this.layout = FinanceTotalLayout.detail,
  });
  final FinanceTotal total;
  final bool emphasize, compact;
  final FinanceTotalLayout layout;

  @override
  Widget build(BuildContext context) => switch (layout) {
    FinanceTotalLayout.hero => _hero(context),
    FinanceTotalLayout.tile => _tile(context),
    FinanceTotalLayout.detail => _detail(context),
  };

  Widget _hero(BuildContext context) {
    final l10n = context.l10n;
    final display = total.currency;
    // Original-currency subtotals only add information for mixed currencies.
    final showOriginals =
        total.originals.length > 1 ||
        (total.originals.isNotEmpty && !total.originals.containsKey(display));
    const white = TextStyle(color: Colors.white, fontSize: 12.5, height: 1.35);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              total.formatted,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w700,
                letterSpacing: -.5,
                fontFeatures: kTabularFigures,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.financeCoverage(total.covered, total.total, total.missingFx),
          style: white,
        ),
        if (total.unknown + total.notApplicable > 0)
          Text(
            l10n.financeUnknownExcluded(total.unknown, total.notApplicable),
            style: white,
          ),
        if (showOriginals)
          Text(
            l10n.financeOriginalSubtotals(
              total.originals.entries
                  .map((e) => '${e.key} ${formatRational(e.value)}')
                  .join(' · '),
            ),
            style: white,
          ),
      ],
    );
  }

  Widget _tile(BuildContext context) {
    final complete = total.covered == total.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              total.formatted,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                height: 1.3,
                fontWeight: FontWeight.w600,
                fontFeatures: kTabularFigures,
              ),
            ),
          ),
        ),
        if (!complete)
          Text(
            context.l10n.financeCoverage(
              total.covered,
              total.total,
              total.missingFx,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
      ],
    );
  }

  Widget _detail(BuildContext context) {
    final p = context.palette;
    final secondary = TextStyle(fontSize: 12.5, color: p.text2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.financeTotalAmount(
            total.covered > 0 ? 'yes' : 'no',
            total.formatted,
            total.currency,
          ),
          style: TextStyle(
            fontSize: compact ? 21 : 30,
            fontWeight: FontWeight.w700,
            color: emphasize ? p.primary : p.text,
            fontFeatures: kTabularFigures,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          context.l10n.financeCoverage(
            total.covered,
            total.total,
            total.missingFx,
          ),
          style: secondary,
        ),
        if (total.unknown + total.notApplicable > 0)
          Text(
            context.l10n.financeUnknownExcluded(
              total.unknown,
              total.notApplicable,
            ),
            style: secondary,
          ),
        if (total.missingFx > 0)
          Text(
            context.l10n.financeMissingFxExcluded,
            style: secondary.copyWith(color: p.amber),
          ),
        if (total.originals.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.l10n.financeOriginalSubtotals(
                total.originals.entries
                    .map((e) => '${e.key} ${formatRational(e.value)}')
                    .join(' · '),
              ),
              style: secondary,
            ),
          ),
      ],
    );
  }
}

String convertedAmount(
  FinanceAmount amount,
  FxSettings fx, {
  AppLocalizations? l10n,
}) {
  final messages = l10n ?? defaultLocalizations;
  if (!amount.known) {
    return amount.status == AmountStatus.notApplicable
        ? messages.financeNotApplicable
        : messages.financeDataUnknown;
  }
  final converted = fx.convert(amount.minor!, amount.currency);
  return converted == null
      ? messages.financeMissingFxPreserved
      : messages.financeApproxAmount(
          formatMinor(converted.round(), currency: fx.displayCurrency),
          fx.displayCurrency,
        );
}

class ValuationCard extends StatelessWidget {
  const ValuationCard({
    super.key,
    required this.value,
    required this.renewal,
    required this.cycleMonths,
    required this.due,
    required this.asOf,
    required this.fx,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });
  final EdgeInsetsGeometry margin;
  final Valuation value;
  final Money renewal;
  final int cycleMonths;
  final LedgerDate due, asOf;
  final FxSettings fx;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final periodLabel = valuationPeriodLabel(
      asOf: asOf,
      start: value.activePeriod.start,
      end: value.activePeriod.end,
      l10n: context.l10n,
    );
    final secondary = TextStyle(fontSize: 12.5, color: p.text2);
    return AppCard(
      margin: margin,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.financeValueTitle, style: secondary),
          const SizedBox(height: 10),
          Text(
            '${value.amount.formatted} ${value.amount.currency}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: p.text,
              fontFeatures: kTabularFigures,
            ),
          ),
          Text(
            convertedAmount(value.amount, fx, l10n: context.l10n),
            style: TextStyle(fontSize: 14, color: p.text2),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.financePeriodProgress(
              periodLabel,
              (value.ratio.toDouble() * 100).toStringAsFixed(1),
              value.activeRemaining,
              value.days,
            ),
            style: TextStyle(fontSize: 14, color: p.text),
          ),
          const SizedBox(height: 9),
          AppProgressBar(value: value.ratio.toDouble().clamp(0, 1).toDouble()),
          const SizedBox(height: 8),
          Text(
            context.l10n.financePeriodDates(
              value.activePeriod.start.toString(),
              value.activePeriod.end.toString(),
            ),
            style: secondary,
          ),
          const SizedBox(height: 8),
          FinanceLine(context.l10n.financeValuationAndDue, '$asOf / $due'),
          const SizedBox(height: 6),
          AppMetricStrip(
            metrics: [
              AppMetric(
                label: context.l10n.r2CopyMetricDaysLeft,
                value: context.l10n.financeDaysValue(value.remainingDays),
              ),
              AppMetric(
                label: context.l10n.r2CopyMetricDaily,
                value:
                    '${formatRational(value.dailyMinor, digits: 4)} ${renewal.currency}',
              ),
            ],
          ),
          FinanceLine(
            context.l10n.financeRenewalCycle,
            context.l10n.financeRenewalValue(
              renewal.formatted,
              renewal.currency,
              cycleMonths,
            ),
          ),
          if (value.futurePeriods > 0)
            FinanceNote(
              context.l10n.financeFuturePeriodsNote(value.futurePeriods),
              padding: const EdgeInsets.only(top: 4),
            ),
          if (value.inferred)
            FinanceNote(
              context.l10n.financeInferredPeriods,
              padding: const EdgeInsets.only(top: 4),
            ),
          FinanceNote(
            context.l10n.financeValueDisclaimer,
            padding: const EdgeInsets.only(top: 4),
          ),
        ],
      ),
    );
  }
}
