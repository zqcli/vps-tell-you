import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/form_feedback.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../servers/ledger_controller.dart';
import '../servers/server_detail.dart';
import '../servers/server_resource_fields.dart';
import '../servers/server_resources.dart';
import 'cloud_controller.dart';
import 'cloud_models.dart';
import 'cloud_provider_definition.dart';
import 'cloud_widgets.dart';

Future<void> _reloadLedger(LedgerController ledger) =>
    ledger.refreshAfterCloudCommit();

void _cloudMessage(BuildContext context, Object message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Builder(
          builder: (context) => Text(localizedText(message, context.l10n)),
        ),
      ),
    );

class CloudAccountsPage extends StatefulWidget {
  const CloudAccountsPage({super.key, required this.ledger});
  final LedgerController ledger;
  @override
  State<CloudAccountsPage> createState() => _CloudAccountsPageState();
}

class _CloudAccountsPageState extends State<CloudAccountsPage> {
  CloudController get cloud => widget.ledger.cloud;
  bool opening = false;
  @override
  void initState() {
    super.initState();
    unawaited(cloud.initialize());
  }

  Future<void> add() async {
    if (opening) return;
    opening = true;
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CloudTemplatesPage(ledger: widget.ledger),
        ),
      );
    } finally {
      opening = false;
    }
  }

  Future<void> menu(CloudAccount account) async {
    if (opening) return;
    opening = true;
    try {
      await cloudAccountMenu(context, widget.ledger, account);
    } finally {
      opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: cloud,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.cloudAccounts),
        actions: [
          IconButton(
            tooltip: context.l10n.cloudAddAccount,
            onPressed: cloud.busy || cloud.needsReload ? null : add,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          LedgerBadge(context.l10n.cloudPanelReadBadge),
          const SizedBox(height: 16),
          Text(
            context.l10n.cloudManageConnections,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          InfoNote(context.l10n.cloudConnectionsInfo),
          if (cloud.needsReload) ...[
            CloudNotice(context.l10n.cloudMetadataIncomplete, error: true),
            OutlinedButton(
              onPressed: cloud.busy ? null : cloud.reload,
              child: Text(context.l10n.cloudReloadMetadata),
            ),
          ] else if (cloud.localizedError != null)
            CloudNotice(cloud.localizedError!, error: true),
          if (cloud.cleanupPending) ...[
            CloudNotice(context.l10n.cloudCleanupNotice, error: true),
            OutlinedButton(
              onPressed: cloud.busy ? null : cloud.retryCleanup,
              child: Text(context.l10n.cloudRetryCleanup),
            ),
          ],
          if (cloud.accounts.isEmpty && !cloud.needsReload)
            LedgerCard(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Icon(
                    Icons.cloud_outlined,
                    size: 44,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.cloudFirstAccount,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  InfoNote(context.l10n.cloudFirstAccountInfo),
                  FilledButton.icon(
                    onPressed: cloud.busy ? null : add,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.cloudChooseTemplate),
                  ),
                ],
              ),
            ),
          for (final account in cloud.accounts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LedgerCard(
                padding: EdgeInsets.zero,
                child: InkWell(
                  key: ValueKey('cloud-account-${account.id}'),
                  onTap: () => menu(account),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.cloud_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.alias,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                context.l10n.cloudProviderLinks(
                                  cloudProviderName(account.provider),
                                  cloud.bindings
                                      .where((b) => b.accountId == account.id)
                                      .length,
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                account.endpoint,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              LedgerBadge(
                                cloudAccountStatus(account, l10n: context.l10n),
                                warning: account.lastFailure != null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.more_vert,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (cloud.accounts.isNotEmpty)
            OutlinedButton.icon(
              onPressed: cloud.busy || cloud.needsReload ? null : add,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.cloudAddAccount),
            ),
          InfoNote(context.l10n.cloudReadOnlyBoundary),
        ],
      ),
    ),
  );
}

class CloudTemplatesPage extends StatefulWidget {
  const CloudTemplatesPage({super.key, required this.ledger});
  final LedgerController ledger;
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
        builder: (_) =>
            CloudAuthorizationPage(ledger: widget.ledger, provider: provider),
      ),
    );
    opening = false;
    if (saved == true && context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.cloudAddAccount)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const CloudSteps(1),
        Text(
          context.l10n.cloudChooseTemplate,
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
        ),
        InfoNote(context.l10n.cloudTemplateInfo),
        for (final provider in CloudProvider.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: LedgerCard(
              padding: EdgeInsets.zero,
              child: SettingRow(
                icon: Icons.cloud_outlined,
                title: cloudProviderName(provider),
                subtitle: CloudProviderDefinition.of(provider)
                    .templateInfo(context.l10n),
                onTap: () => choose(context, provider),
              ),
            ),
          ),
        InfoNote(context.l10n.cloudSupportedPanels),
      ],
    ),
  );
}

