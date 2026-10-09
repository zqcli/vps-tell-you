import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/ledger_store.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../servers/ledger_controller.dart';
import '../servers/refresh_failure_notice.dart';
import '../servers/server_detail.dart';
import '../servers/server_form.dart';
import '../servers/server_record.dart';
import 'cloud_account.dart';
import 'cloud_models.dart';
import 'cloud_pages.dart';
import 'cloud_widgets.dart';
import 'provider_record.dart';

/// A null route result means cancellation; a null [provider] is an explicit
/// choice to add a manual record without a business provider.
class ProviderSelection {
  const ProviderSelection(this.provider);
  final ProviderRecord? provider;
}

String serverProviderLabel(
  BuildContext context,
  LedgerController ledger,
  ServerRecord server,
) =>
    ledger.cloud.providers
        .where((provider) => provider.id == server.providerId)
        .firstOrNull
        ?.name ??
    context.l10n.providerUiUnspecified;

String serverProviderMark(LedgerController ledger, ServerRecord server) {
  final name = ledger.cloud.providers
      .where((provider) => provider.id == server.providerId)
      .firstOrNull
      ?.name;
  return name == null || name.isEmpty
      ? 'VPS'
      : name.runes.take(2).map(String.fromCharCode).join().toUpperCase();
}

bool _canEdit(LedgerController ledger) =>
    ledger.canMutate && !ledger.cloud.busy && !ledger.cloud.needsReload;

String _providerSummary(
  BuildContext context,
  LedgerController ledger,
  ProviderRecord provider,
) => context.l10n.providerUiSummary(
  ledger.cloud.accounts
      .where((a) => a.businessProviderId == provider.id)
      .length,
  ledger.records.where((s) => s.providerId == provider.id).length,
);

String _scopeLabel(BuildContext context, CloudAccount account) =>
    switch (account.authScope) {
      AdapterAuthScope.singleDevice => context.l10n.providerUiSingleScope,
      AdapterAuthScope.account => context.l10n.providerUiAccountScope,
      AdapterAuthScope.unknown => context.l10n.providerUiUnknownScope,
    };

/// Shared status for all provider routes. A successful write followed by a
/// failed reload stays committed, and cannot be submitted a second time.
class _ProviderNotices extends StatelessWidget {
  const _ProviderNotices(this.ledger);
  final LedgerController ledger;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (ledger.refreshFailed) RefreshFailureNotice(controller: ledger),
      if (ledger.cloud.needsReload) ...[
        CloudNotice(context.l10n.cloudMetadataIncomplete, error: true),
        OutlinedButton(
          onPressed: ledger.cloud.busy ? null : ledger.cloud.reload,
          child: Text(context.l10n.cloudReloadMetadata),
        ),
      ] else if (ledger.cloud.localizedError != null)
        CloudNotice(ledger.cloud.localizedError!, error: true),
      if (ledger.cloud.cleanupPending) ...[
        CloudNotice(context.l10n.cloudCleanupNotice, error: true),
        OutlinedButton(
          onPressed: ledger.cloud.busy ? null : ledger.cloud.retryCleanup,
          child: Text(context.l10n.cloudRetryCleanup),
        ),
      ],
    ],
  );
}

Future<ProviderRecord?> editProvider(
  BuildContext context,
  LedgerController ledger, {
  ProviderRecord? provider,
}) => showDialog<ProviderRecord>(
  context: context,
  builder: (_) => _ProviderNameDialog(ledger: ledger, provider: provider),
);

class _ProviderNameDialog extends StatefulWidget {
  const _ProviderNameDialog({required this.ledger, this.provider});
  final LedgerController ledger;
  final ProviderRecord? provider;
  @override
  State<_ProviderNameDialog> createState() => _ProviderNameDialogState();
}

