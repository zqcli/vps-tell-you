import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';
import '../l10n/generated/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import 'snippet.dart';
import 'ssh_service.dart';
import 'terminal_font.dart';
import 'terminal_scheme.dart';

export 'terminal_scheme.dart';

/// Built-in suggestions use the same local draft and exact-send review as
/// user snippets. They are never persisted or executed by selecting them.
List<CommandSnippet> get terminalQuickCommands =>
    terminalQuickCommandsFor(defaultLocalizations);
List<CommandSnippet> terminalQuickCommandsFor(AppLocalizations l10n) =>
    <CommandSnippet>[
      CommandSnippet(
        id: 'builtin-pwd',
        name: l10n.terminalCurrentDirectory,
        content: 'pwd',
      ),
      CommandSnippet(
        id: 'builtin-ls',
        name: l10n.terminalListFiles,
        content: 'ls -lah',
      ),
      CommandSnippet(
        id: 'builtin-uptime',
        name: l10n.terminalUptime,
        content: 'uptime',
      ),
      CommandSnippet(
        id: 'builtin-df',
        name: l10n.terminalDiskUsage,
        content: 'df -h',
      ),
      CommandSnippet(
        id: 'builtin-free',
        name: l10n.terminalMemoryUsage,
        content: 'free -h',
      ),
    ];

/// Rounded dark key cap inside a >=48px touch target. The tap target is the
/// surrounding [TextButton]; only the cap is painted.
class _KeyCap extends StatelessWidget {
  const _KeyCap({
    required this.child,
    required this.enabled,
    this.accent = false,
    this.armed = false,
  });
  final Widget child;
  final bool enabled, accent, armed;

