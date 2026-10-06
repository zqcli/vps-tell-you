import 'package:timezone/timezone.dart' as tz;

import '../core/value_types.dart';
import 'reminder_rule.dart';

/// The ledger supplies this snapshot; no Flutter, database or API dependency.
class ReminderInput {
  const ReminderInput({
    required this.rule,
    required this.dueDate,
    this.isPrepaid = true,
    this.archived = false,
    this.isDemo = false,
  });

  final ReminderRule rule;
  final LedgerDate? dueDate;
  final bool isPrepaid, archived, isDemo;
}

class PlannedReminder {
  const PlannedReminder({
    required this.notificationId,
    required this.serverId,
    required this.leadDays,
    required this.dueDate,
    required this.at,
    required this.usagePlan,
  });

  final int notificationId, leadDays;
  final String serverId;
  final LedgerDate dueDate;
  final tz.TZDateTime at;
  final UsagePlan usagePlan;

  // Deliberately omit machine names, addresses, accounts and prices.
  String get title => 'VPS 到期核对';
  String get body {
    // Absolute dates remain accurate if the OS delays delivery or a gap crosses
    // midnight. Relative "today / in N days" wording would then be misleading.
    final when = '到期日为 $dueDate';
    return usagePlan == UsagePlan.stopAtExpiry
        ? '有服务$when，请核对厂商是否已取消续费。本地计划不会停止扣费。'
        : '有服务$when，请核对厂商账单与使用计划。本提醒不会自动付款。';
  }
}

/// These are candidates, never a claim that the OS scheduled or delivered them.
class ReminderPlan {
  ReminderPlan(List<PlannedReminder> selected, List<PlannedReminder> uncovered)
    : selected = List.unmodifiable(selected),
      uncovered = List.unmodifiable(uncovered);

  final List<PlannedReminder> selected, uncovered;
}

/// Callers explicitly supply the actual IANA device location and OS capacity.
/// Use 64 for the iOS pending queue. Re-plan on timezone/permission/rule changes
/// and on foreground; this function does not request permission or schedule.
///
/// Each local date is constructed with timezone's canonical DST resolution:
/// missing wall times move forward across the gap; a repeated wall time maps to
/// one occurrence. Once that occurrence has passed, it is not caught up/repeated.
/// An entirely skipped calendar date is omitted rather than moved to another day.
ReminderPlan planReminders({
  required Iterable<ReminderInput> inputs,
  required DateTime now,
  required tz.Location location,
  required int capacity,
}) {
  if (capacity < 0) throw ArgumentError('Negative notification capacity');
  final candidates = <PlannedReminder>[];
  final ruleIds = <int>{};
  final serverIds = <String>{};
  for (final input in inputs) {
    final rule = input.rule;
    if (!ruleIds.add(rule.id) || !serverIds.add(rule.serverId)) {
      throw ArgumentError('Duplicate reminder rule or server ID');
    }
    final due = input.dueDate;
    if (due != null && !due.isValid) {
      throw ArgumentError('Invalid reminder due date');
    }
    if (!rule.enabled ||
        due == null ||
        !input.isPrepaid ||
        input.archived ||
        input.isDemo) {
      continue;
    }
    for (final leadDays in rule.leadDays) {
      final date = due.addDays(-leadDays);
      if (!date.isValid) continue;
      final at = tz.TZDateTime(
        location,
        date.year,
        date.month,
        date.day,
        rule.minuteOfDay ~/ 60,
        rule.minuteOfDay % 60,
      );
      // Compare civil components, not elapsed local-day duration. A short DST
      // gap can cross midnight (e.g. Nuuk); only an entire skipped day is inert.
      final requestedWall = date.ordinal.add(
        Duration(minutes: rule.minuteOfDay),
      );
      final normalizedWall = DateTime.utc(
        at.year,
        at.month,
        at.day,
        at.hour,
        at.minute,
      );
      if (normalizedWall.difference(requestedWall).inDays >= 1 ||
          !at.isAfter(now)) {
        continue;
      }
      candidates.add(
        PlannedReminder(
          notificationId: rule.notificationIdFor(leadDays),
          serverId: rule.serverId,
          leadDays: leadDays,
          dueDate: due,
          at: at,
          usagePlan: rule.usagePlan,
        ),
      );
    }
  }
  candidates.sort((a, b) {
    final timeOrder = a.at.compareTo(b.at);
    if (timeOrder != 0) return timeOrder;
    final serverOrder = a.serverId.compareTo(b.serverId);
    return serverOrder != 0
        ? serverOrder
        : a.notificationId.compareTo(b.notificationId);
  });
  return ReminderPlan(
    candidates.take(capacity).toList(),
    candidates.skip(capacity).toList(),
  );
}