class _ProviderNameDialogState extends State<_ProviderNameDialog> {
  late final name = TextEditingController(text: widget.provider?.name);
  bool saving = false;
  LocalizedMessage? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !_canEdit(widget.ledger)) return;
    final value = name.text.trim();
    if (value.isEmpty || value.length > 80) {
      setState(() => error = LocalizedText((l10n) => l10n.providerNameRange));
      return;
    }
    final old = widget.provider;
    final provider = ProviderRecord(
      id: old?.id ?? newLocalId(),
      name: value,
      createdAt: old?.createdAt ?? widget.ledger.clock(),
      revision: old?.revision ?? 0,
      needsReview: old?.needsReview ?? false,
    );
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.ledger.mutate(
        () => widget.ledger.store.saveProvider(provider, isNew: old == null),
      );
      if (mounted) {
        Navigator.pop(
          context,
          widget.ledger.cloud.providers
                  .where((p) => p.id == provider.id)
                  .firstOrNull ??
              provider,
        );
      }
    } catch (problem) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = problem is LocalizedMessage
            ? problem
            : LocalizedText((l10n) => l10n.operationFailed);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      scrollable: true,
      title: Text(
        widget.provider == null
            ? context.l10n.providerUiAdd
            : context.l10n.providerUiRename,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('provider-name'),
            controller: name,
            autofocus: true,
            enabled: !saving,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: context.l10n.providerUiName),
            onSubmitted: (_) => save(),
          ),
          if (widget.provider?.needsReview == true)
            InfoNote(context.l10n.providerUiRenameReviewHelp),
          if (error != null) CloudNotice(error!, error: true),
        ],
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('provider-save'),
          onPressed: saving ? null : save,
          child: Text(saving ? context.l10n.cloudSaving : context.l10n.save),
        ),
      ],
    ),
  );
}

class ProvidersPage extends StatefulWidget {
  const ProvidersPage({super.key, required this.ledger});
  final LedgerController ledger;
  @override
  State<ProvidersPage> createState() => _ProvidersPageState();
}

class _ProvidersPageState extends State<ProvidersPage> {
  bool opening = false;
  Future<void> open(Future<void> Function() action) async {
    if (opening) return;
    setState(() => opening = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> add() => open(() async {
    final provider = await editProvider(context, widget.ledger);
    if (provider != null && mounted && _canEdit(widget.ledger)) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderDetailsPage(
            ledger: widget.ledger,
            providerId: provider.id,
          ),
        ),
      );
    }
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.providerUiTitle),
        actions: [
          IconButton(
            key: const ValueKey('provider-add'),
            tooltip: context.l10n.providerUiAdd,
            onPressed: opening || !_canEdit(widget.ledger) ? null : add,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          InfoNote(context.l10n.providerUiHierarchyHelp),
          _ProviderNotices(widget.ledger),
          if (widget.ledger.cloud.providers.isEmpty)
            LedgerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.providerUiEmpty,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  InfoNote(context.l10n.providerUiEmptyHelp),
                  FilledButton.icon(
                    onPressed: opening || !_canEdit(widget.ledger) ? null : add,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.providerUiAdd),
                  ),
                ],
              ),
            ),
          for (final provider in widget.ledger.cloud.providers)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LedgerCard(
                padding: EdgeInsets.zero,
                child: SettingRow(
                  key: ValueKey('provider-${provider.id}'),
                  icon: provider.needsReview
                      ? Icons.help_outline
                      : Icons.business_outlined,
                  title: provider.name,
                  subtitle:
                      '${_providerSummary(context, widget.ledger, provider)}'
                      '${provider.needsReview ? '\n${context.l10n.providerUiNeedsReview}' : ''}',
                  onTap: opening
                      ? null
                      : () => open(() async {
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProviderDetailsPage(
                                ledger: widget.ledger,
                                providerId: provider.id,
                              ),
                            ),
                          );
                        }),
                ),
              ),
            ),
          InfoNote(
            context.l10n.providerUiUnspecifiedCount(
              widget.ledger.records.where((s) => s.providerId == null).length,
            ),
          ),
        ],
      ),
    ),
  );
}

class ProviderPickerPage extends StatefulWidget {
  const ProviderPickerPage({
    super.key,
    required this.ledger,
    this.allowUnspecified = false,
  });
  final LedgerController ledger;
  final bool allowUnspecified;
  @override
  State<ProviderPickerPage> createState() => _ProviderPickerPageState();
}

