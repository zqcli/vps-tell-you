import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/finance/finance_math.dart';
import 'package:vps_tell_you/finance/finance_models.dart';
import 'package:vps_tell_you/finance/finance_snapshot.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'support/reminder_platform.dart';

void main() {
  final now = DateTime(2026, 10, 7, 12);
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('finance-snapshot-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.db',
      clock: () => now,
    );
    ledger = LedgerController(
      store,
      clock: () => now,
      reminderPlatform: FakeReminderPlatform()..supported = false,
    );
    ledger.records = [
      for (var i = 0; i < 300; i++)
        ServerRecord(
          id: 's$i',
          name: 'Server $i',
          vendor: 'v${i % 7}',
          groupId: i.isEven ? 'g' : null,
          billing: BillingKind.prepaid,
          currency: i.isEven ? 'CNY' : 'USD',
          amountMinor: 1200 + i,
          cycleMonths: 12,
          startDate: const LedgerDate(2026, 1, 1),
          dueDate: const LedgerDate(2026, 10, 8).addDays(i % 365),
          createdAt: now,
          updatedAt: now,
        ),
    ];
    ledger.periods = [
      for (var i = 0; i < 300; i++)
        ServicePeriod(
          id: 'p$i',
          serverId: 's$i',
          start: const LedgerDate(2026, 1, 1),
          end: const LedgerDate(2027, 1, 1).addDays(i),
        ),
    ];
  });

  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  test('figures match the direct per-server computation', () {
    final scope = FinanceScope.of(ledger, 'g');
    expect(scope.records.length, 150);
    final direct = aggregateAmounts(
      scope.records.map(
        (s) =>
            serverValuation(s, ledger.periodsFor(s.id), ledger.today)!.amount,
      ),
      ledger.fx,
    );
    expect(scope.value.convertedMinor, direct.convertedMinor);
    expect(scope.value.covered, direct.covered);
    expect(
      scope.slices(byVendor: true).fold<int>(0, (n, s) => n + s.servers.length),
      scope.records.length,
    );
  });

  test('unrelated notifications reuse the cache; new ledger data does not', () {
    final first = FinanceScope.of(ledger, null);
    ledger.updateFilters(query: 'abc');
    expect(FinanceScope.of(ledger, null), same(first));
    expect(FinanceScope.of(ledger, 'g'), isNot(same(first)));
    ledger.payments = [...ledger.payments];
    expect(FinanceScope.of(ledger, null), isNot(same(first)));
  });
}
