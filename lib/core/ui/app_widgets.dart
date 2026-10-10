import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoSearchTextField,
        CupertinoSlidingSegmentedControl;
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

/// Rounded-square provider avatar with a stable colour derived from the
/// name, initials (or an explicit [mark]) and an optional favourite star.
///
/// ```dart
/// ProviderAvatar(name: 'DigitalOcean', starred: server.favorite)
/// ProviderAvatar(name: 'BandwagonHost', mark: 'BWG', size: 60)
/// ProviderAvatar(name: null) // grey "?" for an unspecified provider
/// ```
///
/// When used as `AppRow.leading` the separator inset follows [size].
class ProviderAvatar extends StatelessWidget implements AppLeading {
  const ProviderAvatar({
    super.key,
    required this.name,
    this.mark,
    this.size = 42,
    this.starred = false,
    this.color,
  });

  /// Provider name; `null` / empty gives a grey "?".
  final String? name;

  /// Explicit 1–3 character mark; derived from [name] when null.
  final String? mark;

  /// Edge length: 42 in lists, 60 in the detail header.
  final double size;

  /// Draws the amber favourite badge at the bottom-right corner.
  final bool starred;

  /// Overrides the hashed colour.
  final Color? color;

  static const _colors = <Color>[
    Color(0xFFF07A2A),
    Color(0xFF1F7AE0),
    Color(0xFF22A06B),
    Color(0xFF6D5AE6),
    Color(0xFFD6334A),
    Color(0xFF0E9F9A),
    Color(0xFFC2410C),
    Color(0xFF8B5CF6),
    Color(0xFF0F766E),
    Color(0xFFDB2777),
  ];

  /// Stable colour for [name] (FNV-1a hash, independent of the Dart VM).
  static Color colorFor(String? name) {
    final text = name?.trim() ?? '';
    if (text.isEmpty) return AppTints.grey;
    var hash = 0x811c9dc5;
    for (final unit in text.toLowerCase().codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return _colors[hash % _colors.length];
  }

  /// Initials for [name]: CJK → first character; "RackNerd" → "RN";
  /// "Hetzner" → "He"; empty → "?".
  static String initialsFor(String? name) {
    final text = name?.trim() ?? '';
    if (text.isEmpty) return '?';
    final first = text.runes.first;
    if (first >= 0x2E80) return String.fromCharCode(first);
    final words = text
        .split(RegExp(r'[\s_\-.]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length >= 2) {
      return (words[0][0] + words[1][0]).toUpperCase();
    }
    final capitals = RegExp('[A-Z]').allMatches(words.first).toList();
    if (capitals.length >= 2) {
      return capitals.take(2).map((m) => m.group(0)!).join();
    }
    final word = words.first;
    if (word.length <= 3 && word == word.toUpperCase()) return word;
    return word.length == 1
        ? word.toUpperCase()
        : word[0].toUpperCase() + word[1].toLowerCase();
  }

  @override
  double get leadingExtent => size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final label = (mark != null && mark!.isNotEmpty)
        ? mark!
        : initialsFor(name);
    final badge = size * 17 / 42;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color ?? colorFor(name),
                borderRadius: BorderRadius.circular(size * .26),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size * .31,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (starred)
            Positioned(
              right: -size * 4 / 42,
              bottom: -size * 4 / 42,
              child: Container(
                width: badge,
                height: badge,
                decoration: BoxDecoration(
                  color: p.surface,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.star_rounded,
                  size: badge * .75,
                  color: p.amberSolid,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// iOS search field (grey rounded fill, magnifier, clear button).
///
/// ```dart
/// AppSearchField(controller: query, placeholder: l10n.searchServers,
///     onChanged: (_) => setState(() {}))
/// ```
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  final TextEditingController? controller;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Outer margin (default 16 horizontally).
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: margin,
      child: CupertinoSearchTextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        placeholder: placeholder,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        backgroundColor: p.fill,
        borderRadius: BorderRadius.circular(11),
        itemColor: p.text2,
        itemSize: 18,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: const Icon(Icons.cancel_rounded),
        padding: const EdgeInsetsDirectional.fromSTEB(8, 9, 8, 9),
        style: TextStyle(fontSize: 16, color: p.text),
        placeholderStyle: TextStyle(fontSize: 16, color: p.text2),
      ),
    );
  }
}

/// Sliding iOS segmented control.
///
/// ```dart
/// AppSegmented<String>(
///   options: const {'provider': 'Provider', 'group': 'Group'},
///   value: split,
///   onChanged: (v) => setState(() => split = v),
/// )
/// AppSegmented<Unit>(compact: true, …) // inside an AppFormRow
/// ```
class AppSegmented<T extends Object> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.compact = false,
    this.margin,
  });

  /// Ordered map of value → label.
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Smaller control for inline use inside form rows (unit pickers).
  final bool compact;

  /// Outer margin. Defaults to 16 horizontally when full-width and none when
  /// [compact].
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final control = CupertinoSlidingSegmentedControl<T>(
      groupValue: options.containsKey(value) ? value : null,
      backgroundColor: p.fill,
      thumbColor: p.segmentThumb,
      padding: const EdgeInsets.all(2),
      onValueChanged: (v) {
        if (v != null && v != value) onChanged(v);
      },
      children: {
        for (final e in options.entries)
          e.key: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 9 : 6,
              vertical: compact ? 4 : 6,
            ),
            child: Text(
              e.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 13 : 13.5,
                fontWeight: e.key == value ? FontWeight.w600 : FontWeight.w500,
                color: p.text,
              ),
            ),
          ),
      },
    );
    return Padding(
      padding:
          margin ??
          (compact
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 16)),
      child: compact ? IntrinsicWidth(child: control) : control,
    );
  }
}

