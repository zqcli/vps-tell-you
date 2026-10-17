import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';

import 'package:flutter/material.dart';

import '../core/app_theme.dart' show showFailure;
import '../core/ui/ui.dart';
import '../finance/finance_math.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/provider_pages.dart';
import 'ledger_controller.dart';
import 'refresh_failure_notice.dart';
import 'server_record.dart';
import 'server_add.dart';
import 'server_row.dart';

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
        slivers: [
          if (empty)
            _sliverOf([
              if (c.refreshFailed) RefreshFailureNotice(controller: c),
              ..._emptyLedger(context),
            ])
          else
            ..._ledger(context, all),
        ],
      );
    },
  );

  static Widget _sliverOf(List<Widget> children) =>
      SliverList(delegate: SliverChildListDelegate(children));

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

  /// The ledger as slivers: the controls and stats above the list, then the
  /// rows (built lazily, only those on screen), then the hint.
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
    final top = [
      if (c.refreshFailed) RefreshFailureNotice(controller: c),
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
        ),
    ];
    return [
      _sliverOf(top),
      if (visible.isNotEmpty)
        SliverList.builder(
          itemCount: visible.length,
          itemBuilder: (context, i) => AppGroupedRow(
            first: i == 0,
            last: i == visible.length - 1,
            inset: big ? 16 : 70,
            child: ServerRow(
              key: ValueKey('server-row:${visible[i].id}'),
              record: visible[i],
              controller: c,
            ),
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 10, 32, 0),
          child: Text(
            l10n.uiServersRowHint,
            textAlign: TextAlign.center,
            style: context.footnoteStyle,
          ),
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

  /// Result count with the pending selection.
  int get count => widget.controller.countMatching(group: group, due: due);

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
