import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../servers/ledger_controller.dart';
import 'host_trust.dart';
import 'security_models.dart';
import 'security_pages.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';

class HostTrustPage extends StatelessWidget {
  const HostTrustPage({super.key, required this.ledger});
  final LedgerController ledger;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ledger.security,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.securityTrustedHosts),
        actions: [
          IconButton(
            tooltip: context.l10n.securityVerifyHostKey,
            icon: const Icon(Icons.add),
            onPressed: ledger.security.busy || ledger.security.needsReload
                ? null
                : () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HostTrustForm(ledger: ledger),
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          InfoNote(context.l10n.securityHostTrustNotice),
          SecurityNotice(controller: ledger.security),
          if (ledger.security.hostTrusts.isEmpty)
            LedgerCard(child: InfoNote(context.l10n.securityNoTrustedHosts)),
          for (final pin in ledger.security.hostTrusts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LedgerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${pin.host}:${pin.port}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    InfoNote(
                      context.l10n.securityHostVerifiedAt(
                        pin.algorithm,
                        pin.verifiedAt.toLocal().toString().substring(0, 16),
                      ),
                    ),
                    SelectableText(pin.fingerprint),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(context.l10n.securityCompleteHostKey),
                      children: [
                        SelectableText('${pin.algorithm} ${pin.publicKey}'),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: ledger.security.busy
                              ? null
                              : () => Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => HostTrustForm(
                                      ledger: ledger,
                                      existing: pin,
                                    ),
                                  ),
                                ),
                          child: Text(context.l10n.securityReverifyHost),
                        ),
                        TextButton(
                          onPressed: ledger.security.busy
                              ? null
                              : () async {
                                  final confirmed = await confirmAction(
                                    context,
                                    title: LocalizedText(
                                      (l10n) =>
                                          l10n.securityRemoveHostTrustTitle,
                                    ),
                                    message: LocalizedText(
                                      (l10n) =>
                                          l10n.securityRemoveHostTrustMessage(
                                            pin.host,
                                            pin.port,
                                            pin.fingerprint,
                                          ),
                                    ),
                                    action: LocalizedText(
                                      (l10n) => l10n.securityRemoveHostTrust,
                                    ),
                                    dangerous: true,
                                  );
                                  if (confirmed) {
                                    await ledger.security.removeHostTrust(pin);
                                  }
                                },
                          child: Text(
                            context.l10n.securityRemoveHostTrust,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          InfoNote(context.l10n.securityHostChangedNotice),
        ],
      ),
    ),
  );
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
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, result) {
      if (didPop) generation++;
    },
    child: Scaffold(
      appBar: AppBar(title: Text(context.l10n.securityVerifyHostKey)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          InfoNote(context.l10n.securityHostTrustInputNotice),
          TextField(
            key: const ValueKey('trust-host'),
            controller: host,
            enabled: !busy && widget.existing == null,
            autocorrect: false,
            decoration: InputDecoration(
              errorMaxLines: 8,
              labelText: context.l10n.securityHostAddress,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('trust-port'),
            controller: port,
            enabled: !busy && widget.existing == null,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              errorMaxLines: 8,
              labelText: context.l10n.securityPort,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: algorithm,
            isExpanded: true,
            decoration: InputDecoration(
              errorMaxLines: 8,
              labelText: context.l10n.securityHostKeyType,
            ),
            items: [
              for (final type in [
                'ssh-ed25519',
                'ssh-rsa',
                'ecdsa-sha2-nistp256',
                'ecdsa-sha2-nistp384',
                'ecdsa-sha2-nistp521',
              ])
                DropdownMenuItem(value: type, child: Text(type)),
            ],
            onChanged: busy
                ? null
                : (value) => setState(() => algorithm = value!),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('trust-public-key'),
            controller: publicKey,
            enabled: !busy,
            maxLines: 5,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              errorMaxLines: 8,
              labelText: context.l10n.securityCompleteHostKey,
              helperText: context.l10n.securityHostKeyHelp,
              helperMaxLines: 16,
            ),
          ),
          InfoNote(context.l10n.securityRsaHostKeyNotice),
          FilledButton(
            onPressed: busy ? null : inspect,
            child: Text(
              busy
                  ? context.l10n.securityChecking
                  : context.l10n.securityCheckFingerprint,
            ),
          ),
        ],
      ),
    ),
  );
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
    builder: (context, _) => PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: saving ? null : () => Navigator.maybePop(context),
          ),
          title: Text(
            changed
                ? context.l10n.securityHostKeyMismatch
                : widget.previous == null
                ? context.l10n.securityFirstHostVerification
                : context.l10n.securityReverifyHost,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            LedgerBadge(
              changed
                  ? context.l10n.securityHostMismatchBadge
                  : context.l10n.securityHostVerifyBeforeSave,
              danger: changed,
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.identity.host}:${widget.identity.port}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (widget.previous != null) ...[
              SectionTitle(context.l10n.securitySavedHostFingerprint),
              LedgerCard(
                child: SelectableText(
                  '${widget.previous!.algorithm}\n${widget.previous!.fingerprint}',
                ),
              ),
            ],
            SectionTitle(context.l10n.securityCandidateHostFingerprint),
            LedgerCard(
              child: SelectableText(
                '${widget.identity.algorithm}\n${widget.identity.fingerprint}',
              ),
            ),
            SectionTitle(context.l10n.securityCompleteHostKey),
            LedgerCard(
              child: SelectableText(
                '${widget.identity.algorithm} ${widget.identity.publicKey}',
              ),
            ),
            InfoNote(context.l10n.securityHostVerificationWarning),
            if (changed && !reverifying)
              OutlinedButton(
                onPressed: () => setState(() {
                  reverifying = true;
                  verified = false;
                }),
                child: Text(context.l10n.securityBeginHostReverification),
              ),
            if (!changed || reverifying) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: verified,
                onChanged: saving
                    ? null
                    : (value) => setState(() => verified = value ?? false),
                title: Text(context.l10n.securityConfirmHostVerified),
              ),
              FilledButton(
                onPressed:
                    !verified ||
                        saving ||
                        widget.ledger.security.busy ||
                        widget.ledger.security.needsReload
                    ? null
                    : () async {
                        setState(() => saving = true);
                        final saved = await widget.ledger.security.verifyHost(
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
                child: Text(
                  changed
                      ? context.l10n.securityReverifyReplaceTrust
                      : context.l10n.securitySaveVerifiedHostTrust,
                ),
              ),
            ],
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: Text(context.l10n.securityRejectBack),
            ),
            if (saving) InfoNote(context.l10n.securitySavingHostTrust),
            SecurityNotice(controller: widget.ledger.security),
            InfoNote(context.l10n.securityLocalHostTrustOnly),
          ],
        ),
      ),
    ),
  );
}
