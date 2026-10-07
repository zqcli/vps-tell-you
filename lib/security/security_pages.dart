import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../servers/ledger_controller.dart';
import '../servers/server_detail.dart';
import 'security_controller.dart';
import 'security_models.dart';
import 'host_trust_pages.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';

final securityRouteObserver = RouteObserver<ModalRoute<dynamic>>();

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

class SecurityNotice extends StatelessWidget {
  const SecurityNotice({super.key, required this.controller});
  final SecurityController controller;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (controller.localizedError != null)
        InfoNote(controller.errorFor(context.l10n)!),
      if (controller.needsReload)
        OutlinedButton(
          onPressed: controller.busy ? null : controller.reload,
          child: Text(context.l10n.securityReloadSaved),
        ),
      if (controller.cleanupPending)
        LedgerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoNote(context.l10n.securityCleanupNotice),
              OutlinedButton(
                onPressed: controller.busy ? null : controller.retryCleanup,
                child: Text(context.l10n.securityRetryCleanup),
              ),
            ],
          ),
        ),
    ],
  );
}

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
    final kind = await showModalBottomSheet<CredentialKind>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(context.l10n.securityAddLoginCredential),
              SettingRow(
                icon: Icons.key_outlined,
                title: context.l10n.securityImportKey,
                subtitle: context.l10n.securityImportKeySubtitle,
                onTap: () => Navigator.pop(context, CredentialKind.privateKey),
              ),
              SettingRow(
                icon: Icons.person_outline,
                title: context.l10n.securitySaveUsernamePassword,
                subtitle: context.l10n.securityReusableCredential,
                onTap: () => Navigator.pop(context, CredentialKind.password),
              ),
            ],
          ),
        ),
      ),
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
      final query = search.trim().toLowerCase();
      final visible = security.credentials.where(
        (c) =>
            (filter == null || c.kind == filter) &&
            '${c.name} ${c.defaultUsername}'.toLowerCase().contains(query),
      );
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.securityTitle),
          actions: [
            IconButton(
              tooltip: context.l10n.securityAddCredential,
              onPressed: security.busy || security.needsReload ? null : add,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  InfoNote(context.l10n.securityCredentialStorageNotice),
                  SecurityNotice(controller: security),
                  TextField(
                    key: const ValueKey('credential-search'),
                    decoration: InputDecoration(
                      errorMaxLines: 8,
                      labelText: context.l10n.securitySearchCredentials,
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => search = value),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in <CredentialKind?, String>{
                        null: context.l10n.securityAll,
                        CredentialKind.privateKey:
                            context.l10n.securityPrivateKeyKind,
                        CredentialKind.password:
                            context.l10n.securityPasswordKind,
                      }.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: filter == entry.key,
                          onSelected: (_) => setState(() => filter = entry.key),
                        ),
                    ],
                  ),
                  SectionTitle(
                    context.l10n.securityCredentialCount(
                      security.credentials.length,
                    ),
                  ),
                  if (visible.isEmpty)
                    LedgerCard(
                      child: InfoNote(
                        context.l10n.securityNoMatchingCredentials,
                      ),
                    ),
                  for (final c in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LedgerCard(
                        padding: EdgeInsets.zero,
                        child: SettingRow(
                          icon: c.kind == CredentialKind.password
                              ? Icons.person_outline
                              : Icons.key_outlined,
                          title: c.name,
                          subtitle:
                              '${credentialKind(c, l10n: context.l10n)}${c.defaultUsername.isEmpty ? '' : ' · ${c.defaultUsername}'}\n${context.l10n.securityLinkedServerCount(security.sshConfigurations.where((s) => s.credentialId == c.id).length)}',
                          onTap: () =>
                              credentialMenu(context, widget.ledger, c),
                        ),
                      ),
                    ),
                  SectionTitle(context.l10n.securityDeviceConnectionSecurity),
                  LedgerCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SettingRow(
                          icon: Icons.verified_user_outlined,
                          title: context.l10n.securityTrustedHosts,
                          subtitle: context.l10n.securityTrustedHostsSubtitle,
                          onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  HostTrustPage(ledger: widget.ledger),
                            ),
                          ),
                        ),
                        const Divider(),
                        SettingRow(
                          icon: Icons.lock_outline,
                          title: context.l10n.securityCredentialProtection,
                          subtitle:
                              context.l10n.securityCredentialProtectionSubtitle,
                          onTap: () => showStage(
                            context,
                            LocalizedText(
                              (l10n) => l10n.securityCredentialProtection,
                            ),
                            LocalizedText(
                              (l10n) => l10n.securityCredentialProtectionDetail,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  InfoNote(context.l10n.securityLocalCredentialNotice),
                ],
              ),
      );
    },
  );
}