class _ProviderPickerPageState extends State<ProviderPickerPage> {
  bool opening = false;
  Future<void> add() async {
    if (opening || !_canEdit(widget.ledger)) return;
    setState(() => opening = true);
    final provider = await editProvider(context, widget.ledger);
    if (!mounted) return;
    setState(() => opening = false);
    if (provider != null && _canEdit(widget.ledger)) {
      opening = true;
      Navigator.pop(context, ProviderSelection(provider));
    }
  }

  void choose(ProviderSelection value) {
    if (opening || !_canEdit(widget.ledger)) return;
    opening = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(context.l10n.providerUiChoose)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ProviderNotices(widget.ledger),
          _ProviderChoices(
            ledger: widget.ledger,
            allowUnspecified: widget.allowUnspecified,
            enabled: !opening && _canEdit(widget.ledger),
            onSelected: choose,
            onAdd: add,
          ),
        ],
      ),
    ),
  );
}

class _ProviderChoices extends StatelessWidget {
  const _ProviderChoices({
    required this.ledger,
    required this.allowUnspecified,
    required this.enabled,
    required this.onSelected,
    required this.onAdd,
  });
  final LedgerController ledger;
  final bool allowUnspecified, enabled;
  final ValueChanged<ProviderSelection> onSelected;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InfoNote(context.l10n.providerUiChooseHelp),
      for (final provider in ledger.cloud.providers)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: LedgerCard(
            padding: EdgeInsets.zero,
            child: SettingRow(
              key: ValueKey('choose-provider-${provider.id}'),
              icon: provider.needsReview
                  ? Icons.help_outline
                  : Icons.business_outlined,
              title: provider.name,
              subtitle: provider.needsReview
                  ? context.l10n.providerUiNeedsReview
                  : _providerSummary(context, ledger, provider),
              onTap: enabled && !provider.needsReview
                  ? () => onSelected(ProviderSelection(provider))
                  : null,
            ),
          ),
        ),
      OutlinedButton.icon(
        key: const ValueKey('choose-provider-add'),
        onPressed: enabled ? onAdd : null,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.providerUiAdd),
      ),
      if (allowUnspecified) ...[
        const SizedBox(height: 12),
        LedgerCard(
          padding: EdgeInsets.zero,
          child: SettingRow(
            key: const ValueKey('choose-provider-unspecified'),
            icon: Icons.edit_note,
            title: context.l10n.providerUiUnspecified,
            subtitle: context.l10n.providerUiUnspecifiedHelp,
            onTap: enabled
                ? () => onSelected(const ProviderSelection(null))
                : null,
          ),
        ),
      ],
    ],
  );
}

class ProviderDetailsPage extends StatefulWidget {
  const ProviderDetailsPage({
    super.key,
    required this.ledger,
    required this.providerId,
  });
  final LedgerController ledger;
  final String providerId;
  @override
  State<ProviderDetailsPage> createState() => _ProviderDetailsPageState();
}

