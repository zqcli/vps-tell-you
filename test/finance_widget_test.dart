import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';
import 'package:vps_tell_you/finance/calculation_share.dart';
import 'package:vps_tell_you/finance/calculation_result_page.dart';
import 'package:vps_tell_you/finance/calculator_page.dart';
import 'package:vps_tell_you/finance/finance_detail_pages.dart';
import 'package:vps_tell_you/finance/finance_page.dart';
import 'package:vps_tell_you/finance/finance_widgets.dart';
import 'package:vps_tell_you/finance/finance_math.dart';
import 'package:vps_tell_you/finance/finance_models.dart';
import 'package:vps_tell_you/finance/fx_page.dart';
import 'package:vps_tell_you/finance/payment_detail_page.dart';
import 'package:vps_tell_you/finance/payment_pages.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_detail.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'support/form_test_helpers.dart' show pickDate;
import 'support/reminder_platform.dart';

const today = LedgerDate(2026, 9, 23);
CalculationShareData shareFixture({String amount = r'$9999999999.99'}) =>
    CalculationShareData(
      amount: amount,
      currency: 'USD',
      converted: '当前汇率缺失 · 未提供参考折算',
      asOf: today,
      start: const LedgerDate(2026, 1, 1),
      end: const LedgerDate(2027, 1, 1),
      due: const LedgerDate(2029, 1, 1),
      ratio: 100 / 365,
      activeRemaining: 100,
      days: 365,
      remaining: 830,
      renewal: r'$9999999999.99 USD / 12 个月',
      daily: '27397260.2739 USD',
      futurePeriods: 2,
      fx: '参考汇率缺失',
      fxSource: '手动汇率 · 未设置日期 · 非实时报价',
      periodBasis: '引用时复制的已知服务期；部分起点为推算，未回写台账。',
    );

