import 'package:flutter/material.dart';

import '../core/ui/ui.dart';
import '../l10n/locale_preference.dart';
import '../core/value_types.dart';
import '../servers/ledger_controller.dart';
import 'finance_models.dart';
import 'finance_widgets.dart';

/// Gradient summary card: monthly reference, coverage, remaining value and
/// 30-day renewals.
class FinanceSummaryCard extends StatelessWidget {
  const FinanceSummaryCard({
    super.key,
    required this.monthly,
    required this.values,
    required this.renewals,
    required this.fx,
    required this.onMonthly,
    required this.onValue,
    required this.onRenewals,
    required this.onFx,
  });
  final FinanceTotal monthly, values, renewals;
  final FxSettings fx;
  final VoidCallback onMonthly, onValue, onRenewals, onFx;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final colors = financeHeroColors(p);
    const label = TextStyle(color: Colors.white, fontSize: 13);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DecoratedBox(
        key: const ValueKey('finance-summary'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
            stops: const [0, .55, 1],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  key: const ValueKey('metric-monthly'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: onMonthly,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.financeMonthlyReference, style: label),
                        const SizedBox(height: 2),
                        FinanceTotalView(
                          total: monthly,
                          emphasize: true,
                          layout: FinanceTotalLayout.hero,
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  key: const ValueKey('finance-fx-status'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: onFx,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.currency_exchange,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.financeFxOverview(
                              fx.displayCurrency,
                              fx.rateDate?.toString() ?? l10n.financeNotSet,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, box) {
                    final valueTile = _SummaryTile(
                      key: const ValueKey('metric-value'),
                      label: l10n.uiFinanceTileRemaining,
                      total: values,
                      onTap: onValue,
                    );
                    final renewalTile = _SummaryTile(
                      key: const ValueKey('metric-renewals'),
                      label: l10n.uiFinanceTileRenewals,
                      total: renewals,
                      onTap: onRenewals,
                    );
                    // Large text or a narrow screen: stack the tiles.
                    final scale = MediaQuery.textScalerOf(context).scale(1);
                    if ((box.maxWidth - 10) / 2 < 110 * scale) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          valueTile,
                          const SizedBox(height: 10),
                          renewalTile,
                        ],
                      );
                    }
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: valueTile),
                          const SizedBox(width: 10),
                          Expanded(child: renewalTile),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    super.key,
    required this.label,
    required this.total,
    required this.onTap,
  });
  final String label;
  final FinanceTotal total;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .16),
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Same caption / figure typography as [AppMetricStrip]; these
            // tiles stay separate because they navigate and may carry a
            // coverage line under the figure.
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .85),
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 2),
            FinanceTotalView(total: total, layout: FinanceTotalLayout.tile),
          ],
        ),
      ),
    ),
  );
}

class _DateBlock extends StatelessWidget implements AppLeading {
  const _DateBlock({required this.date, required this.color});
  final LedgerDate date;
  final Color color;
  @override
  double get leadingExtent => 46;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 46,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            date.day.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 19,
              height: 1,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: kTabularFigures,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              context.l10n.uiFinanceMonthShort('${date.month}'),
              maxLines: 1,
              style: TextStyle(fontSize: 11, color: p.text2),
            ),
          ),
        ],
      ),
    );
  }
}