class _ProviderDetailsPageState extends State<ProviderDetailsPage> {
  String? resolvedProviderId;
  bool opening = false;
  Future<void> open(Future<void> Function() action) async {
    if (opening) return;
    setState(() => opening = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger,
    builder: (context, _) {
      final ledger = widget.ledger;
      final provider = ledger.cloud.providers
          .where((p) => p.id == (resolvedProviderId ?? widget.providerId))
          .firstOrNull;
      if (provider == null) {
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.providerUiDetails)),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _ProviderNotices(ledger),
              InfoNote(context.l10n.providerUiUnavailable),
            ],
          ),
        );
      }
      final accounts = ledger.cloud.accounts
          .where((a) => a.businessProviderId == provider.id)
          .toList();
      final servers = ledger.records
          .where((s) => s.providerId == provider.id)
          .toList();
      final editable = !opening && _canEdit(ledger);
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.providerUiDetails),
          actions: [
            IconButton(
              tooltip: context.l10n.providerUiRename,
              onPressed: editable
                  ? () => open(() async {
                      await editProvider(context, ledger, provider: provider);
                    })
                  : null,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _ProviderNotices(ledger),
            Text(
              provider.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            InfoNote(_providerSummary(context, ledger, provider)),
            if (provider.needsReview)
              CloudNotice(context.l10n.providerUiReviewHelp, error: true),
            if (!provider.needsReview)
              FilledButton.icon(
                key: const ValueKey('provider-add-server'),
                onPressed: editable
                    ? () => open(() async {
                        final id = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddServerPage(
                              ledger: ledger,
                              provider: provider,
                            ),
                          ),
                        );
                        if (id != null &&
                            context.mounted &&
                            ledger.byId(id) != null) {
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ServerDetail(controller: ledger, id: id),
                            ),
                          );
                        }
                      })
                    : null,
                icon: const Icon(Icons.add),
                label: Text(context.l10n.serverAdd),
              ),
            SectionTitle(context.l10n.providerUiInstances),
            if (accounts.isEmpty)
              LedgerCard(child: InfoNote(context.l10n.providerUiNoInstances)),
            for (final account in accounts)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LedgerCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SettingRow(
                        key: ValueKey('provider-instance-${account.id}'),
                        icon: Icons.cloud_outlined,
                        title: account.alias,
                        subtitle:
                            '${cloudProviderName(account.adapterType)} · '
                            '${_scopeLabel(context, account)}\n'
                            '${context.l10n.providerUiLinkedCount(ledger.cloud.bindings.where((b) => b.accountId == account.id).length)}\n'
                            '${account.endpoint}',
                        onTap: opening
                            ? null
                            : () => open(() async {
                                await Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CloudAccountDetailsPage(
                                      ledger: ledger,
                                      accountId: account.id,
                                    ),
                                  ),
                                );
                              }),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (account.pinnedServerId != null)
                              InfoNote(
                                context.l10n.providerUiPinnedHelp(
                                  ledger.byId(account.pinnedServerId!)?.name ??
                                      account.pinnedServerId!,
                                ),
                              ),
                            if (provider.needsReview)
                              OutlinedButton.icon(
                                key: ValueKey('confirm-provider-${account.id}'),
                                onPressed: editable
                                    ? () => open(() async {
                                        final saved =
                                            await confirmAdapterProviderOwnership(
                                              context,
                                              ledger,
                                              account,
                                            );
                                        if (saved &&
                                            mounted &&
                                            !ledger.cloud.providers.any(
                                              (p) => p.id == provider.id,
                                            )) {
                                          final resolved = ledger.cloud.accounts
                                              .where((a) => a.id == account.id)
                                              .firstOrNull;
                                          if (resolved != null) {
                                            setState(
                                              () => resolvedProviderId =
                                                  resolved.businessProviderId,
                                            );
                                          }
                                        }
                                      })
                                    : null,
                                icon: const Icon(Icons.fact_check_outlined),
                                label: Text(
                                  context.l10n.providerUiConfirmOwnership,
                                ),
                              )
                            else
                              TextButton.icon(
                                onPressed: editable
                                    ? () => open(() async {
                                        await cloudAccountMenu(
                                          context,
                                          ledger,
                                          account,
                                        );
                                      })
                                    : null,
                                icon: const Icon(Icons.more_horiz),
                                label: Text(context.l10n.serverMoreActions),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!provider.needsReview)
              OutlinedButton.icon(
                key: const ValueKey('provider-add-instance'),
                onPressed: editable
                    ? () => open(() async {
                        await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CloudTemplatesPage(
                              ledger: ledger,
                              businessProvider: provider,
                            ),
                          ),
                        );
                      })
                    : null,
                icon: const Icon(Icons.add_link),
                label: Text(context.l10n.providerUiAddInstance),
              ),
            SectionTitle(context.l10n.providerUiDevices),
            if (servers.isEmpty) InfoNote(context.l10n.providerUiNoDevices),
            for (final server in servers)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LedgerCard(
                  padding: EdgeInsets.zero,
                  child: SettingRow(
                    key: ValueKey('provider-device-${server.id}'),
                    icon: Icons.dns_outlined,
                    title: server.name,
                    subtitle: [
                      if (server.archived) context.l10n.archivedRecords,
                      server.host,
                      ledger.cloud.bindingFor(server.id) == null
                          ? context.l10n.providerUiManualDevice
                          : context.l10n.providerUiLinkedDevice,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    onTap: opening
                        ? null
                        : () => open(() async {
                            await Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ServerDetail(
                                  controller: ledger,
                                  id: server.id,
                                ),
                              ),
                            );
                          }),
                  ),
                ),
              ),
            InfoNote(context.l10n.cloudReadOnlyBoundary),
          ],
        ),
      );
    },
  );
}