/// − / + stepper in a grey capsule.
///
/// ```dart
/// AppStepper(value: vcpu, min: 1, max: 128, onChanged: (v) => setState(() => vcpu = v))
/// ```
class AppStepper extends StatelessWidget {
  const AppStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.step = 1,
    this.format,
    this.decrementLabel,
    this.incrementLabel,
    this.decrementKey,
    this.incrementKey,
  });

  final int value;

  /// `null` disables both buttons.
  final ValueChanged<int>? onChanged;
  final int min, max, step;

  /// Custom text for the value (defaults to the number).
  final String Function(int value)? format;

  /// Accessibility labels of the two buttons.
  final String? decrementLabel, incrementLabel;
  final Key? decrementKey, incrementKey;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget button(
      Key? key,
      IconData icon,
      String? label,
      bool enabled,
      int target,
    ) => Semantics(
      label: label,
      button: true,
      enabled: enabled,
      excludeSemantics: label != null,
      child: InkWell(
        key: key,
        onTap: enabled ? () => onChanged!(target) : null,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 36,
          height: 30,
          child: Icon(icon, size: 18, color: enabled ? p.text : p.text3),
        ),
      ),
    );
    final live = onChanged != null;
    return Material(
      color: p.fill,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            decrementKey,
            Icons.remove_rounded,
            decrementLabel,
            live && value - step >= min,
            (value - step).clamp(min, max),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 28),
            child: Text(
              format?.call(value) ?? '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: p.text,
                fontFeatures: kTabularFigures,
              ),
            ),
          ),
          button(
            incrementKey,
            Icons.add_rounded,
            incrementLabel,
            live && value + step <= max,
            (value + step).clamp(min, max),
          ),
        ],
      ),
    );
  }
}

/// Filter pill. Selected = dark filled (inverted text / surface colours).
///
/// ```dart
/// AppChipRow(children: [
///   AppChip(label: l10n.all, count: 6, selected: f == 0, onTap: () => set(0)),
///   AppChip(label: l10n.filter, icon: Icons.tune_rounded, outlined: true, onTap: openSheet),
/// ])
/// ```
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.count,
    this.icon,
    this.outlined = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Small secondary number after the label.
  final int? count;
  final IconData? icon;

  /// Transparent pill with a hairline ring (the "Filter" button of the demo).
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = selected ? p.surface : (outlined ? p.text2 : p.text);
    final bg = selected ? p.text : (outlined ? Colors.transparent : p.surface);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: bg,
        shape: StadiumBorder(
          side: outlined && !selected
              ? BorderSide(color: p.separator)
              : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: fg),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: fg,
                      ),
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 5),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: selected ? fg.withValues(alpha: .7) : p.text2,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
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

/// Horizontally scrolling row of [AppChip]s that bleeds to the screen edges.
class AppChipRow extends StatelessWidget {
  const AppChipRow({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 4),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    physics: const BouncingScrollPhysics(),
    padding: padding,
    child: Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          children[i],
        ],
      ],
    ),
  );
}

/// Number + caption tile (expired / due soon / monthly cost).
///
/// ```dart
/// AppStatGrid(children: [
///   AppStatTile(value: '1', label: l10n.expired, tone: AppTone.red, onTap: …),
///   AppStatTile(value: '2', label: l10n.dueSoon, tone: AppTone.amber),
///   AppStatTile(value: '¥184', label: l10n.monthly, compactValue: true),
/// ])
/// ```
class AppStatTile extends StatelessWidget {
  const AppStatTile({
    super.key,
    required this.value,
    required this.label,
    this.tone = AppTone.neutral,
    this.onTap,
    this.compactValue = false,
  });

