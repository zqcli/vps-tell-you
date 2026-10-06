import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/ledger_store.dart';
import '../servers/ledger_controller.dart';
import 'reminder_rule.dart';
import 'reminder_scheduler.dart';

String usagePlanLabel(UsagePlan plan) => switch (plan) {
  UsagePlan.continueUsing => '继续使用',
  UsagePlan.undecided => '待决定',
  UsagePlan.stopAtExpiry => '到期不再使用',
};

String reminderTime(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key, required this.controller});
  final LedgerController controller;
  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool requesting = false;

  Future<void> request() async {
    if (requesting) return;
    setState(() => requesting = true);
    try {
      await widget.controller.reminders.requestPermission();
    } finally {
      if (mounted) setState(() => requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller.reminders,
    builder: (context, _) {
      final reminders = widget.controller.reminders;
      return Scaffold(
        appBar: AppBar(title: const Text('通知权限与排程')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            LedgerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminders.description,
                    key: const ValueKey('reminder-status'),
                  ),
                  if (reminders.timezoneName != null)
                    InfoNote('最近排程时区：${reminders.timezoneName}'),
                ],
              ),
            ),
            const InfoNote(
              '系统权限和每台服务器的提醒规则是两回事。拒绝通知仍可保存规则。各服务器的提前天数、时间和使用计划在详情中编辑。',
            ),
            if (reminders.platform.supported) ...[
              FilledButton(
                onPressed: requesting ? null : request,
                child: Text(requesting ? '正在申请…' : '申请系统通知权限'),
              ),
              const InfoNote('已拒绝或关闭通知渠道时，请到设备系统设置中调整；这里不会假定授权成功。'),
            ],
            OutlinedButton(
              onPressed:
                  requesting || reminders.state == ReminderSyncState.syncing
                  ? null
                  : reminders.reconcile,
              child: const Text('重新核对排程'),
            ),
            const SectionTitle('提醒范围'),
            const InfoNote(
              '只提交未来 366 天内已知的到期提醒；过去的提醒时间不补发。iOS 最多排入最近 64 条，Android 最多 256 条，其余显示为未覆盖。请定期打开应用补充排程。',
            ),
            const InfoNote(
              '应用回到前台会重新读取权限和设备时区。旅行后请打开应用核对；未打开时已提交的提醒可能仍按旧时区投递。系统节电、专注模式及厂商限制可能延迟或阻止提醒，排程成功不代表已经送达。',
            ),
            const InfoNote(
              '提醒内容只包含到期日期和核对提示，不包含服务器名称、地址、账户或金额。不自动付款、不修改厂商续费设置。',
            ),
          ],
        ),
      );
    },
  );
}

