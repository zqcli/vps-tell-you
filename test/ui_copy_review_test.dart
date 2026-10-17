import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/app.dart';
import 'package:vps_tell_you/providers/provider_pages.dart';
import 'package:vps_tell_you/connections/connection_pages.dart';
import 'package:vps_tell_you/connections/snippet_pages.dart';
import 'package:vps_tell_you/connections/tcp_test_page.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/finance/calculation_share.dart';
import 'package:vps_tell_you/finance/calculation_widgets.dart';
import 'package:vps_tell_you/finance/calculator_page.dart';
import 'package:vps_tell_you/finance/finance_math.dart';
import 'package:vps_tell_you/finance/finance_page.dart';
import 'package:vps_tell_you/finance/fx_page.dart';
import 'package:vps_tell_you/finance/payment_pages.dart';
import 'package:vps_tell_you/finance/valuation_copy.dart';
import 'package:vps_tell_you/security/host_trust_pages.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_pages.dart';
import 'package:vps_tell_you/security/ssh_configuration_page.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_detail.dart';
import 'package:vps_tell_you/servers/server_form.dart';
import 'package:vps_tell_you/servers/server_list.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/settings/backup_page.dart';
import 'package:vps_tell_you/settings/reminder_page.dart';
import 'package:vps_tell_you/settings/settings_page.dart';

import 'security_store_test.dart' show FakeDeviceAuth, FakeSecretStore;

