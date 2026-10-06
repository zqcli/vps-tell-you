import 'dart:async';

import 'package:vps_tell_you/settings/reminder_planner.dart';
import 'package:vps_tell_you/settings/reminder_scheduler.dart';

class FakeReminderPlatform implements ReminderPlatform {
  @override
  bool supported = true;
  @override
  int capacity = 64;
  ReminderPermission permissionValue = ReminderPermission.allowed;
  String zone = 'Asia/Shanghai';
  int requests = 0, schedules = 0, active = 0, maxActive = 0;
  bool failSchedule = false, failCancel = false, omitPending = false;
  Completer<void>? gate;
  final pending = <int, PlannedReminder>{};
  final cancelled = <int>[];
  @override
  Future<ReminderPermission> permission() async => permissionValue;
  @override
  Future<void> requestPermission() async {
    requests++;
  }

  @override
  Future<String> timezone() async => zone;
  @override
  Future<List<int>> pendingIds() async =>
      omitPending ? [] : pending.keys.toList();
  @override
  Future<void> cancel(int id) async {
    if (failCancel) throw StateError('synthetic cancel failure');
    cancelled.add(id);
    pending.remove(id);
  }

  @override
  Future<void> schedule(PlannedReminder reminder) async {
    schedules++;
    active++;
    if (active > maxActive) maxActive = active;
    try {
      await gate?.future;
      if (failSchedule) throw StateError('synthetic schedule failure');
      pending[reminder.notificationId] = reminder;
    } finally {
      active--;
    }
  }
}
