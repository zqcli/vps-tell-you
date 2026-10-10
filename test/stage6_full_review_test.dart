import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/app.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_detail.dart';
import 'package:vps_tell_you/settings/backup_page.dart';
import 'package:vps_tell_you/settings/reminder_page.dart';
import 'package:vps_tell_you/settings/reminder_scheduler.dart';

import 'backup_page_test.dart' show FakeBackupTransfer;
import 'ledger_backup_test.dart' show backupNow, backupServer;
import 'support/reminder_platform.dart';

double _contrast(Color a, Color b) {
  double luminance(Color color) {
    double linear(double channel) => channel <= .04045
        ? channel / 12.92
        : math.pow((channel + .055) / 1.055, 2.4).toDouble();
    return .2126 * linear(color.r) +
        .7152 * linear(color.g) +
        .0722 * linear(color.b);
  }

  final first = luminance(a), second = luminance(b);
  return (math.max(first, second) + .05) / (math.min(first, second) + .05);
}

class _DelayedPermission extends FakeReminderPlatform {
  final permissionGate = Completer<ReminderPermission>();
  @override
  Future<ReminderPermission> permission() => permissionGate.future;
}

class _DelayedSaveController extends LedgerController {
  _DelayedSaveController(super.store)
    : super(reminderPlatform: FakeReminderPlatform()..supported = false);
  final saveGate = Completer<void>();
  bool delaying = false;
  @override
  Future<void> refresh() async {
    await super.refresh();
    if (delaying) await saveGate.future;
  }

  @override
  Future<T> mutate<T>(Future<T> Function() action) async {
    delaying = true;
    return super.mutate(action);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const native = MethodChannel('dexterous.com/flutter/local_notifications');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  late LedgerStore store;
  String? launchedId;
  final calls = <String>[];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('stage6-full-review-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite',
      clock: () => backupNow,
    );
    await store.saveServer(backupServer(id: 'fixture'), isNew: true);
    launchedId = null;
    calls.clear();
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    messenger.setMockMethodCallHandler(native, (call) async {
      calls.add(call.method);
      return switch (call.method) {
        'initialize' => true,
        'getNotificationAppLaunchDetails' => {
          'notificationLaunchedApp': launchedId != null,
          if (launchedId != null)
            'notificationResponse': {
              'notificationId': 8,
              'notificationResponseType': 0,
              'payload': launchedId,
            },
        },
        'areNotificationsEnabled' => false,
        'getNotificationChannels' ||
        'pendingNotificationRequests' => <Map<String, dynamic>>[],
        _ => null,
      };
    });
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(native, null);
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> notificationTap(String id) async {
    await messenger.handlePlatformMessage(
      native.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('didReceiveNotificationResponse', {
          'notificationId': 8,
          'notificationResponseType': 0,
          'payload': id,
        }),
      ),
      (_) {},
    );
  }

  Future<void> tapPageBack(WidgetTester tester) async {
    // WidgetTester.pageBack searches the English tooltip before Cupertino.
    // The real app's Material delegates correctly localize that tooltip.
    // Migrated pages use the design-system back button; others still use the
    // Material one.
    final custom = find.byKey(const ValueKey('app-nav-back'));
    final back = custom.evaluate().isNotEmpty
        ? custom
        : find.byType(BackButton);
    expect(back, findsOneWidget, reason: 'One back button expected');
    expect(back.hitTestable(), findsOneWidget);
    final tooltip = MaterialLocalizations.of(tester.element(back))
        .backButtonTooltip;
    expect(find.byTooltip(tooltip).hitTestable(), findsOneWidget);
    await tester.tap(back);
  }

