import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/finance/calculation_share.dart';
import 'package:vps_tell_you/finance/calculator_page.dart';
import 'package:vps_tell_you/finance/finance_math.dart';
import 'package:vps_tell_you/finance/finance_models.dart';
import 'package:vps_tell_you/finance/finance_page.dart';
import 'package:vps_tell_you/finance/finance_widgets.dart';
import 'package:vps_tell_you/finance/fx_page.dart';
import 'package:vps_tell_you/finance/payment_pages.dart';
import 'package:vps_tell_you/finance/valuation_copy.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';
import 'package:vps_tell_you/l10n/localized_message.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'support/form_test_helpers.dart' show pickDate;
import 'support/reminder_platform.dart';

final en = AppLocalizationsEn();
final zh = AppLocalizationsZh();
const today = LedgerDate(2026, 10, 7);

CalculationShareData exportFixture(AppLocalizations l10n) =>
    CalculationShareData(
      localizations: l10n,
      amount: r'$9999999999.99',
      currency: 'USD',
      converted: l10n.financeMissingFxPreserved,
      asOf: const LedgerDate(2025, 12, 1),
      start: const LedgerDate(2026, 1, 1),
      end: const LedgerDate(2027, 1, 1),
      due: const LedgerDate(2028, 1, 1),
      ratio: 1,
      activeRemaining: 365,
      days: 365,
      remaining: 730,
      renewal: l10n.financeRenewalValue(r'$9999999999.99', 'USD', 12),
      daily: '27397260.2739 USD',
      futurePeriods: 2,
      fx: l10n.financeReferenceRateMissing,
      fxSource: l10n.financeFxSource(l10n.financeDateNotSet),
      periodBasis: l10n.financeKnownPeriodsBasis('yes'),
    );

