import 'package:flutter/material.dart';

import '../core/ui/ui.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import 'cloud_account.dart';
import 'cloud_models.dart';

String cloudProviderName(CloudProvider provider) => switch (provider) {
  CloudProvider.solusVm1 => 'SolusVM 1',
  CloudProvider.solusVm2 => 'SolusVM 2',
  CloudProvider.rackNerd => 'RackNerd ctrl',
};

String cloudPowerLabel(CloudPower power, {AppLocalizations? l10n}) {
  final strings = l10n ?? defaultLocalizations;
  return switch (power) {
    CloudPower.running => strings.cloudPowerRunning,
    CloudPower.stopped => strings.cloudPowerStopped,
    CloudPower.unknown => strings.cloudPowerUnknown,
  };
}

String cloudTime(DateTime time) => time.toLocal().toString().substring(0, 16);

String cloudBindingSummary(CloudBinding binding, {AppLocalizations? l10n}) {
  final strings = l10n ?? defaultLocalizations;
  final freshness = binding.missing
      ? strings.cloudMissingKept
      : binding.stale
      ? strings.cloudFailedKept
      : strings.cloudLastRead;
  return strings.cloudBindingSummary(
    freshness,
    cloudPowerLabel(binding.power, l10n: strings),
  );
}

String cloudAccountStatus(CloudAccount account, {AppLocalizations? l10n}) {
  final strings = l10n ?? defaultLocalizations;
  return account.lastFailure == CloudFailureKind.unauthorized
      ? strings.cloudAuthorizationFailedKept
      : account.lastFailure != null
      ? strings.cloudFailedKept
      : strings.cloudVerifiedManual;
}

/// Three-step progress of the add-adapter flow: a thin bar per step with its
/// label underneath; the current step uses the brand colour.
class CloudSteps extends StatelessWidget {
  const CloudSteps(this.step, {super.key});
  final int step;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final labels = [
      context.l10n.cloudStepTemplate,
      context.l10n.cloudStepCredentials,
      context.l10n.cloudStepInstances,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: i + 1 <= step ? p.primary : p.fill,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.cloudStepLabel(i + 1, labels[i]),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: i + 1 == step
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: i + 1 == step ? p.primary : p.text2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Inline notice. [error] gives the red tone, otherwise a blue information
/// banner; [tone] overrides both (e.g. amber for "needs review").
class CloudNotice extends StatelessWidget {
  const CloudNotice(this.message, {super.key, this.error = false, this.tone});
  final Object message;
  final bool error;
  final AppTone? tone;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: AppBanner(
      text: localizedText(message, context.l10n),
      tone: tone ?? (error ? AppTone.red : AppTone.blue),
      icon: (tone ?? (error ? AppTone.red : AppTone.blue)) == AppTone.blue
          ? Icons.info_outline_rounded
          : Icons.error_outline_rounded,
    ),
  );
}

/// Small secondary text under a group or a block of controls (a footnote that
/// is not attached to an `AppSection`).
class CloudFootnote extends StatelessWidget {
  const CloudFootnote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
    child: Text(text, style: context.footnoteStyle),
  );
}

/// Read-only label / value row for adapter details. A missing value reads
/// "unknown (not provided by the API)".
class CloudValue extends StatelessWidget implements AppSectionItem {
  const CloudValue(this.label, this.value, {super.key});
  final String label;
  final String? value;
  @override
  double get separatorInset => 16;
  @override
  Widget build(BuildContext context) => AppKeyValueRow(
    label: label,
    value: value,
    placeholder: context.l10n.cloudApiUnknown,
  );
}

/// Selection row of the import preview and binding pages: a round check mark,
/// title, optional status pill and detail lines. [onChanged] `null` disables
/// the row; it stays fully legible (the check mark alone is dimmed).
class CloudCheckRow extends StatelessWidget implements AppSectionItem {
  const CloudCheckRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.status,
    this.details = const [],
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String title;