void main() {
  late Directory directory;
  late LedgerStore store;
  late LedgerController controller;
  late ServerRecord server;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('vps-finance-widget-');
    DateTime clock() => DateTime(2026, 9, 23, 12);
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.db',
      clock: clock,
    );
    controller = LedgerController(
      store,
      clock: clock,
      reminderPlatform: FakeReminderPlatform()..supported = false,
    );
    await store.saveGroup('Production');
    server = ServerRecord(
      id: 'private-machine-id',
      name: 'PRIVATE_MACHINE_NAME',
      vendor: 'Vendor One',
      host: '192.0.2.9',
      notes: 'PRIVATE_NOTE',
      createdAt: clock(),
      updatedAt: clock(),
      billing: BillingKind.prepaid,
      amountMinor: 3650,
      startDate: const LedgerDate(2026, 1, 1),
      dueDate: const LedgerDate(2027, 1, 1),
      groupId: (await store.groups()).single.id,
    );
    await store.saveServer(server, isNew: true);
    await controller.refresh();
    server = controller.records.single;
  });
  tearDown(() async {
    controller.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 40,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String key, String value) async {
    final target = find.byKey(ValueKey(key));
    await reveal(tester, target);
    await tester.enterText(target, value);
    await tester.pump();
  }

  Widget opener(Widget child) => Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => child),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );

  testWidgets(
    'payment requires confirmed nonfuture date, cancel is inert and repeated save commits once',
    (tester) async {
      await mount(
        tester,
        opener(PaymentForm(controller: controller, server: server)),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await fill(tester, 'pay-date', '2026-09-24');
      await reveal(tester, find.byKey(const ValueKey('save-payment')));
      await tester.tap(find.byKey(const ValueKey('save-payment')));
      await tester.pumpAndSettle();
      expect(controller.payments, isEmpty);
      await reveal(tester, find.byKey(const ValueKey('pay-date')));
      expect(find.text('付款日期不能晚于今天'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(controller.payments, isEmpty);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('save-payment')));
      await tester.tap(find.byKey(const ValueKey('save-payment')));
      await tester.pumpAndSettle();
      expect(find.text('请确认已完成厂商付款并核对资料'), findsOneWidget);
      expect(controller.payments, isEmpty);
      await tester.tap(find.byKey(const ValueKey('pay-confirm')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('save-payment')));
      await tester.tap(find.byKey(const ValueKey('save-payment')));
      await tester.pumpAndSettle();
      expect(controller.payments.length, 1);
      expect(controller.periodsFor(server.id).length, 2);
      expect(controller.byId(server.id)!.dueDate, const LedgerDate(2028, 1, 1));
      expect(controller.byId(server.id)!.amountMinor, 3650);
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  group('edit and delete from the payment detail page', () {
    Future<PaymentRecord> record({int cycles = 1, String id = 'p1'}) async {
      final current = controller.byId(server.id)!;
      final payment = await store.recordPayment(
        id: id,
        server: current,
        amount: const Money('USD', 3650),
        paidDate: today,
        cycleCount: cycles,
        until: renewalDate(current, cycles),
        confirmed: true,
        note: 'first',
      );
      await controller.refresh();
      return payment;
    }

    testWidgets(
      'edit still works after the server was edited and keeps terms',
      (tester) async {
        final payment = await record();
        await store.setFavorite(controller.byId(server.id)!, true);
        await controller.refresh();
        // An unrelated edit bumps the revision but not the term.
        expect(controller.canUndoPayment(payment), isTrue);
        final dueBefore = controller.byId(server.id)!.dueDate;
        final periodsBefore = controller.periodsFor(server.id).length;
        await mount(
          tester,
          PaymentDetailPage(controller: controller, id: payment.id),
        );
        await tester.tap(find.byKey(const ValueKey('payment-edit')));
        await tester.pumpAndSettle();
        await fill(tester, 'edit-amount', '12.50');
        await fill(tester, 'edit-note', 'corrected');
        await tester.tap(find.text('EUR'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        final saved = controller.payments.single;
        expect(saved.amount.minor, 1250);
        expect(saved.amount.currency, 'EUR');
        expect(saved.note, 'corrected');
        expect(controller.byId(server.id)!.dueDate, dueBefore);
        expect(controller.periodsFor(server.id).length, periodsBefore);
        expect(find.text('付款记录已更新'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('invalid edit shows the error and writes nothing', (
      tester,
    ) async {
      final payment = await record();
      await mount(
        tester,
        PaymentDetailPage(controller: controller, id: payment.id),
      );
      await tester.tap(find.byKey(const ValueKey('payment-edit')));
      await tester.pumpAndSettle();
      await fill(tester, 'edit-amount', 'abc');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('请输入有效实付金额，0 表示免费'), findsOneWidget);
      expect(controller.payments.single.amount.minor, 3650);
    });

    testWidgets(
      'latest renewal offers rollback; rolling back restores the term',
      (tester) async {
        final before = controller.byId(server.id)!;
        final payment = await record(cycles: 2);
        await mount(
          tester,
          PaymentDetailPage(controller: controller, id: payment.id),
        );
        await tester.tap(find.byKey(const ValueKey('payment-delete')));
        await tester.pumpAndSettle();
        expect(find.text('删除并回退到期日（→ 2027-01-01）'), findsOneWidget);
        expect(find.text('仅删除记录，保留服务期'), findsOneWidget);
        expect(find.textContaining('到期日仍为 2029-01-01'), findsOneWidget);
        await tester.tap(find.text('删除并回退到期日（→ 2027-01-01）'));
        await tester.pumpAndSettle();
        expect(controller.payments.single.voided, isTrue);
        expect(controller.byId(server.id)!.dueDate, before.dueDate);
        expect(controller.periodsFor(server.id).length, 1);
      },
    );

    testWidgets('delete-only keeps periods and due date', (tester) async {
      final payment = await record();
      final due = controller.byId(server.id)!.dueDate;
      await mount(
        tester,
        PaymentDetailPage(controller: controller, id: payment.id),
      );
      await tester.tap(find.byKey(const ValueKey('payment-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('仅删除记录，保留服务期'));
      await tester.pumpAndSettle();
      expect(controller.payments.single.voided, isTrue);
      expect(controller.byId(server.id)!.dueDate, due);
      expect(controller.periodsFor(server.id).length, 2);
    });

    testWidgets(
      'a renewal that is not the tail only deletes its record and names the later renewals',
      (tester) async {
        final payment = await record();
        await record(id: 'p2');
        await mount(
          tester,
          PaymentDetailPage(controller: controller, id: payment.id),
        );
        await tester.tap(find.byKey(const ValueKey('payment-delete')));
        await tester.pumpAndSettle();
        expect(find.textContaining('删除并回退到期日'), findsNothing);
        expect(find.textContaining('之后还有续费记录（2029-01-01）'), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(controller.payments.every((p) => !p.voided), isTrue);
        await tester.tap(find.byKey(const ValueKey('payment-delete')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除记录').last);
        await tester.pumpAndSettle();
        expect(controller.payments.where((p) => p.voided).single.id, 'p1');
        expect(controller.periodsFor(server.id).length, 3);
        expect(
          controller.byId(server.id)!.dueDate,
          const LedgerDate(2029, 1, 1),
        );
      },
    );

    Future<void> book(WidgetTester tester) async {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('pay-confirm')));
      await tester.tap(find.byKey(const ValueKey('pay-confirm')));
      await tester.pump();
      await reveal(tester, find.byKey(const ValueKey('save-payment')));
      await tester.tap(find.byKey(const ValueKey('save-payment')));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'bug: delete after an unrelated edit rolls the due date back and the next payment starts there',
      (tester) async {
        await mount(
          tester,
          opener(PaymentForm(controller: controller, server: server)),
        );
        await book(tester);
        final payment = controller.payments.single;
        expect(
          controller.byId(server.id)!.dueDate,
          const LedgerDate(2028, 1, 1),
        );
        await store.setFavorite(controller.byId(server.id)!, true);
        await controller.refresh();

        await tester.pumpWidget(const SizedBox());
        await mount(
          tester,
          PaymentDetailPage(controller: controller, id: payment.id),
        );
        await tester.tap(find.byKey(const ValueKey('payment-delete')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('payment-delete-rollback')));
        await tester.pumpAndSettle();
        final back = controller.byId(server.id)!;
        expect(back.dueDate, const LedgerDate(2027, 1, 1));
        expect(back.favorite, isTrue);
        expect(controller.periodsFor(server.id).length, 1);
        expect(controller.payments.single.voided, isTrue);
        expect(controller.orphanTermFor(back), isNull);

        await tester.pumpWidget(const SizedBox());
        await mount(
          tester,
          opener(PaymentForm(controller: controller, server: back)),
        );
        await book(tester);
        final again = controller.payments.firstWhere((p) => !p.voided);
        expect(again.from, const LedgerDate(2027, 1, 1));
        expect(again.until, const LedgerDate(2028, 1, 1));
        expect(
          controller.byId(server.id)!.dueDate,
          const LedgerDate(2028, 1, 1),
        );
      },
    );

    testWidgets(
      'legacy: keep-only delete leaves a banner on the list and the detail page; repairing restores the due date',
      (tester) async {
        final payment = await record();
        await store.setFavorite(controller.byId(server.id)!, true);
        await controller.refresh();
        // The old behaviour: record removed, term kept.
        await store.deletePayment(original: payment);
        await controller.refresh();
        const banner = '2027-01-01 → 2028-01-01 的付款已删除。回退到期日到 2027-01-01？';

        await mount(
          tester,
          ServerDetail(controller: controller, id: server.id),
        );
        await reveal(tester, find.byKey(const ValueKey('orphan-term-banner')));
        expect(find.text(banner), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await mount(
          tester,
          PaymentListPage(controller: controller, serverId: server.id),
        );
        expect(find.text(banner), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('orphan-term-banner')));
        await tester.pumpAndSettle();
        expect(find.text('回退到期日？'), findsOneWidget);
        await tester.tap(find.text('回退').last);
        await tester.pumpAndSettle();
        expect(find.text(banner), findsNothing);
        expect(
          controller.byId(server.id)!.dueDate,
          const LedgerDate(2027, 1, 1),
        );
        expect(controller.periodsFor(server.id).length, 1);
        expect(find.text('到期日已回退到 2027-01-01'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await mount(
          tester,
          opener(
            PaymentForm(
              controller: controller,
              server: controller.byId(server.id)!,
            ),
          ),
        );
        await book(tester);
        expect(
          controller.byId(server.id)!.dueDate,
          const LedgerDate(2028, 1, 1),
        );
        expect(controller.payments.where((p) => !p.voided).length, 1);
      },
    );
  });

  group('payment period filter', () {
    Future<void> seedAges() async {
      for (final age in [3, 20, 60, 200, 400]) {
        await store.recordAccountPayment(
          id: 'age$age',
          accountLabel: 'Bill $age',
          amount: Money('CNY', age * 100),
          paidDate: today.addDays(-age),
        );
      }
      await controller.refresh();
    }

    Finder row(int age) => find.byKey(ValueKey('payment-age$age'));
    String total(WidgetTester tester) => tester
        .widget<FinanceTotalView>(find.byType(FinanceTotalView))
        .total
        .formatted;

    testWidgets('opens on the period it came from and switches windows', (
      tester,
    ) async {
      await seedAges();
      await mount(
        tester,
        PaymentListPage(controller: controller, period: PaymentPeriod.month),
      );
      expect(row(3), findsOneWidget);
      expect(row(20), findsOneWidget);
      expect(row(60), findsNothing);
      expect(total(tester), '¥23.00');
      for (final step in [
        (PaymentPeriod.week, [3], '¥3.00'),
        (PaymentPeriod.quarter, [3, 20, 60], '¥83.00'),
        (PaymentPeriod.halfYear, [3, 20, 60], '¥83.00'),
        (PaymentPeriod.year, [3, 20, 60, 200], '¥283.00'),
        (PaymentPeriod.all, [3, 20, 60, 200, 400], '¥683.00'),
      ]) {
        final chip = find.byKey(ValueKey('payment-period-${step.$1.name}'));
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
        for (final age in [3, 20, 60, 200, 400]) {
          expect(
            row(age),
            step.$2.contains(age) ? findsOneWidget : findsNothing,
            reason: '${step.$1.name} age $age',
          );
        }
        expect(total(tester), step.$3, reason: step.$1.name);
      }
    });

    testWidgets('default is everything; the deleted filter still applies', (
      tester,
    ) async {
      await seedAges();
      await store.deletePayment(
        original: controller.payments.firstWhere((p) => p.id == 'age3'),
      );
      await controller.refresh();
      await mount(tester, PaymentListPage(controller: controller));
      expect(row(400), findsOneWidget);
      expect(row(3), findsNothing);
      expect(total(tester), '¥680.00');
      await tester.tap(find.byKey(const ValueKey('payment-voided')));
      await tester.pumpAndSettle();
      expect(row(3), findsOneWidget);
      // Deleted records are listed but never counted.
      expect(total(tester), '¥680.00');
      await tester.tap(find.byKey(const ValueKey('payment-period-week')));
      await tester.pumpAndSettle();
      expect(row(3), findsOneWidget);
      expect(row(20), findsNothing);
    });
  });

  group('costs page', () {
    testWidgets('payments entry is named 付款记录 and opens the 30-day window', (
      tester,
    ) async {
      await store.recordAccountPayment(
        id: 'recent',
        accountLabel: 'Bill',
        amount: const Money('CNY', 500),
        paidDate: today.addDays(-2),
      );
      await controller.refresh();
      await mount(tester, FinancePage(controller: controller));
      final entry = find.byKey(const ValueKey('finance-recent-payments'));
      await reveal(tester, entry);
      expect(
        find.descendant(of: entry, matching: find.text('付款记录')),
        findsOneWidget,
      );
      expect(find.text('近 30 天已记录实付'), findsNothing);
      expect(
        find.descendant(of: entry, matching: find.text('近 30 天 · 1 笔')),
        findsOneWidget,
      );
      await tester.tap(entry);
      await tester.pumpAndSettle();
      final selected = tester.widget<AppChip>(
        find.byKey(const ValueKey('payment-period-month')),
      );
      expect(selected.selected, isTrue);
    });

    testWidgets(
      'forecast pill is flush right and bar captions carry the symbol',
      (tester) async {
        await controller.refresh();
        await mount(tester, FinancePage(controller: controller));
        final chart = find.byKey(const ValueKey('forecast-open'));
        await reveal(tester, chart);
        final pill = find
            .byType(StatusPill)
            .evaluate()
            .map((e) => e.widget)
            .length;
        expect(pill, greaterThan(0));
        final forecastPill = find.text('按当前续费价');
        await reveal(tester, forecastPill);
        final pillRight = tester
            .getTopRight(
              find.ancestor(
                of: forecastPill,
                matching: find.byType(StatusPill),
              ),
            )
            .dx;
        // The card content ends 16 px (page margin) + 16 px (padding) from the edge.
        expect(pillRight, closeTo(390 - 32, 0.5));
        final captions = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byKey(
                  ValueKey('forecast-${const LedgerDate(2026, 9, 1)}'),
                ),
                matching: find.byType(Text),
              ),
            )
            .map((t) => t.data!);
        expect(captions.any((t) => t.startsWith('¥')), isTrue);
      },
    );
  });

  testWidgets(
    'FX cancel preserves missing rates, save updates only display; finance drilldowns share scope',
    (tester) async {
      await mount(tester, opener(FxPage(controller: controller)));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await fill(tester, 'fx-usd', '7');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(controller.fx.usdToCny, isNull);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await fill(tester, 'fx-usd', '7');
      await reveal(tester, find.text('保存参考汇率'));
      await tester.tap(find.text('保存参考汇率'));
      await tester.pumpAndSettle();
      expect(controller.fx.usdToCny, '7');
      expect(controller.byId(server.id)!.amountMinor, 3650);
      await mount(tester, Scaffold(body: FinancePage(controller: controller)));
      await reveal(tester, find.byKey(const ValueKey('metric-monthly')));
      await tester.tap(find.byKey(const ValueKey('metric-monthly')));
      await tester.pumpAndSettle();
      expect(find.text('月费用明细'), findsOneWidget);
      expect(find.text(server.name), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.byKey(const ValueKey('finance-slice-vendor-legacy:Vendor One')),
      );
      await tester.tap(
        find.byKey(const ValueKey('finance-slice-vendor-legacy:Vendor One')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vendor One · 1 台未归档服务器'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('forecast-2027-01-01')));
      // Bars only select a month; the row under the chart opens its renewals.
      await tester.tap(find.byKey(const ValueKey('forecast-2027-01-01')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('forecast-open')));
      await tester.tap(find.byKey(const ValueKey('forecast-open')));
      await tester.pumpAndSettle();
      expect(find.text('2027 年 1 月续费'), findsOneWidget);
      expect(find.text(server.name), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reference trial keeps periods after price/asof edits, quote and clipboard never modify or expose source',
    (tester) async {
      final before = (await store.servers()).single.toMap();
      final periods = (await store.servicePeriods())
          .map((p) => p.toMap())
          .toList();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await mount(
        tester,
        CalculatorPage(controller: controller, server: server),
      );
      await fill(tester, 'calc-price', '73.00');
      await pickDate(
        tester,
        find.byKey(const ValueKey('calc-asof')),
        DateTime(2025, 1, 1),
      );
      await reveal(tester, find.byKey(const ValueKey('calculate-value')));
      await tester.tap(find.byKey(const ValueKey('calculate-value')));
      await tester.pumpAndSettle();
      expect(find.text('计算结果'), findsOneWidget);
      expect(find.text(r'$73.00 USD'), findsOneWidget);
      await reveal(tester, find.text('复制结果'));
      await tester.tap(find.text('复制结果'));
      await tester.pumpAndSettle();
      expect(copied, contains('2025-01-01'));
      expect(copied, contains(r'$73.00'));
      expect(copied, isNot(contains(server.name)));
      expect(copied, isNot(contains(server.host)));
      expect(copied, isNot(contains(server.notes)));
      await reveal(tester, find.text('转让报价试算 · 可选'));
      await tester.tap(find.text('转让报价试算 · 可选'));
      await tester.pumpAndSettle();
      await fill(tester, 'quote-offer', '0.01');
      await fill(tester, 'quote-fee', '0.05');
      await reveal(tester, find.text('计算报价与费用'));
      await tester.tap(find.text('计算报价与费用'));
      await tester.pumpAndSettle();
      expect(find.text('缺少对应汇率，不能计算参考价值与结算金额。'), findsOneWidget);
      await reveal(tester, find.text('转让报价试算 · 可选'));
      await tester.tap(find.text('转让报价试算 · 可选'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('转让报价试算 · 可选'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('quote-offer')));
      expect(
        tester
            .widget<FinanceFieldRow>(find.byKey(const ValueKey('quote-offer')))
            .controller
            .text,
        '0.01',
      );
      expect((await store.servers()).single.toMap(), before);
      expect(
        (await store.servicePeriods()).map((p) => p.toMap()).toList(),
        periods,
      );
      expect(await store.payments(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'finance surfaces omit standalone bill creation and preserve history',
    (tester) async {
      await store.recordAccountPayment(
        id: 'legacy-account-payment',
        accountLabel: 'Legacy bill',
        amount: const Money('USD', 1234),
        paidDate: today,
      );
      await controller.refresh();
      for (final page in <Widget>[
        Scaffold(body: FinancePage(controller: controller)),
        RenewalsPage(controller: controller),
        PaymentListPage(controller: controller),
      ]) {
        await mount(tester, page, scale: 2);
        final scrollable = find.byType(Scrollable).first;
        while (tester.state<ScrollableState>(scrollable).position.extentAfter >
            0) {
          expect(find.text('记录账户账单'), findsNothing);
          expect(find.byTooltip('记录账户账单'), findsNothing);
          await tester.drag(scrollable, const Offset(0, -400));
          await tester.pumpAndSettle();
        }
        expect(find.text('记录账户账单'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Legacy bill'), findsOneWidget);
      expect(find.textContaining('历史账户账单，只计一次'), findsOneWidget);
      expect((await store.payments()).single.id, 'legacy-account-payment');
    },
  );

  group('calculator dates', () {
    final zh = AppLocalizationsZh();
    String dateOf(WidgetTester tester, String key) => tester
        .widget<FinanceDateRow>(find.byKey(ValueKey(key)))
        .controller
        .text;
    Future<void> pick(WidgetTester tester, String key, DateTime? date) =>
        pickDate(tester, find.byKey(ValueKey(key)), date);
    Future<void> chooseCycle(WidgetTester tester, int from, int to) async {
      final row = find.byKey(ValueKey('calc-cycle-$from'));
      await reveal(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('calc-cycle-option-$to')));
      await tester.pumpAndSettle();
    }

    testWidgets('dates are picked, never typed', (tester) async {
      await mount(tester, CalculatorPage(controller: controller));
      for (final key in ['calc-start', 'calc-asof', 'calc-due']) {
        await reveal(tester, find.byKey(ValueKey(key)));
        expect(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(TextField),
          ),
          findsNothing,
        );
      }
      expect(dateOf(tester, 'calc-start'), '2026-09-23');
      expect(dateOf(tester, 'calc-asof'), '2026-09-23');
      expect(dateOf(tester, 'calc-due'), '2027-09-23');
      // The valuation date is required: no "Set Unknown" there.
      await tester.tap(find.byKey(const ValueKey('calc-asof')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('date-sheet-unknown')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('date-sheet-done')));
      await tester.pumpAndSettle();
      expect(dateOf(tester, 'calc-asof'), '2026-09-23');
    });

    testWidgets('start + cycle generate the due date, clamped at month ends', (
      tester,
    ) async {
      await mount(tester, CalculatorPage(controller: controller));
      await pick(tester, 'calc-start', DateTime(2026, 3, 15));
      expect(dateOf(tester, 'calc-due'), '2027-03-15');
      await chooseCycle(tester, 12, 6);
      expect(dateOf(tester, 'calc-due'), '2026-09-15');
      await pick(tester, 'calc-start', DateTime(2026, 8, 31));
      expect(dateOf(tester, 'calc-due'), '2027-02-28');
      await chooseCycle(tester, 6, 12);
      expect(dateOf(tester, 'calc-due'), '2027-08-31');
      await pick(tester, 'calc-start', DateTime(2024, 2, 29));
      expect(dateOf(tester, 'calc-due'), '2025-02-28');
      await chooseCycle(tester, 12, 1);
      expect(dateOf(tester, 'calc-due'), '2024-03-29');
      // The valuation date never moves the due date.
      await pick(tester, 'calc-asof', DateTime(2024, 3, 1));
      expect(dateOf(tester, 'calc-due'), '2024-03-29');
    });

    testWidgets('a manually picked due date is kept until re-derived', (
      tester,
    ) async {
      await mount(tester, CalculatorPage(controller: controller));
      await pick(tester, 'calc-start', DateTime(2026, 3, 15));
      await pick(tester, 'calc-due', DateTime(2030, 1, 1));
      await pick(tester, 'calc-start', DateTime(2026, 5, 5));
      expect(dateOf(tester, 'calc-due'), '2030-01-01');
      await chooseCycle(tester, 12, 3);
      expect(dateOf(tester, 'calc-due'), '2030-01-01');
      // Picking exactly the derived date turns auto back on.
      await pick(tester, 'calc-due', DateTime(2026, 8, 5));
      await pick(tester, 'calc-start', DateTime(2026, 6, 6));
      expect(dateOf(tester, 'calc-due'), '2026-09-06');
      // So does clearing it (the derived date comes back on the next change).
      await pick(tester, 'calc-due', DateTime(2031, 1, 1));
      await pick(tester, 'calc-due', null);
      expect(dateOf(tester, 'calc-due'), isEmpty);
      await chooseCycle(tester, 3, 6);
      expect(dateOf(tester, 'calc-due'), '2026-12-06');
      // An unknown start leaves the due date alone.
      await pick(tester, 'calc-start', null);
      expect(dateOf(tester, 'calc-start'), isEmpty);
      await chooseCycle(tester, 6, 12);
      expect(dateOf(tester, 'calc-due'), '2026-12-06');
    });

    testWidgets('the generated due date calculates like a typed one', (
      tester,
    ) async {
      await mount(tester, CalculatorPage(controller: controller));
      await fill(tester, 'calc-price', '120');
      await pick(tester, 'calc-start', DateTime(2026, 9, 1));
      await pick(tester, 'calc-asof', DateTime(2026, 9, 23));
      await chooseCycle(tester, 12, 1);
      expect(dateOf(tester, 'calc-due'), '2026-10-01');
      await reveal(tester, find.byKey(const ValueKey('calculate-value')));
      await tester.tap(find.byKey(const ValueKey('calculate-value')));
      await tester.pumpAndSettle();
      final result = tester.widget<CalculationResultPage>(
        find.byType(CalculationResultPage),
      );
      expect(result.due, const LedgerDate(2026, 10, 1));
      expect(result.cycleMonths, 1);
      expect(result.usesKnownPeriods, isFalse);
    });

    testWidgets('a missing due date is reported after Calculate', (
      tester,
    ) async {
      await mount(tester, CalculatorPage(controller: controller));
      await fill(tester, 'calc-price', '120');
      await pick(tester, 'calc-due', null);
      await reveal(tester, find.byKey(const ValueKey('calculate-value')));
      await tester.tap(find.byKey(const ValueKey('calculate-value')));
      await tester.pumpAndSettle();
      expect(find.byType(CalculationResultPage), findsNothing);
      expect(find.text(zh.financeDueError), findsOneWidget);
      // Picking a date clears the message.
      await pick(tester, 'calc-due', DateTime(2027, 1, 1));
      expect(find.text(zh.financeDueError), findsNothing);
    });

    testWidgets('referenced server: auto only while start + cycle = due', (
      tester,
    ) async {
      // start 2026-01-01 + 12 months = due 2027-01-01: derived.
      await mount(
        tester,
        CalculatorPage(controller: controller, server: server),
      );
      expect(dateOf(tester, 'calc-start'), '2026-01-01');
      expect(dateOf(tester, 'calc-due'), '2027-01-01');
      expect(find.text(zh.financeIndependentRebuilt), findsNothing);
      // Valuation date and price edits keep the known periods.
      await pick(tester, 'calc-asof', DateTime(2026, 5, 1));
      expect(find.text(zh.financeIndependentRebuilt), findsNothing);
      // Changing the cycle moves the derived due date and rebuilds periods.
      await chooseCycle(tester, 12, 6);
      expect(dateOf(tester, 'calc-due'), '2026-07-01');
      await reveal(tester, find.text(zh.financeIndependentRebuilt));
      expect(find.text(zh.financeIndependentRebuilt), findsOneWidget);
    });

    testWidgets('referenced renewed server keeps its due date', (tester) async {
      final renewed = ServerRecord(
        id: 'renewed',
        name: 'Renewed',
        vendor: 'Vendor One',
        host: '192.0.2.8',
        createdAt: DateTime(2026, 9, 23),
        updatedAt: DateTime(2026, 9, 23),
        billing: BillingKind.prepaid,
        amountMinor: 1200,
        startDate: const LedgerDate(2024, 1, 1),
        dueDate: const LedgerDate(2027, 1, 1),
      );
      await mount(
        tester,
        CalculatorPage(controller: controller, server: renewed),
      );
      await pick(tester, 'calc-start', DateTime(2025, 1, 1));
      expect(dateOf(tester, 'calc-due'), '2027-01-01');
      expect(find.text(zh.financeIndependentRebuilt), findsNothing);
      await chooseCycle(tester, 12, 6);
      expect(dateOf(tester, 'calc-due'), '2027-01-01');
      await reveal(tester, find.text(zh.financeIndependentRebuilt));
      expect(find.text(zh.financeIndependentRebuilt), findsOneWidget);
    });
  });

  testWidgets(
    '390px large text finance, payment and calculator remain scrollable',
    (tester) async {
      for (final page in <Widget>[
        Scaffold(body: FinancePage(controller: controller)),
        PaymentForm(controller: controller, server: server),
        PaymentForm(controller: controller),
        CalculatorPage(controller: controller, server: server),
        PaymentListPage(controller: controller),
        FxPage(controller: controller),
      ]) {
        await mount(tester, page, scale: 2);
        for (var i = 0; i < 14; i++) {
          await tester.drag(
            find.byType(CustomScrollView).first,
            const Offset(0, -500),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${page.runtimeType} scroll $i',
          );
        }
      }
    },
  );

  testWidgets(
    '390px 2x maximum money and FX result supports a successful quote',
    (tester) async {
      const due = LedgerDate(2027, 1, 1);
      const money = Money('USD', Money.maxMinor);
      final value = valueOfPeriods(
        renewal: money,
        periods: const [
          ServicePeriod(
            id: 'p',
            serverId: 's',
            start: LedgerDate(2026, 1, 1),
            end: due,
          ),
        ],
        asOf: today,
      )!;
      const fx = FxSettings(
        displayCurrency: 'EUR',
        usdToCny: '999999999.99999999',
        eurToCny: '0.00000001',
        rateDate: today,
      );
      await mount(
        tester,
        CalculationResultPage(
          renewal: money,
          cycleMonths: 12,
          asOf: today,
          due: due,
          value: value,
          fx: fx,
          usesKnownPeriods: true,
        ),
        scale: 2,
      );
      await reveal(tester, find.text('转让报价试算 · 可选'));
      await tester.tap(find.text('转让报价试算 · 可选'));
      await tester.pumpAndSettle();
      for (final key in ['quote-offer', 'quote-fee']) {
        await fill(tester, key, '9999999999.99');
      }
      await reveal(tester, find.text('计算报价与费用'));
      await tester.tap(find.text('计算报价与费用'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('卖方预计净收款'));
      expect(find.textContaining('缺少对应汇率'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  group('transfer premium on the result page', () {
    const fx = FxSettings(displayCurrency: 'USD');
    late CalculationResultPage page;
    late QuoteResult Function({
      Money? offer,
      BigInt? premium,
      Rational? percent,
    })
    expected;

    setUp(() {
      const due = LedgerDate(2027, 1, 1);
      const money = Money('USD', 3650);
      final value = valueOfPeriods(
        renewal: money,
        periods: calculatorPeriods(today, due, 12),
        asOf: today,
      )!;
      page = CalculationResultPage(
        renewal: money,
        cycleMonths: 12,
        asOf: today,
        due: due,
        value: value,
        fx: fx,
        usesKnownPeriods: false,
      );
      expected = ({Money? offer, BigInt? premium, Rational? percent}) =>
          calculateQuote(
            offer: offer,
            premiumMinor: premium,
            premiumPercent: percent,
            fee: const Money('USD', 101),
            payer: FeePayer.split,
            reference: value.amount,
            fx: fx,
          )!;
    });

    Future<void> open(WidgetTester tester) async {
      await mount(tester, page);
      await reveal(tester, find.text('转让报价试算 · 可选'));
      await tester.tap(find.text('转让报价试算 · 可选'));
      await tester.pumpAndSettle();
    }

    Future<void> pickMode(WidgetTester tester, QuoteMode mode) async {
      await reveal(tester, find.byKey(const ValueKey('quote-mode')));
      await tester.tap(find.byKey(const ValueKey('quote-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('quote-mode-${mode.name}')));
      await tester.pumpAndSettle();
    }

    Future<void> settle(WidgetTester tester) async {
      await fill(tester, 'quote-fee', '1.01');
      await reveal(tester, find.byKey(const ValueKey('quote-payer')));
      await tester.tap(find.byKey(const ValueKey('quote-payer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quote-payer-split')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('calculate-quote')));
      await tester.tap(find.byKey(const ValueKey('calculate-quote')));
      await tester.pumpAndSettle();
    }

    void expectSettlement(WidgetTester tester, QuoteResult q) {
      final section = find.byKey(const ValueKey('quote-settlement'));
      expect(section, findsOneWidget);
      for (final text in [q.reference, q.offer, q.buyerTotal, q.sellerNet]) {
        expect(find.textContaining(text), findsWidgets, reason: text);
      }
      expect(q.referenceMinor + q.premiumMinor, q.offerMinor);
    }

    testWidgets('quote mode: premium shown as price minus remaining value', (
      tester,
    ) async {
      await open(tester);
      await fill(tester, 'quote-offer', '30.00');
      await settle(tester);
      final q = expected(offer: const Money('USD', 3000));
      expectSettlement(tester, q);
      expect(find.textContaining(q.premium), findsWidgets);
    });

    testWidgets('premium amount adds to the remaining value', (tester) async {
      await open(tester);
      await pickMode(tester, QuoteMode.premium);
      expect(find.byKey(const ValueKey('quote-offer')), findsNothing);
      await fill(tester, 'quote-premium', '2.50');
      await settle(tester);
      final q = expected(premium: BigInt.from(250));
      expectSettlement(tester, q);
      expect(find.text('溢价'), findsWidgets);
    });

    testWidgets('discount percent subtracts and is labelled 折价', (
      tester,
    ) async {
      await open(tester);
      await pickMode(tester, QuoteMode.percent);
      await reveal(tester, find.byKey(const ValueKey('quote-direction')));
      await tester.tap(find.text('折价'));
      await tester.pumpAndSettle();
      await fill(tester, 'quote-percent', '10');
      await settle(tester);
      final q = expected(percent: Rational.of(-10));
      expect(q.isDiscount, isTrue);
      expectSettlement(tester, q);
      expect(find.textContaining('-10.00%'), findsOneWidget);
    });

    testWidgets('invalid percent and an oversized discount are refused', (
      tester,
    ) async {
      await open(tester);
      await pickMode(tester, QuoteMode.percent);
      await fill(tester, 'quote-percent', '1500');
      await settle(tester);
      expect(find.text('请输入 0–1000 的比例，最多 2 位小数'), findsOneWidget);
      expect(find.byKey(const ValueKey('quote-settlement')), findsNothing);
      await pickMode(tester, QuoteMode.premium);
      await reveal(tester, find.byKey(const ValueKey('quote-direction')));
      await tester.tap(find.text('折价'));
      await tester.pumpAndSettle();
      await fill(tester, 'quote-premium', '9999.00');
      await settle(tester);
      expect(find.text('折价不能超过剩余价值，成交价需在支持范围内'), findsOneWidget);
      expect(find.byKey(const ValueKey('quote-settlement')), findsNothing);
    });
  });

  testWidgets('share card is deterministic and only draws the whitelist', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final first = await renderCalculationPng(shareFixture());
      final second = await renderCalculationPng(shareFixture());
      expect(second, first);
      final other = await renderCalculationPng(shareFixture(amount: r'$1.00'));
      expect(other, isNot(first));
      final codec = await ui.instantiateImageCodec(first);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1080);
      expect(frame.image.height, greaterThan(1200));
      frame.image.dispose();
      codec.dispose();
    });
    // The renderer's only input is the whitelist; its plain-text twin carries
    // no quote, server or account information either.
    final text = shareFixture().plainText;
    for (final secret in ['PRIVATE', '192.0.2', 'premium', '溢价', '手续费']) {
      expect(text, isNot(contains(secret)));
    }
  });

  testWidgets(
    'PNG selects Downloads then Documents then support exports, without hiding write failures',
    (tester) async {
      final previous = PathProviderPlatform.instance;
      addTearDown(() => PathProviderPlatform.instance = previous);
      await tester.runAsync(() async {
        final png = await renderCalculationPng(shareFixture());
        final downloads = '${directory.path}/Downloads';
        final documents = '${directory.path}/Documents';
        final support = '${directory.path}/Support';
        for (final available in [downloads, documents, support]) {
          final provider = ExportPathProvider(
            downloads: available == downloads ? downloads : null,
            documents: available == documents ? documents : null,
            support: support,
          );
          PathProviderPlatform.instance = provider;
          final file = File(await saveCalculationPng(png, today));
          expect(
            file.path,
            startsWith(
              available == support ? '$support/exports/' : '$available/',
            ),
          );
          expect(await file.readAsBytes(), png);
          if (available == downloads) {
            expect(provider.documentsReads, 0);
          }
          expect(provider.supportReads, available == support ? 1 : 0);
          if (available == support) {
            final codec = await ui.instantiateImageCodec(
              await file.readAsBytes(),
            );
            final frame = await codec.getNextFrame();
            expect(frame.image.width, 1080);
            frame.image.dispose();
            codec.dispose();
          }
        }
        final notDirectory = File('${directory.path}/not-a-directory');
        await notDirectory.writeAsString('keep');
        final provider = ExportPathProvider(
          downloads: notDirectory.path,
          documents: documents,
          support: support,
        );
        PathProviderPlatform.instance = provider;
        await expectLater(
          saveCalculationPng(png, today),
          throwsA(isA<FileSystemException>()),
        );
        expect(provider.documentsReads, 0);
        expect(provider.supportReads, 0);
        expect(await notDirectory.readAsString(), 'keep');
        final denied = ExportPathProvider(
          downloads: downloads,
          documents: documents,
          support: support,
          denyLookup: true,
        );
        PathProviderPlatform.instance = denied;
        await expectLater(
          saveCalculationPng(png, today),
          throwsA(isA<FileSystemException>()),
        );
        expect(denied.documentsReads, 0);
        expect(denied.supportReads, 0);
      });
    },
  );

  testWidgets(
    'PNG really encodes, unique saves decode; cancelled generation stays closed and failed save can retry',
    (tester) async {
      late Uint8List png;
      await tester.runAsync(() async {
        png = await renderCalculationPng(shareFixture());
        final codec = await ui.instantiateImageCodec(png);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 1080);
        expect(frame.image.height, greaterThan(1200));
        frame.image.dispose();
        codec.dispose();
        final first = await saveCalculationPngIn(directory, png, today);
        final second = await saveCalculationPngIn(directory, png, today);
        expect(first, isNot(second));
        expect(await File(first).readAsBytes(), png);
        final savedCodec = await ui.instantiateImageCodec(
          await File(second).readAsBytes(),
        );
        final savedFrame = await savedCodec.getNextFrame();
        expect(savedFrame.image.width, 1080);
        savedFrame.image.dispose();
        savedCodec.dispose();
      });
      final pending = Completer<Uint8List>();
      await mount(
        tester,
        opener(
          CalculationPreview(
            data: shareFixture(),
            renderer: (_) => pending.future,
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('图片预览'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      pending.complete(png);
      await tester.pumpAndSettle();
      expect(find.text('图片预览'), findsNothing);
      var attempts = 0;
      await mount(
        tester,
        CalculationPreview(
          data: shareFixture(),
          renderer: (_) async => png,
          saver: (_, _) async {
            attempts++;
            if (attempts == 1) throw const FileSystemException('test');
            return '/synthetic/value.png';
          },
        ),
      );
      await reveal(tester, find.text('保存 PNG'));
      await tester.tap(find.text('保存 PNG'));
      await tester.pumpAndSettle();
      expect(find.textContaining('保存未完成'), findsOneWidget);
      expect(find.byKey(const ValueKey('calculation-png')), findsOneWidget);
      await tester.tap(find.text('保存 PNG'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.textContaining('/synthetic/value.png'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class ExportPathProvider extends PathProviderPlatform {
  ExportPathProvider({
    this.downloads,
    this.documents,
    required this.support,
    this.denyLookup = false,
  });
  final String? downloads, documents;
  final String support;
  final bool denyLookup;
  int documentsReads = 0, supportReads = 0;
  @override
  Future<String?> getDownloadsPath() async {
    if (denyLookup) throw const FileSystemException('permission denied');
    return downloads;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    documentsReads++;
    return documents;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    supportReads++;
    return support;
  }
}