  testWidgets(
    'review: cold notification opens its server once; Back is stable',
    (tester) async {
      launchedId = 'fixture';
      await tester.pumpWidget(LedgerApp(openStore: () async => store));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ServerDetail>(find.byType(ServerDetail)).id,
        'fixture',
      );
      expect(calls.where((method) => method.startsWith('request')), isEmpty);
      await tapPageBack(tester);
      await tester.pumpAndSettle();
      expect(find.byType(ServerDetail), findsNothing);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(find.byType(ServerDetail), findsNothing);
      expect(
        calls.where((method) => method == 'getNotificationAppLaunchDetails'),
        hasLength(1),
      );
      await notificationTap('fixture');
      await tester.pumpAndSettle();
      expect(find.byType(ServerDetail), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await notificationTap('fixture');
      await tester.pumpAndSettle();
      expect(find.byType(ServerDetail), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets('review: archived and unknown notification targets stay inert', (
    tester,
  ) async {
    await store.archive((await store.servers()).single);
    launchedId = 'fixture';
    await tester.pumpWidget(LedgerApp(openStore: () async => store));
    await tester.pumpAndSettle();
    expect(find.byType(ServerDetail), findsNothing);
    for (final id in ['missing', 'fixture', '']) {
      await notificationTap(id);
      await tester.pumpAndSettle();
      expect(find.byType(ServerDetail), findsNothing);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant({TargetPlatform.android}));

  testWidgets(
    'review: native notification navigation waits for writes and stale refresh',
    (tester) async {
      await store.saveServer(backupServer(id: 'second'), isNew: true);
      await tester.pumpWidget(LedgerApp(openStore: () async => store));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<HomeShell>(find.byType(HomeShell))
          .controller;
      controller.busy = true;
      await notificationTap('fixture');
      await notificationTap('second');
      await tester.pumpAndSettle();
      expect(find.byType(ServerDetail), findsNothing);
      controller.busy = false;
      controller.updateFilters(query: '');
      await tester.pumpAndSettle();
      expect(
        tester.widget<ServerDetail>(find.byType(ServerDetail)).id,
        'second',
      );
      expect(find.byType(ServerDetail, skipOffstage: false), findsOneWidget);
      await tapPageBack(tester);
      await tester.pumpAndSettle();
      controller.busy = true;
      await notificationTap('fixture');
      controller.busy = false;
      controller.updateFilters(query: '');
      // A newer native tap arrives after writes finish but before the queued
      // frame consumes its old target. The old target must not overtake it.
      await notificationTap('second');
      await tester.pumpAndSettle();
      expect(
        tester.widget<ServerDetail>(find.byType(ServerDetail)).id,
        'second',
      );
      expect(find.byType(ServerDetail, skipOffstage: false), findsOneWidget);
      controller.refreshFailed = true;
      await notificationTap('fixture');
      await tester.pumpAndSettle();
      expect(
        tester.widget<ServerDetail>(find.byType(ServerDetail)).id,
        'second',
      );
      controller.refreshFailed = false;
      controller.updateFilters(query: '');
      await tester.pumpAndSettle();
      expect(
        tester.widget<ServerDetail>(find.byType(ServerDetail)).id,
        'fixture',
      );
      await tapPageBack(tester);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ServerDetail>(find.byType(ServerDetail)).id,
        'second',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  test(
    'review: scheduler disposal fences delayed permission side effects',
    () async {
      final platform = _DelayedPermission();
      final scheduler = ReminderScheduler(store, platform: platform);
      final pending = scheduler.reconcile();
      await Future<void>.delayed(Duration.zero);
      scheduler.dispose();
      platform.permissionGate.complete(ReminderPermission.allowed);
      await pending;
      expect(platform.schedules, 0);
      expect(platform.cancelled, isEmpty);
    },
  );

  testWidgets('review: dark restore conflicts retain readable error contrast', (
    tester,
  ) async {
    final platform = FakeReminderPlatform()..supported = false;
    final controller = LedgerController(store, reminderPlatform: platform);
    await controller.refresh();
    addTearDown(controller.dispose);
    final transfer = FakeBackupTransfer()
      ..source = (await store.exportLedgerBackup()).encode();
    final theme = appTheme(brightness: Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: BackupPage(controller: controller, transfer: transfer),
      ),
    );
    await tester.pumpAndSettle();
    final pick = find.text('选择 JSON 并预览恢复');
    await tester.scrollUntilVisible(pick, 250);
    await tester.tap(pick);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    final conflict = find.text('目标台账已有服务器（含归档）');
    await tester.scrollUntilVisible(conflict, 250);
    final text = tester.widget<Text>(conflict);
    expect(
      _contrast(text.style!.color!, theme.colorScheme.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(tester.takeException(), isNull);
  });

  for (final newerRoute in [false, true]) {
    testWidgets(
      newerRoute
          ? 'review: reminder save preserves newer route and refreshes covered draft'
          : 'review: Back during reminder save cannot double-pop its parent',
      (tester) async {
        final controller = _DelayedSaveController(store);
        await controller.refresh();
        addTearDown(controller.dispose);
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(title: const Text('Parent route')),
                        body: TextButton(
                          onPressed: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReminderPage(
                                controller: controller,
                                serverId: 'fixture',
                              ),
                            ),
                          ),
                          child: const Text('Open reminders'),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Home route'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Home route'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open reminders'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('保存提醒规则'), 300);
        await tester.ensureVisible(find.text('保存提醒规则'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('保存提醒规则'));
        await tester.pumpAndSettle();
        expect((await store.reminderRules()).single.revision, 1);
        if (newerRoute) {
          unawaited(
            navigator.currentState!.push<void>(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Newer notification route')),
                ),
              ),
            ),
          );
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pump(const Duration(milliseconds: 1));
        controller.saveGate.complete();
        await tester.pumpAndSettle();
        if (newerRoute) {
          expect(find.text('Newer notification route'), findsOneWidget);
          await tapPageBack(tester);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('保存提醒规则'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('保存提醒规则'));
          await tester.pumpAndSettle();
          expect((await store.reminderRules()).single.revision, 2);
        }
        expect(find.text('Parent route'), findsOneWidget);
        expect(find.text('Home route'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
