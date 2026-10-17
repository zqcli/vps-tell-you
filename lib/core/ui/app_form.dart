import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputAction, TextInputFormatter;

import '../../l10n/locale_preference.dart';
import '../app_palette.dart';
import 'app_list.dart';

/// iOS switch (always Cupertino look, no platform branching).
///
/// ```dart
/// AppSwitch(value: enabled, onChanged: (v) => setState(() => enabled = v))
/// ```
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;

  /// `null` renders a disabled switch.
  final ValueChanged<bool>? onChanged;

  /// Accessibility label (use when the switch is not inside an [AppSwitchRow]).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: semanticLabel,
      child: CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppPalette.switchGreen,
        inactiveTrackColor: p.isDark
            ? const Color(0xFF39393D)
            : const Color(0xFFE5E5EA),
      ),
    );
  }
}

/// Form row: label on the left, an arbitrary control ([AppTextField],
/// `AppSegmented`, `AppStepper`, `AppSwitch`, a value text …) on the right.
///
/// ```dart
/// AppFormRow(
///   label: l10n.name, required: true,
///   child: AppTextField(controller: name, hint: 'HK-01'),
/// )
/// AppFormRow.pick(label: l10n.provider, value: provider?.name,
///     placeholder: l10n.unspecified, onTap: choose)
/// AppFormRow(label: l10n.notes, stacked: true,
///     child: AppTextField(controller: notes, maxLines: 4, textAlign: TextAlign.start))
/// ```
class AppFormRow extends StatelessWidget implements AppSectionItem {
  const AppFormRow({
    super.key,
    required this.label,
    required Widget this.child,
    this.required = false,
    this.errorText,
    this.stacked = false,
    this.onTap,
    this.chevron = false,
  }) : value = null,
       placeholder = null;

  /// Picker-style row: shows [value] (or the greyed [placeholder]) on the
  /// right with a chevron; [onTap] usually opens `showAppPicker`.
  const AppFormRow.pick({
    super.key,
    required this.label,
    this.value,
    this.placeholder,
    required this.onTap,
    this.required = false,
    this.errorText,
  }) : child = null,
       stacked = false,
       chevron = true;

  final String label;

  /// Right-hand control (or the control below the label when [stacked]).
  final Widget? child;

  /// Appends a red asterisk to the label.
  final bool required;

  /// Validation message shown in red under the row.
  final String? errorText;

  /// Put the control below the label (notes, long text) instead of beside it.
  final bool stacked;
  final VoidCallback? onTap;
  final bool chevron;

  final String? value;
  final String? placeholder;

  @override
  double get separatorInset => 16;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final labelWidget = Text.rich(
      TextSpan(
        text: label,
        children: [
          if (required)
            TextSpan(
              text: ' *',
              style: TextStyle(color: p.red),
            ),
        ],
      ),
      style: TextStyle(fontSize: 16, height: 1.3, color: p.text),
    );
    final Widget control =
        child ??
        Text(
          (value == null || value!.isEmpty) ? (placeholder ?? '') : value!,
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: 16,
            color: (value == null || value!.isEmpty) ? p.text3 : p.text,
          ),
        );
    final Widget line;
    if (stacked) {
      line = Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [labelWidget, control],
        ),
      );
    } else {
      line = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, box) => Row(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth * .45),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: labelWidget,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: control,
                  ),
                ),
                if (chevron) ...[const SizedBox(width: 8), const AppChevron()],
              ],
            ),
          ),
        ),
      );
    }
    final withTap = Material(
      type: MaterialType.transparency,
      child: onTap == null ? line : InkWell(onTap: onTap, child: line),
    );
    // Always a Column: when the error appears or clears the field below must
    // keep its State (focus, selection, IME connection).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        withTap,
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              errorText!,
              style: TextStyle(fontSize: 12.5, height: 1.3, color: p.red),
            ),
          ),
      ],
    );
  }
}

/// Inline text field for [AppFormRow]: no border, no fill, right-aligned by
/// default. Thin wrapper over [TextField] exposing the commonly needed
/// options.
///
/// ```dart
/// AppTextField(controller: host, hint: l10n.hostHint,
///     keyboardType: TextInputType.url, label: l10n.host)
/// ```
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hint,
    this.label,
    this.keyboardType,
    this.textInputAction,
    this.textAlign = TextAlign.end,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.focusNode,
    this.enabled,
    this.readOnly = false,
    this.autofocus = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.style,
    this.suffix,
    this.errorText,
    this.enableInteractiveSelection,
    this.enableIMEPersonalizedLearning = true,
    this.smartDashesType,
    this.smartQuotesType,
  });

  final TextEditingController? controller;
  final String? hint;

  /// Passed to [TextField]; `false` for secrets that must not be selectable.
  final bool? enableInteractiveSelection;

  /// Passed to [TextField]; `false` keeps secrets out of keyboard learning.
  final bool enableIMEPersonalizedLearning;

  /// Accessibility label (the visible label lives in the surrounding row).
  final String? label;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextAlign textAlign;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool? enabled;
  final bool readOnly;
  final bool autofocus;
  final bool autocorrect;
  final bool enableSuggestions;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final TextStyle? style;

  /// Widget after the text, e.g. a unit label.
  final Widget? suffix;

  /// Error text drawn by the field itself (prefer [AppFormRow.errorText]).
  final String? errorText;

  /// Pass [SmartDashesType.disabled] / [SmartQuotesType.disabled] for fields
  /// whose text must stay byte-exact (commands).
  final SmartDashesType? smartDashesType;
  final SmartQuotesType? smartQuotesType;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textAlign: textAlign,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      obscureText: obscureText,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      enableInteractiveSelection: enableInteractiveSelection,
      enableIMEPersonalizedLearning: enableIMEPersonalizedLearning,
      smartDashesType: smartDashesType,
      smartQuotesType: smartQuotesType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      cursorColor: p.primary,
      style: (style ?? const TextStyle()).copyWith(
        fontSize: style?.fontSize ?? 16,
        color: style?.color ?? p.text,
      ),
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        counterText: '',
        suffix: suffix,
      ),
    ).withLabel(label);
  }
}

extension on Widget {
  Widget withLabel(String? label) =>
      label == null ? this : Semantics(label: label, child: this);
}

/// A [Form] page whose shown validation errors follow a live language change:
/// once validated, switching the locale validates again so the messages are
/// re-translated. Put [formKey] on the [Form] and validate with [validateForm]
/// (or set [validationAttempted] when validating another way).
mixin LocaleRevalidatingForm<T extends StatefulWidget> on State<T> {
  final formKey = GlobalKey<FormState>();
  bool validationAttempted = false;
  String? _locale;

  bool validateForm() {
    validationAttempted = true;
    return formKey.currentState!.validate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.l10n.localeName;
    if (_locale != null && _locale != next && validationAttempted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) formKey.currentState?.validate();
      });
    }
    _locale = next;
  }
}
