import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../connections/connection_pages.dart';
import '../core/app_theme.dart' show showFailure;
import '../core/ui/ui.dart';
import '../finance/finance_math.dart';
import '../finance/payment_pages.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/directory_widgets.dart';
import '../providers/provider_pages.dart';
import 'ledger_controller.dart';
import 'refresh_failure_notice.dart';
import 'server_detail.dart';
import 'server_form.dart';
import 'server_record.dart';

Future<void> addServer(
  BuildContext context,
  LedgerController controller,
) async {
  // Straight to the form: the provider and package are rows inside it.
  final id = await showAppModal<String>(
    context,
    builder: (_) => ServerForm(controller: controller),
  );
  if (id != null && context.mounted && controller.byId(id) != null) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ServerDetail(controller: controller, id: id),
      ),
    );
  }
}

/// Confirms, archives [record] and offers the once-only undo toast.
///
/// Same copy and flow as the detail page. [popOnSuccess] closes the calling
/// page (the detail page) after the archive committed.
Future<void> confirmAndArchiveServer(
  BuildContext context,
  LedgerController controller,
  ServerRecord record, {
  bool popOnSuccess = false,
}) async {
  // The list row that started this may be gone once the archive refreshes.
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showAppConfirm(
    context,
    title: LocalizedText((l10n) => l10n.serverArchiveQuestion),
    message: LocalizedText((l10n) => l10n.serverArchiveHelp(record.name)),
    action: LocalizedText((l10n) => l10n.serverArchiveLocal),
    dangerous: true,
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  try {
    final token = await controller.mutate(
      () => controller.store.archive(record),
    );
    final canUndo = !controller.refreshFailed;
    if (popOnSuccess && context.mounted) {
      Navigator.pop(context);
    }
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        // The standard action remains persistent and once-only even though
        // it lives in localized content so an open/queued label can rebuild.
        persist: canUndo,
        content: Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.serverArchived),
              if (canUndo)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: SnackBarAction(
                    label: context.l10n.serverUndo,
                    onPressed: () async {
                      try {
                        await controller.mutate(
                          () => controller.store.undoArchive(token),
                        );
                      } catch (_) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Builder(
                              builder: (context) =>
                                  Text(context.l10n.serverUndoArchiveFailed),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  } catch (error) {
    if (context.mounted) {
      showFailure(context, error);
    }
  }
}

String _sortLabel(AppLocalizations l10n, ServerSort sort) => switch (sort) {
  ServerSort.favorites => l10n.serverSortFavorites,
  ServerSort.due => l10n.serverSortDue,
  ServerSort.name => l10n.serverSortName,
  ServerSort.updated => l10n.serverSortUpdated,
};

class ServerList extends StatefulWidget {
  const ServerList({super.key, required this.controller});
  final LedgerController controller;
  @override
  State<ServerList> createState() => _ServerListState();
}

class _ServerListState extends State<ServerList> {
  late final TextEditingController search;
  LedgerController get c => widget.controller;
  bool openingCloud = false;
  bool openingAdd = false;
  Future<void> openAdd() async {
    if (openingAdd) return;
    openingAdd = true;
    try {
      await addServer(context, c);
    } finally {
      openingAdd = false;
    }
  }

  Future<void> openProviders() async {
    if (openingCloud) {
      return;
    }
    openingCloud = true;
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => ProvidersPage(ledger: c)),
      );
    } finally {
      openingCloud = false;
    }
  }

  @override
  void initState() {
    super.initState();
    search = TextEditingController(text: c.search);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    if (c.busy) return;
    try {
      await c.refresh();
      if (mounted) {
        showAppToast(context, context.l10n.serverReloadedLocal);
      }
    } catch (error) {
      if (mounted) {
        showFailure(context, error);
      }
    }
  }

  Future<void> loadDemo() async {
    final ok = await showAppConfirm(
      context,
      title: LocalizedText((l10n) => l10n.serverLoadDemoQuestion),
      message: LocalizedText((l10n) => l10n.serverLoadDemoHelp),
      action: LocalizedText((l10n) => l10n.serverLoadDemo),
    );
    if (!ok || !mounted) return;
    try {
      await c.mutate(c.store.loadDemo);
    } catch (error) {
      if (mounted) {
        showFailure(context, error);
      }
    }
  }

  Future<void> openFilters() async {
    final result = await showAppSheet<_FilterResult>(
      context,
      title: context.l10n.serverFilterTitle,
      builder: (_) => _FilterSheet(controller: c),
    );
    if (result == null) return;
    c.updateFilters(
      category: ServerFilter.all,
      due: result.due,
      order: result.sort,
    );
    c.setGroup(result.group);
  }

  Future<void> openSort() async {
    final picked = await showAppSheet<ServerSort>(
      context,
      title: context.l10n.serverSort,
      builder: (sheetContext) {
        final p = sheetContext.palette;
        return AppSection(
          topSpacing: 4,
          children: [
            for (final sort in ServerSort.values)
              AppRow(
                title: _sortLabel(sheetContext.l10n, sort),
                trailing: sort == c.sort
                    ? Icon(Icons.check_rounded, size: 22, color: p.primary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, sort),
              ),
          ],
        );
      },
    );
    if (picked != null) {
      c.updateFilters(order: picked);
    }
  }

  void selectCategory(ServerFilter category) {
    c.setGroup(null);
    c.updateFilters(category: category);
  }

  void toggleGroup(String id) {
    c.updateFilters(category: ServerFilter.all);
    c.setGroup(c.groupFilter == id ? null : id);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final l10n = context.l10n;
      final all = c.active;
      final empty = all.isEmpty && c.records.isEmpty;
      return AppScaffold(
        title: l10n.servers,
        subtitle: l10n.serverLedgerCount(all.length.toString()),
        actions: [
          AppNavButton.icon(
            Icons.business_outlined,
            key: const ValueKey('manage-providers'),
            tooltip: l10n.providerUiTitle,
            onPressed: openProviders,
          ),
          AppNavButton.icon(
            Icons.add_rounded,
            key: const ValueKey('add-server'),
            tooltip: l10n.serverAdd,
            onPressed: c.canMutate ? openAdd : null,
          ),
        ],
        onRefresh: reload,
        children: [
          if (c.refreshFailed) RefreshFailureNotice(controller: c),
          if (empty) ..._emptyLedger(context) else ..._ledger(context, all),
        ],
      );
    },
  );

  List<Widget> _emptyLedger(BuildContext context) {
    final l10n = context.l10n;
    return [
      AppEmptyState(
        icon: Icons.dns_outlined,
        title: l10n.serverFirstTitle,
        message: l10n.serverFirstDescription,
        actions: [
          AppButton(
            label: l10n.serverAddFirst,
            icon: Icons.add_rounded,
            onPressed: c.canMutate ? openAdd : null,
          ),
          AppButton(
            label: l10n.serverViewDemo,
            kind: AppButtonKind.plain,
            onPressed: c.canMutate ? loadDemo : null,
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
        child: Text(
          l10n.serverManualStartHelp,
          textAlign: TextAlign.center,
          style: context.footnoteStyle,
        ),
      ),
    ];
  }

  List<Widget> _ledger(BuildContext context, List<ServerRecord> all) {
    final l10n = context.l10n;
    final p = context.palette;
    final visible = c.visible;
    final pending = all.where(c.isPending).toList();
    final overdue = pending.where((s) => c.dueIn(s)! < 0).length;
    final groups = c.groups
        .where((g) => all.any((s) => s.groupId == g.id))
        .toList();
    final filterCount =
        (c.groupFilter != null ? 1 : 0) +
        (c.dueFilter != DueFilter.all ? 1 : 0);
    final showStats =
        c.filter == ServerFilter.all &&
        c.groupFilter == null &&
        c.search.isEmpty &&
        c.dueFilter == DueFilter.all;
    final monthly = aggregateAmounts(
      all.map((s) => monthlyAmount(s, c.today)),
      c.fx,
    );
    final big = MediaQuery.textScalerOf(context).scale(14) > 20;
    final title = c.groupFilter != null
        ? c.groupName(c.groupFilter, l10n: l10n)
        : switch (c.filter) {
            ServerFilter.favorites => l10n.serverFavoriteServers,
            ServerFilter.pending => l10n.serverExpiryNeedsCheck,
            ServerFilter.all => l10n.serverAllServers,
          };
    final sectionTitle = Semantics(
      header: true,
      child: Text(
        title,
        maxLines: big ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: p.text,
        ),
      ),
    );
    final sortButton = Tooltip(
      message: l10n.serverSort,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: openSort,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_vert_rounded, size: 18, color: p.primary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _sortLabel(l10n, c.sort),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: p.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return [
      const SizedBox(height: 4),
      AppSearchField(
        key: const ValueKey('server-search'),
        controller: search,
        placeholder: l10n.serverSearchHint,
        onChanged: (value) => c.updateFilters(query: value),
      ),
      AppChipRow(
        children: [
          AppChip(
            label: l10n.serverAll,
            count: all.length,
            selected: c.filter == ServerFilter.all && c.groupFilter == null,
            onTap: () => selectCategory(ServerFilter.all),
          ),
          AppChip(
            label: l10n.serverFavorites,
            count: all.where((s) => s.favorite).length,
            selected:
                c.filter == ServerFilter.favorites && c.groupFilter == null,
            onTap: () => selectCategory(ServerFilter.favorites),
          ),
          AppChip(
            label: l10n.expiryChecks,
            count: pending.length,
            selected: c.filter == ServerFilter.pending && c.groupFilter == null,
            onTap: () => selectCategory(ServerFilter.pending),
          ),
          for (final g in groups)
            AppChip(
              label: g.name,
              selected: c.groupFilter == g.id,
              onTap: () => toggleGroup(g.id),
            ),
          AppChip(
            label: l10n.serverFilterLabel(
              filterCount > 0 ? l10n.serverFilterSelectedSuffix : '',
            ),
            icon: Icons.tune_rounded,
            outlined: true,
            onTap: openFilters,
          ),
        ],
      ),
      if (showStats && all.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AppCard(
            child: AppMetricStrip(
              metrics: [
                AppMetric(
                  label: l10n.serverExpired,
                  value: '$overdue',
                  valueColor: context.palette.red,
                  onTap: () => c.updateFilters(category: ServerFilter.pending),
                ),
                AppMetric(
                  label: l10n.uiServersDueSoon,
                  value: '${pending.length - overdue}',
                  valueColor: context.palette.amber,
                  onTap: () => c.updateFilters(category: ServerFilter.pending),
                ),
                AppMetric(
                  label: l10n.financeMonthlyReference,
                  value: monthly.covered > 0 && monthly.missingFx == 0
                      ? monthly.formatted
                      : '—',
                ),
              ],
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(32, 22, 20, 4),
        child: AppHeaderRow(title: sectionTitle, action: sortButton),
      ),
      if (visible.isEmpty)
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 26, 16, 20),
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 32, color: p.text3),
              const SizedBox(height: 10),
              Text(
                all.isEmpty ? l10n.serverNoUnarchived : l10n.serverNoMatches,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: p.text),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.serverNoMatchesHelp,
                textAlign: TextAlign.center,
                style: context.footnoteStyle,
              ),
              const SizedBox(height: 14),
              AppButton(
                label: l10n.serverClearFilters,
                kind: AppButtonKind.tonal,
                compact: true,
                onPressed: () {
                  search.clear();
                  c.resetFilters();
                },
              ),
            ],
          ),
        )
      else
        AppSection(
          topSpacing: 0,
          dividers: false,
          children: [
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: EdgeInsetsDirectional.only(start: big ? 16 : 70),
                  child: SizedBox(
                    height: .5,
                    child: ColoredBox(color: p.separator),
                  ),
                ),
              ServerRow(
                key: ValueKey('server-row:${visible[i].id}'),
                record: visible[i],
                controller: c,
              ),
            ],
          ],
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(32, 10, 32, 0),
        child: Column(
          children: [
            Text(
              l10n.uiServersRowHint,
              textAlign: TextAlign.center,
              style: context.footnoteStyle,
            ),
          ],
        ),
      ),
    ];
  }
}

