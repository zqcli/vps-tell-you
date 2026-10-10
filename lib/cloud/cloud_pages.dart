import 'dart:async';

import 'package:flutter/cupertino.dart'
    show
        CupertinoActionSheet,
        CupertinoActionSheetAction,
        CupertinoActivityIndicator,
        CupertinoAlertDialog,
        CupertinoDialogAction,
        showCupertinoDialog,
        showCupertinoModalPopup;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/form_feedback.dart';
import '../core/ui/ui.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../servers/ledger_controller.dart';
import '../servers/server_detail.dart';
import '../servers/server_resource_fields.dart';
import 'cloud_controller.dart';
import 'cloud_models.dart';
import 'cloud_widgets.dart';
import 'provider_pages.dart';

Future<void> _reloadLedger(LedgerController ledger) =>
    ledger.refreshAfterCloudCommit();

void _cloudMessage(BuildContext context, Object message) =>
    showAppToast(context, localizedText(message, context.l10n));

/// Compatibility route; all entry points now use business providers first.
class CloudAccountsPage extends StatelessWidget {
  const CloudAccountsPage({super.key, required this.ledger});
  final LedgerController ledger;
  @override
  Widget build(BuildContext context) => ProvidersPage(ledger: ledger);
}

class CloudTemplatesPage extends StatefulWidget {
  const CloudTemplatesPage({
    super.key,
    required this.ledger,
    required this.businessProvider,
  });
  final LedgerController ledger;
  final ProviderRecord businessProvider;
  @override
  State<CloudTemplatesPage> createState() => _CloudTemplatesPageState();
}

class _CloudTemplatesPageState extends State<CloudTemplatesPage> {
  bool opening = false;
  Future<void> choose(BuildContext context, CloudProvider provider) async {
    if (opening) return;
    opening = true;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CloudAuthorizationPage(
          ledger: widget.ledger,
          provider: provider,
          businessProvider: widget.businessProvider,
        ),
      ),
    );
    opening = false;
    if (saved == true && context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: context.l10n.cloudAddAccount,
    largeTitle: false,
    children: [
      const CloudSteps(1),
      AppSection(
        header: context.l10n.cloudChooseTemplate,
        footer: context.l10n.cloudTemplateInfo,
        children: [
          for (final provider in CloudProvider.values)
            AppRow(
              icon: Icons.cloud_outlined,
              iconColor: AppTints.purple,
              title: cloudProviderName(provider),
              subtitle: switch (provider) {
                CloudProvider.solusVm1 => context.l10n.cloudV1TemplateInfo,
                CloudProvider.solusVm2 => context.l10n.cloudV2TemplateInfo,
                CloudProvider.rackNerd =>
                  context.l10n.cloudRackNerdTemplateInfo,
              },
              chevron: true,
              onTap: () => choose(context, provider),
            ),
        ],
      ),
      CloudFootnote(context.l10n.cloudSupportedPanels),
    ],
  );
}

class CloudAuthorizationPage extends StatefulWidget {
  const CloudAuthorizationPage({
    super.key,
    required this.ledger,
    required this.provider,
    required this.businessProvider,
    this.existing,
  });
  final LedgerController ledger;
  final CloudProvider provider;
  final ProviderRecord businessProvider;
  final CloudAccount? existing;
  @override
  State<CloudAuthorizationPage> createState() => _CloudAuthorizationPageState();
}

