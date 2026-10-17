import 'package:flutter/material.dart';

import '../app_palette.dart';
import 'app_form.dart';

/// Implemented by leading widgets ([AppIconSquare], `ProviderAvatar`) so that
/// [AppRow] can inset the separator to the start of the title text.
abstract interface class AppLeading {
  /// Width of the leading widget in logical pixels.
  double get leadingExtent;
}

/// Implemented by widgets placed in an [AppSection] that want a custom
/// separator inset. Widgets that do not implement it get the default 16.
abstract interface class AppSectionItem {
  /// Left inset of the hairline drawn above this item.
  double get separatorInset;
}

/// Thin iOS chevron (›) used at the end of navigation rows.
class AppChevron extends StatelessWidget {
  const AppChevron({super.key, this.color, this.size = 14});

  /// Defaults to the tertiary text colour.
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => Icon(
    Icons.arrow_forward_ios_rounded,
    size: size,
    color: color ?? context.palette.text3,
    // Mirrors automatically in right-to-left locales.
    textDirection: Directionality.of(context),
  );
}

/// Coloured rounded square with a white glyph (settings / tools rows).
///
/// ```dart
/// AppIconSquare(icon: Icons.folder_outlined, color: AppTints.orange)
/// ```
class AppIconSquare extends StatelessWidget implements AppLeading {
  const AppIconSquare({
    super.key,
    required this.icon,
    this.color = AppTints.blue,
    this.size = 30,
  });

  final IconData icon;

  /// Background; see [AppTints] for the palette used by the demo.
  final Color color;

  /// Edge length. Rows use 30, tool tiles 38.
  final double size;

  @override
  double get leadingExtent => size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size * .27),
    ),
    alignment: Alignment.center,
    child: Icon(icon, size: size * .6, color: Colors.white),
  );
}

/// Small text button used for section header actions ("Edit", "All").
class AppLinkButton extends StatelessWidget {
  const AppLinkButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: onPressed == null ? p.text3 : p.primary,
          ),
        ),
      ),
    );
  }
}

/// Header line: [title] at the start and [action] always flush at the end.
///
/// Both children are flexible, so a long title or action shrinks (ellipsises)
/// instead of pushing the action away or overflowing; above 1.5× text scale
/// the action moves to its own line, still flush right. Used
/// by [AppSection] headers and by custom list headers (e.g. "All servers ·
/// Sort"). Put the text style on the children.
class AppHeaderRow extends StatelessWidget {
  const AppHeaderRow({super.key, required this.title, this.action});

  final Widget title;

  /// Right-hand widget (link button, sort button …).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    if (action == null) {
      return Align(alignment: AlignmentDirectional.centerStart, child: title);
    }
    // Very large text: the action gets its own line (still flush right)
    // rather than truncating its label.
    if (MediaQuery.textScalerOf(context).scale(1) > 1.5) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          Align(alignment: AlignmentDirectional.centerEnd, child: action),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(child: title),
        const SizedBox(width: 12),
        Flexible(child: action),
      ],
    );
  }
}

