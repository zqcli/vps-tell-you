import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import '../core/ui/ui.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../servers/ledger_controller.dart';
import 'cloud_account.dart';
import 'cloud_models.dart';
import 'cloud_widgets.dart';
import 'provider_record.dart';

/// Edits one existing server's local association from saved observations only.
/// Returns true after a successful change. Opening or reloading this page never
/// requests cloud credentials, creates an adapter, or refreshes a remote API.
class ServerCloudBindingPage extends StatefulWidget {
  const ServerCloudBindingPage({
    super.key,
    required this.ledger,
    required this.serverId,
  });
  final LedgerController ledger;
  final String serverId;

  @override
  State<ServerCloudBindingPage> createState() => _ServerCloudBindingPageState();
}

class _ServerCloudBindingPageState extends State<ServerCloudBindingPage> {
  ServerCloudBindingOptions? _options;
  String? _accountId;
  LocalizedMessage? _error;
  CloudBindingChoice? _selected;
  bool _loading = false,
      _saving = false,
      _confirming = false,
      _expired = false,
      _committed = false,
      _disposed = false;

  bool get _busy =>
      _loading ||
      _saving ||
      _confirming ||
      widget.ledger.busy ||
      widget.ledger.cloud.busy;
  bool get _blocked =>
      _busy ||
      _expired ||
      _committed ||
      widget.ledger.refreshFailed ||
      widget.ledger.cloud.needsReload ||
      _options?.server.archived == true ||
      _options?.server.isDemo == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _loading = true;
      _error = null;
      _options = null;
      _selected = null;
    });
    ServerCloudBindingOptions? loaded;
    try {
      if (widget.ledger.refreshFailed) {
        await widget.ledger.refresh();
      } else {
        // Provider confirmation is local metadata too. Read it again even
        // when the previous metadata read succeeded, without invoking an API.
        await widget.ledger.cloud.reload();
      }
      if (!widget.ledger.refreshFailed && !widget.ledger.cloud.needsReload) {
        loaded = await widget.ledger.cloud.serverBindingOptions(
          widget.serverId,
        );
      }
    } catch (_) {
      // Storage exceptions may contain paths or private data. Use a closed UI
      // message, and never attempt another write against this incomplete read.
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _options = loaded;
      _selected = loaded?.current;
      final accounts = _candidateAccounts;
      final currentAccount = accounts
          .where((account) => account.id == loaded?.current?.accountId)
          .firstOrNull;
      _accountId =
          currentAccount?.id ??
          accounts
              .where((account) => _accountRestriction(account) == null)
              .firstOrNull
              ?.id ??
          accounts.firstOrNull?.id;
      _expired = loaded == null;
      if (loaded == null) {
        _error =
            widget.ledger.cloud.localizedError ??
            LocalizedText((l10n) => l10n.cloudBindingReadFailed);
      }
    });
    if (loaded != null && _committed && mounted) {
      Navigator.pop(context, true);
    }
  }

  String _accountName(String id, {AppLocalizations? l10n}) {
    final strings = l10n ?? context.l10n;
    final account = _options?.accounts.where((a) => a.id == id).firstOrNull;
    return account == null
        ? strings.cloudAccounts
        : '${account.alias} · ${account.endpoint}';
  }

  String _instanceName(CloudBindingChoice choice, {AppLocalizations? l10n}) {
    final strings = l10n ?? context.l10n;
    final observation = choice.observation;
    for (final value in [observation.name, observation.hostname]) {
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return observation.serverId == null
        ? strings.cloudSingleAccountInstance
        : strings.cloudInstanceFallback(observation.serverId.toString());
  }

  bool _same(CloudBindingChoice? a, CloudBindingChoice? b) =>
      a?.accountId == b?.accountId && a?.instanceKey == b?.instanceKey;

  ProviderRecord? get _serverProvider => widget.ledger.cloud.providers
      .where((provider) => provider.id == _options?.server.providerId)
      .firstOrNull;

  List<CloudAccount> get _candidateAccounts {
    final provider = _serverProvider;
    if (provider == null || provider.needsReview) return const [];
    return _options?.accounts
            .where((account) => account.businessProviderId == provider.id)
            .toList(growable: false) ??
        const [];
  }

  LocalizedMessage? _accountRestriction(CloudAccount account) {
    final provider = _serverProvider;
    if (_options?.server.providerId == null) {
      return LocalizedText((l10n) => l10n.providerBindingAssignFirst);
    }
    if (provider == null) {
      return LocalizedText((l10n) => l10n.providerUiUnavailable);
    }
    if (provider.needsReview) {
      return LocalizedText((l10n) => l10n.providerReviewRequired);
    }
    if (account.businessProviderId != provider.id) {
      return LocalizedText((l10n) => l10n.adapterProviderMismatch);
    }
    if (account.authScope != adapterScope(account.adapterType)) {
      return LocalizedText((l10n) => l10n.adapterScopeUnavailable);
    }
    if (account.authScope == AdapterAuthScope.singleDevice &&
        account.pinnedServerId != null &&
        account.pinnedServerId != widget.serverId) {
      return LocalizedText((l10n) => l10n.adapterSingletonPinned);
    }
    if (account.lastFailure != null) {
      return LocalizedText((l10n) => l10n.cloudFailedRefresh);
    }
    return null;
  }

  CloudAccount? _accountFor(CloudBindingChoice choice) => _options?.accounts
      .where((account) => account.id == choice.accountId)
      .firstOrNull;

  bool _available(CloudBindingChoice choice) =>
      !choice.stale &&
      !choice.missing &&
      (choice.serverId == null || choice.serverId == widget.serverId) &&
      _accountFor(choice) != null &&
      _accountRestriction(_accountFor(choice)!) == null;

  String _scopeLabel(CloudAccount account) => switch (account.authScope) {
    AdapterAuthScope.singleDevice => context.l10n.providerUiSingleScope,
    AdapterAuthScope.account => context.l10n.providerUiAccountScope,
    AdapterAuthScope.unknown => context.l10n.providerUiUnknownScope,
  };

  Future<void> _save({bool unlink = false}) async {
    final options = _options;
    final choice = unlink ? null : _selected;
    if (_blocked ||
        options == null ||
        (!unlink && (choice == null || !_available(choice))) ||
        _same(options.current, choice)) {
      return;
    }
    if (options.current != null) {
      setState(() => _confirming = true);
      final confirmed = await showAppConfirm(
        context,
        title: LocalizedText(
          (l10n) => unlink
              ? l10n.cloudUnlinkServerTitle
              : l10n.cloudChangeServerTitle,
        ),
        message: LocalizedText(
          (l10n) => l10n.cloudChangeLinkMessage(
            options.server.name,
            _accountName(options.current!.accountId, l10n: l10n),
            _instanceName(options.current!, l10n: l10n),
            unlink
                ? ''
                : l10n.cloudReplacementLink(
                    _accountName(choice!.accountId, l10n: l10n),
                    _instanceName(choice, l10n: l10n),
                  ),
          ),
        ),
        action: LocalizedText(
          (l10n) =>
              unlink ? l10n.cloudOnlyUnlinkThis : l10n.cloudConfirmChangeLink,
        ),
        dangerous: unlink,
      );
      if (!mounted) return;
      setState(() => _confirming = false);
      if (!confirmed || _blocked) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.ledger.cloud.setServerBinding(
      options,
      choice: choice,
      isCancelled: () => _disposed,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _committed = saved;
      _expired = !saved;
      _error = widget.ledger.cloud.localizedError;
    });
    if (!saved) return;
    if (widget.ledger.cloud.needsReload) return;
    showAppToast(
      context,
      localizedText(
        unlink
            ? LocalizedText((l10n) => l10n.cloudServerUnlinked)
            : LocalizedText((l10n) => l10n.cloudBindingSaved),
        context.l10n,
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger,
    builder: (context, _) {
      final options = _options;
      final current = options?.current;
      final provider = _serverProvider;
      final accounts = _candidateAccounts;
      final selectedAccount = accounts
          .where((account) => account.id == _accountId)
          .firstOrNull;
      final accountRestriction = selectedAccount == null
          ? null
          : _accountRestriction(selectedAccount);
      final choices = options?.choices
          .where((choice) => choice.accountId == selectedAccount?.id)
          .toList();
      return PopScope<bool>(
        canPop: !_saving,
        child: AppScaffold(
          title: context.l10n.cloudLinkPanelAccount,
          largeTitle: false,
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CupertinoActivityIndicator()),
              ),
            if (_committed) CloudNotice(context.l10n.cloudBindingCommitted),
            if (_error != null) CloudNotice(_error!, error: true),
            if (widget.ledger.refreshFailed)
              CloudNotice(context.l10n.cloudLedgerNotUpdated, error: true),
            AppSection(
              topSpacing: 12,
              footer: options == null
                  ? context.l10n.cloudLocalBindingInfo
                  : null,
              children: [
                AppRow(
                  key: const ValueKey('server-cloud-reload'),
                  icon: Icons.refresh,
                  iconColor: AppTints.blue,
                  title: context.l10n.cloudReloadLocal,
                  enabled: !_busy,
                  onTap: _busy ? null : _load,
                ),
              ],
            ),
            if (options != null) ...[
              AppSection(
                header: context.l10n.serverDetails,
                footer: context.l10n.cloudLocalBindingInfo,
                children: [
                  AppRow(
                    leading: ProviderAvatar(name: provider?.name),
                    title: options.server.name,
                    subtitle: provider == null
                        ? context.l10n.providerUiUnspecified
                        : provider.needsReview
                        ? context.l10n.providerPendingName(provider.name)
                        : provider.name,
                  ),
                ],
              ),
              if (options.server.providerId == null)
                CloudNotice(context.l10n.providerBindingAssignFirst)
              else if (provider == null)
                CloudNotice(context.l10n.providerUiUnavailable, error: true)
              else if (provider.needsReview)
                CloudNotice(
                  context.l10n.providerReviewRequired,
                  tone: AppTone.amber,
                ),
              if (options.server.archived || options.server.isDemo)
                CloudNotice(context.l10n.cloudBindingReadOnly, error: true),
              if (current != null)
                AppSection(
                  header: context.l10n.cloudCurrentLink,
                  children: [
                    AppRow(
                      icon: Icons.link,
                      iconColor: AppTints.purple,
                      title: _accountName(current.accountId),
                      subtitle: _instanceName(current),
                    ),
                    AppRow(
                      key: const ValueKey('server-cloud-unbind'),
                      center: true,
                      destructive: true,
                      title: context.l10n.cloudUnlinkThis,
                      enabled: !_blocked,
                      onTap: _blocked ? null : () => _save(unlink: true),
                    ),
                  ],
                ),
              AppSection(
                header: context.l10n.providerUiChooseInstance,
                footer: provider != null && !provider.needsReview
                    ? context.l10n.providerUiInstanceChoiceHelp
                    : null,
                children: [
                  if (provider != null &&
                      !provider.needsReview &&
                      accounts.isEmpty)
                    AppRow(title: context.l10n.cloudNoSavedAccounts),
                  for (final account in accounts)
                    AppRow(
                      key: ValueKey('server-cloud-account-${account.id}'),
                      icon: Icons.cloud_outlined,
                      iconColor: AppTints.purple,
                      title: account.alias,
                      subtitle: [
                        cloudProviderName(account.adapterType),
                        _scopeLabel(account),
                        account.endpoint,
                        if (_accountRestriction(account) case final reason?)
                          localizedText(reason, context.l10n),
                      ].join('\n'),
                      trailing: _accountId == account.id
                          ? Icon(
                              Icons.check_rounded,
                              size: 22,
                              color: context.palette.primary,
                            )
                          : null,
                      enabled:
                          !_blocked && _accountRestriction(account) == null,
                      onTap: _blocked || _accountRestriction(account) != null
                          ? null
                          : () => setState(() {
                              _accountId = account.id;
                              _selected = current?.accountId == account.id
                                  ? current
                                  : null;
                            }),
                    ),
                ],
              ),
              if (selectedAccount != null)
                AppSection(
                  header: context.l10n.cloudSelectReadInstance,
                  children: [
                    if (choices?.isEmpty ?? true)
                      AppRow(title: context.l10n.cloudNoSavedInstances),
                    for (final choice in choices!)
                      CloudCheckRow(
                        key: ValueKey(
                          'server-cloud-instance-${choice.accountId}-${choice.instanceKey}',
                        ),
                        value: _same(_selected, choice),
                        onChanged: _blocked || !_available(choice)
                            ? null
                            : (_) => setState(() => _selected = choice),
                        title: _instanceName(choice),
                        status: choice.missing || choice.stale
                            ? Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: StatusPill(
                                  choice.missing
                                      ? context.l10n.cloudMissingRefresh
                                      : context.l10n.cloudFailedRefresh,
                                  tone: AppTone.amber,
                                ),
                              )
                            : choice.serverId == widget.serverId
                            ? Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: StatusPill(
                                  context.l10n.cloudCurrentLink,
                                  tone: AppTone.green,
                                ),
                              )
                            : null,
                        details: [
                          if (choice.observation.ipv4 != null)
                            choice.observation.ipv4!,
                          if (choice.observation.projectName != null)
                            choice.observation.projectName!,
                          context.l10n.cloudReadAt(
                            cloudTime(choice.observation.observedAt),
                          ),
                          if (choice.serverId != null &&
                              choice.serverId != widget.serverId)
                            context.l10n.cloudAlreadyLinkedTo(
                              widget.ledger.byId(choice.serverId!)?.name ??
                                  context.l10n.cloudOtherServer,
                            ),
                          if (accountRestriction != null)
                            localizedText(accountRestriction, context.l10n),
                        ],
                      ),
                  ],
                ),
              CloudAction(
                buttonKey: const ValueKey('server-cloud-save'),
                icon: Icons.link,
                onPressed:
                    _blocked ||
                        _selected == null ||
                        !_available(_selected!) ||
                        _same(current, _selected)
                    ? null
                    : _save,
                label: _saving
                    ? context.l10n.cloudSaving
                    : current == null
                    ? context.l10n.cloudSaveLink
                    : context.l10n.cloudChangeLink,
              ),
              CloudFootnote(context.l10n.cloudLocalLinkBoundary),
            ],
          ],
        ),
      );
    },
  );
}
