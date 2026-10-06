import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';

final now = DateTime(2026, 10, 6, 12);
ServerRecord record({
  String id = 'server-1',
  String? group,
  int? amount = 4999,
  String host = '192.0.2.1',
  int revision = 0,
}) => ServerRecord(
  id: id,
  name: 'HK-01',
  vendor: 'Test vendor',
  host: host,
  groupId: group,
  billing: BillingKind.prepaid,
  amountMinor: amount,
  dueDate: const LedgerDate(2026, 10, 13),
  createdAt: now,
  updatedAt: now,
  revision: revision,
);

void main() {
  late Directory directory;
  late String path;
  late LedgerStore store;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('vps-ledger-test-');
    path = '${directory.path}/ledger.db';
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => now,
    );
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  test('real SQLite survives close/reopen with exact money, IDs, favorite and group rename', () async {
    expect(await store.servers(), isEmpty);
    await store.saveGroup('生产');
    final group = (await store.groups()).single;
    await store.saveServer(record(group: group.id), isNew: true);
    await store.setFavorite((await store.servers()).single, true);
    await store.saveGroup('Production', id: group.id);
    await store.close();
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => now,
    );
    final server = (await store.servers()).single;
    expect(server.id, 'server-1');
    expect(server.favorite, isTrue);
    expect(server.groupId, group.id);
    expect(server.amountMinor, 4999);
    expect((await store.groups()).single.name, 'Production');
    final edited = ServerRecord.fromMap({
      ...server.toMap(),
      'name': 'Edited',
      'amount_minor': 0,
    });
    await store.saveServer(edited, isNew: false);
    expect((await store.servers()).single.money!.decimal, '0.00');
    await expectLater(
      store.saveServer(server, isNew: false),
      throwsA(isA<LedgerConflict>()),
    );
  });

  test('archive, delete group, reopen and undo preserve record and restore as ungrouped', () async {
    await store.saveGroup('实验');
    final group = (await store.groups()).single;
    await store.saveServer(record(group: group.id), isNew: true);
    await store.saveServer(
      record(id: 'server-2', group: group.id),
      isNew: true,
    );
    final undo = await store.archive((await store.servers()).first);
    await store.deleteGroup(group.id);
    expect((await store.servers()).every((s) => s.groupId == null), isTrue);
    await store.close();
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => now,
    );
    await store.undoArchive(undo);
    final records = await store.servers();
    expect(records.length, 2);
    expect(records.every((s) => !s.archived), isTrue);
    expect(records.every((s) => s.amountMinor == 4999), isTrue);
    await expectLater(store.undoArchive(undo), throwsA(isA<LedgerConflict>()));
    final again = await store.archive(records.first);
    await expectLater(store.undoArchive(undo), throwsA(isA<LedgerConflict>()));
    await store.undoArchive(again);
  });

  test('group ordering, case-insensitive duplicate, and stale group save are atomic', () async {
    await store.saveGroup('A');
    await store.saveGroup('B');
    final groups = await store.groups();
    await store.moveGroup(groups.last.id, -1);
    expect((await store.groups()).map((g) => g.name), ['B', 'A']);
    await expectLater(store.saveGroup('a'), throwsA(isA<DatabaseException>()));
    await store.deleteGroup(groups.first.id);
    await expectLater(
      store.saveServer(record(group: groups.first.id), isNew: true),
      throwsA(isA<LedgerConflict>()),
    );
    expect(await store.servers(), isEmpty);
  });

  test('explicit demo is dated from injected today, remains labeled and cannot duplicate', () async {
    expect(await store.servers(), isEmpty);
    await store.loadDemo();
    final rows = await store.servers();
    expect(rows.length, 4);
    expect(rows.every((s) => s.isDemo), isTrue);
    expect(rows.first.dueDate.toString(), '2026-10-13');
    await expectLater(store.loadDemo(), throwsStateError);
    expect((await store.servers()).length, 4);
  });

  test('search/favorite/group/due/sort use true calendar dates and the 30-day boundary', () async {
    await store.loadDemo();
    final c = LedgerController(store, clock: () => now);
    await c.refresh();
    c.updateFilters(query: '192.0.2');
    expect(c.visible.single.name, 'HK-01');
    c.resetFilters();
    c.updateFilters(category: ServerFilter.favorites);
    expect(c.visible.length, 2);
    c.updateFilters(category: ServerFilter.pending);
    expect(c.visible.length, 2);
    c.updateFilters(due: DueFilter.overdue);
    expect(c.visible.single.name, 'JP-01');
    c.resetFilters();
    c.setGroup('');
    expect(c.visible, isEmpty);
    c.setGroup(c.groups.single.id);
    c.updateFilters(order: ServerSort.due);
    expect(c.visible.first.name, 'JP-01');
    final boundary = ServerRecord.fromMap({
      ...record().toMap(),
      'due_date': '2026-11-05',
    });
    expect(c.dueIn(boundary), 30);
    expect(c.isPending(boundary), isFalse);
    c.dispose();
  });

  test(
    'committed write retains its result when only list reload fails',
    () async {
      final c = FailingReadController(store);
      final result = await c.mutate(() async {
        await store.saveServer(record(), isNew: true);
        return 'committed-id';
      });
      expect(result, 'committed-id');
      expect(c.refreshFailed, isTrue);
      expect(c.busy, isFalse);
      expect(c.canMutate, isFalse);
      var attemptedDuplicate = false;
      await expectLater(
        c.mutate(() async => attemptedDuplicate = true),
        throwsStateError,
      );
      expect(attemptedDuplicate, isFalse);
      expect((await store.servers()).length, 1);
      c.fail = false;
      await c.refresh();
      expect(c.refreshFailed, isFalse);
      expect(c.canMutate, isTrue);
      expect(c.active.length, 1);
      c.dispose();
    },
  );

  test(
    'unsupported newer schema is never downgraded, cleared or recreated',
    () async {
      final futurePath = '${directory.path}/future.db';
      final future = await databaseFactoryFfiNoIsolate.openDatabase(
        futurePath,
        options: OpenDatabaseOptions(
          version: 99,
          onCreate: (db, _) async {
            await db.execute('CREATE TABLE marker (value TEXT)');
            await db.insert('marker', {'value': 'keep'});
          },
        ),
      );
      await future.close();
      await expectLater(
        LedgerStore.open(
          factory: databaseFactoryFfiNoIsolate,
          path: futurePath,
        ),
        throwsA(anything),
      );
      final preserved = await databaseFactoryFfiNoIsolate.openDatabase(
        futurePath,
      );
      expect(await preserved.getVersion(), 99);
      expect((await preserved.query('marker')).single['value'], 'keep');
      await preserved.close();
    },
  );

  test('corrupt database open fails without destructive recovery', () async {
    final corrupt = File('${directory.path}/corrupt.db');
    final bytes = List<int>.generate(8192, (i) => 65 + i % 20);
    await corrupt.writeAsBytes(bytes);
    await expectLater(
      LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: corrupt.path,
      ),
      throwsA(anything),
    );
    expect(await corrupt.readAsBytes(), bytes);
  });

  test('calendar leap anchors and money parse retain exact values and reject malformed inputs', () {
    expect(const LedgerDate(2024, 1, 31).addMonths(1).toString(), '2024-02-29');
    expect(const LedgerDate(2024, 1, 31).addMonths(2).toString(), '2024-03-31');
    expect(
      const LedgerDate(2024, 2, 29).addMonths(12).toString(),
      '2025-02-28',
    );
    expect(LedgerDate.tryParse('2026-02-30'), isNull);
    expect(
      const LedgerDate(2026, 3, 7).daysUntil(const LedgerDate(2026, 3, 9)),
      2,
    );
    expect(Money.parseMinor('0.10')! + Money.parseMinor('0.20')!, 30);
    expect(Money.parseMinor('0'), 0);
    expect(Money.parseMinor(''), isNull);
    expect(Money.parseMinor('1.001'), isNull);
    expect(Money.parseMinor('-1'), isNull);
    for (final host in [
      'https://example.com',
      'name@example.com',
      'example.com:22',
      'host/path',
      'host?x=1',
    ]) {
      expect(record(host: host).validate(), isNotNull, reason: host);
    }
    for (final host in [
      '192.0.2.1',
      '2001:db8::1',
      'vps.example.com',
      'localhost',
      '',
    ]) {
      expect(record(host: host).validate(), isNull, reason: host);
    }
  });
}

class FailingReadController extends LedgerController {
  FailingReadController(super.store);
  bool fail = true;
  @override
  Future<void> refresh() async {
    if (fail) throw StateError('simulated reload failure');
    await super.refresh();
  }
}
