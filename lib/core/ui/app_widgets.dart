import 'package:flutter/material.dart';

import '../app_palette.dart';
import 'app_list.dart';
import 'app_overlays.dart';

/// Rounded surface block (radius 14, no border) for free-form content such as
/// the cost summary on the detail page. For lists of rows use [AppSection].
///
/// ```dart
/// AppCard(child: Column(children: […]))
/// AppCard(onTap: open, margin: EdgeInsets.zero, child: …)
/// ```
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.onTap,
    this.color,
  });

  final Widget child;

  /// Inner padding (default 16).
  final EdgeInsetsGeometry padding;

  /// Outer margin (default 16 horizontally, matching the page margin).
  final EdgeInsetsGeometry margin;

  /// Makes the whole card tappable with a pressed highlight.
  final VoidCallback? onTap;

  /// Background override (defaults to the surface colour).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final content = Padding(padding: padding, child: child);
    return Padding(
      padding: margin,
      child: Material(
        color: color ?? p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// Small rounded status label.
///
/// ```dart
/// StatusPill('Expired 2 days', tone: AppTone.red, dot: true)
/// StatusPill('30 days', tone: AppTone.amber)
/// ```
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.text, {
    super.key,
    this.tone = AppTone.neutral,
    this.dot = false,
    this.icon,
  });

  final String text;
  final AppTone tone;

  /// Shows a 6 px dot before the text (used for red / amber urgency).
  final bool dot;

  /// Optional small leading glyph (12 px).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = context.palette.tone(tone);
    return Container(
      constraints: const BoxConstraints(minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: fg,
                fontFeatures: kTabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin rounded progress bar (service-period / usage).
///
/// ```dart
/// AppProgressBar(value: .92, tone: AppTone.amber)
/// ```
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.tone = AppTone.blue,
    this.height = 8,
  });

  /// 0–1.
  final double value;
  final AppTone tone;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = switch (tone) {
      AppTone.amber => p.amberSolid,
      AppTone.red => p.red,
      AppTone.green => p.green,
      AppTone.neutral => p.text3,
      AppTone.blue => p.primary,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: ColoredBox(
          color: p.fill,
          child: FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: value.clamp(0.0, 1.0),
            child: ColoredBox(color: color),
          ),
        ),
      ),
    );
  }
}

/// Inline notice (amber warning, info). Tappable banners show a chevron.
///
/// ```dart
/// AppBanner(tone: AppTone.amber, icon: Icons.warning_amber_rounded,
///     text: l10n.missingRates, onTap: openRates)
/// ```
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.text,
    this.icon,
    this.tone = AppTone.neutral,
    this.onTap,
    this.action,
    this.margin = const EdgeInsets.fromLTRB(16, 10, 16, 0),
  });

  final String text;
  final IconData? icon;
  final AppTone tone;
  final VoidCallback? onTap;

  /// Trailing control with its own tap target (e.g. an ⓘ button); it sits
  /// where the chevron would be, so give it a 44 pt box.
  final Widget? action;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = context.palette.tone(tone);
    return Padding(
      padding: margin,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              12,
              action == null ? 10 : 0,
              action == null ? 12 : 2,
              action == null ? 10 : 0,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: action == null ? 0 : 10,
                    ),
                    child: Text(
                      text,
                      style: TextStyle(fontSize: 13.5, height: 1.35, color: fg),
                    ),
                  ),
                ),
                ?action,
                if (onTap != null && action == null) ...[
                  const SizedBox(width: 8),
                  AppChevron(color: fg.withValues(alpha: .7), size: 13),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty / first-run state: tinted icon tile, title, message and stacked
/// actions (usually [AppButton]s with `expand: true`).
///
/// ```dart
/// AppEmptyState(
///   icon: Icons.dns_outlined,
///   title: l10n.firstServerTitle,
///   message: l10n.firstServerBody,
///   actions: [AppButton(label: l10n.addManually, expand: true, onPressed: add)],
/// )
/// ```
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.messageAccessory,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String? message;

  /// Small control after the message (e.g. an ⓘ button, 44 pt).
  final Widget? messageAccessory;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 40, 30, 0),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: p.primarySoft,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(icon, size: 46, color: p.primary),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: p.text,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.55,
                      color: p.text2,
                    ),
                  ),
                ),
                ?messageAccessory,
              ],
            ),
          ],
          if (actions.isNotEmpty) const SizedBox(height: 26),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: actions[i]),
          ],
        ],
      ),
    );
  }
}

/// Footnote-style "ⓘ label" link that opens the long explanation in a sheet,
/// so rarely needed detail does not take page space.
///
/// ```dart
/// AppInfoLink(label: l10n.credentialHandling, title: l10n.credentialHandling,
///     message: l10n.credentialHandlingBody)
/// ```
class AppInfoLink extends StatelessWidget {
  const AppInfoLink({
    super.key,
    required this.label,
    required this.message,
    this.title,
    this.padding = const EdgeInsets.fromLTRB(32, 8, 32, 0),
  });

  /// Text next to the ⓘ icon.
  final String label;

  /// Explanation shown in the sheet.
  final String message;

  /// Sheet title (defaults to [label]).
  final String? title;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: padding,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => showAppSheet<void>(
              context,
              title: title ?? label,
              builder: (sheetContext) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(
                  message,
                  style: TextStyle(fontSize: 15, height: 1.5, color: p.text),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: p.primary),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: p.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
