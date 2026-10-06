import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../cloud/cloud_widgets.dart';
import '../cloud/server_cloud_binding_page.dart';
import '../core/app_theme.dart';
import '../connections/connection_pages.dart';
import '../connections/tcp_test_page.dart';
import '../finance/calculator_page.dart';
import '../finance/finance_math.dart';
import '../finance/finance_widgets.dart';
import '../finance/payment_pages.dart';
import '../security/ssh_configuration_page.dart';
import '../settings/reminder_page.dart';
import 'hardware_information_card.dart';
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
          '${record.name}\n\n不会销毁云主机，也不会停止厂商扣费。记录将归档，保留同一 ID，可撤销或在“设置 / 已归档记录”中恢复。',
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

  Widget value(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
      final binding = controller.cloud.bindingFor(id);
      final cloudAccount = controller.cloud.accounts
          .where((a) => a.id == binding?.accountId)
          .firstOrNull;
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
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '更多操作',
              enabled: controller.canMutate && !s.archived,
              onSelected: (_) => archive(context, s),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'archive',
                  child: Text(
                    '移除本地记录',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
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
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    s.mark,
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      Expanded(child: value(context, '主机地址', s.host)),
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
                  value(context, '操作系统', s.os),
                  value(
                    context,
                    '分组 / 用途',
                    '${controller.groupName(s.groupId)} · ${s.purpose.isEmpty ? '待补充' : s.purpose}',
                  ),
                  value(context, '规格', s.spec),
                  InfoNote('以上资料保存在本地，云账户刷新不会覆盖。SSH / TCP 连通性不能证明开机状态或业务健康。'),
                ],
              ),
            ),
            SectionTitle(
              '硬件信息',
              action: TextButton(
                onPressed: !controller.canMutate || s.archived
                    ? null
                    : () => Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServerForm(
                            controller: controller,
                            record: s,
                            focusHardware: true,
                          ),
                        ),
                      ),
                child: const Text('编辑硬件'),
              ),
            ),
            HardwareInformationCard(s.resources),
            const SectionTitle('云厂商关联'),
            LedgerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    cloudAccount?.alias ?? '未关联云账户',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (cloudAccount != null)
                    Text(cloudProviderName(cloudAccount.provider)),
                  const InfoNote('关联已保存的云账户及实例，仅管理本地对应关系。硬件信息需手动编辑。'),
                  OutlinedButton.icon(
                    key: const ValueKey('server-cloud-binding'),
                    onPressed:
                        !controller.canMutate ||
                            s.archived ||
                            controller.cloud.busy ||
                            controller.cloud.needsReload
                        ? null
                        : () => Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ServerCloudBindingPage(
                                ledger: controller,
                                serverId: s.id,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.link),
                    label: Text(binding == null ? '关联云账户' : '管理关联'),
                  ),
                  if (controller.cloud.needsReload)
                    TextButton(
                      onPressed: controller.cloud.busy
                          ? null
                          : () => controller.cloud.reload(),
                      child: const Text('重新读取云账户资料'),
                    ),
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    value(context, '付款周期', '${s.cycleMonths} 个月'),
                    value(context, '服务开始日', s.startDate?.toString() ?? '未知'),
                    value(context, '服务到期日', s.dueDate?.toString() ?? '未知'),
                  ],
                  InfoNote(
                    s.billing == BillingKind.unknown
                        ? '未知金额不会当作 0 元。可通过“编辑”补充费用资料。'
                        : s.billing == BillingKind.metered
                        ? '按量费用作为月估算，不产生剩余价值。可在编辑服务器时维护费用资料。'
                        : '按当前续费价折算已知服务期；历史实付另计，不覆盖续费价。',
                  ),
                  if (controller.reminderFor(s.id) case final rule?)
                    SettingRow(
                      icon: Icons.notifications_none,
                      title: '到期提醒与使用计划',
                      subtitle:
                          '${usagePlanLabel(rule.usagePlan)} · ${rule.enabled ? '${rule.leadDays.join(' / ')} 天前 · ${reminderTime(rule.minuteOfDay)}' : '已关闭本条提醒'}',
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReminderPage(
                            controller: controller,
                            serverId: s.id,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (s.billing == BillingKind.prepaid) ...[
              const SectionTitle('剩余价值'),
              Builder(
                builder: (context) {
                  final valuation = serverValuation(
                    s,
                    controller.periodsFor(s.id),
                    controller.today,
                  );
                  if (valuation == null) {
                    return const LedgerCard(
                      child: InfoNote('日期或费用资料不足，剩余价值未知，不按 0 元计。'),
                    );
                  }
                  return ValuationCard(
                    value: valuation,
                    renewal: s.money!,
                    cycleMonths: s.cycleMonths,
                    due: s.dueDate!,
                    asOf: controller.today,
                    fx: controller.fx,
                  );
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed:
                        !controller.canMutate || s.archived || !canRenew(s)
                        ? null
                        : () => Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentForm(
                                controller: controller,
                                server: s,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.add_card_outlined),
                    label: const Text('记录已付款'),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.refreshFailed
                        ? null
                        : () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CalculatorPage(
                                controller: controller,
                                server: s,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('引用资料试算'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PaymentListPage(controller: controller, serverId: s.id),
                ),
              ),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('查看付款记录'),
            ),
            const SectionTitle('连接与控制'),
            LedgerCard(
              padding: EdgeInsets.zero,
              child: SettingRow(
                icon: Icons.terminal,
                title: 'SSH 连接配置',
                subtitle: '地址、端口、用户名与凭据引用',
                onTap: s.archived
                    ? null
                    : () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SshConfigurationPage(
                            ledger: controller,
                            serverId: s.id,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: s.archived || s.isDemo
                      ? null
                      : () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SshConnectPage(
                              ledger: controller,
                              initialServerId: s.id,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.terminal),
                  label: const Text('连接 SSH'),
                ),
                OutlinedButton.icon(
                  onPressed: s.archived || s.isDemo
                      ? null
                      : () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TcpTestPage(
                              initialHost: s.host,
                              initialPort:
                                  controller.security.configFor(s.id)?.port ??
                                  22,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.monitor_heart_outlined),
                  label: const Text('TCP 测试'),
                ),
                OutlinedButton.icon(
                  onPressed: s.archived || s.isDemo
                      ? null
                      : () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SshConnectPage(
                              ledger: controller,
                              initialServerId: s.id,
                              powerMode: true,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.power_settings_new),
                  label: const Text('单机电源'),
                ),
              ],
            ),
            const InfoNote(
              '首次连接先核对完整主机身份；变化会阻断认证。电源操作仅支持 SSH 重启 / 关机，需两次确认，不改变厂商计费。',
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
