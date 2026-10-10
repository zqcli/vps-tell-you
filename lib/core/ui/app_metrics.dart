import 'package:flutter/material.dart';

import '../app_palette.dart';

/// One figure of an [AppMetricStrip]: a short [label] above a [value].
class AppMetric {
  const AppMetric({required this.label, required this.value, this.valueColor});

  /// Short caption (one word or two, e.g. "Days left").
  final String label;

  /// Pre-formatted figure ("$12.40", "7 days"). Never an empty string: render
  /// unknown figures as "—" so columns stay aligned.
  final String value;

  /// Overrides the primary text colour (for example red for "overdue").
  final Color? valueColor;
}

/// A row of 2–4 small KPIs, the iOS "summary strip" used by Health, Stocks and
/// Wallet. This is the rule for *every* "several small figures side by side"
/// situation – do not hand-roll `Row`s of `Column`s.
///
/// * Equal-width columns separated by 0.5 px hairlines.
/// * Every column is start-aligned: caption (13, secondary) above the figure
///   (17, semibold, tabular digits), so captions and figures share baselines
///   across columns.
/// * Text-scale / narrow-screen fallback, measured with the real text metrics:
///   one row → rows of two columns → a single column of
///   caption-left / figure-right lines. A figure is never clipped or wrapped.
///
/// Put it inside an [AppCard] (it has no surface or margin of its own).
///
/// ```dart
/// AppMetricStrip(metrics: [
///   AppMetric(label: l10n.remainingValue, value: r'$12.40'),
///   AppMetric(label: l10n.daysLeft, value: l10n.days(7)),
///   AppMetric(label: l10n.daily, value: r'$0.1370'),
/// ])
/// ```
class AppMetricStrip extends StatelessWidget {
  const AppMetricStrip({super.key, required this.metrics});

  final List<AppMetric> metrics;

  static const _gutter = 12.0;
  static const _labelSize = 13.0;
  static const _valueSize = 17.0;

  static TextStyle _labelStyle(AppPalette p) =>
      TextStyle(fontSize: _labelSize, height: 1.3, color: p.text2);

  static TextStyle _valueStyle(AppPalette p, Color? color) => TextStyle(
    fontSize: _valueSize,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: color ?? p.text,
    fontFeatures: kTabularFigures,
  );

  @override
  Widget build(BuildContext context) {
    assert(metrics.isNotEmpty);
    final p = context.palette;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final base = DefaultTextStyle.of(context).style;

    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: base.merge(style)),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      // 2 % head-room for font-fallback differences between measure and paint.
      return width * 1.02;
    }

    final labels = [for (final m in metrics) measure(m.label, _labelStyle(p))];
    final values = [
      for (final m in metrics) measure(m.value, _valueStyle(p, m.valueColor)),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        bool fits(int columns) {
          if (columns == 1) return true;
          final rowCount = (metrics.length / columns).ceil();
          for (var row = 0; row < rowCount; row++) {
            final cells = metrics.length - row * columns < columns
                ? metrics.length - row * columns
                : columns;
            // Equal columns, even for a short last row.
            final cell = (box.maxWidth - (columns - 1) * .5) / columns;
            for (var i = 0; i < cells; i++) {
              final index = row * columns + i;
              final inner =
                  cell -
                  (i > 0 ? _gutter : 0) -
                  (i < columns - 1 ? _gutter : 0);
              if (labels[index] > inner || values[index] > inner) return false;
            }
          }
          return true;
        }

        final candidates = <int>{
          if (metrics.length <= 4) metrics.length,
          if (metrics.length > 2) 2,
        };
        final columns = [
          for (final c in candidates.toList()..sort((a, b) => b.compareTo(a)))
            if (fits(c)) c,
        ].firstOrNull;

        Widget hairline(Axis axis) => SizedBox(
          width: axis == Axis.vertical ? .5 : null,
          height: axis == Axis.horizontal ? .5 : null,
          child: ColoredBox(color: p.separator),
        );

        Widget semantic(AppMetric m, Widget child) => Semantics(
          container: true,
          label: '${m.label} ${m.value}',
          excludeSemantics: true,
          child: child,
        );

        if (columns == null) {
          // Single column: caption left, figure right.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                if (i > 0) hairline(Axis.horizontal),
                semantic(
                  metrics[i],
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(metrics[i].label, style: _labelStyle(p)),
                        ),
                        const SizedBox(width: _gutter),
                        // Figure first (non-flex) so the caption wraps, never
                        // the figure.
                        Text(
                          metrics[i].value,
                          textAlign: TextAlign.end,
                          style: _valueStyle(p, metrics[i].valueColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        }

        Widget cell(int index, int column) => Expanded(
          child: semantic(
            metrics[index],
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: column > 0 ? _gutter : 0,
                end: column < columns - 1 ? _gutter : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    metrics[index].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _labelStyle(p),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    metrics[index].value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _valueStyle(p, metrics[index].valueColor),
                  ),
                ],
              ),
            ),
          ),
        );

        final rowCount = (metrics.length / columns).ceil();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var row = 0; row < rowCount; row++) ...[
              if (row > 0) const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < columns; c++) ...[
                      if (c > 0) hairline(Axis.vertical),
                      if (row * columns + c < metrics.length)
                        cell(row * columns + c, c)
                      else
                        const Expanded(child: SizedBox.shrink()),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
