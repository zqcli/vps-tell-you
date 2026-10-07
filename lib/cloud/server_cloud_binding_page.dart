import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../servers/ledger_controller.dart';
import 'cloud_account.dart';
import 'cloud_widgets.dart';

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
      if (widget.ledger.refreshFailed) await widget.ledger.refresh();
      if (widget.ledger.cloud.needsReload) {
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
      _accountId =
          loaded?.current?.accountId ?? loaded?.accounts.firstOrNull?.id;
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

  bool _available(CloudBindingChoice choice) =>
      !choice.stale &&
      !choice.missing &&
      (choice.serverId == null || choice.serverId == widget.serverId) &&
      _options?.accounts
              .where((a) => a.id == choice.accountId)
              .firstOrNull
              ?.lastFailure ==
          null;

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
      final confirmed = await confirmAction(
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Builder(
          builder: (context) => Text(
            localizedText(
              unlink
                  ? LocalizedText((l10n) => l10n.cloudServerUnlinked)
                  : LocalizedText((l10n) => l10n.cloudBindingSaved),
              context.l10n,
            ),
          ),
        ),
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
      final choices = options?.choices
          .where((choice) => choice.accountId == _accountId)
          .toList();
      return PopScope<bool>(
        canPop: !_saving,
        child: Scaffold(
          appBar: AppBar(title: Text(context.l10n.cloudLinkPanelAccount)),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  InfoNote(context.l10n.cloudLocalBindingInfo),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_committed)
                    CloudNotice(context.l10n.cloudBindingCommitted),
                  if (_error != null) CloudNotice(_error!, error: true),
                  if (widget.ledger.refreshFailed)
                    CloudNotice(
                      context.l10n.cloudLedgerNotUpdated,
                      error: true,
                    ),
                  TextButton.icon(
                    key: const ValueKey('server-cloud-reload'),
                    onPressed: _busy ? null : _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.cloudReloadLocal),
                  ),
                  if (options != null) ...[
                    Text(
                      options.server.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (options.server.archived || options.server.isDemo)
                      CloudNotice(
                        context.l10n.cloudBindingReadOnly,
                        error: true,
                      ),
                    if (current != null) ...[
                      SectionTitle(context.l10n.cloudCurrentLink),
                      LedgerCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(_accountName(current.accountId)),
                            Text(_instanceName(current)),
                            TextButton.icon(
                              key: const ValueKey('server-cloud-unbind'),
                              onPressed: _blocked
                                  ? null
                                  : () => _save(unlink: true),
                              icon: const Icon(Icons.link_off),
                              label: Text(context.l10n.cloudUnlinkThis),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SectionTitle(context.l10n.cloudSelectAccount),
                    if (options.accounts.isEmpty)
                      CloudNotice(context.l10n.cloudNoSavedAccounts),
                    for (final account in options.accounts)
                      ListTile(
                        key: ValueKey('server-cloud-account-${account.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _accountId == account.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        title: Text(account.alias),
                        subtitle: Text(
                          '${cloudProviderName(account.provider)}\n${account.endpoint}',
                        ),
                        selected: _accountId == account.id,
                        onTap: _blocked
                            ? null
                            : () => setState(() {
                                _accountId = account.id;
                                _selected = current?.accountId == account.id
                                    ? current
                                    : null;
                              }),
                      ),
                    if (_accountId != null) ...[
                      SectionTitle(context.l10n.cloudSelectReadInstance),
                      if (choices?.isEmpty ?? true)
                        CloudNotice(context.l10n.cloudNoSavedInstances),
                      for (final choice in choices!)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: LedgerCard(
                            padding: EdgeInsets.zero,
                            child: CheckboxListTile(
                              key: ValueKey(
                                'server-cloud-instance-${choice.accountId}-${choice.instanceKey}',
                              ),
                              value: _same(_selected, choice),
                              onChanged: _blocked || !_available(choice)
                                  ? null
                                  : (_) => setState(() => _selected = choice),
                              title: Text(_instanceName(choice)),
                              subtitle: Text(
                                [
                                  if (choice.observation.ipv4 != null)
                                    choice.observation.ipv4!,
                                  if (choice.observation.projectName != null)
                                    choice.observation.projectName!,
                                  context.l10n.cloudReadAt(
                                    cloudTime(choice.observation.observedAt),
                                  ),
                                  if (choice.serverId == widget.serverId)
                                    context.l10n.cloudCurrentLink,
                                  if (choice.serverId != null &&
                                      choice.serverId != widget.serverId)
                                    context.l10n.cloudAlreadyLinkedTo(
                                      widget.ledger
                                              .byId(choice.serverId!)
                                              ?.name ??
                                          context.l10n.cloudOtherServer,
                                    ),
                                  if (choice.missing)
                                    context.l10n.cloudMissingRefresh
                                  else if (choice.stale ||
                                      !_available(choice) &&
                                          choice.serverId == null)
                                    context.l10n.cloudFailedRefresh,
                                ].join('\n'),
                              ),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const ValueKey('server-cloud-save'),
                      onPressed:
                          _blocked ||
                              _selected == null ||
                              !_available(_selected!) ||
                              _same(current, _selected)
                          ? null
                          : _save,
                      icon: const Icon(Icons.link),
                      label: Text(
                        _saving
                            ? context.l10n.cloudSaving
                            : current == null
                            ? context.l10n.cloudSaveLink
                            : context.l10n.cloudChangeLink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InfoNote(context.l10n.cloudLocalLinkBoundary),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
