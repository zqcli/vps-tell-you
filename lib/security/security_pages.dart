import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ui/ui.dart';
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
            ? const [
                Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CupertinoActivityIndicator()),
                ),
              ]
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
                      AppRow.custom(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            l10n.securityNoMatchingCredentials,
                            style: context.footnoteStyle.copyWith(fontSize: 14),
                          ),
                        ),
                      ),
                    for (final c in visible)
                      AppRow(
                        icon: credentialIcon(c.kind),
                        iconColor: credentialTint(c.kind),
                        title: c.name,
                        subtitle:
                            '${credentialKind(c, l10n: l10n)}${c.defaultUsername.isEmpty ? '' : ' · ${c.defaultUsername}'}',
                        trailing: StatusPill(
                          l10n.securityLinkedServerCount(
                            security.sshConfigurations
                                .where((s) => s.credentialId == c.id)
                                .length,
                          ),
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

  /// Errors are derived while building, so they follow the app language and
  /// clear as soon as the input becomes valid.
  bool validationAttempted = false;

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

  void markDirty() {
    if (!dirty) setState(() => dirty = true);
  }

  String? nameError(AppLocalizations l10n) =>
      validationAttempted && name.text.trim().isEmpty
      ? l10n.securityCredentialNameRequired
      : null;

  String? usernameError(AppLocalizations l10n) =>
      validationAttempted &&
          widget.kind == CredentialKind.password &&
          username.text.trim().isEmpty
      ? l10n.securityDefaultUsernameRequired
      : null;

  String? secretError(AppLocalizations l10n) =>
      validationAttempted && widget.existing == null && secret.text.isEmpty
      ? widget.kind == CredentialKind.password
            ? l10n.securityLoginPasswordRequired
            : l10n.securityPrivateKeyRequired
      : null;

  String? passphraseError(AppLocalizations l10n) =>
      validationAttempted &&
          widget.existing != null &&
          secret.text.isEmpty &&
          passphrase.text.isNotEmpty
      ? l10n.securityReimportForPassphrase
      : null;

  Future<void> cancel() async {
    if (saving) return;
    final discard =
        !dirty ||
        await showAppConfirm(
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
    final l10n = context.l10n;
    setState(() => validationAttempted = true);
    if (nameError(l10n) != null ||
        usernameError(l10n) != null ||
        secretError(l10n) != null ||
        passphraseError(l10n) != null) {
      return;
    }
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
    builder: (context, _) {
      final l10n = context.l10n;
      final isPassword = widget.kind == CredentialKind.password;
      final isKey = widget.kind == CredentialKind.privateKey;
      final busy = saving || picking || pasting;
      final impacts = widget.existing == null
          ? const <SshConfiguration>[]
          : security.sshConfigurations
                .where((s) => s.credentialId == widget.existing!.id)
                .toList();
      return PopScope(
        canPop: allowPop || (!dirty && !saving),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            cancel();
          } else {
            generation++;
          }
        },
        child: AppScaffold(
          title: widget.existing == null
              ? l10n.securityAddCredential
              : l10n.securityEditCredential,
          largeTitle: false,
          leading: AppNavButton.icon(
            Icons.close,
            tooltip: l10n.securityCancelCredentialEdit,
            onPressed: saving ? null : cancel,
          ),
          bottomBar: AppButton(
            label: saving ? l10n.securitySaving : l10n.securitySaveCredential,
            expand: true,
            onPressed: busy || security.busy || security.needsReload
                ? null
                : save,
          ),
          children: [
            SecurityNotice(controller: security),
            AppSection(
              header: isPassword
                  ? l10n.securityPasswordKind
                  : l10n.securityImportKey,
              children: [
                AppFormRow(
                  label: l10n.securityCredentialName,
                  required: true,
                  errorText: nameError(l10n),
                  child: AppTextField(
                    key: const ValueKey('credential-name'),
                    controller: name,
                    enabled: !saving,
                    maxLength: 80,
                    label: l10n.securityCredentialName,
                    onChanged: (_) => setState(() => dirty = true),
                  ),
                ),
                AppFormRow(
                  label: isPassword
                      ? l10n.securityDefaultLoginUsername
                      : l10n.securityOptionalDefaultUsername,
                  required: isPassword,
                  errorText: usernameError(l10n),
                  child: AppTextField(
                    key: const ValueKey('credential-username'),
                    controller: username,
                    enabled: !saving,
                    maxLength: 64,
                    autocorrect: false,
                    label: isPassword
                        ? l10n.securityDefaultLoginUsername
                        : l10n.securityOptionalDefaultUsername,
                    onChanged: (_) => setState(() => dirty = true),
                  ),
                ),
              ],
            ),
            if (isKey)
              AppSection(
                footer: l10n.securityPrivateKeyImportNotice,
                children: [
                  AppRow(
                    icon: Icons.file_open_outlined,
                    iconColor: AppTints.green,
                    title: picking
                        ? l10n.securityChoosingFile
                        : l10n.securityChoosePrivateKeyFile,
                    enabled: !busy,
                    onTap: import,
                  ),
                  AppRow(
                    key: const ValueKey('credential-paste-key'),
                    icon: Icons.content_paste,
                    iconColor: AppTints.indigo,
                    title: l10n.securityPasteCompleteKey,
                    enabled: !busy,
                    onTap: pasteKey,
                  ),
                ],
              ),
            AppSection(
              footer: widget.existing == null
                  ? null
                  : l10n.securityKeepSecretHidden,
              children: [
                AppFormRow(
                  label: isPassword
                      ? l10n.securityLoginPassword
                      : l10n.securityPrivateKeyContent,
                  required: widget.existing == null,
                  errorText: secretError(l10n),
                  child: AppTextField(
                    key: const ValueKey('credential-secret'),
                    controller: secret,
                    enabled: !busy,
                    readOnly: isKey,
                    enableInteractiveSelection: !isKey,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    autofillHints: const [],
                    label: isPassword
                        ? l10n.securityLoginPassword
                        : l10n.securityPrivateKeyContent,
                    onChanged: (_) => setState(() => dirty = true),
                  ),
                ),
              ],
            ),
            if (isKey)
              AppSection(
                footer: l10n.securityPrivateKeyPassphraseHelp,
                children: [
                  AppFormRow(
                    label: l10n.securityPrivateKeyPassphrase,
                    errorText: passphraseError(l10n),
                    child: AppTextField(
                      key: const ValueKey('credential-passphrase'),
                      controller: passphrase,
                      enabled: !saving,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      autofillHints: const [],
                      label: l10n.securityPrivateKeyPassphrase,
                      onChanged: (_) => setState(() => dirty = true),
                    ),
                  ),
                  AppSwitchRow(
                    key: const ValueKey('credential-save-passphrase'),
                    title: l10n.securityStoreKeyPassphrase,
                    subtitle: l10n.securityStoreKeyPassphraseHelp,
                    value: savePassphrase,
                    onChanged: saving
                        ? null
                        : (value) => setState(() {
                            savePassphrase = value;
                            dirty = true;
                          }),
                  ),
                ],
              ),
            SecurityFootnote(l10n.securityCredentialEditNotice),
            if (widget.existing != null)
              AppSection(
                header: l10n.securityCurrentLinkImpact,
                children: [
                  if (impacts.isEmpty)
                    AppRow.custom(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          l10n.securityNoCredentialReferences,
                          style: context.footnoteStyle.copyWith(fontSize: 14),
                        ),
                      ),
                    ),
                  for (final config in impacts)
                    AppRow(
                      icon: Icons.dns_outlined,
                      iconColor: AppTints.teal,
                      title:
                          widget.ledger.byId(config.serverId)?.name ??
                          l10n.securityServerFallback,
                      subtitle:
                          '${config.username} @ ${config.host}:${config.port}',
                    ),
                ],
              ),
          ],
        ),
      );
    },
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

  Future<void> copyFingerprint(BuildContext context, String fingerprint) async {
    try {
      await Clipboard.setData(ClipboardData(text: fingerprint));
      if (context.mounted) {
        securityMessage(
          context,
          LocalizedText((l10n) => l10n.securityFingerprintCopied),
        );
      }
    } catch (_) {
      if (context.mounted) {
        securityMessage(
          context,
          LocalizedText((l10n) => l10n.securityCopyFailed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: security,
    builder: (context, _) {
      final l10n = context.l10n;
      final p = context.palette;
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
                    AppSection(
                      header: l10n.securityProtectedPassword,
                      footer: revealed
                          ? l10n.securityPasswordRevealNotice
                          : l10n.securityPasswordHiddenNotice,
                      children: [
                        AppRow.custom(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              revealed
                                  ? security.revealedSecret!
                                  : '••••••••••••••••',
                              key: const ValueKey('revealed-secret'),
                              style: kMonoTextStyle.copyWith(
                                fontSize: 16,
                                color: p.text,
                              ),
                            ),
                          ),
                        ),
                      ],
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
      final configs = ledger.security.sshConfigurations
          .where((s) => s.credentialId == credential.id)
          .toList();
      return AppScaffold(
        title: l10n.securityLinkedServers,
        largeTitle: false,
        children: [
          AppSection(
            header: credential.name,
            footer: l10n.securityCredentialReferenceCount(configs.length),
            children: [
              if (configs.isEmpty)
                AppRow.custom(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      l10n.securityNoCredentialReferences,
                      style: context.footnoteStyle.copyWith(fontSize: 14),
                    ),
                  ),
                ),
              for (final config in configs)
                AppRow(
                  icon: Icons.dns_outlined,
                  iconColor: AppTints.teal,
                  title:
                      ledger.byId(config.serverId)?.name ??
                      l10n.securityServerFallback,
                  subtitle:
                      '${config.username} @ ${config.host}:${config.port}',
                  chevron: true,
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
      final references = security.sshConfigurations
          .where((s) => s.credentialId == widget.credential.id)
          .toList();
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
                  AppRow(
                    icon: Icons.dns_outlined,
                    iconColor: AppTints.teal,
                    title:
                        widget.ledger.byId(s.serverId)?.name ??
                        l10n.securityServerFallback,
                    subtitle: '${s.username} @ ${s.host}:${s.port}',
                  ),
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
