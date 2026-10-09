import 'support/provider_fixture.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/settings/reminder_rule.dart';
import 'package:vps_tell_you/settings/reminder_scheduler.dart';

import 'support/reminder_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final now = DateTime.utc(2026, 10, 6);
  late Directory directory;
  late String path;
  late LedgerStore store;
  late FakeReminderPlatform platform;
  late ReminderScheduler scheduler;
  ServerRecord record(
    String id, {
    LedgerDate due = const LedgerDate(2026, 10, 20),
  }) => ServerRecord(
    id: id,
    name: 'Fixture $id',
    vendor: 'Fixture',
    host: '192.0.2.1',
    billing: BillingKind.prepaid,
    amountMinor: 3650,
    dueDate: due,
    createdAt: now,
    updatedAt: now,
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('reminder-test-');
    path = '${directory.path}/ledger.sqlite';
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => now,
    );
    platform = FakeReminderPlatform();
    scheduler = ReminderScheduler(store, platform: platform, clock: () => now);
    await store.saveServer(record('one'), isNew: true);
  });
  tearDown(() async {
    scheduler.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  test(
    'rules auto-create durably; revisions and archive conflicts are enforced',
    () async {
      final rule = (await store.reminderRules()).single;
      expect(rule.leadDays, [7, 3, 1]);
      await store.saveReminderRule(
        rule.copyWith(minuteOfDay: 600, usagePlan: UsagePlan.stopAtExpiry),
      );
      await expectLater(
        store.saveReminderRule(rule.copyWith(enabled: false)),
        throwsA(isA<LedgerConflict>()),
      );
      await store.saveThemeMode('dark');
      await store.close();
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      final saved = (await store.reminderRules()).single;
      expect(saved.id, rule.id);
      expect(saved.revision, 1);
      expect(saved.minuteOfDay, 600);
      expect(await store.themeMode(), 'dark');
      await store.archive((await store.servers()).single);
      await expectLater(
        store.saveReminderRule(saved),
        throwsA(isA<LedgerConflict>()),
      );
    },
  );

  test(
    'v5 upgrade preserves prior ledger rows and adds rules/default appearance',
    () async {
      final raw = await databaseFactoryFfiNoIsolate.openDatabase(path);
      await removeProviderSchema(raw);
      final before = await raw.query('servers');
      final periods = await raw.query('service_periods');
      await raw.execute('DROP TRIGGER server_reminder');
      await raw.execute('DROP TABLE reminder_rules');
      await raw.execute('DROP TABLE app_settings');
      await raw.execute('ALTER TABLE servers DROP COLUMN resources_json');
      await raw.setVersion(5);
      await store.close();
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      final upgraded = await databaseFactoryFfiNoIsolate.openDatabase(path);
      expect(await upgraded.getVersion(), LedgerStore.schemaVersion);
      expect(
        (await upgraded.query('servers'))
            .map(legacyProviderProjection)
            .toList(),
        before,
      );
      expect(await upgraded.query('service_periods'), periods);
      expect((await store.reminderRules()).single.serverId, 'one');
      expect(await store.themeMode(), 'system');
    },
  );

  test(
    'submits real candidate instants then verifies OS pending IDs',
    () async {
      await scheduler.reconcile();
      expect(scheduler.state, ReminderSyncState.ready);
      expect(scheduler.submitted, 3);
      expect(scheduler.uncovered, 0);
      expect(platform.requests, 0);
      expect(
        platform.pending.values.first.at.toUtc(),
        DateTime.utc(2026, 10, 13, 1),
      );
      expect(platform.pending.values.first.body, contains('2026-10-20'));
      platform.omitPending = true;
      await scheduler.reconcile();
      expect(scheduler.state, ReminderSyncState.failed);
      expect(scheduler.submitted, 0);
    },
  );

  test('denial/revocation cancels old tasks; request result is not assumed allowed', () async {
    await scheduler.reconcile();
    platform.permissionValue = ReminderPermission.denied;
    await scheduler.requestPermission();
    expect(platform.requests, 1);
    expect(scheduler.state, ReminderSyncState.denied);
    expect(platform.pending, isEmpty);
    expect((await store.reminderRules()).single.enabled, isTrue);
  });

  test(
    'unsupported platform never calls native schedule or requests',
    () async {
      platform.supported = false;
      await scheduler.reconcile();
      expect(scheduler.state, ReminderSyncState.unsupported);
      expect(scheduler.submitted, 0);
      expect(platform.schedules, 0);
      expect(platform.requests, 0);
    },
  );

  test(
    'rule disable/archive cancel; restore retains same stable rule ID',
    () async {
      await scheduler.reconcile();
      final rule = (await store.reminderRules()).single;
      await store.saveReminderRule(rule.copyWith(enabled: false));
      await scheduler.reconcile();
      expect(platform.pending, isEmpty);
      await store.saveReminderRule(
        (await store.reminderRules()).single.copyWith(enabled: true),
      );
      await scheduler.reconcile();
      final token = await store.archive((await store.servers()).single);
      await scheduler.reconcile();
      expect(platform.pending, isEmpty);
      await store.undoArchive(token);
      await scheduler.reconcile();
      expect((await store.reminderRules()).single.id, rule.id);
      expect(platform.pending.length, 3);
    },
  );

  test(
    'timezone refresh replaces old instants; unknown timezone fails honestly',
    () async {
      await scheduler.reconcile();
      final first = platform.pending.values.first;
      platform.zone = 'America/New_York';
      await scheduler.reconcile();
      expect(
        platform.pending[first.notificationId]!.at.toUtc(),
        DateTime.utc(2026, 10, 13, 13),
      );
      expect(scheduler.timezoneName, 'America/New_York');
      platform.zone = 'not/a-zone';
      await scheduler.reconcile();
      expect(scheduler.state, ReminderSyncState.failed);
      expect(
        platform.pending,
        isNotEmpty,
      ); // failure does not falsely claim removal
    },
  );

  test(
    'one-year horizon and global capacity expose uncovered reminders',
    () async {
      platform.capacity = 2;
      await store.saveServer(
        record('future', due: const LedgerDate(2039, 1, 1)),
        isNew: true,
      );
      await scheduler.reconcile();
      expect(scheduler.submitted, 2);
      expect(scheduler.uncovered, 4);
      expect(platform.pending.values.every((r) => r.serverId == 'one'), isTrue);
    },
  );

  test(
    'late native schedule cannot overtake newer disable reconciliation',
    () async {
      platform.gate = Completer<void>();
      final first = scheduler.reconcile();
      while (platform.schedules == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      await store.saveReminderRule(
        (await store.reminderRules()).single.copyWith(enabled: false),
      );
      final second = scheduler.reconcile();
      expect(platform.schedules, 1);
      platform.gate!.complete();
      await Future.wait([first, second]);
      expect(platform.maxActive, 1);
      expect(platform.pending, isEmpty);
      expect(scheduler.submitted, 0);
      expect(scheduler.state, ReminderSyncState.ready);
    },
  );

  test(
    'schedule/cancel failures preserve saved rule and permit explicit retry',
    () async {
      platform.failSchedule = true;
      await scheduler.reconcile();
      expect(scheduler.state, ReminderSyncState.failed);
      expect((await store.reminderRules()).single.enabled, isTrue);
      platform.failSchedule = false;
      await scheduler.reconcile();
      expect(scheduler.state, ReminderSyncState.ready);
      platform.failCancel = true;
      await scheduler.reconcile();
      expect(scheduler.state, ReminderSyncState.failed);
      platform.failCancel = false;
      await scheduler.reconcile();
      expect(scheduler.state, ReminderSyncState.ready);
    },
  );
}
