import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/app.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/settings/reminder_page.dart';
import 'package:vps_tell_you/settings/reminder_rule.dart';
import 'package:vps_tell_you/settings/reminder_scheduler.dart';

import 'support/reminder_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late LedgerStore store;
  late FakeReminderPlatform platform;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('reminder-widget-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite',
    );
    final now = DateTime.now();
    await store.saveServer(
      ServerRecord(
        id: 'fixture',
        name: '提醒测试',
        vendor: 'Fixture',
        billing: BillingKind.prepaid,
        amountMinor: 3650,
        dueDate: LedgerDate.today(now).addDays(14),
        createdAt: now,
        updatedAt: now,
      ),
      isNew: true,
    );
    platform = FakeReminderPlatform()..supported = false;
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> reveal(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(find.text(text).last, 250);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'per-server edits cancel cleanly and explicit save preserves usage intent',
    (tester) async {
      final controller = LedgerController(store, reminderPlatform: platform);
      await controller.refresh();
      await controller.reminders.reconcile();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
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
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 天'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect((await store.reminderRules()).single.leadDays, [7, 3, 1]);
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 天'));
      await reveal(tester, '到期不再使用');
      await tester.tap(find.text('到期不再使用'));
      await tester.pump();
      await reveal(tester, '保存提醒规则');
      await tester.tap(find.text('保存提醒规则'));
      await tester.pumpAndSettle();
      final saved = (await store.reminderRules()).single;
      expect(saved.leadDays, [30, 7, 3, 1]);
      expect(saved.usagePlan, UsagePlan.stopAtExpiry);
      expect(saved.enabled, isTrue);
      expect(platform.schedules, 0);
      expect(find.text('打开'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real app persists theme and foreground reconciles changed timezone',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        platform.supported = true;
        await tester.pumpWidget(
          LedgerApp(openStore: () async => store, reminderPlatform: platform),
        );
        await tester.pumpAndSettle();
        for (var tab = 0; tab < 4; tab++) {
          expect(
            tester
                .getSemantics(find.byKey(ValueKey('tab-$tab')))
                .flagsCollection
                .isEnabled,
            Tristate.isTrue,
          );
        }
        await tester.tap(find.byKey(const ValueKey('tab-3')));
        await tester.pumpAndSettle();
        await reveal(tester, '外观');
        await tester.tap(find.text('外观'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('深色'));
        await tester.pumpAndSettle();
        expect(await store.themeMode(), 'dark');
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
          ThemeMode.dark,
        );
        await tester.tap(find.text('外观'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(await store.themeMode(), 'dark');
        final previous = platform.pending.values.first.at;
        platform.zone = 'America/New_York';
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(
          platform.pending.values.first.at.toUtc(),
          isNot(previous.toUtc()),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'denied permission request remains denied and retained rules stay editable',
    (tester) async {
      platform
        ..supported = true
        ..permissionValue = ReminderPermission.denied;
      final controller = LedgerController(store, reminderPlatform: platform);
      await controller.refresh();
      await controller.reminders.reconcile();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(home: NotificationPage(controller: controller)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('申请系统通知权限'));
      await tester.pumpAndSettle();
      expect(platform.requests, 1);
      expect(find.textContaining('系统通知未获允许'), findsOneWidget);
      expect((await store.reminderRules()).single.enabled, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('reminder settings fit390px/2x $brightness', (tester) async {
      final controller = LedgerController(store, reminderPlatform: platform);
      await controller.refresh();
      await controller.reminders.reconcile();
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final page in [
        ReminderPage(controller: controller, serverId: 'fixture'),
        NotificationPage(controller: controller),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: page,
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < 10; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -350));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    });
  }
}
