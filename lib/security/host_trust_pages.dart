import 'package:flutter/material.dart';

import '../core/net_address.dart';
import '../core/ui/ui.dart';
import '../servers/ledger_controller.dart';
import 'host_trust.dart';
import 'security_models.dart';
import 'security_widgets.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';

const _hostKeyTypes = [
  'ssh-ed25519',
  'ssh-rsa',
  'ecdsa-sha2-nistp256',
  'ecdsa-sha2-nistp384',
  'ecdsa-sha2-nistp521',
];

class HostTrustPage extends StatelessWidget {
  const HostTrustPage({super.key, required this.ledger});
  final LedgerController ledger;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ledger.security,
    builder: (context, _) {
      final l10n = context.l10n;
      final security = ledger.security;
      return AppScaffold(
        title: l10n.securityTrustedHosts,
        actions: [
          AppNavButton.icon(
            Icons.add,
            tooltip: l10n.securityVerifyHostKey,
            onPressed: security.busy || security.needsReload
                ? null
                : () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HostTrustForm(ledger: ledger),
                    ),
                  ),
          ),
        ],
        children: [
          AppBanner(
            icon: Icons.info_outline_rounded,
            text: l10n.securityHostTrustNotice,
          ),
          SecurityNotice(controller: security),
          if (security.hostTrusts.isEmpty)
            AppSection(
              children: [
                AppRow.custom(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      l10n.securityNoTrustedHosts,
                      style: context.footnoteStyle.copyWith(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          for (final pin in security.hostTrusts)
            AppSection(
              children: [
                AppRow(
                  icon: Icons.verified_user_outlined,
                  iconColor: AppTints.green,
                  title: formatHostPort(pin.host, pin.port),
                  subtitle: l10n.securityHostVerifiedAt(
                    pin.algorithm,
                    pin.verifiedAt.toLocal().toString().substring(0, 16),
                  ),
                  trailing: StatusPill(
                    l10n.uiSecurityVerified,
                    tone: AppTone.green,
                    dot: true,
                  ),
                ),
                AppRow.custom(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SelectableText(
                      pin.fingerprint,
                      style: kMonoTextStyle.copyWith(
                        fontSize: 13,
                        height: 1.5,
                        color: context.palette.text,
                      ),
                    ),
                  ),
                ),
                _CompleteHostKeyRow(text: '${pin.algorithm} ${pin.publicKey}'),
                AppRow(
                  icon: Icons.refresh_rounded,
                  iconColor: AppTints.blue,
                  title: l10n.securityReverifyHost,
                  chevron: true,
                  enabled: !security.busy,
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          HostTrustForm(ledger: ledger, existing: pin),
                    ),
                  ),
                ),
                AppRow(
                  title: l10n.securityRemoveHostTrust,
                  destructive: true,
                  enabled: !security.busy,
                  onTap: () async {
                    final confirmed = await showAppConfirm(
                      context,
                      title: LocalizedText(
                        (l10n) => l10n.securityRemoveHostTrustTitle,
                      ),
                      message: LocalizedText(
                        (l10n) => l10n.securityRemoveHostTrustMessage(
                          bracketedHost(pin.host),
                          pin.port,
                          pin.fingerprint,
                        ),
                      ),
                      action: LocalizedText(
                        (l10n) => l10n.securityRemoveHostTrust,
                      ),
                      dangerous: true,
                    );
                    if (confirmed) await security.removeHostTrust(pin);
                  },
                ),
              ],
            ),
          SecurityFootnote(l10n.securityHostChangedNotice),
        ],
      );
    },
  );
}

/// Collapsible "complete host key" row of a trusted host.
class _CompleteHostKeyRow extends StatefulWidget {
  const _CompleteHostKeyRow({required this.text});
  final String text;
  @override
  State<_CompleteHostKeyRow> createState() => _CompleteHostKeyRowState();
}

class _CompleteHostKeyRowState extends State<_CompleteHostKeyRow> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppRow(
          icon: Icons.vpn_key_outlined,
          iconColor: AppTints.indigo,
          title: context.l10n.securityCompleteHostKey,
          trailing: Icon(
            expanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: p.text3,
          ),
          onTap: () => setState(() => expanded = !expanded),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SelectableText(
              widget.text,
              style: kMonoTextStyle.copyWith(
                fontSize: 12.5,
                height: 1.5,
                color: p.text,
              ),
            ),
          ),
      ],
    );
  }
}