/// This confirmation names every device whose ownership will move. Renaming
/// the migration placeholder never counts as confirming adapter authority.
Future<bool> confirmAdapterProviderOwnership(
  BuildContext context,
  LedgerController ledger,
  CloudAccount account,
) async {
  if (!_canEdit(ledger)) return false;
  final selection = await Navigator.push<ProviderSelection>(
    context,
    MaterialPageRoute(builder: (_) => ProviderPickerPage(ledger: ledger)),
  );
  if (!context.mounted || selection?.provider == null) return false;
  final target = selection!.provider!;
  final current = ledger.cloud.accounts
      .where((a) => a.id == account.id)
      .firstOrNull;
  if (current == null) return false;
  final affected = ledger.cloud.bindings
      .where((b) => b.accountId == current.id)
      .map((b) => ledger.byId(b.serverId)?.name ?? b.serverId)
      .toList();
  final confirmed = await confirmAction(
    context,
    title: LocalizedText((l10n) => l10n.providerUiConfirmOwnership),
    message: LocalizedText(
      (l10n) => l10n.providerUiConfirmOwnershipMessage(
        current.alias,
        target.name,
        affected.isEmpty
            ? l10n.providerUiNoAffectedDevices
            : affected.map((n) => '• $n').join('\n'),
      ),
    ),
    action: LocalizedText((l10n) => l10n.providerUiConfirmOwnership),
  );
  if (!confirmed || !context.mounted || !_canEdit(ledger)) return false;
  try {
    await ledger.mutate(
      () => ledger.store.confirmAdapterProvider(current, target),
    );
    return true;
  } catch (error) {
    if (context.mounted) showFailure(context, error);
    return false;
  }
}

/// The only route that changes ownership of an existing device. The ordinary
/// edit form retains its original provider and revision.
Future<bool> changeServerProvider(
  BuildContext context,
  LedgerController ledger,
  ServerRecord server,
) async {
  if (!_canEdit(ledger) || server.archived || server.isDemo) return false;
  final selection = await Navigator.push<ProviderSelection>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          ProviderPickerPage(ledger: ledger, allowUnspecified: true),
    ),
  );
  if (!context.mounted ||
      selection == null ||
      selection.provider?.id == server.providerId) {
    return false;
  }
  final options = await ledger.cloud.serverBindingOptions(server.id);
  if (!context.mounted) return false;
  if (options == null) {
    showFailure(
      context,
      ledger.cloud.localizedError ??
          LocalizedText((l10n) => l10n.cloudOperationFailed),
    );
    return false;
  }
  final current = options.server;
  if (current.archived ||
      current.isDemo ||
      current.providerId == selection.provider?.id) {
    return false;
  }
  final binding = options.current;
  final account = options.accounts
      .where((a) => a.id == binding?.accountId)
      .firstOrNull;
  final oldName = serverProviderLabel(context, ledger, current);
  final confirmed = await confirmAction(
    context,
    title: LocalizedText((l10n) => l10n.providerUiChange),
    message: LocalizedText(
      (l10n) => l10n.providerUiChangeMessage(
        current.name,
        oldName,
        selection.provider?.name ?? l10n.providerUiUnspecified,
        binding == null
            ? l10n.providerUiChangeNoLink
            : l10n.providerUiChangeUnlink(account?.alias ?? binding.accountId),
      ),
    ),
    action: LocalizedText(
      (l10n) => binding == null
          ? l10n.providerUiChange
          : l10n.providerUiUnlinkAndChange,
    ),
    dangerous: binding != null,
  );
  if (!confirmed || !context.mounted || !_canEdit(ledger)) return false;
  try {
    await ledger.mutate(
      () => ledger.store.setServerProvider(
        options,
        selection.provider?.id,
        confirmUnlink: binding != null,
      ),
    );
    return true;
  } catch (error) {
    if (context.mounted) showFailure(context, error);
    return false;
  }
}

