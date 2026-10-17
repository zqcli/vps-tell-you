import 'package:flutter/material.dart';

import '../core/ui/ui.dart';
import '../l10n/locale_preference.dart';
import '../servers/ledger_controller.dart';
import 'credential_form.dart';
import 'credential_pages.dart';
import 'host_trust_pages.dart';
import 'security_controller.dart';
import 'security_models.dart';
import 'security_widgets.dart';

// Re-exported for app.dart and the connection pages (other areas).
export 'credential_pages.dart' show securityRouteObserver;
export 'security_widgets.dart' show credentialKind;

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key, required this.ledger});
  final LedgerController ledger;
  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  String search = '';
  CredentialKind? filter;
  bool loading = true;
  SecurityController get security => widget.ledger.security;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    await security.initialize();
    if (mounted) setState(() => loading = false);
  }

  Future<void> add() async {
    final kind = await showAppPicker<CredentialKind>(
      context,
      title: context.l10n.securityAddLoginCredential,
      options: [
        AppPickerOption(
          value: CredentialKind.privateKey,
          title: context.l10n.securityImportKey,
          subtitle: context.l10n.securityImportKeySubtitle,
          icon: credentialIcon(CredentialKind.privateKey),
          iconColor: credentialTint(CredentialKind.privateKey),
        ),
        AppPickerOption(
          value: CredentialKind.password,
          title: context.l10n.securitySaveUsernamePassword,
          subtitle: context.l10n.securityReusableCredential,
          icon: credentialIcon(CredentialKind.password),
          iconColor: credentialTint(CredentialKind.password),
        ),
      ],
    );
    if (kind != null && mounted) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CredentialForm(ledger: widget.ledger, kind: kind),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: security,
    builder: (context, _) {
      final l10n = context.l10n;
      final query = search.trim().toLowerCase();
      final linked = referenceCounts(security, (s) => s.credentialId);
      final visible = security.credentials
          .where(
            (c) =>
                (filter == null || c.kind == filter) &&
                '${c.name} ${c.defaultUsername}'.toLowerCase().contains(query),
          )
          .toList();
      return AppScaffold(
        title: l10n.securityTitle,
        actions: [
          AppNavButton.icon(
            Icons.add,
            tooltip: l10n.securityAddCredential,
            onPressed: security.busy || security.needsReload ? null : add,
          ),
        ],
        children: loading
            ? securityLoadingChildren
            : [
                SecurityNotice(controller: security),
                const SizedBox(height: 10),
                AppSearchField(
                  key: const ValueKey('credential-search'),
                  placeholder: l10n.securitySearchCredentials,
                  onChanged: (value) => setState(() => search = value),
                ),
                const SizedBox(height: 12),
                AppChipRow(
                  children: [
                    for (final entry in <CredentialKind?, String>{
                      null: l10n.securityAll,
                      CredentialKind.privateKey: l10n.securityPrivateKeyKind,
                      CredentialKind.password: l10n.securityPasswordKind,
                    }.entries)
                      AppChip(
                        label: entry.value,
                        selected: filter == entry.key,
                        onTap: () => setState(() => filter = entry.key),
                      ),
                  ],
                ),
                AppSection(
                  header: l10n.securityCredentialCount(
                    security.credentials.length,
                  ),
                  footer: l10n.securityCredentialStorageNotice,
                  children: [
                    if (visible.isEmpty)
                      securityEmptyRow(
                        context,
                        l10n.securityNoMatchingCredentials,
                      ),
                    for (final c in visible)
                      AppRow(
                        icon: credentialIcon(c.kind),
                        iconColor: credentialTint(c.kind),
                        title: c.name,
                        subtitle:
                            '${credentialKind(c, l10n: l10n)}${c.defaultUsername.isEmpty ? '' : ' · ${c.defaultUsername}'}',
                        trailing: StatusPill(
                          l10n.securityLinkedServerCount(linked[c.id] ?? 0),
                        ),
                        chevron: true,
                        onTap: () => credentialMenu(context, widget.ledger, c),
                      ),
                  ],
                ),
                AppSection(
                  header: l10n.securityDeviceConnectionSecurity,
                  footer: l10n.securityLocalCredentialNotice,
                  children: [
                    AppRow(
                      icon: Icons.verified_user_outlined,
                      iconColor: AppTints.blue,
                      title: l10n.securityTrustedHosts,
                      subtitle: l10n.securityTrustedHostsSubtitle,
                      chevron: true,
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HostTrustPage(ledger: widget.ledger),
                        ),
                      ),
                    ),
                    AppRow(
                      icon: Icons.lock_outline,
                      iconColor: AppTints.indigo,
                      title: l10n.securityCredentialProtection,
                      subtitle: l10n.securityCredentialProtectionSubtitle,
                      chevron: true,
                      onTap: () => showAppSheet<void>(
                        context,
                        title: l10n.securityCredentialProtection,
                        builder: (sheetContext) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppCard(
                              child: Text(
                                sheetContext
                                    .l10n
                                    .securityCredentialProtectionDetail,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.45,
                                  color: sheetContext.palette.text,
                                ),
                              ),
                            ),
                            SecurityAction(
                              child: AppButton(
                                label: sheetContext.l10n.gotIt,
                                expand: true,
                                onPressed: () => Navigator.pop(sheetContext),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
      );
    },
  );
}

Future<void> credentialMenu(
  BuildContext context,
  LedgerController ledger,
  CredentialMetadata credential,
) async {
  final action = await showAppSheet<String>(
    context,
    title: credential.name,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      return AppSection(
        topSpacing: 4,
        header: credentialKind(credential, l10n: l10n),
        children: [
          AppRow(
            icon: Icons.visibility_outlined,
            iconColor: AppTints.blue,
            title: l10n.securityViewDetails,
            subtitle: credential.kind == CredentialKind.privateKey
                ? l10n.securityPrivateKeyDetailsSubtitle
                : l10n.securityPasswordDetailsSubtitle,
            chevron: true,
            onTap: () => Navigator.pop(sheetContext, 'detail'),
          ),
          AppRow(
            icon: Icons.edit_outlined,
            iconColor: AppTints.indigo,
            title: l10n.securityEditCredential,
            subtitle: l10n.securityKeepSecret,
            chevron: true,
            onTap: () => Navigator.pop(sheetContext, 'edit'),
          ),
          AppRow(
            icon: Icons.link,
            iconColor: AppTints.teal,
            title: l10n.securityLinkedServers,
            subtitle: l10n.securityIndependentUsernames,
            chevron: true,
            onTap: () => Navigator.pop(sheetContext, 'references'),
          ),
          AppRow(
            icon: Icons.delete_outline,
            iconColor: AppTints.red,
            title: l10n.securityDeleteCredential,
            subtitle: l10n.securityReviewDeleteImpact,
            destructive: true,
            chevron: true,
            onTap: () => Navigator.pop(sheetContext, 'delete'),
          ),
        ],
      );
    },
  );
  if (!context.mounted || action == null) return;
  final page = switch (action) {
    'edit' => CredentialForm(
      ledger: ledger,
      kind: credential.kind,
      existing: credential,
    ),
    'references' => CredentialReferencesPage(
      ledger: ledger,
      credential: credential,
    ),
    'delete' => CredentialDeletePage(ledger: ledger, credential: credential),
    _ => CredentialDetailPage(ledger: ledger, credentialId: credential.id),
  };
  await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => page));
}
