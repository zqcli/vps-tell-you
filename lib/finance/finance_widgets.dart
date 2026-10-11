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

/// Brand gradient of the hero cards (Costs summary, calculation result):
/// blue to violet, pulled towards the page background in dark mode.
List<Color> financeHeroColors(AppPalette p) {
  final stops = [
    AppTints.blue,
    Color.lerp(AppTints.blue, AppTints.indigo, .5)!,
    Color.lerp(AppTints.blue, AppTints.purple, .55)!,
  ];
  return p.isDark ? [for (final c in stops) Color.lerp(c, p.bg, .5)!] : stops;
}

/// Circular progress: [value] 0..1 drawn clockwise from 12 o'clock over a
/// faint track; [child] sits in the middle.
class FinanceRing extends StatelessWidget {
  const FinanceRing({
    super.key,
    required this.value,
    required this.size,
    required this.color,
    required this.track,
    this.stroke = 8,
    this.child,
  });
  final double value, size, stroke;
  final Color color, track;
  final Widget? child;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _RingPainter(
        value.isFinite ? value.clamp(0, 1).toDouble() : 0,
        color,
        track,
        stroke,
      ),
      child: Center(child: child),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.track, this.stroke);
  final double value, stroke;
  final Color color, track;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, 6.283185307179586, false, paint..color = track);
    if (value > 0) {
      canvas.drawArc(
        arc,
        -1.5707963267948966,
        6.283185307179586 * value,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      value != old.value ||
      color != old.color ||
      track != old.track ||
      stroke != old.stroke;
}

/// Period start → valuation date → due date. The valuation dot sits at its
/// real position between the ends; the three captions are spread evenly so
/// they can never overlap.
class FinanceTimeline extends StatelessWidget {
  const FinanceTimeline({
    super.key,
    required this.start,
    required this.asOf,
    required this.due,
  });
  final LedgerDate start, asOf, due;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final total = start.daysUntil(due);
    final fraction = total <= 0
        ? 0.0
        : (start.daysUntil(asOf) / total).clamp(0, 1).toDouble();
    Widget caption(String label, LedgerDate date, TextAlign align) => Expanded(
      child: Column(
        crossAxisAlignment: switch (align) {
          TextAlign.center => CrossAxisAlignment.center,
          TextAlign.end => CrossAxisAlignment.end,
          _ => CrossAxisAlignment.start,
        },
        children: [
          Text(
            label,
            textAlign: align,
            style: TextStyle(fontSize: 12, color: p.text2),
          ),
          Text(
            date.toString(),
            textAlign: align,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: p.text,
              fontFeatures: kTabularFigures,
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 24,
          child: CustomPaint(
            painter: _TimelinePainter(
              fraction,
              p.primary,
              p.fill,
              p.surface,
              p.text3,
            ),
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, box) {
            // Three dates side by side need ~90 px each; under large text or on
            // a narrow screen list them as caption-left / date-right lines.
            final scale = MediaQuery.textScalerOf(context).scale(1);
            if (box.maxWidth / 3 < 92 * scale) {
              return Column(
                children: [
                  for (final item in [
                    (l10n.r3FinanceTimelineStart, start),
                    (l10n.r3FinanceTimelineAsOf, asOf),
                    (l10n.r3FinanceTimelineDue, due),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          children: [
                            Text(
                              item.$1,
                              style: TextStyle(fontSize: 12, color: p.text2),
                            ),
                            Text(
                              item.$2.toString(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: p.text,
                                fontFeatures: kTabularFigures,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                caption(l10n.r3FinanceTimelineStart, start, TextAlign.start),
                caption(l10n.r3FinanceTimelineAsOf, asOf, TextAlign.center),
                caption(l10n.r3FinanceTimelineDue, due, TextAlign.end),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter(
    this.fraction,
    this.color,
    this.track,
    this.surface,
    this.endColor,
  );
  final double fraction;
  final Color color, track, surface, endColor;
  @override
  void paint(Canvas canvas, Size size) {
    const inset = 7.0;
    final y = size.height / 2;
    final left = inset, right = size.width - inset;
    final x = left + (right - left) * fraction;
    final line = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(left, y), Offset(right, y), line..color = track);
    if (x > left) {
      canvas.drawLine(Offset(left, y), Offset(x, y), line..color = color);
    }
    canvas.drawCircle(Offset(left, y), 5, Paint()..color = color);
    canvas.drawCircle(Offset(right, y), 5, Paint()..color = endColor);
    canvas.drawCircle(Offset(x, y), 10, Paint()..color = color);
    canvas.drawCircle(Offset(x, y), 5, Paint()..color = surface);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      fraction != old.fraction ||
      color != old.color ||
      track != old.track ||
      surface != old.surface ||
      endColor != old.endColor;
}

/// Hero of the calculation result: gradient card with the big remaining value,
/// the converted amount and a ring for the unused part of the shown period.
class CalculationHero extends StatelessWidget {
  const CalculationHero({
    super.key,
    required this.value,
    required this.fx,
    required this.asOf,
  });
  final Valuation value;
  final FxSettings fx;
  final LedgerDate asOf;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final ratio = value.ratio.toDouble().clamp(0, 1).toDouble();
    final percent = (ratio * 100).toStringAsFixed(1);
    final periodLabel = valuationPeriodLabel(
      asOf: asOf,
      start: value.activePeriod.start,
      end: value.activePeriod.end,
      l10n: l10n,
    );
    const white = TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        key: const ValueKey('calculation-hero'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: financeHeroColors(p),
            stops: const [0, .55, 1],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    child: Text(
                      l10n.financeEstimatedOnly,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(l10n.financeValueTitle, style: white),
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${value.amount.formatted} ${value.amount.currency}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.5,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                ),
              ),
              Text(
                convertedAmount(value.amount, fx, l10n: l10n),
                style: white.copyWith(
                  color: Colors.white.withValues(alpha: .9),
                ),
              ),
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final scale = MediaQuery.textScalerOf(context).scale(1);
                      final ring = FinanceRing(
                        key: const ValueKey('calculation-ring'),
                        value: ratio,
                        size: 76,
                        stroke: 8,
                        color: Colors.white,
                        track: Colors.white.withValues(alpha: .28),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: FittedBox(
                            child: Text(
                              '$percent%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                fontFeatures: kTabularFigures,
                              ),
                            ),
                          ),
                        ),
                      );
                      final text = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.financePeriodProgress(
                              periodLabel,
                              percent,
                              value.activeRemaining,
                              value.days,
                            ),
                            style: white,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.financePeriodDates(
                              value.activePeriod.start.toString(),
                              value.activePeriod.end.toString(),
                            ),
                            style: white.copyWith(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: .85),
                            ),
                          ),
                        ],
                      );
                      // Large text / narrow screen: ring above the text.
                      if ((box.maxWidth - 90) / scale < 170) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [ring, const SizedBox(height: 10), text],
                        );
                      }
                      return Row(
                        children: [
                          ring,
                          const SizedBox(width: 14),
                          Expanded(child: text),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figures under the hero: timeline, key numbers and the renewal terms.
class CalculationDetails extends StatelessWidget {
  const CalculationDetails({
    super.key,
    required this.value,
    required this.renewal,
    required this.cycleMonths,
    required this.due,
    required this.asOf,
  });
  final Valuation value;
  final Money renewal;
  final int cycleMonths;
  final LedgerDate due, asOf;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FinanceTimeline(
            start: value.activePeriod.start,
            asOf: asOf,
            due: due,
          ),
          const SizedBox(height: 16),
          AppMetricStrip(
            metrics: [
              AppMetric(
                label: l10n.r2CopyMetricDaysLeft,
                value: l10n.financeDaysValue(value.remainingDays),
              ),
              AppMetric(
                label: l10n.r2CopyMetricDaily,
                value:
                    '${formatRational(value.dailyMinor, digits: 4)} ${renewal.currency}',
              ),
            ],
          ),
          FinanceLine(
            l10n.financeRenewalCycle,
            l10n.financeRenewalValue(
              renewal.formatted,
              renewal.currency,
              cycleMonths,
            ),
          ),
          if (value.futurePeriods > 0)
            FinanceNote(
              l10n.financeFuturePeriodsNote(value.futurePeriods),
              padding: const EdgeInsets.only(top: 2),
            ),
          if (value.inferred)
            FinanceNote(
              l10n.financeInferredPeriods,
              padding: const EdgeInsets.only(top: 4),
            ),
          FinanceNote(
            l10n.financeValueDisclaimer,
            padding: const EdgeInsets.only(top: 4),
          ),
        ],
      ),
    );
  }
}
