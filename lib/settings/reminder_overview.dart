import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/ui/ui.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import '../servers/ledger_controller.dart';
import '../servers/server_record.dart';
import 'reminder_page.dart';
import 'reminder_planner.dart';

/// Why a server contributes no upcoming notification.
enum ReminderExclusion { archived, demo, noDate, notPrepaid, off, noUpcoming }

String reminderExclusionLabel(
  ReminderExclusion reason,
  AppLocalizations l10n,
) => switch (reason) {
  ReminderExclusion.archived => l10n.r2TabsReasonArchived,
  ReminderExclusion.demo => l10n.r2TabsReasonDemo,
  ReminderExclusion.noDate => l10n.r2TabsReasonNoDate,
  ReminderExclusion.notPrepaid => l10n.r2TabsReasonNotPrepaid,
  ReminderExclusion.off => l10n.r2TabsReasonOff,
  ReminderExclusion.noUpcoming => l10n.r2TabsReasonNoUpcoming,
};

/// One notification candidate. [covered] is false when it was left out of the
/// OS submission (capacity or 366-day horizon).
class ReminderEntry {
  const ReminderEntry(this.reminder, this.server, {required this.covered});
  final PlannedReminder reminder;
  final ServerRecord server;
  final bool covered;
}

class ExcludedServer {
  const ExcludedServer(this.server, this.reason);
  final ServerRecord server;
  final ReminderExclusion reason;
}

/// Snapshot of what the scheduler submitted (or left out) plus the servers that
/// produce nothing. Built in one linear pass from the scheduler's own planner
/// output, so the list always matches what is scheduled.
class ReminderOverview {
  ReminderOverview._({
    required this.entries,
    required this.excluded,
    required this.scheduledCount,
    required this.notCoveredCount,
    required this._sources,
  });

  /// Sorted by fire time.
  final List<ReminderEntry> entries;
  final List<ExcludedServer> excluded;
  final int scheduledCount, notCoveredCount;
  final List<Object> _sources;

  static List<Object> _sourcesOf(LedgerController c) => [
    c.reminders.planned,
    c.reminders.notCovered,
    c.records,
    c.reminderRules,
  ];

  /// Whether this snapshot was built from the controller's current data.
  bool isCurrentFor(LedgerController controller) {
    final now = _sourcesOf(controller);
    for (var i = 0; i < now.length; i++) {
      if (!identical(now[i], _sources[i])) return false;
    }
    return true;
  }

  factory ReminderOverview.of(LedgerController controller) {
    final scheduler = controller.reminders;
    final servers = {for (final s in controller.records) s.id: s};
    final entries = <ReminderEntry>[];
    final withReminder = <String>{};
    void add(Iterable<PlannedReminder> items, bool covered) {
      for (final item in items) {
        final server = servers[item.serverId];
        if (server == null) continue;
        withReminder.add(server.id);
        entries.add(ReminderEntry(item, server, covered: covered));
      }
    }

    add(scheduler.planned, true);
    add(scheduler.notCovered, false);
    entries.sort((a, b) {
      final order = a.reminder.at.compareTo(b.reminder.at);
      return order != 0 ? order : a.server.id.compareTo(b.server.id);
    });
    final rules = {for (final r in controller.reminderRules) r.serverId: r};
    final excluded = <ExcludedServer>[];
    for (final server in controller.records) {
      if (withReminder.contains(server.id)) continue;
      final rule = rules[server.id];
      final reason = server.archived
          ? ReminderExclusion.archived
          : server.isDemo
          ? ReminderExclusion.demo
          : server.dueDate == null
          ? ReminderExclusion.noDate
          : server.billing != BillingKind.prepaid
          ? ReminderExclusion.notPrepaid
          : rule == null || !rule.enabled
          ? ReminderExclusion.off
          : ReminderExclusion.noUpcoming;
      excluded.add(ExcludedServer(server, reason));
    }
    excluded.sort((a, b) => a.server.name.compareTo(b.server.name));
    return ReminderOverview._(
      entries: entries,
      excluded: excluded,
      scheduledCount: scheduler.planned.length,
      notCoveredCount: scheduler.notCovered.length,
      sources: _sourcesOf(controller),
    );
  }
}

