import 'package:flutter/material.dart';

import '../l10n/locale_preference.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/app_theme.dart';
import '../core/value_types.dart';
import 'finance_models.dart';
import 'valuation_copy.dart';

class FinanceLine extends StatelessWidget {
  const FinanceLine(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 3),
        SelectableText(value),
      ],
    ),
  );
}

class FinanceTotalView extends StatelessWidget {
  const FinanceTotalView({
    super.key,
    required this.total,
    this.emphasize = false,
    this.compact = false,
  });
  final FinanceTotal total;
  final bool emphasize, compact;
  @override
  Widget build(BuildContext context) => Column(
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
          color: emphasize
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        context.l10n.financeCoverage(
          total.covered,
          total.total,
          total.missingFx,
        ),
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      if (total.unknown + total.notApplicable > 0)
        Text(
          context.l10n.financeUnknownExcluded(
            total.unknown,
            total.notApplicable,
          ),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      if (total.missingFx > 0)
        Text(
          context.l10n.financeMissingFxExcluded,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.tertiary,
          ),
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
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
    ],
  );
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
  });
  final Valuation value;
  final Money renewal;
  final int cycleMonths;
  final LedgerDate due, asOf;
  final FxSettings fx;
  @override
  Widget build(BuildContext context) {
    final periodLabel = valuationPeriodLabel(
      asOf: asOf,
      start: value.activePeriod.start,
      end: value.activePeriod.end,
      l10n: context.l10n,
    );
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.financeValueTitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${value.amount.formatted} ${value.amount.currency}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
          ),
          Text(
            convertedAmount(value.amount, fx, l10n: context.l10n),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            context.l10n.financePeriodProgress(
              periodLabel,
              (value.ratio.toDouble() * 100).toStringAsFixed(1),
              value.activeRemaining,
              value.days,
            ),
          ),
          const SizedBox(height: 9),
          LinearProgressIndicator(
            value: value.ratio.toDouble().clamp(0, 1),
            borderRadius: BorderRadius.circular(5),
            minHeight: 7,
            backgroundColor: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.financePeriodDates(
              value.activePeriod.start.toString(),
              value.activePeriod.end.toString(),
            ),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FinanceLine(context.l10n.financeValuationAndDue, '$asOf / $due'),
          FinanceLine(
            context.l10n.financeRemainingDays,
            context.l10n.financeDaysValue(value.remainingDays),
          ),
          FinanceLine(
            context.l10n.financeRenewalCycle,
            context.l10n.financeRenewalValue(
              renewal.formatted,
              renewal.currency,
              cycleMonths,
            ),
          ),
          FinanceLine(
            context.l10n.financeDailyShown,
            '${formatRational(value.dailyMinor, digits: 4)} ${renewal.currency}',
          ),
          if (value.futurePeriods > 0)
            InfoNote(
              context.l10n.financeFuturePeriodsNote(value.futurePeriods),
            ),
          if (value.inferred) InfoNote(context.l10n.financeInferredPeriods),
          InfoNote(context.l10n.financeValueDisclaimer),
        ],
      ),
    );
  }
}