  final String value;
  final String label;

  /// Colours the number and shows a matching dot before [label] (red / amber).
  final AppTone tone;
  final VoidCallback? onTap;

  /// Smaller number (20 instead of 24) for currency amounts.
  final bool compactValue;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final coloured = tone == AppTone.red || tone == AppTone.amber;
    final valueColor = coloured ? p.tone(tone).$1 : p.text;
    final dot = tone == AppTone.red
        ? p.red
        : tone == AppTone.amber
        ? p.amberSolid
        : null;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: compactValue ? 20 : 24,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  if (dot != null) ...[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 12, color: p.text2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Equal-width row of [AppStatTile]s (10 px gap, 16 px page margin).
class AppStatGrid extends StatelessWidget {
  const AppStatGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: children[i]),
          ],
        ],
      ),
    ),
  );
}

/// Circular-icon quick action tile (detail page: SSH, TCP, payment, power).
///
/// A [dimmed] action looks disabled but still calls [onTap], so the page can
/// explain why it is unavailable.
///
/// ```dart
/// AppQuickActionRow(children: [
///   AppQuickAction(icon: Icons.terminal, label: 'SSH', onTap: ssh),
///   AppQuickAction(icon: Icons.power_settings_new, label: l10n.power,
///       tone: AppTone.red, dimmed: !canPower, onTap: power),
/// ])
/// ```
class AppQuickAction extends StatelessWidget {
  const AppQuickAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.tone = AppTone.blue,
    this.dimmed = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// [AppTone.blue] (default) or [AppTone.red] for the power action.
  final AppTone tone;

  /// Grey "unavailable" look; taps are still delivered.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (fg, bg) = dimmed ? (p.text3, p.fill2) : _colors(p);
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: fg),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.25,
                  color: dimmed ? p.text3 : p.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (Color, Color) _colors(AppPalette p) => switch (tone) {
    AppTone.red => (p.red, p.redSoft),
    AppTone.green => (p.green, p.greenSoft),
    AppTone.amber => (p.amber, p.amberSoft),
    _ => (p.primary, p.primarySoft),
  };
}

/// Equal-width row of [AppQuickAction]s (8 px gap).
class AppQuickActionRow extends StatelessWidget {
  const AppQuickActionRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: children[i]),
          ],
        ],
      ),
    ),
  );
}

/// Visual weight of an [AppButton].
enum AppButtonKind { primary, tonal, plain }

/// Flat rounded button (radius 14, height 50; [compact]: radius 10, 40).
/// There are no outlined buttons in the design.
///
/// ```dart
/// AppButton(label: l10n.addManually, icon: Icons.edit_outlined, onPressed: add)
/// AppButton(label: l10n.delete, kind: AppButtonKind.tonal, destructive: true, onPressed: del)
/// ```
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AppButtonKind.primary,
    this.icon,
    this.compact = false,
    this.expand = false,
    this.destructive = false,
    this.busy = false,
  });

  final String label;

  /// `null` renders the disabled look.
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final IconData? icon;

  /// Smaller button for use inside cards.
  final bool compact;

  /// Take the full available width (wraps in an infinite-width box).
  final bool expand;

  /// Red colours instead of the brand colours.
  final bool destructive;

  /// Shows an activity indicator and ignores taps.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (Color fg, Color bg) = switch (kind) {
      AppButtonKind.primary =>
        destructive ? (Colors.white, p.red) : (p.onPrimary, p.primary),
      AppButtonKind.tonal =>
        destructive ? (p.red, p.redSoft) : (p.onPrimarySoft, p.primarySoft),
      AppButtonKind.plain => (
        destructive ? p.red : p.primary,
        Colors.transparent,
      ),
    };
    final active = onPressed != null && !busy;
    final radius = BorderRadius.circular(compact ? 10 : 14);
    final button = Opacity(
      opacity: onPressed == null ? .4 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: active ? onPressed : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 40 : 50),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 14 : 20,
                vertical: 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: CupertinoActivityIndicator(radius: 8, color: fg),
                    )
                  else if (icon != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: Icon(icon, size: compact ? 18 : 20, color: fg),
                    ),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: compact ? 14 : 16,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: fg,
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
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
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
    this.margin = const EdgeInsets.fromLTRB(16, 10, 16, 0),
  });

  final String text;
  final IconData? icon;
  final AppTone tone;
  final VoidCallback? onTap;
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(fontSize: 13.5, height: 1.35, color: fg),
                  ),
                ),
                if (onTap != null) ...[
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
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String? message;
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
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.55, color: p.text2),
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
