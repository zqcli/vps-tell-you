import 'package:flutter/cupertino.dart'
    show CupertinoAlertDialog, CupertinoDialogAction, showCupertinoDialog;
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/ui/ui.dart';
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

AppTone _scopeTone(CloudAccount account) => switch (account.authScope) {
  AdapterAuthScope.singleDevice => AppTone.blue,
  AdapterAuthScope.account => AppTone.green,
  AdapterAuthScope.unknown => AppTone.amber,
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
      if (ledger.refreshFailed)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: RefreshFailureNotice(controller: ledger),
        ),
      if (ledger.cloud.needsReload) ...[
        CloudNotice(context.l10n.cloudMetadataIncomplete, error: true),
        AppSection(
          topSpacing: 10,
          children: [
            AppRow(
              center: true,
              title: context.l10n.cloudReloadMetadata,
              enabled: !ledger.cloud.busy,
              onTap: ledger.cloud.busy ? null : ledger.cloud.reload,
            ),
          ],
        ),
      ] else if (ledger.cloud.localizedError != null)
        CloudNotice(ledger.cloud.localizedError!, error: true),
      if (ledger.cloud.cleanupPending) ...[
        CloudNotice(context.l10n.cloudCleanupNotice, error: true),
        AppSection(
          topSpacing: 10,
          children: [
            AppRow(
              center: true,
              title: context.l10n.cloudRetryCleanup,
              enabled: !ledger.cloud.busy,
              onTap: ledger.cloud.busy ? null : ledger.cloud.retryCleanup,
            ),
          ],
        ),
      ],
    ],
  );
}

Future<ProviderRecord?> editProvider(
  BuildContext context,
  LedgerController ledger, {
  ProviderRecord? provider,
}) => showCupertinoDialog<ProviderRecord>(
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
  Widget build(BuildContext context) {
    final p = context.palette;
    return PopScope(
      canPop: !saving,
      child: CupertinoAlertDialog(
        title: Text(
          widget.provider == null
              ? context.l10n.providerUiAdd
              : context.l10n.providerUiRename,
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CloudPromptField(
                fieldKey: const ValueKey('provider-name'),
                controller: name,
                hint: context.l10n.providerUiName,
                enabled: !saving,
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => save(),
              ),
              if (widget.provider?.needsReview == true)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    context.l10n.providerUiRenameReviewHelp,
                    textAlign: TextAlign.start,
                    style: TextStyle(fontSize: 12.5, color: p.text2),
                  ),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      localizedText(error!, context.l10n),
                      textAlign: TextAlign.start,
                      style: TextStyle(fontSize: 13, color: p.red),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          CupertinoDialogAction(
            key: const ValueKey('provider-save'),
            isDefaultAction: true,
            onPressed: saving ? null : save,
            child: Text(saving ? context.l10n.cloudSaving : context.l10n.save),
          ),
        ],
      ),
    );
  }
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
    builder: (context, _) {
      final ledger = widget.ledger;
      final providers = ledger.cloud.providers;
      final canAdd = !opening && _canEdit(ledger);
      final unspecified = ledger.records
          .where((s) => s.providerId == null)
          .length;
      return AppScaffold(
        title: context.l10n.uiCloudProvidersTitle,
        // An empty list shows its single primary action in the body instead
        // of a second, duplicated "+" in the bar.
        actions: [
          if (providers.isNotEmpty)
            AppNavButton.icon(
              Icons.add,
              key: const ValueKey('provider-add'),
              tooltip: context.l10n.providerUiAdd,
              onPressed: canAdd ? add : null,
            ),
        ],
        children: [
          _ProviderNotices(ledger),
          if (providers.isEmpty)
            AppEmptyState(
              icon: Icons.business_outlined,
              title: context.l10n.providerUiEmpty,
              message: context.l10n.providerUiEmptyHelp,
              actions: [
                AppButton(
                  key: const ValueKey('provider-add'),
                  label: context.l10n.providerUiAdd,
                  icon: Icons.add,
                  onPressed: canAdd ? add : null,
                ),
              ],
            )
          else
            AppSection(
              topSpacing: 8,
              footer: context.l10n.providerUiHierarchyHelp,
              children: [
                for (final provider in providers)
                  AppRow(
                    key: ValueKey('provider-${provider.id}'),
                    leading: ProviderAvatar(name: provider.name),
                    title: provider.name,
                    subtitle: _providerSummary(context, ledger, provider),
                    trailing: provider.needsReview
                        ? StatusPill(
                            context.l10n.uiCloudNeedsReviewPill,
                            tone: AppTone.amber,
                          )
                        : null,
                    chevron: true,
                    onTap: opening
                        ? null
                        : () => open(() async {
                            await Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProviderDetailsPage(
                                  ledger: ledger,
                                  providerId: provider.id,
                                ),
                              ),
                            );
                          }),
                  ),
              ],
            ),
          if (providers.isNotEmpty || unspecified > 0)
            AppSection(
              children: [
                AppRow(
                  leading: const ProviderAvatar(name: null),
                  title: context.l10n.providerUiUnspecified,
                  subtitle: context.l10n.providerUiUnspecifiedCount(
                    unspecified,
                  ),
                ),
              ],
            ),
        ],
      );
    },
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
    builder: (context, _) => AppScaffold(
      title: context.l10n.providerUiChoose,
      largeTitle: false,
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
  );
}