class FinanceRenewalRow extends StatelessWidget implements AppSectionItem {
  const FinanceRenewalRow({
    super.key,
    required this.event,
    required this.controller,
    required this.onTap,
  });
  final RenewalEvent event;
  final LedgerController controller;
  final VoidCallback onTap;
  @override
  double get separatorInset => 74;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final fx = controller.fx;
    final days = controller.today.daysUntil(event.date);
    final tone = days == 0 ? p.red : p.amber;
    final amount = event.amount;
    final converted = amount.currency == fx.displayCurrency
        ? null
        : convertedAmount(amount, fx, l10n: l10n);
    return AppRow.custom(
      key: ValueKey('finance-renewal-${event.server.id}'),
      leading: _DateBlock(date: event.date, color: tone),
      chevron: true,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, box) {
          Widget info() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.server.name,
                style: TextStyle(fontSize: 16, height: 1.3, color: p.text),
              ),
              Text(
                days == 0 ? l10n.serverDueToday : l10n.serverDueInDays(days),
                style: TextStyle(fontSize: 13, height: 1.35, color: tone),
              ),
            ],
          );
          Widget amounts(CrossAxisAlignment align, TextAlign textAlign) =>
              Column(
                crossAxisAlignment: align,
                children: [
                  Text(
                    amount.formatted,
                    textAlign: textAlign,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                  if (converted != null)
                    Text(
                      converted,
                      textAlign: textAlign,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: p.text2,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                ],
              );
          // Large text or a narrow screen: amounts go under the name.
          final stacked =
              box.maxWidth < 200 * MediaQuery.textScalerOf(context).scale(1);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      info(),
                      const SizedBox(height: 4),
                      amounts(CrossAxisAlignment.start, TextAlign.start),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: info()),
                      const SizedBox(width: 8),
                      Flexible(
                        child: amounts(CrossAxisAlignment.end, TextAlign.end),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

/// Horizontal stacked share bar.
class FinanceStackBar extends StatelessWidget {
  const FinanceStackBar({
    super.key,
    required this.ratios,
    required this.colors,
  });
  final List<double> ratios;
  final List<Color> colors;
  @override
  Widget build(BuildContext context) {
    final shown = [
      for (var i = 0; i < ratios.length; i++)
        if (ratios[i] > 0) i,
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: shown.isEmpty
            ? ColoredBox(color: context.palette.fill)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var k = 0; k < shown.length; k++) ...[
                    if (k > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: (ratios[shown[k]] * 10000).round().clamp(1, 10000),
                      child: ColoredBox(color: colors[shown[k]]),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Six-month prepaid renewal chart: tappable bars, the selected month's
/// amount and renewal count above. Months whose total is partial (missing
/// exchange rate or unknown amount) are drawn in amber with a gap pill.
class FinanceForecastChart extends StatelessWidget {
  const FinanceForecastChart({
    super.key,
    required this.forecast,
    required this.selected,
    required this.onSelect,
  });
  final List<ForecastMonth> forecast;
  final int selected;
  final ValueChanged<int> onSelect;

  static bool _gaps(FinanceTotal t) => t.missingFx > 0 || t.unknown > 0;

  /// Compact bar caption with the display-currency symbol: `¥676`, `¥1.2k`,
  /// `¥3.4M`; '—' when nothing in the month could be converted.
  static String _caption(FinanceTotal t) {
    if (t.covered == 0 && t.total > 0) return '—';
    final symbol = currencySymbol(t.currency);
    final whole = (t.convertedMinor / Rational.of(100)).round();
    String scaled(int divisor, String unit) {
      final tenths =
          (whole * BigInt.from(10) + BigInt.from(divisor ~/ 2)) ~/
          BigInt.from(divisor);
      final text = tenths % BigInt.from(10) == BigInt.zero
          ? '${tenths ~/ BigInt.from(10)}'
          : '${tenths ~/ BigInt.from(10)}.${tenths % BigInt.from(10)}';
      return '$symbol$text$unit';
    }

    if (whole.abs() >= BigInt.from(999500)) return scaled(1000000, 'M');
    if (whole.abs() >= BigInt.from(1000)) return scaled(1000, 'k');
    return '$symbol$whole';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final sel = forecast[selected];
    final maxValue = forecast.fold<double>(
      0,
      (m, f) => f.total.convertedMinor.toDouble() > m
          ? f.total.convertedMinor.toDouble()
          : m,
    );
    final gapParts = [
      if (sel.total.missingFx > 0)
        l10n.uiFinanceGapMissingFx(sel.total.missingFx),
      if (sel.total.unknown > 0) l10n.uiFinanceGapUnknown(sel.total.unknown),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.financeForecastMonth(
                        sel.month.year,
                        sel.month.month,
                        sel.events.length,
                      ),
                      style: TextStyle(fontSize: 13, color: p.text2),
                    ),
                    Text(
                      sel.total.formatted,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // A fixed share of the row keeps the title column roomy and the
              // pill flush with the right edge, whatever its width.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * .45,
                ),
                child: StatusPill(
                  gapParts.isEmpty
                      ? l10n.uiFinanceForecastBasis
                      : gapParts.join(' · '),
                  tone: gapParts.isEmpty ? AppTone.neutral : AppTone.amber,
                  icon: gapParts.isEmpty ? null : Icons.warning_amber_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < forecast.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _ForecastBar(
                      month: forecast[i],
                      ratio: maxValue <= 0
                          ? 0
                          : forecast[i].total.convertedMinor.toDouble() /
                                maxValue,
                      selected: i == selected,
                      caption: _caption(forecast[i].total),
                      gaps: _gaps(forecast[i].total),
                      onTap: () => onSelect(i),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastBar extends StatelessWidget {
  const _ForecastBar({
    required this.month,
    required this.ratio,
    required this.selected,
    required this.caption,
    required this.gaps,
    required this.onTap,
  });
  final ForecastMonth month;
  final double ratio;
  final bool selected, gaps;
  final String caption;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final base = gaps ? p.amberSolid : p.primary;
    final monthLabel = l10n.uiFinanceMonthShort('${month.month.month}');
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: '$monthLabel ${month.total.formatted}',
      onTap: onTap,
      child: GestureDetector(
        key: ValueKey('forecast-${month.month}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                caption,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? p.text : p.text2,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: (ratio.clamp(0, 1) * box.maxHeight).clamp(
                      4,
                      box.maxHeight,
                    ),
                    decoration: BoxDecoration(
                      color: base.withValues(alpha: selected ? 1 : .3),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                        bottom: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                monthLabel,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? p.text : p.text2,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
