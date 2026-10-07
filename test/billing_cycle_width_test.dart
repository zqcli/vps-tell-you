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

void main() {
  final evidence = Platform.environment['VPS_CYCLE_WIDTH_EVIDENCE_DIR'];
  var fontsLoaded = false;
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late ServerRecord record;
  final now = DateTime.utc(2026, 10, 7, 12);
  const labels = {1: '月', 3: '季', 6: '半年', 12: '年', 24: '2年', 36: '3年'};

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
  Finder cycleButton() => find.descendant(
    of: field('cycle'),
    matching: find.byType(DropdownButton<int>),
  );

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

  void expectFeeRow(WidgetTester tester, double width, String cycleLabel) {
    final amount = tester.getRect(field('amount'));
    final currency = tester.getRect(field('currency'));
    final cycle = tester.getRect(field('cycle'));
    expect(amount.top, closeTo(currency.top, 0.01));
    expect(currency.top, closeTo(cycle.top, 0.01));
    expect(amount.right + 6, closeTo(currency.left, 0.01));
    expect(currency.right + 6, closeTo(cycle.left, 0.01));
    expect(amount.left, greaterThanOrEqualTo(20));
    expect(cycle.right, lessThanOrEqualTo(width - 20 + 0.01));
    for (final rect in [amount, currency, cycle]) {
      expect(rect.width, greaterThanOrEqualTo(48));
      expect(rect.height, greaterThanOrEqualTo(48));
    }
    for (final entry in {
      'amount': '金额',
      'currency': '币种',
      'cycle': '周期',
    }.entries) {
      expectCompleteText(
        tester,
        find.descendant(of: field(entry.key), matching: find.text(entry.value)),
        entry.value,
        within: tester.getRect(field(entry.key)),
        floatingLabel: true,
      );
    }
    expectCompleteText(
      tester,
      find.descendant(of: field('cycle'), matching: find.text(cycleLabel)),
      cycleLabel,
      within: cycle,
    );
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

  Future<void> select<T>(WidgetTester tester, String id, T value) async {
    await Scrollable.ensureVisible(tester.element(field(id)), alignment: 0.12);
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButton<T>>(
      find.descendant(of: field(id), matching: find.byType(DropdownButton<T>)),
    );
    final option = dropdown.items!.singleWhere((item) => item.value == value);
    await tester.tap(field(id));
    await tester.pumpAndSettle();
    final label = (option.child as Text).data!;
    final matchingText = find.text(label);
    // Long labels make the small-screen menu scroll. Its last options may
    // not have an element until the popup's own scrollable reaches them.
    if (matchingText.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        matchingText,
        100,
        scrollable: find.byType(Scrollable).last,
      );
    }
    final menuText = matchingText.last;
    await tester.ensureVisible(menuText);
    await tester.pumpAndSettle();
    expect(menuText.hitTestable(), findsOneWidget);
    expectCompleteText(tester, menuText, label);
    await tester.tap(menuText);
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('cycle contents remain complete at $width px / $scale text', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          await mount(tester, width: width, scale: scale);
          for (final entry in labels.entries) {
            await select(tester, 'cycle', entry.key);
            await reveal(tester);
            expectFeeRow(tester, width, entry.value);
            final spoken = tester.getSemantics(field('cycle')).label;
            expect(spoken, contains('续费周期'));
            expect(
              spoken,
              contains(entry.key == 12 ? '每年' : '每 ${entry.key} 个月'),
            );
            if (entry.key == 12 || entry.key == 6) {
              await capture(
                tester,
                'cycle-${entry.key}-${width.toInt()}-${scale.toInt()}x',
              );
            }
          }
          await tester.tap(find.text('保存服务器'));
          await tester.pumpAndSettle();
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

  testWidgets(
    'cycle sizes to its selection while amount receives extra space',
    (tester) async {
      await mount(tester);
      final yearWidth = tester.getSize(field('cycle')).width;
      final amountWidth = tester.getSize(field('amount')).width;
      expect(yearWidth, lessThan(80));
      expect(amountWidth, greaterThan(yearWidth));
      await select(tester, 'cycle', 6);
      final halfYearWidth = tester.getSize(field('cycle')).width;
      expect(halfYearWidth, greaterThan(yearWidth));
      expect(halfYearWidth, lessThan(100));
      expect(
        tester.getSize(field('amount')).width,
        closeTo(amountWidth - (halfYearWidth - yearWidth), 0.01),
      );
      tester.view.physicalSize = const Size(760, 844);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(field('cycle')).width,
        closeTo(halfYearWidth, 0.01),
      );
      await select(tester, 'cycle', 12);
      expect(tester.getSize(field('cycle')).width, closeTo(yearWidth, 0.01));
      expect(
        tester.getSize(field('amount')).width,
        closeTo(amountWidth + 370, 0.01),
      );
      expectFeeRow(tester, 760, '年');
    },
  );

  testWidgets('resizing and text scaling preserve edits with every currency', (
    tester,
  ) async {
    final scale = ValueNotifier<double>(1);
    addTearDown(scale.dispose);
    await mount(tester, textScale: scale, brightness: Brightness.dark);
    final amount = tester.widget<TextFormField>(field('amount')).controller!;
    await tester.enterText(field('amount'), '9999999999.99');
    amount.selection = const TextSelection.collapsed(offset: 7);
    FocusManager.instance.primaryFocus?.unfocus();
    await select(tester, 'cycle', 6);
    final initialWidth = tester.getSize(field('cycle')).width;
    tester.view.physicalSize = const Size(320, 844);
    scale.value = 2;
    await tester.pumpAndSettle();
    await reveal(tester);
    expect(
      tester.widget<TextFormField>(field('amount')).controller,
      same(amount),
    );
    expect(amount.text, '9999999999.99');
    expect(amount.selection.baseOffset, 7);
    expect(tester.getSize(field('cycle')).width, greaterThan(initialWidth));
    for (final currency in Money.currencies) {
      await select(tester, 'currency', currency);
      expectFeeRow(tester, 320, '半年');
      expectCompleteText(
        tester,
        find.descendant(of: field('currency'), matching: find.text(currency)),
        currency,
        within: tester.getRect(field('currency')),
      );
      expect(find.textContaining('9999999999.99 $currency'), findsOneWidget);
    }
    await capture(tester, 'cycle-resized-dark-320-2x');
    await tester.tap(find.text('保存服务器'));
    await tester.pumpAndSettle();
    final saved = (await store.servers()).single;
    expect(saved.cycleMonths, 6);
    expect(saved.amountMinor, Money.maxMinor);
    expect(saved.currency, Money.currencies.last);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all full menu names stay reachable on a small doubled-text view',
    (tester) async {
      await mount(tester, width: 320, height: 560, scale: 2);
      await tester.tap(field('cycle'));
      await tester.pumpAndSettle();
      for (final months in [1, 3, 6, 12, 24, 36]) {
        final name = months == 12 ? '每年' : '每 $months 个月';
        final option = find.text(name).last;
        await tester.ensureVisible(option);
        await tester.pumpAndSettle();
        expect(option.hitTestable(), findsOneWidget);
        expectCompleteText(tester, option, name);
        expect(
          tester
              .renderObject<RenderParagraph>(option)
              .getBoxesForSelection(
                TextSelection(baseOffset: 0, extentOffset: name.length),
              ),
          hasLength(1),
          reason:
              'The popup must give each standard period a full readable line',
        );
      }
      await capture(tester, 'cycle-menu-320-560-2x');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expectFeeRow(tester, 320, '年');
      expect((await store.servers()).single.cycleMonths, 12);
      await select(tester, 'cycle', 36);
      expectFeeRow(tester, 320, '3年');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cycle retains focus styling and a full padded touch target', (
    tester,
  ) async {
    await mount(tester);
    final dropdown = tester.widget<DropdownButton<int>>(cycleButton());
    final buttonRect = tester.getRect(cycleButton());
    expect(buttonRect.width, greaterThanOrEqualTo(48));
    expect(buttonRect.height, greaterThanOrEqualTo(48));
    expect(
      dropdown.menuWidth!,
      greaterThan(tester.getSize(field('cycle')).width),
    );
    dropdown.focusNode!.requestFocus();
    await tester.pumpAndSettle();
    expect(tester.widget<InputDecorator>(field('cycle')).isFocused, isTrue);
    await tester.tapAt(Offset(buttonRect.center.dx, buttonRect.top + 2));
    await tester.pumpAndSettle();
    expect(find.text('每 36 个月').hitTestable(), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<DropdownButton<int>>(cycleButton()).value, 12);
    expect(tester.widget<InputDecorator>(field('cycle')).isFocused, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy period stays literal and is never silently normalized', (
    tester,
  ) async {
    record = ServerRecord.fromMap({...record.toMap(), 'cycle_months': 18});
    await mount(tester, width: 320, scale: 2);
    expectFeeRow(tester, 320, '18个月');
    final dropdown = tester.widget<DropdownButton<int>>(cycleButton());
    expect(dropdown.value, 18);
    expect(find.textContaining('每 18 个月续费金额'), findsOneWidget);
    expect(record.cycleMonths, 18);
    await capture(tester, 'cycle-legacy-18-320-2x');
    await select(tester, 'cycle', 3);
    expectFeeRow(tester, 320, '季');
    await tester.tap(find.text('保存服务器'));
    await tester.pumpAndSettle();
    expect((await store.servers()).single.cycleMonths, 3);
    expect(await store.payments(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'locked cycle keeps compact geometry and immutable paid history',
    (tester) async {
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
      expectFeeRow(tester, 320, '年');
      expect(
        tester.widget<DropdownButton<int>>(cycleButton()).onChanged,
        isNull,
      );
      await tester.tap(field('cycle'));
      await tester.pumpAndSettle();
      expect(find.text('每 36 个月'), findsNothing);
      expect(tester.getSize(field('cycle')).width, lessThan(90));
      await tester.enterText(field('amount'), '0');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.text('保存服务器'));
      await tester.pumpAndSettle();
      expect((await store.servers()).single.cycleMonths, 12);
      expect((await store.payments()).map((p) => p.toMap()).toList(), payments);
      expect(
        (await store.servicePeriods()).map((p) => p.toMap()).toList(),
        periods,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