/// A run of entries under one date heading.
class ReminderDateGroup {
  ReminderDateGroup(this.label);
  final String label;
  final List<ReminderEntry> entries = [];
}

/// Groups time-sorted [entries] into Today / Tomorrow / Next 7 days / months.
List<ReminderDateGroup> groupReminderEntries(
  Iterable<ReminderEntry> entries,
  AppLocalizations l10n,
  DateTime now,
) {
  final groups = <ReminderDateGroup>[];
  String? currentKey;
  DateTime? today;
  for (final entry in entries) {
    final at = entry.reminder.at;
    today ??= DateTime.utc(
      tz.TZDateTime.from(now, at.location).year,
      tz.TZDateTime.from(now, at.location).month,
      tz.TZDateTime.from(now, at.location).day,
    );
    final diff = DateTime.utc(
      at.year,
      at.month,
      at.day,
    ).difference(today).inDays;
    final (key, label) = diff <= 0
        ? ('today', l10n.r2TabsToday)
        : diff == 1
        ? ('tomorrow', l10n.r2TabsTomorrow)
        : diff <= 6
        ? ('week', l10n.r2TabsWithinWeek)
        : (
            '${at.year}-${at.month}',
            l10n.r2TabsMonth(
              at.year.toString(),
              at.month.toString().padLeft(2, '0'),
            ),
          );
    if (key != currentKey) {
      groups.add(ReminderDateGroup(label));
      currentKey = key;
    }
    groups.last.entries.add(entry);
  }
  return groups;
}

String _two(int v) => v.toString().padLeft(2, '0');

void openServerReminder(
  BuildContext context,
  LedgerController controller,
  String serverId,
) => Navigator.push<void>(
  context,
  MaterialPageRoute(
    builder: (_) => ReminderPage(controller: controller, serverId: serverId),
  ),
);

/// Row of one upcoming notification: server name, lead + due date, fire time.
class ReminderEntryRow extends StatelessWidget implements AppSectionItem {
  const ReminderEntryRow({super.key, required this.entry, required this.onTap});
  final ReminderEntry entry;
  final VoidCallback onTap;

  @override
  double get separatorInset => 16;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final r = entry.reminder;
    final lead = r.leadDays == 0
        ? l10n.reminderOnDueDate
        : l10n.reminderDaysBefore(r.leadDays);
    final time =
        '${_two(r.at.month)}/${_two(r.at.day)} ${_two(r.at.hour)}:${_two(r.at.minute)}';
    return AppRow(
      title: entry.server.name,
      subtitle: l10n.r2TabsRowSub(lead, r.dueDate.toString()),
      chevron: true,
      onTap: onTap,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            time,
            style: TextStyle(
              fontSize: 14,
              color: p.text2,
              fontFeatures: kTabularFigures,
            ),
          ),
          if (!entry.covered) ...[
            const SizedBox(height: 4),
            StatusPill(l10n.r2TabsNotCoveredPill, tone: AppTone.amber),
          ],
        ],
      ),
    );
  }
}

class ExcludedServerRow extends StatelessWidget implements AppSectionItem {
  const ExcludedServerRow({super.key, required this.item, required this.onTap});
  final ExcludedServer item;
  final VoidCallback onTap;

  @override
  double get separatorInset => 16;

  @override
  Widget build(BuildContext context) => AppRow(
    title: item.server.name,
    subtitle: reminderExclusionLabel(item.reason, context.l10n),
    chevron: true,
    onTap: onTap,
  );
}

enum ReminderListFilter { all, notCovered, none }

