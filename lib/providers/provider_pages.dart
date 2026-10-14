import 'package:flutter/cupertino.dart'
    show CupertinoAlertDialog, CupertinoDialogAction, showCupertinoDialog;
import 'package:flutter/material.dart';

import '../core/app_theme.dart' show showFailure;
import '../core/ui/ui.dart';
import '../data/ledger_store.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../servers/ledger_controller.dart';
import '../servers/refresh_failure_notice.dart';
import '../servers/server_detail.dart';
import '../servers/server_form.dart';
import '../servers/server_record.dart';
import 'directory_widgets.dart';
import 'provider_record.dart';

export 'provider_lists.dart' show ProvidersPage, AllProvidersPage;

/// What the user picked as the provider of a server. A null route result
/// means cancellation. [provider] is the existing local provider; [catalog] is
/// the catalog provider it belongs to (or, with a null [provider], the catalog
/// provider whose local provider is created when the server is saved). Both
/// null is the explicit "no provider" choice.
class ProviderSelection {
  const ProviderSelection(this.provider, {this.catalog});
  final ProviderRecord? provider;
  final CatalogProviderRef? catalog;

  bool get isPending => provider == null && catalog != null;
  String? get name => provider?.name ?? catalog?.name;
  CatalogProviderRef? get pendingRef => isPending ? catalog : null;
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
  ledger.providerUsage[provider.id]?.servers.length ?? 0,
);

/// Shared status for all provider routes. A successful write followed by a
/// failed reload stays committed, and cannot be submitted a second time.
class ProviderNotices extends StatelessWidget {
  const ProviderNotices(this.ledger, {super.key});
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

/// Asks for the name of a new provider but writes nothing: the draft is saved
/// together with the server that uses it, so cancelling leaves no provider.
Future<ProviderRecord?> draftProvider(
  BuildContext context,
  LedgerController ledger,
) => showCupertinoDialog<ProviderRecord>(
  context: context,
  builder: (_) => _ProviderNameDialog(ledger: ledger, deferred: true),
);

class _ProviderNameDialog extends StatefulWidget {
  const _ProviderNameDialog({
    required this.ledger,
    this.provider,
    this.deferred = false,
  });
  final LedgerController ledger;
  final ProviderRecord? provider;

  /// Return a draft instead of saving it.
  final bool deferred;
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
    if (widget.deferred &&
        widget.ledger.providers.any(
          (p) => p.name.toLowerCase() == value.toLowerCase(),
        )) {
      setState(
        () => error = LocalizedText((l10n) => l10n.providerAlreadyExists),
      );
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
    if (widget.deferred) {
      Navigator.pop(context, provider);
      return;
    }
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

/// Opens the new-server form for [selection] as a page sheet and returns the
/// id of the saved server.
Future<String?> openServerForm(
  BuildContext context,
  LedgerController ledger,
  ProviderSelection selection,
) => showAppModal<String>(
  context,
  builder: (_) => ServerForm(
    controller: ledger,
    businessProvider: selection.provider,
    catalogProvider: selection.isPending ? selection.catalog : null,
  ),
);

class ProviderDetailsPage extends StatefulWidget {
  /// A local provider ([providerId]) or a catalog provider ([catalogId]); a
  /// catalog provider which has not been added yet shows an "Add" action.
  const ProviderDetailsPage({
    super.key,
    required this.ledger,
    this.providerId,
    this.catalogId,
  }) : assert(providerId != null || catalogId != null);
  final LedgerController ledger;
  final String? providerId, catalogId;
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
      final l10n = context.l10n;
      final local = widget.providerId != null
          ? ledger.providers.where((p) => p.id == widget.providerId).firstOrNull
          : ledger.localProviderForCatalog(widget.catalogId!);
      final catalog = local != null
          ? ledger.directoryProviderFor(local)
          : ledger.directory.provider(widget.catalogId ?? '');
      final name = local?.name ?? catalog?.displayName(l10n);
      if (name == null) {
        return AppScaffold(
          title: l10n.providerUiDetails,
          largeTitle: false,
          children: [
            ProviderNotices(ledger),
            if (widget.providerId != null || ledger.directory.loaded)
              AppBanner(
                text: l10n.providerUiUnavailable,
                tone: AppTone.amber,
                icon: Icons.error_outline_rounded,
              ),
          ],
        );
      }
      final servers = local == null
          ? const <ServerRecord>[]
          : ledger.providerUsage[local.id]?.servers ?? const <ServerRecord>[];
      final editable = !opening && _canEdit(ledger);
      final selection = ProviderSelection(local, catalog: catalog?.refIn(l10n));
      return AppScaffold(
        title: l10n.providerUiDetails,
        largeTitle: false,
        actions: [
          if (local != null)
            AppNavButton.icon(
              Icons.more_horiz,
              key: const ValueKey('provider-menu'),
              tooltip: l10n.serverMoreActions,
              onPressed: editable ? () => menu(ledger, local, editable) : null,
            ),
        ],
        children: [
          ProviderNotices(ledger),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                ProviderAvatar(name: name, size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 22,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: context.palette.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        local == null
                            ? l10n.r6CatProviderSummary(0)
                            : _providerSummary(context, ledger, local),
                        style: TextStyle(
                          fontSize: 14,
                          color: context.palette.text2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      StatusPill(
                        key: const ValueKey('provider-badge'),
                        catalog != null
                            ? l10n.r8BadgeCatalog
                            : l10n.r8BadgeCustom,
                        tone: catalog != null ? AppTone.blue : AppTone.neutral,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (local == null) ...[
            AppBanner(
              text: l10n.r6CatCatalogProviderHelp,
              icon: Icons.info_outline_rounded,
            ),
            AppSection(
              topSpacing: 10,
              children: [
                AppRow(
                  key: const ValueKey('provider-add-catalog'),
                  center: true,
                  title: l10n.providerUiAdd,
                  enabled: editable,
                  onTap: editable
                      ? () => open(() async {
                          try {
                            await ledger.mutate(
                              () => ledger.store.addCatalogProvider(
                                selection.pendingRef!,
                              ),
                            );
                          } catch (error) {
                            if (context.mounted) showFailure(context, error);
                          }
                        })
                      : null,
                ),
              ],
            ),
          ],
          if (servers.isNotEmpty)
            AppSection(
              header: l10n.providerUiDevices,
              children: [
                for (final server in servers)
                  AppRow(
                    key: ValueKey('provider-device-${server.id}'),
                    icon: Icons.dns_outlined,
                    iconColor: AppTints.slate,
                    title: server.name,
                    subtitle: [
                      if (server.archived) l10n.archivedRecords,
                      server.primaryAddress,
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
              ],
            ),
          AppSection(
            children: [
              AppRow(
                key: const ValueKey('provider-add-server'),
                center: true,
                title: l10n.serverAdd,
                enabled: editable,
                onTap: editable
                    ? () => open(() async {
                        final id = await openServerForm(
                          context,
                          ledger,
                          selection,
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