Future<void> credentialMenu(
  BuildContext context,
  LedgerController ledger,
  CredentialMetadata credential,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              credential.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            InfoNote(credentialKind(credential, l10n: context.l10n)),
            for (final item in <String, (IconData, String, String)>{
              'detail': (
                Icons.visibility_outlined,
                context.l10n.securityViewDetails,
                credential.kind == CredentialKind.privateKey
                    ? context.l10n.securityPrivateKeyDetailsSubtitle
                    : context.l10n.securityPasswordDetailsSubtitle,
              ),
              'edit': (
                Icons.edit_outlined,
                context.l10n.securityEditCredential,
                context.l10n.securityKeepSecret,
              ),
              'references': (
                Icons.link,
                context.l10n.securityLinkedServers,
                context.l10n.securityIndependentUsernames,
              ),
              'delete': (
                Icons.delete_outline,
                context.l10n.securityDeleteCredential,
                context.l10n.securityReviewDeleteImpact,
              ),
            }.entries)
              SettingRow(
                icon: item.value.$1,
                title: item.value.$2,
                subtitle: item.value.$3,
                onTap: () => Navigator.pop(context, item.key),
              ),
          ],
        ),
      ),
    ),
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

/// Only the user-selected file is read. No filename/path enters app metadata.
Future<String?> pickPrivateKey({AppLocalizations? l10n}) async {
  final strings = l10n ?? defaultLocalizations;
  final file = await openFile(confirmButtonText: strings.securityOpenKeyFile);
  if (file == null) return null;
  if (await file.length() > 128 * 1024) throw const FormatException();
  final bytes = await file.readAsBytes();
  if (bytes.length > 128 * 1024) throw const FormatException();
  return utf8.decode(bytes);
}

class CredentialForm extends StatefulWidget {
  const CredentialForm({
    super.key,
    required this.ledger,
    required this.kind,
    this.existing,
    this.pickKey,
  });
  final LedgerController ledger;
  final CredentialKind kind;
  final CredentialMetadata? existing;
  final Future<String?> Function()? pickKey;
  @override
  State<CredentialForm> createState() => _CredentialFormState();
}