class HostTrustForm extends StatefulWidget {
  const HostTrustForm({
    super.key,
    required this.ledger,
    this.existing,
    this.lookup,
  });
  final Future<HostTrustRecord?> Function(String, int)? lookup;
  final LedgerController ledger;
  final HostTrustRecord? existing;
  @override
  State<HostTrustForm> createState() => _HostTrustFormState();
}

class _HostTrustFormState extends State<HostTrustForm> {
  late final host = TextEditingController(text: widget.existing?.host);
  late final port = TextEditingController(
    text: '${widget.existing?.port ?? 22}',
  );
  final publicKey = TextEditingController();
  String algorithm = 'ssh-ed25519';
  bool busy = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    algorithm = widget.existing?.algorithm ?? 'ssh-ed25519';
  }

  @override
  void dispose() {
    host.dispose();
    port.dispose();
    publicKey.dispose();
    super.dispose();
  }

  Future<void> chooseAlgorithm() async {
    final chosen = await showAppPicker<String>(
      context,
      title: context.l10n.securityHostKeyType,
      selected: algorithm,
      options: [
        for (final type in _hostKeyTypes)
          AppPickerOption(value: type, title: type),
      ],
    );
    if (chosen != null && mounted) setState(() => algorithm = chosen);
  }

  Future<void> inspect() async {
    final request = ++generation;
    setState(() => busy = true);
    try {
      final candidate = HostKeyIdentity.validated(
        host: host.text,
        port: int.tryParse(port.text) ?? 0,
        algorithm: algorithm,
        publicKey: publicKey.text,
      );
      final security = widget.ledger.security;
      final previous = await (widget.lookup ?? security.store.hostTrust)(
        candidate.host,
        candidate.port,
      );
      if (!mounted || request != generation) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => HostVerificationPage(
            ledger: widget.ledger,
            identity: candidate,
            previous: previous,
          ),
        ),
      );
    } catch (error) {
      if (mounted && request == generation) {
        securityMessage(
          context,
          error is SecurityFailure
              ? error
              : LocalizedText((l10n) => l10n.securityHostTrustReadFailed),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locked = busy || widget.existing != null;
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) generation++;
      },
      child: AppScaffold(
        title: l10n.securityVerifyHostKey,
        largeTitle: false,
        bottomBar: AppButton(
          label: busy ? l10n.securityChecking : l10n.securityCheckFingerprint,
          expand: true,
          onPressed: busy ? null : inspect,
        ),
        children: [
          AppBanner(
            icon: Icons.info_outline_rounded,
            text: l10n.securityHostTrustInputNotice,
          ),
          AppSection(
            children: [
              AppFormRow(
                label: l10n.securityHostAddress,
                child: AppTextField(
                  key: const ValueKey('trust-host'),
                  controller: host,
                  enabled: !locked,
                  autocorrect: false,
                  label: l10n.securityHostAddress,
                ),
              ),
              AppFormRow(
                label: l10n.securityPort,
                child: AppTextField(
                  key: const ValueKey('trust-port'),
                  controller: port,
                  enabled: !locked,
                  keyboardType: TextInputType.number,
                  label: l10n.securityPort,
                ),
              ),
              AppFormRow.pick(
                label: l10n.securityHostKeyType,
                value: algorithm,
                onTap: busy ? null : chooseAlgorithm,
              ),
            ],
          ),
          AppSection(
            footer: l10n.securityHostKeyHelp,
            children: [
              AppFormRow(
                label: l10n.securityCompleteHostKey,
                stacked: true,
                child: AppTextField(
                  key: const ValueKey('trust-public-key'),
                  controller: publicKey,
                  enabled: !busy,
                  minLines: 4,
                  maxLines: 8,
                  autocorrect: false,
                  enableSuggestions: false,
                  textAlign: TextAlign.start,
                  style: kMonoTextStyle.copyWith(fontSize: 13),
                  label: l10n.securityCompleteHostKey,
                ),
              ),
            ],
          ),
          AppInfoLink(
            label: l10n.r2CopyInfoRsaKey,
            message: l10n.securityRsaHostKeyNotice,
          ),
        ],
      ),
    );
  }
}