  @override
  Widget build(BuildContext context) {
    final scheme = TerminalScheme.of(context);
    return Opacity(
      opacity: enabled ? 1 : .4,
      child: Container(
        constraints: const BoxConstraints(minWidth: 42, minHeight: 34),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent
              ? scheme.accent
              : armed
              ? scheme.keyArmed
              : scheme.key,
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
  }
}

class TerminalKeyBar extends StatelessWidget {
  const TerminalKeyBar({
    super.key,
    required this.connected,
    required this.controlArmed,
    required this.onControl,
    required this.onKey,
    required this.onCommands,
    required this.hasDraft,
    required this.onPaste,
  });
  final bool connected, controlArmed, hasDraft;
  final VoidCallback onControl, onCommands;
  final VoidCallback? onPaste;
  final void Function(TerminalKey key, {bool ctrl}) onKey;

  static const _keyText = TextStyle(
    fontFamily: terminalFontFamily,
    fontSize: 13,
    height: 1.2,
  );

  ButtonStyle _style(TerminalScheme scheme, {double minWidth = 48}) =>
      TextButton.styleFrom(
        minimumSize: Size(minWidth, 48),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
        foregroundColor: scheme.theme.foreground,
        disabledForegroundColor: scheme.theme.foreground,
        textStyle: _keyText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = TerminalScheme.of(context);
    return Material(
      color: scheme.chrome,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.hairline)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Do not wrap. The strip remains one row above the keyboard, even
            // with accessibility text scaling; all controls have >=48px touch
            // targets.
            Row(
              children: [
                const SizedBox(width: 5),
                ExcludeFocus(
                  child: Tooltip(
                    message: hasDraft
                        ? context.l10n.terminalCommandsWithDraft
                        : context.l10n.terminalCommandsSnippets,
                    child: TextButton(
                      key: const ValueKey('terminal-commands'),
                      onPressed: onCommands,
                      style: _style(scheme, minWidth: 64).copyWith(
                        foregroundColor: WidgetStatePropertyAll(
                          scheme.onAccent,
                        ),
                      ),
                      child: _KeyCap(
                        enabled: true,
                        accent: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Badge(
                              isLabelVisible: hasDraft,
                              child: const Icon(Icons.code_rounded, size: 18),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              context.l10n.terminalCommands,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('terminal-key-scroll'),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      children: [
                        ExcludeFocus(
                          child: TextButton(
                            key: const ValueKey('terminal-control'),
                            onPressed: connected ? onControl : null,
                            style: _style(scheme, minWidth: 52),
                            child: Semantics(
                              toggled: controlArmed,
                              label: context.l10n.terminalControlHelp,
                              excludeSemantics: true,
                              child: _KeyCap(
                                enabled: connected,
                                armed: controlArmed,
                                child: const Text('Ctrl'),
                              ),
                            ),
                          ),
                        ),
                        ExcludeFocus(
                          child: Tooltip(
                            message: context.l10n.terminalControlPaste,
                            child: TextButton(
                              key: const ValueKey('terminal-paste'),
                              onPressed: onPaste,
                              style: _style(scheme, minWidth: 64),
                              child: _KeyCap(
                                enabled: onPaste != null,
                                child: const Text('Ctrl V'),
                              ),
                            ),
                          ),
                        ),
                        for (final item
                            in <(String, TerminalKey, bool, IconData?)>[
                              ('Esc', TerminalKey.escape, false, null),
                              ('Tab', TerminalKey.tab, false, null),
                              ('Ctrl+C', TerminalKey.keyC, true, null),
                              (
                                context.l10n.terminalArrowUp,
                                TerminalKey.arrowUp,
                                false,
                                Icons.keyboard_arrow_up,
                              ),
                              (
                                context.l10n.terminalArrowDown,
                                TerminalKey.arrowDown,
                                false,
                                Icons.keyboard_arrow_down,
                              ),
                              (
                                context.l10n.terminalArrowLeft,
                                TerminalKey.arrowLeft,
                                false,
                                Icons.keyboard_arrow_left,
                              ),
                              (
                                context.l10n.terminalArrowRight,
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
                                style: _style(scheme),
                                child: _KeyCap(
                                  enabled: connected,
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
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TerminalCommandSheet extends StatefulWidget {
  const TerminalCommandSheet({
    super.key,
    required this.draft,
    required this.service,
    required this.target,
    required this.insertSnippet,
    required this.replaceDraft,
    required this.sendDraft,
    required this.pasteDraft,
  });
  final TextEditingController draft;
  final SshService service;
  final String target;
  final Future<void> Function() insertSnippet;
  final Future<bool> Function(String content) replaceDraft;
  final Future<bool> Function(String exact, int generation, bool appendEnter)
  sendDraft;
  final Future<Object?> Function() pasteDraft;
  @override
  State<TerminalCommandSheet> createState() => _TerminalCommandSheetState();
}

class _TerminalCommandSheetState extends State<TerminalCommandSheet> {
  bool _busy = false;
  Object? _error;
  late final int _generation = widget.service.generation;

  Future<void> _run(Future<void> Function() action) async {
    if (!mounted || _busy || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _send(bool appendEnter) => _run(() async {
    if (!widget.service.acceptsInput ||
        widget.service.generation != _generation ||
        widget.draft.text.isEmpty) {
      return;
    }
    final sent = await widget.sendDraft(
      widget.draft.text,
      _generation,
      appendEnter,
    );
    if (!mounted) {
      return;
    }
    if (sent) {
      Navigator.pop(context, true);
    } else {
      setState(
        () => _error = LocalizedText((l10n) => l10n.terminalSendUnconfirmed),
      );
    }
  });

  Widget _sendActions(BuildContext context, bool enabled) {
    final scheme = TerminalScheme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final normal = FilledButton.icon(
      key: const ValueKey('terminal-send'),
      onPressed: enabled ? () => _send(false) : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: shape,
        backgroundColor: scheme.key,
        foregroundColor: scheme.theme.foreground,
        disabledBackgroundColor: scheme.key.withValues(alpha: .5),
      ),
      icon: const Icon(Icons.send_outlined, size: 18),
      label: Text(context.l10n.terminalSend),
    );
    final execute = FilledButton.icon(
      key: const ValueKey('terminal-send-execute'),
      onPressed: enabled ? () => _send(true) : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: shape,
        backgroundColor: scheme.accent,
        foregroundColor: scheme.onAccent,
        disabledBackgroundColor: scheme.accent.withValues(alpha: .35),
      ),
      icon: const Icon(Icons.keyboard_return, size: 18),
      label: Text(context.l10n.terminalSendExecute),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: context.l10n.terminalSendExecute,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: TextDirection.ltr,
    )..layout();
    final rowWidth = (painter.width + 18 + 8 + 40) * 2 + 8;
    painter.dispose();
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= rowWidth
          ? Row(
              children: [
                Expanded(child: normal),
                const SizedBox(width: 8),
                Expanded(child: execute),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [normal, const SizedBox(height: 8), execute],
            ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.draft, widget.service]),
    builder: (context, _) {
      final scheme = TerminalScheme.of(context);
      final current = widget.service.generation == _generation;
      final enabled =
          !_busy &&
          current &&
          widget.service.acceptsInput &&
          widget.draft.text.isNotEmpty;
      final hiddenBytes = RegExp(
        r'[\x00-\x1f\x7f-\x9f\u00ad\u061c\u180e\u200b-\u200f\u2028-\u202e\u2060-\u206f\ufeff]',
      ).hasMatch(widget.draft.text);
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: .88,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 5,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: scheme.muted.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.terminalCommandsSnippets,
                          style: Theme.of(context).textTheme.titleMedium!
                              .copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.theme.foreground,
                              ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('terminal-commands-close'),
                        tooltip: context.l10n.terminalBack,
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: scheme.key,
                          foregroundColor: scheme.muted,
                        ),
                        icon: const Icon(Icons.close, size: 18),
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
                          context.l10n.terminalQuickCommands,
                          key: const ValueKey('terminal-command-choices'),
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(color: scheme.muted),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final command in terminalQuickCommandsFor(
                              context.l10n,
                            ))
                              ActionChip(
                                key: ValueKey(command.id),
                                tooltip: command.name,
                                backgroundColor: scheme.key,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                label: Text(
                                  command.content,
                                  style: const TextStyle(
                                    fontFamily: terminalFontFamily,
                                    fontSize: 13,
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
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: const ValueKey('terminal-insert-snippet'),
                            style: TextButton.styleFrom(
                              foregroundColor: scheme.link,
                            ),
                            onPressed: _busy
                                ? null
                                : () => _run(widget.insertSnippet),
                            icon: const Icon(
                              Icons.bookmarks_outlined,
                              size: 18,
                            ),
                            label: Text(context.l10n.terminalInsertSnippet),
                          ),
                        ),
                        Divider(height: 24, color: scheme.hairline),
                        TextField(
                          key: const ValueKey('terminal-draft'),
                          controller: widget.draft,
                          enabled: !_busy,
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
                          minLines: 2,
                          maxLines: 6,
                          autocorrect: false,
                          enableSuggestions: false,
                          enableIMEPersonalizedLearning: false,
                          keyboardType: TextInputType.multiline,
                          style: TextStyle(
                            fontFamily: terminalFontFamily,
                            fontSize: 14,
                            color: scheme.theme.foreground,
                          ),
                          cursorColor: scheme.link,
                          onChanged: (_) {
                            if (_error != null) {
                              setState(() => _error = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: context.l10n.terminalDraft,
                            hintText: context.l10n.terminalDraftHint,
                            filled: true,
                            fillColor: scheme.theme.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: scheme.accent),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            key: const ValueKey('terminal-draft-paste'),
                            style: TextButton.styleFrom(
                              foregroundColor: scheme.link,
                            ),
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    final error = await widget.pasteDraft();
                                    if (mounted && error != null) {
                                      setState(() => _error = error);
                                    }
                                  }),
                            icon: const Icon(Icons.content_paste, size: 18),
                            label: Text(context.l10n.terminalPaste),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.terminalSendTo,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        SelectableText(
                          escapedCommandPreview(widget.target),
                          key: const ValueKey('terminal-send-target'),
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontFamily: terminalFontFamily,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (hiddenBytes) ...[
                          Text(
                            context.l10n.terminalControlCharacterWarning,
                            key: const ValueKey('draft-control-warning'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 144),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                escapedCommandPreview(widget.draft.text),
                                key: const ValueKey('draft-exact-preview'),
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  fontFamily: terminalFontFamily,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              localizedText(_error!, context.l10n),
                              key: const ValueKey('terminal-draft-error'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        Text(
                          !current
                              ? context.l10n.terminalSessionChanged
                              : !widget.service.acceptsInput
                              ? context.l10n.terminalCannotSend
                              : context.l10n.terminalSendMeaning,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        _sendActions(context, enabled),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