class _CloudAuthorizationPageState extends State<CloudAuthorizationPage>
    with WidgetsBindingObserver {
  final form = GlobalKey<FormState>();
  final alias = TextEditingController();
  bool _aliasInitialized = false;
  bool _validated = false;
  late final endpoint = TextEditingController(
    text: widget.existing?.endpoint ?? '',
  );
  final keyField = TextEditingController();
  final hashField = TextEditingController();
  final token = TextEditingController();
  CloudController get cloud => widget.ledger.cloud;
  bool get singleInstance => widget.provider.isSingleInstance;
  bool get rackNerd => widget.provider == CloudProvider.rackNerd;
  bool reading = false, navigating = false;
  int serial = 0;
  LocalizedMessage? error;
  CloudEndpoint? get parsedEndpoint {
    try {
      return CloudEndpoint.parse(
        endpoint.text,
        allowSolusVm1ConsolePath: widget.provider == CloudProvider.solusVm1,
        allowRackNerdApiPath: rackNerd,
      );
    } on CloudFailure {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_aliasInitialized) {
      alias.text =
          widget.existing?.alias ??
          context.l10n.cloudSuggestedAlias(cloudProviderName(widget.provider));
      _aliasInitialized = true;
    }
    if (_validated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) form.currentState?.validate();
      });
    }
  }

  void clearSecrets() {
    keyField.clear();
    hashField.clear();
    token.clear();
  }

  void cancel({bool update = true}) {
    serial++;
    cloud.cancelVerification();
    clearSecrets();
    if (mounted && update) {
      setState(() {
        reading = false;
        error = LocalizedText((l10n) => l10n.cloudVerifyCancelled);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (!navigating) cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!navigating) cloud.cancelVerification(notify: false);
    serial++;
    clearSecrets();
    alias.dispose();
    endpoint.dispose();
    keyField.dispose();
    hashField.dispose();
    token.dispose();
    super.dispose();
  }

  Future<void> verify() async {
    if (reading || navigating) return;
    _validated = !form.currentState!.validate();
    if (_validated) return;
    // Long forms lazily unmount offscreen fields. Validate the local alias
    // independently before any network request, not only via FormState.
    if (alias.text.trim().isEmpty || alias.text.trim().length > 80) {
      setState(() => error = LocalizedText((l10n) => l10n.cloudAliasInvalid));
      return;
    }
    final request = ++serial;
    FocusScope.of(context).unfocus();
    setState(() {
      reading = true;
      error = null;
    });
    CloudVerification? verified;
    try {
      final credentials = switch (widget.provider) {
        CloudProvider.solusVm1 => SolusVm1Credentials(
          key: keyField.text,
          hash: hashField.text,
        ),
        CloudProvider.solusVm2 => SolusVm2Credentials(token.text),
        CloudProvider.rackNerd => RackNerdCredentials(
          key: keyField.text,
          hash: hashField.text,
        ),
      };
      verified = await cloud.verifyConnection(
        provider: widget.provider,
        businessProvider: widget.businessProvider,
        endpoint: endpoint.text,
        credentials: credentials,
        existing: widget.existing,
      );
    } on CloudFailure catch (failure) {
      error = failure;
    } catch (_) {
      error = LocalizedText((l10n) => l10n.cloudVerifyFailed);
    } finally {
      if (mounted && request == serial) clearSecrets();
    }
    if (!mounted || request != serial) return;
    setState(() {
      reading = false;
      error ??= verified == null
          ? cloud.localizedError ??
                LocalizedText((l10n) => l10n.cloudVerifyNotSaved)
          : null;
    });
    if (verified == null) return;
    navigating = true;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CloudImportPage(
          ledger: widget.ledger,
          verification: verified!,
          alias: alias.text.trim(),
        ),
      ),
    );
    navigating = false;
    cloud.cancelVerification();
    if (!mounted) return;
    if (saved == true || verified.isCommitted) {
      Navigator.pop(context, true);
    } else {
      setState(
        () => error = LocalizedText((l10n) => l10n.cloudVerifyAgainRequired),
      );
    }
  }

  Widget secretField(
    TextEditingController controller,
    String label,
    String fieldKey,
  ) => cloudFormField(
    key: ValueKey(fieldKey),
    label: label,
    controller: controller,
    secret: true,
    required: true,
    enabled: !reading && !kIsWeb,
    validator: (text) =>
        text.isEmpty ? context.l10n.cloudRequiredField(label) : null,
  );

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) cancel(update: false);
    },
    child: AppScaffold(
      title: widget.existing == null
          ? context.l10n.cloudConnectProvider(
              cloudProviderName(widget.provider),
            )
          : context.l10n.cloudReauthorize,
      largeTitle: false,
      children: [
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CloudSteps(2),
              AppSection(
                children: [
                  AppRow(
                    icon: Icons.cloud_outlined,
                    iconColor: AppTints.purple,
                    title:
                        '${cloudProviderName(widget.provider)} · ${singleInstance ? context.l10n.cloudSingleVpsApi : context.l10n.cloudUserAccountApi}',
                  ),
                ],
              ),
              if (kIsWeb)
                CloudNotice(context.l10n.cloudWebPreviewNotice, error: true),
              AppSection(
                footerWidget: CloudFootnotes([
                  rackNerd
                      ? context.l10n.cloudRackNerdEndpointInfo
                      : context.l10n.cloudEndpointInfo,
                  if (widget.existing != null)
                    context.l10n.cloudEndpointIdentityInfo,
                ]),
                children: [
                  cloudFormField(
                    key: const ValueKey('cloud-alias'),
                    label: context.l10n.cloudAliasLabel,
                    controller: alias,
                    required: true,
                    enabled: !reading,
                    maxLength: 80,
                    validator: (text) => text.trim().isEmpty
                        ? context.l10n.cloudAliasRequired
                        : null,
                  ),
                  cloudFormField(
                    key: const ValueKey('cloud-endpoint'),
                    label: context.l10n.cloudEndpointLabel,
                    controller: endpoint,
                    required: true,
                    enabled: !reading,
                    readOnly: widget.existing != null,
                    keyboardType: TextInputType.url,
                    hint: widget.provider == CloudProvider.solusVm1
                        ? 'https://panel.example.com:5656'
                        : 'https://panel.example.com',
                    onChanged: (_) => setState(() => error = null),
                    validator: (_) => parsedEndpoint == null
                        ? rackNerd
                              ? context.l10n.cloudRackNerdEndpointValidation
                              : context.l10n.cloudEndpointValidation
                        : null,
                  ),
                ],
              ),
              if (parsedEndpoint case final target?)
                CloudNotice(
                  context.l10n.cloudVerifyTarget(
                    target.normalizedConsolePath
                        ? context.l10n.cloudConsolePathRemoved
                        : target.normalizedApiPath
                        ? context.l10n.cloudRackNerdApiPathRemoved
                        : '',
                    target.origin.toString(),
                  ),
                ),
              AppSection(
                footerWidget: CloudFootnotes([
                  if (singleInstance)
                    rackNerd
                        ? context.l10n.cloudRackNerdCredentialsInfo
                        : context.l10n.cloudV1CredentialsInfo
                  else
                    context.l10n.cloudV2CredentialsInfo,
                  if (!singleInstance && widget.existing != null)
                    context.l10n.cloudV2ReauthorizationInfo,
                ]),
                children: [
                  if (singleInstance) ...[
                    secretField(keyField, 'API Key', 'cloud-key'),
                    secretField(hashField, 'API Hash', 'cloud-hash'),
                  ] else
                    secretField(token, 'API Token', 'cloud-token'),
                ],
              ),
              if (singleInstance && widget.existing != null)
                CloudNotice(
                  context.l10n.cloudV1ReauthorizationInfo,
                  tone: AppTone.amber,
                ),
              if (error != null) CloudNotice(error!, error: true),
              if (reading)
                AppSection(
                  footer: context.l10n.cloudVerifyingInfo,
                  children: [
                    const AppRow.custom(
                      child: Center(child: CupertinoActivityIndicator()),
                    ),
                    AppRow(
                      key: const ValueKey('cancel-cloud-verify'),
                      center: true,
                      title: context.l10n.cloudCancelVerification,
                      onTap: cancel,
                    ),
                  ],
                )
              else
                CloudAction(
                  buttonKey: const ValueKey('verify-cloud'),
                  label: context.l10n.cloudVerifyRead,
                  icon: Icons.link,
                  onPressed: kIsWeb ? null : verify,
                ),
              CloudFootnote(context.l10n.cloudVerifyScopeInfo),
              AppInfoLink(
                label: context.l10n.r2CopyInfoCredentialHandling,
                message: context.l10n.cloudCredentialMemoryInfo,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class CloudImportPage extends StatefulWidget {
  const CloudImportPage({
    super.key,
    required this.ledger,
    this.verification,
    this.inventory,
    this.alias,
  }) : assert((verification == null) != (inventory == null));
  final LedgerController ledger;
  final CloudVerification? verification;
  final CloudInventory? inventory;
  final String? alias;
  @override
  State<CloudImportPage> createState() => _CloudImportPageState();
}

class _CloudImportPageState extends State<CloudImportPage>
    with WidgetsBindingObserver {
  CloudController get cloud => widget.ledger.cloud;
  CloudSnapshot get snapshot =>
      widget.verification?.snapshot ?? widget.inventory!.snapshot;
  CloudInventory? inventory;
  CloudAccount? get account =>
      inventory?.account ?? widget.verification?.existingAccount;
  CloudAccount? get currentAccount =>
      cloud.accounts.where((value) => value.id == account?.id).firstOrNull ??
      account;
  ProviderRecord? get businessProvider => cloud.providers
      .where(
        (provider) =>
            provider.id ==
            (widget.verification?.businessProvider.id ??
                account?.businessProviderId),
      )
      .firstOrNull;
  bool get singleInstance => snapshot.provider.isSingleInstance;
  bool get rebind =>
      singleInstance && widget.verification?.existingAccount != null;
  bool get authorizationSaved =>
      inventory != null || widget.verification?.isCommitted == true;
  bool get awaitingRebind => rebind && !authorizationSaved;
  bool get needsReload => cloud.needsReload || widget.ledger.refreshFailed;
  bool get unavailable =>
      businessProvider == null ||
      businessProvider!.needsReview ||
      (inventory != null &&
          currentAccount?.authScope == AdapterAuthScope.unknown);
  String? get pinnedServerId =>
      singleInstance && !awaitingRebind ? currentAccount?.pinnedServerId : null;
  final selected = <String>{};
  final drafts = <String, CloudImportDraft>{};
  final outcomes = <String, CloudImportItemResult>{};
  final failures = <String, LocalizedMessage>{};
  final unprocessed = <String>{};
  final displayName = TextEditingController();
  final resourceForm = GlobalKey<ServerResourceFieldsState>();
  final singleSelection = GlobalKey();
  final scroll = ScrollController();
  bool saving = false,
      editing = false,
      reloading = false,
      confirmRebind = false,
      committed = false,
      expired = false,
      hasResult = false,
      cancelling = false,
      closing = false;
  LocalizedMessage? error, interruption;
  Set<String> get conflictingKeys => {
    for (final instance in snapshot.instances)
      if (hasIdentityConflict(instance)) keyFor(instance),
  };
  Set<String> get retryKeys => {...failures.keys, ...unprocessed};
  Set<String> get retrySelection =>
      retryKeys.intersection(selected).difference(conflictingKeys);
  Set<String> get newSelection => selected
      .difference(retryKeys)
      .difference(outcomes.keys.toSet())
      .difference(conflictingKeys);
  bool get blocked =>
      saving ||
      editing ||
      reloading ||
      expired ||
      needsReload ||
      unavailable ||
      closing;
  String keyFor(CloudInstance instance) => cloudInstanceKey(snapshot, instance);
  bool hasIdentityConflict(CloudInstance instance) =>
      !awaitingRebind &&
      (cloud.hasSourceIdentityConflict(
            accountId: account?.id,
            instanceKey: keyFor(instance),
            uuid: instance.uuid,
          ) ||
          conflictingIds(instance).isNotEmpty);

  List<String> existingIds(CloudInstance instance) {
    if (awaitingRebind) return const [];
    return cloud
        .matchingDevices(
          type: snapshot.provider,
          endpoint:
              widget.verification?.endpoint.toString() ?? account!.endpoint,
          remoteAccountId: snapshot.remoteAccountId,
          instanceKey: keyFor(instance),
          accountId: account?.id,
          uuid: instance.uuid,
        )
        .map((binding) => binding.serverId)
        .toSet()
        .toList(growable: false);
  }

  List<String> conflictingIds(CloudInstance instance) {
    if (awaitingRebind) return const [];
    return cloud
        .conflictingDevices(
          type: snapshot.provider,
          endpoint:
              widget.verification?.endpoint.toString() ?? account!.endpoint,
          remoteAccountId: snapshot.remoteAccountId,
          instanceKey: keyFor(instance),
          accountId: account?.id,
          uuid: instance.uuid,
        )
        .map((binding) => binding.serverId)
        .toSet()
        .toList(growable: false);
  }

  void finish({bool? result, bool afterSave = false}) {
    if (!mounted ||
        closing ||
        (saving && !afterSave) ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    closing = true;
    if (!authorizationSaved) cloud.cancelVerification();
    Navigator.pop(context, result ?? committed);
  }

  bool complete(CloudInstance instance) =>
      drafts[keyFor(instance)]!.resources.validate(requireComplete: true) ==
      null;

  String deviceName(String id) {
    final server = widget.ledger.byId(id);
    return server == null
        ? context.l10n.cloudLocalRecord
        : context.l10n.cloudRecordWithState(
            server.name,
            server.archived ? context.l10n.cloudArchivedSuffix : '',
          );
  }

  List<String> addressHints(CloudInstance instance) {
    final ids = existingIds(instance).toSet();
    final addresses = [instance.ipv4, instance.ipv6, instance.hostname]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .map((value) => value.toLowerCase())
        .toSet();
    if (addresses.isEmpty) return const [];
    return widget.ledger.records
        .where(
          (server) =>
              !ids.contains(server.id) &&
              [server.host, server.resources?.ip, server.resources?.hostname]
                  .whereType<String>()
                  .any((value) => addresses.contains(value.toLowerCase())),
        )
        .map((server) => deviceName(server.id))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    inventory = widget.inventory;
    for (final instance in snapshot.instances) {
      final key = keyFor(instance);
      drafts[key] = CloudImportDraft(
        instanceKey: key,
        resources: resourcesFromCloud(instance),
      );
    }
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.inactive &&
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached) {
      return;
    }
    if (saving) stop();
    if (widget.verification != null && !authorizationSaved) {
      cloud.cancelVerification();
      if (mounted) {
        setState(() {
          expired = true;
          error = LocalizedText((l10n) => l10n.cloudAuthorizationExpired);
        });
      }
    }
  }

  @override
  void dispose() {
    closing = true;
    cancelling = true;
    WidgetsBinding.instance.removeObserver(this);
    if (widget.verification != null && !authorizationSaved) {
      cloud.cancelVerification(notify: false);
    }
    if (saving && inventory != null) {
      cloud.cancelAccount(inventory!.account.id, notify: false);
    }
    displayName.dispose();
    scroll.dispose();
    super.dispose();
  }

  void stop() {
    if (!saving || cancelling) return;
    if (inventory != null) {
      cloud.cancelAccount(inventory!.account.id);
    } else if (!authorizationSaved) {
      cloud.cancelVerification();
    }
    if (mounted) setState(() => cancelling = true);
  }

  Future<void> reloadLocal() async {
    if (saving || editing || reloading) return;
    setState(() => reloading = true);
    await cloud.reload();
    if (!cloud.needsReload) await _reloadLedger(widget.ledger);
    if (!mounted) return;
    setState(() {
      reloading = false;
      error = needsReload
          ? cloud.localizedError ??
                LocalizedText((l10n) => l10n.cloudLedgerNotUpdated)
          : null;
    });
  }

  Future<void> edit(CloudInstance instance) async {
    if (blocked ||
        hasIdentityConflict(instance) ||
        existingIds(instance).isNotEmpty ||
        outcomes.containsKey(keyFor(instance))) {
      return;
    }
    setState(() => editing = true);
    final result = await Navigator.push<CloudImportDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => _CloudResourceCompletionPage(
          instance: instance,
          draft: drafts[keyFor(instance)]!,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      editing = false;
      if (result != null && !expired) {
        drafts[result.instanceKey] = result;
        selected.add(result.instanceKey);
        error = null;
      }
    });
  }

  /// Credentials are committed once, before the independent per-device batch.
  /// Retries always reuse this exact inventory and never resubmit verification.
  Future<void> save({bool accountOnly = false, bool retry = false}) async {
    if (blocked || (awaitingRebind && !confirmRebind)) return;
    final picked = accountOnly
        ? <String>{}
        : Set<String>.of(retry ? retrySelection : newSelection);
    picked.removeAll(outcomes.keys);
    if (!accountOnly && picked.isEmpty) return;
    if (singleInstance && picked.isNotEmpty) {
      final invalid = <FormFieldState<Object?>>{};
      final resources = resourceForm.currentState?.validateAndRead(
        invalidFields: invalid,
      );
      if (resources == null) {
        revealFirstInvalidField(invalid);
        setState(
          () => error = LocalizedText((l10n) => l10n.cloudResourcesIncomplete),
        );
        return;
      }
      final key = picked.single;
      drafts[key] = CloudImportDraft(
        instanceKey: key,
        resources: resources,
        displayName: displayName.text.trim().isEmpty
            ? null
            : displayName.text.trim(),
      );
    }
    if (picked.any(
      (key) => drafts[key]?.resources.validate(requireComplete: true) != null,
    )) {
      setState(
        () => error = LocalizedText((l10n) => l10n.cloudResourcesIncomplete),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      cancelling = false;
      error = null;
    });
    try {
      if (inventory == null) {
        final saved = await cloud.saveAccount(
          widget.verification!,
          alias: widget.alias!,
          selectedInstanceKeys: const {},
          confirmV1Rebind: confirmRebind,
        );
        if (!saved) {
          if (mounted) {
            setState(() {
              expired = widget.verification!.cancellation.isCancelled;
              error =
                  cloud.localizedError ??
                  LocalizedText((l10n) => l10n.cloudSaveFailed);
            });
          }
          return;
        }
        inventory = cloud.lastSavedInventory;
        committed = true;
        expired = false;
        if (mounted) setState(() {});
      }
      // A pop/replacement can remove this route during post-commit cleanup.
      // The saved instance stays committed, but a new batch must not begin.
      if (!mounted || closing) return;
      if (accountOnly) {
        if (!needsReload) await _reloadLedger(widget.ledger);
        if (!mounted || closing || ModalRoute.of(context)?.isCurrent != true) {
          return;
        }
        if (!needsReload) {
          _cloudMessage(
            context,
            LocalizedText((l10n) => l10n.cloudAccountSavedOnly),
          );
          finish(result: true, afterSave: true);
        }
        return;
      }
      if (needsReload ||
          inventory == null ||
          cancelling ||
          ModalRoute.of(context)?.isCurrent != true) {
        if (mounted) {
          setState(() {
            hasResult = true;
            unprocessed.addAll(picked);
            interruption = cancelling
                ? LocalizedText((l10n) => l10n.cloudImportCancelled)
                : null;
            error = needsReload ? cloud.localizedError : null;
          });
        }
        return;
      }
      final result = await cloud.importBatch(inventory!, [
        for (final key in picked) drafts[key]!,
      ]);
      if (result != null) {
        hasResult = true;
        for (final key in picked) {
          failures.remove(key);
          unprocessed.remove(key);
        }
        for (final item in result.items) {
          outcomes[item.instanceKey] = item;
          selected.remove(item.instanceKey);
        }
        failures.addAll(result.failures);
        unprocessed.addAll(result.unprocessed);
        interruption = result.interruption;
        committed = committed || result.importedCount > 0;
        if (!cloud.needsReload) await _reloadLedger(widget.ledger);
      } else {
        hasResult = true;
        unprocessed.addAll(picked);
        interruption =
            cloud.localizedError ??
            LocalizedText((l10n) => l10n.cloudOperationFailed);
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
          cancelling = false;
        });
        if (hasResult) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && scroll.hasClients) scroll.jumpTo(0);
          });
        }
      }
    }
  }

  bool get needsSingleSelection =>
      singleInstance &&
      selected.isEmpty &&
      snapshot.instances.isNotEmpty &&
      existingIds(snapshot.instances.single).isEmpty &&
      pinnedServerId == null &&
      !hasResult;

  void revealSingleSelection() {
    FocusScope.of(context).unfocus();
    final target = singleSelection.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 250),
        alignment: 0.1,
      );
    }
  }

  Widget openDevice(String id) {
    final available = !saving && widget.ledger.byId(id) != null;
    return AppRow(
      icon: Icons.dns_outlined,
      iconColor: AppTints.slate,
      title: deviceName(id),
      chevron: true,
      enabled: available,
      onTap: available
          ? () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => ServerDetail(controller: widget.ledger, id: id),
              ),
            )
          : null,
    );
  }

  Widget instanceCard(CloudInstance instance, {String? header}) {
    final key = keyFor(instance);
    final conflicting = conflictingIds(instance);
    final identityConflict = hasIdentityConflict(instance);
    final existing = existingIds(instance);
    final result = outcomes[key];
    final ids = identityConflict ? conflicting : result?.serverIds ?? existing;
    final linked = !identityConflict && (result != null || existing.isNotEmpty);
    final hints = linked || identityConflict
        ? const <String>[]
        : addressHints(instance);
    final ready = complete(instance);
    final (statusText, statusTone) = identityConflict
        ? (context.l10n.cloudImportIdentityConflict, AppTone.red)
        : result?.imported == true
        ? (context.l10n.cloudImportImported, AppTone.green)
        : linked
        ? (context.l10n.cloudImportExisting, AppTone.blue)
        : failures.containsKey(key)
        ? (context.l10n.cloudImportFailed, AppTone.red)
        : unprocessed.contains(key)
        ? (context.l10n.cloudImportUnprocessed, AppTone.amber)
        : ready
        ? (context.l10n.cloudImportReady, AppTone.green)
        : (context.l10n.cloudImportNeedsCompletion, AppTone.amber);
    final addresses = [instance.ipv4, instance.ipv6].whereType<String>();
    return AppSection(
      key: singleInstance ? singleSelection : null,
      header: header,
      topSpacing: header == null ? 12 : null,
      children: [
        CloudCheckRow(
          key: ValueKey('cloud-select-$key'),
          value: !identityConflict && (linked || selected.contains(key)),
          onChanged:
              blocked ||
                  identityConflict ||
                  linked ||
                  pinnedServerId != null ||
                  (!singleInstance && !ready)
              ? null
              : (checked) => setState(() {
                  if (checked) {
                    selected.add(key);
                  } else {
                    selected.remove(key);
                  }
                }),
          title: singleInstance
              ? context.l10n.cloudV1Instance
              : instance.name ??
                    context.l10n.cloudInstanceFallback(
                      instance.serverId?.toString() ??
                          context.l10n.cloudPowerUnknown,
                    ),
          status: Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusPill(statusText, tone: statusTone),
          ),
          details: [
            if (!singleInstance)
              context.l10n.cloudProjectInstance(
                (instance.projectName ?? instance.projectId)?.toString() ??
                    context.l10n.cloudPowerUnknown,
                instance.serverId?.toString() ?? context.l10n.cloudPowerUnknown,
              ),
            singleInstance
                ? context.l10n.cloudV1Identity
                : addresses.isEmpty
                ? context.l10n.cloudIpNotProvided
                : addresses.join(' / '),
            context.l10n.cloudPowerLastRead(
              cloudPowerLabel(instance.power, l10n: context.l10n),
            ),
            if (!singleInstance && ready && !linked && !identityConflict)
              drafts[key]!.resources.specSummaryFor(context.l10n),
          ],
        ),
        if (identityConflict)
          const CloudInlineNote(CloudAccountFailure.identity, error: true),
        if (ids.length > 1 && !identityConflict)
          CloudInlineNote(
            context.l10n.cloudImportExistingConflict(ids.length),
            error: true,
          ),
        for (final id in ids) openDevice(id),
        if (hints.isNotEmpty)
          CloudInlineNote(context.l10n.cloudImportAddressHint(hints.join('、'))),
        if (failures[key] case final message?)
          CloudInlineNote(message, error: true),
        if (!singleInstance && !linked && !identityConflict)
          AppRow(
            key: ValueKey('cloud-complete-$key'),
            icon: Icons.edit_outlined,
            iconColor: ready ? AppTints.green : AppTints.orange,
            title: ready
                ? context.l10n.cloudImportReviewResources
                : context.l10n.cloudImportCompleteResources,
            chevron: true,
            enabled: !blocked,
            onTap: blocked ? null : () => edit(instance),
          ),
      ],
    );
  }

  /// Single-device forms keep every field mounted (one box in a sliver);
  /// long device inventories scroll lazily.
  Widget page(List<Widget> children) => AppScaffold(
    title: context.l10n.cloudChooseInstances,
    largeTitle: false,
    controller: scroll,
    slivers: singleInstance
        ? [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ]
        : null,
    children: singleInstance ? const [] : children,
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.ledger, cloud]),
    builder: (context, _) => PopScope<Object?>(
      canPop: !saving && !committed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !saving && committed) {
          finish(result: true);
        } else if (didPop) {
          closing = true;
          if (saving) stop();
          if (!authorizationSaved) cloud.cancelVerification();
        }
      },
      child: page([
        const CloudSteps(3),
        CloudNotice(
          context.l10n.cloudInventoryComplete(
            snapshot.instances.length,
            cloudTime(snapshot.completedAt),
            authorizationSaved ? '' : context.l10n.cloudAuthorizationUnsaved,
          ),
        ),
        AppSection(
          children: [
            AppRow(
              leading: ProviderAvatar(name: businessProvider?.name),
              title: widget.alias ?? account!.alias,
              subtitle: businessProvider?.name,
            ),
            AppKeyValueRow(
              label: context.l10n.cloudPanelAddress,
              value:
                  widget.verification?.endpoint.toString() ?? account!.endpoint,
              mono: true,
            ),
          ],
        ),
        if (authorizationSaved) CloudNotice(context.l10n.cloudImportSaved),
        if (unavailable)
          CloudNotice(
            businessProvider?.needsReview == true || businessProvider == null
                ? context.l10n.providerReviewRequired
                : context.l10n.adapterScopeUnavailable,
            tone: AppTone.amber,
          ),
        if (needsReload) ...[
          CloudNotice(context.l10n.cloudSavedReloadFailed, error: true),
          AppSection(
            topSpacing: 10,
            children: [
              AppRow(
                key: const ValueKey('cloud-import-reload'),
                center: true,
                title: context.l10n.cloudReloadLocal,
                enabled: !(saving || reloading),
                onTap: saving || reloading ? null : reloadLocal,
              ),
            ],
          ),
        ],
        if (pinnedServerId case final id?) ...[
          CloudNotice(context.l10n.providerUiPinnedHelp(deviceName(id))),
          AppSection(topSpacing: 10, children: [openDevice(id)]),
        ],
        if (hasResult) ...[
          AppSection(
            key: const ValueKey('cloud-import-results'),
            header: context.l10n.cloudImportResultsTitle,
            children: [
              AppRow(
                title: context.l10n.cloudImportSummary(
                  outcomes.values.where((item) => item.imported).length,
                  outcomes.values.where((item) => !item.imported).length,
                  failures.length,
                  unprocessed.length,
                ),
              ),
            ],
          ),
          if (interruption != null) CloudNotice(interruption!, error: true),
        ],
        if (snapshot.instances.isEmpty)
          AppSection(
            topSpacing: 12,
            children: [
              AppRow(
                title: authorizationSaved
                    ? context.l10n.cloudEmptyInventory
                    : context.l10n.cloudEmptyVerification,
              ),
            ],
          ),
        for (final (index, instance) in snapshot.instances.indexed)
          instanceCard(
            instance,
            header: index == 0 ? context.l10n.cloudStepInstances : null,
          ),
        if (singleInstance &&
            snapshot.instances.isNotEmpty &&
            existingIds(snapshot.instances.single).isEmpty &&
            !outcomes.containsKey(keyFor(snapshot.instances.single)) &&
            pinnedServerId == null) ...[
          if (needsSingleSelection)
            CloudNotice(
              context.l10n.cloudSelectBeforeComplete,
              tone: AppTone.amber,
            ),
          AppSection(
            footer: context.l10n.cloudLocalNameInfo,
            children: [
              AppFormRow(
                label: context.l10n.cloudLocalDisplayName,
                child: AppTextField(
                  key: const ValueKey('cloud-v1-name'),
                  controller: displayName,
                  label: context.l10n.cloudLocalDisplayName,
                  enabled: !blocked,
                  maxLength: 80,
                ),
              ),
            ],
          ),
          ServerResourceFields(
            key: resourceForm,
            enabled: !blocked,
            observed: observedCloudResources(snapshot.instances.single),
          ),
          CloudFootnote(
            snapshot.provider == CloudProvider.rackNerd
                ? context.l10n.cloudRackNerdResourcesInfo
                : context.l10n.cloudV1ResourcesInfo,
          ),
        ],
        if (awaitingRebind) ...[
          CloudNotice(context.l10n.cloudRebindWarning, tone: AppTone.amber),
          AppSection(
            topSpacing: 10,
            children: [
              CloudCheckRow(
                key: const ValueKey('cloud-confirm-rebind'),
                value: confirmRebind,
                onChanged: blocked
                    ? null
                    : (value) => setState(() => confirmRebind = value),
                title: context.l10n.cloudConfirmRebind,
              ),
            ],
          ),
        ],
        CloudFootnote(
          context.l10n.cloudImportBoundary(
            singleInstance
                ? context.l10n.cloudV1Deduplication
                : context.l10n.cloudV2Deduplication,
          ),
        ),
        CloudFootnote(context.l10n.cloudImportFinanceLater),
        if (error != null) CloudNotice(error!, error: true),
        if (needsSingleSelection && !blocked)
          AppSection(
            children: [
              AppRow(
                key: const ValueKey('cloud-return-to-instance'),
                center: true,
                title: context.l10n.cloudReturnSelect,
                onTap: revealSingleSelection,
              ),
            ],
          ),
        if (!hasResult || newSelection.isNotEmpty)
          CloudAction(
            buttonKey: const ValueKey('cloud-import-submit'),
            icon: Icons.download_outlined,
            onPressed:
                blocked ||
                    newSelection.isEmpty ||
                    pinnedServerId != null ||
                    (awaitingRebind && !confirmRebind)
                ? null
                : () => save(),
            label: saving
                ? context.l10n.cloudSaving
                : newSelection.isEmpty
                ? context.l10n.cloudNoneSelected
                : authorizationSaved
                ? context.l10n.cloudImportCount(newSelection.length)
                : context.l10n.cloudSaveImportCount(newSelection.length),
          ),
        if (hasResult && retryKeys.isNotEmpty)
          CloudAction(
            buttonKey: const ValueKey('cloud-import-retry'),
            icon: Icons.refresh,
            onPressed: blocked || retrySelection.isEmpty
                ? null
                : () => save(retry: true),
            label: retrySelection.isEmpty
                ? context.l10n.cloudNoneSelected
                : context.l10n.cloudImportRetryCount(retrySelection.length),
          ),
        if (widget.verification != null && !authorizationSaved)
          CloudAction(
            buttonKey: const ValueKey('cloud-save-only'),
            kind: AppButtonKind.tonal,
            onPressed: blocked || (awaitingRebind && !confirmRebind)
                ? null
                : () => save(accountOnly: true),
            label: widget.verification!.existingAccount == null
                ? context.l10n.cloudSaveOnly
                : rebind
                ? context.l10n.cloudUpdateUnlink
                : context.l10n.cloudUpdateOnly,
          ),
        if (saving) ...[
          CloudFootnote(context.l10n.cloudSavingInfo),
          CloudAction(
            buttonKey: const ValueKey('cloud-import-cancel'),
            kind: AppButtonKind.tonal,
            destructive: true,
            onPressed: cancelling ? null : stop,
            label: cancelling
                ? context.l10n.cloudImportCancelling
                : context.l10n.cloudImportCancel,
          ),
        ],
        if ((hasResult || authorizationSaved) && !saving)
          CloudAction(
            buttonKey: const ValueKey('cloud-import-done'),
            kind: AppButtonKind.tonal,
            onPressed: finish,
            label: context.l10n.cloudDone,
          ),
        if (expired && !saving)
          CloudAction(
            buttonKey: const ValueKey('cloud-import-return-verify'),
            kind: AppButtonKind.tonal,
            onPressed: finish,
            label: context.l10n.cloudReturnVerify,
          ),
      ]),
    ),
  );
}

