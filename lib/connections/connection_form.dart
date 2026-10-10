import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ui/ui.dart';

/// Validated text row for the connection forms: an [AppFormRow] whose error
/// text is shown under the row, wired into the surrounding [Form] so that
/// `validate()` and `Form.onChanged` keep working.
///
/// [fieldKey] is placed on the [AppTextField] (tests enter text through it).
class ValidatedTextRow extends StatelessWidget implements AppSectionItem {
  const ValidatedTextRow({
    super.key,
    this.fieldKey,
    required this.label,
    required this.controller,
    this.validator,
    this.hint,
    this.keyboardType,
    this.autocorrect = false,
    this.enableSuggestions = false,
    this.enabled,
    this.maxLength,
    this.minLines,
    this.maxLines = 1,
    this.stacked = false,
    this.mono = false,
    this.required = false,
    this.onChanged,
    this.inputFormatters,
    this.exactText = false,
  });

  final Key? fieldKey;
  final String label;
  final TextEditingController controller;
  final String? Function(String value)? validator;
  final String? hint;
  final TextInputType? keyboardType;
  final bool autocorrect, enableSuggestions;
  final bool? enabled;
  final int? maxLength, minLines, maxLines;

  /// Control below the label with start-aligned text (multi-line content).
  final bool stacked;
  final bool mono, required;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  /// Disables smart dashes / quotes (exact command content).
  final bool exactText;

  @override
  double get separatorInset => 16;

  @override
  Widget build(BuildContext context) => FormField<String>(
    validator: validator == null ? null : (_) => validator!(controller.text),
    builder: (state) => AppFormRow(
      label: label,
      required: required,
      stacked: stacked,
      errorText: state.errorText,
      child: _field(state),
    ),
  );

  Widget _field(FormFieldState<String> state) => AppTextField(
    key: fieldKey,
    controller: controller,
    label: label,
    hint: hint,
    keyboardType: keyboardType,
    autocorrect: autocorrect,
    enableSuggestions: enableSuggestions,
    enabled: enabled,
    maxLength: maxLength,
    minLines: minLines,
    maxLines: maxLines,
    inputFormatters: inputFormatters,
    smartDashesType: exactText ? SmartDashesType.disabled : null,
    smartQuotesType: exactText ? SmartQuotesType.disabled : null,
    textAlign: stacked ? TextAlign.start : TextAlign.end,
    style: mono ? kMonoTextStyle : null,
    onChanged: (value) {
      state.didChange(value);
      onChanged?.call(value);
    },
  );
}
