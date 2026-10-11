import '../l10n/locale_preference.dart';

import '../core/net_address.dart';

import 'package:flutter/material.dart';

import '../core/app_theme.dart' show InfoNote;
import '../security/host_trust.dart';
import 'snippet.dart' show escapedCommandPreview;
import 'ssh_service.dart';

/// Host-key verification and key-passphrase prompts shared by every screen
/// that drives [SshService.connect] / [SshService.connectSftp] (terminal and
/// SFTP). The security decisions stay in the service; this only asks the
/// user and drops answers that arrive after the attempt was invalidated.
class SshPrompts {
  SshPrompts({
    required this.service,
    required this.dialogContext,
    required this.targetLabel,
    required this.isOpen,
  });

  final SshService service;

  /// Context for dialogs; read lazily because the page may rebuild.
  final BuildContext Function() dialogContext;
  final String targetLabel;

  /// False once the owning page is closing or its target was replaced.
  final bool Function() isOpen;

  Future<String?> requestKeyPassphrase(String credentialName) async {
    if (!isOpen()) {
      return null;
    }
    final generation = service.generation;
    final value = await showDialog<String>(
      context: dialogContext(),
      barrierDismissible: false,
      builder: (_) => KeyPassphraseDialog(
        service: service,
        generation: generation,
        credentialName: credentialName,
        target: targetLabel,
      ),
    );
    if (!isOpen() ||
        service.generation != generation ||
        service.status != SshStatus.connecting) {
      return null;
    }
    return value;
  }

  Future<bool> verifyHost(HostVerificationRequest request) async {
    if (!isOpen()) {
      return false;
    }
    final generation = service.generation;
    bool current() =>
        isOpen() &&
        service.generation == generation &&
        service.status == SshStatus.verifying;
    if (request.status == HostTrustStatus.changed) {
      final start = await showDialog<bool>(
        context: dialogContext(),
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(context.l10n.terminalHostChanged),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(
                  formatHostPort(request.identity.host, request.identity.port),
                ),
                InfoNote(context.l10n.terminalHostChangedHelp),
                Text(context.l10n.terminalPreviousFingerprint),
                SelectableText(
                  request.previous?.fingerprint ??
                      context.l10n.terminalNoRecord,
                ),
                const SizedBox(height: 12),
                Text(context.l10n.terminalCurrentFingerprint),
                SelectableText(request.identity.fingerprint),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.terminalRejectConnection),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.terminalReverify),
            ),
          ],
        ),
      );
      if (start != true || !current()) {
        return false;
      }
    }
    if (!current()) {
      return false;
    }
    final accepted = await showDialog<bool>(
      context: dialogContext(),
      barrierDismissible: false,
      builder: (_) => VerifyHostDialog(
        service: service,
        generation: generation,
        request: request,
      ),
    );
    return accepted == true && current();
  }
}

class VerifyHostDialog extends StatefulWidget {
  const VerifyHostDialog({
    super.key,
    required this.service,
    required this.generation,
    required this.request,
  });
  final SshService service;
  final int generation;
  final HostVerificationRequest request;
  @override
  State<VerifyHostDialog> createState() => VerifyHostDialogState();
}