/// Each V2 device uses one eager shared form. Large inventory scrolling cannot
/// dispose resource editors or overwrite a reviewed draft with raw API values.
class _CloudResourceCompletionPage extends StatefulWidget {
  const _CloudResourceCompletionPage({
    required this.instance,
    required this.draft,
  });
  final CloudInstance instance;
  final CloudImportDraft draft;
  @override
  State<_CloudResourceCompletionPage> createState() =>
      _CloudResourceCompletionPageState();
}

class _CloudResourceCompletionPageState
    extends State<_CloudResourceCompletionPage> {
  final resourceForm = GlobalKey<ServerResourceFieldsState>();
  late final name = TextEditingController(text: widget.draft.displayName);
  LocalizedMessage? error;
  bool returning = false;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void save() {
    if (returning || ModalRoute.of(context)?.isCurrent != true) return;
    final invalid = <FormFieldState<Object?>>{};
    final resources = resourceForm.currentState?.validateAndRead(
      invalidFields: invalid,
    );
    if (resources == null) {
      revealFirstInvalidField(invalid);
      setState(
        () => error = LocalizedText((l10n) => l10n.cloudResourcesIncomplete),
      );
      return;
    }
    returning = true;
    Navigator.pop(
      context,
      CloudImportDraft(
        instanceKey: widget.draft.instanceKey,
        resources: resources,
        displayName: name.text.trim().isEmpty ? null : name.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: context.l10n.cloudImportReviewResources,
    largeTitle: false,
    // One box keeps every resource editor mounted while scrolling.
    slivers: [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                widget.instance.name ??
                    context.l10n.cloudInstanceFallback(
                      widget.instance.serverId.toString(),
                    ),
                style: TextStyle(
                  fontSize: 22,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: context.palette.text,
                ),
              ),
            ),
            AppSection(
              topSpacing: 8,
              footerWidget: CloudFootnotes([
                context.l10n.cloudLocalNameInfo,
                context.l10n.cloudImportCompletionInfo,
              ]),
              children: [
                AppFormRow(
                  label: context.l10n.cloudLocalDisplayName,
                  child: AppTextField(
                    key: const ValueKey('cloud-device-name'),
                    controller: name,
                    label: context.l10n.cloudLocalDisplayName,
                    maxLength: 80,
                  ),
                ),
              ],
            ),
            ServerResourceFields(
              key: resourceForm,
              initial: widget.draft.resources,
              observed: observedCloudResources(widget.instance),
            ),
            if (error != null) CloudNotice(error!, error: true),
            CloudAction(
              buttonKey: const ValueKey('cloud-resource-done'),
              icon: Icons.check,
              onPressed: save,
              label: context.l10n.cloudImportCompleteAndSelect,
            ),
          ],
        ),
      ),
    ],
  );
}

