import 'package:flutter/material.dart';

import '../l10n/locale_preference.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/ui/ui.dart';
import 'finance_models.dart';

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

/// A validated date in a grouped form row, picked from the date sheet.
///
/// [controller] holds the ISO date (empty = unknown); the owner changes it
/// from [onTap]. The row redraws whenever the controller changes.
class FinanceDateRow extends FormField<String> {
  FinanceDateRow({
    super.key,
    required this.controller,
    required this.label,
    String? Function(String text)? check,
    required VoidCallback onTap,
  }) : super(
         validator: check == null ? null : (_) => check(controller.text),
         builder: (state) => ValueListenableBuilder<TextEditingValue>(
           valueListenable: controller,
           builder: (context, value, _) {
             final p = context.palette;
             final text = value.text.trim();
             return AppFormRow(
               label: label,
               errorText: state.errorText,
               onTap: onTap,
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Flexible(
                     // Never wrap an ISO date: shrink it instead.
                     child: FittedBox(
                       fit: BoxFit.scaleDown,
                       alignment: AlignmentDirectional.centerEnd,
                       child: Text(
                         text.isEmpty ? context.l10n.financeUnknown : text,
                         maxLines: 1,
                         softWrap: false,
                         style: TextStyle(
                           fontSize: 16,
                           color: text.isEmpty ? p.text3 : p.text,
                           fontFeatures: kTabularFigures,
                         ),
                       ),
                     ),
                   ),
                   const SizedBox(width: 8),
                   Icon(
                     Icons.calendar_today_outlined,
                     size: 18,
                     color: p.text2,
                   ),
                 ],
               ),
             );
           },
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

  String get _originals => total.originals.entries
      .map((e) => '${e.key} ${formatRational(e.value)}')
      .join(' · ');

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
          Text(l10n.financeOriginalSubtotals(_originals), style: white),
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
              context.l10n.financeOriginalSubtotals(_originals),
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