class HostVerificationPage extends StatefulWidget {
  const HostVerificationPage({
    super.key,
    required this.ledger,
    required this.identity,
    this.previous,
  });
  final LedgerController ledger;
  final HostKeyIdentity identity;
  final HostTrustRecord? previous;
  @override
  State<HostVerificationPage> createState() => _HostVerificationPageState();
}

class _HostVerificationPageState extends State<HostVerificationPage> {
  bool verified = false, reverifying = false, saving = false;
  bool get changed =>
      widget.previous != null &&
      (widget.previous!.algorithm != widget.identity.algorithm ||
          widget.previous!.publicKey != widget.identity.publicKey);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger.security,
    builder: (context, _) {
      final l10n = context.l10n;
      final security = widget.ledger.security;
      return PopScope(
        canPop: !saving,
        child: AppScaffold(
          title: changed
              ? l10n.securityHostKeyMismatch
              : widget.previous == null
              ? l10n.securityFirstHostVerification
              : l10n.securityReverifyHost,
          largeTitle: false,
          children: [
            AppBanner(
              tone: changed ? AppTone.red : AppTone.amber,
              icon: Icons.warning_amber_rounded,
              text: changed
                  ? l10n.securityHostMismatchBadge
                  : l10n.securityHostVerifyBeforeSave,
            ),
            AppSection(
              children: [
                AppRow(
                  icon: Icons.dns_outlined,
                  iconColor: changed ? AppTints.red : AppTints.orange,
                  title: formatHostPort(
                    widget.identity.host,
                    widget.identity.port,
                  ),
                  trailing: StatusPill(
                    changed
                        ? l10n.uiSecurityKeyChanged
                        : l10n.uiSecurityUnverified,
                    tone: changed ? AppTone.red : AppTone.amber,
                    dot: true,
                  ),
                ),
              ],
            ),
            if (widget.previous != null)
              SecurityMonoCard(
                header: l10n.securitySavedHostFingerprint,
                text:
                    '${widget.previous!.algorithm}\n${widget.previous!.fingerprint}',
              ),
            SecurityMonoCard(
              header: l10n.securityCandidateHostFingerprint,
              text:
                  '${widget.identity.algorithm}\n${widget.identity.fingerprint}',
            ),
            SecurityMonoCard(
              header: l10n.securityCompleteHostKey,
              text: '${widget.identity.algorithm} ${widget.identity.publicKey}',
            ),
            SecurityFootnote(l10n.securityHostVerificationWarning),
            if (changed && !reverifying)
              SecurityAction(
                child: AppButton(
                  label: l10n.securityBeginHostReverification,
                  kind: AppButtonKind.tonal,
                  expand: true,
                  onPressed: () => setState(() {
                    reverifying = true;
                    verified = false;
                  }),
                ),
              ),
            if (!changed || reverifying) ...[
              AppSection(
                children: [
                  AppSwitchRow(
                    title: l10n.securityConfirmHostVerified,
                    value: verified,
                    onChanged: saving
                        ? null
                        : (value) => setState(() => verified = value),
                  ),
                ],
              ),
              SecurityAction(
                child: AppButton(
                  label: changed
                      ? l10n.securityReverifyReplaceTrust
                      : l10n.securitySaveVerifiedHostTrust,
                  expand: true,
                  destructive: changed,
                  onPressed:
                      !verified ||
                          saving ||
                          security.busy ||
                          security.needsReload
                      ? null
                      : () async {
                          setState(() => saving = true);
                          final saved = await security.verifyHost(
                            widget.identity,
                            expected: widget.previous,
                          );
                          if (!mounted) return;
                          setState(() => saving = false);
                          if (saved && context.mounted) {
                            Navigator.pop(context);
                            securityMessage(
                              context,
                              LocalizedText(
                                (l10n) => l10n.securityHostTrustSaved,
                              ),
                            );
                          }
                        },
                ),
              ),
            ],
            SecurityAction(
              child: AppButton(
                label: l10n.securityRejectBack,
                kind: AppButtonKind.plain,
                expand: true,
                onPressed: saving ? null : () => Navigator.pop(context),
              ),
            ),
            if (saving) SecurityFootnote(l10n.securitySavingHostTrust),
            SecurityNotice(controller: security),
            SecurityFootnote(l10n.securityLocalHostTrustOnly),
          ],
        ),
      );
    },
  );
}