/// Full, lazily built list of every upcoming reminder or unreminded server.
class ReminderListPage extends StatefulWidget {
  const ReminderListPage({
    super.key,
    required this.controller,
    this.initialFilter = ReminderListFilter.all,
  });
  final LedgerController controller;
  final ReminderListFilter initialFilter;
  @override
  State<ReminderListPage> createState() => _ReminderListPageState();
}

/// Flattened list item: a date heading or a row, with its position in the
/// rounded group (so lazily built rows can draw group corners).
class _FlatItem {
  const _FlatItem.header(this.header)
    : entry = null,
      excluded = null,
      first = true,
      last = true;
  const _FlatItem.row({
    this.entry,
    this.excluded,
    required this.first,
    required this.last,
  }) : header = null;
  final String? header;
  final ReminderEntry? entry;
  final ExcludedServer? excluded;
  final bool first, last;
}

class _ReminderListPageState extends State<ReminderListPage> {
  late ReminderListFilter filter = widget.initialFilter;
  final search = TextEditingController();
  String query = '';

  ReminderOverview? _overview;
  List<_FlatItem> _items = const [];
  (ReminderOverview, ReminderListFilter, String, String)? _itemsKey;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  /// Recomputed only when the planner output, filter, query or language
  /// changed; never from an item builder.
  List<_FlatItem> _itemsFor(BuildContext context) {
    final controller = widget.controller;
    var overview = _overview;
    if (overview == null || !overview.isCurrentFor(controller)) {
      overview = _overview = ReminderOverview.of(controller);
    }
    final l10n = context.l10n;
    final key = (overview, filter, query, l10n.localeName);
    if (_itemsKey == key) return _items;
    final needle = query.trim().toLowerCase();
    bool matches(String name) =>
        needle.isEmpty || name.toLowerCase().contains(needle);
    final items = <_FlatItem>[];
    if (filter == ReminderListFilter.none) {
      final list = [
        for (final e in overview.excluded)
          if (matches(e.server.name)) e,
      ];
      for (var i = 0; i < list.length; i++) {
        items.add(
          _FlatItem.row(
            excluded: list[i],
            first: i == 0,
            last: i == list.length - 1,
          ),
        );
      }
    } else {
      final list = [
        for (final e in overview.entries)
          if ((filter == ReminderListFilter.all || !e.covered) &&
              matches(e.server.name))
            e,
      ];
      final now = controller.reminders.clock();
      for (final group in groupReminderEntries(list, l10n, now)) {
        items.add(_FlatItem.header(group.label));
        for (var i = 0; i < group.entries.length; i++) {
          items.add(
            _FlatItem.row(
              entry: group.entries[i],
              first: i == 0,
              last: i == group.entries.length - 1,
            ),
          );
        }
      }
    }
    _itemsKey = key;
    return _items = items;
  }

  Widget _buildItem(BuildContext context, _FlatItem item) {
    final p = context.palette;
    if (item.header != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 22, 32, 7),
        child: Text(
          item.header!,
          style: TextStyle(fontSize: 13, color: p.text2),
        ),
      );
    }
    final radius = Radius.circular(14);
    final row = item.entry != null
        ? ReminderEntryRow(
            entry: item.entry!,
            onTap: () => openServerReminder(
              context,
              widget.controller,
              item.entry!.server.id,
            ),
          )
        : ExcludedServerRow(
            item: item.excluded!,
            onTap: () => openServerReminder(
              context,
              widget.controller,
              item.excluded!.server.id,
            ),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: p.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: item.first ? radius : Radius.zero,
            bottom: item.last ? radius : Radius.zero,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!item.first)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 16),
                child: SizedBox(
                  height: .5,
                  child: ColoredBox(color: p.separator),
                ),
              ),
            row,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller,
      widget.controller.reminders,
    ]),
    builder: (context, _) {
      final l10n = context.l10n;
      final items = _itemsFor(context);
      return AppScaffold(
        title: l10n.r2TabsAllReminders,
        largeTitle: false,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                AppSearchField(
                  controller: search,
                  placeholder: l10n.r2TabsSearchHint,
                  onChanged: (value) => setState(() => query = value),
                ),
                const SizedBox(height: 12),
                AppSegmented<ReminderListFilter>(
                  options: {
                    ReminderListFilter.all: l10n.r2TabsFilterAll,
                    ReminderListFilter.notCovered: l10n.r2TabsMetricNotCovered,
                    ReminderListFilter.none: l10n.r2TabsMetricNoReminder,
                  },
                  value: filter,
                  onChanged: (value) => setState(() => filter = value),
                ),
                if (filter == ReminderListFilter.none)
                  const SizedBox(height: 16),
              ],
            ),
          ),
          if (items.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    l10n.r2TabsEmpty,
                    style: TextStyle(color: context.palette.text2),
                  ),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, i) => _buildItem(context, items[i]),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      );
    },
  );
}

