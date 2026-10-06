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
  if (!service.connected || target == null) return null;
  final generation = service.generation;
  bool current() => service.connected && service.generation == generation;
  final label = action == SshPowerAction.reboot ? '重启' : '关机';
  final command = powerCommand(action);
  final first = await confirmAction(
    context,
    title: '$label影响确认（1/2）',
    message:
        '${escapedCommandPreview(target.name)}\n${escapedCommandPreview(target.label)}\n\n通过当前单台 SSH 连接执行：\n$command\n\n可能立即中断业务及 SSH 会话，需要远端相应权限。关机不会取消厂商计费，SSH 无法再次开机。连接中断或超时后结果未知，请到厂商控制台核实，勿盲目重试。',
    action: '了解影响，继续核对',
    dangerous: true,
  );
  if (!first || !context.mounted || !current()) return null;
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
  if (confirmed != true || !context.mounted || !current()) return null;
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
  final String label, target;
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
        title: Text('最终确认${widget.label}（2/2）'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('请完整输入本次目标，确认只下发一次：'),
              SelectableText(widget.target),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('power-confirm-target'),
                controller: _input,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: '用户名@主机:端口'),
              ),
              if (!current) const InfoNote('连接已变化。本次确认已作废，未下发指令。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('power-confirm-submit'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: current && !_submitted && _input.text == widget.target
                ? () {
                    setState(() => _submitted = true);
                    Navigator.pop(context, true);
                  }
                : null,
            child: Text('仅执行一次${widget.label}'),
          ),
        ],
      );
    },
  );
}
