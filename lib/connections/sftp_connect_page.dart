import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/ui/ui.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../security/security_models.dart';
import '../security/ssh_configuration_page.dart';
import '../servers/ledger_controller.dart';
import 'sftp_pages.dart';
import 'sftp_session.dart';
import 'sftp_support.dart';
import 'ssh_prompts.dart';
import 'ssh_service.dart';
import 'terminal_page.dart' show SshServiceFactory;

/// Opens SFTP for a saved server: connect (same host-key and passphrase
/// prompts as the terminal), then the file browser; shows a toast if the
/// browser was closed by the app (for example, backgrounding).
Future<void> openSftpForServer(
  BuildContext context, {
  required LedgerController ledger,
  required String serverId,
  SshServiceFactory? serviceFactory,
  SftpLocalFiles localFiles = const SystemSftpLocalFiles(),
}) async {
  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => SftpConnectPage(
        ledger: ledger,
        serverId: serverId,
        serviceFactory: serviceFactory,
        localFiles: localFiles,
        // The connect page is replaced by the browser, so the browser's
        // closing reason is handed back through this callback.
        onBrowserClosed: (reason) {
          if (reason != null && context.mounted) {
            showAppToast(context, reason);
          }
        },
      ),
    ),
  );
}

/// Connecting state of a standalone SFTP connection. On success it replaces
/// itself with [SftpBrowserPage], which then owns the connection.
class SftpConnectPage extends StatefulWidget {
  const SftpConnectPage({
    super.key,
    required this.ledger,
    required this.serverId,
    this.serviceFactory,
    this.localFiles = const SystemSftpLocalFiles(),
    this.onBrowserClosed,
  });
  final LedgerController ledger;
  final String serverId;
  final SshServiceFactory? serviceFactory;
  final SftpLocalFiles localFiles;

  /// Called when the browser that replaced this page is closed; the argument
  /// is the reason if the app closed it (for example, backgrounding).
  final void Function(String? reason)? onBrowserClosed;

  @override
  State<SftpConnectPage> createState() => _SftpConnectPageState();
}

class _SftpConnectPageState extends State<SftpConnectPage> {
  SshService? _service;
  SshTarget? _target;
  LocalizedMessage? _error;
  bool _needsCredential = false, _handedOver = false, _cancelled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_connect());
    });
  }

  @override
  void dispose() {
    _service?.removeListener(_changed);
    if (!_handedOver) {
      _service?.disconnect();
      _service?.dispose();
    }
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _connect() async {
    if (kIsWeb) {
      return _fail(LocalizedText((l10n) => l10n.sshBrowserUnsupported));
    }
    final security = widget.ledger.security;
    setState(() {
      _error = null;
      _needsCredential = false;
      _cancelled = false;
    });
    if (!await security.initialize()) {
      return _fail(LocalizedText((l10n) => l10n.connectionReadFailed));
    }
    if (!mounted) return;
    final config = security.configFor(widget.serverId);
    final server = widget.ledger.byId(widget.serverId);
    final credentialId = config?.credentialId;
    if (config == null ||
        server == null ||
        credentialId == null ||
        !security.credentials.any((item) => item.id == credentialId)) {
      setState(() => _needsCredential = true);
      return _fail(LocalizedText((l10n) => l10n.r3SftpChooseCredential));
    }
    final target = SshTarget(
      name: server.name,
      host: config.host,
      port: config.port,
      username: config.username,
      credentialId: credentialId,
      serverId: widget.serverId,
    );
    _service?.removeListener(_changed);
    _service?.dispose();
    final service =
        widget.serviceFactory?.call(security) ??
        NativeSshService(security: security);
    _service = service;
    _target = target;
    service.addListener(_changed);
    final prompts = SshPrompts(
      service: service,
      dialogContext: () => context,
      targetLabel: target.label,
      isOpen: () => mounted && !_cancelled && !_handedOver,
    );
    try {
      final session = await service.connectSftp(
        target,
        verifyHost: prompts.verifyHost,
        requestKeyPassphrase: prompts.requestKeyPassphrase,
      );
      if (!mounted || _cancelled) {
        await session.close();
        return;
      }
      _handedOver = true;
      service.removeListener(_changed);
      final onClosed = widget.onBrowserClosed;
      unawaited(
        Navigator.of(context)
            .pushReplacement<String, void>(
              MaterialPageRoute<String>(
                builder: (_) => SftpBrowserPage(
                  session: session,
                  localFiles: widget.localFiles,
                  onClosed: service.dispose,
                ),
              ),
            )
            .then((reason) => onClosed?.call(reason)),
      );
    } on SecurityFailure catch (problem) {
      if (!_cancelled) _fail(problem);
    } on SftpException catch (problem) {
      if (!_cancelled) {
        _fail(LocalizedText((l10n) => sftpErrorText(l10n, problem)));
      }
    } catch (_) {
      if (!_cancelled) {
        _fail(LocalizedText((l10n) => l10n.sshConnectionIncomplete));
      }
    }
  }

  void _fail(LocalizedMessage message) {
    if (mounted) setState(() => _error = message);
  }

  void _cancel() {
    _cancelled = true;
    _service?.disconnect();
    Navigator.of(context).pop();
  }

  String _statusText(AppLocalizations l10n) =>
      switch (_service?.status ?? SshStatus.connecting) {
        SshStatus.verifying => l10n.terminalVerifying,
        SshStatus.authenticating => l10n.terminalAuthenticating,
        _ => l10n.r3SftpConnecting,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final error = _error;
    return PopScope(
      canPop: error != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: AppScaffold(
        title: l10n.r3SftpTitle,
        largeTitle: false,
        leading: error == null
            ? AppNavButton.text(
                l10n.cancel,
                key: const ValueKey('sftp-connect-cancel'),
                onPressed: _cancel,
              )
            : null,
        children: [
          if (error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 96, 32, 0),
              child: Column(
                children: [
                  const CupertinoActivityIndicator(radius: 14),
                  const SizedBox(height: 18),
                  Text(
                    _statusText(l10n),
                    key: const ValueKey('sftp-connect-status'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: palette.text),
                  ),
                  if (_target != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _target!.label,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: kMonoTextStyle.copyWith(
                        fontSize: 13,
                        color: palette.text2,
                      ),
                    ),
                  ],
                ],
              ),
            )
          else ...[
            AppEmptyState(
              icon: Icons.cloud_off_rounded,
              title: l10n.r3SftpConnectFailed,
              message: error.messageFor(l10n),
              actions: [
                if (_needsCredential)
                  AppButton(
                    key: const ValueKey('sftp-connect-settings'),
                    label: l10n.r3SftpSshSettings,
                    kind: AppButtonKind.tonal,
                    onPressed: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SshConfigurationPage(
                            ledger: widget.ledger,
                            serverId: widget.serverId,
                          ),
                        ),
                      );
                      if (mounted) unawaited(_connect());
                    },
                  )
                else
                  AppButton(
                    key: const ValueKey('sftp-connect-retry'),
                    label: l10n.r3SftpRetry,
                    kind: AppButtonKind.tonal,
                    onPressed: _connect,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