/// iOS inset-grouped list section: optional small grey header, a rounded
/// group (radius 14, no border) with inset hairline separators, and an
/// optional footnote underneath.
///
/// Children are usually [AppRow], [AppFormRow], [AppKeyValueRow] or
/// [AppSwitchRow]; any widget is allowed (it gets a 16 px separator inset
/// unless it implements [AppSectionItem]). The section already includes the
/// 16 px horizontal page margin.
///
/// ```dart
/// AppSection(
///   header: l10n.ledger,
///   footer: l10n.groupsHelp,
///   children: [
///     AppRow(icon: Icons.folder_outlined, iconColor: AppTints.orange,
///         title: 'Groups', value: '3', chevron: true, onTap: openGroups),
///   ],
/// )
/// ```
class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    this.header,
    this.headerAction,
    this.footer,
    this.footerWidget,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.topSpacing,
    this.dividers = true,
  });

  /// Small grey title above the group.
  final String? header;

  /// Widget aligned to the right of the header, e.g. [AppLinkButton].
  final Widget? headerAction;

  /// Footnote text under the group (12.5 px, secondary colour).
  final String? footer;

  /// Footnote as a widget (use instead of [footer] for rich content).
  final Widget? footerWidget;

  final List<Widget> children;

  /// Outer horizontal margin (default 16). Use [EdgeInsets.zero] when nesting
  /// the section inside an already padded container such as a sheet body that
  /// provides its own padding.
  final EdgeInsetsGeometry margin;

  /// Space above the section. Defaults to 22 when there is a header and 16
  /// otherwise.
  final double? topSpacing;

  /// Draw hairlines between children (default true).
  final bool dividers;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasHeader = header != null || headerAction != null;
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      if (i > 0 && dividers) {
        final inset = child is AppSectionItem
            ? (child as AppSectionItem).separatorInset
            : 16.0;
        items.add(
          Padding(
            padding: EdgeInsetsDirectional.only(start: inset),
            child: SizedBox(height: .5, child: ColoredBox(color: p.separator)),
          ),
        );
      }
      items.add(child);
    }
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader)
            Padding(
              padding: EdgeInsets.fromLTRB(16, topSpacing ?? 22, 16, 7),
              child: AppHeaderRow(
                title: Text(
                  header ?? '',
                  style: TextStyle(fontSize: 13, color: p.text2),
                ),
                action: headerAction,
              ),
            )
          else
            SizedBox(height: topSpacing ?? 16),
          Material(
            color: p.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: items,
            ),
          ),
          if (footerWidget != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
              child: footerWidget,
            )
          else if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
              child: Text(footer!, style: context.footnoteStyle),
            ),
        ],
      ),
    );
  }
}

/// A row of an [AppSection]: optional leading icon square / avatar, title,
/// subtitle, trailing value text, chevron.
///
/// ```dart
/// AppRow(
///   icon: Icons.key_outlined, iconColor: AppTints.green,
///   title: l10n.security, value: '2', chevron: true, onTap: open,
/// )
/// AppRow(title: l10n.delete, destructive: true, onTap: remove)
/// AppRow(title: l10n.addServer, center: true, onTap: add) // blue centered
/// ```
class AppRow extends StatelessWidget implements AppSectionItem {
  const AppRow({
    super.key,
    this.leading,
    this.icon,
    this.iconColor = AppTints.blue,
    required this.title,
    this.subtitle,
    this.subtitleMaxLines,
    this.value,
    this.valueMaxLines = 1,
    this.trailing,
    this.chevron = false,
    this.onTap,
    this.onLongPress,
    this.destructive = false,
    this.enabled = true,
    this.center = false,
    this.mono = false,
  }) : child = null;

  /// Row chrome (padding, press highlight, min height 48) around arbitrary
  /// [child] content, for rows whose layout is too special for [AppRow].
  const AppRow.custom({
    super.key,
    required Widget this.child,
    this.leading,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.chevron = false,
    this.trailing,
  }) : icon = null,
       iconColor = AppTints.blue,
       title = '',
       subtitle = null,
       subtitleMaxLines = null,
       value = null,
       valueMaxLines = 1,
       destructive = false,
       center = false,
       mono = false;

  /// Custom leading widget (e.g. `ProviderAvatar`). Overrides [icon].
  final Widget? leading;

  /// Convenience: shows an [AppIconSquare] with [iconColor].
  final IconData? icon;
  final Color iconColor;

  final String title;
  final String? subtitle;
  final int? subtitleMaxLines;

  /// Secondary text aligned to the right (current setting value).
  final String? value;
  final int valueMaxLines;

  /// Replaces [value] with an arbitrary widget (pill, switch, …).
  final Widget? trailing;

  /// Show › after the content. Implied visually "tappable"; combine with
  /// [onTap].
  final bool chevron;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Title in red for delete / archive-type rows.
  final bool destructive;

  /// `false` dims the row and disables taps.
  final bool enabled;

  /// Centre the title in the primary colour (a "button row").
  final bool center;

  /// Monospace value text (addresses, ids).
  final bool mono;

  /// Content set by [AppRow.custom].
  final Widget? child;

  Widget? _leading() =>
      leading ??
      (icon == null ? null : AppIconSquare(icon: icon!, color: iconColor));

