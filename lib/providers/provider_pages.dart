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
import 'package_widgets.dart';
import 'provider_catalog.dart';
import 'provider_lists.dart';
import 'provider_record.dart';

export 'provider_lists.dart'
    show ProvidersPage, AllProvidersPage, PackageListPage;

/// What the user picked as the provider of a server. A null route result
/// means cancellation. [provider] is the existing local provider; [catalog] is
/// the catalog provider it belongs to (or, with a null [provider], the catalog
/// provider whose local provider is created when the server is saved). Both
/// null is the explicit "no provider" choice.
class ProviderSelection {
  const ProviderSelection(this.provider, {this.catalog});
  final ProviderRecord? provider;
  final CatalogProvider? catalog;

  bool get isPending => provider == null && catalog != null;
  String? get name => provider?.name ?? catalog?.name;
  CatalogProviderRef? get pendingRef => isPending
      ? CatalogProviderRef(catalogId: catalog!.id, name: catalog!.name)
      : null;
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
) {
  final servers = context.l10n.r6CatProviderSummary(
    ledger.providerUsage[provider.id]?.servers.length ?? 0,
  );
  final catalog = ledger.catalogProviderFor(provider);
  return catalog == null || catalog.packages.isEmpty
      ? servers
      : '$servers · ${context.l10n.r6CatPackageCount(catalog.packages.length)}';
}

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
      CatalogFailureBanner(ledger: ledger),
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