class _FilterResult {
  const _FilterResult(this.group, this.due, this.sort);
  final String? group;
  final DueFilter due;
  final ServerSort sort;
}

/// Group / due-status chips and sort rows. Nothing reaches the controller
/// until "Show N" is pressed.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.controller});
  final LedgerController controller;
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? group = widget.controller.groupFilter;
  late DueFilter due = widget.controller.dueFilter;
  late ServerSort sort = widget.controller.sort;

  /// Result count with the pending selection; the controller is restored
  /// synchronously and never notifies.
  int get count {
    final c = widget.controller;
    final savedGroup = c.groupFilter;
    final savedDue = c.dueFilter;
    final savedFilter = c.filter;
    c.groupFilter = group;
    c.dueFilter = due;
    c.filter = ServerFilter.all;
    try {
      return c.visible.length;
    } finally {
      c.groupFilter = savedGroup;
      c.dueFilter = savedDue;
      c.filter = savedFilter;
    }
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 12, 16, 8),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, color: context.palette.text2),
    ),
  );

  Widget _chips(List<Widget> chips) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Wrap(spacing: 8, runSpacing: 8, children: chips),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final c = widget.controller;
    final dues = [
      (DueFilter.all, l10n.serverAllStatuses),
      (DueFilter.overdue, l10n.serverExpired),
      (DueFilter.next30, l10n.serverDueNext30),
      (DueFilter.unknown, l10n.serverCostDateUnknown),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(l10n.serverGroup),
        _chips([
          AppChip(
            label: l10n.serverAllGroups,
            selected: group == null,
            onTap: () => setState(() => group = null),
          ),
          for (final g in c.groups)
            AppChip(
              label: g.name,
              selected: group == g.id,
              onTap: () => setState(() => group = g.id),
            ),
          AppChip(
            label: l10n.ungrouped,
            selected: group == '',
            onTap: () => setState(() => group = ''),
          ),
        ]),
        _label(l10n.serverDueStatus),
        _chips([
          for (final (value, label) in dues)
            AppChip(
              label: label,
              selected: due == value,
              onTap: () => setState(() => due = value),
            ),
        ]),
        AppSection(
          header: l10n.serverSort,
          children: [
            for (final option in ServerSort.values)
              AppRow(
                title: _sortLabel(l10n, option),
                trailing: option == sort
                    ? Icon(Icons.check_rounded, size: 22, color: p.primary)
                    : null,
                onTap: () => setState(() => sort = option),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: l10n.uiServersReset,
                  kind: AppButtonKind.tonal,
                  expand: true,
                  onPressed: () => setState(() {
                    group = null;
                    due = DueFilter.all;
                    sort = ServerSort.favorites;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: l10n.uiServersShowCount(count),
                  expand: true,
                  onPressed: () =>
                      Navigator.pop(context, _FilterResult(group, due, sort)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A ledger row with swipe-to-reveal actions (SSH, favourite, archive) and a
/// long-press action menu.
class ServerRow extends StatefulWidget {
  const ServerRow({super.key, required this.record, required this.controller});
  final ServerRecord record;
  final LedgerController controller;
  @override
  State<ServerRow> createState() => _ServerRowState();
}

class _ServerRowState extends State<ServerRow> {
  static const _buttonWidth = 76.0;
  static const _actionsWidth = _buttonWidth * 3;

  /// Only one row stays swiped open.
  static _ServerRowState? _open;

  /// How far the content is pushed towards the leading edge.
  double extent = 0;
  bool dragging = false;

  /// The action buttons are only built while swiped or animating, so their
  /// colours never bleed through the antialiased corners of the group.
  bool actionsVisible = false;

  ServerRecord get s => widget.record;
  LedgerController get c => widget.controller;
  bool get canSsh => !s.isDemo && !s.archived;

  @override
  void dispose() {
    if (_open == this) _open = null;
    super.dispose();
  }

  void _setExtent(double value, {bool drag = false}) {
    if (!mounted) return;
    setState(() {
      if (value > 0 || drag) {
        actionsVisible = true;
      } else if (extent == 0) {
        actionsVisible = false;
      }
      extent = value;
      dragging = drag;
    });
    if (value > 0) {
      if (_open != this) {
        final previous = _open;
        _open = this;
        previous?._setExtent(0);
      }
    } else if (_open == this) {
      _open = null;
    }
  }

  void close() => _setExtent(0);

  void openDetail() {
    if (extent > 0) return close();
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ServerDetail(controller: c, id: s.id),
      ),
    );
  }

  void openSsh() => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => SshConnectPage(ledger: c, initialServerId: s.id),
    ),
  );

  Future<void> toggleFavorite() async {
    try {
      await c.mutate(() => c.store.setFavorite(s, !s.favorite));
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> copyHost() async {
    try {
      await Clipboard.setData(ClipboardData(text: s.primaryAddress));
      if (mounted) showAppToast(context, context.l10n.serverHostCopied);
    } catch (error) {
      if (mounted) {
        showFailure(
          context,
          error,
          fallbackMessage: LocalizedText((l10n) => l10n.serverCopyHostFailed),
        );
      }
    }
  }

  void recordPayment() => showAppModal<bool>(
    context,
    builder: (_) => PaymentForm(controller: c, server: s),
  );

  Future<void> openMenu() {
    final l10n = context.l10n;
    final canRecordPayment =
        c.canMutate && s.billing == BillingKind.prepaid && canRenew(s);
    return showAppActionMenu<void>(
      context,
      title: s.primaryAddress.isEmpty
          ? s.name
          : '${s.name} · ${s.primaryAddress}',
      actions: [
        if (s.primaryAddress.isNotEmpty)
          AppMenuAction(label: l10n.serverCopyHost, onPressed: copyHost),
        if (canSsh)
          AppMenuAction(label: l10n.serverConnectSsh, onPressed: openSsh),
        if (canRecordPayment)
          AppMenuAction(
            label: l10n.serverRecordPayment,
            onPressed: recordPayment,
          ),
        if (c.canMutate)
          AppMenuAction(
            label: s.favorite
                ? l10n.serverRemoveFavorite
                : l10n.serverSetFavorite,
            onPressed: toggleFavorite,
          ),
        if (c.canMutate)
          AppMenuAction(
            label: l10n.uiServersArchive,
            destructive: true,
            onPressed: () => confirmAndArchiveServer(context, c, s),
          ),
      ],
    );
  }

  Widget _actionButton({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) => SizedBox(
    width: _buttonWidth,
    child: Opacity(
      opacity: onTap == null ? .45 : 1,
      child: Material(
        color: color,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  close();
                  onTap();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: Colors.white),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _actions(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return SizedBox(
      width: _actionsWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _actionButton(
            color: p.primary,
            icon: Icons.terminal_rounded,
            label: 'SSH',
            onTap: canSsh ? openSsh : null,
          ),
          _actionButton(
            color: p.amberSolid,
            icon: s.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
            label: s.favorite
                ? l10n.serverRemoveFavorite
                : l10n.serverFavorites,
            onTap: c.canMutate ? toggleFavorite : null,
          ),
          _actionButton(
            color: p.red,
            icon: Icons.archive_outlined,
            label: l10n.uiServersArchive,
            onTap: c.canMutate
                ? () => confirmAndArchiveServer(context, c, s)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _price(BuildContext context) {
    final p = context.palette;
    final text = s.billing == BillingKind.unknown
        ? '—'
        : s.billingLabelFor(context.l10n);
    final slash = text.indexOf('/');
    final main = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: p.text,
      fontFeatures: kTabularFigures,
    );
    return Text.rich(
      TextSpan(
        style: main,
        children: [
          TextSpan(text: slash < 0 ? text : text.substring(0, slash)),
          if (slash >= 0)
            TextSpan(
              text: text.substring(slash),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: p.text2,
              ),
            ),
        ],
      ),
      textAlign: TextAlign.end,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _content(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final days = c.dueIn(s);
    final due = switch (s.billing) {
      BillingKind.unknown => l10n.serverCostsMissing,
      BillingKind.metered => l10n.serverMeteredBilling,
      BillingKind.prepaid =>
        days == null
            ? l10n.serverDueUnknown
            : days < 0
            ? l10n.serverExpiredDays(-days)
            : days == 0
            ? l10n.serverDueToday
            : l10n.serverDueInDays(days),
    };
    final tone = days == null
        ? AppTone.neutral
        : days < 0
        ? AppTone.red
        : days < 30
        ? AppTone.amber
        : AppTone.neutral;
    final pill = StatusPill(due, tone: tone, dot: tone != AppTone.neutral);
    final big = MediaQuery.textScalerOf(context).scale(14) > 20;
    final provider = c.providerFor(s);
    final titleLine = Text.rich(
      TextSpan(
        children: [
          if (big && s.favorite)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: Icon(Icons.star_rounded, size: 16, color: p.amberSolid),
              ),
            ),
          TextSpan(
            text: s.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: p.text,
            ),
          ),
          if (s.purpose.isNotEmpty)
            TextSpan(
              text: '  ${s.purpose}',
              style: TextStyle(fontSize: 13, color: p.text2),
            ),
        ],
      ),
      maxLines: big ? 2 : 1,
      overflow: TextOverflow.ellipsis,
    );
    final subLine = Row(
      children: [
        Flexible(
          child: Text(
            [
              serverProviderLabel(context, c, s),
              s.region,
            ].where((e) => e.isNotEmpty).join(' · '),
            maxLines: big ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: p.text2),
          ),
        ),
        if (s.isDemo) ...[
          const SizedBox(width: 6),
          StatusPill(l10n.serverDemo),
        ],
      ],
    );
    final avatar = ProviderLogo(
      ledger: c,
      provider: provider,
      mark: provider == null ? null : serverProviderMark(c, s),
      starred: s.favorite,
    );
    Widget body(bool stacked) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleLine,
        const SizedBox(height: 3),
        subLine,
        if (stacked) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [_price(context), pill],
          ),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        // Price and status move below the text on narrow rows or when the
        // text is enlarged; at very large sizes the avatar goes as well.
        final stacked =
            big ||
            box.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(14) > 16;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: big
              ? body(true)
              : Row(
                  children: [
                    avatar,
                    const SizedBox(width: 12),
                    Expanded(child: body(stacked)),
                    if (!stacked) ...[
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 156),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _price(context),
                            const SizedBox(height: 5),
                            pill,
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // Positive logical extent moves the content towards the leading edge.
    final sign = Directionality.of(context) == TextDirection.rtl ? 1.0 : -1.0;
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: !actionsVisible
                  ? const SizedBox.shrink()
                  : ExcludeSemantics(
                      excluding: extent == 0,
                      child: IgnorePointer(
                        ignoring: extent == 0,
                        child: _actions(context),
                      ),
                    ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _setExtent(extent, drag: true),
            onHorizontalDragUpdate: (details) => _setExtent(
              (extent + details.delta.dx * sign).clamp(0.0, _actionsWidth + 30),
              drag: true,
            ),
            onHorizontalDragEnd: (_) =>
                _setExtent(extent > 70 ? _actionsWidth : 0),
            onHorizontalDragCancel: () =>
                _setExtent(extent > 70 ? _actionsWidth : 0),
            child: AnimatedContainer(
              duration: dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              onEnd: () {
                if (extent == 0 && actionsVisible && mounted) {
                  setState(() => actionsVisible = false);
                }
              },
              transform: Matrix4.translationValues(extent * sign, 0, 0),
              child: Material(
                color: p.surface,
                child: InkWell(
                  key: ValueKey('server-${s.id}'),
                  onTap: openDetail,
                  onLongPress: openMenu,
                  child: _content(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
