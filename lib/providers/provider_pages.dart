import 'package:flutter/cupertino.dart'
    show CupertinoAlertDialog, CupertinoDialogAction, showCupertinoDialog;
import 'package:flutter/material.dart';

import '../core/ui/ui.dart';
import '../data/ledger_store.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../servers/ledger_controller.dart';
import '../servers/refresh_failure_notice.dart';
import '../servers/server_detail.dart';
import '../servers/server_form.dart';
import '../servers/server_record.dart';
import 'provider_record.dart';

/// A null route result means cancellation; a null [provider] is an explicit
/// choice to add a record without a business provider.
class ProviderSelection {
  const ProviderSelection(this.provider);
  final ProviderRecord? provider;
}

String serverProviderLabel(
  BuildContext context,
  LedgerController ledger,
  ServerRecord server,
) => ledger.providerFor(server)?.name ?? context.l10n.providerUiUnspecified;

String serverProviderMark(LedgerController ledger, ServerRecord server) {
  final name = ledger.providerFor(server)?.name;
  return name == null || name.isEmpty
      ? 'VPS'
      : name.runes.take(2).map(String.fromCharCode).join().toUpperCase();
}

bool _canEdit(LedgerController ledger) => ledger.canMutate;

String _providerSummary(
  BuildContext context,
  LedgerController ledger,
  ProviderRecord provider,
) => context.l10n.r6CatProviderSummary(
  ledger.records.where((s) => s.providerId == provider.id).length,
);

/// Shared status for all provider routes. A successful write followed by a
/// failed reload stays committed, and cannot be submitted a second time.
class _ProviderNotices extends StatelessWidget {
  const _ProviderNotices(this.ledger);
  final LedgerController ledger;
  @override
  Widget build(BuildContext context) => ledger.refreshFailed
      ? Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: RefreshFailureNotice(controller: ledger),
        )
      : const SizedBox.shrink();
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
      catalogId: old?.catalogId,
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
          widget.ledger.providers
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
              Material(
                color: p.fill,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: TextField(
                    key: const ValueKey('provider-name'),
                    controller: name,
                    autofocus: true,
                    enabled: !saving,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.words,
                    cursorColor: p.primary,
                    style: TextStyle(fontSize: 16, color: p.text),
                    decoration: InputDecoration(
                      hintText: context.l10n.providerUiName,
                      counterText: '',
                      semanticCounterText: context.l10n.providerUiName,
                    ),
                    onSubmitted: (_) => save(),
                  ),
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
            child: Text(saving ? context.l10n.saving : context.l10n.save),
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
      final providers = ledger.providers;
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

/// Grouped provider choices: providers, "new provider" and, when allowed, the
/// explicit "unspecified" row.
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
      AppSection(
        topSpacing: 8,
        footer: context.l10n.providerUiChooseHelp,
        children: [
          for (final provider in ledger.providers)
            AppRow(
              key: ValueKey('choose-provider-${provider.id}'),
              leading: ProviderAvatar(name: provider.name),
              title: provider.name,
              subtitle: _providerSummary(context, ledger, provider),
              enabled: enabled,
              onTap: enabled
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
      final provider = ledger.providers
          .where((p) => p.id == widget.providerId)
          .firstOrNull;
      if (provider == null) {
        return AppScaffold(
          title: context.l10n.providerUiDetails,
          largeTitle: false,
          children: [
            _ProviderNotices(ledger),
            AppBanner(
              text: context.l10n.providerUiUnavailable,
              tone: AppTone.amber,
              icon: Icons.error_outline_rounded,
            ),
          ],
        );
      }
      final servers = ledger.records
          .where((s) => s.providerId == provider.id)
          .toList();
      final editable = !opening && _canEdit(ledger);
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
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppSection(
            header: context.l10n.providerUiDevices,
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
              AppRow(
                key: const ValueKey('provider-add-server'),
                center: true,
                title: context.l10n.serverAdd,
                enabled: editable,
                onTap: editable
                    ? () => open(() async {
                        final id = await showAppModal<String>(
                          context,
                          builder: (_) => ServerForm(
                            controller: ledger,
                            businessProvider: provider,
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

/// Add flow: choose the provider, then fill the form.
class AddServerPage extends StatefulWidget {
  const AddServerPage({super.key, required this.ledger});
  final LedgerController ledger;
  @override
  State<AddServerPage> createState() => _AddServerPageState();
}

class _AddServerPageState extends State<AddServerPage> {
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

  Future<void> manual(ProviderRecord? provider) async {
    if (opening || finishing || !_canEdit(widget.ledger)) return;
    setState(() => opening = true);
    try {
      final id = await showAppModal<String>(
        context,
        builder: (_) =>
            ServerForm(controller: widget.ledger, businessProvider: provider),
      );
      if (id != null && mounted) finish(id);
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> addProvider() async {
    if (opening || finishing || !_canEdit(widget.ledger)) return;
    setState(() => opening = true);
    final created = await editProvider(context, widget.ledger);
    if (!mounted) return;
    setState(() => opening = false);
    if (created != null) await manual(created);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger,
    builder: (context, _) {
      final enabled = !opening && !finishing && _canEdit(widget.ledger);
      return AppScaffold(
        title: context.l10n.serverAdd,
        largeTitle: false,
        children: [
          _ProviderNotices(widget.ledger),
          _ProviderChoices(
            ledger: widget.ledger,
            allowUnspecified: true,
            enabled: enabled,
            onAdd: addProvider,
            onSelected: (value) => manual(value.provider),
          ),
        ],
      );
    },
  );
}
