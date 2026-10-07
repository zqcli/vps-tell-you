import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_form.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

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

  Future<void> select<T>(WidgetTester tester, String id, T value) async {
    await reveal(tester, field(id));
    final dropdown = tester.widget<DropdownButton<T>>(
      find.descendant(of: field(id), matching: find.byType(DropdownButton<T>)),
    );
    final option = dropdown.items!.singleWhere((item) => item.value == value);
    await tester.tap(field(id));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidget(option.child).last);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('保存服务器'));
    await tester.pumpAndSettle();
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
    final input = tester.widget<TextFormField>(field(id));
    expect(input.controller!.text, expected);
    expect(input.controller!.text, isNot(contains('\n')));
    final editor = find.descendant(
      of: field(id),
      matching: find.byType(EditableText),
    );
    final render = tester.state<EditableTextState>(editor).renderEditable;
    for (var offset = 0; offset < expected.length; offset++) {
      final boxes = render.getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + 1),
      );
      expect(boxes, isNotEmpty);
      for (final box in boxes) {
        expect(box.left, greaterThanOrEqualTo(-0.01));
        expect(box.right, lessThanOrEqualTo(render.size.width + 0.01));
        expect(box.top, greaterThanOrEqualTo(-0.01));
        expect(box.bottom, lessThanOrEqualTo(render.size.height + 0.01));
      }
    }
    // Flutter snaps the caret to physical pixels after computing text metrics.
    // The glyph boxes above remain strict; only this raster alignment may add
    // up to one physical pixel at the editable's edge.
    final rasterTolerance = 1 / tester.view.devicePixelRatio + 0.01;
    for (var offset = 0; offset <= expected.length; offset++) {
      final caret = render.getLocalRectForCaret(TextPosition(offset: offset));
      expect(caret.left, greaterThanOrEqualTo(-0.01));
      expect(caret.right, lessThanOrEqualTo(render.size.width + 2.01));
      expect(caret.top, greaterThanOrEqualTo(-rasterTolerance));
      expect(
        caret.bottom,
        lessThanOrEqualTo(render.size.height + rasterTolerance),
      );
    }
  }

  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets('complete ISO dates survive a doubled-text row at $width', (
      tester,
    ) async {
      await mount(tester, width: width);
      await reveal(tester, find.byKey(const ValueKey('row-fees')));
      await capture(tester, 'fee-row-${width.toInt()}-2x');
      await reveal(tester, find.byKey(const ValueKey('row-dates')));
      await tester.pumpAndSettle();
      final start = tester.getRect(field('start'));
      final due = tester.getRect(field('due'));
      expect(start.top, closeTo(due.top, 0.01));
      expect(start.right, lessThan(due.left));
      expect(due.right, lessThanOrEqualTo(width - 20));
      expectFullDate(tester, 'start', '2024-02-29');
      expectFullDate(tester, 'due', '2027-01-01');
      await capture(tester, 'complete-dates-${width.toInt()}-2x');
      for (final entry in {
        'amount': '金额',
        'currency': '币种',
        'cycle': '周期',
      }.entries) {
        final label = find.descendant(
          of: field(entry.key),
          matching: find.text(entry.value),
        );
        expect(
          tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
          isFalse,
          reason: '${entry.value} must remain fully readable at $width / 2x',
        );
      }
      await save(tester);
      final saved = (await store.servers()).single;
      expect(saved.startDate, record.startDate);
      expect(saved.dueDate, record.dueDate);
      expect(saved.amountMinor, record.amountMinor);
      expect(saved.resources!.toJson(), record.resources!.toJson());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('date reflow and next action preserve exact edits and cursor', (
    tester,
  ) async {
    final scale = ValueNotifier<double>(1);
    addTearDown(scale.dispose);
    await mount(tester, width: 390, scale: scale);
    await fill(tester, 'amount', '9999999999.99');
    await fill(tester, 'start', '2026-10-06');
    await fill(tester, 'due', '2028-02-29');
    final controller = tester.widget<TextFormField>(field('start')).controller!;
    controller.selection = const TextSelection.collapsed(offset: 7);
    tester.view.physicalSize = const Size(320, 844);
    scale.value = 2;
    await tester.pumpAndSettle();
    await reveal(tester, field('start'));
    expect(
      tester.widget<TextFormField>(field('start')).controller,
      same(controller),
    );
    expect(controller.selection.baseOffset, 7);
    expectFullDate(tester, 'start', '2026-10-06');
    expectFullDate(tester, 'due', '2028-02-29');
    await tester.showKeyboard(field('start'));
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    final dueEditor = tester.widget<EditableText>(
      find.descendant(of: field('due'), matching: find.byType(EditableText)),
    );
    expect(dueEditor.focusNode.hasFocus, isTrue);
    expect(controller.text, '2026-10-06');
    FocusManager.instance.primaryFocus?.unfocus();
    await save(tester);
    final saved = (await store.servers()).single;
    expect(saved.startDate, const LedgerDate(2026, 10, 6));
    expect(saved.dueDate, const LedgerDate(2028, 2, 29));
    expect(saved.amountMinor, Money.maxMinor);
    expect(saved.currency, 'EUR');
    expect(saved.resources!.toJson(), record.resources!.toJson());
    expect(tester.takeException(), isNull);
  });

  testWidgets('full-width row errors retain field identity and semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await mount(tester);
      await fill(tester, 'amount', '1.234');
      await fill(tester, 'start', '2026-02-29');
      await fill(tester, 'due', '2027-13-01');
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
      await save(tester);
      expect(field('start').hitTestable(), findsOneWidget);
      expect(find.text('开始日期：'), findsOneWidget);
      expect(find.text('结束日期：'), findsOneWidget);
      final dateErrors = find.text('请使用有效日期，例如 2026-10-06');
      expect(dateErrors, findsNWidgets(2));
      for (final error in dateErrors.evaluate()) {
        expect(
          (error.renderObject! as RenderParagraph).didExceedMaxLines,
          isFalse,
        );
      }
      for (final id in ['start', 'due']) {
        await reveal(tester, field(id));
        await tester.pumpAndSettle();
        node = tester.getSemantics(field(id));
        expect(node.label, contains(id == 'start' ? '服务开始日（选填）' : '服务到期日（选填）'));
        expect(node.hint, contains('请使用有效日期，例如 2026-10-06'));
        expect(node.validationResult, ui.SemanticsValidationResult.invalid);
      }
      await capture(tester, 'both-date-errors-320-2x');
      await fill(tester, 'start', '2026-10-06');
      await fill(tester, 'due', '2026-10-06');
      await save(tester);
      expect(find.text('开始日期：'), findsNothing);
      expect(find.text('结束日期：'), findsOneWidget);
      expect(find.text('到期日必须晚于开始日').hitTestable(), findsOneWidget);
      node = tester.getSemantics(field('start'));
      expect(node.validationResult, ui.SemanticsValidationResult.valid);
      expect(node.hint, isNot(contains('请使用有效日期')));
      await fill(tester, 'due', '2027-01-01');
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

  testWidgets('all compact payment periods retain their full spoken meaning', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await mount(tester);
      for (final months in [1, 3, 6, 12, 24, 36]) {
        await select(tester, 'cycle', months);
        final node = tester.getSemantics(field('cycle'));
        expect(node.label, contains('付款周期'));
        expect(node.label, contains(months == 12 ? '每年' : '每 $months 个月'));
        final amountRect = tester.getRect(field('amount'));
        final currencyRect = tester.getRect(field('currency'));
        final cycleRect = tester.getRect(field('cycle'));
        expect(amountRect.top, closeTo(currencyRect.top, 0.01));
        expect(currencyRect.top, closeTo(cycleRect.top, 0.01));
        expect(amountRect.right, lessThan(currencyRect.left));
        expect(currencyRect.right, lessThan(cycleRect.left));
        expect(cycleRect.right, lessThanOrEqualTo(300));
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
    await fill(tester, 'start', 'not-a-date');
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
    await fill(tester, 'start', '');
    await fill(tester, 'due', '');
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
    expect(
      tester
          .widget<DropdownButtonFormField<BillingKind>>(field('billing'))
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<DropdownButton<int>>(
            find.descendant(
              of: field('cycle'),
              matching: find.byType(DropdownButton<int>),
            ),
          )
          .onChanged,
      isNull,
    );
    for (final id in ['start', 'due']) {
      expect(tester.widget<TextFormField>(field(id)).enabled, isFalse);
    }
    await reveal(tester, field('start'));
    await tester.pumpAndSettle();
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