class _CredentialFormState extends State<CredentialForm>
    with WidgetsBindingObserver {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.existing?.name);
  late final username = TextEditingController(
    text: widget.existing?.defaultUsername,
  );
  final secret = TextEditingController();
  final passphrase = TextEditingController();
  bool savePassphrase = false;
  bool dirty = false,
      saving = false,
      picking = false,
      pasting = false,
      allowPop = false;
  int generation = 0;
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

  SecurityController get security => widget.ledger.security;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (!picking) generation++;
      secret.clear();
      passphrase.clear();
    }
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    name.dispose();
    username.dispose();
    secret.dispose();
    passphrase.dispose();
    super.dispose();
  }

  Future<void> cancel() async {
    if (saving) return;
    final discard =
        !dirty ||
        await confirmAction(
          context,
          title: LocalizedText((l10n) => l10n.securityDiscardCredentialTitle),
          message: LocalizedText(
            (l10n) => l10n.securityDiscardCredentialMessage,
          ),
          action: LocalizedText((l10n) => l10n.securityDiscardChanges),
          dangerous: true,
        );
    if (!discard || !mounted) return;
    setState(() => allowPop = true);
    Navigator.pop(context);
  }

  Future<void> import() async {
    final request = ++generation;
    setState(() => picking = true);
    try {
      final content =
          await (widget.pickKey?.call() ?? pickPrivateKey(l10n: context.l10n));
      if (!mounted || request != generation || content == null) return;
      secret.text = content;
      setState(() => dirty = true);
      securityMessage(
        context,
        LocalizedText((l10n) => l10n.securityKeyImported),
      );
    } catch (_) {
      if (mounted && request == generation) {
        securityMessage(
          context,
          LocalizedText((l10n) => l10n.securityKeyFileReadFailed),
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> pasteKey() async {
    final request = ++generation;
    setState(() => pasting = true);
    try {
      final content = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (!mounted || request != generation || content == null) return;
      if (content.isEmpty || utf8.encode(content).length > 128 * 1024) {
        throw const FormatException();
      }
      // Assign directly: Flutter's single-line obscured input formatter would
      // otherwise remove PEM newlines from a normal keyboard/menu paste.
      secret.text = content;
      setState(() => dirty = true);
      securityMessage(context, LocalizedText((l10n) => l10n.securityKeyPasted));
    } catch (_) {
      if (mounted && request == generation) {
        securityMessage(
          context,
          LocalizedText((l10n) => l10n.securityKeyPasteFailed),
        );
      }
    } finally {
      if (mounted) setState(() => pasting = false);
    }
  }

  Future<void> save() async {
    if (saving || picking || pasting) return;
    validationAttempted = true;
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    final saved = await security.saveCredential(
      existing: widget.existing,
      name: name.text,
      kind: widget.kind,
      defaultUsername: username.text,
      secret: secret.text.isEmpty && widget.existing != null
          ? null
          : secret.text,
      passphrase: passphrase.text,
      savePassphrase: savePassphrase,
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (saved) {
      secret.clear();
      passphrase.clear();
      setState(() => allowPop = true);
      Navigator.pop(context);
      securityMessage(
        context,
        LocalizedText((l10n) => l10n.securityCredentialSaved),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: security,
    builder: (context, _) => PopScope(
      canPop: allowPop || (!dirty && !saving),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          cancel();
        } else {
          generation++;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existing == null
                ? context.l10n.securityAddCredential
                : context.l10n.securityEditCredential,
          ),
          leading: IconButton(
            tooltip: context.l10n.securityCancelCredentialEdit,
            onPressed: saving ? null : cancel,
            icon: const Icon(Icons.close),
          ),
        ),
        body: Form(
          key: form,
          onChanged: () {
            if (!dirty) setState(() => dirty = true);
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              InfoNote(
                widget.kind == CredentialKind.password
                    ? context.l10n.securityPasswordKind
                    : context.l10n.securityImportKey,
              ),
              SecurityNotice(controller: security),
              TextFormField(
                key: const ValueKey('credential-name'),
                controller: name,
                enabled: !saving,
                maxLength: 80,
                decoration: InputDecoration(
                  errorMaxLines: 8,
                  labelText: context.l10n.securityCredentialName,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? context.l10n.securityCredentialNameRequired
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('credential-username'),
                controller: username,
                enabled: !saving,
                maxLength: 64,
                autocorrect: false,
                decoration: InputDecoration(
                  errorMaxLines: 8,
                  labelText: widget.kind == CredentialKind.password
                      ? context.l10n.securityDefaultLoginUsername
                      : context.l10n.securityOptionalDefaultUsername,
                ),
                validator: (value) =>
                    widget.kind == CredentialKind.password &&
                        (value == null || value.trim().isEmpty)
                    ? context.l10n.securityDefaultUsernameRequired
                    : null,
              ),
              const SizedBox(height: 14),
              if (widget.kind == CredentialKind.privateKey) ...[
                OutlinedButton.icon(
                  onPressed: saving || picking || pasting ? null : import,
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(
                    picking
                        ? context.l10n.securityChoosingFile
                        : context.l10n.securityChoosePrivateKeyFile,
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('credential-paste-key'),
                  onPressed: saving || picking || pasting ? null : pasteKey,
                  icon: const Icon(Icons.content_paste),
                  label: Text(context.l10n.securityPasteCompleteKey),
                ),
                InfoNote(context.l10n.securityPrivateKeyImportNotice),
              ],
              TextFormField(
                key: const ValueKey('credential-secret'),
                controller: secret,
                enabled: !saving && !picking && !pasting,
                readOnly: widget.kind == CredentialKind.privateKey,
                enableInteractiveSelection:
                    widget.kind != CredentialKind.privateKey,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                autofillHints: const [],
                decoration: InputDecoration(
                  errorMaxLines: 8,
                  labelText: widget.kind == CredentialKind.password
                      ? context.l10n.securityLoginPassword
                      : context.l10n.securityPrivateKeyContent,
                  helperMaxLines: 16,
                  helperText: widget.existing == null
                      ? null
                      : context.l10n.securityKeepSecretHidden,
                ),
                validator: (value) =>
                    widget.existing == null && (value == null || value.isEmpty)
                    ? widget.kind == CredentialKind.password
                          ? context.l10n.securityLoginPasswordRequired
                          : context.l10n.securityPrivateKeyRequired
                    : null,
              ),
              if (widget.kind == CredentialKind.privateKey) ...[
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('credential-passphrase'),
                  validator: (value) =>
                      widget.existing != null &&
                          secret.text.isEmpty &&
                          (value?.isNotEmpty ?? false)
                      ? context.l10n.securityReimportForPassphrase
                      : null,
                  controller: passphrase,
                  enabled: !saving,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  autofillHints: const [],
                  decoration: InputDecoration(
                    errorMaxLines: 8,
                    labelText: context.l10n.securityPrivateKeyPassphrase,
                    helperText: context.l10n.securityPrivateKeyPassphraseHelp,
                    helperMaxLines: 16,
                  ),
                ),
                CheckboxListTile(
                  key: const ValueKey('credential-save-passphrase'),
                  contentPadding: EdgeInsets.zero,
                  value: savePassphrase,
                  onChanged: saving
                      ? null
                      : (value) => setState(() {
                          savePassphrase = value == true;
                          dirty = true;
                        }),
                  title: Text(context.l10n.securityStoreKeyPassphrase),
                  subtitle: Text(context.l10n.securityStoreKeyPassphraseHelp),
                ),
              ],
              InfoNote(context.l10n.securityCredentialEditNotice),
              if (widget.existing != null) ...[
                SectionTitle(context.l10n.securityCurrentLinkImpact),
                for (final config in security.sshConfigurations.where(
                  (s) => s.credentialId == widget.existing!.id,
                ))
                  InfoNote(
                    '${widget.ledger.byId(config.serverId)?.name ?? context.l10n.securityServerFallback} · ${config.username} @ ${config.host}:${config.port}',
                  ),
              ],
              FilledButton(
                onPressed:
                    saving ||
                        picking ||
                        pasting ||
                        security.busy ||
                        security.needsReload
                    ? null
                    : save,
                child: Text(
                  saving
                      ? context.l10n.securitySaving
                      : context.l10n.securitySaveCredential,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}

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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: security,
    builder: (context, _) {
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
        child: Scaffold(
          appBar: AppBar(title: Text(context.l10n.securityCredentialDetails)),
          body: c == null
              ? Center(child: Text(context.l10n.securityCredentialDeleted))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      c.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    InfoNote(
                      context.l10n.securityCredentialDefaultUsername(
                        credentialKind(c, l10n: context.l10n),
                        c.defaultUsername.isEmpty
                            ? context.l10n.securityUsernamePerConnection
                            : c.defaultUsername,
                      ),
                    ),
                    SecurityNotice(controller: security),
                    if (c.kind == CredentialKind.privateKey) ...[
                      SectionTitle(context.l10n.securityPublicKeyFingerprint),
                      LedgerCard(
                        child: SelectableText(
                          '${c.keyAlgorithm ?? ''}\n${c.fingerprint ?? ''}',
                        ),
                      ),
                      InfoNote(context.l10n.securityPublicKeyFingerprintNotice),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await Clipboard.setData(
                              ClipboardData(text: c.fingerprint ?? ''),
                            );
                            if (context.mounted) {
                              securityMessage(
                                context,
                                LocalizedText(
                                  (l10n) => l10n.securityFingerprintCopied,
                                ),
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              securityMessage(
                                context,
                                LocalizedText(
                                  (l10n) => l10n.securityCopyFailed,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: Text(context.l10n.securityCopyFingerprint),
                      ),
                    ] else ...[
                      SectionTitle(context.l10n.securityProtectedPassword),
                      LedgerCard(
                        child: Text(
                          revealed
                              ? security.revealedSecret!
                              : '••••••••••••••••',
                          key: const ValueKey('revealed-secret'),
                        ),
                      ),
                      InfoNote(
                        revealed
                            ? context.l10n.securityPasswordRevealNotice
                            : context.l10n.securityPasswordHiddenNotice,
                      ),
                      FilledButton.icon(
                        onPressed: security.busy
                            ? null
                            : () {
                                if (revealed) {
                                  security.hideSensitive();
                                } else {
                                  security.reveal(c, l10n: context.l10n);
                                }
                              },
                        icon: Icon(
                          revealed
                              ? Icons.lock_outline
                              : Icons.visibility_outlined,
                        ),
                        label: Text(
                          revealed
                              ? context.l10n.securityHidePassword
                              : context.l10n.securityVerifyViewPassword,
                        ),
                      ),
                      TextButton(
                        onPressed: () => security.hideSensitive(),
                        child: Text(context.l10n.securityCancelVerifyHide),
                      ),
                    ],
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: security.busy
                          ? null
                          : () async {
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
                      child: Text(context.l10n.securityEditCredential),
                    ),
                  ],
                ),
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.securityLinkedServers)),
    body: ListenableBuilder(
      listenable: ledger.security,
      builder: (context, _) {
        final configs = ledger.security.sshConfigurations
            .where((s) => s.credentialId == credential.id)
            .toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              credential.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            InfoNote(
              context.l10n.securityCredentialReferenceCount(configs.length),
            ),
            for (final config in configs)
              LedgerCard(
                padding: EdgeInsets.zero,
                child: SettingRow(
                  icon: Icons.dns_outlined,
                  title:
                      ledger.byId(config.serverId)?.name ??
                      context.l10n.securityServerFallback,
                  subtitle:
                      '${config.username} @ ${config.host}:${config.port}',
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ServerDetail(controller: ledger, id: config.serverId),
                    ),
                  ),
                ),
              ),
            if (configs.isEmpty)
              InfoNote(context.l10n.securityNoCredentialReferences),
          ],
        );
      },
    ),
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
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger.security,
    builder: (context, _) {
      final security = widget.ledger.security;
      final references = security.sshConfigurations
          .where((s) => s.credentialId == widget.credential.id)
          .toList();
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.securityDeleteCredential)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.credential.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            InfoNote(
              context.l10n.securityCredentialDeleteImpact(references.length),
            ),
            for (final s in references)
              LedgerCard(
                child: Text(
                  '${widget.ledger.byId(s.serverId)?.name ?? context.l10n.securityServerFallback}\n${s.username} @ ${s.host}:${s.port}',
                ),
              ),
            if (references.isNotEmpty) ...[
              SectionTitle(context.l10n.securityManageLinks),
              DropdownButtonFormField<String>(
                initialValue: replacementId ?? '',
                isExpanded: true,
                decoration: InputDecoration(
                  errorMaxLines: 8,
                  labelText: context.l10n.securityReplaceOrUnlink,
                ),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Builder(
                      builder: (context) =>
                          Text(context.l10n.securityUnlinkAll),
                    ),
                  ),
                  for (final c in security.credentials.where(
                    (c) => c.id != widget.credential.id,
                  ))
                    DropdownMenuItem(
                      value: c.id,
                      child: Builder(
                        builder: (context) => Text(
                          context.l10n.securityReplaceWith(c.name),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
                onChanged: security.busy
                    ? null
                    : (value) => setState(() {
                        replacementId = value == '' ? null : value;
                        confirmed = false;
                      }),
              ),
            ],
            InfoNote(
              replacementId == null
                  ? context.l10n.securityUnlinkCredentialNotice
                  : context.l10n.securityReplaceCredentialNotice,
            ),
            InfoNote(context.l10n.securityDeleteLocalCredentialNotice),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: confirmed,
              onChanged: security.busy
                  ? null
                  : (value) => setState(() => confirmed = value ?? false),
              title: Text(context.l10n.securityConfirmCredentialImpact),
            ),
            SecurityNotice(controller: security),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
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
              child: Text(context.l10n.securityConfirmDelete),
            ),
          ],
        ),
      );
    },
  );
}
