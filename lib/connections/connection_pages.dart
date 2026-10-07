import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/app_viewport.dart';
import '../security/host_trust.dart';
import '../security/security_pages.dart';
import '../security/ssh_configuration_page.dart';
import '../servers/ledger_controller.dart';
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

  @override
  Widget build(BuildContext context) {
    final security = widget.ledger.security;
    final server = widget.ledger.byId(_serverId ?? '');
    final credential = security.credentials
        .where((item) => item.id == _credentialId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.powerMode
              ? context.l10n.connectionChoosePowerTarget
              : context.l10n.sshQuickConnect,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  InfoNote(context.l10n.connectionIdentityFirst),
                  if (kIsWeb)
                    InfoNote(context.l10n.connectionWebPreviewWarning),
                  if (_error != null) ...[
                    InfoNote(_error!.messageFor(context.l10n)),
                    TextButton(
                      onPressed: _load,
                      child: Text(context.l10n.connectionReloadDetails),
                    ),
                  ],
                  DropdownButtonFormField<String>(
                    key: const ValueKey('connect-target'),
                    initialValue: _serverId ?? '',
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.connectionTargetServer,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Builder(
                          builder: (context) =>
                              Text(context.l10n.connectionTemporaryTarget),
                        ),
                      ),
                      for (final item in widget.ledger.active)
                        DropdownMenuItem(
                          value: item.id,
                          child: Builder(
                            builder: (context) => Text(
                              '${item.name}${item.isDemo ? context.l10n.connectionDemoSuffix : ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _selectServer(value == '' ? null : value);
                    }),
                  ),
                  if (server?.isDemo == true)
                    InfoNote(context.l10n.connectionDemoBlocked),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('connect-host'),
                    controller: _host,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: context.l10n.serverHostAddress,
                      hintText: context.l10n.connectionAddressHint,
                    ),
                    validator: (value) {
                      try {
                        normalizedHost(value ?? '');
                        return null;
                      } catch (_) {
                        return context.l10n.connectionValidHost;
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('connect-port'),
                    controller: _port,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.connectionPort,
                    ),
                    validator: (value) {
                      final port = int.tryParse(value ?? '');
                      return port == null || port < 1 || port > 65535
                          ? context.l10n.connectionPortRange
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('connect-user'),
                    controller: _username,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: 64,
                    decoration: InputDecoration(
                      labelText: context.l10n.connectionUsername,
                    ),
                    validator: (value) =>
                        value == null ||
                            value.trim().isEmpty ||
                            RegExp(r'[\x00-\x20\x7f]').hasMatch(value.trim())
                        ? context.l10n.connectionValidUsername
                        : null,
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'connect-credential-$_serverId-$_credentialId',
                    ),
                    initialValue: credential?.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.connectionSavedCredentials,
                    ),
                    items: [
                      for (final item in security.credentials)
                        DropdownMenuItem(
                          value: item.id,
                          child: Builder(
                            builder: (context) => Text(
                              '${item.name} · ${credentialKind(item, l10n: context.l10n)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (id) => setState(() => _credentialId = id),
                    validator: (_) => credential == null
                        ? context.l10n.connectionChooseCredentials
                        : null,
                  ),
                  if (credential != null &&
                      credential.defaultUsername.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(
                        () => _username.text = credential.defaultUsername,
                      ),
                      child: Text(
                        context.l10n.connectionUseDefaultUsername(
                          (credential.defaultUsername).toString(),
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SecurityPage(ledger: widget.ledger),
                        ),
                      );
                      if (mounted) {
                        setState(() {});
                      }
                    },
                    child: Text(context.l10n.connectionManageCredentials),
                  ),
                  if (_serverId != null)
                    TextButton(
                      onPressed: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SshConfigurationPage(
                              ledger: widget.ledger,
                              serverId: _serverId!,
                            ),
                          ),
                        );
                        if (mounted) {
                          setState(() => _selectServer(_serverId));
                        }
                      },
                      child: Text(context.l10n.connectionEditSavedSettings),
                    ),
                  InfoNote(context.l10n.connectionTemporaryChangesHelp),
                  if (widget.initialDraft.isNotEmpty)
                    InfoNote(context.l10n.connectionSnippetDraftOnly),
                  if (widget.powerMode)
                    InfoNote(context.l10n.connectionPowerAfterConnect),
                  FilledButton.icon(
                    key: const ValueKey('connect-start'),
                    onPressed:
                        _opening ||
                            kIsWeb ||
                            server?.isDemo == true ||
                            security.needsReload ||
                            _error != null
                        ? null
                        : _connect,
                    icon: const Icon(Icons.terminal),
                    label: Text(context.l10n.connectionReviewConnect),
                  ),
                ],
              ),
            ),
    );
  }
}
