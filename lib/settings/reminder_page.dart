import '../l10n/locale_preference.dart';
import '../l10n/generated/app_localizations.dart';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/ledger_store.dart';
import '../servers/ledger_controller.dart';
import 'reminder_rule.dart';
import 'reminder_scheduler.dart';

String usagePlanLabel(UsagePlan plan, {AppLocalizations? l10n}) =>
    switch (plan) {
      UsagePlan.continueUsing => (l10n ?? defaultLocalizations).usageContinue,
      UsagePlan.undecided => (l10n ?? defaultLocalizations).usageUndecided,
      UsagePlan.stopAtExpiry => (l10n ?? defaultLocalizations).usageStop,
    };

String reminderTime(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

String reminderDaysLabel(Iterable<int> days, {AppLocalizations? l10n}) {
  final messages = l10n ?? defaultLocalizations;
  return days.isEmpty
      ? messages.reminderNoDays
      : days
            .map(
              (day) => day == 0
                  ? messages.reminderOnDueDate
                  : messages.reminderDaysBefore(day),
            )
            .join(messages.localeName.startsWith('zh') ? '、' : ', ');
}

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key, required this.controller});
  final LedgerController controller;
  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool requesting = false;

  Future<void> request() async {
    if (requesting) {
      return;
    }
    setState(() => requesting = true);
    try {
      await widget.controller.reminders.requestPermission();
    } finally {
      if (mounted) {
        setState(() => requesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller.reminders,
    builder: (context, _) {
      final reminders = widget.controller.reminders;
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.notificationStatus)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            LedgerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminders.descriptionFor(context.l10n),
                    key: const ValueKey('reminder-status'),
                  ),
                  if (reminders.timezoneName != null)
                    InfoNote(
                      context.l10n.reminderLastTimezone(
                        (reminders.timezoneName).toString(),
                      ),
                    ),
                ],
              ),
            ),
            InfoNote(context.l10n.reminderEnableHelp),
            if (reminders.platform.supported) ...[
              FilledButton(
                onPressed: requesting ? null : request,
                child: Text(
                  requesting
                      ? context.l10n.requestingPermission
                      : context.l10n.requestNotificationPermission,
                ),
              ),
              InfoNote(context.l10n.notificationPermissionHelp),
            ],
            OutlinedButton(
              onPressed:
                  requesting || reminders.state == ReminderSyncState.syncing
                  ? null
                  : reminders.reconcile,
              child: Text(context.l10n.checkReminderStatus),
            ),
            SectionTitle(context.l10n.reminderCoverage),
            InfoNote(context.l10n.reminderHorizonHelp),
            InfoNote(context.l10n.reminderDeliveryHelp),
            InfoNote(context.l10n.reminderPrivacyHelp),
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
    if (saving || rule == null) {
      return;
    }
    final route = ModalRoute.of(context);
    FocusScope.of(context).unfocus();
    setState(() => saving = true);
    try {
      await widget.controller.mutate(
        () => widget.controller.store.saveReminderRule(rule),
      );
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      // Back/replaced routes remain mounted during transitions. A notification
      // may also push a newer page while SQLite finishes. Never pop that route.
      if (route?.isCurrent == true) {
        Navigator.pop(context);
      } else {
        draft = widget.controller.reminderFor(widget.serverId) ?? draft;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Builder(
            builder: (context) => Text(context.l10n.reminderRulesSaved),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        showFailure(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
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
            title: Text(context.l10n.localExpiryReminders),
            leading: IconButton(
              tooltip: context.l10n.back,
              icon: const Icon(Icons.arrow_back),
              onPressed: saving
                  ? null
                  : () {
                      if (!saving) {
                        Navigator.pop(context);
                      }
                    },
            ),
          ),
          body: rule == null || server == null
              ? Center(child: Text(context.l10n.recordMissingReload))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    Text(
                      '${server.name} · ${server.dueDate ?? context.l10n.dueDateNotEntered}',
                    ),
                    InfoNote(context.l10n.reminderSaveHelp),
                    if (server.isDemo)
                      InfoNote(context.l10n.demoNoNotifications),
                    if (server.archived)
                      InfoNote(context.l10n.archivedNoReminders),
                    LedgerCard(
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.l10n.enableServerReminders),
                        subtitle: Text(context.l10n.reminderOnlyHelp),
                        value: rule.enabled,
                        onChanged: editable
                            ? (value) => setState(
                                () => draft = rule.copyWith(enabled: value),
                              )
                            : null,
                      ),
                    ),
                    SectionTitle(context.l10n.daysBefore),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final day in ReminderRule.allowedLeadDays)
                          FilterChip(
                            label: Text(
                              day == 0
                                  ? context.l10n.sameDay
                                  : context.l10n.dayCount(day),
                            ),
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
                    SectionTitle(context.l10n.reminderTime),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: Text(reminderTime(rule.minuteOfDay)),
                      onPressed: editable
                          ? () async {
                              FocusScope.of(context).unfocus();
                              final time = await showTimePicker(
                                context: context,
                                builder: (context, child) => MediaQuery(
                                  data: MediaQuery.of(context)
                                      .copyWith(alwaysUse24HourFormat: true),
                                  child: child!,
                                ),
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
                    InfoNote(context.l10n.reminderDstHelp),
                    SectionTitle(context.l10n.myUsagePlan),
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
                              title: Text(
                                usagePlanLabel(plan, l10n: context.l10n),
                              ),
                              value: plan,
                              enabled: editable,
                            ),
                        ],
                      ),
                    ),
                    InfoNote(context.l10n.usagePlanWarning),
                    SectionTitle(context.l10n.savedRuleSchedule),
                    Text(scheduler.descriptionFor(context.l10n)),
                    if (scheduler.state == ReminderSyncState.ready) ...[
                      Text(
                        context.l10n.serverScheduledCount(
                          (plans.length).toString(),
                        ),
                      ),
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
                      child: Text(context.l10n.viewReminderCoverage),
                    ),
                    FilledButton(
                      onPressed: editable ? save : null,
                      child: Text(
                        saving
                            ? context.l10n.saving
                            : context.l10n.saveReminderRules,
                      ),
                    ),
                    TextButton(
                      onPressed: saving ? null : () => Navigator.pop(context),
                      child: Text(context.l10n.cancel),
                    ),
                  ],
                ),
        ),
      );
    },
  );
}