/// Overview block of [NotificationPage]: metrics, the next [previewLimit]
/// notifications grouped by date, and the entry to the full lists.
class ReminderOverviewBlock extends StatefulWidget {
  const ReminderOverviewBlock({
    super.key,
    required this.controller,
    this.previewLimit = 20,
  });
  final LedgerController controller;
  final int previewLimit;
  @override
  State<ReminderOverviewBlock> createState() => _ReminderOverviewBlockState();
}

class _ReminderOverviewBlockState extends State<ReminderOverviewBlock> {
  ReminderOverview? _overview;

  void _openList(ReminderListFilter filter) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => ReminderListPage(
        controller: widget.controller,
        initialFilter: filter,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final l10n = context.l10n;
    var overview = _overview;
    if (overview == null || !overview.isCurrentFor(controller)) {
      overview = _overview = ReminderOverview.of(controller);
    }
    final preview = overview.entries.take(widget.previewLimit);
    final groups = groupReminderEntries(
      preview,
      l10n,
      controller.reminders.clock(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        AppCard(
          child: AppMetricStrip(
            metrics: [
              AppMetric(
                label: l10n.r2TabsMetricScheduled,
                value: '${overview.scheduledCount}',
              ),
              AppMetric(
                label: l10n.r2TabsMetricNotCovered,
                value: '${overview.notCoveredCount}',
                valueColor: overview.notCoveredCount > 0
                    ? context.palette.amber
                    : null,
                onTap: overview.notCoveredCount == 0
                    ? null
                    : () => _openList(ReminderListFilter.notCovered),
              ),
              AppMetric(
                label: l10n.r2TabsMetricNoReminder,
                value: '${overview.excluded.length}',
                onTap: overview.excluded.isEmpty
                    ? null
                    : () => _openList(ReminderListFilter.none),
              ),
            ],
          ),
        ),
        if (overview.notCoveredCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
            child: Text(l10n.r2TabsCoverageNote, style: context.footnoteStyle),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
          child: Text(
            l10n.r2TabsUpcoming,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        if (groups.isEmpty)
          AppSection(
            topSpacing: 10,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.r2TabsNoUpcoming,
                  style: TextStyle(color: context.palette.text2),
                ),
              ),
            ],
          ),
        for (final group in groups)
          AppSection(
            header: group.label,
            children: [
              for (final entry in group.entries)
                ReminderEntryRow(
                  entry: entry,
                  onTap: () =>
                      openServerReminder(context, controller, entry.server.id),
                ),
            ],
          ),
        if (overview.entries.length > widget.previewLimit)
          AppSection(
            children: [
              AppRow(
                title: l10n.r2TabsShowAll(overview.entries.length.toString()),
                center: true,
                onTap: () => _openList(ReminderListFilter.all),
              ),
            ],
          ),
        if (overview.excluded.isNotEmpty)
          AppSection(
            children: [
              AppRow(
                title: l10n.r2TabsNoReminderServers,
                value: overview.excluded.length.toString(),
                chevron: true,
                onTap: () => _openList(ReminderListFilter.none),
              ),
            ],
          ),
      ],
    );
  }
}
