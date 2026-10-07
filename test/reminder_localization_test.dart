import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';
import 'package:vps_tell_you/l10n/locale_preference.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/settings/reminder_planner.dart';
import 'package:vps_tell_you/settings/reminder_rule.dart';
import 'package:vps_tell_you/settings/reminder_scheduler.dart';

import 'support/reminder_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  tz_data.initializeTimeZones();
  final en = AppLocalizationsEn(), zh = AppLocalizationsZh();
  final now = DateTime.utc(2026, 10, 7);
  const due = LedgerDate(2026, 10, 20);

  test(
    'notification locale changes text only, retaining dates, IDs and privacy',
    () {
      for (final usage in UsagePlan.values) {
        final input = ReminderInput(
          rule: ReminderRule(
            id: 1,
            serverId: 'DO-NOT-LEAK-SERVER-ID',
            usagePlan: usage,
          ),
          dueDate: due,
        );
        final english = planReminders(
          inputs: [input],
          now: now,
          location: tz.getLocation('Asia/Shanghai'),
          capacity: 64,
          localizations: en,
        ).selected;
        final chinese = planReminders(
          inputs: [input],
          now: now,
          location: tz.getLocation('Asia/Shanghai'),
          capacity: 64,
          localizations: zh,
        ).selected;
        expect(
          english.map((r) => r.notificationId),
          chinese.map((r) => r.notificationId),
        );
        expect(english.map((r) => r.at), chinese.map((r) => r.at));
        for (final item in english) {
          expect(item.title, 'Check VPS expiry');
          expect(item.body, contains('2026-10-20'));
          expect(item.body, isNot(contains('DO-NOT-LEAK')));
          expect(item.body, isNot(matches(RegExp(r'[\u3400-\u9fff]'))));
        }
        for (final item in chinese) {
          expect(item.title, 'VPS 到期核对');
          expect(item.body, contains('2026-10-20'));
        }
      }
    },
  );

  test('saving and relaunching English reschedules existing reminders without changing ledger data', () async {
    final directory = await Directory.systemTemp.createTemp('reminder-l10n-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/ledger.db';
    var store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => now,
    );
    await store.saveServer(
      ServerRecord(
        id: 'fixture',
        name: 'DO-NOT-LEAK-NAME',
        vendor: 'DO-NOT-LEAK-PROVIDER',
        billing: BillingKind.prepaid,
        currency: 'EUR',
        amountMinor: 2400,
        dueDate: due,
        createdAt: now,
        updatedAt: now,
      ),
      isNew: true,
    );
    final platform = FakeReminderPlatform();
    var controller = LedgerController(
      store,
      clock: () => now,
      reminderPlatform: platform,
    );
    await controller.refresh();
    await controller.reminders.reconcile();
    final before = await store.exportLedgerBackup();
    final originalIds = platform.pending.keys.toSet();
    expect(originalIds, isNotEmpty);
    expect(
      platform.pending.values.every(
        (r) => r.title == zh.expiryNotificationTitle,
      ),
      isTrue,
    );
    await controller.setLanguage(LocalePreference.english);
    await controller.reminders.reconcile();
    expect(platform.pending.keys.toSet(), originalIds);
    expect(
      platform.pending.values.every(
        (r) => r.title == en.expiryNotificationTitle,
      ),
      isTrue,
    );
    expect(
      platform.pending.values.every((r) => !r.body.contains('DO-NOT-LEAK')),
      isTrue,
    );
    expect(platform.requests, 0);
    final after = await store.exportLedgerBackup();
    expect(after.servers, before.servers);
    expect(after.payments, before.payments);
    expect(after.fx, before.fx);
    controller.dispose();
    await store.close();
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => now,
    );
    controller = LedgerController(
      store,
      clock: () => now,
      reminderPlatform: platform,
    );
    await controller.refresh();
    await controller.reminders.reconcile();
    expect(controller.languagePreference, LocalePreference.english);
    expect(
      platform.pending.values.every(
        (r) => r.title == en.expiryNotificationTitle,
      ),
      isTrue,
    );
    controller.dispose();
    await store.close();
  });

  test(
    'notification submission failure cannot undo a saved language preference',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'reminder-l10n-failure-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${directory.path}/ledger.db',
        clock: () => now,
      );
      await store.saveServer(
        ServerRecord(
          id: 'fixture',
          name: 'Synthetic',
          vendor: 'Synthetic',
          billing: BillingKind.prepaid,
          amountMinor: 100,
          dueDate: due,
          createdAt: now,
          updatedAt: now,
        ),
        isNew: true,
      );
      final platform = FakeReminderPlatform()..failSchedule = true;
      final controller = LedgerController(
        store,
        clock: () => now,
        reminderPlatform: platform,
      );
      await controller.refresh();
      await controller.setLanguage(LocalePreference.english);
      await controller.reminders.reconcile();
      expect(controller.languagePreference, LocalePreference.english);
      expect(await store.languagePreference(), LocalePreference.english);
      expect(controller.reminders.state, ReminderSyncState.failed);
      expect(controller.reminders.descriptionFor(en), en.reminderCheckFailed);
      expect(platform.requests, 0);
      controller.dispose();
      await store.close();
    },
  );
}