/// Grouped provider choices: confirmed providers, "new provider" and, when
/// allowed, the explicit "unspecified" (manual only) row.
class _ProviderChoices extends StatelessWidget {
  const _ProviderChoices({
    required this.ledger,
    required this.allowUnspecified,
    required this.enabled,
    required this.onSelected,
    required this.onAdd,
    this.header,
  });
  final LedgerController ledger;
  final bool allowUnspecified, enabled;
  final ValueChanged<ProviderSelection> onSelected;
  final VoidCallback onAdd;
  final String? header;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppSection(
        header: header,
        topSpacing: header == null ? 8 : null,
        footer: context.l10n.providerUiChooseHelp,
        children: [
          for (final provider in ledger.cloud.providers)
            AppRow(
              key: ValueKey('choose-provider-${provider.id}'),
              leading: ProviderAvatar(name: provider.name),
              title: provider.name,
              subtitle: provider.needsReview
                  ? context.l10n.providerUiNeedsReview
                  : _providerSummary(context, ledger, provider),
              trailing: provider.needsReview
                  ? StatusPill(
                      context.l10n.uiCloudNeedsReviewPill,
                      tone: AppTone.amber,
                    )
                  : null,
              enabled: enabled && !provider.needsReview,
              onTap: enabled && !provider.needsReview
                  ? () => onSelected(ProviderSelection(provider))
                  : null,
            ),
          AppRow(
            key: const ValueKey('choose-provider-add'),
            icon: Icons.add_rounded,
            iconColor: AppTints.green,
            title: context.l10n.providerUiAdd,
            enabled: enabled,
            onTap: enabled ? onAdd : null,
          ),
        ],
      ),
      if (allowUnspecified)
        AppSection(
          children: [
            AppRow(
              key: const ValueKey('choose-provider-unspecified'),
              leading: const ProviderAvatar(name: null),
              title: context.l10n.providerUiUnspecified,
              subtitle: context.l10n.providerUiUnspecifiedHelp,
              enabled: enabled,
              onTap: enabled
                  ? () => onSelected(const ProviderSelection(null))
                  : null,
            ),
          ],
        ),
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

