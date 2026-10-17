import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ui/ui.dart';
import '../l10n/locale_preference.dart';
import 'error_details.dart';

/// "Details ›" link after a friendly error message: opens [showErrorDetails].
/// Text rather than a second ⓘ, so it never repeats the error icon that
/// usually sits before the message. 44 pt tall hit target.
class ErrorDetailsButton extends StatelessWidget {
  const ErrorDetailsButton({super.key, required this.details, this.color});
  final ErrorDetails details;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      container: true,
      button: true,
      label: l10n.r14ErrorDetails,
      onTap: () => showErrorDetails(context, details),
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('error-details-button'),
        behavior: HitTestBehavior.opaque,
        onTap: () => showErrorDetails(context, details),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: _DetailsLabel(color: color ?? context.palette.primary),
        ),
      ),
    );
  }
}

class _DetailsLabel extends StatelessWidget {
  const _DetailsLabel({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.r15Details,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(width: 3),
        AppChevron(color: color.withValues(alpha: .8), size: 12),
      ],
    ),
  );
}

/// A red banner: error icon, message and, when [details] exist, the whole
/// banner opens them with a trailing "Details ›" (one icon, one target).
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.text, this.details});
  final String text;
  final ErrorDetails? details;

  @override
  Widget build(BuildContext context) {
    final d = details;
    final banner = AppBanner(
      tone: AppTone.red,
      icon: Icons.error_outline_rounded,
      text: text,
      onTap: d == null ? null : () => showErrorDetails(context, d),
      action: d == null
          ? null
          : KeyedSubtree(
              key: const ValueKey('error-details-button'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Center(
                  widthFactor: 1,
                  child: _DetailsLabel(
                    color: context.palette.tone(AppTone.red).$1,
                  ),
                ),
              ),
            ),
    );
    if (d == null) return banner;
    return Semantics(
      button: true,
      hint: context.l10n.r14ErrorDetails,
      child: banner,
    );
  }
}

/// "Error Details" sheet: stage, target, proxy, time and the redacted
/// original error (monospace, selectable) with a Copy button.
Future<void> showErrorDetails(BuildContext context, ErrorDetails details) =>
    showAppSheet<void>(
      context,
      title: context.l10n.r14ErrorDetails,
      builder: (_) => ErrorDetailsView(details: details),
    );

class ErrorDetailsView extends StatefulWidget {
  const ErrorDetailsView({super.key, required this.details});
  final ErrorDetails details;
  @override
  State<ErrorDetailsView> createState() => _ErrorDetailsViewState();
}

class _ErrorDetailsViewState extends State<ErrorDetailsView> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(text: widget.details.report(context.l10n)),
    );
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final d = widget.details;
    Widget ltr(String text) => Text(
      text,
      textAlign: TextAlign.end,
      textDirection: TextDirection.ltr,
      style: kMonoTextStyle.copyWith(
        fontSize: 14,
        height: 1.35,
        color: p.text2,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSection(
          topSpacing: 4,
          children: [
            AppKeyValueRow(
              key: const ValueKey('error-details-stage'),
              label: l10n.r14ErrorStage,
              value: d.stage.label(l10n),
            ),
            if (d.target != null)
              AppKeyValueRow(
                key: const ValueKey('error-details-target'),
                label: l10n.r14ErrorTarget,
                valueWidget: ltr(d.target!),
              ),
            if (d.proxy != null)
              AppKeyValueRow(
                key: const ValueKey('error-details-proxy'),
                label: l10n.r14ErrorProxy,
                value: d.proxy,
              ),
            AppKeyValueRow(
              key: const ValueKey('error-details-time'),
              label: l10n.r14ErrorTime,
              value: d.timeText(),
            ),
          ],
        ),
        AppSection(
          header: l10n.r14ErrorTechnical,
          footer: l10n.r14ErrorFootnote,
          children: [
            AppRow.custom(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SelectableText(
                    d.technical,
                    key: const ValueKey('error-details-technical'),
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    style: kMonoTextStyle.copyWith(
                      fontSize: 13,
                      height: 1.4,
                      color: p.text,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: AppButton(
            key: const ValueKey('error-details-copy'),
            label: _copied ? l10n.r14ErrorCopied : l10n.r14ErrorCopy,
            icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
            kind: AppButtonKind.tonal,
            expand: true,
            onPressed: _copy,
          ),
        ),
      ],
    );
  }
}