class VerifyHostDialogState extends State<VerifyHostDialog> {
  bool _checked = false, _submitted = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) {
      final identity = widget.request.identity;
      final changed = widget.request.status == HostTrustStatus.changed;
      final current =
          widget.service.generation == widget.generation &&
          widget.service.status == SshStatus.verifying;
      return AlertDialog(
        scrollable: true,
        title: Text(
          changed
              ? context.l10n.terminalVerifyNewHost
              : context.l10n.terminalFirstHostVerification,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                context.l10n.terminalHostIdentity(
                  (identity.host).toString(),
                  (identity.port).toString(),
                  (identity.algorithm).toString(),
                ),
              ),
              const SizedBox(height: 12),
              Text(context.l10n.terminalSha256Fingerprint),
              SelectableText(identity.fingerprint),
              const SizedBox(height: 12),
              Text(context.l10n.terminalFullHostKey),
              SelectableText('${identity.algorithm} ${identity.publicKey}'),
              InfoNote(context.l10n.terminalIndependentVerificationHelp),
              CheckboxListTile(
                key: const ValueKey('host-verified-check'),
                contentPadding: EdgeInsets.zero,
                value: _checked,
                onChanged: current
                    ? (value) => setState(() => _checked = value == true)
                    : null,
                title: Text(
                  changed
                      ? context.l10n.terminalConfirmedChangedHost
                      : context.l10n.terminalConfirmedHost,
                ),
              ),
              if (!current) InfoNote(context.l10n.terminalVerificationExpired),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.terminalRejectConnection),
          ),
          FilledButton(
            key: const ValueKey('host-verified-confirm'),
            onPressed: current && _checked && !_submitted
                ? () {
                    setState(() => _submitted = true);
                    Navigator.pop(context, true);
                  }
                : null,
            child: Text(
              changed
                  ? context.l10n.terminalUpdateTrustAuthenticate
                  : context.l10n.terminalTrustAuthenticate,
            ),
          ),
        ],
      );
    },
  );
}

/// The passphrase exists only in this obscured prompt and the current connect
/// call. It is never copied to metadata, draft, terminal output or a store.
class KeyPassphraseDialog extends StatefulWidget {
  const KeyPassphraseDialog({
    super.key,
    required this.service,
    required this.generation,
    required this.credentialName,
    required this.target,
  });
  final SshService service;
  final int generation;
  final String credentialName, target;
  @override
  State<KeyPassphraseDialog> createState() => KeyPassphraseDialogState();
}

class KeyPassphraseDialogState extends State<KeyPassphraseDialog>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  bool _submitted = false, _invalidated = false;

  bool get _current =>
      !_invalidated &&
      !_submitted &&
      widget.service.generation == widget.generation &&
      widget.service.status == SshStatus.connecting;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_serviceChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  void _serviceChanged() {
    if (!mounted || _submitted) {
      return;
    }
    if (widget.service.generation != widget.generation ||
        widget.service.status != SshStatus.connecting) {
      _input.clear();
      setState(() => _invalidated = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _input.clear();
      if (mounted) {
        setState(() => _invalidated = true);
      }
    }
  }

  void _cancel() {
    _input.clear();
    Navigator.pop(context);
  }

  void _submit() {
    if (!_current || _input.text.isEmpty) {
      return;
    }
    final value = _input.text;
    _submitted = true;
    _input.clear();
    Navigator.pop(context, value);
  }

  @override
  void dispose() {
    widget.service.removeListener(_serviceChanged);
    WidgetsBinding.instance.removeObserver(this);
    _input.clear();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(context.l10n.terminalUnlockKey),
    content: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            escapedCommandPreview(widget.target),
            textDirection: TextDirection.ltr,
          ),
          Text(
            context.l10n.terminalCredentialName(
              (escapedCommandPreview(widget.credentialName)).toString(),
            ),
          ),
          InfoNote(context.l10n.terminalPassphraseHelp),
          TextField(
            key: const ValueKey('ssh-key-passphrase'),
            controller: _input,
            enabled: _current,
            obscureText: true,
            enableIMEPersonalizedLearning: false,
            autocorrect: false,
            enableSuggestions: false,
            enableInteractiveSelection: false,
            autofillHints: const [],
            maxLength: 4096,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: context.l10n.terminalKeyPassphrase,
            ),
          ),
          if (_invalidated) InfoNote(context.l10n.terminalPassphraseCleared),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _cancel,
        child: Text(context.l10n.terminalCancelConnection),
      ),
      FilledButton(
        key: const ValueKey('ssh-key-passphrase-submit'),
        onPressed: _current && _input.text.isNotEmpty ? _submit : null,
        child: Text(context.l10n.terminalUnlockOnce),
      ),
    ],
  );
}
