import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import 'snippet.dart';
import 'ssh_service.dart';
import 'terminal_font.dart';
import 'terminal_scheme.dart';

/// The pieces of the terminal page that only depend on a few values: status
/// chip, banners, selection actions, overflow menu and the session dialog.

String terminalStatusLabel(AppLocalizations l10n, SshStatus status) =>
    switch (status) {
      SshStatus.idle => l10n.terminalNotConnected,
      SshStatus.connecting => l10n.terminalConnecting,
      SshStatus.verifying => l10n.terminalVerifying,
      SshStatus.authenticating => l10n.terminalAuthenticating,
      SshStatus.connected => l10n.terminalConnected,
      SshStatus.disconnected => l10n.terminalDisconnected,
      SshStatus.failed => l10n.terminalFailed,
    };

/// App-bar title: session name, status chip and target; opens the details.
class TerminalTitle extends StatelessWidget {
  const TerminalTitle({
    super.key,
    required this.scheme,
    required this.target,
    required this.status,
    required this.compact,
    required this.onTap,
  });
  final TerminalScheme scheme;
  final SshTarget target;
  final SshStatus status;

  /// Only the name, in a smaller size (a keyboard leaves little height).
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: context.l10n.terminalSessionSemantics(
      escapedCommandPreview(target.label),
      terminalStatusLabel(context.l10n, status),
    ),
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            escapedCommandPreview(target.displayNameFor(context.l10n)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: scheme.theme.foreground,
              fontSize: compact ? 14 : 17,
              height: 1.15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!compact)
            Row(
              key: const ValueKey('terminal-status'),
              children: [
                Flexible(
                  flex: 2,
                  child: TerminalStatusPill(scheme: scheme, status: status),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    escapedCommandPreview(target.label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontFamily: terminalFontFamily,
                      fontSize: 11,
                      height: 1.15,
                      color: scheme.muted,
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

/// Status chip under the title: green when connected, amber while
/// connecting, red when failed, grey otherwise.
class TerminalStatusPill extends StatelessWidget {
  const TerminalStatusPill({
    super.key,
    required this.scheme,
    required this.status,
  });
  final TerminalScheme scheme;
  final SshStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = switch (status) {
      SshStatus.connected => (
        scheme.theme.green,
        scheme.theme.green.withValues(alpha: .15),
      ),
      SshStatus.connecting || SshStatus.verifying || SshStatus.authenticating =>
        (scheme.theme.yellow, scheme.theme.yellow.withValues(alpha: .15)),
      SshStatus.failed => (
        scheme.theme.red,
        scheme.theme.red.withValues(alpha: .15),
      ),
      _ => (scheme.muted, scheme.muted.withValues(alpha: .12)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              terminalStatusLabel(context.l10n, status),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                fontSize: 11,
                height: 1.15,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Only before a session exists: connecting (with cancel) or the idle
/// "connect" prompt. Once a session has ended the page closes instead.
class TerminalConnectionBanner extends StatelessWidget {
  const TerminalConnectionBanner({
    super.key,
    required this.scheme,
    required this.connecting,
    required this.onCancel,
    required this.onConnect,
  });
  final TerminalScheme scheme;
  final bool connecting;
  final VoidCallback onCancel, onConnect;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('terminal-connection-banner'),
    width: double.infinity,
    color: scheme.chrome,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .25,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  connecting
                      ? context.l10n.terminalEstablishingSecure
                      : context.l10n.terminalOffline,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (connecting)
                  TextButton(
                    key: const ValueKey('terminal-disconnect'),
                    onPressed: onCancel,
                    child: Text(context.l10n.terminalCancelConnection),
                  )
                else
                  TextButton(
                    key: const ValueKey('terminal-connect'),
                    onPressed: kIsWeb ? null : onConnect,
                    child: Text(context.l10n.terminalConnect),
                  ),
              ],
            ),
            if (kIsWeb) Text(context.l10n.terminalBrowserUnsupported),
          ],
        ),
      ),
    ),
  );
}

class TerminalNoticeBanner extends StatelessWidget {
  const TerminalNoticeBanner({
    super.key,
    required this.scheme,
    required this.text,
    required this.onDismiss,
  });
  final TerminalScheme scheme;
  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Container(
    color: scheme.chrome,
    padding: const EdgeInsets.only(left: 16, right: 4),
    child: Row(
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 80),
            child: SingleChildScrollView(
              child: Text(text, style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
        ),
        IconButton(
          tooltip: context.l10n.terminalDismissNotice,
          onPressed: onDismiss,
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    ),
  );
}

/// Copy / clear actions floating over the terminal while text is selected.
class TerminalSelectionBar extends StatelessWidget {
  const TerminalSelectionBar({
    super.key,
    required this.scheme,
    required this.onCopy,
    required this.onClear,
  });
  final TerminalScheme scheme;
  final VoidCallback onCopy, onClear;

