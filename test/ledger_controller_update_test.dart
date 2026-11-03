import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/finance/finance_models.dart';
import 'package:vps_tell_you/finance/finance_snapshot.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_list_state.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/settings/reminder_scheduler.dart';

import 'support/reminder_platform.dart';

class _CountingReminders extends FakeReminderPlatform {
  int checks = 0;
  @override
  Future<ReminderPermission> permission() {
    checks++;
    return super.permission();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final now = DateTime.utc(2026, 10, 6);
  late Directory directory;
  late String path;
  late LedgerStore store;
  late LedgerController controller;
  late _CountingReminders platform;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ledger-updates-');
    path = '${directory.path}/ledger.db';
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => now,
    );
    await store.saveGroup('A');
    await store.saveServer(
      ServerRecord(
        id: 'server',
        name: 'Alpha',
        vendor: 'Fixture',
        groupId: (await store.groups()).single.id,
        billing: BillingKind.prepaid,
        amountMinor: 1200,
        dueDate: const LedgerDate(2026, 10, 20),
        createdAt: now,
        updatedAt: now,
      ),
      isNew: true,
    );
    platform = _CountingReminders();
    controller = LedgerController(
      store,
      clock: () => now,
      reminderPlatform: platform,
    );
    await controller.refresh();
    await controller.reminders.reconcile();
  });

  tearDown(() async {
    controller.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  test(
    'list controls notify only the list and preserve financial snapshots',
    () {
      var ledgerChanges = 0, listChanges = 0;
      controller.addListener(() => ledgerChanges++);
      controller.listState.addListener(() => listChanges++);
      final finance = FinanceScope.of(controller, null);

      controller.listState.updateFilters(query: 'Alpha');
      expect(controller.visible.single.id, 'server');
      controller.listState.updateFilters(category: ServerFilter.favorites);
      expect(controller.visible, isEmpty);
      controller.listState.setGroup('');
      controller.listState.resetFilters();

      expect(controller.visible.single.id, 'server');
      expect(listChanges, 4);
      expect(ledgerChanges, 0);
      expect(FinanceScope.of(controller, null), same(finance));
    },
  );

  test(
    'small writes preserve unrelated data and do not reschedule reminders',
    () async {
      final records = controller.records;
      final periods = controller.periods;
      final payments = controller.payments;
      final rules = controller.reminderRules;
      final checks = platform.checks;
      final schedules = platform.schedules;
      final cancelled = platform.cancelled.length;
      final group = controller.groups.single;

      await controller.setThemeMode('dark');
      expect(controller.themeMode, 'dark');
      expect(await store.themeMode(), 'dark');
      await controller.saveFx(const FxSettings(displayCurrency: 'USD'));
      expect(controller.fx.displayCurrency, 'USD');
      await controller.saveGroup('Renamed', id: group.id);
      await controller.saveGroup('B');
      await controller.moveGroup(controller.groups.last.id, -1);
      expect(controller.groups.map((g) => g.name), ['B', 'Renamed']);
      expect(controller.records, same(records));

      await controller.setFavorite(controller.byId('server')!, true);
      expect(controller.byId('server')!.favorite, isTrue);
      expect(controller.byId('server')!.revision, 1);
      controller.listState.setGroup(group.id);
      await controller.deleteGroup(group.id);
      expect(controller.byId('server')!.groupId, isNull);
      expect(controller.listState.groupFilter, isNull);
      expect(controller.periods, same(periods));
      expect(controller.payments, same(payments));
      expect(controller.reminderRules, same(rules));
      await Future<void>.delayed(Duration.zero);
      expect(platform.checks, checks);
      expect(platform.schedules, schedules);
      expect(platform.cancelled.length, cancelled);

      await controller.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(platform.checks, greaterThan(checks));
      await controller.reminders.reconcile();
      expect(controller.reminders.state, ReminderSyncState.ready);
    },
  );

  test('a committed favorite survives a targeted reload failure', () async {
    final db = await databaseFactoryFfiNoIsolate.openDatabase(path);
    await db.execute('''CREATE TRIGGER corrupt_resource
      AFTER UPDATE OF favorite ON servers BEGIN
        UPDATE servers SET resources_json = '{' WHERE id = NEW.id;
      END''');

    await controller.setFavorite(controller.byId('server')!, true);
    expect(controller.refreshFailed, isTrue);
    expect(controller.busy, isFalse);
    expect((await db.query('servers')).single['favorite'], 1);
    await expectLater(
      controller.setFavorite(controller.byId('server')!, true),
      throwsStateError,
    );
    expect((await db.query('servers')).single['revision'], 1);

    await db.execute('DROP TRIGGER corrupt_resource');
    await db.update('servers', {'resources_json': null});
    await controller.refresh();
    await controller.reminders.reconcile();
    expect(controller.canMutate, isTrue);
    expect(controller.byId('server')!.favorite, isTrue);
  });
}
