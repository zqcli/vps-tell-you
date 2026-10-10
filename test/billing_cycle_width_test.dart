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

import 'support/form_test_helpers.dart';

void main() {
  final evidence = Platform.environment['VPS_CYCLE_WIDTH_EVIDENCE_DIR'];
  var fontsLoaded = false;
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late ServerRecord record;
  final now = DateTime.utc(2026, 10, 7, 12);

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('billing-cycle-width-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
      clock: () => now,
    );
    record = ServerRecord(
      id: 'cycle-width-fixture',
      name: '合成测试服务器',
      vendor: '合成测试厂商',
      billing: BillingKind.prepaid,
      currency: 'USD',
      amountMinor: 1250,
      cycleMonths: 12,
      startDate: const LedgerDate(2026, 1, 1),
      dueDate: const LedgerDate(2027, 1, 1),
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

  Future<void> reveal(WidgetTester tester) async {
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('row-fees'))),
      alignment: 0.12,
    );
    await tester.pumpAndSettle();
  }

  Future<void> mount(
    WidgetTester tester, {
    double width = 390,
    double height = 844,
    double scale = 1,
    ValueNotifier<double>? textScale,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scaleListenable = textScale ?? ValueNotifier<double>(scale);
    if (textScale == null) addTearDown(scaleListenable.dispose);
    if (evidence != null && !fontsLoaded) {
      await tester.runAsync(() async {
        final font = FontLoader('Cycle width Noto');
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
    final theme = appTheme(brightness: brightness);
    await tester.pumpWidget(
      MaterialApp(
        theme: evidence == null
            ? theme
            : theme.copyWith(
                textTheme: theme.textTheme.apply(
                  fontFamily: 'Cycle width Noto',
                ),
                appBarTheme: theme.appBarTheme.copyWith(
                  titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
                    fontFamily: 'Cycle width Noto',
                  ),
                ),
              ),
        builder: (context, child) => ValueListenableBuilder<double>(
          valueListenable: scaleListenable,
          child: RepaintBoundary(
            key: const ValueKey('cycle-width-evidence'),
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
                    builder: (_) =>
                        ServerForm(controller: ledger, record: record),
                  ),
                ),
                child: const Text('Open cycle width review'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open cycle width review'));
    await tester.pumpAndSettle();
    await reveal(tester);
  }

  void expectCompleteText(
    WidgetTester tester,
    Finder finder,
    String text, {
    Rect? within,
    bool floatingLabel = false,
  }) {
    expect(finder, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(finder);
    expect(paragraph.text.toPlainText(), text);
    expect(paragraph.didExceedMaxLines, isFalse);
    // Selection boxes include half the trailing letter spacing beyond the
    // paragraph's logical width. Keep that exact typographic allowance; the
    // enclosing control bounds below remain strict.
    final selectionOverhang =
        (paragraph.text.style?.letterSpacing ?? 0).abs() / 2;
    for (var offset = 0; offset < text.length; offset++) {
      if (text[offset].trim().isEmpty) continue;
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + 1),
      );
      expect(boxes, isNotEmpty, reason: 'Missing glyph $offset in $text');
      for (final box in boxes) {
        expect(box.left, greaterThanOrEqualTo(-0.01));
        expect(
          box.right,
          lessThanOrEqualTo(paragraph.size.width + selectionOverhang + 0.01),
        );
        // Material intentionally gives floating labels a height of 1, so
        // Noto's font-metric selection box extends above and below that line
        // without clipping the glyphs. Width/ellipsis checks still apply to
        // labels; selected values and popup text retain strict vertical bounds.
        if (!floatingLabel) {
          expect(box.top, greaterThanOrEqualTo(-0.01));
          expect(box.bottom, lessThanOrEqualTo(paragraph.size.height + 0.01));
        }
        if (within != null) {
          final left = paragraph.localToGlobal(Offset(box.left, box.top)).dx;
          final right = paragraph.localToGlobal(Offset(box.right, box.top)).dx;
          expect(left, greaterThanOrEqualTo(within.left - 0.01));
          expect(right, lessThanOrEqualTo(within.right + 0.01));
        }
      }
    }
  }

  Future<void> select<T>(WidgetTester tester, String id, T value) async {
    final title = value is int
        ? (value == 12 ? '每年' : '每 $value 个月')
        : value.toString();
    await chooseOption(tester, field(id), title);
  }

  /// Amount, currency and cycle each keep their complete text inside the
  /// grouped rows without overflowing the screen.
  void expectFeeRows(WidgetTester tester, double width, String cycleText) {
    final amount = tester.getRect(field('amount'));
    final currency = tester.getRect(field('currency'));
    final cycle = tester.getRect(field('cycle'));
    expect(amount.top, closeTo(currency.top, 12));
    expect(amount.right, lessThan(currency.left));
    expect(cycle.top, greaterThan(amount.bottom - 1));
    for (final rect in [currency, cycle]) {
      expect(rect.right, lessThanOrEqualTo(width + 0.01));
      expect(rect.height, greaterThanOrEqualTo(44));
    }
    expect(amount.left, greaterThanOrEqualTo(16));
    expect(amount.width, greaterThanOrEqualTo(48));
    final value = find.descendant(
      of: field('cycle'),
      matching: find.text(cycleText),
    );
    expectCompleteText(tester, value, cycleText, within: cycle);
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (evidence == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('cycle-width-evidence')),
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

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('cycle contents remain complete at $width px / $scale text', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          await mount(tester, width: width, scale: scale);
          for (final months in [1, 3, 6, 12, 24, 36]) {
            await select(tester, 'cycle', months);
            await reveal(tester);
            expectFeeRows(tester, width, months == 12 ? '每年' : '每 $months 个月');
            final spoken = tester.getSemantics(field('cycle')).label;
            expect(spoken, contains('续费周期'));
            expect(spoken, contains(months == 12 ? '每年' : '每 $months 个月'));
            if (months == 12 || months == 6) {
              await capture(
                tester,
                'cycle-$months-${width.toInt()}-${scale.toInt()}x',
              );
            }
          }
          await tapSave(tester);
          final saved = (await store.servers()).single;
          expect(saved.cycleMonths, 36);
          expect(saved.amountMinor, 1250);
          expect(saved.currency, 'USD');
          expect(saved.startDate, record.startDate);
          expect(saved.dueDate, record.dueDate);
          expect(await store.payments(), isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
  }

  testWidgets('resizing and text scaling preserve edits with every currency', (
    tester,
  ) async {
    final scale = ValueNotifier<double>(1);
    addTearDown(scale.dispose);
    await mount(tester, textScale: scale, brightness: Brightness.dark);
    final amount = fieldController(tester, 'field-amount');
    await tester.enterText(field('amount'), '9999999999.99');
    amount.selection = const TextSelection.collapsed(offset: 7);
    FocusManager.instance.primaryFocus?.unfocus();
    await select(tester, 'cycle', 6);
    tester.view.physicalSize = const Size(320, 844);
    scale.value = 2;
    await tester.pumpAndSettle();
    await reveal(tester);
    expect(fieldController(tester, 'field-amount'), same(amount));
    expect(amount.text, '9999999999.99');
    expect(amount.selection.baseOffset, 7);
    for (final currency in Money.currencies) {
      await select(tester, 'currency', currency);
      expectFeeRows(tester, 320, '每 6 个月');
      expectCompleteText(
        tester,
        find.descendant(of: field('currency'), matching: find.text(currency)),
        currency,
        within: tester.getRect(field('currency')),
      );
      expect(find.textContaining('9999999999.99 $currency'), findsOneWidget);
    }
    await capture(tester, 'cycle-resized-dark-320-2x');
    await tapSave(tester);
    final saved = (await store.servers()).single;
    expect(saved.cycleMonths, 6);
    expect(saved.amountMinor, Money.maxMinor);
    expect(saved.currency, Money.currencies.last);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all full period names stay reachable on a small doubled-text view',
    (tester) async {
      await mount(tester, width: 320, height: 560, scale: 2);
      await tester.tap(field('cycle'));
      await tester.pumpAndSettle();
      for (final months in [1, 3, 6, 12, 24, 36]) {
        final name = months == 12 ? '每年' : '每 $months 个月';
        final option = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(name),
        );
        await tester.ensureVisible(option);
        await tester.pumpAndSettle();
        expect(option.hitTestable(), findsOneWidget);
        expectCompleteText(tester, option, name);
      }
      await capture(tester, 'cycle-menu-320-560-2x');
      await tester.tap(find.byKey(const ValueKey('app-sheet-close')));
      await tester.pumpAndSettle();
      expectFeeRows(tester, 320, '每年');
      expect((await store.servers()).single.cycleMonths, 12);
      await select(tester, 'cycle', 36);
      expectFeeRows(tester, 320, '每 36 个月');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cycle row is a full-height touch target that opens the picker', (
    tester,
  ) async {
    await mount(tester);
    final rect = tester.getRect(field('cycle'));
    expect(rect.height, greaterThanOrEqualTo(48));
    await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
    await tester.pumpAndSettle();
    expect(find.text('每 36 个月').hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-sheet-close')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect((await store.servers()).single.cycleMonths, 12);
  });

  testWidgets('legacy period stays literal and is never silently normalized', (
    tester,
  ) async {
    record = ServerRecord.fromMap({...record.toMap(), 'cycle_months': 18});
    await mount(tester, width: 320, scale: 2);
    expectFeeRows(tester, 320, '每 18 个月');
    expect(find.textContaining('每 18 个月续费金额'), findsOneWidget);
    expect(record.cycleMonths, 18);
    await capture(tester, 'cycle-legacy-18-320-2x');
    await select(tester, 'cycle', 3);
    expectFeeRows(tester, 320, '每 3 个月');
    await tapSave(tester);
    expect((await store.servers()).single.cycleMonths, 3);
    expect(await store.payments(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked cycle keeps its layout and immutable paid history', (
    tester,
  ) async {
    await store.recordPayment(
      id: 'cycle-width-payment',
      server: record,
      amount: const Money('USD', 1250),
      paidDate: const LedgerDate(2026, 10, 7),
      cycleCount: 1,
      until: const LedgerDate(2028, 1, 1),
      confirmed: true,
    );
    await ledger.refresh();
    record = ledger.byId(record.id)!;
    final payments = (await store.payments()).map((p) => p.toMap()).toList();
    final periods = (await store.servicePeriods())
        .map((p) => p.toMap())
        .toList();
    await mount(tester, width: 320, scale: 2);
    expectFeeRows(tester, 320, '每年');
    await tester.tap(field('cycle'));
    await tester.pumpAndSettle();
    // No picker opens for locked terms; the lock is explained instead.
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('每 36 个月'), findsNothing);
    await tester.enterText(field('amount'), '0');
    FocusManager.instance.primaryFocus?.unfocus();
    await tapSave(tester);
    expect((await store.servers()).single.cycleMonths, 12);
    expect((await store.payments()).map((p) => p.toMap()).toList(), payments);
    expect(
      (await store.servicePeriods()).map((p) => p.toMap()).toList(),
      periods,
    );
    expect(tester.takeException(), isNull);
  });
}
