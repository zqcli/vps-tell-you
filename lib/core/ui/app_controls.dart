import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoSearchTextField,
        CupertinoSlidingSegmentedControl;
import 'package:flutter/material.dart';

import '../app_palette.dart';
import 'app_glass.dart';

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
    // iOS 26: the field is a glass capsule; before that a grey rounded fill.
    final liquid = context.glassStyle.isLiquid;
    final field = CupertinoSearchTextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      placeholder: placeholder,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      backgroundColor: liquid ? Colors.transparent : p.fill,
      borderRadius: liquid ? AppGlass.capsule : BorderRadius.circular(11),
      itemColor: p.text2,
      itemSize: 18,
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: const Icon(Icons.cancel_rounded),
      padding: EdgeInsetsDirectional.fromSTEB(liquid ? 12 : 8, 9, 8, 9),
      style: TextStyle(fontSize: 16, color: p.text),
      placeholderStyle: TextStyle(fontSize: 16, color: p.text2),
    );
    return Padding(
      padding: margin,
      child: liquid
          ? AppGlass(
              kind: AppGlassKind.control,
              borderRadius: AppGlass.capsule,
              child: field,
            )
          : field,
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
