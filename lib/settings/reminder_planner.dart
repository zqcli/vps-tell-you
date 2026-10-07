import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';

import 'package:timezone/timezone.dart' as tz;

import '../core/value_types.dart';
import 'reminder_rule.dart';

/// The ledger supplies this snapshot; planning performs no database or API work.
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
    this.localizations,
  });

  final int notificationId, leadDays;
  final String serverId;
  final LedgerDate dueDate;
  final tz.TZDateTime at;
  final UsagePlan usagePlan;
  final AppLocalizations? localizations;
  AppLocalizations get l10n => localizations ?? defaultLocalizations;

  // Deliberately omit machine names, addresses, accounts and prices.
  String get title => l10n.expiryNotificationTitle;
  String get body {
    // Absolute dates remain accurate if the OS delays delivery or a gap crosses
    // midnight. Relative "today / in N days" wording would then be misleading.
    final when = l10n.notificationDueDate((dueDate).toString());
    return usagePlan == UsagePlan.stopAtExpiry
        ? l10n.notificationStopBody((when).toString())
        : l10n.notificationContinueBody((when).toString());
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
  AppLocalizations? localizations,
}) {
  if (capacity < 0) {
    throw ArgumentError('Negative notification capacity');
  }
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
      if (!date.isValid) {
        continue;
      }
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
          localizations: localizations,
        ),
      );
    }
  }
  candidates.sort((a, b) {
    final timeOrder = a.at.compareTo(b.at);
    if (timeOrder != 0) {
      return timeOrder;
    }
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
