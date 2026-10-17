import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/net_address.dart';
import '../core/ui/ui.dart';
import '../servers/ledger_controller.dart';
import 'proxy_pages.dart';
import 'security_models.dart';
import 'security_pages.dart';
import '../l10n/generated/app_localizations.dart';
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
  final host = TextEditingController(),
      port = TextEditingController(),
      username = TextEditingController();
  String? credentialId, proxyId;
  int revision = -1;

  /// Errors are derived while building, so they follow the app language and
  /// clear as soon as the input becomes valid.
  bool validationAttempted = false;
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
    host.text =
        config?.host ??
        widget.ledger.byId(widget.serverId)?.primaryAddress ??
        '';
    port.text = '${config?.port ?? 22}';
    username.text = config?.username ?? '';
    credentialId = config?.credentialId;
    proxyId = config?.proxyId;
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
        !await showAppConfirm(
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
    final l10n = context.l10n;
    final chosen = await showAppPicker<String>(
      context,
      title: l10n.securityChooseCredential,
      selected: credentialId ?? '',
      options: [
        AppPickerOption(
          value: '',
          title: l10n.securityUnlinkCurrentCredential,
          subtitle: l10n.securityChooseCredentialLater,
          icon: Icons.link_off,
          iconColor: AppTints.orange,
        ),
        for (final c in security.credentials)
          AppPickerOption(
            value: c.id,
            title: c.name,
            subtitle: l10n.securityCredentialChoiceSubtitle(
              credentialKind(c, l10n: l10n),
              c.defaultUsername.isEmpty
                  ? l10n.securityNotSet
                  : c.defaultUsername,
            ),
            icon: credentialIcon(c.kind),
            iconColor: credentialTint(c.kind),
          ),
      ],
      footnote: security.credentials.isEmpty
          ? l10n.securityNoCredentialsToChoose
          : null,
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
    final adopt = await showAppConfirm(
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

  Future<void> chooseProxyRow() async {
    final choice = await chooseProxy(
      context,
      widget.ledger,
      selectedId: proxyId,
    );
    if (!mounted || choice == null) return;
    setState(() {
      proxyId = choice.savedId;
      dirty = true;
    });
  }

  String? hostError(AppLocalizations l10n) {
    if (!validationAttempted) return null;
    final text = host.text.trim();
    if (text.isEmpty) return l10n.securityHostRequired;
    // Same rules as the connection itself: IPv4, IPv6 (brackets and a
    // link-local zone allowed) or a DNS name, nothing numeric-ambiguous.
    return NetAddress.tryParse(text) == null ? l10n.connectionValidHost : null;
  }

  String? portError(AppLocalizations l10n) {
    if (!validationAttempted) return null;
    final n = int.tryParse(port.text);
    return n == null || n < 1 || n > 65535 ? l10n.securityPortRequired : null;
  }

  String? usernameError(AppLocalizations l10n) =>
      validationAttempted && username.text.trim().isEmpty
      ? l10n.securityConnectionUsernameRequired
      : null;

  Future<void> save() async {
    if (saving) return;
    final l10n = context.l10n;
    setState(() => validationAttempted = true);
    if (hostError(l10n) != null ||
        portError(l10n) != null ||
        usernameError(l10n) != null) {
      return;
    }
    setState(() => saving = true);
    final saved = await widget.ledger.security.saveSshConfiguration(
      SshConfiguration(
        serverId: widget.serverId,
        host: host.text,
        port: int.parse(port.text),
        username: username.text,
        credentialId: credentialId,
        proxyId: proxyId,
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
      final l10n = context.l10n;
      final security = widget.ledger.security;
      final credential = security.credentials
          .where((c) => c.id == credentialId)
          .firstOrNull;
      final proxy = security.proxyById(proxyId);
      return PopScope(
        canPop: allowPop || (!dirty && !saving),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) cancel();
        },
        child: AppScaffold(
          title: l10n.securitySshConfiguration,
          largeTitle: false,
          bottomBar: loading
              ? null
              : AppButton(
                  label: saving
                      ? l10n.securitySaving
                      : l10n.securitySaveSshConfiguration,
                  expand: true,
                  onPressed: saving || security.busy || security.needsReload
                      ? null
                      : save,
                ),
          children: loading
              ? const [
                  Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CupertinoActivityIndicator()),
                  ),
                ]
              : [
                  SecurityNotice(controller: security),
                  AppSection(
                    header:
                        widget.ledger.byId(widget.serverId)?.name ??
                        l10n.securityServerFallback,
                    footerWidget: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.securitySshConfigurationNotice,
                          style: context.footnoteStyle,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.securityConnectionUsernameNotice,
                          style: context.footnoteStyle,
                        ),
                      ],
                    ),
                    children: [
                      AppFormRow(
                        label: l10n.securityHostAddress,
                        required: true,
                        errorText: hostError(l10n),
                        child: AppTextField(
                          key: const ValueKey('ssh-host'),
                          controller: host,
                          enabled: !saving,
                          autocorrect: false,
                          keyboardType: TextInputType.url,
                          hint: l10n.securityHostHint,
                          label: l10n.securityHostAddress,
                          onChanged: (_) => setState(() => dirty = true),
                        ),
                      ),
                      AppFormRow(
                        label: l10n.securityPort,
                        required: true,
                        errorText: portError(l10n),
                        child: AppTextField(
                          key: const ValueKey('ssh-port'),
                          controller: port,
                          enabled: !saving,
                          keyboardType: TextInputType.number,
                          label: l10n.securityPort,
                          onChanged: (_) => setState(() => dirty = true),
                        ),
                      ),
                      AppFormRow(
                        label: l10n.securityConnectionUsername,
                        required: true,
                        errorText: usernameError(l10n),
                        child: AppTextField(
                          key: const ValueKey('ssh-username'),
                          controller: username,
                          enabled: !saving,
                          autocorrect: false,
                          maxLength: 64,
                          label: l10n.securityConnectionUsername,
                          onChanged: (_) => setState(() => dirty = true),
                        ),
                      ),
                    ],
                  ),
                  AppSection(
                    header: l10n.securityLoginCredential,
                    footer: l10n.securityConfigurationOnlyNotice,
                    children: [
                      AppRow(
                        icon: credential == null
                            ? Icons.key_off_outlined
                            : credentialIcon(credential.kind),
                        iconColor: credential == null
                            ? AppTints.orange
                            : credentialTint(credential.kind),
                        title:
                            credential?.name ??
                            l10n.securityCredentialNotConfigured,
                        subtitle: credential == null
                            ? l10n.securityCredentialRequiredBeforeConnect
                            : l10n.securityChangeCredentialSubtitle(
                                credentialKind(credential, l10n: l10n),
                              ),
                        chevron: true,
                        enabled: !(saving || security.needsReload),
                        onTap: chooseCredential,
                      ),
                      AppRow(
                        icon: Icons.manage_accounts_outlined,
                        iconColor: AppTints.indigo,
                        title: l10n.securityManageCredentials,
                        chevron: true,
                        enabled: !saving,
                        onTap: () async {
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SecurityPage(ledger: widget.ledger),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                    ],
                  ),
                  AppSection(
                    header: l10n.r13ProxyRow,
                    footer: l10n.r13ProxyRowFooter,
                    children: [
                      AppRow(
                        key: const ValueKey('ssh-proxy-row'),
                        icon: proxy == null
                            ? Icons.arrow_outward_rounded
                            : proxyIcon,
                        iconColor: proxy == null ? AppTints.slate : proxyTint,
                        title: proxy?.name ?? l10n.r13ProxyDirect,
                        subtitle: proxy == null
                            ? l10n.r13ProxyDirectSubtitle
                            : proxySummary(proxy),
                        chevron: true,
                        enabled: !(saving || security.needsReload),
                        onTap: chooseProxyRow,
                      ),
                    ],
                  ),
                ],
        ),
      );
    },
  );
}