class CloudAuthorizationPage extends StatefulWidget {
  const CloudAuthorizationPage({
    super.key,
    required this.ledger,
    required this.provider,
    this.existing,
  });
  final LedgerController ledger;
  final CloudProvider provider;
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
  CloudProviderDefinition get definition =>
      CloudProviderDefinition.of(widget.provider);
  bool get singleInstance => widget.provider.isSingleInstance;
  bool reading = false, navigating = false;
  int serial = 0;
  LocalizedMessage? error;
  CloudEndpoint? get parsedEndpoint {
    try {
      return definition.parseEndpoint(endpoint.text);
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
      final credentials = definition.createCredentials(
        key: keyField.text,
        hash: hashField.text,
        token: token.text,
      );
      verified = await cloud.verifyConnection(
        provider: widget.provider,
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
    if (saved == true) {
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
  ) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: TextFormField(
      key: ValueKey(fieldKey),
      controller: controller,
      enabled: !reading && !kIsWeb,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      keyboardType: TextInputType.visiblePassword,
      decoration: InputDecoration(labelText: label, errorMaxLines: 5),
      validator: (value) => value == null || value.isEmpty
          ? context.l10n.cloudRequiredField(label)
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) cancel(update: false);
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? context.l10n.cloudConnectProvider(
                  cloudProviderName(widget.provider),
                )
              : context.l10n.cloudReauthorize,
        ),
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const CloudSteps(2),
            LedgerCard(
              child: Text(
                '${cloudProviderName(widget.provider)} · ${singleInstance ? context.l10n.cloudSingleVpsApi : context.l10n.cloudUserAccountApi}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (kIsWeb)
              CloudNotice(context.l10n.cloudWebPreviewNotice, error: true),
            const SizedBox(height: 20),
            TextFormField(
              key: const ValueKey('cloud-alias'),
              controller: alias,
              enabled: !reading,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: context.l10n.cloudAliasLabel,
                errorMaxLines: 5,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.l10n.cloudAliasRequired
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('cloud-endpoint'),
              controller: endpoint,
              enabled: !reading,
              readOnly: widget.existing != null,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: context.l10n.cloudEndpointLabel,
                errorMaxLines: 6,
                hintText: definition.endpointHint,
              ),
              onChanged: (_) => setState(() => error = null),
              validator: (_) => parsedEndpoint == null
                  ? definition.endpointValidation(context.l10n)
                  : null,
            ),
            InfoNote(definition.endpointInfo(context.l10n)),
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
            if (widget.existing != null)
              InfoNote(context.l10n.cloudEndpointIdentityInfo),
            if (definition.credentialKind == CloudCredentialKind.keyHash) ...[
              secretField(keyField, 'API Key', 'cloud-key'),
              secretField(hashField, 'API Hash', 'cloud-hash'),
            ] else
              secretField(token, 'API Token', 'cloud-token'),
            InfoNote(definition.credentialsInfo(context.l10n)),
            if (singleInstance && widget.existing != null)
              CloudNotice(context.l10n.cloudV1ReauthorizationInfo, error: true),
            if (!singleInstance && widget.existing != null)
              InfoNote(context.l10n.cloudV2ReauthorizationInfo),
            CloudNotice(context.l10n.cloudVerifyScopeInfo),
            if (error != null) CloudNotice(error!, error: true),
            if (reading) ...[
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
              InfoNote(context.l10n.cloudVerifyingInfo),
              OutlinedButton(
                key: const ValueKey('cancel-cloud-verify'),
                onPressed: cancel,
                child: Text(context.l10n.cloudCancelVerification),
              ),
            ] else
              FilledButton.icon(
                key: const ValueKey('verify-cloud'),
                onPressed: kIsWeb ? null : verify,
                icon: const Icon(Icons.link),
                label: Text(context.l10n.cloudVerifyRead),
              ),
            InfoNote(context.l10n.cloudCredentialMemoryInfo),
          ],
        ),
      ),
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
  CloudAccount? get account =>
      widget.verification?.existingAccount ?? widget.inventory?.account;
  CloudProviderDefinition get definition =>
      CloudProviderDefinition.of(snapshot.provider);
  bool get singleInstance => snapshot.provider.isSingleInstance;
  bool get rebind =>
      singleInstance && widget.verification?.existingAccount != null;
  final selected = <String>{};
  final displayName = TextEditingController();
  final resourceForm = GlobalKey<ServerResourceFieldsState>();
  final singleSelection = GlobalKey();
  bool saving = false,
      confirmRebind = false,
      committed = false,
      expired = false;
  LocalizedMessage? error;
  String keyFor(CloudInstance instance) =>
      widget.verification?.keyFor(instance) ??
      widget.inventory!.keyFor(instance);
  CloudBinding? linked(CloudInstance instance) => rebind
      ? null
      : cloud.bindings
            .where(
              (b) =>
                  b.accountId == account?.id &&
                  b.instanceKey == keyFor(instance),
            )
            .firstOrNull;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.verification != null &&
        !committed &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      cloud.cancelVerification();
      setState(() {
        expired = true;
        error = LocalizedText((l10n) => l10n.cloudAuthorizationExpired);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.verification != null && !committed) {
      cloud.cancelVerification(notify: false);
    }
    displayName.dispose();
    super.dispose();
  }

