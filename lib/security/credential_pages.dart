import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ui/ui.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../servers/ledger_controller.dart';
import '../servers/server_detail.dart';
import 'credential_form.dart';
import 'security_controller.dart';
import 'security_models.dart';
import 'security_widgets.dart';

final securityRouteObserver = RouteObserver<ModalRoute<dynamic>>();

class CredentialDetailPage extends StatefulWidget {
  const CredentialDetailPage({
    super.key,
    required this.ledger,
    required this.credentialId,
  });
  final LedgerController ledger;
  final String credentialId;
  @override
  State<CredentialDetailPage> createState() => _CredentialDetailPageState();
}

class _CredentialDetailPageState extends State<CredentialDetailPage>
    with WidgetsBindingObserver, RouteAware {
  bool foreground = true;
  ModalRoute<dynamic>? subscribedRoute;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != subscribedRoute) {
      securityRouteObserver.unsubscribe(this);
      subscribedRoute = route;
      if (route != null) securityRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() => security.hideSensitive();
  @override
  void didPop() => security.hideSensitive();
  SecurityController get security => widget.ledger.security;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => foreground = state == AppLifecycleState.resumed);
    if (state != AppLifecycleState.resumed) {
      security.hideSensitive(
        cancelAuthentication: state != AppLifecycleState.inactive,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    securityRouteObserver.unsubscribe(this);
    security.hideSensitive();
    super.dispose();
  }

  Future<void> copyFingerprint(BuildContext context, String fingerprint) async {
    var copied = true;
    try {
      await Clipboard.setData(ClipboardData(text: fingerprint));
    } catch (_) {
      copied = false;
    }
    if (!context.mounted) return;
    securityMessage(
      context,
      LocalizedText(
        (l10n) =>
            copied ? l10n.securityFingerprintCopied : l10n.securityCopyFailed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: security,
    builder: (context, _) {
      final l10n = context.l10n;
      final c = security.credentials
          .where((c) => c.id == widget.credentialId)
          .firstOrNull;
      final revealed =
          foreground &&
          security.revealedCredentialId == c?.id &&
          security.revealedSecret != null;
      return PopScope(
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) security.hideSensitive();
        },
        child: AppScaffold(
          title: l10n.securityCredentialDetails,
          largeTitle: false,
          children: c == null
              ? [
                  AppEmptyState(
                    icon: Icons.key_off_outlined,
                    title: l10n.securityCredentialDeleted,
                  ),
                ]
              : [
                  AppSection(
                    children: [
                      AppRow(
                        icon: credentialIcon(c.kind),
                        iconColor: credentialTint(c.kind),
                        title: c.name,
                        subtitle: l10n.securityCredentialDefaultUsername(
                          credentialKind(c, l10n: l10n),
                          c.defaultUsername.isEmpty
                              ? l10n.securityUsernamePerConnection
                              : c.defaultUsername,
                        ),
                      ),
                    ],
                  ),
                  SecurityNotice(controller: security),
                  if (c.kind == CredentialKind.privateKey) ...[
                    SecurityMonoCard(
                      header: l10n.securityPublicKeyFingerprint,
                      text: '${c.keyAlgorithm ?? ''}\n${c.fingerprint ?? ''}',
                    ),
                    SecurityFootnote(l10n.securityPublicKeyFingerprintNotice),
                    AppSection(
                      children: [
                        AppRow(
                          icon: Icons.copy,
                          iconColor: AppTints.blue,
                          title: l10n.securityCopyFingerprint,
                          onTap: () =>
                              copyFingerprint(context, c.fingerprint ?? ''),
                        ),
                      ],
                    ),
                  ] else ...[
                    SecretRevealSection(
                      secret: revealed ? security.revealedSecret : null,
                      textKey: const ValueKey('revealed-secret'),
                    ),
                    SecurityAction(
                      child: AppButton(
                        label: revealed
                            ? l10n.securityHidePassword
                            : l10n.securityVerifyViewPassword,
                        icon: revealed
                            ? Icons.lock_outline
                            : Icons.visibility_outlined,
                        expand: true,
                        onPressed: security.busy
                            ? null
                            : () {
                                if (revealed) {
                                  security.hideSensitive();
                                } else {
                                  security.reveal(c, l10n: l10n);
                                }
                              },
                      ),
                    ),
                    SecurityAction(
                      child: AppButton(
                        label: l10n.securityCancelVerifyHide,
                        kind: AppButtonKind.plain,
                        expand: true,
                        onPressed: () => security.hideSensitive(),
                      ),
                    ),
                  ],
                  AppSection(
                    children: [
                      AppRow(
                        icon: Icons.edit_outlined,
                        iconColor: AppTints.indigo,
                        title: l10n.securityEditCredential,
                        chevron: true,
                        enabled: !security.busy,
                        onTap: () async {
                          security.hideSensitive();
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CredentialForm(
                                ledger: widget.ledger,
                                kind: c.kind,
                                existing: c,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
        ),
      );
    },
  );
}

class CredentialReferencesPage extends StatelessWidget {
  const CredentialReferencesPage({
    super.key,
    required this.ledger,
    required this.credential,
  });
  final LedgerController ledger;
  final CredentialMetadata credential;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ledger.security,
    builder: (context, _) {
      final l10n = context.l10n;
      final configs = ledger.security.referencesTo(credential.id);
      return AppScaffold(
        title: l10n.securityLinkedServers,
        largeTitle: false,
        children: [
          AppSection(
            header: credential.name,
            footer: l10n.securityCredentialReferenceCount(configs.length),
            children: [
              if (configs.isEmpty)
                securityEmptyRow(context, l10n.securityNoCredentialReferences),
              for (final config in configs)
                sshReferenceRow(
                  context,
                  ledger,
                  config,
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ServerDetail(controller: ledger, id: config.serverId),
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

class CredentialDeletePage extends StatefulWidget {
  const CredentialDeletePage({
    super.key,
    required this.ledger,
    required this.credential,
  });
  final LedgerController ledger;
  final CredentialMetadata credential;
  @override
  State<CredentialDeletePage> createState() => _CredentialDeletePageState();
}

class _CredentialDeletePageState extends State<CredentialDeletePage> {
  String? replacementId;
  bool confirmed = false;

  Future<void> chooseReplacement(SecurityController security) async {
    final l10n = context.l10n;
    final chosen = await showAppPicker<String>(
      context,
      title: l10n.securityReplaceOrUnlink,
      selected: replacementId ?? '',
      options: [
        AppPickerOption(
          value: '',
          title: l10n.securityUnlinkAll,
          icon: Icons.link_off,
          iconColor: AppTints.orange,
        ),
        for (final c in security.credentials.where(
          (c) => c.id != widget.credential.id,
        ))
          AppPickerOption(
            value: c.id,
            title: l10n.securityReplaceWith(c.name),
            icon: credentialIcon(c.kind),
            iconColor: credentialTint(c.kind),
          ),
      ],
    );
    if (chosen == null || !mounted) return;
    setState(() {
      replacementId = chosen.isEmpty ? null : chosen;
      confirmed = false;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger.security,
    builder: (context, _) {
      final l10n = context.l10n;
      final security = widget.ledger.security;
      final references = security.referencesTo(widget.credential.id);
      final replacement = security.credentials
          .where((c) => c.id == replacementId)
          .firstOrNull;
      return AppScaffold(
        title: l10n.securityDeleteCredential,
        largeTitle: false,
        children: [
          AppSection(
            footer: l10n.securityCredentialDeleteImpact(references.length),
            children: [
              AppRow(
                icon: credentialIcon(widget.credential.kind),
                iconColor: credentialTint(widget.credential.kind),
                title: widget.credential.name,
                subtitle: credentialKind(widget.credential, l10n: l10n),
              ),
            ],
          ),
          if (references.isNotEmpty)
            AppSection(
              children: [
                for (final s in references)
                  sshReferenceRow(context, widget.ledger, s),
              ],
            ),
          if (references.isNotEmpty)
            AppSection(
              header: l10n.securityManageLinks,
              children: [
                AppFormRow.pick(
                  label: l10n.securityReplaceOrUnlink,
                  value: replacement == null
                      ? l10n.securityUnlinkAll
                      : l10n.securityReplaceWith(replacement.name),
                  onTap: security.busy
                      ? null
                      : () => chooseReplacement(security),
                ),
              ],
            ),
          SecurityFootnote(
            replacementId == null
                ? l10n.securityUnlinkCredentialNotice
                : l10n.securityReplaceCredentialNotice,
          ),
          SecurityFootnote(l10n.securityDeleteLocalCredentialNotice),
          AppSection(
            children: [
              AppSwitchRow(
                title: l10n.securityConfirmCredentialImpact,
                value: confirmed,
                onChanged: security.busy
                    ? null
                    : (value) => setState(() => confirmed = value),
              ),
            ],
          ),
          SecurityNotice(controller: security),
          SecurityAction(
            child: AppButton(
              label: l10n.securityConfirmDelete,
              destructive: true,
              expand: true,
              onPressed: !confirmed || security.busy || security.needsReload
                  ? null
                  : () async {
                      final saved = await security.deleteCredential(
                        widget.credential,
                        replacementId: replacementId,
                      );
                      if (saved && context.mounted) {
                        Navigator.pop(context);
                        securityMessage(
                          context,
                          LocalizedText(
                            (l10n) => l10n.securityLocalCredentialDeleted,
                          ),
                        );
                      }
                    },
            ),
          ),
        ],
      );
    },
  );
}