/// Owns one cancellable saved-account read. Leaving cannot open a late result.
class CloudReadPage extends StatefulWidget {
  const CloudReadPage({
    super.key,
    required this.ledger,
    required this.account,
    required this.importAfterRead,
  });
  final LedgerController ledger;
  final CloudAccount account;
  final bool importAfterRead;
  @override
  State<CloudReadPage> createState() => _CloudReadPageState();
}

class _CloudReadPageState extends State<CloudReadPage>
    with WidgetsBindingObserver {
  CloudController get cloud => widget.ledger.cloud;
  bool reading = true;
  bool closing = false, openingPreview = false;
  CloudInventory? result;
  LocalizedMessage? error;
  int serial = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initialSerial = serial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && serial == initialSerial) unawaited(read());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (reading &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      cancel();
    }
  }

  @override
  void dispose() {
    closing = true;
    WidgetsBinding.instance.removeObserver(this);
    serial++;
    cloud.cancelAccount(widget.account.id, notify: false);
    super.dispose();
  }

  void cancel({bool update = true}) {
    serial++;
    cloud.cancelAccount(widget.account.id);
    if (update && mounted) {
      setState(() {
        reading = false;
        error = LocalizedText((l10n) => l10n.cloudReadCancelled);
      });
    }
  }

  void finish([bool? result]) {
    if (!mounted || closing || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    closing = true;
    Navigator.pop(context, result);
  }

  Future<void> openPreview(CloudInventory inventory) async {
    if (!mounted ||
        closing ||
        reading ||
        openingPreview ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() => openingPreview = true);
    final imported = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CloudImportPage(ledger: widget.ledger, inventory: inventory),
      ),
    );
    if (!mounted) return;
    setState(() => openingPreview = false);
    finish(imported);
  }

  Future<void> read() async {
    if (closing || openingPreview || reading && serial != 0) return;
    final request = ++serial;
    setState(() {
      reading = true;
      error = null;
    });
    final current = cloud.accounts
        .where((a) => a.id == widget.account.id)
        .firstOrNull;
    if (current == null) {
      setState(() {
        reading = false;
        error = LocalizedText((l10n) => l10n.cloudAccountUnlinkedReturn);
      });
      return;
    }
    final provider = cloud.providers
        .where((provider) => provider.id == current.businessProviderId)
        .firstOrNull;
    if (widget.importAfterRead &&
        (provider == null ||
            provider.needsReview ||
            current.authScope == AdapterAuthScope.unknown)) {
      setState(() {
        reading = false;
        error = provider == null || provider.needsReview
            ? LocalizedText((l10n) => l10n.providerReviewRequired)
            : LocalizedText((l10n) => l10n.adapterScopeUnavailable);
      });
      return;
    }
    final inventory = await cloud.refreshAccount(current);
    if (!mounted || request != serial) return;
    setState(() {
      reading = false;
      result = inventory;
      error = inventory == null
          ? cloud.localizedError ??
                LocalizedText((l10n) => l10n.cloudReadIncomplete)
          : null;
    });
    if (inventory != null &&
        widget.importAfterRead &&
        !closing &&
        ModalRoute.of(context)?.isCurrent == true) {
      await openPreview(inventory);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) {
        closing = true;
        cancel(update: false);
      }
    },
    child: AppScaffold(
      title: widget.importAfterRead
          ? context.l10n.cloudReadImportable
          : context.l10n.cloudRefreshAccount,
      largeTitle: false,
      children: [
        AppSection(
          topSpacing: 8,
          children: [
            AppRow(
              icon: Icons.cloud_outlined,
              iconColor: AppTints.purple,
              title: widget.account.alias,
              subtitle: widget.account.endpoint,
            ),
          ],
        ),
        if (reading)
          AppSection(
            footer: context.l10n.cloudReadingInfo,
            children: [
              const AppRow.custom(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(child: CupertinoActivityIndicator()),
                ),
              ),
              AppRow(
                center: true,
                title: context.l10n.cloudCancelRead,
                onTap: cancel,
              ),
            ],
          ),
        if (error != null) ...[
          CloudNotice(error!, error: true),
          CloudAction(
            buttonKey: const ValueKey('cloud-read-again'),
            kind: AppButtonKind.tonal,
            icon: Icons.refresh,
            onPressed: read,
            label: context.l10n.cloudReadAgain,
          ),
        ],
        if (result != null && !reading && error == null) ...[
          CloudNotice(
            context.l10n.cloudInventoryComplete(
              result!.snapshot.instances.length,
              cloudTime(result!.snapshot.completedAt),
              '',
            ),
          ),
          CloudFootnote(context.l10n.cloudReadCompleteInfo),
          if (widget.importAfterRead)
            CloudAction(
              buttonKey: const ValueKey('cloud-read-open-preview'),
              icon: Icons.download_outlined,
              onPressed: openingPreview ? null : () => openPreview(result!),
              label: context.l10n.cloudChooseInstances,
            ),
          CloudAction(
            buttonKey: const ValueKey('cloud-read-done'),
            kind: widget.importAfterRead
                ? AppButtonKind.tonal
                : AppButtonKind.primary,
            onPressed: finish,
            label: context.l10n.cloudDone,
          ),
        ],
      ],
    ),
  );
}

