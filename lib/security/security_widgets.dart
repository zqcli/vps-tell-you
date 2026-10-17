import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import '../core/net_address.dart';
import '../core/ui/ui.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../servers/ledger_controller.dart';
import 'security_controller.dart';
import 'security_models.dart';

String credentialKind(CredentialMetadata credential, {AppLocalizations? l10n}) {
  final strings = l10n ?? defaultLocalizations;
  return credential.kind == CredentialKind.password
      ? strings.securityPasswordKind
      : strings.securityPrivateKeyKind;
}

void securityMessage(BuildContext context, Object message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Builder(
          builder: (context) => Text(localizedText(message, context.l10n)),
        ),
      ),
    );

IconData credentialIcon(CredentialKind kind) => kind == CredentialKind.password
    ? Icons.password_rounded
    : Icons.key_outlined;

Color credentialTint(CredentialKind kind) =>
    kind == CredentialKind.password ? AppTints.orange : AppTints.green;

/// Footnote paragraph under a group (aligned with the group's inner text).
class SecurityFootnote extends StatelessWidget {
  const SecurityFootnote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
    child: Text(text, style: context.footnoteStyle),
  );
}

/// Section header text followed by a card with a monospace, selectable block
/// (host key fingerprints and public keys).
class SecurityMonoCard extends StatelessWidget {
  const SecurityMonoCard({super.key, required this.header, required this.text});
  final String header;
  final String text;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 22, 32, 7),
          child: Text(header, style: TextStyle(fontSize: 13, color: p.text2)),
        ),
        AppCard(
          child: SelectableText(
            text,
            style: kMonoTextStyle.copyWith(
              fontSize: 13,
              height: 1.5,
              color: p.text,
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-width button block with the page margin.
class SecurityAction extends StatelessWidget {
  const SecurityAction({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: child);
}

class SecurityNotice extends StatelessWidget {
  const SecurityNotice({super.key, required this.controller});
  final SecurityController controller;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (controller.localizedError != null)
        AppBanner(
          tone: AppTone.red,
          icon: Icons.error_outline_rounded,
          text: controller.errorFor(context.l10n)!,
        ),
      if (controller.needsReload)
        AppSection(
          children: [
            AppRow(
              center: true,
              title: context.l10n.securityReloadSaved,
              enabled: !controller.busy,
              onTap: () => controller.reload(),
            ),
          ],
        ),
      if (controller.cleanupPending) ...[
        AppBanner(
          tone: AppTone.amber,
          icon: Icons.warning_amber_rounded,
          text: context.l10n.securityCleanupNotice,
        ),
        AppSection(
          topSpacing: 10,
          children: [
            AppRow(
              center: true,
              title: context.l10n.securityRetryCleanup,
              enabled: !controller.busy,
              onTap: () => controller.retryCleanup(),
            ),
          ],
        ),
      ],
    ],
  );
}

/// Page body while the metadata is still loading.
const securityLoadingChildren = <Widget>[
  Padding(
    padding: EdgeInsets.only(top: 80),
    child: Center(child: CupertinoActivityIndicator()),
  ),
];

/// Centred placeholder line inside an otherwise empty list section.
Widget securityEmptyRow(BuildContext context, String text) => AppRow.custom(
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: context.footnoteStyle.copyWith(fontSize: 14),
    ),
  ),
);

/// A server that uses a credential or proxy: its name and `user @ host:port`.
Widget sshReferenceRow(
  BuildContext context,
  LedgerController ledger,
  SshConfiguration config, {
  VoidCallback? onTap,
}) => AppRow(
  icon: Icons.dns_outlined,
  iconColor: AppTints.teal,
  title:
      ledger.byId(config.serverId)?.name ?? context.l10n.securityServerFallback,
  subtitle: '${config.username} @ ${formatHostPort(config.host, config.port)}',
  chevron: onTap != null,
  onTap: onTap,
);

/// How many SSH configurations reference each id chosen by [idOf]; one pass
/// instead of a scan per list row.
Map<String, int> referenceCounts(
  SecurityController security,
  String? Function(SshConfiguration) idOf,
) {
  final counts = <String, int>{};
  for (final config in security.sshConfigurations) {
    final id = idOf(config);
    if (id != null) counts[id] = (counts[id] ?? 0) + 1;
  }
  return counts;
}

/// Whether the app left the foreground far enough that typed secrets must go.
bool leftForeground(AppLifecycleState state) =>
    state == AppLifecycleState.paused ||
    state == AppLifecycleState.hidden ||
    state == AppLifecycleState.detached;

/// The "Protected password" group: the secret while revealed, dots otherwise.
class SecretRevealSection extends StatelessWidget {
  const SecretRevealSection({
    super.key,
    required this.secret,
    required this.textKey,
  });

  /// The revealed text, or null while hidden.
  final String? secret;
  final Key textKey;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final revealed = secret != null;
    return AppSection(
      header: l10n.securityProtectedPassword,
      footer: revealed
          ? l10n.securityPasswordRevealNotice
          : l10n.securityPasswordHiddenNotice,
      children: [
        AppRow.custom(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              secret ?? '••••••••••••••••',
              key: textKey,
              style: kMonoTextStyle.copyWith(
                fontSize: 16,
                color: context.palette.text,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
