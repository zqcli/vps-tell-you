import '../l10n/locale_preference.dart';
import '../l10n/generated/app_localizations.dart';

import 'package:flutter/cupertino.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/ui/ui.dart';
import '../data/ledger_store.dart';
import '../servers/ledger_controller.dart';
import '../servers/server_record.dart';
import 'reminder_overview.dart';
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
    listenable: Listenable.merge([
      widget.controller,
      widget.controller.reminders,
    ]),
    builder: (context, _) {
      final l10n = context.l10n;
      final reminders = widget.controller.reminders;
      return AppScaffold(
        title: l10n.notificationStatus,
        largeTitle: false,
        children: [
          AppSection(
            footer: reminders.timezoneName == null
                ? null
                : l10n.reminderLastTimezone(reminders.timezoneName.toString()),
            children: [
              _NoteRow(
                reminders.descriptionFor(l10n),
                key: const ValueKey('reminder-status'),
                color: context.palette.text,
              ),
            ],
          ),
          _Footnote(l10n.r2TabsEnableHelp),
          if (reminders.platform.supported) ...[
            _ButtonBlock(
              AppButton(
                expand: true,
                label: requesting
                    ? l10n.requestingPermission
                    : l10n.requestNotificationPermission,
                onPressed: requesting ? null : request,
              ),
            ),
            _Footnote(l10n.r2TabsPermissionHelp),
          ],
          _ButtonBlock(
            AppButton(
              expand: true,
              kind: AppButtonKind.tonal,
              label: l10n.checkReminderStatus,
              onPressed:
                  requesting || reminders.state == ReminderSyncState.syncing
                  ? null
                  : reminders.reconcile,
            ),
          ),
          if (reminders.state == ReminderSyncState.ready)
            ReminderOverviewBlock(controller: widget.controller),
          AppSection(
            children: [
              AppRow(
                title: l10n.reminderCoverage,
                chevron: true,
                onTap: () => showAppSheet<void>(
                  context,
                  title: l10n.reminderCoverage,
                  builder: (_) => AppSection(
                    topSpacing: 4,
                    children: [
                      _NoteRow(l10n.reminderHorizonHelp),
                      _NoteRow(l10n.reminderDeliveryHelp),
                      _NoteRow(l10n.reminderPrivacyHelp),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

/// Footnote paragraph between grouped blocks (page margin + 16 px inset).
class _Footnote extends StatelessWidget {
  const _Footnote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
    child: Text(text, style: context.footnoteStyle),
  );
}

class _ButtonBlock extends StatelessWidget {
  const _ButtonBlock(this.button);
  final Widget button;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: button);
}

/// Free-form paragraph row inside a grouped section.
class _NoteRow extends StatelessWidget {
  const _NoteRow(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.4,
        color: color ?? context.palette.text2,
      ),
    ),
  );
}

/// Multi-select pill for the "days before" group. Selected = brand colour.
class _LeadDayChip extends StatelessWidget {
  const _LeadDayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: Material(
        color: selected ? p.primary : Colors.transparent,
        shape: StadiumBorder(
          side: selected
              ? BorderSide.none
              : BorderSide(color: p.separator, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                fontFeatures: kTabularFigures,
                color: selected ? p.onPrimary : p.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
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

  /// The wheel edits the draft directly; nothing is stored until Save.
  Future<void> pickTime() async {
    final minute = draft?.minuteOfDay;
    if (minute == null) {
      return;
    }
    FocusScope.of(context).unfocus();
    await showAppSheet<void>(
      context,
      title: context.l10n.reminderTime,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          height: 216,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: true,
            initialDateTime: DateTime(2000, 1, 1, minute ~/ 60, minute % 60),
            onDateTimeChanged: (time) {
              if (mounted && draft != null) {
                setState(
                  () => draft = draft!.copyWith(
                    minuteOfDay: time.hour * 60 + time.minute,
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  /// Local-time preview of the reminders the draft would schedule, mirroring
  /// the planner's rules (prepaid, not archived/demo, only future moments).
  String? previewFor(
    AppLocalizations l10n,
    ServerRecord server,
    ReminderRule rule,
  ) {
    final due = server.dueDate;
    if (due == null ||
        server.archived ||
        server.isDemo ||
        server.billing != BillingKind.prepaid) {
      return null;
    }
    final now = DateTime.now();
    final dates = <String>[];
    for (final day in rule.leadDays) {
      final date = due.addDays(-day);
      if (!date.isValid) {
        continue;
      }
      final at = DateTime(
        date.year,
        date.month,
        date.day,
        rule.minuteOfDay ~/ 60,
        rule.minuteOfDay % 60,
      );
      if (at.isAfter(now)) {
        dates.add('${date.month}/${date.day}');
      }
    }
    return dates.isEmpty
        ? l10n.uiTabsReminderPreviewNone
        : l10n.uiTabsReminderPreview(
            dates.join(l10n.localeName.startsWith('zh') ? '、' : ', '),
            reminderTime(rule.minuteOfDay),
          );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l10n = context.l10n;
      final p = context.palette;
      final controller = widget.controller;
      final server = controller.byId(widget.serverId);
      final rule = draft;
      final editable =
          !saving && controller.canMutate && server != null && !server.archived;
      final scheduler = controller.reminders;
      final plans = scheduler.planned
          .where((r) => r.serverId == widget.serverId)
          .toList();
      final ready = rule != null && server != null;
      final preview = ready ? previewFor(l10n, server, rule) : null;
      return PopScope(
        canPop: !saving,
        child: AppScaffold(
          title: l10n.localExpiryReminders,
          largeTitle: false,
          actions: [
            AppNavButton.text(
              l10n.save,
              key: const ValueKey('reminder-save'),
              bold: true,
              onPressed: ready && editable ? save : null,
            ),
          ],
          children: [
            if (!ready)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text(l10n.recordMissingReload)),
              )
            else ...[
              AppSection(
                footer: server.dueDate == null
                    ? '${server.name} · ${l10n.dueDateNotEntered}'
                    : l10n.uiTabsReminderDue(
                        server.name,
                        server.dueDate.toString(),
                      ),
                children: [
                  AppSwitchRow(
                    title: l10n.enableServerReminders,
                    subtitle: l10n.reminderOnlyHelp,
                    value: rule.enabled,
                    onChanged: editable
                        ? (value) => setState(
                            () => draft = rule.copyWith(enabled: value),
                          )
                        : null,
                  ),
                ],
              ),
              if (server.isDemo)
                AppBanner(
                  tone: AppTone.amber,
                  icon: Icons.info_outline,
                  text: l10n.demoNoNotifications,
                ),
              if (server.archived)
                AppBanner(
                  tone: AppTone.amber,
                  icon: Icons.inventory_2_outlined,
                  text: l10n.archivedNoReminders,
                ),
              Opacity(
                opacity: rule.enabled ? 1 : .45,
                child: IgnorePointer(
                  ignoring: !rule.enabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSection(
                        header: l10n.daysBefore,
                        footer: l10n.reminderDstHelp,
                        children: [
                          AppRow.custom(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final day
                                      in ReminderRule.allowedLeadDays)
                                    _LeadDayChip(
                                      label: day == 0
                                          ? l10n.sameDay
                                          : l10n.dayCount(day),
                                      selected: rule.leadDays.contains(day),
                                      onTap: editable
                                          ? () => setState(
                                              () => draft = rule.copyWith(
                                                leadDays:
                                                    rule.leadDays.contains(day)
                                                    ? rule.leadDays.where(
                                                        (d) => d != day,
                                                      )
                                                    : [...rule.leadDays, day],
                                              ),
                                            )
                                          : null,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          AppRow(
                            title: l10n.reminderTime,
                            value: reminderTime(rule.minuteOfDay),
                            chevron: true,
                            enabled: editable,
                            onTap: pickTime,
                          ),
                        ],
                      ),
                      AppSection(
                        header: l10n.myUsagePlan,
                        footer: l10n.usagePlanWarning,
                        children: [
                          for (final plan in UsagePlan.values)
                            Semantics(
                              checked: rule.usagePlan == plan,
                              inMutuallyExclusiveGroup: true,
                              child: AppRow(
                                title: usagePlanLabel(plan, l10n: l10n),
                                subtitle: switch (plan) {
                                  UsagePlan.continueUsing =>
                                    l10n.uiTabsUsageContinueHint,
                                  UsagePlan.undecided =>
                                    l10n.uiTabsUsageUndecidedHint,
                                  UsagePlan.stopAtExpiry =>
                                    l10n.uiTabsUsageStopHint,
                                },
                                trailing: rule.usagePlan == plan
                                    ? Icon(
                                        Icons.check_rounded,
                                        size: 22,
                                        color: p.primary,
                                      )
                                    : null,
                                enabled: editable,
                                onTap: () => setState(
                                  () => draft = rule.copyWith(usagePlan: plan),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (preview != null && rule.enabled) _Footnote(preview),
                    ],
                  ),
                ),
              ),
              AppSection(
                header: l10n.savedRuleSchedule,
                children: [
                  _NoteRow(
                    [
                      scheduler.descriptionFor(l10n),
                      if (scheduler.state == ReminderSyncState.ready) ...[
                        l10n.serverScheduledCount(plans.length.toString()),
                        for (final item in plans)
                          '${item.at.year}-${item.at.month.toString().padLeft(2, '0')}-${item.at.day.toString().padLeft(2, '0')} ${reminderTime(item.at.hour * 60 + item.at.minute)}',
                      ],
                    ].join('\n'),
                  ),
                  AppRow(
                    title: l10n.viewReminderCoverage,
                    chevron: true,
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            NotificationPage(controller: controller),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
}