Future<void> cloudAccountMenu(
  BuildContext context,
  LedgerController ledger,
  CloudAccount account,
) async {
  final provider = ledger.cloud.providers
      .where((provider) => provider.id == account.businessProviderId)
      .firstOrNull;
  final needsReview = provider == null || provider.needsReview;
  bool actionEnabled(String action) =>
      action == 'detail' ||
      action == 'servers' ||
      (!ledger.cloud.busy &&
          !ledger.cloud.needsReload &&
          !ledger.refreshFailed &&
          !(needsReview && (action == 'reauthorize' || action == 'import')) &&
          !(action == 'import' &&
              account.authScope == AdapterAuthScope.unknown));
  // An action sheet cannot grey out entries, so unavailable ones are left out
  // (the message explains a pending provider review). Labels resolve while the
  // sheet builds, so a language change re-translates it.
  final action = await showCupertinoModalPopup<String>(
    context: context,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      final rows = <(String, String)>[
        ('detail', l10n.cloudViewDetails),
        if (needsReview) ('provider', l10n.providerUiConfirmOwnership),
        ('rename', l10n.cloudRenameAccount),
        ('reauthorize', l10n.cloudReauthorize),
        ('import', l10n.cloudContinueImport),
        ('servers', l10n.cloudLinkedServers),
        ('refresh', l10n.cloudRefreshAccount),
        ('unbind', l10n.cloudUnlinkAccount),
      ];
      return CupertinoActionSheet(
        title: Text(account.alias),
        message: Text(
          [
            '${cloudProviderName(account.provider)} · ${account.endpoint}',
            if (needsReview) l10n.providerReviewRequired,
          ].join('\n'),
        ),
        actions: [
          for (final (id, label) in rows)
            if (actionEnabled(id))
              CupertinoActionSheetAction(
                isDestructiveAction: id == 'unbind',
                onPressed: () => Navigator.pop(sheetContext, id),
                child: Text(label),
              ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(l10n.cancel),
        ),
      );
    },
  );
  if (!context.mounted || action == null) return;
  final cloud = ledger.cloud;
  final current = cloud.accounts.where((a) => a.id == account.id).firstOrNull;
  if (current == null) return;
  if (action == 'provider') {
    await confirmAdapterProviderOwnership(context, ledger, current);
  } else if (action == 'detail' || action == 'servers') {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CloudAccountDetailsPage(
          ledger: ledger,
          accountId: current.id,
          associationsOnly: action == 'servers',
        ),
      ),
    );
  } else if (action == 'reauthorize') {
    final businessProvider = cloud.providers
        .where((p) => p.id == current.businessProviderId)
        .firstOrNull;
    if (businessProvider == null || businessProvider.needsReview) {
      _cloudMessage(context, context.l10n.providerReviewRequired);
      return;
    }
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CloudAuthorizationPage(
          ledger: ledger,
          provider: current.provider,
          businessProvider: businessProvider,
          existing: current,
        ),
      ),
    );
  } else if (action == 'rename') {
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (_) => _CloudRenameDialog(alias: current.alias),
    );
    if (name == null) return;
    final ok = await cloud.renameAccount(current, name);
    if (context.mounted) {
      _cloudMessage(
        context,
        ok
            ? LocalizedText((l10n) => l10n.cloudAliasSaved)
            : cloud.localizedError ??
                  LocalizedText((l10n) => l10n.cloudNameSaveFailed),
      );
    }
  } else if (action == 'import' || action == 'refresh') {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CloudReadPage(
          ledger: ledger,
          account: current,
          importAfterRead: action == 'import',
        ),
      ),
    );
  } else if (action == 'unbind') {
    final affected = cloud.bindings
        .where((binding) => binding.accountId == current.id)
        .map((binding) => binding.serverId)
        .toSet();
    final ok = await showAppConfirm(
      context,
      title: LocalizedText((l10n) => l10n.cloudUnlinkAccountTitle),
      message: LocalizedText(
        (l10n) =>
            '${l10n.cloudUnlinkAccountMessage(current.alias, current.provider.isSingleInstance ? l10n.cloudRevokeV1 : l10n.cloudRevokeV2)}\n\n${l10n.cloudInstanceDeleteImpact(affected.length, affected.isEmpty ? l10n.providerUiNoAffectedDevices : affected.map((id) => l10n.cloudRecordWithState(ledger.byId(id)?.name ?? l10n.cloudLocalRecord, ledger.byId(id)?.archived == true ? l10n.cloudArchivedSuffix : '')).join('\n'))}',
      ),
      action: LocalizedText((l10n) => l10n.cloudUnlinkLocal),
      dangerous: true,
    );
    if (!ok) return;
    final saved = await cloud.unbindAccount(current);
    if (saved) await _reloadLedger(ledger);
    if (context.mounted) {
      _cloudMessage(
        context,
        saved
            ? LocalizedText((l10n) => l10n.cloudAccountUnlinked)
            : cloud.localizedError ??
                  LocalizedText((l10n) => l10n.cloudUnlinkFailed),
      );
    }
  }
}

