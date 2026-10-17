import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ui/ui.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../servers/ledger_controller.dart';
import 'security_controller.dart';
import 'security_models.dart';
import 'security_widgets.dart';

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
    if (leftForeground(state)) {
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
          : security.referencesTo(widget.existing!.id);
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
                    securityEmptyRow(
                      context,
                      l10n.securityNoCredentialReferences,
                    ),
                  for (final config in impacts)
                    sshReferenceRow(context, widget.ledger, config),
                ],
              ),
          ],
        ),
      );
    },
  );
}
