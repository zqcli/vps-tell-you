import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/finance/finance_math.dart';
import 'package:vps_tell_you/finance/finance_models.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';

final now = DateTime(2026, 9, 23, 12);
LedgerDate d(String s) => LedgerDate.tryParse(s)!;
ServerRecord fixture({
  String id = 's',
  String? group,
  int cycle = 12,
  String? start = '2026-01-01',
  String? due = '2027-01-01',
  BillingKind billing = BillingKind.prepaid,
  bool archived = false,
  String currency = 'USD',
}) => ServerRecord(
  id: id,
  name: 'Server $id',
  vendor: 'Test vendor',
  groupId: group,
  createdAt: now,
  updatedAt: now,
  billing: billing,
  amountMinor: 3650,
  currency: currency,
  cycleMonths: cycle,
  startDate: start == null ? null : d(start),
  dueDate: due == null ? null : d(due),
  archivedAt: archived ? now : null,
);
ServerRecord edit(ServerRecord s, Map<String, Object?> values) =>
    ServerRecord.fromMap({...s.toMap(), ...values});

void main() {
  late Directory dir;
  late String path;
  late LedgerStore store;
  Future<void> reopen() async {
    await store.close();
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => now,
    );
  }

  Future<Database> raw() => databaseFactoryFfiNoIsolate.openDatabase(path);
  Future<ServerRecord> only() async => (await store.servers()).single;
  Future<PaymentRecord> pay(
    ServerRecord s, {
    String id = 'payment',
    int cycles = 1,
    int minor = 100,
    LedgerDate? until,
    LedgerDate? date,
    bool confirmed = true,
  }) => store.recordPayment(
    id: id,
    server: s,
    amount: Money('EUR', minor),
    paidDate: date ?? LedgerDate.today(now),
    cycleCount: cycles,
    until: until ?? renewalDate(s, cycles),
    confirmed: confirmed,
    note: 'discount',
  );
  setUp(() async {
    sqfliteFfiInit();
    dir = await Directory.systemTemp.createTemp('finance-store-');
    path = '${dir.path}/ledger.db';
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => now,
    );
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });

  test('true v1 migration preserves every old field, infers only known periods, no invented payments or FX', () async {
    await store.close();
    await File(path).delete();
    final originals = [
      fixture(id: 'known', group: 'g'),
      fixture(id: 'inferred', start: null, currency: 'EUR'),
      fixture(id: 'undated', start: null, due: null),
      fixture(id: 'archive', archived: true, group: 'g'),
      fixture(
        id: 'metered',
        billing: BillingKind.metered,
        start: null,
        due: null,
      ),
    ];
    final oldMaps = originals
        .map(
          (r) => r.toMap()
            ..remove('renewal_anchor_date')
            ..remove('resources_json')
            ..remove('provider_id'),
        )
        .toList();
    final v1 = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await createV1(db);
          await db.insert('server_groups', {
            'id': 'g',
            'name': 'Production',
            'position': 2,
          });
          for (final row in oldMaps) {
            await db.insert('servers', row);
          }
        },
      ),
    );
    await v1.close();
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => now,
    );
    await reopen();
    final loaded = await store.servers();
    for (final expected in oldMaps) {
      final actual = loaded.singleWhere((r) => r.id == expected['id']).toMap()
        ..remove('renewal_anchor_date')
        ..remove('resources_json')
        ..remove('provider_id');
      expect(actual, expected);
    }
    expect((await store.groups()).single.name, 'Production');
    final ps = await store.servicePeriods();
    expect(ps.map((p) => p.serverId).toSet(), {'known', 'inferred', 'archive'});
    expect(ps.singleWhere((p) => p.serverId == 'known').inferred, isFalse);
    final inferred = ps.singleWhere((p) => p.serverId == 'inferred');
    expect(inferred.inferred, isTrue);
    expect(inferred.start, d('2026-01-01'));
    expect(
      loaded.singleWhere((r) => r.id == 'known').renewalAnchorDate,
      d('2027-01-01'),
    );
    expect(await store.payments(), isEmpty);
    final fx = await store.fxSettings();
    expect(fx.usdToCny, isNull);
    expect(fx.eurToCny, isNull);
    expect(fx.rateDate, isNull);
    expect(await (await raw()).getVersion(), LedgerStore.schemaVersion);
  });

  test('advance two-period payment commits once under double submit, reopen retry and stale competing key', () async {
    await store.saveServer(fixture(), isNew: true);
    final original = await only();
    final results = await Future.wait([
      pay(original, cycles: 2),
      pay(original, cycles: 2),
    ]);
    expect(results.map((p) => p.id).toSet(), {'payment'});
    var current = await only();
    expect(current.dueDate, d('2029-01-01'));
    expect(current.startDate, original.startDate);
    expect(current.amountMinor, 3650);
    expect(current.currency, 'USD');
    expect((await store.payments()).single.amount.currency, 'EUR');
    expect((await store.servicePeriods()).length, 3);
    expect(
      serverValuation(
        current,
        await store.servicePeriods(),
        d('2026-09-23'),
      )!.amount.minor,
      Rational.of(8300),
    );
    await reopen();
    expect((await pay(original, cycles: 2)).id, 'payment');
    expect((await store.payments()).length, 1);
    expect((await store.servicePeriods()).length, 3);
    await expectLater(
      pay(original, id: 'other', cycles: 2),
      throwsA(isA<LedgerConflict>()),
    );
    await expectLater(
      pay(original, cycles: 2, minor: 101),
      throwsArgumentError,
    );
    current = await only();
    expect(current.revision, 1);
    expect((await store.payments()).length, 1);
  });

  test('SQLite trigger abort at final due update rolls back prior payment and period inserts', () async {
    await store.saveServer(fixture(), isNew: true);
    final before = await only();
    final db = await raw();
    await db.execute(
      "CREATE TRIGGER abort_due BEFORE UPDATE OF due_date ON servers BEGIN SELECT RAISE(ABORT, 'test rollback'); END",
    );
    await expectLater(
      pay(before, cycles: 2),
      throwsA(isA<DatabaseException>()),
    );
    expect(await store.payments(), isEmpty);
    expect((await store.servicePeriods()).length, 1);
    expect((await only()).toMap(), before.toMap());
    await db.execute('DROP TRIGGER abort_due');
    await pay(before, cycles: 2);
    expect((await store.payments()).length, 1);
  });

  test('confirmation, calendar range, future date, stale revision and invalid until leave no partial writes', () async {
    await store.saveServer(fixture(), isNew: true);
    final before = await only();
    await expectLater(pay(before, confirmed: false), throwsArgumentError);
    await expectLater(
      pay(before, date: LedgerDate.today(now).addDays(1)),
      throwsArgumentError,
    );
    await expectLater(pay(before, until: d('2028-01-02')), throwsArgumentError);
    await expectLater(pay(before, minor: -1), throwsArgumentError);
    await expectLater(pay(before, cycles: 4), throwsArgumentError);
    await store.setFavorite(before, true);
    await expectLater(pay(before), throwsA(isA<LedgerConflict>()));
    expect(await store.payments(), isEmpty);
    expect((await store.servicePeriods()).length, 1);
    expect((await only()).dueDate, before.dueDate);
  });

  test('durable monthly anchor survives separate commits/reopen; undo is atomic, tombstoned and conflict-safe', () async {
    await store.saveServer(
      fixture(cycle: 1, start: '2023-12-31', due: '2024-01-31'),
      isNew: true,
    );
    final firstInput = await only();
    final first = await pay(firstInput, id: 'first');
    expect((await only()).dueDate, d('2024-02-29'));
    await reopen();
    final secondInput = await only();
    final second = await pay(secondInput, id: 'second');
    expect((await only()).dueDate, d('2024-03-31'));
    expect((await only()).renewalAnchorDate, d('2024-01-31'));
    final c = LedgerController(store);
    await c.refresh();
    expect(c.canUndoPayment(first), isFalse);
    expect(c.canUndoPayment(second), isTrue);
    await expectLater(
      store.undoPayment('first'),
      throwsA(isA<LedgerConflict>()),
    );
    await store.undoPayment('second');
    expect((await only()).dueDate, d('2024-02-29'));
    expect((await store.servicePeriods()).length, 2);
    expect(
      (await store.payments()).singleWhere((p) => p.id == 'second').voided,
      isTrue,
    );
    await reopen();
    await expectLater(pay(secondInput, id: 'second'), throwsArgumentError);
    await store.undoPayment(
      'second',
    ); // Harmless repeated undo, cannot revive the key.
    final third = await pay(await only(), id: 'third');
    expect(third.until, d('2024-03-31'));
    await store.setFavorite(await only(), true);
    final changed = await only();
    await expectLater(
      store.undoPayment('third'),
      throwsA(isA<LedgerConflict>()),
    );
    expect((await only()).toMap(), changed.toMap());
    expect(
      (await store.payments()).singleWhere((p) => p.id == 'third').voided,
      isFalse,
    );
    expect((await store.servicePeriods()).length, 3);
    c.dispose();
  });

  test('safe undo restores only due, removes owned periods/payment totals, and never reuses a void key', () async {
    await store.saveServer(fixture(), isNew: true);
    final before = await only();
    await pay(before, cycles: 3, minor: 0);
    await store.undoPayment('payment');
    final restored = await only();
    expect(restored.dueDate, before.dueDate);
    expect(restored.startDate, before.startDate);
    expect(restored.amountMinor, before.amountMinor);
    expect(restored.revision, 2);
    expect((await store.servicePeriods()).length, 1);
    expect(
      recentPayments(await store.payments(), LedgerDate.today(now)),
      isEmpty,
    );
    await expectLater(pay(before, cycles: 3, minor: 0), throwsArgumentError);
  });

  test(
    'SQLite abort at final undo step restores the entire payment transaction',
    () async {
      await store.saveServer(fixture(), isNew: true);
      await pay(await only(), cycles: 2);
      final serverBefore = (await only()).toMap();
      final periodsBefore = (await store.servicePeriods())
          .map((p) => p.toMap())
          .toList();
      final paymentBefore = (await store.payments()).single.toMap();
      final db = await raw();
      await db.execute(
        "CREATE TRIGGER abort_void BEFORE UPDATE OF voided_at ON payments BEGIN SELECT RAISE(ABORT, 'test undo rollback'); END",
      );
      await expectLater(
        store.undoPayment('payment'),
        throwsA(isA<DatabaseException>()),
      );
      expect((await only()).toMap(), serverBefore);
      expect(
        (await store.servicePeriods()).map((p) => p.toMap()).toList(),
        periodsBefore,
      );
      expect((await store.payments()).single.toMap(), paymentBefore);
      await db.execute('DROP TRIGGER abort_void');
      await store.undoPayment('payment');
      expect((await only()).dueDate, d('2027-01-01'));
      expect((await store.servicePeriods()).length, 1);
      expect((await store.payments()).single.voided, isTrue);
    },
  );

  test('independent account bills are stored once, omit group allocations, survive archive and undo without servers', () async {
    final amount = const Money('CNY', 10);
    final account = await store.recordAccountPayment(
      id: 'account',
      accountLabel: ' Provider account ',
      amount: amount,
      paidDate: LedgerDate.today(now),
      from: d('2026-08-01'),
      until: d('2026-09-01'),
    );
    await store.recordAccountPayment(
      id: 'account',
      accountLabel: 'Provider account',
      amount: amount,
      paidDate: LedgerDate.today(now),
      from: d('2026-08-01'),
      until: d('2026-09-01'),
    );
    expect(account.accountLabel, 'Provider account');
    expect(await store.servers(), isEmpty);
    await store.saveGroup('Group');
    final group = (await store.groups()).single;
    for (final id in ['metered1', 'metered2']) {
      await store.saveServer(
        fixture(
          id: id,
          group: group.id,
          billing: BillingKind.metered,
          start: null,
          due: null,
        ),
        isNew: true,
      );
    }
    await store.saveServer(
      fixture(id: 'prepaid', group: group.id),
      isNew: true,
    );
    var records = await store.servers();
    final prepaid = records.singleWhere((s) => s.id == 'prepaid');
    await pay(prepaid, id: 'server-payment');
    await store.archive(
      (await store.servers()).singleWhere((s) => s.id == 'prepaid'),
    );
    await reopen();
    records = await store.servers();
    final all = recentPayments(await store.payments(), LedgerDate.today(now));
    expect(all.length, 2);
    expect(
      recentPayments(
        all,
        LedgerDate.today(now),
        records: records,
        groupId: group.id,
      ).single.id,
      'server-payment',
    );
    expect(
      aggregateAmounts(
        records
            .where((s) => !s.archived)
            .map((s) => monthlyAmount(s, LedgerDate.today(now))),
        const FxSettings(displayCurrency: 'USD'),
      ).formatted,
      '\$73.00',
    );
    await store.undoPayment('account');
    expect(
      (await store.payments()).singleWhere((p) => p.id == 'account').voided,
      isTrue,
    );
    await expectLater(
      store.recordAccountPayment(
        id: 'bad',
        accountLabel: 'provider',
        amount: amount,
        paidDate: LedgerDate.today(now).addDays(1),
      ),
      throwsArgumentError,
    );
    await expectLater(
      store.recordAccountPayment(
        id: 'bad',
        accountLabel: 'provider',
        amount: amount,
        paidDate: LedgerDate.today(now),
        from: d('2026-08-01'),
      ),
      throwsArgumentError,
    );
  });

  test('normal edits and price/FX changes preserve periods, historical original money and read-only trial snapshots', () async {
    await store.saveServer(fixture(), isNew: true);
    await pay(await only(), cycles: 2, minor: 13);
    final before = await only();
    final periodMaps = (await store.servicePeriods())
        .map((p) => p.toMap())
        .toList();
    for (final fields in [
      <String, Object?>{'due_date': '2030-01-01'},
      <String, Object?>{'start_date': '2025-01-01'},
      <String, Object?>{'cycle_months': 1},
      <String, Object?>{'billing': 'metered'},
    ]) {
      await expectLater(
        store.saveServer(edit(before, fields), isNew: false),
        throwsArgumentError,
      );
    }
    await store.saveServer(
      edit(before, {'amount_minor': 7300, 'currency': 'CNY', 'name': 'Edited'}),
      isNew: false,
    );
    expect(
      (await store.servicePeriods()).map((p) => p.toMap()).toList(),
      periodMaps,
    );
    final saved = (await store.payments()).single;
    expect(saved.amount.minor, 13);
    expect(saved.amount.currency, 'EUR');
    expect(saved.targetName, 'Server s');
    final fx = FxSettings(
      displayCurrency: 'EUR',
      usdToCny: '7.1',
      eurToCny: '7.8',
      rateDate: LedgerDate.today(now),
    );
    await expectLater(
      store.saveFx(
        FxSettings(usdToCny: '7', rateDate: LedgerDate.today(now).addDays(1)),
      ),
      throwsArgumentError,
    );
    await store.saveFx(fx);
    await reopen();
    expect((await store.fxSettings()).toMap(), fx.toMap());
    final db = await raw();
    Future<List<Object?>> snapshot() async => [
      await db.query('servers'),
      await db.query('service_periods'),
      await db.query('payments'),
      await db.query('finance_settings'),
    ];
    final state = await snapshot();
    final ps = await store.servicePeriods();
    valueOfPeriods(
      renewal: const Money('EUR', 5000),
      periods: ps,
      asOf: d('2027-02-01'),
    );
    valueOfPeriods(
      renewal: const Money('USD', 100),
      periods: ps,
      asOf: d('2026-02-01'),
    );
    expect(await snapshot(), state);
  });

  test('controller publishes all finance data together and retains committed payment on failed reread', () async {
    await store.saveServer(fixture(), isNew: true);
    final c = LedgerController(store, clock: () => now);
    await c.refresh();
    final visible = c.records.single.toMap();
    final visiblePeriods = c.periods;
    final db = await raw();
    await db.execute('ALTER TABLE finance_settings RENAME TO saved_settings');
    final result = await c.mutate(() => pay(c.records.single));
    expect(result.id, 'payment');
    expect(c.refreshFailed, isTrue);
    expect(c.canMutate, isFalse);
    expect(c.records.single.toMap(), visible);
    expect(c.periods, visiblePeriods);
    expect(c.payments, isEmpty);
    expect((await store.payments()).single.id, 'payment');
    await db.execute('ALTER TABLE saved_settings RENAME TO finance_settings');
    await c.refresh();
    expect(c.refreshFailed, isFalse);
    expect(c.payments.single.id, 'payment');
    expect(c.periods.length, 2);
    expect(c.records.single.dueDate, d('2028-01-01'));
    expect(c.fx.displayCurrency, 'CNY');
    c.dispose();
  });
}