  /// Usually a [StatusPill] shown under the title.
  final Widget? status;

  /// Secondary lines, one `Text` each.
  final List<String> details;

  @override
  double get separatorInset => 16 + 24 + 12;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onChanged != null;
    return Semantics(
      checked: value,
      enabled: enabled,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? () => onChanged!(!value) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      value
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 24,
                      color: value
                          ? (enabled ? p.primary : p.text3)
                          : (enabled ? p.text3 : p.separator),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.3,
                            color: p.text,
                          ),
                        ),
                        if (status != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: status!,
                          ),
                        for (final line in details)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              line,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: p.text2,
                              ),
                            ),
                          ),
                      ],
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

/// Short message inside a group (under a row), e.g. a per-device failure.
class CloudInlineNote extends StatelessWidget {
  const CloudInlineNote(this.message, {super.key, this.error = false});
  final Object message;
  final bool error;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(52, 2, 16, 12),
      child: Text(
        localizedText(message, context.l10n),
        style: TextStyle(
          fontSize: 13,
          height: 1.35,
          color: error ? context.palette.red : context.palette.text2,
        ),
      ),
    ),
  );
}

/// Footnote made of several short paragraphs (an `AppSection.footerWidget`).
class CloudFootnotes extends StatelessWidget {
  const CloudFootnotes(this.paragraphs, {super.key});
  final List<String> paragraphs;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < paragraphs.length; i++)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
          child: Text(paragraphs[i], style: context.footnoteStyle),
        ),
    ],
  );
}

/// Full-width action below a form or list: primary (default) or tonal.
/// [buttonKey] lands on the [AppButton] so tests and callers can read
/// `onPressed`.
class CloudAction extends StatelessWidget {
  const CloudAction({
    super.key,
    this.buttonKey,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = AppButtonKind.primary,
    this.destructive = false,
  });
  final Key? buttonKey;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonKind kind;
  final bool destructive;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: AppButton(
      key: buttonKey,
      label: label,
      icon: icon,
      kind: kind,
      destructive: destructive,
      expand: true,
      onPressed: onPressed,
    ),
  );
}

/// Single-line text field for an iOS alert prompt (rename). [fieldKey] is put
/// on the `TextField` itself.
class CloudPromptField extends StatelessWidget {
  const CloudPromptField({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.hint,
    this.enabled = true,
    this.maxLength = 80,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
  });
  final Key fieldKey;
  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final int maxLength;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.fill,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: TextField(
          key: fieldKey,
          controller: controller,
          autofocus: true,
          enabled: enabled,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          cursorColor: p.primary,
          style: TextStyle(fontSize: 16, color: p.text),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            semanticCounterText: hint,
          ),
          onSubmitted: onSubmitted,
        ),
      ),
    );
  }
}

/// A grouped, validated single-line field for the adapter forms: an
/// [AppFormRow] whose error text is driven by `Form.validate()` like a
/// `TextFormField`. [validator] receives the current controller text.
FormField<String> cloudFormField({
  required Key key,
  required String label,
  required TextEditingController controller,
  String? Function(String text)? validator,
  bool enabled = true,
  bool readOnly = false,
  bool secret = false,
  bool required = false,
  String? hint,
  TextInputType? keyboardType,
  int? maxLength,
  ValueChanged<String>? onChanged,
}) => FormField<String>(
  key: key,
  validator: validator == null ? null : (_) => validator(controller.text),
  builder: (state) => AppFormRow(
    label: label,
    required: required,
    errorText: state.errorText,
    child: AppTextField(
      controller: controller,
      label: label,
      hint: hint,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: secret,
      autocorrect: !secret && keyboardType != TextInputType.url,
      enableSuggestions: !secret && keyboardType != TextInputType.url,
      keyboardType: secret ? TextInputType.visiblePassword : keyboardType,
      maxLength: maxLength,
      onChanged: (text) {
        if (state.hasError) state.validate();
        onChanged?.call(text);
      },
    ),
  ),
);