class CloudAccountDetailsPage extends StatelessWidget {
  const CloudAccountDetailsPage({
    super.key,
    required this.ledger,
    required this.accountId,
    this.associationsOnly = false,
  });
  final LedgerController ledger;
  final String accountId;
  final bool associationsOnly;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([ledger, ledger.cloud]),
    builder: (context, _) {
      final account = ledger.cloud.accounts
          .where((a) => a.id == accountId)
          .firstOrNull;
      final bindings = ledger.cloud.bindings
          .where((b) => b.accountId == accountId)
          .toList();
      final provider = ledger.cloud.providers
          .where((provider) => provider.id == account?.businessProviderId)
          .firstOrNull;
      final p = context.palette;
      return AppScaffold(
        title: associationsOnly
            ? context.l10n.cloudLinkedServers
            : context.l10n.cloudAccountDetails,
        largeTitle: false,
        actions: [
          if (account != null)
            _CloudAccountMenuButton(ledger: ledger, account: account),
        ],
        children: [
          if (account == null)
            CloudNotice(context.l10n.cloudAccountRemovedNotice)
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  const AppIconSquare(
                    icon: Icons.cloud_outlined,
                    color: AppTints.purple,
                    size: 44,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.alias,
                          style: TextStyle(
                            fontSize: 22,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            color: p.text,
                          ),
                        ),
                        Text(
                          cloudProviderName(account.provider),
                          style: TextStyle(fontSize: 14, color: p.text2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AppSection(
              topSpacing: 12,
              children: [
                AppRow(
                  key: const ValueKey('cloud-instance-provider'),
                  leading: ProviderAvatar(name: provider?.name),
                  title: provider?.name ?? context.l10n.providerUiUnspecified,
                  subtitle: context.l10n.providerUiOpenProvider,
                  chevron: provider != null,
                  onTap: provider == null
                      ? null
                      : () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProviderDetailsPage(
                              ledger: ledger,
                              providerId: provider.id,
                            ),
                          ),
                        ),
                ),
              ],
            ),
            if (provider == null || provider.needsReview) ...[
              CloudNotice(
                context.l10n.providerReviewRequired,
                tone: AppTone.amber,
              ),
              AppSection(
                topSpacing: 10,
                children: [
                  AppRow(
                    key: const ValueKey('cloud-instance-confirm-provider'),
                    icon: Icons.fact_check_outlined,
                    iconColor: AppTints.orange,
                    title: context.l10n.providerUiConfirmOwnership,
                    chevron: true,
                    enabled: !(ledger.cloud.busy || ledger.cloud.needsReload),
                    onTap: ledger.cloud.busy || ledger.cloud.needsReload
                        ? null
                        : () => confirmAdapterProviderOwnership(
                            context,
                            ledger,
                            account,
                          ),
                  ),
                ],
              ),
            ],
            if (account.pinnedServerId case final id?)
              CloudFootnote(
                context.l10n.providerUiPinnedHelp(
                  ledger.byId(id)?.name ?? context.l10n.cloudLocalRecord,
                ),
              ),
            if (!associationsOnly)
              AppSection(
                footer: context.l10n.cloudScopeNotice,
                children: [
                  CloudValue(
                    context.l10n.cloudTemplateLabel,
                    cloudProviderName(account.provider),
                  ),
                  CloudValue(context.l10n.cloudPanelAddress, account.endpoint),
                  AppKeyValueRow(
                    label: context.l10n.cloudReadStatus,
                    valueWidget: StatusPill(
                      cloudAccountStatus(account, l10n: context.l10n),
                      tone: account.lastFailure == null
                          ? AppTone.green
                          : AppTone.red,
                    ),
                  ),
                  CloudValue(
                    context.l10n.cloudLastAttempt,
                    account.lastAttemptAt == null
                        ? context.l10n.cloudNoAttempts
                        : cloudTime(account.lastAttemptAt!),
                  ),
                  CloudValue(
                    context.l10n.cloudVerifiedScope,
                    account.authScope == AdapterAuthScope.unknown
                        ? context.l10n.providerUiUnknownScope
                        : account.provider.isSingleInstance
                        ? context.l10n.cloudV1Scope
                        : context.l10n.cloudV2Scope(
                            account.remoteAccountId?.toString() ??
                                context.l10n.cloudPowerUnknown,
                          ),
                  ),
                  CloudValue(
                    context.l10n.cloudAppCapabilities,
                    context.l10n.cloudReadCapabilities,
                  ),
                  CloudValue(
                    context.l10n.cloudAuthorizationStorage,
                    context.l10n.cloudSecureStorageInfo,
                  ),
                ],
              ),
            AppSection(
              header: context.l10n.cloudLinkedCount(bindings.length),
              children: [
                if (bindings.isEmpty)
                  AppRow(title: context.l10n.cloudNoLinkedInstances),
                for (final binding in bindings)
                  AppRow(
                    icon: Icons.dns_outlined,
                    iconColor: AppTints.slate,
                    title: context.l10n.cloudRecordWithState(
                      ledger.byId(binding.serverId)?.name ??
                          context.l10n.cloudLocalRecord,
                      ledger.byId(binding.serverId)?.archived == true
                          ? context.l10n.cloudArchivedSuffix
                          : '',
                    ),
                    subtitle: context.l10n.cloudBindingWithTime(
                      cloudBindingSummary(binding, l10n: context.l10n),
                      cloudTime(binding.observedAt),
                    ),
                    chevron: ledger.byId(binding.serverId) != null,
                    onTap: ledger.byId(binding.serverId) == null
                        ? null
                        : () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ServerDetail(
                                controller: ledger,
                                id: binding.serverId,
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          ],
        ],
      );
    },
  );
}

class _CloudAccountMenuButton extends StatefulWidget {
  const _CloudAccountMenuButton({required this.ledger, required this.account});
  final LedgerController ledger;
  final CloudAccount account;
  @override
  State<_CloudAccountMenuButton> createState() =>
      _CloudAccountMenuButtonState();
}

class _CloudAccountMenuButtonState extends State<_CloudAccountMenuButton> {
  bool opening = false;
  @override
  Widget build(BuildContext context) => AppNavButton.icon(
    Icons.more_horiz,
    key: const ValueKey('cloud-instance-menu'),
    tooltip: context.l10n.serverMoreActions,
    onPressed: opening
        ? null
        : () async {
            setState(() => opening = true);
            try {
              await cloudAccountMenu(context, widget.ledger, widget.account);
            } finally {
              if (mounted) setState(() => opening = false);
            }
          },
  );
}

class _CloudRenameDialog extends StatefulWidget {
  const _CloudRenameDialog({required this.alias});
  final String alias;
  @override
  State<_CloudRenameDialog> createState() => _CloudRenameDialogState();
}

class _CloudRenameDialogState extends State<_CloudRenameDialog> {
  late final field = TextEditingController(text: widget.alias);
  LocalizedMessage? error;
  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  void save() {
    final value = field.text.trim();
    if (value.isEmpty || value.length > 80) {
      setState(() => error = LocalizedText((l10n) => l10n.cloudAliasRange));
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => CupertinoAlertDialog(
    title: Text(context.l10n.cloudRenameAccount),
    content: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CloudPromptField(
            fieldKey: const ValueKey('cloud-rename'),
            controller: field,
            hint: context.l10n.cloudAliasLabel,
            onSubmitted: (_) => save(),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                error!.messageFor(context.l10n),
                style: TextStyle(fontSize: 13, color: context.palette.red),
              ),
            ),
        ],
      ),
    ),
    actions: [
      CupertinoDialogAction(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cloudCancel),
      ),
      CupertinoDialogAction(
        isDefaultAction: true,
        onPressed: save,
        child: Text(context.l10n.cloudSaveName),
      ),
    ],
  );
}