Future<void> createV1(DatabaseExecutor db) async {
  await db.execute(
    '''CREATE TABLE server_groups (
    id TEXT PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE UNIQUE, position INTEGER NOT NULL)''',
  );
  await db.execute('''CREATE TABLE servers (
    id TEXT PRIMARY KEY, name TEXT NOT NULL, vendor TEXT NOT NULL,
    host TEXT NOT NULL DEFAULT '', region TEXT NOT NULL DEFAULT '',
    purpose TEXT NOT NULL DEFAULT '', os TEXT NOT NULL DEFAULT '',
    spec TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '',
    group_id TEXT REFERENCES server_groups(id) ON DELETE SET NULL,
    favorite INTEGER NOT NULL DEFAULT 0 CHECK(favorite IN (0,1)),
    billing TEXT NOT NULL CHECK(billing IN ('unknown','prepaid','metered')),
    currency TEXT NOT NULL CHECK(currency IN ('USD','CNY','EUR')),
    amount_minor INTEGER CHECK(amount_minor >= 0), cycle_months INTEGER NOT NULL,
    start_date TEXT, due_date TEXT, archived_at TEXT,
    created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
    revision INTEGER NOT NULL DEFAULT 0,
    is_demo INTEGER NOT NULL DEFAULT 0 CHECK(is_demo IN (0,1)))''');
  await db.execute('CREATE INDEX servers_group ON servers(group_id)');
  await db.execute('CREATE INDEX servers_archive ON servers(archived_at)');
}