  Future<void> menu(
    LedgerController ledger,
    ProviderRecord provider,
    bool editable,
  ) => showAppActionMenu<void>(
    context,
    title: provider.name,
    actions: [
      AppMenuAction(
        label: context.l10n.providerUiRename,
        onPressed: editable
            ? () => open(() async {
                await editProvider(context, ledger, provider: provider);
              })
            : null,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger,
    builder: (context, _) {
      final ledger = widget.ledger;
      final provider = ledger.cloud.providers
          .where((p) => p.id == (resolvedProviderId ?? widget.providerId))
          .firstOrNull;
      if (provider == null) {
        return AppScaffold(
          title: context.l10n.providerUiDetails,
          largeTitle: false,
          children: [
            _ProviderNotices(ledger),
            CloudNotice(
              context.l10n.providerUiUnavailable,
              tone: AppTone.amber,
            ),
          ],
        );
      }
      final accounts = ledger.cloud.accounts
          .where((a) => a.businessProviderId == provider.id)
          .toList();
      final servers = ledger.records
          .where((s) => s.providerId == provider.id)
          .toList();
      final editable = !opening && _canEdit(ledger);
      final pins = [
        for (final account in accounts)
          if (account.pinnedServerId != null)
            context.l10n.providerUiPinnedHelp(
              ledger.byId(account.pinnedServerId!)?.name ??
                  account.pinnedServerId!,
            ),
      ];
      return AppScaffold(
        title: context.l10n.providerUiDetails,
        largeTitle: false,
        actions: [
          AppNavButton.icon(
            Icons.more_horiz,
            key: const ValueKey('provider-menu'),
            tooltip: context.l10n.serverMoreActions,
            onPressed: editable ? () => menu(ledger, provider, editable) : null,
          ),
        ],
        children: [
          _ProviderNotices(ledger),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                ProviderAvatar(name: provider.name, size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.name,
                        style: TextStyle(
                          fontSize: 22,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: context.palette.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _providerSummary(context, ledger, provider),
                        style: TextStyle(
                          fontSize: 14,
                          color: context.palette.text2,
                        ),
                      ),
                      if (provider.needsReview)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: StatusPill(
                            context.l10n.uiCloudNeedsReviewPill,
                            tone: AppTone.amber,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (provider.needsReview)
            CloudNotice(context.l10n.providerUiReviewHelp, tone: AppTone.amber),
          AppSection(
            header: context.l10n.providerUiInstances,
            footerWidget: pins.isEmpty
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final pin in pins)
                        Text(pin, style: context.footnoteStyle),
                    ],
                  ),
            children: [
              if (accounts.isEmpty)
                AppRow(
                  title: context.l10n.providerUiNoInstances,
                  enabled: false,
                ),
              for (final account in accounts) ...[
                AppRow(
                  key: ValueKey('provider-instance-${account.id}'),
                  icon: Icons.cloud_outlined,
                  iconColor: AppTints.purple,
                  title: account.alias,
                  subtitle:
                      '${cloudProviderName(account.adapterType)} · '
                      '${context.l10n.providerUiLinkedCount(ledger.cloud.bindings.where((b) => b.accountId == account.id).length)}\n'
                      '${account.endpoint}',
                  trailing: StatusPill(
                    _scopeLabel(context, account),
                    tone: _scopeTone(account),
                  ),
                  chevron: true,
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
                  onLongPress: provider.needsReview || !editable
                      ? null
                      : () => open(() async {
                          await cloudAccountMenu(context, ledger, account);
                        }),
                ),
                if (provider.needsReview)
                  AppRow(
                    key: ValueKey('confirm-provider-${account.id}'),
                    icon: Icons.fact_check_outlined,
                    iconColor: AppTints.orange,
                    title: context.l10n.providerUiConfirmOwnership,
                    enabled: editable,
                    chevron: true,
                    onTap: editable
                        ? () => open(() async {
                            final saved = await confirmAdapterProviderOwnership(
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
                  ),
              ],
              if (!provider.needsReview)
                AppRow(
                  key: const ValueKey('provider-add-instance'),
                  center: true,
                  title: context.l10n.providerUiAddInstance,
                  enabled: editable,
                  onTap: editable
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
                ),
            ],
          ),
          AppSection(
            header: context.l10n.providerUiDevices,
            footer: context.l10n.cloudReadOnlyBoundary,
            children: [
              if (servers.isEmpty)
                AppRow(title: context.l10n.providerUiNoDevices, enabled: false),
              for (final server in servers)
                AppRow(
                  key: ValueKey('provider-device-${server.id}'),
                  icon: Icons.dns_outlined,
                  iconColor: AppTints.slate,
                  title: server.name,
                  subtitle: [
                    if (server.archived) context.l10n.archivedRecords,
                    server.host,
                    ledger.cloud.bindingFor(server.id) == null
                        ? context.l10n.providerUiManualDevice
                        : context.l10n.providerUiLinkedDevice,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  chevron: true,
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
              if (!provider.needsReview)
                AppRow(
                  key: const ValueKey('provider-add-server'),
                  center: true,
                  title: context.l10n.serverAdd,
                  enabled: editable,
                  onTap: editable
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
                ),
            ],
          ),
        ],
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
  final confirmed = await showAppConfirm(
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
  final confirmed = await showAppConfirm(
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

/// Unified add flow, laid out like the demo's add sheet: a provider section
/// (explicit choice first, then a single picker row) and two method cards.
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
      final name = provider?.name ?? selected?.name;
      return PopScope<String>(
        canPop: finishing || selection == null || widget.provider != null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !opening) setState(() => selection = null);
        },
        child: AppScaffold(
          title: context.l10n.serverAdd,
          largeTitle: false,
          children: [
            _ProviderNotices(widget.ledger),
            if (selection == null)
              _ProviderChoices(
                ledger: widget.ledger,
                allowUnspecified: true,
                enabled: enabled,
                header: context.l10n.uiCloudOwnerSection,
                onAdd: addProvider,
                onSelected: (value) => setState(() => selection = value),
              )
            else ...[
              AppSection(
                header: context.l10n.uiCloudOwnerSection,
                topSpacing: 8,
                children: [
                  AppRow(
                    key: const ValueKey('add-change-provider'),
                    leading: ProviderAvatar(name: name),
                    title: name ?? context.l10n.providerUiUnspecified,
                    subtitle: name == null
                        ? context.l10n.providerUiUnspecifiedHelp
                        : context.l10n.providerUiSelected,
                    chevron: widget.provider == null,
                    onTap: widget.provider == null && enabled
                        ? () => setState(() => selection = null)
                        : null,
                  ),
                ],
              ),
              if (!available)
                CloudNotice(
                  context.l10n.providerUiUnavailable,
                  tone: AppTone.amber,
                ),
              AppSection(
                header: context.l10n.uiCloudMethodSection,
                children: [
                  AppRow(
                    key: const ValueKey('add-manual'),
                    leading: const AppIconSquare(
                      icon: Icons.edit_outlined,
                      color: AppTints.blue,
                      size: 38,
                    ),
                    title: context.l10n.serverManualAdd,
                    subtitle: context.l10n.providerUiManualHelp,
                    chevron: true,
                    enabled: enabled && available,
                    onTap: enabled && available ? manual : null,
                  ),
                ],
              ),
              AppSection(
                topSpacing: 12,
                footer: context.l10n.uiCloudAddFooter,
                children: [
                  AppRow(
                    key: const ValueKey('add-automatic'),
                    leading: const AppIconSquare(
                      icon: Icons.cloud_download_outlined,
                      color: AppTints.purple,
                      size: 38,
                    ),
                    title: context.l10n.providerUiAutomatic,
                    subtitle: provider == null
                        ? context.l10n.providerUiAutoNeedsProvider
                        : context.l10n.providerUiAutomaticHelp,
                    chevron: provider != null,
                    enabled: enabled && available && provider != null,
                    onTap: enabled && available && provider != null
                        ? () => automatic(provider)
                        : null,
                  ),
                ],
              ),
            ],
          ],
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
      return AppScaffold(
        title: context.l10n.providerUiChooseInstance,
        largeTitle: false,
        children: [
          _ProviderNotices(widget.ledger),
          AppSection(
            header: current?.name ?? widget.provider.name,
            footer: context.l10n.providerUiInstanceChoiceHelp,
            children: [
              for (final account in accounts) ...[
                () {
                  // A singleton pin survives unlinking. Zero current bindings
                  // does not mean these credentials can authorize a new local
                  // device.
                  final selectable =
                      enabled &&
                      account.authScope != AdapterAuthScope.unknown &&
                      !(account.authScope == AdapterAuthScope.singleDevice &&
                          account.pinnedServerId != null);
                  return AppRow(
                    key: ValueKey('choose-instance-${account.id}'),
                    icon: Icons.cloud_outlined,
                    iconColor: AppTints.purple,
                    title: account.alias,
                    subtitle:
                        '${cloudProviderName(account.adapterType)} · ${context.l10n.providerUiLinkedCount(widget.ledger.cloud.bindings.where((b) => b.accountId == account.id).length)}\n'
                        '${account.authScope == AdapterAuthScope.singleDevice && account.pinnedServerId != null ? context.l10n.providerUiPinnedHelp(widget.ledger.byId(account.pinnedServerId!)?.name ?? account.pinnedServerId!) : account.endpoint}',
                    trailing: StatusPill(
                      _scopeLabel(context, account),
                      tone: _scopeTone(account),
                    ),
                    chevron: selectable,
                    onTap: selectable ? () => open(account) : null,
                  );
                }(),
                if (account.pinnedServerId != null &&
                    widget.ledger.byId(account.pinnedServerId!) != null)
                  AppRow(
                    key: ValueKey('pinned-device-${account.id}'),
                    icon: Icons.dns_outlined,
                    iconColor: AppTints.slate,
                    title: context.l10n.serverDetails,
                    chevron: true,
                    onTap: opening ? null : () => openPinned(account),
                  ),
              ],
              AppRow(
                key: const ValueKey('choose-instance-add'),
                center: true,
                title: context.l10n.providerUiAddInstance,
                enabled: enabled,
                onTap: enabled ? () => open(null) : null,
              ),
            ],
          ),
        ],
      );
    },
  );
}