  Future<void> save({bool accountOnly = false}) async {
    if (saving || expired || (rebind && !confirmRebind)) return;
    if (!accountOnly && selected.isEmpty) return;
    final ServerResources? resources;
    if (singleInstance && !accountOnly && selected.isNotEmpty) {
      final invalid = <FormFieldState<Object?>>{};
      resources = resourceForm.currentState?.validateAndRead(
        invalidFields: invalid,
      );
      if (resources == null) {
        revealFirstInvalidField(invalid);
        setState(
          () => error = LocalizedText((l10n) => l10n.cloudResourcesIncomplete),
        );
        return;
      }
    } else {
      resources = null;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      error = null;
    });
    final name = displayName.text.trim();
    final picked = accountOnly ? <String>{} : Set<String>.of(selected);
    final ok = widget.verification != null
        ? await cloud.saveAccount(
            widget.verification!,
            alias: widget.alias!,
            selectedInstanceKeys: picked,
            confirmV1Rebind: confirmRebind,
            v1DisplayName: name.isEmpty ? null : name,
            v1Resources: resources,
          )
        : await cloud.importInstances(
            widget.inventory!,
            selectedInstanceKeys: picked,
            v1DisplayName: name.isEmpty ? null : name,
            v1Resources: resources,
          );
    if (ok) {
      committed = true;
      await _reloadLedger(widget.ledger);
    }
    if (!mounted) return;
    setState(() {
      saving = false;
      error = ok
          ? null
          : cloud.localizedError ??
                LocalizedText((l10n) => l10n.cloudSaveFailed);
    });
    if (ok) {
      _cloudMessage(
        context,
        picked.isEmpty
            ? LocalizedText((l10n) => l10n.cloudAccountSavedOnly)
            : LocalizedText((l10n) => l10n.cloudInstancesSaved),
      );
      Navigator.pop(context, true);
    }
  }

  bool get needsSingleSelection =>
      singleInstance &&
      selected.isEmpty &&
      snapshot.instances.isNotEmpty &&
      linked(snapshot.instances.single) == null;

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

  Widget _importBody(List<Widget> children) {
    // Single-instance APIs own a bounded nested completion form. Eagerly mount
    // that form so validation and edits survive any scroll.
    // V2 inventories may be large and continue using lazy list children.
    return singleInstance
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          )
        : ListView(padding: const EdgeInsets.all(20), children: children);
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(title: Text(context.l10n.cloudChooseInstances)),
      body: _importBody([
        const CloudSteps(3),
        CloudNotice(
          context.l10n.cloudInventoryComplete(
            snapshot.instances.length,
            cloudTime(snapshot.completedAt),
            widget.verification != null
                ? context.l10n.cloudAuthorizationUnsaved
                : '',
          ),
        ),
        Text(
          widget.alias ?? account!.alias,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        SelectableText(
          widget.verification?.endpoint.toString() ?? account!.endpoint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        if (snapshot.instances.isEmpty)
          LedgerCard(
            child: Text(
              widget.verification != null
                  ? context.l10n.cloudEmptyVerification
                  : context.l10n.cloudEmptyInventory,
            ),
          ),
        for (final instance in snapshot.instances)
          Padding(
            key: singleInstance ? singleSelection : null,
            padding: const EdgeInsets.only(bottom: 12),
            child: LedgerCard(
              padding: EdgeInsets.zero,
              child: CheckboxListTile(
                key: ValueKey('cloud-select-${keyFor(instance)}'),
                value:
                    linked(instance) != null ||
                    selected.contains(keyFor(instance)),
                onChanged: saving || expired || linked(instance) != null
                    ? null
                    : (checked) => setState(() {
                        if (checked == true) {
                          selected.add(keyFor(instance));
                        } else {
                          selected.remove(keyFor(instance));
                        }
                      }),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                title: Text(
                  singleInstance
                      ? context.l10n.cloudV1Instance
                      : instance.name ??
                            context.l10n.cloudInstanceFallback(
                              instance.serverId?.toString() ??
                                  context.l10n.cloudPowerUnknown,
                            ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (linked(instance) != null)
                      LedgerBadge(context.l10n.cloudAlreadyLinked),
                    if (!singleInstance)
                      Text(
                        context.l10n.cloudProjectInstance(
                          (instance.projectName ?? instance.projectId)
                                  ?.toString() ??
                              context.l10n.cloudPowerUnknown,
                          instance.serverId?.toString() ??
                              context.l10n.cloudPowerUnknown,
                        ),
                      ),
                    Text(
                      singleInstance
                          ? context.l10n.cloudV1Identity
                          : [
                              instance.ipv4,
                              instance.ipv6,
                            ].whereType<String>().join(' / ').isEmpty
                          ? context.l10n.cloudIpNotProvided
                          : [
                              instance.ipv4,
                              instance.ipv6,
                            ].whereType<String>().join(' / '),
                    ),
                    Text(
                      context.l10n.cloudPowerLastRead(
                        cloudPowerLabel(instance.power, l10n: context.l10n),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (singleInstance) ...[
          if (needsSingleSelection)
            InfoNote(context.l10n.cloudSelectBeforeComplete),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey('cloud-v1-name'),
            controller: displayName,
            enabled: !saving && !expired,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: context.l10n.cloudLocalDisplayName,
              helperText: context.l10n.cloudLocalNameInfo,
              helperMaxLines: 4,
            ),
          ),
          if (snapshot.instances.isNotEmpty &&
              linked(snapshot.instances.single) == null)
            ServerResourceFields(
              key: resourceForm,
              enabled: !saving && !expired,
              observed: {
                'ip':
                    snapshot.instances.single.ipv4 ??
                    snapshot.instances.single.ipv6,
                'hostname': snapshot.instances.single.hostname,
                'diskBytes': snapshot.instances.single.diskBytes,
                'trafficBytes': snapshot.instances.single.trafficBytes,
                'trafficUnlimited': snapshot.instances.single.trafficUnlimited,
                'ramBytes': snapshot.instances.single.ramBytes,
                'vcpu': snapshot.instances.single.vcpu,
              },
            ),
          if (definition.resourceCompletionInfo(context.l10n) case final info?)
            InfoNote(info),
        ],
        if (rebind) ...[
          CloudNotice(context.l10n.cloudRebindWarning, error: true),
          CheckboxListTile(
            key: const ValueKey('cloud-confirm-rebind'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: confirmRebind,
            onChanged: saving || expired
                ? null
                : (value) => setState(() => confirmRebind = value ?? false),
            title: Text(context.l10n.cloudConfirmRebind),
          ),
        ],
        InfoNote(
          context.l10n.cloudImportBoundary(
            singleInstance
                ? context.l10n.cloudV1Deduplication
                : context.l10n.cloudV2Deduplication,
          ),
        ),
        if (error != null) CloudNotice(error!, error: true),
        if (needsSingleSelection && !saving && !expired)
          TextButton.icon(
            key: const ValueKey('cloud-return-to-instance'),
            onPressed: revealSingleSelection,
            icon: const Icon(Icons.arrow_upward),
            label: Text(context.l10n.cloudReturnSelect),
          ),
        FilledButton.icon(
          key: const ValueKey('cloud-import-submit'),
          onPressed:
              saving ||
                  expired ||
                  selected.isEmpty ||
                  (rebind && !confirmRebind)
              ? null
              : save,
          icon: const Icon(Icons.download_outlined),
          label: Text(
            saving
                ? context.l10n.cloudSaving
                : selected.isEmpty
                ? context.l10n.cloudNoneSelected
                : widget.verification == null
                ? context.l10n.cloudImportCount(selected.length)
                : context.l10n.cloudSaveImportCount(selected.length),
          ),
        ),
        if (widget.verification != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey('cloud-save-only'),
            onPressed: saving || expired || (rebind && !confirmRebind)
                ? null
                : () => save(accountOnly: true),
            child: Text(
              widget.verification!.existingAccount == null
                  ? context.l10n.cloudSaveOnly
                  : rebind
                  ? context.l10n.cloudUpdateUnlink
                  : context.l10n.cloudUpdateOnly,
            ),
          ),
        ],
        if (expired && !saving)
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cloudReturnVerify),
          ),
        if (saving) InfoNote(context.l10n.cloudSavingInfo),
      ]),
    ),
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

  Future<void> read() async {
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
    if (inventory != null && widget.importAfterRead) {
      final imported = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CloudImportPage(ledger: widget.ledger, inventory: inventory),
        ),
      );
      if (mounted) Navigator.pop(context, imported);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) cancel(update: false);
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.importAfterRead
              ? context.l10n.cloudReadImportable
              : context.l10n.cloudRefreshAccount,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.account.alias,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
          ),
          SelectableText(widget.account.endpoint),
          if (reading) ...[
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            ),
            InfoNote(context.l10n.cloudReadingInfo),
            OutlinedButton(
              onPressed: cancel,
              child: Text(context.l10n.cloudCancelRead),
            ),
          ],
          if (error != null) ...[
            CloudNotice(error!, error: true),
            OutlinedButton(
              onPressed: read,
              child: Text(context.l10n.cloudReadAgain),
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
            InfoNote(context.l10n.cloudReadCompleteInfo),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cloudDone),
            ),
          ],
        ],
      ),
    ),
  );
}

