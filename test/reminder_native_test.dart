import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/settings/reminder_planner.dart';
import 'package:vps_tell_you/settings/reminder_rule.dart';
import 'package:vps_tell_you/settings/reminder_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const timezoneChannel = MethodChannel('flutter_timezone');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  var enabled = true, importance = 3;
  setUp(() {
    calls.clear();
    enabled = true;
    importance = 3;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'initialize' ||
        'requestNotificationsPermission' ||
        'requestPermissions' => true,
        'getNotificationAppLaunchDetails' => {'notificationLaunchedApp': false},
        'areNotificationsEnabled' => enabled,
        'checkPermissions' => {'isEnabled': enabled},
        'getNotificationChannels' => [
          {
            'id': NativeReminderPlatform.channelId,
            'name': '到期核对',
            'importance': importance,
            'showBadge': false,
            'bypassDnd': false,
            'playSound': true,
            'enableLights': false,
            'enableVibration': true,
            'ledColor': 0,
            'audioAttributesUsage': 5,
          },
        ],
        'pendingNotificationRequests' => <Map<String, dynamic>>[],
        _ => null,
      };
    });
    messenger.setMockMethodCallHandler(
      timezoneChannel,
      (_) async => {'identifier': 'Asia/Shanghai'},
    );
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(timezoneChannel, null);
  });

  test('Android uses actual permission/channel APIs and inexact one-shot scheduling', () async {
    final port = NativeReminderPlatform();
    expect(await port.permission(), ReminderPermission.allowed);
    expect(calls.any((c) => c.method.startsWith('request')), isFalse);
    importance = 0;
    expect(await port.permission(), ReminderPermission.denied);
    importance = 3;
    enabled = false;
    expect(await port.permission(), ReminderPermission.denied);
    await port.requestPermission();
    expect(
      calls.where((c) => c.method == 'requestNotificationsPermission'),
      hasLength(1),
    );
    expect(await port.permission(), ReminderPermission.denied);
    expect(await port.timezone(), 'Asia/Shanghai');
    final future = tz.TZDateTime.from(
      DateTime.now().add(const Duration(days: 2)),
      tz.getLocation('Asia/Shanghai'),
    );
    await port.schedule(
      PlannedReminder(
        notificationId: 8,
        serverId: 'fixture-id',
        leadDays: 0,
        dueDate: LedgerDate(future.year, future.month, future.day),
        at: future,
        usagePlan: UsagePlan.stopAtExpiry,
      ),
    );
    final args =
        calls.singleWhere((c) => c.method == 'zonedSchedule').arguments as Map;
    expect(
      (args['platformSpecifics'] as Map)['scheduleMode'],
      'inexactAllowWhileIdle',
    );
    expect(args['payload'], 'fixture-id');
    expect(args.containsKey('matchDateTimeComponents'), isFalse);
    expect(args['timeZoneName'], 'Asia/Shanghai');
    expect(
      calls.any((c) => c.method.toLowerCase().contains('exactalarm')),
      isFalse,
    );
  });

  test('iOS initialization never prompts; explicit request is read back separately', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    enabled = false;
    final port = NativeReminderPlatform();
    expect(await port.permission(), ReminderPermission.denied);
    final args =
        calls.singleWhere((c) => c.method == 'initialize').arguments as Map;
    expect(args['requestAlertPermission'], false);
    expect(args['requestSoundPermission'], false);
    expect(args['requestBadgePermission'], false);
    expect(calls.any((c) => c.method.startsWith('request')), isFalse);
    await port.requestPermission();
    expect(await port.permission(), ReminderPermission.denied);
    expect(port.capacity, 64);
  });

  test(
    'Linux native adapter never initializes or fabricates permission',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final port = NativeReminderPlatform();
      expect(await port.permission(), ReminderPermission.unsupported);
      await port.requestPermission();
      expect(calls, isEmpty);
    },
  );
}