class ReminderPage extends StatefulWidget {
  const ReminderPage({
    super.key,
    required this.controller,
    required this.serverId,
  });
  final LedgerController controller;
  final String serverId;
  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  ReminderRule? draft;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    draft = widget.controller.reminderFor(widget.serverId);
  }

  Future<void> save() async {
    final rule = draft;
    if (saving || rule == null) return;
    final route = ModalRoute.of(context);
    FocusScope.of(context).unfocus();
    setState(() => saving = true);
    try {
      await widget.controller.mutate(
        () => widget.controller.store.saveReminderRule(rule),
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      // Back/replaced routes remain mounted during transitions. A notification
      // may also push a newer page while SQLite finishes. Never pop that route.
      if (route?.isCurrent == true) {
        Navigator.pop(context);
      } else {
        draft = widget.controller.reminderFor(widget.serverId) ?? draft;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('本机提醒规则已保存；系统排程状态请以通知设置为准。')),
      );
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final server = controller.byId(widget.serverId);
      final rule = draft;
      final editable =
          !saving && controller.canMutate && server != null && !server.archived;
      final scheduler = controller.reminders;
      final plans = scheduler.planned
          .where((r) => r.serverId == widget.serverId)
          .toList();
      return PopScope(
        canPop: !saving,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('本机到期提醒'),
            leading: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back),
              onPressed: saving
                  ? null
                  : () {
                      if (!saving) Navigator.pop(context);
                    },
            ),
          ),
          body: rule == null || server == null
              ? const Center(child: Text('记录不存在，请返回重新读取。'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    Text('${server.name} · ${server.dueDate ?? '未填写到期日'}'),
                    const InfoNote('修改后点保存生效；返回或取消不保存。到期不再使用仍保留取消续费核对提醒。'),
                    if (server.isDemo) const InfoNote('演示数据不会提交真实系统通知。'),
                    if (server.archived) const InfoNote('已归档记录不会排程提醒。'),
                    LedgerCard(
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('启用本条提醒'),
                        subtitle: const Text('仅提醒，不自动续费或取消服务'),
                        value: rule.enabled,
                        onChanged: editable
                            ? (value) => setState(
                                () => draft = rule.copyWith(enabled: value),
                              )
                            : null,
                      ),
                    ),
                    const SectionTitle('提前几天'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final day in ReminderRule.allowedLeadDays)
                          FilterChip(
                            label: Text(day == 0 ? '当天' : '$day 天'),
                            selected: rule.leadDays.contains(day),
                            onSelected: editable
                                ? (selected) => setState(
                                    () => draft = rule.copyWith(
                                      leadDays: selected
                                          ? [...rule.leadDays, day]
                                          : rule.leadDays.where(
                                              (d) => d != day,
                                            ),
                                    ),
                                  )
                                : null,
                          ),
                      ],
                    ),
                    const SectionTitle('提醒时间'),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: Text(reminderTime(rule.minuteOfDay)),
                      onPressed: editable
                          ? () async {
                              FocusScope.of(context).unfocus();
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: rule.minuteOfDay ~/ 60,
                                  minute: rule.minuteOfDay % 60,
                                ),
                              );
                              if (mounted && time != null) {
                                setState(
                                  () => draft = draft!.copyWith(
                                    minuteOfDay: time.hour * 60 + time.minute,
                                  ),
                                );
                              }
                            }
                          : null,
                    ),
                    const InfoNote(
                      '随设备当前时区。夏令时缺失时间向后顺延，重复时间仅提醒一次；整天被跳过的日期不排程。',
                    ),
                    const SectionTitle('我的使用计划'),
                    RadioGroup<UsagePlan>(
                      groupValue: rule.usagePlan,
                      onChanged: (value) {
                        if (editable) {
                          setState(
                            () => draft = rule.copyWith(usagePlan: value),
                          );
                        }
                      },
                      child: Column(
                        children: [
                          for (final plan in UsagePlan.values)
                            RadioListTile<UsagePlan>(
                              title: Text(usagePlanLabel(plan)),
                              value: plan,
                              enabled: editable,
                            ),
                        ],
                      ),
                    ),
                    const InfoNote('使用计划只是本地记录。计划到期停用不会停止厂商扣费，请另行向厂商确认取消续费。'),
                    const SectionTitle('当前已保存规则的排程'),
                    Text(scheduler.description),
                    if (scheduler.state == ReminderSyncState.ready) ...[
                      Text('本服务器已排程 ${plans.length} 条'),
                      for (final item in plans)
                        Text(
                          '${item.at.year}-${item.at.month.toString().padLeft(2, '0')}-${item.at.day.toString().padLeft(2, '0')} ${reminderTime(item.at.hour * 60 + item.at.minute)}',
                        ),
                    ],
                    TextButton(
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              NotificationPage(controller: controller),
                        ),
                      ),
                      child: const Text('查看通知权限与覆盖范围'),
                    ),
                    FilledButton(
                      onPressed: editable ? save : null,
                      child: Text(saving ? '正在保存…' : '保存提醒规则'),
                    ),
                    TextButton(
                      onPressed: saving ? null : () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                  ],
                ),
        ),
      );
    },
  );
}
