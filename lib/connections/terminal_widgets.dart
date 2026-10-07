import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import 'snippet.dart';
import 'ssh_service.dart';
import 'terminal_font.dart';

const terminalChromeColor = Color(0xFF151F2F);
const mobileTerminalTheme = TerminalTheme(
  cursor: Color(0xFFD3E0F6),
  selection: Color(0x806B91CD),
  foreground: Color(0xFFD6E1F0),
  background: Color(0xFF0B1220),
  black: Color(0xFF121B2A),
  red: Color(0xFFEB767D),
  green: Color(0xFF8CE4B6),
  yellow: Color(0xFFEED18F),
  blue: Color(0xFF82B5F4),
  magenta: Color(0xFFC8A0EC),
  cyan: Color(0xFF7BD8DE),
  white: Color(0xFFD6E1F0),
  brightBlack: Color(0xFF7E8CA3),
  brightRed: Color(0xFFFFA0A7),
  brightGreen: Color(0xFFB4F1D0),
  brightYellow: Color(0xFFFFE5AC),
  brightBlue: Color(0xFFB5D1FF),
  brightMagenta: Color(0xFFE0C5FC),
  brightCyan: Color(0xFFADF0F3),
  brightWhite: Color(0xFFF4F7FC),
  searchHitBackground: Color(0xFFEED18F),
  searchHitBackgroundCurrent: Color(0xFF8CE4B6),
  searchHitForeground: Color(0xFF0B1220),
);

/// Built-in suggestions use the same local draft and exact-send review as
/// user snippets. They are never persisted or executed by selecting them.
const terminalQuickCommands = <CommandSnippet>[
  CommandSnippet(id: 'builtin-pwd', name: '当前目录', content: 'pwd'),
  CommandSnippet(id: 'builtin-ls', name: '列出文件', content: 'ls -lah'),
  CommandSnippet(id: 'builtin-uptime', name: '运行时间', content: 'uptime'),
  CommandSnippet(id: 'builtin-df', name: '磁盘用量', content: 'df -h'),
  CommandSnippet(id: 'builtin-free', name: '内存用量', content: 'free -h'),
];

class TerminalKeyBar extends StatelessWidget {
  const TerminalKeyBar({
    super.key,
    required this.connected,
    required this.controlArmed,
    required this.onControl,
    required this.onKey,
    required this.onCommands,
    required this.hasDraft,
  });
  final bool connected, controlArmed, hasDraft;
  final VoidCallback onControl, onCommands;
  final void Function(TerminalKey key, {bool ctrl}) onKey;