class AddServerPage extends StatefulWidget {
  const AddServerPage({super.key, required this.ledger, this.provider});
  final LedgerController ledger;
  final ProviderRecord? provider;
  @override
  State<AddServerPage> createState() => _AddServerPageState();
}

class _AddServerPageState extends State<AddServerPage> {
  late ProviderSelection? selection = widget.provider == null
      ? null
      : ProviderSelection(widget.provider);
  bool opening = false;
  bool finishing = false;
  void finish([String? id]) {
    if (!mounted || finishing) return;
    final route = ModalRoute.of(context);
    setState(() => finishing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && route?.isCurrent == true) Navigator.pop(context, id);
    });
  }

  Future<void> addProvider() async {
    if (opening || finishing || !_canEdit(widget.ledger)) return;
    setState(() => opening = true);
    final created = await editProvider(context, widget.ledger);
    if (!mounted) return;
    setState(() {
      opening = false;
      if (created != null && _canEdit(widget.ledger)) {
        selection = ProviderSelection(created);
      }
    });
  }

  Future<void> manual() async {
    if (opening || finishing || !_canEdit(widget.ledger)) return;
    setState(() => opening = true);
    try {
      final id = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => ServerForm(
            controller: widget.ledger,
            businessProvider: selection?.provider,
          ),
        ),
      );
      if (id != null && mounted) finish(id);
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> automatic(ProviderRecord provider) async {
    if (opening ||
        finishing ||
        !_canEdit(widget.ledger) ||
        provider.needsReview) {
      return;
    }
    setState(() => opening = true);
    try {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              _ProviderAdaptersPage(ledger: widget.ledger, provider: provider),
        ),
      );
      if (saved == true && mounted) finish();
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger,
    builder: (context, _) {
      final selected = selection?.provider;
      final provider = selected == null
          ? null
          : widget.ledger.cloud.providers
                .where((p) => p.id == selected.id)
                .firstOrNull;
      final available =
          selection != null &&
          (selected == null || (provider != null && !provider.needsReview));
      final enabled = !opening && !finishing && _canEdit(widget.ledger);
      return PopScope<String>(
        canPop: finishing || selection == null || widget.provider != null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !opening) setState(() => selection = null);
        },
        child: Scaffold(
          appBar: AppBar(title: Text(context.l10n.serverAdd)),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _ProviderNotices(widget.ledger),
              if (selection == null) ...[
                Text(
                  context.l10n.providerUiChoose,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                _ProviderChoices(
                  ledger: widget.ledger,
                  allowUnspecified: true,
                  enabled: enabled,
                  onAdd: addProvider,
                  onSelected: (value) => setState(() => selection = value),
                ),
              ] else ...[
                LedgerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.l10n.providerUiSelected,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        provider?.name ??
                            selected?.name ??
                            context.l10n.providerUiUnspecified,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (widget.provider == null)
                        TextButton(
                          key: const ValueKey('add-change-provider'),
                          onPressed: enabled
                              ? () => setState(() => selection = null)
                              : null,
                          child: Text(context.l10n.providerUiChooseAnother),
                        ),
                    ],
                  ),
                ),
                SectionTitle(context.l10n.providerUiChooseMethod),
                if (!available)
                  CloudNotice(context.l10n.providerUiUnavailable, error: true),
                LedgerCard(
                  padding: EdgeInsets.zero,
                  child: SettingRow(
                    key: const ValueKey('add-manual'),
                    icon: Icons.edit_note,
                    title: context.l10n.serverManualAdd,
                    subtitle: context.l10n.providerUiManualHelp,
                    onTap: enabled && available ? manual : null,
                  ),
                ),
                const SizedBox(height: 12),
                LedgerCard(
                  padding: EdgeInsets.zero,
                  child: SettingRow(
                    key: const ValueKey('add-automatic'),
                    icon: Icons.cloud_download_outlined,
                    title: context.l10n.providerUiAutomatic,
                    subtitle: provider == null
                        ? context.l10n.providerUiAutoNeedsProvider
                        : context.l10n.providerUiAutomaticHelp,
                    onTap: enabled && available && provider != null
                        ? () => automatic(provider)
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _ProviderAdaptersPage extends StatefulWidget {
  const _ProviderAdaptersPage({required this.ledger, required this.provider});
  final LedgerController ledger;
  final ProviderRecord provider;
  @override
  State<_ProviderAdaptersPage> createState() => _ProviderAdaptersPageState();
}

class _ProviderAdaptersPageState extends State<_ProviderAdaptersPage> {
  bool opening = false;
  Future<void> openPinned(CloudAccount account) async {
    if (opening || widget.ledger.byId(account.pinnedServerId!) == null) return;
    setState(() => opening = true);
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ServerDetail(
            controller: widget.ledger,
            id: account.pinnedServerId!,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> open(CloudAccount? account) async {
    if (opening || !_canEdit(widget.ledger)) return;
    setState(() => opening = true);
    try {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => account == null
              ? CloudTemplatesPage(
                  ledger: widget.ledger,
                  businessProvider: widget.provider,
                )
              : CloudReadPage(
                  ledger: widget.ledger,
                  account: account,
                  importAfterRead: true,
                ),
        ),
      );
      if (saved == true && mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger,
    builder: (context, _) {
      final current = widget.ledger.cloud.providers
          .where((p) => p.id == widget.provider.id)
          .firstOrNull;
      final enabled =
          !opening &&
          _canEdit(widget.ledger) &&
          current != null &&
          !current.needsReview;
      final accounts = widget.ledger.cloud.accounts
          .where((a) => a.businessProviderId == widget.provider.id)
          .toList();
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.providerUiChooseInstance)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _ProviderNotices(widget.ledger),
            Text(
              current?.name ?? widget.provider.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            InfoNote(context.l10n.providerUiInstanceChoiceHelp),
            for (final account in accounts)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LedgerCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SettingRow(
                        key: ValueKey('choose-instance-${account.id}'),
                        icon: Icons.cloud_outlined,
                        title: account.alias,
                        subtitle:
                            '${cloudProviderName(account.adapterType)} · ${_scopeLabel(context, account)}\n'
                            '${context.l10n.providerUiLinkedCount(widget.ledger.cloud.bindings.where((b) => b.accountId == account.id).length)}\n'
                            '${account.authScope == AdapterAuthScope.singleDevice && account.pinnedServerId != null ? context.l10n.providerUiPinnedHelp(widget.ledger.byId(account.pinnedServerId!)?.name ?? account.pinnedServerId!) : account.endpoint}',
                        // A singleton pin survives unlinking. Zero current bindings does
                        // not mean these credentials can authorize a new local device.
                        onTap:
                            enabled &&
                                account.authScope != AdapterAuthScope.unknown &&
                                !(account.authScope ==
                                        AdapterAuthScope.singleDevice &&
                                    account.pinnedServerId != null)
                            ? () => open(account)
                            : null,
                      ),
                      if (account.pinnedServerId != null &&
                          widget.ledger.byId(account.pinnedServerId!) != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: TextButton.icon(
                            key: ValueKey('pinned-device-${account.id}'),
                            onPressed: opening
                                ? null
                                : () => openPinned(account),
                            icon: const Icon(Icons.dns_outlined),
                            label: Text(context.l10n.serverDetails),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            OutlinedButton.icon(
              key: const ValueKey('choose-instance-add'),
              onPressed: enabled ? () => open(null) : null,
              icon: const Icon(Icons.add_link),
              label: Text(context.l10n.providerUiAddInstance),
            ),
          ],
        ),
      );
    },
  );
}