  @override
  double get separatorInset {
    final l = _leading();
    if (l == null) return 16;
    return 16 + (l is AppLeading ? (l as AppLeading).leadingExtent : 30) + 12;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final lead = _leading();
    final titleColor = destructive
        ? p.red
        : center
        ? p.primary
        : p.text;
    Widget body;
    if (child != null) {
      body = child!;
    } else {
      final text = Column(
        crossAxisAlignment: center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: 16,
              height: 1.3,
              color: titleColor,
              fontWeight: center ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                maxLines: subtitleMaxLines,
                overflow: subtitleMaxLines == null
                    ? null
                    : TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, height: 1.35, color: p.text2),
              ),
            ),
        ],
      );
      final side =
          trailing ??
          (value == null
              ? null
              : Text(
                  value!,
                  maxLines: valueMaxLines,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: (mono ? kMonoTextStyle : const TextStyle()).copyWith(
                    fontSize: mono ? 14 : 15,
                    color: p.text2,
                    fontFeatures: kTabularFigures,
                  ),
                ));
      body = LayoutBuilder(
        builder: (context, box) => Row(
          children: [
            Expanded(child: text),
            if (side != null) ...[
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: box.maxWidth * (trailing != null ? .6 : .5),
                ),
                child: side,
              ),
            ],
          ],
        ),
      );
    }
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (lead != null) ...[lead, const SizedBox(width: 12)],
            Expanded(
              child: Padding(
                padding: child != null || center
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(vertical: 12),
                child: body,
              ),
            ),
            if (child != null && trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
            if (chevron) ...[const SizedBox(width: 8), const AppChevron()],
          ],
        ),
      ),
    );
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? onTap : null,
          onLongPress: enabled ? onLongPress : null,
          child: content,
        ),
      ),
    );
  }
}

/// A row with a leading title and a switch on the right; tapping the row
/// toggles it.
///
/// ```dart
/// AppSwitchRow(title: l10n.reminders, value: on, onChanged: setOn)
/// ```
class AppSwitchRow extends StatelessWidget implements AppSectionItem {
  const AppSwitchRow({
    super.key,
    this.icon,
    this.iconColor = AppTints.blue,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData? icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;

  /// `null` disables the row.
  final ValueChanged<bool>? onChanged;

  @override
  double get separatorInset => icon == null ? 16 : 58;

  @override
  Widget build(BuildContext context) => AppRow(
    icon: icon,
    iconColor: iconColor,
    title: title,
    subtitle: subtitle,
    enabled: onChanged != null,
    onTap: onChanged == null ? null : () => onChanged!(!value),
    trailing: ExcludeSemantics(
      child: AppSwitch(value: value, onChanged: onChanged),
    ),
  );
}

/// Label / value row for read-only details (hostname, OS, region …).
///
/// ```dart
/// AppKeyValueRow(label: l10n.os, value: 'Debian 12')
/// AppKeyValueRow(label: l10n.address, value: ip, mono: true, onLongPress: copy)
/// ```
class AppKeyValueRow extends StatelessWidget implements AppSectionItem {
  const AppKeyValueRow({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.placeholder,
    this.mono = false,
    this.onTap,
    this.onLongPress,
    this.chevron = false,
  });

  final String label;

  /// Value text. Wraps over several lines when long.
  final String? value;

  /// Replaces [value] with a widget (pill, link …).
  final Widget? valueWidget;

  /// Text shown greyed when [value] is null or empty (e.g. "—").
  final String? placeholder;
  final bool mono;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool chevron;

  @override
  double get separatorInset => 16;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final empty = valueWidget == null && (value == null || value!.isEmpty);
    final Widget valueView =
        valueWidget ??
        Text(
          empty ? (placeholder ?? '—') : value!,
          textAlign: TextAlign.end,
          style: (mono ? kMonoTextStyle : const TextStyle()).copyWith(
            fontSize: mono ? 14 : 15,
            height: 1.35,
            color: empty ? p.text3 : p.text2,
            fontFeatures: kTabularFigures,
          ),
        );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: LayoutBuilder(
              builder: (context, box) => Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth * .45),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.3,
                        color: p.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: valueView,
                    ),
                  ),
                  if (chevron) ...[
                    const SizedBox(width: 8),
                    const AppChevron(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
