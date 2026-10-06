import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/ledger_store.dart';
import '../finance/fx_page.dart';
import '../security/security_pages.dart';
import '../servers/ledger_controller.dart';
import '../servers/refresh_failure_notice.dart';
import '../servers/server_record.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});
  final LedgerController controller;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        '设置',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 22),
      if (controller.refreshFailed)
        RefreshFailureNotice(controller: controller),
      const LedgerCard(
        child: Row(
          children: [
            Icon(Icons.dns_outlined, size: 32, color: AppColors.blue),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'vps tell you',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '个人 VPS 管理 · 本地优先',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SectionTitle('组织与数据'),
      LedgerCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            SettingRow(
              icon: Icons.folder_outlined,
              title: '分组管理',
              subtitle: '${controller.groups.length} 个分组 · 删除分组保留记录',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupsPage(controller: controller),
                ),
              ),
            ),
            const Divider(),
            SettingRow(
              icon: Icons.inventory_2_outlined,
              title: '已归档记录',
              subtitle: '${controller.archived.length} 条 · 可恢复到服务器列表',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ArchivePage(controller: controller),
                ),
              ),
            ),
          ],
        ),
      ),
      const SectionTitle('后续能力'),
      LedgerCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            SettingRow(
              icon: Icons.cloud_outlined,
              title: '云账户',
              subtitle: 'SolusVM 1 / 2 · 阶段 5',
              onTap: () => showStage(
                context,
                '云账户尚未接入',
                '目前仅支持手动台账。阶段 5 将提供 SolusVM 1 / 2 读取能力，当前不会接收或保存 API 凭据。',
              ),
            ),
            const Divider(),
            SettingRow(
              icon: Icons.shield_outlined,
              title: '密钥与安全',
              subtitle: '凭据、SSH 配置与主机信任',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => SecurityPage(ledger: controller),
                ),
              ),
            ),
            const Divider(),
            SettingRow(
              icon: Icons.currency_exchange,
              title: '币种与参考汇率',
              subtitle:
                  '${controller.fx.displayCurrency} · 手动汇率 ${controller.fx.rateDate ?? '未设置'}',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => FxPage(controller: controller),
                ),
              ),
            ),
            const Divider(),
            SettingRow(
              icon: Icons.notifications_none,
              title: '通知与备份',
              subtitle: '移动端提醒与台账备份 · 阶段 6',
              onTap: () => showStage(
                context,
                '通知与备份尚未接入',
                '当前没有申请通知权限，也没有排程提醒。数据仅保存在本机，尚无导出或恢复入口。请勿清除应用数据。',
              ),
            ),
          ],
        ),
      ),
      const SectionTitle('关于'),
      const LedgerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '阶段 4 · SSH / TCP / 命令片段',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            InfoNote(
              'V6.2 视觉基础 · 本地优先\n无需 App 登录 · 不安装监控 Agent\n删除本地记录不会取消服务或停止扣费。',
            ),
          ],
        ),
      ),
    ],
  );
}

class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key, required this.controller});
  final LedgerController controller;
  Future<void> edit(BuildContext context, [ServerGroup? group]) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _GroupNameDialog(name: group?.name),
    );
    if (result != null) {
      try {
        await controller.mutate(
          () => controller.store.saveGroup(result, id: group?.id),
        );
      } catch (error) {
        if (context.mounted) showFailure(context, error);
      }
    }
  }

  Future<void> menu(
    BuildContext context,
    ServerGroup group,
    String action,
  ) async {
    if (action == 'rename') return edit(context, group);
    if (action == 'delete') {
      final ok = await confirmAction(
        context,
        title: '删除“${group.name}”？',
        message: '组内活动和归档服务器都将移到“未分组”，服务器资料与稳定 ID 保留。不会修改远端机器。',
        action: '删除分组',
        dangerous: true,
      );
      if (!ok) return;
    }
    try {
      await controller.mutate(
        () => action == 'delete'
            ? controller.store.deleteGroup(group.id)
            : controller.store.moveGroup(group.id, action == 'up' ? -1 : 1),
      );
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('分组管理'),
        actions: [
          IconButton(
            tooltip: '新增分组',
            onPressed: controller.canMutate ? () => edit(context) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (controller.refreshFailed)
            RefreshFailureNotice(controller: controller),
          const InfoNote('按用途整理机器。重命名、调整顺序或删除分组，不修改服务器端内容。'),
          if (controller.groups.isEmpty)
            const LedgerCard(child: Text('还没有自定义分组，点右上角 + 新建。')),
          for (final g in controller.groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LedgerCard(
                child: Row(
                  children: [
                    const Icon(Icons.folder_outlined, color: AppColors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${controller.active.where((s) => s.groupId == g.id).length} 台活动服务器',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: '${g.name}的操作',
                      enabled: controller.canMutate,
                      onSelected: (a) => menu(context, g, a),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('重命名')),
                        PopupMenuItem(value: 'up', child: Text('上移')),
                        PopupMenuItem(value: 'down', child: Text('下移')),
                        PopupMenuItem(value: 'delete', child: Text('删除分组')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          LedgerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '未分组',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                InfoNote(
                  '${controller.active.where((s) => s.groupId == null).length} 台活动服务器 · 默认分组，不可删除',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key, required this.controller});
  final LedgerController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('已归档记录')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (controller.refreshFailed)
            RefreshFailureNotice(controller: controller),
          const InfoNote('归档保留服务器资料和 ID。恢复不会连接云主机，也不会启动或续费服务。'),
          if (controller.archived.isEmpty)
            const LedgerCard(child: Text('没有已归档记录')),
          for (final s in controller.archived)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LedgerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      '${s.vendor} · ${controller.groupName(s.groupId)}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: !controller.canMutate
                          ? null
                          : () async {
                              try {
                                await controller.mutate(
                                  () => controller.store.undoArchive(
                                    ArchiveUndo(s.id, s.revision),
                                  ),
                                );
                              } catch (error) {
                                if (context.mounted) {
                                  showFailure(context, error);
                                }
                              }
                            },
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text('恢复记录'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _GroupNameDialog extends StatefulWidget {
  const _GroupNameDialog({this.name});
  final String? name;
  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  late final TextEditingController field = TextEditingController(
    text: widget.name,
  );
  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.name == null ? '新增分组' : '重命名分组'),
    content: TextField(
      key: const ValueKey('group-name'),
      controller: field,
      autofocus: true,
      maxLength: 40,
      decoration: const InputDecoration(labelText: '分组名称'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, field.text),
        child: const Text('保存'),
      ),
    ],
  );
}
