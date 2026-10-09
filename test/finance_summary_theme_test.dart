import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/app.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/finance/finance_page.dart';
import 'package:vps_tell_you/finance/finance_widgets.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'support/reminder_platform.dart';

double _contrast(Color first, Color second) {
  double luminance(Color color) {
    double linear(double channel) => channel <= .04045
        ? channel / 12.92
        : math.pow((channel + .055) / 1.055, 2.4).toDouble();
    return .2126 * linear(color.r) +
        .7152 * linear(color.g) +
        .0722 * linear(color.b);
  }

  final a = luminance(first), b = luminance(second);
  return (math.max(a, b) + .05) / (math.min(a, b) + .05);
}

void main() {
  final now = DateTime(2026, 10, 7, 12);
  final summary = find.byKey(const ValueKey('finance-summary'));
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  var fontsLoaded = false;

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('finance-summary-');
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
    await ledger.refresh();
  });

  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> seed() async {
    for (final item in [
      ('cny', 'CNY', 120000, BillingKind.prepaid),
      ('eur', 'EUR', 2400, BillingKind.prepaid),
      ('metered', 'CNY', 2800, BillingKind.metered),
      ('unknown', 'CNY', null, BillingKind.unknown),
    ]) {
      await store.saveServer(
        ServerRecord(
          id: item.$1,
          name: 'Synthetic ${item.$1}',
          vendor: 'Synthetic provider',
          host: '192.0.2.10',
          billing: item.$4,
          currency: item.$2,
          amountMinor: item.$3,
          cycleMonths: 12,
          startDate: const LedgerDate(2026, 1, 1),
          dueDate: const LedgerDate(2027, 1, 1),
          createdAt: now,
          updatedAt: now,
        ),
        isNew: true,
      );
    }
    await ledger.refresh();
  }

  Future<void> mount(
    WidgetTester tester, {
    required String language,
    required Brightness brightness,
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (!fontsLoaded) {
      await tester.runAsync(() async {
        final font = FontLoader('Finance summary review');
        font.addFont(
          File(
            Platform.environment['VPS_I18N_FONT'] ??
                'assets/fonts/DejaVuSansMono.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        );
        await font.load();
        if (Platform.environment['FLUTTER_BOOTSTRAP_ROOT'] case final sdk?) {
          final icons = FontLoader('MaterialIcons');
          icons.addFont(
            File(
              '$sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes().then(ByteData.sublistView),
          );
          await icons.load();
        }
        fontsLoaded = true;
      });
    }
    final base = appTheme(brightness: brightness);
    await tester.pumpWidget(
      MaterialApp(
        theme: base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: 'Finance summary review'),
        ),
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: const ValueKey('finance-summary-evidence'),
            child: child,
          ),
        ),
        home: HomeShell(controller: ledger),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
    }
    await tester.scrollUntilVisible(
      target,
      180,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 50,
    );
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final output = Platform.environment['VPS_FINANCE_SUMMARY_EVIDENCE_DIR'];
    if (output == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('finance-summary-evidence')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$output/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<Color> backgroundPixel(WidgetTester tester, Finder target) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('finance-summary-evidence')),
    );
    final position = boundary.globalToLocal(
      tester.getTopRight(target) + const Offset(-2, 3),
    );
    return (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final offset =
          (position.dy.floor() * image.width + position.dx.floor()) * 4;
      final color = Color.fromARGB(
        bytes.getUint8(offset + 3),
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      );
      image.dispose();
      return color;
    }))!;
  }

  /// The summary is a gradient card with white text: every text must stay
  /// readable against the lightest stop of its gradient.
  void checkColors(WidgetTester tester) {
    final decoration =
        tester.widget<DecoratedBox>(summary).decoration as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    expect(decoration.border, isNull);
    final totals = tester.widgetList<FinanceTotalView>(
      find.descendant(of: summary, matching: find.byType(FinanceTotalView)),
    );
    expect(totals.map((total) => total.layout), [
      FinanceTotalLayout.hero,
      FinanceTotalLayout.tile,
      FinanceTotalLayout.tile,
    ]);
    for (final element
        in find
            .descendant(of: summary, matching: find.byType(Text))
            .evaluate()) {
      final widget = element.widget as Text;
      final style = DefaultTextStyle.of(element).style.merge(widget.style);
      for (final stop in gradient.colors) {
        expect(
          _contrast(style.color!, stop),
          greaterThanOrEqualTo(4.5),
          reason: widget.data,
        );
      }
      expect(widget.maxLines, isNull);
      expect(widget.overflow, isNull);
    }
  }

  for (final language in ['zh', 'en']) {
    for (final brightness in Brightness.values) {
      for (final size in [(390.0, 1.0), (320.0, 2.0)]) {
        testWidgets(
          '$language ${brightness.name} summary is legible at ${size.$1}px/${size.$2}x',
          (tester) async {
            await seed();
            final before = (await store.exportLedgerBackup()).encode();
            await mount(
              tester,
              language: language,
              brightness: brightness,
              width: size.$1,
              scale: size.$2,
            );
            final prefix = '$language-${brightness.name}-${size.$1.toInt()}';
            if (size.$2 == 1) await capture(tester, '$prefix-overview');
            final monthly = find.byKey(const ValueKey('metric-monthly'));
            await reveal(tester, monthly);
            checkColors(tester);
            final total = tester
                .widget<FinanceTotalView>(
                  find.descendant(
                    of: monthly,
                    matching: find.byType(FinanceTotalView),
                  ),
                )
                .total;
            expect(total.formatted, '¥128.00');
            expect(total.covered, 2);
            expect(total.total, 4);
            expect(total.missingFx, 1);
            expect(total.unknown, 1);
            final l10n = AppLocalizations.of(tester.element(summary));
            final inventory = find.byKey(const ValueKey('finance-inventory'));
            await reveal(tester, inventory);
            expect(
              find.descendant(
                of: inventory,
                matching: find.text(l10n.uiFinanceServerCount(4)),
              ),
              findsOneWidget,
            );
            await reveal(tester, monthly);
            await capture(tester, '$prefix-monthly');
            final value = find.byKey(const ValueKey('metric-value'));
            await reveal(tester, value);
            final remaining = tester
                .widget<FinanceTotalView>(
                  find.descendant(
                    of: value,
                    matching: find.byType(FinanceTotalView),
                  ),
                )
                .total;
            expect(remaining.covered, 1);
            expect(remaining.unknown, 1);
            expect(remaining.notApplicable, 1);
            expect(remaining.missingFx, 1);
            await capture(tester, '$prefix-value');

            for (final destination in [
              (monthly, FinanceMetric.monthly),
              (value, FinanceMetric.value),
              (inventory, FinanceMetric.inventory),
            ]) {
              await reveal(tester, destination.$1);
              await tester.tap(destination.$1);
              await tester.pumpAndSettle();
              expect(
                tester
                    .widget<FinanceDetailPage>(find.byType(FinanceDetailPage))
                    .metric,
                destination.$2,
              );
              final back = find
                  .byKey(const ValueKey('app-nav-back'))
                  .hitTestable();
              expect(back, findsOneWidget);
              await tester.tap(back);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
            expect((await store.exportLedgerBackup()).encode(), before);
          },
        );
      }
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name} summary interaction layers keep contrast', (
      tester,
    ) async {
      await seed();
      await mount(tester, language: 'en', brightness: brightness);
      final previous = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = previous);

      for (final key in ['metric-monthly', 'metric-value']) {
        final target = find.byKey(ValueKey(key));
        await reveal(tester, target);
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: Offset.zero);
        Focus.of(
          tester.element(
            find.descendant(
              of: target,
              matching: find.byType(FinanceTotalView),
            ),
          ),
        ).requestFocus();
        await mouse.moveTo(tester.getCenter(target));
        await tester.pumpAndSettle();
        final focused = await backgroundPixel(tester, target);
        // White text on the gradient (plus hover / focus layers) stays legible.
        expect(_contrast(Colors.white, focused), greaterThanOrEqualTo(4.5));
        await capture(tester, '${brightness.name}-$key-focused-hovered');

        await mouse.down(tester.getCenter(target));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        final pressed = await backgroundPixel(tester, target);
        expect(_contrast(Colors.white, pressed), greaterThanOrEqualTo(4.5));
        await capture(tester, '${brightness.name}-$key-pressed');
        await mouse.cancel();
        await mouse.removePointer();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(find.byType(FinanceDetailPage), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('${brightness.name} empty summary uses the same theme roles', (
      tester,
    ) async {
      await mount(tester, language: 'en', brightness: brightness);
      await reveal(tester, find.byKey(const ValueKey('metric-monthly')));
      checkColors(tester);
      final totals = tester.widgetList<FinanceTotalView>(
        find.descendant(of: summary, matching: find.byType(FinanceTotalView)),
      );
      for (final total in totals) {
        expect(total.total.total, 0);
        expect(total.total.unknown, 0);
        expect(total.total.missingFx, 0);
      }
      await capture(tester, 'en-${brightness.name}-empty');
    });
  }
}
