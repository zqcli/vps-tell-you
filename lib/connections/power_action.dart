import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'ssh_service.dart';
import 'snippet.dart';

/// Two independent confirmations bind to a single live connection generation.
/// A lost connection invalidates either dialog; reconnect never resumes it.
Future<PowerResult?> confirmSshPower(
  BuildContext context, {
  required SshService service,
  required SshPowerAction action,
}) async {
  final target = service.target;
  if (!service.connected || target == null) {
    return null;
  }
  final generation = service.generation;
  bool current() => service.connected && service.generation == generation;
  final label = LocalizedText(
    (l10n) => action == SshPowerAction.reboot
        ? l10n.powerRestart
        : l10n.powerShutdown,
  );
  final command = powerCommand(action);
  final first = await confirmAction(
    context,
    title: LocalizedText(
      (l10n) => l10n.powerImpactTitle(label.messageFor(l10n)),
    ),
    message: LocalizedText(
      (l10n) => l10n.powerImpactHelp(
        (escapedCommandPreview(target.displayNameFor(l10n))).toString(),
        (escapedCommandPreview(target.label)).toString(),
        (command).toString(),
      ),
    ),
    action: LocalizedText((l10n) => l10n.powerUnderstandContinue),
    dangerous: true,
  );
  if (!first || !context.mounted || !current()) {
    return null;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PowerTargetDialog(
      service: service,
      generation: generation,
      label: label,
      target: escapedCommandPreview(target.label),
    ),
  );
  if (confirmed != true || !context.mounted || !current()) {
    return null;
  }
  return service.power(action, expectedGeneration: generation);
}

class _PowerTargetDialog extends StatefulWidget {
  const _PowerTargetDialog({
    required this.service,
    required this.generation,
    required this.label,
    required this.target,
  });
  final SshService service;
  final int generation;
  final LocalizedMessage label;
  final String target;
  @override
  State<_PowerTargetDialog> createState() => _PowerTargetDialogState();
}

class _PowerTargetDialogState extends State<_PowerTargetDialog> {
  final _input = TextEditingController();
  bool _submitted = false;
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) {
      final current =
          widget.service.connected &&
          widget.service.generation == widget.generation;
      return AlertDialog(
        scrollable: true,
        title: Text(
          context.l10n.powerFinalTitle(widget.label.messageFor(context.l10n)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.powerEnterTarget,
                style: TextStyle(color: context.palette.text2),
              ),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: context.palette.fill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: SelectableText(
                    widget.target,
                    textDirection: TextDirection.ltr,
                    style: kMonoTextStyle.copyWith(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('power-confirm-target'),
                controller: _input,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: context.l10n.powerTargetFormat,
                ),
              ),
              if (!current)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    context.l10n.powerConfirmationInvalidated,
                    style: context.footnoteStyle.copyWith(
                      color: context.palette.red,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('power-confirm-submit'),
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.red,
              foregroundColor: Colors.white,
            ),
            onPressed: current && !_submitted && _input.text == widget.target
                ? () {
                    setState(() => _submitted = true);
                    Navigator.pop(context, true);
                  }
                : null,
            child: Text(
              context.l10n.powerExecuteOnce(
                widget.label.messageFor(context.l10n),
              ),
            ),
          ),
        ],
      );
    },
  );
}
