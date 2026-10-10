import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/app.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/finance/calculation_share.dart';
import 'package:vps_tell_you/finance/calculator_page.dart';
import 'package:vps_tell_you/finance/finance_page.dart';
import 'package:vps_tell_you/finance/finance_widgets.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'support/reminder_platform.dart';

void main() {
  final now = DateTime(2026, 10, 7, 12);
  final en = AppLocalizationsEn(), zh = AppLocalizationsZh();
  final entry = find.byKey(const ValueKey('finance-calculator-entry'));
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late ValueNotifier<Locale> locale;
  var fontsLoaded = false;

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('finance-entry-');
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
    locale = ValueNotifier(const Locale('en'));
  });
  tearDown(() async {
    locale.dispose();
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester, {
    double width = 390,
    double scale = 1,
    Brightness brightness = Brightness.light,
    bool reviewFont = false,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (reviewFont && !fontsLoaded) {
      await tester.runAsync(() async {
        final font = FontLoader('Finance entry review');
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
    final theme = reviewFont
        ? base.copyWith(
            textTheme: base.textTheme.apply(fontFamily: 'Finance entry review'),
          )
        : base;
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (_, current, _) => MaterialApp(
          locale: current,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(
              key: const ValueKey('finance-entry-evidence'),
              child: child,
            ),
          ),
          home: HomeShell(controller: ledger),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
    }
    await tester.scrollUntilVisible(
      finder,
      220,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 50,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await reveal(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String key, String value) async {
    final field = find.byKey(ValueKey(key));
    await reveal(tester, field);
    await tester.enterText(field, value);
    await tester.pump();
  }

  Future<String> input(WidgetTester tester, String key) async {
    final field = find.byKey(ValueKey(key));
    await reveal(tester, field);
    return tester.widget<FinanceFieldRow>(field).controller.text;
  }

  Future<void> back(WidgetTester tester) async {
    // Redesigned pages use the app bar back button; the PNG preview page keeps
    // the Material one.
    final button = find
        .byWidgetPredicate(
          (w) => w is BackButton || w.key == const ValueKey('app-nav-back'),
        )
        .hitTestable();
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> addServer(
    String id, {
    String currency = 'USD',
    int? amount = 3650,
    String? group,
    BillingKind billing = BillingKind.prepaid,
    bool archived = false,
  }) => store.saveServer(
    ServerRecord(
      id: id,
      name: 'Synthetic $id',
      vendor: 'Synthetic provider',
      host: '192.0.2.10',
      notes: 'PRIVATE_SOURCE_NOTE',
      billing: billing,
      currency: currency,
      amountMinor: amount,
      cycleMonths: 12,
      startDate: const LedgerDate(2026, 1, 1),
      dueDate: const LedgerDate(2027, 1, 1),
      groupId: group,
      archivedAt: archived ? now : null,
      createdAt: now,
      updatedAt: now,
    ),
    isNew: true,
  );

  Future<void> capture(WidgetTester tester, String name) async {
    final evidence = Platform.environment['VPS_FINANCE_ENTRY_EVIDENCE_DIR'];
    if (evidence == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('finance-entry-evidence')),
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

  for (final l10n in [zh, en]) {
    testWidgets(
      '${l10n.localeName} empty Costs opens an independent calculator',
      (tester) async {
        locale.value = Locale(l10n.localeName);
        final before = (await store.exportLedgerBackup()).encode();
        await mount(tester);
        double contentTop(Finder finder) =>
            tester.getTopLeft(finder).dy +
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .pixels;
        final metric = find.byKey(const ValueKey('metric-value'));
        await reveal(tester, metric);
        final summaryTop = contentTop(metric);
        await reveal(tester, entry);
        expect(find.text(l10n.calculatorDescription), findsOneWidget);
        final entryTop = contentTop(entry);
        expect(entryTop, greaterThan(summaryTop));
        // The redesigned Costs page lists renewals first and keeps the
        // calculator in the closing "records & tools" group.
        final upcoming = find.textContaining(l10n.financeUpcomingRenewals);
        await reveal(tester, upcoming);
        expect(entryTop, greaterThan(contentTop(upcoming)));
        await tap(tester, entry);
        expect(find.byType(CalculatorPage), findsOneWidget);
        expect(find.text(l10n.financeIndependentNote), findsOneWidget);
        expect(await input(tester, 'calc-price'), isEmpty);
        await tap(tester, find.text(l10n.financeReferenceServer));
        expect(find.text(l10n.financeNoPrepaid), findsOneWidget);
        Navigator.of(tester.element(find.text(l10n.financeNoPrepaid))).pop();
        await tester.pumpAndSettle();
        await fill(tester, 'calc-price', '36.50');
        await fill(tester, 'calc-asof', '2026-10-07');
        await fill(tester, 'calc-due', '2027-01-01');
        await tap(tester, find.byKey(const ValueKey('calculate-value')));
        final result = tester.widget<CalculationResultPage>(
          find.byType(CalculationResultPage),
        );
        expect(result.usesKnownPeriods, isFalse);
        expect(result.renewal.currency, 'USD');
        expect(result.renewal.minor, 3650);
        expect(result.value.amount.formatted, r'$8.60');
        await tap(tester, find.text(l10n.financeEditInputs));
        expect(await input(tester, 'calc-price'), '36.50');
        expect(await input(tester, 'calc-asof'), '2026-10-07');
        expect(await input(tester, 'calc-due'), '2027-01-01');
        await back(tester);
        expect(find.byType(FinancePage), findsOneWidget);
        await tap(tester, entry);
        expect(await input(tester, 'calc-price'), isEmpty);
        await back(tester);
        expect((await store.exportLedgerBackup()).encode(), before);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('repeated entry taps open one route and can reopen after Back', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await mount(tester);
      await reveal(tester, entry);
      final data = tester
          .getSemantics(
            find.descendant(of: entry, matching: find.byType(InkWell)),
          )
          .getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
      expect(data.label, contains(en.remainingValueCalculator));
      expect(data.label, contains(en.calculatorDescription));
      final activate = tester.widget<AppRow>(entry).onTap!;
      activate();
      activate();
      await tester.pumpAndSettle();
      expect(find.byType(CalculatorPage, skipOffstage: false), findsOneWidget);
      await back(tester);
      expect(find.byType(FinancePage), findsOneWidget);
      await tap(tester, entry);
      expect(find.byType(CalculatorPage, skipOffstage: false), findsOneWidget);
      await back(tester);
      expect(find.byType(CalculatorPage, skipOffstage: false), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Costs scope and scroll survive a calculator round trip', (
    tester,
  ) async {
    await store.saveGroup('Production');
    final groupId = (await store.groups()).single.id;
    await addServer('usd', group: groupId);
    await addServer('eur', currency: 'EUR', amount: 2400);
    await ledger.refresh();
    final before = (await store.exportLedgerBackup()).encode();
    await mount(tester);
    await tester.tap(find.byKey(const ValueKey('finance-scope')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('finance-group-$groupId')));
    await tester.pumpAndSettle();
    await reveal(tester, entry);
    final financeState = tester.state(find.byType(FinancePage));
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final offset = position.pixels;
    await tap(tester, entry);
    await tap(tester, find.text(en.financeReferenceServer));
    // The overview filter is not a currency or server constraint on a trial.
    expect(find.text('Synthetic usd'), findsOneWidget);
    expect(find.text('Synthetic eur'), findsOneWidget);
    await tester.tap(find.text('Synthetic eur'));
    await tester.pumpAndSettle();
    expect(await input(tester, 'calc-price'), '24.00');
    expect(find.byKey(const ValueKey('calc-currency-EUR')), findsOneWidget);
    await back(tester);
    expect(tester.state(find.byType(FinancePage)), same(financeState));
    expect(position.pixels, offset);
    // The scope chip still shows the selected group.
    await reveal(tester, find.byKey(const ValueKey('finance-scope')));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('finance-scope')),
        matching: find.text('Production'),
      ),
      findsOneWidget,
    );
    expect((await store.exportLedgerBackup()).encode(), before);
  });

  testWidgets('original currencies and existing PNG export remain read-only', (
    tester,
  ) async {
    await addServer('usd');
    await addServer('eur', currency: 'EUR', amount: 2400);
    await addServer('free', currency: 'CNY', amount: 0);
    await addServer('unknown', billing: BillingKind.unknown, amount: null);
    await addServer('metered', billing: BillingKind.metered);
    await addServer('archived', archived: true);
    await ledger.refresh();
    final before = (await store.exportLedgerBackup()).encode();
    await mount(tester);
    await tap(tester, entry);
    for (final item in [
      ('usd', 'USD', 3650),
      ('free', 'CNY', 0),
      ('eur', 'EUR', 2400),
    ]) {
      await tap(tester, find.text(en.financeReferenceServer));
      expect(find.text('Synthetic unknown'), findsNothing);
      expect(find.text('Synthetic metered'), findsNothing);
      expect(find.text('Synthetic archived'), findsNothing);
      await tester.tap(find.text('Synthetic ${item.$1}'));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('calc-currency-${item.$2}')), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('calculate-value')));
      final result = tester.widget<CalculationResultPage>(
        find.byType(CalculationResultPage),
      );
      expect(result.usesKnownPeriods, isTrue);
      expect(result.renewal.currency, item.$2);
      expect(result.renewal.minor, item.$3);
      if (item.$1 != 'eur') await back(tester);
    }
    await reveal(tester, find.byKey(const ValueKey('preview-png')));
    await tester.tap(find.byKey(const ValueKey('preview-png')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final preview = tester.widget<CalculationPreview>(
      find.byType(CalculationPreview),
    );
    expect(preview.renderer, renderCalculationPng);
    expect(preview.data.currency, 'EUR');
    expect(preview.data.converted, en.financeMissingFxPreserved);
    expect(preview.data.plainText, isNot(contains('Synthetic')));
    expect(preview.data.plainText, isNot(contains('PRIVATE_SOURCE_NOTE')));
    expect(preview.data.plainText, isNot(contains('192.0.2.10')));
    await back(tester);
    await tap(tester, find.text(en.financeEditInputs));
    expect(await input(tester, 'calc-price'), '24.00');
    await back(tester);
    expect((await store.exportLedgerBackup()).encode(), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'entry follows live language and still works after a failed refresh',
    (tester) async {
      ledger.refreshFailed = true;
      await mount(tester);
      await reveal(tester, entry);
      expect(find.text(en.remainingValueCalculator), findsOneWidget);
      locale.value = const Locale('zh');
      await tester.pumpAndSettle();
      await reveal(tester, entry);
      expect(find.text(zh.remainingValueCalculator), findsOneWidget);
      expect(find.text(zh.calculatorDescription), findsOneWidget);
      await tap(tester, entry);
      await fill(tester, 'calc-price', '12.34');
      locale.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(await input(tester, 'calc-price'), '12.34');
      expect(find.text(en.financeCalculatorTitle), findsOneWidget);
      await back(tester);
      await reveal(tester, entry);
      expect(find.text(en.remainingValueCalculator), findsOneWidget);
      expect(ledger.refreshFailed, isTrue);
    },
  );

  for (final language in ['zh', 'en']) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final size in [(390.0, 1.0), (320.0, 2.0)]) {
        testWidgets(
          '$language ${brightness.name} entry at ${size.$1}px and ${size.$2}x text',
          (tester) async {
            locale.value = Locale(language);
            await addServer('eur', currency: 'EUR', amount: 2400);
            await ledger.refresh();
            await mount(
              tester,
              width: size.$1,
              scale: size.$2,
              brightness: brightness,
              reviewFont: true,
            );
            if (size.$2 == 1) {
              await capture(tester, '$language-${brightness.name}-overview');
            }
            await reveal(tester, entry);
            final row = entry;
            expect(row.hitTestable(), findsOneWidget);
            expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
            for (final text in tester.widgetList<Text>(
              find.descendant(of: entry, matching: find.byType(Text)),
            )) {
              expect(text.maxLines, isNull);
              expect(text.overflow, isNull);
            }
            final position = tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position;
            position.jumpTo(
              (position.pixels - 160).clamp(0.0, position.maxScrollExtent),
            );
            await tester.pumpAndSettle();
            await capture(
              tester,
              '$language-${brightness.name}-${size.$1.toInt()}x${size.$2.toInt()}',
            );
            await tap(tester, entry);
            expect(find.byType(CalculatorPage), findsOneWidget);
            await back(tester);
            await reveal(tester, entry);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
