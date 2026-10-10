import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoDatePicker;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_form.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

import 'support/form_test_helpers.dart';

void main() {
  final evidence = Platform.environment['VPS_BILLING_REVIEW_EVIDENCE_DIR'];
  var fontsLoaded = false;
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late ServerRecord record;
  final now = DateTime.utc(2026, 10, 6, 12);

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('billing-row-review-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
      clock: () => now,
    );
    record = ServerRecord(
      id: 'billing-layout-review',
      name: '合成测试服务器',
      vendor: '合成测试厂商',
      billing: BillingKind.prepaid,
      currency: 'EUR',
      amountMinor: 1250,
      cycleMonths: 6,
      startDate: const LedgerDate(2024, 2, 29),
      dueDate: const LedgerDate(2027, 1, 1),
      resources: ServerResources(
        ip: '192.0.2.17',
        vcpu: 2,
        ramBytes: 1610612736,
        diskBytes: 21474836480,
        trafficBytes: ServerResources.maxBytes,
      ),
      createdAt: now,
      updatedAt: now,
    );
    await store.saveServer(record, isNew: true);
    ledger = LedgerController(store, clock: () => now);
    await ledger.refresh();
    record = ledger.byId(record.id)!;
  });

  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Finder field(String id) => find.byKey(ValueKey('field-$id'));

  Future<void> mount(
    WidgetTester tester, {
    double width = 320,
    double height = 844,
    ValueNotifier<double>? scale,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final textScale = scale ?? ValueNotifier<double>(2);
    if (scale == null) addTearDown(textScale.dispose);
    if (evidence != null && !fontsLoaded) {
      await tester.runAsync(() async {
        final font = FontLoader('Billing review Noto');
        font.addFont(
          File(
            Platform.environment['VPS_FORM_EVIDENCE_FONT_PATH'] ??
                '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
          ).readAsBytes().then(ByteData.sublistView),
        );
        await font.load();
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
    final theme = appTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: evidence == null
            ? theme
            : theme.copyWith(
                textTheme: theme.textTheme.apply(
                  fontFamily: 'Billing review Noto',
                ),
                appBarTheme: theme.appBarTheme.copyWith(
                  titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
                    fontFamily: 'Billing review Noto',
                  ),
                ),
              ),
        builder: (context, child) => ValueListenableBuilder<double>(
          valueListenable: textScale,
          child: RepaintBoundary(
            key: const ValueKey('billing-review-evidence'),
            child: child,
          ),
          builder: (context, factor, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(factor)),
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ServerForm(
                      controller: ledger,
                      record: ledger.byId(record.id),
                    ),
                  ),
                ),
                child: const Text('Open billing review'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open billing review'));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.12);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String id, String value) async {
    await reveal(tester, field(id));
    await tester.enterText(field(id), value);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  /// Billing is a segmented control; currency and cycle are picker sheets.
  Future<void> select<T>(WidgetTester tester, String id, T value) async {
    await reveal(tester, field(id));
    if (value is BillingKind) {
      final label = switch (value) {
        BillingKind.prepaid => '预付',
        BillingKind.metered => '按量',
        BillingKind.unknown => '未知',
      };
      await tester.tap(
        find.descendant(of: field(id), matching: find.text(label)),
      );
      await tester.pumpAndSettle();
      return;
    }
    await chooseOption(
      tester,
      field(id),
      value is int ? (value == 12 ? '每年' : '每 $value 个月') : '$value',
    );
  }

  Future<void> save(WidgetTester tester) => tapSave(tester);

  Future<void> date(WidgetTester tester, String id, DateTime? value) =>
      pickDate(tester, field(id), value);

  String rowDate(WidgetTester tester, String id) {
    final texts = find.descendant(of: field(id), matching: find.byType(Text));
    return tester
        .widgetList<Text>(texts)
        .map((t) => t.data ?? '')
        .firstWhere(
          (t) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t),
          orElse: () => '',
        );
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (evidence == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('billing-review-evidence')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(evidence).create(recursive: true);
      await File('$evidence/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  void expectFullDate(WidgetTester tester, String id, String expected) {
    final text = find.descendant(of: field(id), matching: find.text(expected));
    expect(text, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(text);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(
      paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: expected.length),
      ),
      hasLength(1),
      reason: 'The ISO date must stay complete on one line',
    );
    expect(
      tester.getRect(text).right,
      lessThanOrEqualTo(tester.getRect(field(id)).right),
    );
  }

  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets('complete ISO dates survive a doubled-text row at $width', (
      tester,
    ) async {
      await mount(tester, width: width);
      await reveal(tester, find.byKey(const ValueKey('row-fees')));
      await capture(tester, 'fee-row-${width.toInt()}-2x');
      await reveal(tester, field('start'));
      final start = tester.getRect(field('start'));
      final due = tester.getRect(field('due'));
      // Date rows are stacked full-width rows of the group.
      expect(start.bottom, lessThanOrEqualTo(due.top + 0.01));
      expect(due.right, lessThanOrEqualTo(width - 16));
      expect(start.height, greaterThanOrEqualTo(48));
      expectFullDate(tester, 'start', '2024-02-29');
      expectFullDate(tester, 'due', '2027-01-01');
      await capture(tester, 'complete-dates-${width.toInt()}-2x');
      await save(tester);
      final saved = (await store.servers()).single;
      expect(saved.startDate, record.startDate);
      expect(saved.dueDate, record.dueDate);
      expect(saved.amountMinor, record.amountMinor);
      expect(saved.resources!.toJson(), record.resources!.toJson());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('date sheet sets, clears and keeps exact values', (tester) async {
    await mount(tester, width: 390, scale: ValueNotifier<double>(1));
    await fill(tester, 'amount', '9999999999.99');
    await date(tester, 'start', DateTime(2026, 10, 6));
    await date(tester, 'due', DateTime(2028, 2, 29));
    expectFullDate(tester, 'start', '2026-10-06');
    expectFullDate(tester, 'due', '2028-02-29');
    // Reopening starts from the stored date; closing without "done" keeps it.
    await reveal(tester, field('start'));
    await tester.tap(field('start'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-sheet-close')));
    await tester.pumpAndSettle();
    expectFullDate(tester, 'start', '2026-10-06');
    // "Set unknown" clears the date.
    await date(tester, 'start', null);
    expect(rowDate(tester, 'start'), isEmpty);
    await date(tester, 'start', DateTime(2026, 10, 6));
    await save(tester);
    final saved = (await store.servers()).single;
    expect(saved.startDate, const LedgerDate(2026, 10, 6));
    expect(saved.dueDate, const LedgerDate(2028, 2, 29));
    expect(saved.amountMinor, Money.maxMinor);
    expect(saved.currency, 'EUR');
    expect(saved.resources!.toJson(), record.resources!.toJson());
    expect(tester.takeException(), isNull);
  });

  testWidgets('resizing and text scaling keep every draft and the cursor', (
    tester,
  ) async {
    final scale = ValueNotifier<double>(1);
    addTearDown(scale.dispose);
    await mount(tester, width: 390, scale: scale);
    await fill(tester, 'amount', '9999999999.99');
    final controller = fieldController(tester, 'field-amount');
    controller.selection = const TextSelection.collapsed(offset: 7);
    tester.view.physicalSize = const Size(320, 844);
    scale.value = 2;
    await tester.pumpAndSettle();
    await reveal(tester, field('amount'));
    expect(fieldController(tester, 'field-amount'), same(controller));
    expect(controller.text, '9999999999.99');
    expect(controller.selection.baseOffset, 7);
    expectFullDate(tester, 'start', '2024-02-29');
    expectFullDate(tester, 'due', '2027-01-01');
    expect(tester.takeException(), isNull);
  });

  testWidgets('row errors retain field identity and semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await mount(tester);
      await fill(tester, 'amount', '1.234');
      await fill(tester, 'notes', 'Preserve all corrections');
      await save(tester);
      expect(field('amount').hitTestable(), findsOneWidget);
      final moneyError = find.text('请输入有效金额，最多两位小数');
      expect(moneyError.hitTestable(), findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(moneyError).didExceedMaxLines,
        isFalse,
      );
      var node = tester.getSemantics(field('amount'));
      expect(node.label, contains('续费金额'));
      expect(node.hint, contains('请输入有效金额，最多两位小数'));
      expect(node.validationResult, ui.SemanticsValidationResult.invalid);
      await capture(tester, 'amount-error-320-2x');
      await fill(tester, 'amount', '0.01');
      // Dates can only be set through the picker, so an invalid order is the
      // one date error a user can produce; it is marked on the due row.
      await date(tester, 'start', DateTime(2026, 10, 6));
      await date(tester, 'due', DateTime(2026, 10, 6));
      await save(tester);
      expect(find.text('到期日必须晚于开始日').hitTestable(), findsOneWidget);
      node = tester.getSemantics(field('due'));
      expect(node.label, contains('服务到期日（选填）'));
      expect(node.hint, contains('到期日必须晚于开始日'));
      expect(node.validationResult, ui.SemanticsValidationResult.invalid);
      node = tester.getSemantics(field('start'));
      expect(node.validationResult, ui.SemanticsValidationResult.valid);
      await capture(tester, 'date-error-320-2x');
      await date(tester, 'due', DateTime(2027, 1, 1));
      await save(tester);
      final saved = (await store.servers()).single;
      expect(saved.amountMinor, 1);
      expect(saved.startDate, const LedgerDate(2026, 10, 6));
      expect(saved.dueDate, const LedgerDate(2027, 1, 1));
      expect(saved.notes, 'Preserve all corrections');
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('all payment periods retain their full spoken meaning', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await mount(tester);
      for (final months in [1, 3, 6, 12, 24, 36]) {
        await select(tester, 'cycle', months);
        final node = tester.getSemantics(field('cycle'));
        expect(node.label, contains('续费周期'));
        expect(node.label, contains(months == 12 ? '每年' : '每 $months 个月'));
        expect(field('cycle').hitTestable(), findsOneWidget);
        expect(tester.getRect(field('cycle')).right, lessThanOrEqualTo(320));
      }
      await capture(tester, 'compact-period-320-2x');
      await tester.tap(field('cycle'));
      await tester.pumpAndSettle();
      final lastPeriod = find.text('每 36 个月').last;
      expect(lastPeriod.hitTestable(), findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(lastPeriod).didExceedMaxLines,
        isFalse,
      );
      await capture(tester, 'payment-period-menu-320-2x');
      await tester.tap(lastPeriod);
      await tester.pumpAndSettle();
      await save(tester);
      expect((await store.servers()).single.cycleMonths, 36);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('free unknown and metered remain distinct after invalid rows', (
    tester,
  ) async {
    await mount(tester);
    await fill(tester, 'amount', '1.234');
    await save(tester);
    await select(tester, 'billing', BillingKind.unknown);
    expect(field('amount'), findsNothing);
    expect(field('start'), findsNothing);
    await save(tester);
    var saved = (await store.servers()).single;
    expect(saved.billing, BillingKind.unknown);
    expect(saved.amountMinor, isNull);
    expect(saved.startDate, isNull);
    expect(saved.dueDate, isNull);
    await tester.tap(find.text('Open billing review'));
    await tester.pumpAndSettle();
    await select(tester, 'billing', BillingKind.prepaid);
    await fill(tester, 'amount', '0');
    await date(tester, 'start', null);
    await date(tester, 'due', null);
    await save(tester);
    saved = (await store.servers()).single;
    expect(saved.billing, BillingKind.prepaid);
    expect(saved.amountMinor, 0);
    expect(saved.startDate, isNull);
    expect(saved.dueDate, isNull);
    await tester.tap(find.text('Open billing review'));
    await tester.pumpAndSettle();
    await select(tester, 'billing', BillingKind.metered);
    expect(field('cycle'), findsNothing);
    expect(field('start'), findsNothing);
    expect(field('due'), findsNothing);
    expect(find.textContaining('每月费用估算'), findsOneWidget);
    await fill(tester, 'amount', '0.01');
    await select(tester, 'currency', 'CNY');
    await save(tester);
    saved = (await store.servers()).single;
    expect(saved.billing, BillingKind.metered);
    expect(saved.amountMinor, 1);
    expect(saved.currency, 'CNY');
    expect(saved.startDate, isNull);
    expect(saved.dueDate, isNull);
    expect(saved.resources!.toJson(), record.resources!.toJson());
    expect(await store.payments(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wrapped locked dates and cycle cannot rewrite paid history', (
    tester,
  ) async {
    await store.recordPayment(
      id: 'billing-review-payment',
      server: record,
      amount: const Money('USD', 9876),
      paidDate: const LedgerDate(2026, 10, 6),
      cycleCount: 1,
      until: const LedgerDate(2027, 7, 1),
      confirmed: true,
    );
    await ledger.refresh();
    record = ledger.byId(record.id)!;
    final beforePayments = (await store.payments())
        .map((p) => p.toMap())
        .toList();
    final beforePeriods = (await store.servicePeriods())
        .map((p) => p.toMap())
        .toList();
    await mount(tester);
    // Locked: billing, cycle and dates explain the lock and never change.
    for (final id in ['cycle', 'start', 'due']) {
      await reveal(tester, field(id));
      await tester.tap(field(id));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(CupertinoDatePicker), findsNothing);
    }
    await reveal(tester, field('billing'));
    await tester.tap(
      find.descendant(of: field('billing'), matching: find.text('按量')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<AppSegmented<BillingKind>>(field('billing')).value,
      BillingKind.prepaid,
    );
    expectFullDate(tester, 'start', record.startDate.toString());
    expectFullDate(tester, 'due', record.dueDate.toString());
    await capture(tester, 'locked-dates-320-2x');
    await select(tester, 'currency', 'CNY');
    await fill(tester, 'amount', '0');
    await save(tester);
    final saved = (await store.servers()).single;
    expect(saved.amountMinor, 0);
    expect(saved.currency, 'CNY');
    expect(saved.startDate, record.startDate);
    expect(saved.dueDate, record.dueDate);
    expect(saved.cycleMonths, record.cycleMonths);
    expect(saved.billing, record.billing);
    expect(
      (await store.payments()).map((p) => p.toMap()).toList(),
      beforePayments,
    );
    expect(
      (await store.servicePeriods()).map((p) => p.toMap()).toList(),
      beforePeriods,
    );
    expect(tester.takeException(), isNull);
  });
}