  @override
  Widget build(BuildContext context) => Material(
    color: scheme.chrome,
    elevation: 4,
    borderRadius: BorderRadius.circular(12),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          key: const ValueKey('terminal-copy-selection'),
          onPressed: onCopy,
          icon: const Icon(Icons.copy_outlined, size: 18),
          label: Text(context.l10n.terminalCopy),
        ),
        IconButton(
          tooltip: context.l10n.terminalClearSelection,
          onPressed: onClear,
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    ),
  );
}

enum TerminalMenuAction { details, paste, sftp, scheme, reboot, shutdown }

/// Overflow menu of the top bar.
class TerminalMenuButton extends StatelessWidget {
  const TerminalMenuButton({
    super.key,
    required this.scheme,
    required this.sftpEnabled,
    required this.powerEnabled,
    required this.onOpened,
    required this.onSelected,
  });
  final TerminalScheme scheme;
  final bool sftpEnabled, powerEnabled;
  final VoidCallback onOpened;
  final ValueChanged<TerminalMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    PopupMenuItem<TerminalMenuAction> item(
      TerminalMenuAction value,
      String Function(AppLocalizations l10n) label, {
      bool enabled = true,
    }) => PopupMenuItem(
      value: value,
      enabled: enabled,
      child: Builder(builder: (context) => Text(label(context.l10n))),
    );
    return PopupMenuButton<TerminalMenuAction>(
      tooltip: context.l10n.terminalMenu,
      color: scheme.key,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onOpened: onOpened,
      onSelected: onSelected,
      itemBuilder: (_) => [
        item(TerminalMenuAction.details, (l10n) => l10n.terminalSessionDetails),
        item(TerminalMenuAction.paste, (l10n) => l10n.terminalPasteIntoDraft),
        item(
          TerminalMenuAction.sftp,
          (l10n) => l10n.r3SftpTitle,
          enabled: sftpEnabled,
        ),
        item(TerminalMenuAction.scheme, (l10n) => l10n.r3TermColorScheme),
        const PopupMenuDivider(),
        item(
          TerminalMenuAction.reboot,
          (l10n) => l10n.terminalSshRestart,
          enabled: powerEnabled,
        ),
        item(
          TerminalMenuAction.shutdown,
          (l10n) => l10n.terminalSshShutdown,
          enabled: powerEnabled,
        ),
      ],
    );
  }
}

/// The "current session" dialog behind the title. [dimensions] is evaluated
/// whenever the dialog builds, so it shows the live status and size.
Future<void> showTerminalSessionDetails(
  BuildContext context, {
  required SshTarget target,
  required String Function(AppLocalizations l10n) dimensions,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    scrollable: true,
    title: Text(context.l10n.terminalCurrentSession),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          escapedCommandPreview(target.displayNameFor(context.l10n)),
        ),
        const SizedBox(height: 8),
        SelectableText(
          escapedCommandPreview(target.label),
          textDirection: TextDirection.ltr,
        ),
        const SizedBox(height: 12),
        Text(dimensions(context.l10n)),
        const SizedBox(height: 12),
        Text(context.l10n.terminalSelectionHelp),
        const SizedBox(height: 12),
        Text(context.l10n.terminalInputHelp),
        const SizedBox(height: 12),
        Text(context.l10n.terminalBackgroundHelp),
        const SizedBox(height: 12),
        Text(context.l10n.terminalOfflineFont),
        TextButton(
          onPressed: () => showLicensePage(context: context),
          child: Text(context.l10n.terminalLicenses),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.connectionClose),
      ),
    ],
  ),
);