void main() {
  test(
    'localized valuation periods retain inclusive start and exclusive end',
    () {
      const start = LedgerDate(2026, 1, 1), end = LedgerDate(2027, 1, 1);
      for (final item in [
        (const LedgerDate(2025, 12, 31), 'Future period', '尚未开始的周期'),
        (start, 'Current period', '当前周期'),
        (const LedgerDate(2026, 12, 31), 'Current period', '当前周期'),
        (end, 'Ended period', '已结束的周期'),
      ]) {
        expect(
          valuationPeriodLabel(asOf: item.$1, start: start, end: end, l10n: en),
          item.$2,
        );
        expect(
          valuationPeriodLabel(asOf: item.$1, start: start, end: end, l10n: zh),
          item.$3,
        );
      }
      expect(valuationPeriodLabel(asOf: start, l10n: en), 'Shown period');
      expect(valuationPeriodLabel(asOf: start), '所示周期');
    },
  );

  test('known zero, unknown, not applicable and missing FX stay distinct', () {
    const fx = FxSettings(displayCurrency: 'USD');
    expect(
      convertedAmount(FinanceAmount.money(const Money('USD', 0)), fx, l10n: en),
      r'Approx. $0.00 USD',
    );
    expect(
      convertedAmount(const FinanceAmount.unknown('USD'), fx, l10n: en),
      'Information unknown',
    );
    expect(
      convertedAmount(const FinanceAmount.notApplicable('USD'), fx, l10n: en),
      'Not applicable / excluded',
    );
    expect(
      convertedAmount(FinanceAmount.money(const Money('EUR', 0)), fx, l10n: en),
      'Exchange rate missing · Original currency retained',
    );
    expect(
      const FxSettings(usdToCny: '0').validate(l10n: en),
      contains('positive'),
    );
    expect(const FxSettings(usdToCny: '0').validate(), contains('正数'));
  });

  test('finance errors have a stable type and display-time language', () {
    Object? error;
    try {
      calculatorPeriods(today, const LedgerDate(2200, 1, 1), 12);
    } catch (caught) {
      error = caught;
    }
    expect(error, isA<ArgumentError>());
    expect(error, isA<LocalizedMessage>());
    expect((error! as LocalizedMessage).messageFor(en), contains('100-year'));
    expect((error as LocalizedMessage).messageFor(zh), contains('100 年'));
  });

  test(
    'export locale is immutable and English retains values and boundaries',
    () {
      final english = exportFixture(en);
      final chinese = exportFixture(zh);
      expect(english.l10n.localeName, 'en');
      expect(english.plainText, contains(r'$9999999999.99 USD'));
      expect(english.plainText, contains('2026-01-01 to 2027-01-01'));
      expect(english.plainText, contains('end date excluded'));
      expect(english.plainText, contains('Future period'));
      expect(english.plainText, contains('2 future periods'));
      expect(english.plainText, contains('not a refund promise or sale price'));
      expect(RegExp(r'[\u4e00-\u9fff]').hasMatch(english.plainText), isFalse);
      expect(chinese.plainText, contains('尚未开始的周期'));
      expect(english.plainText, isNot(contains('尚未开始的周期')));
    },
  );

  testWidgets(
    'English PNG uses snapshot content and accommodates long amounts',
    (tester) async {
      final data = exportFixture(en);
      await tester.runAsync(() async {
        final bytes = await renderCalculationPng(data);
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        expect(image.width, 1080);
        expect(image.height, greaterThan(1200));
        image.dispose();
        codec.dispose();
      });
    },
  );

  group('English finance UI', () {
    late Directory directory;
    late LedgerStore store;
    late LedgerController ledger;
    late ServerRecord server;
    final now = DateTime(2026, 10, 7, 12);
    setUp(() async {
      sqfliteFfiInit();
      directory = await Directory.systemTemp.createTemp('finance-l10n-');
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
      server = ServerRecord(
        id: 'finance-l10n-server',
        name: '用户自填服务器名',
        vendor: 'Synthetic provider',
        host: '192.0.2.10',
        billing: BillingKind.prepaid,
        currency: 'USD',
        amountMinor: 3650,
        cycleMonths: 12,
        startDate: const LedgerDate(2026, 1, 1),
        dueDate: const LedgerDate(2027, 1, 1),
        createdAt: now,
        updatedAt: now,
      );
      await store.saveServer(server, isNew: true);
      await store.recordAccountPayment(
        id: 'finance-l10n-payment',
        accountLabel: '用户自填账户名',
        amount: const Money('EUR', 1000),
        paidDate: today,
        note: '用户自填备注',
      );
      await ledger.refresh();
      server = ledger.records.single;
    });
    tearDown(() async {
      ledger.dispose();
      await store.close();
      await directory.delete(recursive: true);
    });

    Widget app(Widget page, {String locale = 'en', double scale = 1}) =>
        MaterialApp(
          theme: appTheme(),
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: page,
        );

    Future<void> mount(
      WidgetTester tester,
      Widget page, {
      String locale = 'en',
      double scale = 1,
      double width = 390,
    }) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(page, locale: locale, scale: scale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> reveal(WidgetTester tester, Finder finder) async {
      // Finish any text-focus reveal before moving the page ourselves. A
      // previously visited lazy child may be above the current viewport.
      await tester.pumpAndSettle();
      final scrolling = find.byType(Scrollable).first;
      if (finder.evaluate().isEmpty) {
        final position = tester.state<ScrollableState>(scrolling).position;
        position.jumpTo(position.minScrollExtent);
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(
        finder,
        250,
        scrollable: scrolling,
        maxScrolls: 70,
      );
      // Lazy content and expanded sections update their scroll extent on the
      // next frame. Align using the resulting geometry, then check the target.
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
      await tester.pumpAndSettle();
      expect(finder.hitTestable(), findsOneWidget);
    }

    Future<void> inspectScroll(WidgetTester tester) async {
      for (var i = 0; i < 100; i++) {
        final states = tester
            .stateList<ScrollableState>(find.byType(Scrollable))
            .where(
              (state) =>
                  state.axisDirection == AxisDirection.down &&
                  state.position.hasContentDimensions,
            );
        if (states.isEmpty || states.first.position.extentAfter <= 1) break;
        final state = states.first;
        state.position.jumpTo(
          (state.position.pixels + 400).clamp(
            0.0,
            state.position.maxScrollExtent,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'section $i');
        if (i == 99) fail('Page was not fully inspected');
      }
    }

    Future<void> inspect(WidgetTester tester, Widget page) async {
      await mount(tester, page, width: 320, scale: 2);
      await inspectScroll(tester);
    }

    final pages = <String, Widget Function()>{
      'dashboard': () => Scaffold(body: FinancePage(controller: ledger)),
      'calculator': () => CalculatorPage(controller: ledger, server: server),
      'server payment': () => PaymentForm(controller: ledger, server: server),
      'account payment': () => PaymentForm(controller: ledger),
      'exchange rates': () => FxPage(controller: ledger),
      'payment list': () => PaymentListPage(controller: ledger),
      'payment details': () =>
          PaymentDetailPage(controller: ledger, id: 'finance-l10n-payment'),
      'monthly details': () =>
          FinanceDetailPage(controller: ledger, metric: FinanceMetric.monthly),
      'remaining value details': () =>
          FinanceDetailPage(controller: ledger, metric: FinanceMetric.value),
      'renewals': () => RenewalsPage(controller: ledger),
      'calculation result': () => CalculationResultPage(
        renewal: server.money!,
        cycleMonths: 12,
        asOf: today,
        due: server.dueDate!,
        value: serverValuation(server, ledger.periodsFor(server.id), today)!,
        fx: ledger.fx,
        usesKnownPeriods: true,
      ),
    };
    for (final entry in pages.entries) {
      testWidgets('${entry.key} supports English at 320 pixels and 2x text', (
        tester,
      ) async {
        await inspect(tester, entry.value());
      });
    }

    testWidgets(
      'calculator language changes preserve drafts and refresh errors',
      (tester) async {
        final page = CalculatorPage(controller: ledger, server: server);
        await mount(tester, page, locale: 'zh');
        final price = find.byKey(const ValueKey('calc-price'));
        await reveal(tester, price);
        final controller = tester.widget<FinanceFieldRow>(price).controller;
        await tester.enterText(price, '52.34');
        final due = find.byKey(const ValueKey('calc-due'));
        await reveal(tester, due);
        await pickDate(tester, due, null);
        final calculate = find.byKey(const ValueKey('calculate-value'));
        await reveal(tester, calculate);
        await tester.tap(calculate);
        await tester.pumpAndSettle();
        await reveal(tester, due);
        expect(tester.state<FormFieldState<String>>(due).errorText, '请输入有效到期日');
        await tester.pumpWidget(app(page));
        await tester.pumpAndSettle();
        expect(
          tester.state<FormFieldState<String>>(due).errorText,
          'Enter a valid due date',
        );
        expect(tester.widget<FinanceDateRow>(due).controller.text, isEmpty);
        await reveal(tester, price);
        expect(
          tester.widget<FinanceFieldRow>(price).controller,
          same(controller),
        );
        expect(controller.text, '52.34');
        expect(ledger.byId(server.id)!.amountMinor, 3650);
        expect(ledger.byId(server.id)!.name, '用户自填服务器名');
      },
    );

    testWidgets(
      'payment draft and confirmation error survive a language switch',
      (tester) async {
        final page = PaymentForm(controller: ledger);
        await mount(tester, page, locale: 'zh');
        final account = find.byKey(const ValueKey('pay-account'));
        await reveal(tester, account);
        await tester.enterText(account, '原样保存用户输入');
        final amount = find.byKey(const ValueKey('pay-amount'));
        await reveal(tester, amount);
        await tester.enterText(amount, 'not-a-number');
        final save = find.byKey(const ValueKey('save-payment'));
        await reveal(tester, save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.text('请确认已完成厂商付款并核对资料'), findsOneWidget);
        await tester.pumpWidget(app(page));
        await tester.pumpAndSettle();
        await reveal(tester, find.text(en.financePaymentConfirmError));
        expect(find.text(en.financePaymentConfirmError), findsOneWidget);
        await reveal(tester, amount);
        expect(
          tester.widget<FinanceFieldRow>(amount).controller.text,
          'not-a-number',
        );
        expect(
          tester.state<FormFieldState<String>>(amount).errorText,
          en.financePaidAmountError,
        );
        await reveal(tester, account);
        expect(
          tester.widget<FinanceFieldRow>(account).controller.text,
          '原样保存用户输入',
        );
        expect(ledger.payments.length, 1);
      },
    );

    testWidgets(
      'expanded transfer quote keeps drafts and retranslates errors',
      (tester) async {
        final page = CalculationResultPage(
          renewal: server.money!,
          cycleMonths: 12,
          asOf: today,
          due: server.dueDate!,
          value: serverValuation(server, ledger.periodsFor(server.id), today)!,
          fx: ledger.fx,
          usesKnownPeriods: true,
        );
        await mount(tester, page, width: 320, scale: 2);
        final panel = find.text(en.financeQuoteTitle);
        await reveal(tester, panel);
        await tester.tap(panel);
        await tester.pumpAndSettle();
        final offer = find.byKey(const ValueKey('quote-offer'));
        await reveal(tester, offer);
        await tester.enterText(offer, '100.50');
        final settle = find.text(en.financeCalculateQuote);
        await reveal(tester, settle);
        await tester.tap(settle);
        await tester.pumpAndSettle();
        await reveal(tester, find.text(en.financeQuoteFxError));
        expect(find.text(en.financeQuoteFxError), findsOneWidget);
        await inspectScroll(tester);
        await tester.pumpWidget(app(page, locale: 'zh', scale: 2));
        await tester.pumpAndSettle();
        await reveal(tester, find.text(zh.financeQuoteFxError));
        expect(find.text(zh.financeQuoteFxError), findsOneWidget);
        await reveal(tester, offer);
        expect(tester.widget<FinanceFieldRow>(offer).controller.text, '100.50');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('expanded algorithm explanation fits narrow English screens', (
      tester,
    ) async {
      await mount(
        tester,
        CalculatorPage(controller: ledger),
        width: 320,
        scale: 2,
      );
      final title = find.text(en.financeAlgorithmTitle);
      await reveal(tester, title);
      await tester.tap(title);
      await tester.pumpAndSettle();
      await inspectScroll(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FX form retains raw decimal drafts across language changes', (
      tester,
    ) async {
      final page = FxPage(controller: ledger);
      await mount(tester, page, locale: 'zh');
      final rate = find.byKey(const ValueKey('fx-usd'));
      await reveal(tester, rate);
      await tester.enterText(rate, '7.12345678');
      final date = find.byKey(const ValueKey('fx-date'));
      await reveal(tester, date);
      await tester.enterText(date, 'invalid-date');
      await reveal(tester, find.text('保存参考汇率'));
      await tester.tap(find.text('保存参考汇率'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(page));
      await tester.pumpAndSettle();
      await reveal(tester, date);
      expect(
        tester.state<FormFieldState<String>>(date).errorText,
        en.financePastDateError,
      );
      await reveal(tester, rate);
      expect(
        tester.widget<FinanceFieldRow>(rate).controller.text,
        '7.12345678',
      );
      expect(ledger.fx.usdToCny, isNull);
    });

    testWidgets(
      'delete confirmation shows the full copy in both languages and cancellation is inert',
      (tester) async {
        for (final (locale, l10n) in [('en', en), ('zh', zh)]) {
          final page = PaymentDetailPage(
            controller: ledger,
            id: 'finance-l10n-payment',
          );
          await mount(tester, page, locale: locale);
          await reveal(tester, find.byKey(const ValueKey('payment-delete')));
          await tester.tap(find.byKey(const ValueKey('payment-delete')));
          await tester.pumpAndSettle();
          expect(find.text(l10n.r2FinanceDeleteTitle), findsOneWidget);
          expect(find.text(l10n.r2FinanceDeleteAccountMsg), findsOneWidget);
          await tester.tap(find.text(l10n.cancel));
          await tester.pumpAndSettle();
          expect(ledger.payments.single.voided, isFalse);
          expect(find.text(l10n.r2FinanceDeleteTitle), findsNothing);
        }
      },
    );

    testWidgets('open calculation rules follow language changes', (
      tester,
    ) async {
      final page = Scaffold(body: FinancePage(controller: ledger));
      await mount(tester, page);
      await tester.tap(find.byTooltip(en.financeCalculationRules));
      await tester.pumpAndSettle();
      expect(find.text(en.financeRulesTitle), findsOneWidget);
      await tester.pumpWidget(app(page, locale: 'zh'));
      await tester.pumpAndSettle();
      expect(find.text(zh.financeRulesTitle), findsOneWidget);
      expect(find.text(zh.financeRulesBody), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'PNG failure status retranslates without rerendering or data loss',
      (tester) async {
        var calls = 0;
        final snapshot = exportFixture(en);
        final page = CalculationPreview(
          data: snapshot,
          renderer: (_) async {
            calls++;
            throw StateError('synthetic image failure');
          },
        );
        await mount(tester, page);
        expect(find.text(en.financePngRenderFailed), findsOneWidget);
        expect(calls, 1);
        await tester.pumpWidget(app(page, locale: 'zh'));
        await tester.pumpAndSettle();
        expect(find.text(zh.financePngRenderFailed), findsOneWidget);
        expect(calls, 1);
        expect(snapshot.l10n.localeName, 'en');
        expect(snapshot.plainText, contains('Future period'));
      },
    );
  });
}
