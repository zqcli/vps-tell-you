import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import 'ledger_controller.dart';
import 'refresh_failure_notice.dart';
import 'server_form.dart';
import 'server_record.dart';

class ServerDetail extends StatelessWidget {
  const ServerDetail({super.key, required this.controller, required this.id});
  final LedgerController controller;
  final String id;

  Future<void> archive(BuildContext context, ServerRecord record) async {
    final confirmed = await confirmAction(
      context,
      title: '移除本地服务器记录？',
      message:
          '${record.name}\n\n不会销毁云主机，也不会停止厂商扣费。记录将归档，保留同一 ID，可撤销或在“设置 → 已归档记录”中恢复。',
      action: '仅归档本地记录',
      dangerous: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      final token = await controller.mutate(
        () => controller.store.archive(record),
      );
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: const Text('已归档，云端资源和扣费未改变'),
          action: controller.refreshFailed
              ? null
              : SnackBarAction(
                  label: '撤销',
                  onPressed: () async {
                    try {
                      await controller.mutate(
                        () => controller.store.undoArchive(token),
                      );
                    } catch (_) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('无法撤销，请在设置的归档记录中检查')),
                      );
                    }
                  },
                ),
        ),
      );
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Widget value(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        const SizedBox(height: 3),
        SelectableText(value.isEmpty ? '待补充' : value),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final s = controller.byId(id);
      if (s == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('服务器详情')),
          body: const Center(child: Text('记录暂不可用，请返回重试')),
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('服务器详情'),
          actions: [
            IconButton(
              tooltip: s.favorite ? '取消常用' : '设为常用',
              onPressed: !controller.canMutate || s.archived
                  ? null
                  : () async {
                      try {
                        await controller.mutate(
                          () => controller.store.setFavorite(s, !s.favorite),
                        );
                      } catch (error) {
                        if (context.mounted) showFailure(context, error);
                      }
                    },
              icon: Icon(
                s.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: AppColors.blue,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '更多操作',
              enabled: controller.canMutate && !s.archived,
              onSelected: (_) => archive(context, s),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'archive',
                  child: Text('移除本地记录', style: TextStyle(color: AppColors.red)),
                ),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (controller.refreshFailed)
              RefreshFailureNotice(controller: controller),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.soft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    s.mark,
                    maxLines: 1,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        [
                          s.purpose,
                          s.vendor,
                          s.region,
                        ].where((e) => e.isNotEmpty).join(' · '),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (s.isDemo)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LedgerBadge('演示记录 · 保留地址，不连接真实服务器'),
              ),
            SectionTitle(
              '基本信息',
              action: TextButton(
                onPressed: !controller.canMutate || s.archived
                    ? null
                    : () => Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ServerForm(controller: controller, record: s),
                        ),
                      ),
                child: const Text('编辑'),
              ),
            ),
            LedgerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: value('主机地址', s.host)),
                      IconButton(
                        tooltip: '复制主机地址',
                        onPressed: s.host.isEmpty
                            ? null
                            : () async {
                                try {
                                  await Clipboard.setData(
                                    ClipboardData(text: s.host),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('主机地址已复制')),
                                    );
                                  }
                                } catch (error) {
                                  if (context.mounted) {
                                    showFailure(context, error);
                                  }
                                }
                              },
                        icon: const Icon(Icons.copy_outlined, size: 20),
                      ),
                    ],
                  ),
                  const Divider(),
                  value('操作系统', s.os),
                  value(
                    '分组 / 用途',
                    '${controller.groupName(s.groupId)} · ${s.purpose.isEmpty ? '待补充' : s.purpose}',
                  ),
                  value('规格', s.spec),
                  const InfoNote('未检测 · 本地记录\n尚未连接厂商 API 或 SSH，不能据此判断开机或业务健康。'),
                ],
              ),
            ),
            const SectionTitle('续费信息'),
            LedgerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.billing == BillingKind.metered
                        ? '月费用估算'
                        : s.billing == BillingKind.prepaid
                        ? '续费金额'
                        : '费用待补充',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (s.money != null && s.billing != BillingKind.unknown)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 8,
                      children: [
                        Text(
                          s.money!.formatted,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(s.currency),
                      ],
                    ),
                  if (s.billing == BillingKind.prepaid) ...[
                    value('付款周期', '${s.cycleMonths} 个月'),
                    value('服务开始日', s.startDate?.toString() ?? '未知'),
                    value('服务到期日', s.dueDate?.toString() ?? '未知'),
                  ],
                  InfoNote(
                    s.billing == BillingKind.unknown
                        ? '未知金额不会当作 0 元。可通过“编辑”补充费用资料。'
                        : s.billing == BillingKind.metered
                        ? '仅保存原币月估算，无预付到期日。费用统计与付款记录将在阶段 2 提供。'
                        : '原币续费资料已保存。剩余价值计算与实际付款记录将在阶段 2 提供。',
                  ),
                ],
              ),
            ),
            const SectionTitle('连接与控制'),
            const LedgerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SSH 与 TCP 连接能力待接入',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  InfoNote(
                    '凭据与主机信任：阶段 3\nSSH、TCP、命令片段与单机电源：阶段 4\n当前版本不会连接或控制这台服务器。',
                  ),
                ],
              ),
            ),
            if (s.notes.isNotEmpty) ...[
              const SectionTitle('备注'),
              LedgerCard(child: SelectableText(s.notes)),
            ],
            InfoNote(
              '本地保存于 ${s.updatedAt.toLocal().toString().substring(0, 16)}\n服务器 ID：${s.id}',
            ),
          ],
        ),
      );
    },
  );
}
