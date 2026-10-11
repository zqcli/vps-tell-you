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
  Future<ServerRecord> only2(String id) async =>
      (await store.servers()).firstWhere((s) => s.id == id);
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

  test('durable monthly anchor survives separate commits/reopen; undo is atomic, tombstoned and conflict-safe; unrelated edits do not block it', () async {
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
    // An unrelated edit (favourite) bumps the revision but must not block the
    // rollback of the tail renewal; a stale expected revision still does.
    await store.setFavorite(await only(), true);
    final changed = await only();
    await expectLater(
      store.deletePayment(
        original: third,
        rollbackRenewal: true,
        expectedServerRevision: changed.revision - 1,
      ),
      throwsA(isA<LedgerConflict>()),
    );
    expect((await only()).toMap(), changed.toMap());
    expect(
      (await store.payments()).singleWhere((p) => p.id == 'third').voided,
      isFalse,
    );
    expect((await store.servicePeriods()).length, 3);
    await store.undoPayment('third');
    expect((await only()).dueDate, d('2024-02-29'));
    expect((await only()).favorite, isTrue);
    expect((await store.servicePeriods()).length, 2);
    expect(
      (await store.payments()).singleWhere((p) => p.id == 'third').voided,
      isTrue,
    );
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

  group('edit and delete payments', () {
    Future<PaymentRecord> stored(String id) async =>
        (await store.payments()).singleWhere((p) => p.id == id);

    test(
      'edit changes only bookkeeping fields; periods, due date and cycle stay',
      () async {
        await store.saveServer(fixture(), isNew: true);
        final created = await pay(await only(), cycles: 2);
        final serverBefore = (await only()).toMap();
        final periodsBefore = (await store.servicePeriods())
            .map((p) => p.toMap())
            .toList();
        final edited = await store.editPayment(
          original: created,
          amount: const Money('USD', 4321),
          paidDate: d('2026-09-01'),
          note: 'corrected',
        );
        expect(edited.amount.currency, 'USD');
        expect(edited.amount.minor, 4321);
        expect(edited.paidDate, d('2026-09-01'));
        expect(edited.note, 'corrected');
        expect(edited.cycleCount, 2);
        expect(edited.until, created.until);
        expect(edited.from, created.from);
        expect(edited.requestFingerprint, created.requestFingerprint);
        expect((await only()).toMap(), serverBefore);
        expect(
          (await store.servicePeriods()).map((p) => p.toMap()).toList(),
          periodsBefore,
        );
        // The edit persists, and the original idempotency key still maps to
        // the same record instead of creating a second payment.
        await reopen();
        expect((await stored('payment')).amount.minor, 4321);
        expect((await store.payments()).length, 1);
      },
    );

    test('edit works after the server was edited or renewed again', () async {
      await store.saveServer(fixture(), isNew: true);
      final first = await pay(await only(), id: 'first');
      await pay(await only(), id: 'second');
      await store.setFavorite(await only(), true);
      final c = LedgerController(store);
      await c.refresh();
      expect(c.canUndoPayment(first), isFalse);
      final edited = await store.editPayment(
        original: first,
        amount: const Money('CNY', 500),
        paidDate: first.paidDate,
        note: '',
      );
      expect(edited.amount.currency, 'CNY');
      expect(edited.amount.minor, 500);
      expect((await only()).dueDate, d('2029-01-01'));
      c.dispose();
    });

    test('account bill edit renames label and target together', () async {
      final bill = await store.recordAccountPayment(
        id: 'account',
        accountLabel: 'Old',
        amount: const Money('CNY', 10),
        paidDate: d('2026-09-01'),
      );
      final edited = await store.editPayment(
        original: bill,
        amount: const Money('CNY', 20),
        paidDate: d('2026-09-02'),
        accountLabel: '  New name ',
      );
      expect(edited.accountLabel, 'New name');
      expect(edited.targetName, 'New name');
      await expectLater(
        store.editPayment(
          original: edited,
          amount: const Money('CNY', 20),
          paidDate: d('2026-09-02'),
          accountLabel: '   ',
        ),
        throwsArgumentError,
      );
    });

    test(
      'invalid edits and a stale original leave the row untouched',
      () async {
        await store.saveServer(fixture(), isNew: true);
        final created = await pay(await only());
        for (final bad in [
          (const Money('USD', -1), d('2026-09-01')),
          (const Money('GBP', 1), d('2026-09-01')),
          (const Money('USD', 1), LedgerDate.today(now).addDays(1)),
        ]) {
          await expectLater(
            store.editPayment(
              original: created,
              amount: bad.$1,
              paidDate: bad.$2,
            ),
            throwsArgumentError,
          );
        }
        expect((await stored('payment')).toMap(), created.toMap());
        final winner = await store.editPayment(
          original: created,
          amount: const Money('USD', 7),
          paidDate: created.paidDate,
        );
        // A second editor still holding the first snapshot is rejected.
        await expectLater(
          store.editPayment(
            original: created,
            amount: const Money('USD', 8),
            paidDate: created.paidDate,
          ),
          throwsA(isA<LedgerConflict>()),
        );
        await expectLater(
          store.deletePayment(original: created),
          throwsA(isA<LedgerConflict>()),
        );
        expect((await stored('payment')).toMap(), winner.toMap());
      },
    );

    test('SQLite abort during edit rolls the whole update back', () async {
      await store.saveServer(fixture(), isNew: true);
      final created = await pay(await only());
      final db = await raw();
      await db.execute(
        "CREATE TRIGGER abort_edit BEFORE UPDATE OF note ON payments BEGIN SELECT RAISE(ABORT, 'test edit rollback'); END",
      );
      await expectLater(
        store.editPayment(
          original: created,
          amount: const Money('USD', 999),
          paidDate: created.paidDate,
          note: 'changed',
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect((await stored('payment')).toMap(), created.toMap());
      await db.execute('DROP TRIGGER abort_edit');
      await db.close();
    });

    test(
      'delete with rollback restores due date and periods like undo',
      () async {
        await store.saveServer(fixture(), isNew: true);
        final before = await only();
        final created = await pay(before, cycles: 2);
        await store.deletePayment(original: created, rollbackRenewal: true);
        final restored = await only();
        expect(restored.dueDate, before.dueDate);
        expect((await store.servicePeriods()).length, 1);
        expect((await stored('payment')).voided, isTrue);
        expect(
          recentPayments(await store.payments(), LedgerDate.today(now)),
          isEmpty,
        );
      },
    );

    test('delete with rollback is refused once the server moved on', () async {
      await store.saveServer(fixture(), isNew: true);
      final first = await pay(await only(), id: 'first');
      await pay(await only(), id: 'second');
      final serverBefore = (await only()).toMap();
      await expectLater(
        store.deletePayment(original: first, rollbackRenewal: true),
        throwsA(isA<LedgerConflict>()),
      );
      expect((await only()).toMap(), serverBefore);
      expect((await stored('first')).voided, isFalse);
      expect((await store.servicePeriods()).length, 3);
    });

    test('delete keeping the term voids only the record: periods and due stay, totals drop it', () async {
      await store.saveServer(fixture(), isNew: true);
      final first = await pay(await only(), id: 'first', minor: 700);
      await pay(await only(), id: 'second', minor: 300);
      final serverBefore = (await only()).toMap();
      final periodsBefore = (await store.servicePeriods())
          .map((p) => p.toMap())
          .toList();
      await store.deletePayment(original: first);
      expect((await only()).toMap(), serverBefore);
      expect(
        (await store.servicePeriods()).map((p) => p.toMap()).toList(),
        periodsBefore,
      );
      final deleted = await stored('first');
      expect(deleted.voided, isTrue);
      final totals = aggregateAmounts(
        recentPayments(
          await store.payments(),
          LedgerDate.today(now),
        ).map((p) => FinanceAmount.money(p.amount)),
        const FxSettings(displayCurrency: 'EUR'),
      );
      expect(totals.convertedMinor, Rational.of(300));
      // Repeating the delete is a no-op.
      await store.deletePayment(original: first);
      await store.deletePayment(original: deleted);
      expect((await only()).toMap(), serverBefore);
    });

    test(
      'a deleted payment can be neither edited, undone nor re-recorded',
      () async {
        await store.saveServer(fixture(), isNew: true);
        final server = await only();
        final created = await pay(server);
        await store.deletePayment(original: created);
        final deleted = await stored('payment');
        final serverAfter = (await only()).toMap();
        await expectLater(
          store.editPayment(
            original: deleted,
            amount: const Money('EUR', 1),
            paidDate: deleted.paidDate,
          ),
          throwsArgumentError,
        );
        // An old undo token (the id) does nothing and cannot revert the term.
        await store.undoPayment('payment');
        expect((await only()).toMap(), serverAfter);
        expect((await store.servicePeriods()).length, 2);
        // The idempotency key stays used after a reopen.
        await reopen();
        await expectLater(pay(server), throwsArgumentError);
        expect((await store.payments()).single.voided, isTrue);
      },
    );

    test('SQLite abort during delete+rollback restores everything', () async {
      await store.saveServer(fixture(), isNew: true);
      final created = await pay(await only(), cycles: 2);
      final serverBefore = (await only()).toMap();
      final periodsBefore = (await store.servicePeriods())
          .map((p) => p.toMap())
          .toList();
      final db = await raw();
      await db.execute(
        "CREATE TRIGGER abort_void BEFORE UPDATE OF voided_at ON payments BEGIN SELECT RAISE(ABORT, 'test delete rollback'); END",
      );
      await expectLater(
        store.deletePayment(original: created, rollbackRenewal: true),
        throwsA(isA<DatabaseException>()),
      );
      expect((await only()).toMap(), serverBefore);
      expect(
        (await store.servicePeriods()).map((p) => p.toMap()).toList(),
        periodsBefore,
      );
      expect((await stored('payment')).toMap(), created.toMap());
      await db.execute('DROP TRIGGER abort_void');
      await db.close();
    });

    test('account bill delete drops it from totals', () async {
      final bill = await store.recordAccountPayment(
        id: 'account',
        accountLabel: 'Provider',
        amount: const Money('CNY', 10),
        paidDate: LedgerDate.today(now),
      );
      await store.deletePayment(original: bill);
      expect((await stored('account')).voided, isTrue);
      expect(
        recentPayments(await store.payments(), LedgerDate.today(now)),
        isEmpty,
      );
    });
  });
  group('term-based rollback and orphan repair', () {
    Future<PaymentRecord> stored(String id) async =>
        (await store.payments()).singleWhere((p) => p.id == id);
    Future<List<ServicePeriod>> periodsOf(String serverId) async =>
        (await store.servicePeriods())
            .where((p) => p.serverId == serverId)
            .toList();
    Future<PaymentRecord> renew(String id, {int cycles = 1}) async =>
        pay(await only(), id: id, cycles: cycles);
    Future<void> unrelatedEdits() async {
      await store.setFavorite(await only(), true);
      await store.saveServer(
        edit(await only(), {
          'name': 'Renamed',
          'notes': 'note',
          'os': 'Debian',
        }),
        isNew: false,
      );
    }

    test('tail renewal rolls back despite unrelated edits; booking again offers the restored due', () async {
      await store.saveServer(fixture(), isNew: true);
      final before = await only();
      final payment = await renew('p1');
      await unrelatedEdits();
      final shown = await only();
      expect(shown.revision, greaterThan(payment.appliedServerRevision!));
      expect(
        canRollbackPayment(shown, await store.servicePeriods(), payment),
        isTrue,
      );
      await store.deletePayment(
        original: payment,
        rollbackRenewal: true,
        expectedServerRevision: shown.revision,
      );
      final restored = await only();
      expect(restored.dueDate, before.dueDate);
      expect(restored.revision, shown.revision + 1);
      expect(restored.name, 'Renamed');
      expect(restored.favorite, isTrue);
      expect(restored.renewalAnchorDate, before.dueDate);
      expect((await periodsOf('s')).length, 1);
      expect((await stored('p1')).voided, isTrue);
      expect(renewalDate(restored, 1), d('2028-01-01'));
      final again = await pay(restored, id: 'p2');
      expect(again.from, d('2027-01-01'));
      expect(again.until, d('2028-01-01'));
      expect((await only()).dueDate, d('2028-01-01'));
    });

    test(
      'a stale expected revision is a conflict and changes nothing',
      () async {
        await store.saveServer(fixture(), isNew: true);
        final payment = await renew('p1');
        final shown = await only();
        await store.setFavorite(shown, true); // happens after the UI looked
        final dbBefore = (await only()).toMap();
        await expectLater(
          store.deletePayment(
            original: payment,
            rollbackRenewal: true,
            expectedServerRevision: shown.revision,
          ),
          throwsA(isA<LedgerConflict>()),
        );
        expect((await only()).toMap(), dbBefore);
        expect((await stored('p1')).voided, isFalse);
        expect((await periodsOf('s')).length, 2);
      },
    );

    test('a non-tail renewal, an archived server and a changed cycle refuse the rollback', () async {
      await store.saveServer(fixture(), isNew: true);
      final first = await renew('first');
      final second = await renew('second');
      await unrelatedEdits();
      var c = await only();
      expect(
        canRollbackPayment(c, await store.servicePeriods(), first),
        isFalse,
      );
      expect(
        canRollbackPayment(c, await store.servicePeriods(), second),
        isTrue,
      );
      await expectLater(
        store.deletePayment(original: first, rollbackRenewal: true),
        throwsA(isA<LedgerConflict>()),
      );
      // Cycle edited behind the term's back (legacy / tampered data).
      final db = await raw();
      await db.update('servers', {'cycle_months': 6});
      c = await only();
      expect(
        canRollbackPayment(c, await store.servicePeriods(), second),
        isFalse,
      );
      await expectLater(
        store.deletePayment(original: second, rollbackRenewal: true),
        throwsA(isA<LedgerConflict>()),
      );
      await expectLater(
        store.undoPayment('second'),
        throwsA(isA<LedgerConflict>()),
      );
      expect((await only()).toMap(), c.toMap());
      expect((await stored('second')).voided, isFalse);
      expect((await periodsOf('s')).length, 3);
      // Restore the cycle, then archive: still refused.
      await db.update('servers', {'cycle_months': 12});
      await store.archive(await only());
      await expectLater(
        store.deletePayment(original: second, rollbackRenewal: true),
        throwsA(isA<LedgerConflict>()),
      );
      expect((await stored('second')).voided, isFalse);
    });

    test('a period ending after the payment refuses the rollback', () async {
      await store.saveServer(fixture(), isNew: true);
      final payment = await renew('p1');
      final db = await raw();
      // A period beyond the payment (e.g. restored from a foreign backup).
      await db.insert('service_periods', {
        'id': 'extra',
        'server_id': 's',
        'start_date': '2028-01-01',
        'end_date': '2029-01-01',
        'inferred': 0,
        'payment_id': null,
      });
      final server = await only();
      expect(
        canRollbackPayment(server, await store.servicePeriods(), payment),
        isFalse,
      );
      await expectLater(
        store.deletePayment(original: payment, rollbackRenewal: true),
        throwsA(isA<LedgerConflict>()),
      );
      await db.close();
    });

    test('anchor: rolling back the first renewal keeps a usable anchor; month-end cycles re-book exactly', () async {
      await store.saveServer(
        fixture(cycle: 1, start: '2023-12-31', due: '2024-01-31'),
        isNew: true,
      );
      final first = await renew('first');
      expect((await only()).dueDate, d('2024-02-29'));
      await store.deletePayment(original: first, rollbackRenewal: true);
      var server = await only();
      expect(server.dueDate, d('2024-01-31'));
      expect(server.renewalAnchorDate, d('2024-01-31'));
      // With no payment period left the terms are editable again.
      expect(
        (await store.servicePeriods()).where((p) => p.paymentId != null),
        isEmpty,
      );
      await renew('again');
      await renew('third');
      await renew('fourth');
      expect((await only()).dueDate, d('2024-04-30'));
      await store.undoPayment('fourth');
      server = await only();
      expect(server.dueDate, d('2024-03-31'));
      expect(renewalDate(server, 1), d('2024-04-30'));
    });

    test('keep-only delete leaves an orphan tail that can be repaired, group by group', () async {
      await store.saveServer(fixture(), isNew: true);
      final first = await renew('first');
      final second = await renew('second', cycles: 2);
      await store.deletePayment(original: second); // legacy: keep periods
      await store.deletePayment(original: first);
      await unrelatedEdits();
      var server = await only();
      var c = LedgerController(store, clock: () => now);
      await c.refresh();
      var orphan = c.orphanTermFor(server)!;
      expect(orphan.start, d('2028-01-01'));
      expect(orphan.end, d('2030-01-01'));
      expect(orphan.paymentId, 'second');
      // Stale revision → conflict, nothing changes.
      await expectLater(
        store.rollbackOrphanTerm(
          serverId: 's',
          expectedRevision: server.revision - 1,
        ),
        throwsA(isA<LedgerConflict>()),
      );
      expect((await only()).toMap(), server.toMap());
      expect(
        await store.rollbackOrphanTerm(
          serverId: 's',
          expectedRevision: server.revision,
        ),
        d('2028-01-01'),
      );
      server = await only();
      expect(server.dueDate, d('2028-01-01'));
      expect(server.revision, greaterThan(0));
      expect((await periodsOf('s')).map((p) => p.paymentId), [null, 'first']);
      await c.refresh();
      orphan = c.orphanTermFor(server)!;
      expect(orphan.paymentId, 'first');
      expect(
        await store.rollbackOrphanTerm(
          serverId: 's',
          expectedRevision: server.revision,
        ),
        d('2027-01-01'),
      );
      server = await only();
      expect(server.dueDate, d('2027-01-01'));
      expect((await periodsOf('s')).single.paymentId, isNull);
      await c.refresh();
      expect(c.orphanTermFor(server), isNull);
      // Only the initial period is left: nothing more to repair.
      await expectLater(
        store.rollbackOrphanTerm(
          serverId: 's',
          expectedRevision: server.revision,
        ),
        throwsA(isA<LedgerConflict>()),
      );
      final booked = await pay(server, id: 'new');
      expect(booked.until, d('2028-01-01'));
      c.dispose();
    });

    test(
      'repair never touches live payments, inferred periods or other servers',
      () async {
        await store.saveServer(fixture(), isNew: true);
        await store.saveServer(fixture(id: 'o', start: null), isNew: true);
        final live = await pay(
          (await store.servers()).firstWhere((s) => s.id == 's'),
        );
        await expectLater(
          store.rollbackOrphanTerm(
            serverId: 's',
            expectedRevision: (await only2('s')).revision,
          ),
          throwsA(isA<LedgerConflict>()),
        );
        await expectLater(
          store.rollbackOrphanTerm(
            serverId: 'o',
            expectedRevision: (await only2('o')).revision,
          ),
          throwsA(isA<LedgerConflict>()),
        );
        await expectLater(
          store.rollbackOrphanTerm(serverId: 'missing', expectedRevision: 0),
          throwsA(isA<LedgerConflict>()),
        );
        expect((await stored(live.id)).voided, isFalse);
        expect((await periodsOf('s')).length, 2);
        expect((await periodsOf('o')).single.inferred, isTrue);
      },
    );

    test('a failed repair rolls everything back', () async {
      await store.saveServer(fixture(), isNew: true);
      final payment = await renew('p1');
      await store.deletePayment(original: payment);
      final server = await only();
      final periods = (await periodsOf('s')).map((p) => p.toMap()).toList();
      final db = await raw();
      await db.execute(
        "CREATE TRIGGER abort_repair BEFORE DELETE ON service_periods BEGIN SELECT RAISE(ABORT, 'test repair'); END",
      );
      await expectLater(
        store.rollbackOrphanTerm(
          serverId: 's',
          expectedRevision: server.revision,
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect((await only()).toMap(), server.toMap());
      expect((await periodsOf('s')).map((p) => p.toMap()).toList(), periods);
      await db.execute('DROP TRIGGER abort_repair');
      await db.close();
    });

    test(
      'a failed rollback delete is atomic too (server update undone)',
      () async {
        await store.saveServer(fixture(), isNew: true);
        final payment = await renew('p1');
        await unrelatedEdits();
        final server = await only();
        final db = await raw();
        await db.execute(
          "CREATE TRIGGER abort_rb BEFORE DELETE ON service_periods BEGIN SELECT RAISE(ABORT, 'test rollback'); END",
        );
        await expectLater(
          store.deletePayment(
            original: payment,
            rollbackRenewal: true,
            expectedServerRevision: server.revision,
          ),
          throwsA(isA<DatabaseException>()),
        );
        expect((await only()).toMap(), server.toMap());
        expect((await stored('p1')).voided, isFalse);
        await db.close();
      },
    );

    test(
      'undo tokens stay no-ops after repair; voided payments are never revived',
      () async {
        await store.saveServer(fixture(), isNew: true);
        final payment = await renew('p1');
        await store.deletePayment(original: payment);
        final server = await only();
        await store.rollbackOrphanTerm(
          serverId: 's',
          expectedRevision: server.revision,
        );
        final repaired = (await only()).toMap();
        await store.undoPayment('p1');
        await store.deletePayment(
          original: await stored('p1'),
          rollbackRenewal: true,
        );
        expect((await only()).toMap(), repaired);
        await expectLater(pay(await only(), id: 'p1'), throwsArgumentError);
        expect((await stored('p1')).voided, isTrue);
      },
    );
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
