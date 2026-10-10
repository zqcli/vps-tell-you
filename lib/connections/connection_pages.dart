import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import '../core/app_viewport.dart';
import '../core/ui/ui.dart';
import '../security/host_trust.dart';
import '../security/security_pages.dart';
import '../security/ssh_configuration_page.dart';
import '../servers/ledger_controller.dart';
import 'connection_form.dart';
import 'ssh_service.dart';
import 'terminal_page.dart';

/// Saved configurations and temporary targets use the same terminal flow.
/// Opening this page only reads metadata; the connect button is the network gate.
class SshConnectPage extends StatefulWidget {
  const SshConnectPage({
    super.key,
    required this.ledger,
    this.initialServerId,
    this.initialDraft = '',
    this.powerMode = false,
    this.serviceFactory,
  });
  final LedgerController ledger;
  final String? initialServerId;
  final String initialDraft;
  final bool powerMode;
  final SshServiceFactory? serviceFactory;

  @override
  State<SshConnectPage> createState() => _SshConnectPageState();
}

class _SshConnectPageState extends State<SshConnectPage> {
  final _form = GlobalKey<FormState>();
  bool _hasValidated = false;
  String? _validationLocale;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.l10n.localeName;
    if (_validationLocale != null &&
        _validationLocale != next &&
        _hasValidated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _form.currentState?.validate();
        }
      });
    }
    _validationLocale = next;
  }

  final _host = TextEditingController();
  final _port = TextEditingController(text: '22');
  final _username = TextEditingController();
  String? _serverId, _credentialId;
  LocalizedMessage? _error;
  bool _loading = true, _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await widget.ledger.security.initialize();
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _error = loaded
          ? null
          : LocalizedText((l10n) => l10n.connectionReadFailed);
      if (loaded) {
        _selectServer(widget.initialServerId);
      }
    });
  }

  void _selectServer(String? id) {
    _serverId = id;
    final config = id == null ? null : widget.ledger.security.configFor(id);
    _host.text = config?.host ?? widget.ledger.byId(id ?? '')?.host ?? '';
    _port.text = '${config?.port ?? 22}';
    _username.text = config?.username ?? '';
    _credentialId = config?.credentialId;
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_opening || kIsWeb) {
      return;
    }
    _hasValidated = true;
    if (!_form.currentState!.validate()) {
      return;
    }
    final server = widget.ledger.byId(_serverId ?? '');
    if (server?.isDemo == true || server?.archived == true) {
      return;
    }
    setState(() => _opening = true);
    try {
      final target = SshTarget(
        name: server?.name ?? '',
        isTemporary: server == null,
        host: normalizedHost(_host.text),
        port: int.parse(_port.text),
        username: _username.text.trim(),
        credentialId: _credentialId!,
        serverId: _serverId,
      );
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: sshTerminalRouteName),
          builder: (_) => TerminalPage(
            ledger: widget.ledger,
            target: target,
            initialDraft: widget.initialDraft,
            powerMode: widget.powerMode,
            connectOnOpen: true,
            serviceFactory: widget.serviceFactory,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = LocalizedText((l10n) => l10n.connectionInvalidDetails),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  /// Local metadata only: a pinned key for this host and port means the
  /// first-use verification is already done. Nothing is contacted here.
  bool? get _hostKeyTrusted {
    try {
      final host = normalizedHost(_host.text);
      final port = int.tryParse(_port.text);
      if (port == null) {
        return null;
      }
      return widget.ledger.security.hostTrusts.any(
        (item) => item.host == host && item.port == port,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickServer() async {
    final l10n = context.l10n;
    final id = await showAppPicker<String>(
      context,
      title: l10n.connectionTargetServer,
      selected: _serverId ?? '',
      options: [
        AppPickerOption(value: '', title: l10n.connectionTemporaryTarget),
        for (final item in widget.ledger.active)
          AppPickerOption(
            value: item.id,
            title:
                '${item.name}${item.isDemo ? l10n.connectionDemoSuffix : ''}',
          ),
      ],
    );
    if (id == null || !mounted) {
      return;
    }
    setState(() => _selectServer(id == '' ? null : id));
  }

  Future<void> _manageCredentials() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => SecurityPage(ledger: widget.ledger)),
    );
    if (mounted) {
      setState(() {});
    }
  }

  /// Built from the sheet's own context so that an open list follows a live
  /// language change.
  Future<String?> _chooseCredential() => showAppSheet<String>(
    context,
    title: context.l10n.connectionSavedCredentials,
    builder: (sheetContext) {
      final palette = sheetContext.palette;
      return AppSection(
        topSpacing: 4,
        children: [
          for (final item in widget.ledger.security.credentials)
            AppRow(
              title:
                  '${item.name} · ${credentialKind(item, l10n: sheetContext.l10n)}',
              trailing: item.id == _credentialId
                  ? Icon(Icons.check_rounded, size: 22, color: palette.primary)
                  : null,
              onTap: () => Navigator.pop(sheetContext, item.id),
            ),
        ],
      );
    },
  );

  Future<void> _pickCredential(FormFieldState<String> field) async {
    if (widget.ledger.security.credentials.isEmpty) {
      await _manageCredentials();
      return;
    }
    final id = await _chooseCredential();
    if (id == null || !mounted) {
      return;
    }
    setState(() => _credentialId = id);
    if (field.hasError) {
      field.validate();
    }
  }

  Future<void> _editSavedSettings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SshConfigurationPage(ledger: widget.ledger, serverId: _serverId!),
      ),
    );
    if (mounted) {
      setState(() => _selectServer(_serverId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final security = widget.ledger.security;
    final server = widget.ledger.byId(_serverId ?? '');
    final credential = security.credentials
        .where((item) => item.id == _credentialId)
        .firstOrNull;
    final trusted = _hostKeyTrusted;
    final notes = [
      l10n.connectionIdentityFirst,
      l10n.connectionTemporaryChangesHelp,
      if (widget.initialDraft.isNotEmpty) l10n.connectionSnippetDraftOnly,
    ];
    final canConnect =
        !(_opening ||
            kIsWeb ||
            server?.isDemo == true ||
            security.needsReload ||
            _error != null);
    return AppScaffold(
      title: widget.powerMode
          ? l10n.connectionChoosePowerTarget
          : l10n.sshQuickConnect,
      largeTitle: false,
      bottomBar: _loading
          ? null
          : AppButton(
              key: const ValueKey('connect-start'),
              label: l10n.connectionReviewConnect,
              icon: widget.powerMode
                  ? Icons.power_settings_new_rounded
                  : Icons.terminal,
              destructive: widget.powerMode,
              expand: true,
              onPressed: canConnect ? _connect : null,
            ),
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CupertinoActivityIndicator()),
          )
        else
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (kIsWeb)
                  AppBanner(
                    tone: AppTone.amber,
                    icon: Icons.warning_amber_rounded,
                    text: l10n.connectionWebPreviewWarning,
                  ),
                if (widget.powerMode)
                  AppBanner(
                    tone: AppTone.red,
                    icon: Icons.power_settings_new_rounded,
                    text: l10n.connectionPowerAfterConnect,
                  ),
                if (_error != null) ...[
                  AppBanner(
                    tone: AppTone.red,
                    icon: Icons.error_outline_rounded,
                    text: _error!.messageFor(l10n),
                  ),
                  AppSection(
                    topSpacing: 10,
                    children: [
                      AppRow(
                        title: l10n.connectionReloadDetails,
                        center: true,
                        onTap: _load,
                      ),
                    ],
                  ),
                ],
                AppSection(
                  header: l10n.uiConnTarget,
                  footer: server?.isDemo == true
                      ? l10n.connectionDemoBlocked
                      : null,
                  children: [
                    AppFormRow.pick(
                      key: const ValueKey('connect-target'),
                      label: l10n.connectionTargetServer,
                      value: server == null
                          ? l10n.connectionTemporaryTarget
                          : '${server.name}${server.isDemo ? l10n.connectionDemoSuffix : ''}',
                      onTap: _pickServer,
                    ),
                    ValidatedTextRow(
                      fieldKey: const ValueKey('connect-host'),
                      label: l10n.serverHostAddress,
                      hint: l10n.connectionAddressHint,
                      controller: _host,
                      mono: true,
                      keyboardType: TextInputType.url,
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        try {
                          normalizedHost(value);
                          return null;
                        } catch (_) {
                          return l10n.connectionValidHost;
                        }
                      },
                    ),
                    ValidatedTextRow(
                      fieldKey: const ValueKey('connect-port'),
                      label: l10n.connectionPort,
                      controller: _port,
                      mono: true,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        final port = int.tryParse(value);
                        return port == null || port < 1 || port > 65535
                            ? l10n.connectionPortRange
                            : null;
                      },
                    ),
                    ValidatedTextRow(
                      fieldKey: const ValueKey('connect-user'),
                      label: l10n.connectionUsername,
                      controller: _username,
                      maxLength: 64,
                      validator: (value) =>
                          value.trim().isEmpty ||
                              RegExp(r'[\x00-\x20\x7f]').hasMatch(value.trim())
                          ? l10n.connectionValidUsername
                          : null,
                    ),
                  ],
                ),
                AppSection(
                  header: l10n.uiConnCredential,
                  children: [
                    FormField<String>(
                      validator: (_) =>
                          security.credentials.any(
                            (item) => item.id == _credentialId,
                          )
                          ? null
                          : l10n.connectionChooseCredentials,
                      builder: (field) => AppFormRow.pick(
                        key: ValueKey(
                          'connect-credential-$_serverId-$_credentialId',
                        ),
                        label: l10n.connectionSavedCredentials,
                        value: credential == null
                            ? null
                            : '${credential.name} · ${credentialKind(credential, l10n: l10n)}',
                        placeholder: '—',
                        errorText: field.errorText,
                        onTap: () => _pickCredential(field),
                      ),
                    ),
                    if (credential != null &&
                        credential.defaultUsername.isNotEmpty)
                      AppRow(
                        title: l10n.connectionUseDefaultUsername(
                          credential.defaultUsername,
                        ),
                        center: true,
                        onTap: () => setState(
                          () => _username.text = credential.defaultUsername,
                        ),
                      ),
                    AppRow(
                      title: l10n.connectionManageCredentials,
                      chevron: true,
                      onTap: _manageCredentials,
                    ),
                    if (_serverId != null)
                      AppRow(
                        title: l10n.connectionEditSavedSettings,
                        chevron: true,
                        onTap: _editSavedSettings,
                      ),
                  ],
                ),
                AppSection(
                  header: l10n.uiConnStatus,
                  footerWidget: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final note in notes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(note, style: context.footnoteStyle),
                        ),
                    ],
                  ),
                  children: [
                    AppKeyValueRow(
                      label: l10n.uiConnHostKey,
                      valueWidget: trusted == null
                          ? null
                          : StatusPill(
                              trusted
                                  ? l10n.uiConnHostKeyVerified
                                  : l10n.uiConnHostKeyFirstUse,
                              tone: trusted ? AppTone.green : AppTone.amber,
                              dot: true,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