  @override
  Widget build(BuildContext context) => Material(
    color: terminalChromeColor,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        // Do not wrap. The strip remains one row above the keyboard, even with
        // accessibility text scaling; all controls have >=48px touch targets.
        Row(
          children: [
            ExcludeFocus(
              child: Tooltip(
                message: hasDraft ? '命令与片段 · 有未发送草稿' : '命令与片段',
                child: TextButton.icon(
                  key: const ValueKey('terminal-commands'),
                  onPressed: onCommands,
                  style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                  icon: Badge(
                    isLabelVisible: hasDraft,
                    child: const Icon(Icons.code_rounded, size: 20),
                  ),
                  label: const Text('命令'),
                ),
              ),
            ),
            const SizedBox(height: 32, child: VerticalDivider(width: 1)),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('terminal-key-scroll'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    ExcludeFocus(
                      child: TextButton(
                        key: const ValueKey('terminal-control'),
                        onPressed: connected ? onControl : null,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(52, 48),
                          backgroundColor: controlArmed
                              ? const Color(0xFF315586)
                              : null,
                        ),
                        child: Semantics(
                          toggled: controlArmed,
                          label: 'Ctrl，作用于下一个按键，再点取消',
                          excludeSemantics: true,
                          child: const Text('Ctrl'),
                        ),
                      ),
                    ),
                    for (final item
                        in const <(String, TerminalKey, bool, IconData?)>[
                          ('Esc', TerminalKey.escape, false, null),
                          ('Tab', TerminalKey.tab, false, null),
                          ('Ctrl+C', TerminalKey.keyC, true, null),
                          (
                            '向上方向键',
                            TerminalKey.arrowUp,
                            false,
                            Icons.keyboard_arrow_up,
                          ),
                          (
                            '向下方向键',
                            TerminalKey.arrowDown,
                            false,
                            Icons.keyboard_arrow_down,
                          ),
                          (
                            '向左方向键',
                            TerminalKey.arrowLeft,
                            false,
                            Icons.keyboard_arrow_left,
                          ),
                          (
                            '向右方向键',
                            TerminalKey.arrowRight,
                            false,
                            Icons.keyboard_arrow_right,
                          ),
                          (
                            'Enter',
                            TerminalKey.enter,
                            false,
                            Icons.keyboard_return,
                          ),
                          ('Home', TerminalKey.home, false, null),
                          ('End', TerminalKey.end, false, null),
                        ])
                      ExcludeFocus(
                        child: Tooltip(
                          message: item.$1,
                          excludeFromSemantics: true,
                          child: TextButton(
                            key: ValueKey('terminal-key-${item.$2.name}'),
                            onPressed: connected
                                ? () => onKey(item.$2, ctrl: item.$3)
                                : null,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                            child: item.$4 == null
                                ? Text(item.$1)
                                : Icon(
                                    item.$4,
                                    size: 21,
                                    semanticLabel: item.$1,
                                  ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class TerminalCommandSheet extends StatefulWidget {
  const TerminalCommandSheet({
    super.key,
    required this.draft,
    required this.service,
    required this.insertSnippet,
    required this.replaceDraft,
    required this.sendDraft,
  });
  final TextEditingController draft;
  final SshService service;
  final Future<void> Function() insertSnippet;
  final Future<bool> Function(String content) replaceDraft;
  final Future<bool> Function() sendDraft;
  @override
  State<TerminalCommandSheet> createState() => _TerminalCommandSheetState();
}

class _TerminalCommandSheetState extends State<TerminalCommandSheet> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.draft, widget.service]),
    builder: (context, _) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: .88,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '命令与片段',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('terminal-commands-close'),
                      tooltip: '返回终端',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('terminal-command-scroll'),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '点选仅填入草稿。确认发送前不会写入 SSH。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '常用命令',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final command in terminalQuickCommands)
                            ActionChip(
                              key: ValueKey(command.id),
                              tooltip: command.name,
                              label: Text(
                                command.content,
                                style: const TextStyle(
                                  fontFamily: terminalFontFamily,
                                ),
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                      await widget.replaceDraft(
                                        command.content,
                                      );
                                    }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const ValueKey('terminal-insert-snippet'),
                          onPressed: _busy
                              ? null
                              : () => _run(widget.insertSnippet),
                          icon: const Icon(Icons.bookmarks_outlined, size: 18),
                          label: const Text('插入片段'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const ValueKey('terminal-draft'),
                        controller: widget.draft,
                        maxLength: CommandSnippet.maxContentLength,
                        inputFormatters: [
                          TextInputFormatter.withFunction(
                            (oldValue, newValue) =>
                                newValue.text.length <=
                                    CommandSnippet.maxContentLength
                                ? newValue
                                : oldValue,
                          ),
                        ],
                        minLines: 3,
                        maxLines: 7,
                        autocorrect: false,
                        enableSuggestions: false,
                        enableIMEPersonalizedLearning: false,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(
                          fontFamily: terminalFontFamily,
                          fontSize: 14,
                        ),
                        decoration: const InputDecoration(
                          labelText: '待发送草稿',
                          hintText: '先编辑，再核对目标和完整内容',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const ValueKey('terminal-send'),
                        onPressed:
                            !_busy &&
                                widget.service.connected &&
                                widget.draft.text.isNotEmpty
                            ? () => _run(() async {
                                final sent = await widget.sendDraft();
                                if (sent && context.mounted) {
                                  Navigator.pop(context, true);
                                }
                              })
                            : null,
                        icon: const Icon(Icons.preview_outlined),
                        label: const Text('预览并发送'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.service.connected
                            ? '默认不追加回车。终端键盘和底部特殊键会直接发送。'
                            : '当前未连接。可以编辑草稿；重连时会清空，不自动发送。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
