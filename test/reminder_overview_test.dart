import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/settings/reminder_overview.dart';
import 'package:vps_tell_you/settings/reminder_page.dart';
import 'package:vps_tell_you/settings/reminder_scheduler.dart';
import 'package:vps_tell_you/settings/settings_page.dart';

import 'support/reminder_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late LedgerStore store;
  late FakeReminderPlatform platform;
  final now = DateTime.now();

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('reminder-overview-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite',
    );
    platform = FakeReminderPlatform();
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  ServerRecord server(
    String id,
    String name, {
    int? dueIn,
    BillingKind billing = BillingKind.prepaid,
    bool demo = false,
  }) => ServerRecord(
    id: id,
    name: name,
    vendor: 'Fixture',
    billing: billing,
    amountMinor: 1000,
    dueDate: dueIn == null ? null : LedgerDate.today(now).addDays(dueIn),
    createdAt: now,
    updatedAt: now,
    isDemo: demo,
  );

  Future<LedgerController> controllerFor() async {
    final controller = LedgerController(store, reminderPlatform: platform);
    await controller.refresh();
    await controller.reminders.reconcile();
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> mount(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'small ledger: grouped upcoming list, reasons, row opens editor',
    (tester) async {
      await store.saveServer(server('a', 'Alpha', dueIn: 8), isNew: true);
      await store.saveServer(server('b', 'Beta-NoDate'), isNew: true);
      await store.saveServer(
        server('c', 'Gamma-Metered', dueIn: 20, billing: BillingKind.metered),
        isNew: true,
      );
      await store.saveServer(
        server('d', 'Delta-Demo', dueIn: 20, demo: true),
        isNew: true,
      );
      final controller = await controllerFor();
      await mount(tester, NotificationPage(controller: controller));

      // Alpha: due +8 -> leads 7/3/1 at +1, +5, +7 days, all in the future.
      expect(controller.reminders.planned.length, 3);
      expect(find.text('明天'), findsOneWidget);
      expect(find.text('7 天内'), findsOneWidget);
      expect(find.text('Alpha'), findsNWidgets(3));
      expect(find.textContaining('提前 7 天'), findsOneWidget);
      expect(find.byType(StatusPill), findsNothing);
      // Three servers produce nothing: no date, metered, demo.
      final overview = ReminderOverview.of(controller);
      expect(
        {for (final e in overview.excluded) e.server.id: e.reason},
        {
          'b': ReminderExclusion.noDate,
          'c': ReminderExclusion.notPrepaid,
          'd': ReminderExclusion.demo,
        },
      );
      expect(find.text('未提醒的服务器'), findsOneWidget);
      expect(find.text('显示全部（3）'), findsNothing);

      await tester.ensureVisible(find.text('未提醒的服务器'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('未提醒的服务器'));
      await tester.pumpAndSettle();
      expect(find.byType(ReminderListPage), findsOneWidget);
      expect(find.text('未填到期日'), findsOneWidget);
      expect(find.text('非预付费'), findsOneWidget);
      expect(find.text('演示数据'), findsOneWidget);

      await tester.tap(find.text('Beta-NoDate'));
      await tester.pumpAndSettle();
      expect(find.byType(ReminderPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in ['zh', 'en']) {
    testWidgets('$locale overview fits 320px at 2x text', (tester) async {
      platform.capacity = 2;
      await store.saveServer(
        server('a', 'A-very-long-server-name-for-layout-checks', dueIn: 8),
        isNew: true,
      );
      await store.saveServer(server('b', 'No-date'), isNew: true);
      final controller = await controllerFor();
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final page in [
        NotificationPage(controller: controller),
        ReminderListPage(controller: controller),
        ReminderListPage(
          controller: controller,
          initialFilter: ReminderListFilter.notCovered,
        ),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(),
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: page,
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < 6; i++) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -400),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    });
  }

  testWidgets('settings row shows how many reminders are scheduled', (
    tester,
  ) async {
    await store.saveServer(server('a', 'Alpha', dueIn: 8), isNew: true);
    final controller = await controllerFor();
    await mount(tester, SettingsPage(controller: controller));
    expect(find.text('已安排 3 条'), findsOneWidget);
  });

  testWidgets('denied permission shows no overview', (tester) async {
    platform.permissionValue = ReminderPermission.denied;
    await store.saveServer(server('a', 'Alpha', dueIn: 8), isNew: true);
    final controller = await controllerFor();
    await mount(tester, NotificationPage(controller: controller));
    expect(find.byType(ReminderOverviewBlock), findsNothing);
    expect(find.text('Alpha'), findsNothing);
  });

  testWidgets(
    '1,000 servers: bounded preview, lazy full list, filters and navigation',
    (tester) async {
      // Seed outside the fake-async zone: 1,000 SQLite writes.
      await tester.runAsync(() async {
        for (var i = 0; i < 1000; i++) {
          final kind = i % 10;
          await store.saveServer(
            server(
              's$i',
              'Server-${i.toString().padLeft(4, '0')}',
              dueIn: kind == 0 ? null : 8 + i % 300,
              billing: kind == 1 ? BillingKind.metered : BillingKind.prepaid,
            ),
            isNew: true,
          );
        }
      });
      final controller = LedgerController(store, reminderPlatform: platform);
      await controller.refresh();
      await controller.reminders.reconcile();
      addTearDown(controller.dispose);

      final planned = controller.reminders.planned.length;
      final notCovered = controller.reminders.notCovered.length;
      expect(planned, 64);
      expect(notCovered, greaterThan(1000));
      expect(controller.reminders.uncovered, notCovered);

      final built = Stopwatch()..start();
      await mount(tester, NotificationPage(controller: controller));
      built.stop();
      // Only the 20-row preview is built, whatever the ledger size.
      expect(
        find.byType(ReminderEntryRow).evaluate().length,
        lessThanOrEqualTo(20),
      );
      expect(find.text('显示全部（${planned + notCovered}）'), findsOneWidget);
      expect(built.elapsedMilliseconds, lessThan(5000));

      await tester.ensureVisible(find.text('显示全部（${planned + notCovered}）'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('显示全部（${planned + notCovered}）'));
      await tester.pumpAndSettle();
      expect(find.byType(ReminderListPage), findsOneWidget);
      int rows() => find.byType(ReminderEntryRow).evaluate().length;
      expect(rows(), greaterThan(0));
      expect(rows(), lessThan(40), reason: 'list must build lazily');
      for (var i = 0; i < 6; i++) {
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -3000),
        );
        await tester.pump();
        expect(rows(), lessThan(40));
      }
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();

      // "Not covered" filter keeps only uncovered rows (all carry the pill).
      Finder segment(String label) => find.descendant(
        of: find.byType(AppSegmented<ReminderListFilter>),
        matching: find.text(label),
      );
      await tester.tap(segment('未覆盖'));
      await tester.pumpAndSettle();
      expect(rows(), greaterThan(0));
      expect(
        find.byType(StatusPill).evaluate().length,
        rows(),
        reason: 'every visible row is marked not covered',
      );

      // Search narrows to one server (each has up to 3 reminders).
      await tester.tap(segment('全部'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AppSearchField),
          matching: find.byType(EditableText),
        ),
        'Server-0007',
      );
      await tester.pumpAndSettle();
      final hit = find.descendant(
        of: find.byType(ReminderEntryRow),
        matching: find.text('Server-0007'),
      );
      expect(hit, findsWidgets);
      expect(find.text('Server-0008'), findsNothing);

      await tester.tap(hit.first);
      await tester.pumpAndSettle();
      expect(find.byType(ReminderPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets('1,000 servers: "no reminder" list is lazy too', (tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 1000; i++) {
        await store.saveServer(
          server('s$i', 'Plain-${i.toString().padLeft(4, '0')}'),
          isNew: true,
        );
      }
    });
    final controller = LedgerController(store, reminderPlatform: platform);
    await controller.refresh();
    await controller.reminders.reconcile();
    addTearDown(controller.dispose);
    await mount(
      tester,
      ReminderListPage(
        controller: controller,
        initialFilter: ReminderListFilter.none,
      ),
    );
    expect(find.byType(ExcludedServerRow).evaluate().length, lessThan(30));
    expect(find.text('未填到期日'), findsWidgets);
    await tester.tap(find.text('Plain-0000'));
    await tester.pumpAndSettle();
    expect(find.byType(ReminderPage), findsOneWidget);
  });
}
