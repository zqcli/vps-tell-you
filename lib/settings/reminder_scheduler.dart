import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/ledger_store.dart';
import '../servers/server_record.dart';
import 'reminder_planner.dart';

enum ReminderPermission { unsupported, denied, allowed }

enum ReminderSyncState { idle, syncing, ready, denied, unsupported, failed }

/// All platform effects have one small, replaceable boundary for native tests.
abstract interface class ReminderPlatform {
  bool get supported;
  int get capacity;
  Future<ReminderPermission> permission();
  Future<void> requestPermission();
  Future<String> timezone();
  Future<List<int>> pendingIds();
  Future<void> cancel(int id);
  Future<void> schedule(PlannedReminder reminder);
}

class NativeReminderPlatform implements ReminderPlatform {
  NativeReminderPlatform({this.onOpen});
  final void Function(String serverId)? onOpen;
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initializing;
  static const channelId = 'vps_expiry_checks';

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  @override
  int get capacity => defaultTargetPlatform == TargetPlatform.iOS ? 64 : 256;

  Future<void> _initialize() =>
      _initializing ??= _start().catchError((Object error) {
        _initializing = null;
        throw error;
      });

  Future<void> _start() async {
    if (!supported) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final id = response.payload;
        if (id != null && id.isNotEmpty) onOpen?.call(id);
      },
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        '到期核对',
        description: '本地到期提醒，不自动续费或付款',
        importance: Importance.defaultImportance,
      ),
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final id = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true &&
        id != null &&
        id.isNotEmpty) {
      onOpen?.call(id);
    }
  }

  @override
  Future<ReminderPermission> permission() async {
    if (!supported) return ReminderPermission.unsupported;
    await _initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!;
      final enabled = await android.areNotificationsEnabled();
      final channels = await android.getNotificationChannels();
      final channel = channels?.where((c) => c.id == channelId).firstOrNull;
      return enabled == true && channel?.importance != Importance.none
          ? ReminderPermission.allowed
          : ReminderPermission.denied;
    }
    final settings = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()!
        .checkPermissions();
    return settings?.isEnabled == true
        ? ReminderPermission.allowed
        : ReminderPermission.denied;
  }

  @override
  Future<void> requestPermission() async {
    if (!supported) return;
    await _initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!
          .requestNotificationsPermission();
    } else {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()!
          .requestPermissions(alert: true, sound: true, badge: false);
    }
  }

  @override
  Future<String> timezone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;
  @override
  Future<List<int>> pendingIds() async =>
      (await _plugin.pendingNotificationRequests()).map((r) => r.id).toList();
  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
  @override
  Future<void> schedule(PlannedReminder reminder) => _plugin.zonedSchedule(
    id: reminder.notificationId,
    title: reminder.title,
    body: reminder.body,
    payload: reminder.serverId,
    scheduledDate: reminder.at,
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        '到期核对',
        channelDescription: '本地到期提醒，不自动续费或付款',
        importance: Importance.defaultImportance,
        visibility: NotificationVisibility.private,
      ),
      iOS: DarwinNotificationDetails(presentBadge: false),
    ),
  );
}

/// SQLite commits and OS requests are not atomic. Serialize reconciliations;
/// never let a late platform request overtake a newer rule/date cancellation.
class ReminderScheduler extends ChangeNotifier {
  ReminderScheduler(
    this.store, {
    ReminderPlatform? platform,
    DateTime Function()? clock,
  }) : platform = platform ?? NativeReminderPlatform(),
       clock = clock ?? DateTime.now {
    tz_data.initializeTimeZones();
  }
  final LedgerStore store;
  final ReminderPlatform platform;
  final DateTime Function() clock;
  ReminderSyncState state = ReminderSyncState.idle;
  String? timezoneName;
  int submitted = 0, uncovered = 0;
  List<PlannedReminder> planned = const [];
  Future<void> _tail = Future.value();
  int _generation = 0;
  bool _disposed = false;

  String get description => switch (state) {
    ReminderSyncState.idle => '尚未检查系统通知',
    ReminderSyncState.syncing => '正在核对系统提醒…',
    ReminderSyncState.ready => '已安排 $submitted 条提醒 · 未安排 $uncovered 条',
    ReminderSyncState.denied => '系统通知未获允许或通知渠道已关闭；已保存规则仍保留',
    ReminderSyncState.unsupported => '此平台不支持定时通知；已保存规则不会在此设备触发提醒',
    ReminderSyncState.failed => '提醒状态核对失败，可能仍有旧提醒；请重试或检查系统设置',
  };

  Future<void> requestPermission() async {
    if (_disposed) return;
    try {
      await platform.requestPermission();
      await reconcile();
    } catch (_) {
      if (!_disposed) {
        state = ReminderSyncState.failed;
        notifyListeners();
      }
    }
  }

  Future<void> reconcile() {
    final ticket = ++_generation;
    _tail = _tail.then((_) async {
      if (_disposed || ticket != _generation) return;
      state = ReminderSyncState.syncing;
      notifyListeners();
      try {
        if (!platform.supported) {
          submitted = uncovered = 0;
          planned = const [];
          state = ReminderSyncState.unsupported;
          return;
        }
        final permission = await platform.permission();
        if (_disposed || ticket != _generation) return;
        if (permission != ReminderPermission.allowed) {
          for (final id in await platform.pendingIds()) {
            await platform.cancel(id);
          }
          submitted = uncovered = 0;
          planned = const [];
          state = ReminderSyncState.denied;
          return;
        }
        final zone = await platform.timezone();
        final location = tz.getLocation(zone); // No silent UTC fallback.
        final rules = await store.reminderRules();
        final servers = {
          for (final server in await store.servers()) server.id: server,
        };
        final now = clock();
        final plan = planReminders(
          inputs: [
            for (final rule in rules)
              if (servers[rule.serverId] case final server?)
                ReminderInput(
                  rule: rule,
                  dueDate: server.dueDate,
                  archived: server.archived,
                  isDemo: server.isDemo,
                  isPrepaid: server.billing == BillingKind.prepaid,
                ),
          ],
          now: now,
          location: location,
          capacity: 1 << 30,
        );
        // Short, disclosed horizon avoids far-future timezone/database limits.
        final horizon = now.add(const Duration(days: 366));
        final inRange = plan.selected
            .where((r) => r.at.isBefore(horizon))
            .toList();
        final selected = inRange.take(platform.capacity).toList();
        if (_disposed || ticket != _generation) return;
        // This app has only expiry notifications. Cancel old tasks before
        // replacement, including unchanged IDs whose dates/content changed.
        for (final id in await platform.pendingIds()) {
          await platform.cancel(id);
        }
        for (final reminder in selected) {
          if (_disposed || ticket != _generation) return;
          await platform.schedule(reminder);
        }
        if (_disposed || ticket != _generation) return;
        final actual = (await platform.pendingIds()).toSet();
        if (actual.length != selected.length ||
            selected.any((r) => !actual.contains(r.notificationId))) {
          throw StateError('Pending notification verification failed');
        }
        timezoneName = zone;
        planned = List.unmodifiable(selected);
        submitted = selected.length;
        uncovered = plan.selected.length - selected.length;
        state = ReminderSyncState.ready;
      } catch (_) {
        if (!_disposed) {
          state = ReminderSyncState.failed;
          submitted = 0;
        }
      } finally {
        if (!_disposed && ticket == _generation) notifyListeners();
      }
    });
    return _tail;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