/// A package row: name with its optional "Default" / "In use · N" pills, then
/// the price and hardware summary. The pills sit beside the name and wrap
/// below it on narrow screens or large text instead of squeezing the row.
AppRow packageRow(
  BuildContext context, {
  required Key key,
  required CatalogPackage package,
  Widget? trailing,
  bool chevron = false,
  int useCount = 0,
  VoidCallback? onTap,
}) {
  final l10n = context.l10n;
  final p = context.palette;
  return AppRow.custom(
    key: key,
    leading: chevron
        ? const AppIconSquare(
            icon: Icons.inventory_2_outlined,
            color: AppTints.purple,
          )
        : null,
    trailing: trailing,
    chevron: chevron,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                package.name,
                style: TextStyle(fontSize: 16, height: 1.3, color: p.text),
              ),
              if (package.isDefault) StatusPill(l10n.r6CatDefaultPill),
              if (useCount > 0)
                StatusPill(l10n.r8InUseCount(useCount), tone: AppTone.blue),
            ],
          ),
          if (packageSummaryLine(l10n, package).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                packageSummaryLine(l10n, package),
                style: TextStyle(fontSize: 13, height: 1.35, color: p.text2),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Opens the new-server form for [selection] (and [package]) as a page sheet
/// and returns the id of the saved server.
Future<String?> openServerForm(
  BuildContext context,
  LedgerController ledger,
  ProviderSelection selection, {
  CatalogPackage? package,
}) => showAppModal<String>(
  context,
  builder: (_) => ServerForm(
    controller: ledger,
    businessProvider: selection.provider,
    catalogProvider: selection.isPending ? selection.catalog : null,
    initialPackage: package,
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
  @override
  void initState() {
    super.initState();
    widget.ledger.loadCatalog();
  }

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
          ? ledger.catalogProviderFor(local)
          : ledger.catalog.provider(widget.catalogId ?? '');
      final name = local?.name ?? catalog?.name;
      if (name == null) {
        return AppScaffold(
          title: l10n.providerUiDetails,
          largeTitle: false,
          children: [
            ProviderNotices(ledger),
            if (widget.providerId != null || ledger.catalogLoaded)
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
      // Only what is in use is listed here; the rest of a catalog lives behind
      // "All Packages".
      final byPackage = <String, List<ServerRecord>>{};
      final noPackage = <ServerRecord>[];
      for (final server in servers) {
        if (server.packageId == null) {
          noPackage.add(server);
        } else {
          (byPackage[server.packageId!] ??= []).add(server);
        }
      }
      CatalogPackage? packageOf(String id) =>
          catalog?.package(id) ??
          byPackage[id]!.map(ledger.packageSnapshotFor).nonNulls.firstOrNull;
      final inUse =
          [
            for (final id in byPackage.keys)
              if (packageOf(id) != null) (packageOf(id)!, byPackage[id]!),
          ]..sort(
            (a, b) =>
                a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase()),
          );
      final editable = !opening && _canEdit(ledger);
      final selection = ProviderSelection(local, catalog: catalog);
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
                            ? l10n.r6CatPackageCount(
                                catalog?.packages.length ?? 0,
                              )
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
          if (inUse.isNotEmpty)
            AppSection(
              header: l10n.r8PackagesInUse,
              children: [
                for (final (package, linked) in inUse)
                  packageRow(
                    context,
                    key: ValueKey('provider-package-${package.id}'),
                    package: package,
                    chevron: true,
                    trailing: Text(
                      l10n.r6CatProviderSummary(linked.length),
                      style: TextStyle(
                        fontSize: 13,
                        color: context.palette.text2,
                      ),
                    ),
                    onTap: opening
                        ? null
                        : () => open(() async {
                            await Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PackageDetailsPage(
                                  ledger: ledger,
                                  packageId: package.id,
                                ),
                              ),
                            );
                          }),
                  ),
              ],
            ),
          if (catalog != null)
            AppSection(
              footer: catalog.packages.isEmpty ? l10n.r6CatNoPackagesYet : null,
              children: [
                if (catalog.packages.isNotEmpty)
                  AppRow(
                    key: const ValueKey('provider-all-packages'),
                    icon: Icons.inventory_2_outlined,
                    iconColor: AppTints.purple,
                    title: l10n.r8AllPackages,
                    value: '${catalog.packages.length}',
                    chevron: true,
                    onTap: opening
                        ? null
                        : () => open(() async {
                            await Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PackageListPage(
                                  ledger: ledger,
                                  catalogId: catalog.id,
                                ),
                              ),
                            );
                          }),
                  )
                else
                  AppRow(title: l10n.r6CatNoPackagesYet, enabled: false),
              ],
            ),
          if (noPackage.isNotEmpty)
            AppSection(
              header: catalog != null && catalog.packages.isNotEmpty
                  ? l10n.r6CatNoPackageRow
                  : l10n.providerUiDevices,
              children: [
                for (final server in noPackage)
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

/// One package: specification, price, the servers linked to it and, when the
/// catalog changed since a server chose it, what that server saved.
class PackageDetailsPage extends StatefulWidget {
  const PackageDetailsPage({
    super.key,
    required this.ledger,
    required this.packageId,
    this.server,
  });
  final LedgerController ledger;
  final String packageId;

  /// The server this page was opened from; its saved snapshot is compared
  /// with the current catalog.
  final ServerRecord? server;
  @override
  State<PackageDetailsPage> createState() => _PackageDetailsPageState();
}

class _PackageDetailsPageState extends State<PackageDetailsPage> {
  bool opening = false;
  @override
  void initState() {
    super.initState();
    widget.ledger.loadCatalog();
  }

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
      final l10n = context.l10n;
      final linked = ledger.serversForPackage(widget.packageId);
      final current = ledger.catalog.package(widget.packageId);
      final from = widget.server == null
          ? null
          : ledger.byId(widget.server!.id) ?? widget.server;
      // An unlisted package is still described by what servers saved.
      final saved =
          (from?.packageId == widget.packageId
              ? ledger.packageSnapshotFor(from!)
              : null) ??
          linked.map(ledger.packageSnapshotFor).nonNulls.firstOrNull;
      final shown = current ?? saved;
      if (shown == null) {
        return AppScaffold(
          title: l10n.r6CatPackageDetails,
          largeTitle: false,
          children: [
            ProviderNotices(ledger),
            if (ledger.catalogLoaded)
              AppBanner(
                text: l10n.providerUiUnavailable,
                tone: AppTone.amber,
                icon: Icons.error_outline_rounded,
              ),
          ],
        );
      }
      final catalogProvider = ledger.catalog.provider(shown.providerId);
      final local = ledger.localProviderForCatalog(shown.providerId);
      final providerName = local?.name ?? catalogProvider?.name;
      final state = current == null
          ? (ledger.catalogLoaded
                ? PackageCatalogState.removed
                : PackageCatalogState.unknown)
          : (saved != null && !current.sameSpecAs(saved)
                ? PackageCatalogState.changed
                : PackageCatalogState.same);
      final showSaved =
          state == PackageCatalogState.changed &&
          from != null &&
          ledger.packageStateFor(from) == PackageCatalogState.changed;
      final canAdd =
          !opening &&
          _canEdit(ledger) &&
          current != null &&
          catalogProvider != null;
      return AppScaffold(
        title: l10n.r6CatPackageDetails,
        largeTitle: false,
        children: [
          ProviderNotices(ledger),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shown.name,
                  key: const ValueKey('package-name'),
                  style: TextStyle(
                    fontSize: 22,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: context.palette.text,
                  ),
                ),
                if (providerName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      providerName,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.palette.text2,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (current?.isDefault ?? false)
                        StatusPill(l10n.r6CatDefaultPill),
                      ?packageStatePill(l10n, state),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (state == PackageCatalogState.changed)
            AppBanner(
              key: const ValueKey('package-changed-note'),
              text: l10n.r6CatChangedNotice,
              tone: AppTone.amber,
              icon: Icons.info_outline_rounded,
            ),
          if (state == PackageCatalogState.removed)
            AppBanner(
              key: const ValueKey('package-removed-note'),
              text: l10n.r6CatRemovedNotice,
              icon: Icons.info_outline_rounded,
            ),
          AppSection(
            header: showSaved ? l10n.r6CatCurrentValues : l10n.r6CatSpecs,
            children: packageSpecRows(context, shown),
          ),
          if (showSaved)
            AppSection(
              header: l10n.r6CatSavedValues,
              children: packageSpecRows(context, saved!),
            ),
          AppSection(
            header: l10n.r6CatLinkedServers,
            footer: l10n.r6CatLinkedFooter,
            children: [
              if (linked.isEmpty)
                AppRow(title: l10n.r6CatNoLinkedServers, enabled: false),
              for (final server in linked)
                AppRow(
                  key: ValueKey('package-server-${server.id}'),
                  icon: Icons.dns_outlined,
                  iconColor: AppTints.slate,
                  title: server.name,
                  subtitle: [
                    if (server.archived) l10n.archivedRecords,
                    server.primaryAddress,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  trailing: packageStatePill(
                    l10n,
                    ledger.packageStateFor(server),
                  ),
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
          if (current != null && catalogProvider != null)
            AppSection(
              children: [
                AppRow(
                  key: const ValueKey('package-add-server'),
                  center: true,
                  title: l10n.r6CatAddServerWithPackage,
                  enabled: canAdd,
                  onTap: canAdd
                      ? () => open(() async {
                          final id = await openServerForm(
                            context,
                            ledger,
                            ProviderSelection(local, catalog: catalogProvider),
                            package: current,
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
