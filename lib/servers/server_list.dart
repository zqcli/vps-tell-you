import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';

import 'package:flutter/material.dart';

import '../cloud/cloud_pages.dart';
import '../cloud/cloud_widgets.dart';
import '../core/app_theme.dart';
import 'ledger_controller.dart';
import 'refresh_failure_notice.dart';
import 'server_detail.dart';
import 'server_form.dart';
import 'server_record.dart';

Future<void> addServer(
  BuildContext context,
  LedgerController controller,
) async {
  final id = await Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (_) => ServerForm(controller: controller)),
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
  Future<void> importCloud() async {
    if (openingCloud) {
      return;
    }
    openingCloud = true;
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => CloudTemplatesPage(ledger: c)),
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

  Future<void> filters() async {
    var group = c.groupFilter;
    var due = c.dueFilter;
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: true,
          title: Text(context.l10n.serverFilterTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: group ?? '__all',
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.serverGroup,
                ),
                items: [
                  DropdownMenuItem(
                    value: '__all',
                    child: Builder(
                      builder: (context) => Text(context.l10n.serverAllGroups),
                    ),
                  ),
                  DropdownMenuItem(
                    value: '',
                    child: Builder(
                      builder: (context) => Text(context.l10n.ungrouped),
                    ),
                  ),
                  ...c.groups.map(
                    (g) => DropdownMenuItem(value: g.id, child: Text(g.name)),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => group = v == '__all' ? null : v),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<DueFilter>(
                initialValue: due,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.serverDueStatus,
                ),
                items: [
                  DropdownMenuItem(
                    value: DueFilter.all,
                    child: Builder(
                      builder: (context) =>
                          Text(context.l10n.serverAllStatuses),
                    ),
                  ),
                  DropdownMenuItem(
                    value: DueFilter.overdue,
                    child: Builder(
                      builder: (context) => Text(context.l10n.serverExpired),
                    ),
                  ),
                  DropdownMenuItem(
                    value: DueFilter.next30,
                    child: Builder(
                      builder: (context) => Text(context.l10n.serverDueNext30),
                    ),
                  ),
                  DropdownMenuItem(
                    value: DueFilter.unknown,
                    child: Builder(
                      builder: (context) =>
                          Text(context.l10n.serverCostDateUnknown),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => due = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.serverApplyFilters),
            ),
          ],
        ),
      ),
    );
    if (apply == true) {
      c.setGroup(group);
      c.updateFilters(due: due);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = c.active;
    final visible = c.visible;
    final pending = all.where(c.isPending).toList();
    final overdue = pending.where((s) => c.dueIn(s)! < 0).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.servers,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.serverLedgerCount((all.length).toString()),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.l10n.serverReloadLocal,
              onPressed: c.busy
                  ? null
                  : () async {
                      try {
                        await c.refresh();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Builder(
                                builder: (context) =>
                                    Text(context.l10n.serverReloadedLocal),
                              ),
                            ),
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          showFailure(context, error);
                        }
                      }
                    },
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 3),
            IconButton.filled(
              key: const ValueKey('add-server'),
              tooltip: context.l10n.serverAdd,
              onPressed: c.canMutate ? () => addServer(context, c) : null,
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 28),
            ),
          ],
        ),
        if (c.refreshFailed) RefreshFailureNotice(controller: c),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('import-cloud-server'),
          onPressed: c.canMutate ? importCloud : null,
          icon: const Icon(Icons.cloud_download_outlined),
          label: Text(context.l10n.serverImportPanel),
        ),
        if (all.isEmpty && c.records.isEmpty) ...[
          const SizedBox(height: 78),
          Center(
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.dns_outlined,
                size: 38,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.serverFirstTitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.serverFirstDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: c.canMutate ? () => addServer(context, c) : null,
            icon: const Icon(Icons.add),
            label: Text(context.l10n.serverAddFirst),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: !c.canMutate
                ? null
                : () async {
                    final ok = await confirmAction(
                      context,
                      title: LocalizedText(
                        (l10n) => l10n.serverLoadDemoQuestion,
                      ),
                      message: LocalizedText((l10n) => l10n.serverLoadDemoHelp),
                      action: LocalizedText((l10n) => l10n.serverLoadDemo),
                    );
                    if (ok) {
                      try {
                        await c.mutate(c.store.loadDemo);
                      } catch (error) {
                        if (context.mounted) {
                          showFailure(context, error);
                        }
                      }
                    }
                  },
            child: Text(context.l10n.serverViewDemo),
          ),
          InfoNote(context.l10n.serverManualStartHelp),
        ] else ...[
          const SizedBox(height: 22),
          TextField(
            key: const ValueKey('server-search'),
            controller: search,
            onChanged: (value) => c.updateFilters(query: value),
            decoration: InputDecoration(
              hintText: context.l10n.serverSearchHint,
              prefixIcon: const Icon(Icons.search, size: 21),
              suffixIcon: c.search.isEmpty
                  ? null
                  : IconButton(
                      tooltip: context.l10n.serverClearSearch,
                      onPressed: () {
                        search.clear();
                        c.updateFilters(query: '');
                      },
                      icon: const Icon(Icons.close, size: 18),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ...[
                (ServerFilter.all, context.l10n.serverAll),
                (ServerFilter.favorites, context.l10n.serverFavorites),
                (ServerFilter.pending, context.l10n.expiryChecks),
              ].map(
                (entry) => ChoiceChip(
                  label: Text(entry.$2),
                  selected: c.filter == entry.$1,
                  showCheckmark: false,
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  labelStyle: TextStyle(
                    color: c.filter == entry.$1
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  onSelected: (_) => c.updateFilters(category: entry.$1),
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.tune, size: 17),
                label: Text(
                  context.l10n.serverFilterLabel(
                    (c.groupFilter != null || c.dueFilter != DueFilter.all
                            ? context.l10n.serverFilterSelectedSuffix
                            : '')
                        .toString(),
                  ),
                ),
                onPressed: filters,
              ),
            ],
          ),
          if (pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Material(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => c.updateFilters(category: ServerFilter.pending),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          '${pending.length}',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context)
                                .colorScheme
                                .onTertiaryContainer,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.serverExpiryNeedsCheck,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onTertiaryContainer,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                context.l10n.serverExpiryCounts(
                                  (overdue).toString(),
                                  (pending.length - overdue).toString(),
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onTertiaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Theme.of(context)
                              .colorScheme
                              .onTertiaryContainer,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SectionTitle(
            c.filter == ServerFilter.favorites
                ? context.l10n.serverFavoriteServers
                : c.filter == ServerFilter.pending
                ? context.l10n.serverExpiryNeedsCheck
                : context.l10n.serverAllServers,
            action: PopupMenuButton<ServerSort>(
              tooltip: context.l10n.serverSort,
              initialValue: c.sort,
              onSelected: (value) => c.updateFilters(order: value),
              itemBuilder: (_) => [
                for (final sort in ServerSort.values)
                  PopupMenuItem(
                    value: sort,
                    child: Builder(
                      builder: (context) => Text(switch (sort) {
                        ServerSort.favorites =>
                          context.l10n.serverSortFavorites,
                        ServerSort.due => context.l10n.serverSortDue,
                        ServerSort.name => context.l10n.serverSortName,
                        ServerSort.updated => context.l10n.serverSortUpdated,
                      }),
                    ),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      switch (c.sort) {
                        ServerSort.favorites =>
                          context.l10n.serverSortFavorites,
                        ServerSort.due => context.l10n.serverSortDue,
                        ServerSort.name => context.l10n.serverSortName,
                        ServerSort.updated => context.l10n.serverSortUpdated,
                      },
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                    Icon(
                      Icons.expand_more,
                      color: Theme.of(context).colorScheme.primary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (visible.isEmpty)
            LedgerCard(
              child: Column(
                children: [
                  Icon(
                    Icons.search_off,
                    size: 32,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    all.isEmpty
                        ? context.l10n.serverNoUnarchived
                        : context.l10n.serverNoMatches,
                  ),
                  InfoNote(context.l10n.serverNoMatchesHelp),
                  TextButton(
                    onPressed: () {
                      search.clear();
                      c.resetFilters();
                    },
                    child: Text(context.l10n.serverClearFilters),
                  ),
                ],
              ),
            )
          else
            LedgerCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0) const Divider(),
                    ServerRow(record: visible[i], controller: c),
                  ],
                ],
              ),
            ),
          InfoNote(context.l10n.serverListObservationHelp),
        ],
      ],
    );
  }
}