Future<void> cloudAccountMenu(
  BuildContext context,
  LedgerController ledger,
  CloudAccount account,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account.alias,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            InfoNote(
              '${cloudProviderName(account.provider)} · ${account.endpoint}',
            ),
            for (final row in <(String, IconData, String)>[
              ('detail', Icons.info_outline, context.l10n.cloudViewDetails),
              ('rename', Icons.edit_outlined, context.l10n.cloudRenameAccount),
              (
                'reauthorize',
                Icons.key_outlined,
                context.l10n.cloudReauthorize,
              ),
              (
                'import',
                Icons.download_outlined,
                context.l10n.cloudContinueImport,
              ),
              ('servers', Icons.dns_outlined, context.l10n.cloudLinkedServers),
              ('refresh', Icons.refresh, context.l10n.cloudRefreshAccount),
              ('unbind', Icons.link_off, context.l10n.cloudUnlinkAccount),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  row.$2,
                  color: row.$1 == 'unbind'
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
                title: Text(row.$3),
                onTap: () => Navigator.pop(context, row.$1),
              ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || action == null) return;
  final cloud = ledger.cloud;
  final current = cloud.accounts.where((a) => a.id == account.id).firstOrNull;
  if (current == null) return;
  if (action == 'detail' || action == 'servers') {
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
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CloudAuthorizationPage(
          ledger: ledger,
          provider: current.provider,
          existing: current,
        ),
      ),
    );
  } else if (action == 'rename') {
    final name = await showDialog<String>(
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
    final ok = await confirmAction(
      context,
      title: LocalizedText((l10n) => l10n.cloudUnlinkAccountTitle),
      message: LocalizedText(
        (l10n) => l10n.cloudUnlinkAccountMessage(
          current.alias,
          current.provider.isSingleInstance
              ? l10n.cloudRevokeV1
              : l10n.cloudRevokeV2,
        ),
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
    listenable: ledger.cloud,
    builder: (context, _) {
      final account = ledger.cloud.accounts
          .where((a) => a.id == accountId)
          .firstOrNull;
      final bindings = ledger.cloud.bindings
          .where((b) => b.accountId == accountId)
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: Text(
            associationsOnly
                ? context.l10n.cloudLinkedServers
                : context.l10n.cloudAccountDetails,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (account == null)
              CloudNotice(context.l10n.cloudAccountRemovedNotice)
            else ...[
              Text(
                account.alias,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!associationsOnly) ...[
                const SizedBox(height: 18),
                LedgerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CloudValue(
                        context.l10n.cloudTemplateLabel,
                        cloudProviderName(account.provider),
                      ),
                      CloudValue(
                        context.l10n.cloudPanelAddress,
                        account.endpoint,
                      ),
                      CloudValue(
                        context.l10n.cloudReadStatus,
                        cloudAccountStatus(account, l10n: context.l10n),
                      ),
                      CloudValue(
                        context.l10n.cloudLastAttempt,
                        account.lastAttemptAt == null
                            ? context.l10n.cloudNoAttempts
                            : cloudTime(account.lastAttemptAt!),
                      ),
                      CloudValue(
                        context.l10n.cloudVerifiedScope,
                        account.provider.isSingleInstance
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
                ),
                InfoNote(context.l10n.cloudScopeNotice),
              ],
              SectionTitle(context.l10n.cloudLinkedCount(bindings.length)),
              if (bindings.isEmpty)
                LedgerCard(child: Text(context.l10n.cloudNoLinkedInstances)),
              for (final binding in bindings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: LedgerCard(
                    padding: EdgeInsets.zero,
                    child: SettingRow(
                      icon: Icons.dns_outlined,
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
                  ),
                ),
            ],
          ],
        ),
      );
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

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(context.l10n.cloudRenameAccount),
    content: TextField(
      key: const ValueKey('cloud-rename'),
      controller: field,
      maxLength: 80,
      autofocus: true,
      decoration: InputDecoration(
        labelText: context.l10n.cloudAliasLabel,
        errorText: error?.messageFor(context.l10n),
        errorMaxLines: 5,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cloudCancel),
      ),
      FilledButton(
        onPressed: () {
          final value = field.text.trim();
          if (value.isEmpty || value.length > 80) {
            setState(
              () => error = LocalizedText((l10n) => l10n.cloudAliasRange),
            );
            return;
          }
          Navigator.pop(context, value);
        },
        child: Text(context.l10n.cloudSaveName),
      ),
    ],
  );
}