void main() {
  final evidence = Platform.environment['VPS_COPY_EVIDENCE_DIR'];
  final fontPath = Platform.environment['VPS_COPY_FONT'];
  var fontsLoaded = false;
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late ServerRecord server;
  final now = DateTime(2026, 10, 7, 12);

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('ui-copy-review-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.db',
      clock: () => now,
    );
    ledger = LedgerController(
      store,
      clock: () => now,
      security: SecurityController(
        store: store,
        secrets: FakeSecretStore(),
        authenticator: FakeDeviceAuth(),
      ),
    );
    server = ServerRecord(
      id: 'copy-review-fixture',
      name: '文案审查演示服务器',
      vendor: '合成厂商',
      host: '192.0.2.10',
      purpose: '合成演示',
      billing: BillingKind.prepaid,
      currency: 'EUR',
      amountMinor: 2400,
      cycleMonths: 12,
      startDate: const LedgerDate(2026, 1, 1),
      dueDate: const LedgerDate(2027, 1, 1),
      createdAt: now,
      updatedAt: now,
      isDemo: true,
    );
    await store.saveServer(server, isNew: true);
    await ledger.refresh();
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester,
    Widget page, {
    double scale = 2,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    if (fontPath != null && !fontsLoaded) {
      await tester.runAsync(() async {
        final loader = FontLoader('Copy Review CJK');
        loader.addFont(File(fontPath).readAsBytes().then(ByteData.sublistView));
        await loader.load();
        final icons = FontLoader('MaterialIcons');
        icons.addFont(
          File(
            '${Platform.environment['FLUTTER_BOOTSTRAP_ROOT']}/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then(ByteData.sublistView),
        );
        await icons.load();
        fontsLoaded = true;
      });
    }
    final base = appTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: fontPath == null
            ? base
            : base.copyWith(
                textTheme: base.textTheme.apply(fontFamily: 'Copy Review CJK'),
                appBarTheme: base.appBarTheme.copyWith(
                  titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
                    fontFamily: 'Copy Review CJK',
                  ),
                ),
              ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: const ValueKey('copy-evidence'),
            child: child,
          ),
        ),
        home: page,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (evidence == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('copy-evidence')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('$evidence/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> inspectPage(
    WidgetTester tester,
    String name,
    Widget page,
  ) async {
    await mount(tester, page);
    await capture(tester, '$name-top-320x2');
    // Visit every vertical section, including lazily built rows, without
    // activating a network, system clipboard, picker, notification or keyring.
    for (var i = 0; i < 45; i++) {
      final scrollables = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .where(
            (state) =>
                state.axisDirection == AxisDirection.down &&
                state.position.hasContentDimensions,
          );
      if (scrollables.isEmpty) break;
      final state = scrollables.first;
      if (state.position.extentAfter <= 1) break;
      final target = (state.position.pixels + 430).clamp(
        0.0,
        state.position.maxScrollExtent,
      );
      state.position.jumpTo(target);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$name section $i');
      if (i == 3) await capture(tester, '$name-middle-320x2');
    }
    await capture(tester, '$name-bottom-320x2');
  }

  test('valuation wording distinguishes future, current, expired and unknown periods', () {
    const start = LedgerDate(2026, 1, 1), end = LedgerDate(2027, 1, 1);
    for (final item in [
      (const LedgerDate(2025, 12, 31), '尚未开始的周期'),
      (start, '当前周期'),
      (const LedgerDate(2026, 12, 31), '当前周期'),
      (end, '已结束的周期'),
    ]) {
      expect(
        valuationPeriodLabel(asOf: item.$1, start: start, end: end),
        item.$2,
      );
    }
    expect(valuationPeriodLabel(asOf: start), '所示周期');
    expect(reminderDaysLabel([7, 1, 0]), '提前 7 天、提前 1 天、到期当天');
    expect(reminderDaysLabel([]), '未选择提醒日期');
  });

  testWidgets(
    'generic errors do not diagnose unrelated group errors or expose drivers',
    (tester) async {
      await mount(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showFailure(context, StateError('PRIVATE SQL DRIVER VALUES')),
              child: const Text('模拟失败'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('模拟失败'));
      await tester.pumpAndSettle();
      expect(find.text('操作未完成，请重试。已保存的资料仍保留。'), findsOneWidget);
      expect(find.textContaining('分组'), findsNothing);
      expect(find.textContaining('PRIVATE'), findsNothing);
    },
  );

  final pages = <String, Widget Function()>{
    'server-list': () => Scaffold(body: ServerList(controller: ledger)),
    'server-form': () => ServerForm(controller: ledger, record: server),
    'server-detail': () => ServerDetail(controller: ledger, id: server.id),
    'finance': () => Scaffold(body: FinancePage(controller: ledger)),
    'calculator': () => CalculatorPage(controller: ledger, server: server),
    'payment': () => PaymentForm(controller: ledger, server: server),
    'exchange-rates': () => FxPage(controller: ledger),
    'tools': () => Scaffold(body: ToolsPage(controller: ledger)),
    'settings': () => Scaffold(body: SettingsPage(controller: ledger)),
    'backup': () => BackupPage(controller: ledger),
    'reminder': () => ReminderPage(controller: ledger, serverId: server.id),
    'notification': () => NotificationPage(controller: ledger),
    'providers': () => ProvidersPage(ledger: ledger),
    'security': () => SecurityPage(ledger: ledger),
    'ssh-config': () =>
        SshConfigurationPage(ledger: ledger, serverId: server.id),
    'ssh-connect': () => SshConnectPage(ledger: ledger),
    'host-trust': () => HostTrustPage(ledger: ledger),
    'snippets': () => SnippetListPage(store: store),
    'tcp': () => const TcpTestPage(),
  };
  for (final entry in pages.entries) {
    testWidgets(
      '${entry.key} copy stays readable at 320 logical pixels and 2x text',
      (tester) async {
        await inspectPage(tester, entry.key, entry.value());
      },
    );
  }

  testWidgets(
    'future period card and exported text use the same precise description',
    (tester) async {
      const asOf = LedgerDate(2025, 12, 1);
      final value = serverValuation(
        server,
        ledger.periodsFor(server.id),
        asOf,
      )!;
      await inspectPage(
        tester,
        'future-value',
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              CalculationHero(value: value, fx: ledger.fx, asOf: asOf),
              const SizedBox(height: 16),
              CalculationDetails(
                value: value,
                renewal: server.money!,
                cycleMonths: 12,
                due: server.dueDate!,
                asOf: asOf,
              ),
            ],
          ),
        ),
      );
      final data = CalculationShareData(
        amount: value.amount.formatted,
        currency: server.currency,
        converted: '汇率未设置',
        asOf: asOf,
        start: value.activePeriod.start,
        end: value.activePeriod.end,
        due: server.dueDate!,
        ratio: value.ratio.toDouble(),
        activeRemaining: value.activeRemaining,
        days: value.days,
        remaining: value.remainingDays,
        renewal: '24.00 EUR / 12 个月',
        daily: '0.0658 EUR',
        futurePeriods: value.futurePeriods,
        fx: '汇率未设置',
        fxSource: '手动汇率',
        periodBasis: '引用已知服务期',
      );
      expect(data.plainText, contains('尚未开始的周期'));
      expect(data.plainText, contains('不含结束日'));
      expect(data.plainText, isNot(contains('本周期')));
      expect(value.amount.minor!.round(), BigInt.from(2400));
    },
  );
}