class ServerRow extends StatelessWidget {
  const ServerRow({super.key, required this.record, required this.controller});
  final ServerRecord record;
  final LedgerController controller;
  @override
  Widget build(BuildContext context) {
    final s = record;
    final binding = controller.cloud.bindingFor(s.id);
    final days = controller.dueIn(s);
    final due = switch (s.billing) {
      BillingKind.unknown => context.l10n.serverCostsMissing,
      BillingKind.metered => context.l10n.serverMeteredBilling,
      BillingKind.prepaid =>
        days == null
            ? context.l10n.serverDueUnknown
            : days < 0
            ? context.l10n.serverExpiredDays(-days)
            : days == 0
            ? context.l10n.serverDueToday
            : context.l10n.serverDueInDays(days),
    };
    final big = MediaQuery.textScalerOf(context).scale(14) > 20;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('server-${s.id}'),
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => ServerDetail(controller: controller, id: s.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!big) ...[
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    s.mark,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          s.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (s.purpose.isNotEmpty)
                          Text(s.purpose, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        s.vendor,
                        s.region,
                        if (s.favorite) context.l10n.serverFavorites,
                      ].where((e) => e.isNotEmpty).join(' · '),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          s.billingLabelFor(context.l10n),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        LedgerBadge(
                          due,
                          warning: days != null && days >= 0 && days < 30,
                          danger: days != null && days < 0,
                        ),
                        if (s.isDemo) LedgerBadge(context.l10n.serverDemo),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      binding != null
                          ? cloudBindingSummary(binding, l10n: context.l10n)
                          : context.l10n.serverLocalUnqueried,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 6, left: 4),
                child: Icon(
                  Icons.chevron_right,
                  size: 17,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
