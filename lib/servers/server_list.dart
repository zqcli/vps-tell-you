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
    if (openingCloud) return;
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
          title: const Text('筛选服务器'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: group ?? '__all',
                isExpanded: true,
                decoration: const InputDecoration(labelText: '分组'),
                items: [
                  const DropdownMenuItem(value: '__all', child: Text('全部分组')),
                  const DropdownMenuItem(value: '', child: Text('未分组')),
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
                decoration: const InputDecoration(labelText: '到期状态'),
                items: const [
                  DropdownMenuItem(value: DueFilter.all, child: Text('全部状态')),
                  DropdownMenuItem(
                    value: DueFilter.overdue,
                    child: Text('已过期'),
                  ),
                  DropdownMenuItem(
                    value: DueFilter.next30,
                    child: Text('未来 30 天到期'),
                  ),
                  DropdownMenuItem(
                    value: DueFilter.unknown,
                    child: Text('费用 / 到期日未知'),
                  ),
                ],
                onChanged: (v) => setState(() => due = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('应用筛选'),
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
                  const Text(
                    '服务器',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${all.length} 台服务器 · 本地台账',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '重新读取本地台账',
              onPressed: c.busy
                  ? null
                  : () async {
                      try {
                        await c.refresh();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已重新读取本地台账，未查询远端状态')),
                          );
                        }
                      } catch (error) {
                        if (context.mounted) showFailure(context, error);
                      }
                    },
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 3),
            IconButton.filled(
              key: const ValueKey('add-server'),
              tooltip: '添加服务器',
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
          label: const Text('从面板账户导入'),
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
          const Text(
            '你的第一台 VPS，\n从这里开始',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Text(
            '把机器、费用和连接放在一起。\n无需安装监控程序，也可直接手动记录。',
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
            label: const Text('添加第一台服务器'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: !c.canMutate
                ? null
                : () async {
                    final ok = await confirmAction(
                      context,
                      title: '载入演示数据？',
                      message: '将写入 4 条带“演示”标记的本地记录，地址均为保留地址。不会连接服务器。可在各服务器详情中归档这些记录。',
                      action: '载入演示',
                    );
                    if (ok) {
                      try {
                        await c.mutate(c.store.loadDemo);
                      } catch (error) {
                        if (context.mounted) showFailure(context, error);
                      }
                    }
                  },
            child: const Text('先看看演示数据'),
          ),
          const InfoNote('已经有机器？手动记录就能开始。'),
        ] else ...[
          const SizedBox(height: 22),
          TextField(
            key: const ValueKey('server-search'),
            controller: search,
            onChanged: (value) => c.updateFilters(query: value),
            decoration: InputDecoration(
              hintText: '搜索名称、地址、厂商、用途或地区',
              prefixIcon: const Icon(Icons.search, size: 21),
              suffixIcon: c.search.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清除搜索',
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
                (ServerFilter.all, '全部'),
                (ServerFilter.favorites, '常用'),
                (ServerFilter.pending, '到期核对'),
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
                  '筛选${c.groupFilter != null || c.dueFilter != DueFilter.all ? ' · 已选' : ''}',
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
                                '到期待核对',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onTertiaryContainer,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$overdue 台已过期 · ${pending.length - overdue} 台 30 天内到期',
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
                ? '常用服务器'
                : c.filter == ServerFilter.pending
                ? '到期待核对'
                : '所有服务器',
            action: PopupMenuButton<ServerSort>(
              tooltip: '排序',
              initialValue: c.sort,
              onSelected: (value) => c.updateFilters(order: value),
              itemBuilder: (_) => [
                for (final entry in [
                  (ServerSort.favorites, '按常用排序'),
                  (ServerSort.due, '按到期排序'),
                  (ServerSort.name, '按名称排序'),
                  (ServerSort.updated, '按更新时间'),
                ])
                  PopupMenuItem(value: entry.$1, child: Text(entry.$2)),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      switch (c.sort) {
                        ServerSort.favorites => '按常用排序',
                        ServerSort.due => '按到期排序',
                        ServerSort.name => '按名称排序',
                        ServerSort.updated => '按更新时间',
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
                  Text(all.isEmpty ? '没有未归档服务器' : '没有符合条件的记录'),
                  const InfoNote('试试调整筛选；已归档记录可在设置中恢复。'),
                  TextButton(
                    onPressed: () {
                      search.clear();
                      c.resetFilters();
                    },
                    child: const Text('清除筛选'),
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
          const InfoNote(
            '显示本地资料和最近一次面板查询结果，不持续监控。\n到期天数按设备日期计算；未来 30 天包含今天及后 29 天。',
          ),
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
      BillingKind.unknown => '费用待补充',
      BillingKind.metered => '按量计费',
      BillingKind.prepaid =>
        days == null
            ? '到期日未知'
            : days < 0
            ? '已过期 ${-days} 天 · 待核实'
            : days == 0
            ? '今天到期'
            : '$days 天后到期',
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
                        if (s.favorite) '常用',
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
                          s.billingLabel,
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
                        if (s.isDemo) const LedgerBadge('演示'),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      binding != null
                          ? cloudBindingSummary(binding)
                          : '本地记录 · 未查询运行状态',
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
