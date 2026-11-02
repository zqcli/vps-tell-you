import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/finance/finance_detail_pages.dart';
import 'package:vps_tell_you/finance/finance_models.dart';
import 'package:vps_tell_you/finance/finance_widgets.dart';
import 'package:vps_tell_you/finance/payment_pages.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_management_pages.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'support/reminder_platform.dart';

class _PageLedger extends LedgerController {
  _PageLedger(super.store, {required super.clock, super.reminderPlatform});
  void changed() => notifyListeners();
}

/// Counts reads of source payments, independently of the page's projection.
class _CountingList<T> extends ListBase<T> {
  _CountingList(this.values);
  final List<T> values;
  int reads = 0;
  @override
  int get length => values.length;
  @override
  set length(int value) => throw UnsupportedError('Read-only fixture');
  @override
  T operator [](int index) {
    reads++;
    return values[index];
  }
  @override
  void operator []=(int index, T value) =>
      throw UnsupportedError('Read-only fixture');
}

void main() {
  late Directory directory;
  late LedgerStore store;
  late _PageLedger ledger;
  late DateTime now;
  late ValueNotifier<Locale> locale;
  const size = 120;

  ServerRecord server(int i, {bool archived = false, String? group = 'g'}) =>
      ServerRecord(
        id: archived ? 'a$i' : 's$i',
        name: '${archived ? 'Archived' : 'Server'} $i',
        vendor: 'Fixture',
        groupId: group,
        billing: BillingKind.prepaid,
        currency: 'USD',
        amountMinor: 1200,
        cycleMonths: 12,
        startDate: const LedgerDate(2026, 1, 1),
        dueDate: const LedgerDate(2026, 10, 8),
        archivedAt: archived ? now : null,
        createdAt: now,
        updatedAt: now,
      );

  PaymentRecord payment(int i, {int age = 0, bool voided = false}) =>
      PaymentRecord(
        id: 'p$i',
        serverId: 's$i',
        targetName: 'Payment $i',
        amount: Money('USD', 100 * (i + 1)),
        paidDate: LedgerDate.today(now).addDays(-age),
        createdAt: now,
        voidedAt: voided ? now : null,
      );

  setUp(() async {
    sqfliteFfiInit();
    now = DateTime(2026, 10, 7, 12);
    directory = await Directory.systemTemp.createTemp('finance-list-scale-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.db',
      clock: () => now,
    );
    ledger = _PageLedger(
      store,
      clock: () => now,
      reminderPlatform: FakeReminderPlatform()..supported = false,
    );
    ledger.records = [
      for (var i = 0; i < size; i++) server(i),
      for (var i = 0; i < size; i++) server(i, archived: true),
    ];
    ledger.groups = [const ServerGroup(id: 'g', name: 'Group', position: 0)];
    ledger.payments = [for (var i = 0; i < size; i++) payment(i, age: i)];
    ledger.fx = const FxSettings(displayCurrency: 'USD');
    locale = ValueNotifier(const Locale('en'));
  });
  tearDown(() async {
    locale.dispose();
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester, Widget page, {double height = 844}) async {
    tester.view.physicalSize = Size(390, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ValueListenableBuilder<Locale>(
      valueListenable: locale,
      builder: (_, value, _) => MaterialApp(
        theme: appTheme(),
        locale: value,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    ));
    await tester.pumpAndSettle();
  }

  final pages = <String, (Widget Function(), String)>{
    'payments': (() => PaymentListPage(controller: ledger), 'payment-p119'),
    'finance details': (
      () => FinanceDetailPage(controller: ledger, metric: FinanceMetric.monthly),
      'finance-detail-s119',
    ),
    'renewals': (() => RenewalsPage(controller: ledger), 'renewal-s99-2026-10-08'),
    'archive': (() => ArchivePage(controller: ledger), 'archive-a119'),
  };
  for (final entry in pages.entries) {
    testWidgets('${entry.key}: long lists build a screenful and reach the last row', (tester) async {
      await mount(tester, entry.value.$1());
      final last = find.byKey(ValueKey(entry.value.$2));
      expect(last, findsNothing);
      expect(find.byType(AppGroupedRow).evaluate().length, lessThan(40));
      await tester.scrollUntilVisible(
        last,
        700,
        scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical).first,
        maxScrolls: 100,
      );
      await tester.pumpAndSettle();
      expect(last, findsOneWidget);
      expect(find.byType(AppGroupedRow).evaluate().length, lessThan(40));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('payment projection survives locale and invalidates for day, FX, records and payments', (tester) async {
    final source = _CountingList([
      payment(0),
      payment(1, age: 6),
      payment(2, age: 9),
      payment(3, voided: true),
    ]);
    ledger.payments = source;
    await mount(tester, PaymentListPage(controller: ledger, groupId: 'g', period: PaymentPeriod.week), height: 1600);
    FinanceTotal total() => tester.widget<FinanceTotalView>(find.byType(FinanceTotalView)).total;
    expect(total().convertedMinor, Rational.of(300));
    final initial = total();
    final reads = source.reads;
    locale.value = const Locale('zh');
    await tester.pumpAndSettle();
    expect(total(), same(initial));
    expect(source.reads, reads, reason: 'Translating the page must not rescan payments.');

    now = now.add(const Duration(days: 1));
    ledger.changed();
    await tester.pumpAndSettle();
    expect(total().convertedMinor, Rational.of(100));
    expect(source.reads, greaterThan(reads));
    ledger.fx = const FxSettings(usdToCny: '7', rateDate: LedgerDate(2026, 10, 8));
    ledger.changed();
    await tester.pumpAndSettle();
    expect(total().convertedMinor, Rational.of(700));

    ledger.records = [server(0, group: null), server(1), server(2), server(3)];
    ledger.changed();
    await tester.pumpAndSettle();
    expect(find.byType(FinanceTotalView), findsNothing);
    ledger.payments = [
      for (final p in source.values) if (p.id != 'p1') p,
      payment(1),
    ];
    ledger.changed();
    await tester.pumpAndSettle();
    expect(total().convertedMinor, Rational.of(1400));
    expect(tester.takeException(), isNull);
  });
}
