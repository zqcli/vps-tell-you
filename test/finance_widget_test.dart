import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/finance/calculation_share.dart';
import 'package:vps_tell_you/finance/calculator_page.dart';
import 'package:vps_tell_you/finance/finance_page.dart';
import 'package:vps_tell_you/finance/finance_math.dart';
import 'package:vps_tell_you/finance/finance_models.dart';
import 'package:vps_tell_you/finance/fx_page.dart';
import 'package:vps_tell_you/finance/payment_pages.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';

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
    controller = LedgerController(store, clock: clock);
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
        find.byKey(const ValueKey('finance-slice-vendor-Vendor One')),
      );
      await tester.tap(
        find.byKey(const ValueKey('finance-slice-vendor-Vendor One')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vendor One · 1 台活动服务器'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('forecast-2027-01-01')));
      await tester.tap(find.byKey(const ValueKey('forecast-2027-01-01')));
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
      await fill(tester, 'calc-asof', '2025-01-01');
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
      await reveal(tester, find.text('转让结算 · 可选'));
      await tester.tap(find.text('转让结算 · 可选'));
      await tester.pumpAndSettle();
      await fill(tester, 'quote-offer', '0.01');
      await fill(tester, 'quote-fee', '0.05');
      await reveal(tester, find.text('计算转让结算'));
      await tester.tap(find.text('计算转让结算'));
      await tester.pumpAndSettle();
      expect(find.text('缺少对应汇率，不能计算参考价值与结算金额。'), findsOneWidget);
      await reveal(tester, find.text('转让结算 · 可选'));
      await tester.tap(find.text('转让结算 · 可选'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('转让结算 · 可选'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('quote-offer')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('quote-offer')))
            .controller!
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
          await tester.drag(find.byType(ListView).first, const Offset(0, -500));
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
      await reveal(tester, find.text('转让结算 · 可选'));
      await tester.tap(find.text('转让结算 · 可选'));
      await tester.pumpAndSettle();
      for (final key in ['quote-offer', 'quote-fee']) {
        await fill(tester, key, '9999999999.99');
      }
      await reveal(tester, find.text('计算转让结算'));
      await tester.tap(find.text('计算转让结算'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('卖方净收款'));
      expect(find.textContaining('缺少对应汇率'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
