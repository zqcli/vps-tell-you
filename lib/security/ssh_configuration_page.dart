import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../servers/ledger_controller.dart';
import 'security_models.dart';
import 'security_pages.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';

class SshConfigurationPage extends StatefulWidget {
  const SshConfigurationPage({
    super.key,
    required this.ledger,
    required this.serverId,
  });
  final LedgerController ledger;
  final String serverId;
  @override
  State<SshConfigurationPage> createState() => _SshConfigurationPageState();
}

class _SshConfigurationPageState extends State<SshConfigurationPage> {
  final form = GlobalKey<FormState>();
  final host = TextEditingController(),
      port = TextEditingController(),
      username = TextEditingController();
  String? credentialId;
  int revision = -1;
  bool validationAttempted = false;
  String? validationLocale;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.l10n.localeName;
    if (validationLocale != null &&
        validationLocale != next &&
        validationAttempted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) form.currentState?.validate();
      });
    }
    validationLocale = next;
  }

  bool loading = true, dirty = false, saving = false, allowPop = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    await widget.ledger.security.initialize();
    if (!mounted) return;
    final config = widget.ledger.security.configFor(widget.serverId);
    host.text = config?.host ?? widget.ledger.byId(widget.serverId)?.host ?? '';
    port.text = '${config?.port ?? 22}';
    username.text = config?.username ?? '';
    credentialId = config?.credentialId;
    revision = config?.revision ?? -1;
    setState(() => loading = false);
  }

  @override
  void dispose() {
    host.dispose();
    port.dispose();
    username.dispose();
    super.dispose();
  }

  Future<void> cancel() async {
    if (saving) return;
    if (dirty &&
        !await confirmAction(
          context,
          title: LocalizedText((l10n) => l10n.securityDiscardSshTitle),
          message: LocalizedText((l10n) => l10n.securityDiscardSshMessage),
          action: LocalizedText((l10n) => l10n.securityDiscardChanges),
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => allowPop = true);
    Navigator.pop(context);
  }

  Future<void> chooseCredential() async {
    final security = widget.ledger.security;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .55,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(20),
            children: [
              SectionTitle(context.l10n.securityChooseCredential),
              SettingRow(
                icon: Icons.link_off,
                title: context.l10n.securityUnlinkCurrentCredential,
                subtitle: context.l10n.securityChooseCredentialLater,
                onTap: () => Navigator.pop(context, ''),
              ),
              for (final c in security.credentials)
                SettingRow(
                  icon: c.kind == CredentialKind.privateKey
                      ? Icons.key_outlined
                      : Icons.person_outline,
                  title: c.name,
                  subtitle: context.l10n.securityCredentialChoiceSubtitle(
                    credentialKind(c, l10n: context.l10n),
                    c.defaultUsername.isEmpty
                        ? context.l10n.securityNotSet
                        : c.defaultUsername,
                  ),
                  onTap: () => Navigator.pop(context, c.id),
                ),
              if (security.credentials.isEmpty)
                InfoNote(context.l10n.securityNoCredentialsToChoose),
            ],
          ),
        ),
      ),
    );
    if (!mounted || chosen == null) return;
    setState(() {
      credentialId = chosen.isEmpty ? null : chosen;
      dirty = true;
    });
    final credential = security.credentials
        .where((c) => c.id == chosen)
        .firstOrNull;
    if (credential == null ||
        credential.defaultUsername.isEmpty ||
        username.text == credential.defaultUsername) {
      return;
    }
    final adopt = await confirmAction(
      context,
      title: LocalizedText((l10n) => l10n.securityAdoptUsernameTitle),
      message: LocalizedText(
        (l10n) => l10n.securityAdoptUsernameMessage(
          username.text.isEmpty ? l10n.securityNotEntered : username.text,
          credential.defaultUsername,
        ),
      ),
      action: LocalizedText((l10n) => l10n.securityAdoptUsername),
    );
    if (mounted && adopt) username.text = credential.defaultUsername;
  }

  Future<void> save() async {
    if (saving) return;
    validationAttempted = true;
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    final saved = await widget.ledger.security.saveSshConfiguration(
      SshConfiguration(
        serverId: widget.serverId,
        host: host.text,
        port: int.parse(port.text),
        username: username.text,
        credentialId: credentialId,
        revision: revision,
      ),
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (saved) {
      setState(() => allowPop = true);
      Navigator.pop(context);
      securityMessage(
        context,
        LocalizedText((l10n) => l10n.securitySshConfigurationSaved),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger.security,
    builder: (context, _) {
      final security = widget.ledger.security;
      final credential = security.credentials
          .where((c) => c.id == credentialId)
          .firstOrNull;
      return PopScope(
        canPop: allowPop || (!dirty && !saving),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) cancel();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.securitySshConfiguration),
            leading: IconButton(
              tooltip: context.l10n.securityCancelSshConfiguration,
              icon: const Icon(Icons.arrow_back),
              onPressed: saving ? null : cancel,
            ),
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: form,
                  onChanged: () {
                    if (!dirty) setState(() => dirty = true);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        widget.ledger.byId(widget.serverId)?.name ??
                            context.l10n.securityServerFallback,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      InfoNote(context.l10n.securitySshConfigurationNotice),
                      SecurityNotice(controller: security),
                      TextFormField(
                        key: const ValueKey('ssh-host'),
                        controller: host,
                        enabled: !saving,
                        autocorrect: false,
                        decoration: InputDecoration(
                          errorMaxLines: 8,
                          labelText: context.l10n.securityHostAddress,
                          hintText: context.l10n.securityHostHint,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? context.l10n.securityHostRequired
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('ssh-port'),
                        controller: port,
                        enabled: !saving,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          errorMaxLines: 8,
                          labelText: context.l10n.securityPort,
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return n == null || n < 1 || n > 65535
                              ? context.l10n.securityPortRequired
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('ssh-username'),
                        controller: username,
                        enabled: !saving,
                        autocorrect: false,
                        maxLength: 64,
                        decoration: InputDecoration(
                          errorMaxLines: 8,
                          labelText: context.l10n.securityConnectionUsername,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? context.l10n.securityConnectionUsernameRequired
                            : null,
                      ),
                      SectionTitle(
                        context.l10n.securityLoginCredential,
                        action: TextButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  await Navigator.push<void>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          SecurityPage(ledger: widget.ledger),
                                    ),
                                  );
                                  if (mounted) setState(() {});
                                },
                          child: Text(context.l10n.securityManageCredentials),
                        ),
                      ),
                      LedgerCard(
                        padding: EdgeInsets.zero,
                        child: SettingRow(
                          icon: Icons.key_outlined,
                          title:
                              credential?.name ??
                              context.l10n.securityCredentialNotConfigured,
                          subtitle: credential == null
                              ? context
                                    .l10n
                                    .securityCredentialRequiredBeforeConnect
                              : context.l10n.securityChangeCredentialSubtitle(
                                  credentialKind(
                                    credential,
                                    l10n: context.l10n,
                                  ),
                                ),
                          onTap: saving || security.needsReload
                              ? null
                              : chooseCredential,
                        ),
                      ),
                      InfoNote(context.l10n.securityConnectionUsernameNotice),
                      InfoNote(context.l10n.securityConfigurationOnlyNotice),
                      FilledButton(
                        onPressed:
                            saving || security.busy || security.needsReload
                            ? null
                            : save,
                        child: Text(
                          saving
                              ? context.l10n.securitySaving
                              : context.l10n.securitySaveSshConfiguration,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),
      );
    },
  );
}
