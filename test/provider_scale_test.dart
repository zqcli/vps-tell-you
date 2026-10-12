import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/providers/provider_catalog.dart';
import 'package:vps_tell_you/providers/provider_pages.dart';
import 'package:vps_tell_you/providers/provider_pickers.dart';
import 'package:vps_tell_you/providers/provider_record.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_form.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'support/large_catalog.dart';

/// Providers and packages with a catalog of 300 providers × 40 packages: the
/// pages must stay small, searchable and lazy.
void main() {
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late LargeCatalog catalog;
  final locale = ValueNotifier<Locale>(const Locale('en'));
  final now = DateTime.utc(2026, 10, 6);

  setUp(() async {
    locale.value = const Locale('en');
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('vps-scale-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
      clock: () => now,
    );
    catalog = LargeCatalog();
    ledger = LedgerController(store, clock: () => now, catalog: catalog);
    await ledger.refresh();
    await ledger.loadCatalog();
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  /// A server of catalog provider [n] using package [j] (null = none).
  Future<void> addServer(String id, int n, {int? j}) async {
    final package = j == null
        ? null
        : catalog.snapshot.package('${largeProviderId(n)}-p$j')!;
    await store.saveServer(
      ServerRecord(
        id: id,
        name: 'srv-$id',
        vendor: '',
        packageId: package?.id,
        packageSnapshot: package?.encodeSnapshot(),
        createdAt: now,
        updatedAt: now,
      ),
      isNew: true,
      catalogProvider: CatalogProviderRef(
        catalogId: largeProviderId(n),
        name: largeProviderName(n),
      ),
    );
    await ledger.refresh();
  }

  Future<void> mount(
    WidgetTester tester,
    Widget home, {
    double width = 390,
    double height = 900,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (context, value, _) => MaterialApp(
          theme: appTheme(),
          locale: value,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder rows() => find.byType(AppRow);
  Finder search() => find.byKey(const ValueKey('list-search'));

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(search(), text);
    await tester.pumpAndSettle();
  }

  Finder provider(int n) =>
      find.byKey(ValueKey('catalog-provider-${largeProviderId(n)}'));

  group('providers overview', () {
    testWidgets('lists only providers that have servers, name-sorted', (
      tester,
    ) async {
      await addServer('a', 7, j: 3);
      await addServer('b', 7, j: 4);
      await addServer('c', 2); // no package
      await store.saveProvider(
        ProviderRecord(id: 'unused', name: 'Unused Own', createdAt: now),
        isNew: true,
      );
      await ledger.refresh();
      await mount(tester, ProvidersPage(ledger: ledger));
      final used = [
        for (final p in ledger.providers)
          if (ledger.providerUsage.containsKey(p.id)) p,
      ];
      expect(used, hasLength(2));
      // 3 rows at most: two providers + "All Providers" (+ nothing for the
      // 298 other catalog entries).
      expect(rows().evaluate().length, lessThanOrEqualTo(4));
      expect(find.text('Café Hosting 2'), findsOneWidget);
      expect(find.text('Ünited Servers 7'), findsOneWidget);
      expect(find.text('Unused Own'), findsNothing);
      // Café sorts before Ünited (accents folded: cafe < united).
      expect(
        tester.getTopLeft(find.text('Café Hosting 2')).dy,
        lessThan(tester.getTopLeft(find.text('Ünited Servers 7')).dy),
      );
      expect(find.text('2 servers · 2 packages in use'), findsOneWidget);
      expect(find.text('1 server'), findsOneWidget);
      // 300 catalog + 1 own (the two used ones are already local, so counted
      // once).
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('providers-all')),
          matching: find.text('301'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('empty: short text and the All Providers row', (tester) async {
      await mount(tester, ProvidersPage(ledger: ledger));
      expect(find.byKey(const ValueKey('providers-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('providers-all')), findsOneWidget);
      expect(find.byKey(const ValueKey('provider-add')), findsOneWidget);
    });
  });

  group('All Providers', () {
    testWidgets('builds only what is visible', (tester) async {
      await mount(tester, AllProvidersPage(ledger: ledger));
      final built = rows().evaluate().length;
      expect(built, greaterThan(5));
      expect(built, lessThan(30), reason: '300 providers, lazily built');
      // Scrolling far still builds a screenful only.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -20000));
      await tester.pumpAndSettle();
      expect(rows().evaluate().length, lessThan(30));
      expect(tester.takeException(), isNull);
    });

    testWidgets('search: case, accents, Chinese substring, no match', (
      tester,
    ) async {
      await mount(tester, AllProvidersPage(ledger: ledger));
      await type(tester, 'CLOUD nine 12');
      expect(provider(12), findsOneWidget);
      // Words match from the start of a number: 12, 120, 124, 128.
      expect(rows().evaluate().length, 4);
      // Accent-insensitive both ways.
      await type(tester, 'cafe hosting 2');
      expect(provider(2), findsOneWidget);
      await type(tester, 'ünited servers 3');
      expect(provider(3), findsOneWidget);
      await type(tester, 'UNITED servers 3');
      expect(provider(3), findsOneWidget);
      // Chinese: a substring in the middle of the name.
      await type(tester, '海主');
      expect(provider(1), findsOneWidget);
      await type(tester, '云海主机 297');
      expect(provider(297), findsOneWidget);
      expect(rows().evaluate().length, 1);
      await type(tester, 'no such provider');
      expect(find.byKey(const ValueKey('providers-no-match')), findsOneWidget);
      expect(find.text('No matches.'), findsOneWidget);
      // Clearing restores the full list.
      await type(tester, '');
      expect(find.text('No matches.'), findsNothing);
      expect(rows().evaluate().length, greaterThan(5));
    });

    testWidgets('sections: mine first, then the catalog not yet added', (
      tester,
    ) async {
      await addServer('a', 5, j: 3);
      await store.saveProvider(
        ProviderRecord(id: 'own', name: 'Own Host', createdAt: now),
        isNew: true,
      );
      await ledger.refresh();
      await mount(tester, AllProvidersPage(ledger: ledger));
      final mine = find.text('My providers');
      final cat = find.text('Catalog providers');
      expect(mine, findsOneWidget);
      expect(cat, findsOneWidget);
      expect(tester.getTopLeft(mine).dy, lessThan(tester.getTopLeft(cat).dy));
      expect(find.byKey(const ValueKey('provider-own')), findsOneWidget);
      // The added catalog provider is one of mine now, not listed twice.
      expect(provider(5), findsNothing);
      await type(tester, '云海主机 5');
      expect(rows().evaluate().length, 3, reason: '5, 53, 57');
      await tester.tap(rows().first);
      await tester.pumpAndSettle();
      expect(find.byType(ProviderDetailsPage), findsOneWidget);
    });

    testWidgets('a catalog provider opens with All Packages, not 40 rows', (
      tester,
    ) async {
      await mount(tester, AllProvidersPage(ledger: ledger));
      await type(tester, 'Cloud Nine 8');
      await tester.tap(provider(8));
      await tester.pumpAndSettle();
      expect(find.byType(ProviderDetailsPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey('provider-all-packages')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('provider-all-packages')),
          matching: find.text('40'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Plan '), findsNothing);
      expect(
        find.byKey(const ValueKey('provider-add-catalog')),
        findsOneWidget,
      );
    });
  });

  group('provider page and package list', () {
    testWidgets('only packages in use are inline', (tester) async {
      await addServer('a', 4, j: 3);
      await addServer('b', 4, j: 3);
      await addServer('c', 4, j: 12);
      await addServer('d', 4);
      await mount(
        tester,
        ProviderDetailsPage(ledger: ledger, catalogId: largeProviderId(4)),
      );
      final inline = [
        for (var j = 0; j < 40; j++)
          if (find
              .byKey(ValueKey('provider-package-${largeProviderId(4)}-p$j'))
              .evaluate()
              .isNotEmpty)
            j,
      ];
      expect(inline, [3, 12]);
      expect(find.text('2 servers'), findsOneWidget);
      expect(find.byKey(const ValueKey('provider-device-d')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('provider-all-packages')),
        findsOneWidget,
      );
    });

    Future<void> openList(WidgetTester tester, {double height = 900}) async {
      await mount(
        tester,
        PackageListPage(ledger: ledger, catalogId: largeProviderId(4)),
        height: height,
      );
    }

    Finder plan(int j) =>
        find.byKey(ValueKey('package-list-${largeProviderId(4)}-p$j'));

    testWidgets('lazy: 40 packages, a screenful built', (tester) async {
      await openList(tester);
      expect(rows().evaluate().length, lessThan(40));
      expect(rows().evaluate().length, greaterThan(4));
      expect(find.text('All Packages'), findsWidgets);
      expect(find.text('Cloud Nine 4'), findsOneWidget, reason: 'subtitle');
    });

    testWidgets('search by spec text, region and name', (tester) async {
      await openList(tester, height: 5000); // tall: every match is built
      // "2 GB" is written many ways; RAM 2 GiB is every j % 5 == 1.
      await type(tester, '2 GB');
      expect(rows().evaluate().length, 8);
      expect(plan(1), findsOneWidget);
      await type(tester, '2gb');
      expect(rows().evaluate().length, 8);
      // vCPU 2 is j % 8 == 1; "2C" must not match 12 GB, 20C ... anything.
      await type(tester, '2C');
      expect(rows().evaluate().length, 5);
      await type(tester, '2 vCPU 2 GiB');
      expect(plan(1), findsOneWidget);
      await type(tester, 'tokyo');
      expect(rows().evaluate().length, 4, reason: 'j % 10 == 0');
      await type(tester, 'plan 39');
      expect(plan(39), findsOneWidget);
      await type(tester, 'nothing like this');
      expect(find.byKey(const ValueKey('packages-no-match')), findsOneWidget);
    });

    testWidgets('badges: Default and In use; sort by price and name', (
      tester,
    ) async {
      await addServer('a', 4, j: 3);
      await addServer('b', 4, j: 3);
      await openList(tester, height: 5000);
      final row = plan(3);
      expect(
        find.descendant(of: row, matching: find.text('Default')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('In use · 2')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: plan(5), matching: find.textContaining('In use')),
        findsNothing,
      );
      // Listed order: Plan 0 first. Name order: "Plan 0, Plan 1, Plan 10".
      double top(Finder f) => tester.getTopLeft(f).dy;
      expect(top(plan(0)), lessThan(top(plan(1))));
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      expect(top(plan(10)), lessThan(top(plan(2))), reason: 'text order');
      // Price: cheapest first (5 + j USD), so Plan 0 again before Plan 1.
      await tester.tap(find.text('Price'));
      await tester.pumpAndSettle();
      expect(top(plan(0)), lessThan(top(plan(1))));
      expect(top(plan(1)), lessThan(top(plan(2))));
      await tester.tap(plan(2));
      await tester.pumpAndSettle();
      expect(find.byType(PackageDetailsPage), findsOneWidget);
    });
  });

  group('form pickers', () {
    Future<void> openForm(WidgetTester tester, {double scale = 1}) async {
      await mount(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open'),
              onPressed: () => showAppModal<String>(
                context,
                builder: (_) => ServerForm(controller: ledger),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        scale: scale,
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
    }

    Finder topScrollable() => find
        .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
        .last;

    String? value(WidgetTester tester, String key) =>
        tester.widget<AppFormRow>(find.byKey(ValueKey(key))).value;

    testWidgets('provider picker: lazy, search, default package prefill', (
      tester,
    ) async {
      await openForm(tester);
      await tester.tap(find.byKey(const ValueKey('form-provider')));
      await tester.pumpAndSettle();
      expect(find.byType(ProviderPickerPage), findsOneWidget);
      expect(rows().evaluate().length, lessThan(30));
      await type(tester, 'ünited 11');
      final item = find.byKey(
        ValueKey('picker-catalog-${largeProviderId(11)}'),
      );
      expect(item, findsOneWidget);
      expect(find.text('40 packages'), findsWidgets);
      await tester.tap(item);
      await tester.pumpAndSettle();
      expect(find.byType(ProviderPickerPage), findsNothing);
      expect(value(tester, 'form-provider'), 'Ünited Servers 11');
      // Default package (Plan 3) preselected and applied.
      expect(value(tester, 'form-package'), 'Plan 3');
      expect(
        tester
            .widget<AppTextField>(find.byKey(const ValueKey('field-amount')))
            .controller!
            .text,
        '8.00',
      );
      // Nothing is stored before saving.
      expect(await store.providers(), isEmpty);
    });

    testWidgets('package picker: search, choose, cancel keeps the choice', (
      tester,
    ) async {
      await openForm(tester);
      await tester.tap(find.byKey(const ValueKey('form-provider')));
      await tester.pumpAndSettle();
      await type(tester, '云海 9');
      await tester.tap(
        find.byKey(ValueKey('picker-catalog-${largeProviderId(9)}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('form-package')));
      await tester.pumpAndSettle();
      expect(find.byType(PackagePickerPage), findsOneWidget);
      expect(rows().evaluate().length, lessThan(40), reason: 'lazy');
      // The current package carries the check and the Default badge.
      final current = find.byKey(
        ValueKey('picker-package-${largeProviderId(9)}-p3'),
      );
      expect(
        find.descendant(
          of: current,
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: current, matching: find.text('Default')),
        findsOneWidget,
      );
      await type(tester, 'tokyo');
      expect(find.byKey(const ValueKey('picker-package-none')), findsNothing);
      // Cancel: the selection is unchanged.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(value(tester, 'form-package'), 'Plan 3');
      // Choose another one: values are replaced (new server, same provider
      // package -> no confirmation).
      await tester.tap(find.byKey(const ValueKey('form-package')));
      await tester.pumpAndSettle();
      await type(tester, 'tokyo');
      final tokyo = find.byKey(
        ValueKey('picker-package-${largeProviderId(9)}-p10'),
      );
      await tester.scrollUntilVisible(tokyo, 200, scrollable: topScrollable());
      await tester.tap(tokyo);
      await tester.pumpAndSettle();
      expect(value(tester, 'form-package'), 'Plan 10');
      expect(
        tester
            .widget<AppTextField>(find.byKey(const ValueKey('field-amount')))
            .controller!
            .text,
        '15.00',
      );
      await tester.enterText(find.byKey(const ValueKey('field-name')), 'Big');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final saved = (await store.servers()).single;
      expect(saved.packageId, '${largeProviderId(9)}-p10');
      expect((await store.providers()).single.catalogId, largeProviderId(9));
    });

    testWidgets('picker: None and cancel leave things unchanged', (
      tester,
    ) async {
      await openForm(tester);
      await tester.tap(find.byKey(const ValueKey('form-provider')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('picker-provider-none')));
      await tester.pumpAndSettle();
      expect(value(tester, 'form-provider'), isNull);
      await tester.tap(find.byKey(const ValueKey('form-provider')));
      await tester.pumpAndSettle();
      await type(tester, 'cloud nine 4');
      await tester.tap(
        find.byKey(ValueKey('picker-catalog-${largeProviderId(4)}')),
      );
      await tester.pumpAndSettle();
      expect(value(tester, 'form-provider'), 'Cloud Nine 4');
      await tester.tap(find.byKey(const ValueKey('form-provider')));
      await tester.pumpAndSettle();
      await type(tester, 'cloud nine 12');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(value(tester, 'form-provider'), 'Cloud Nine 4');
      expect(await store.providers(), isEmpty);
    });

    testWidgets('picker: new provider from the typed text', (tester) async {
      await openForm(tester);
      await tester.tap(find.byKey(const ValueKey('form-provider')));
      await tester.pumpAndSettle();
      await type(tester, 'Brand New Host');
      expect(find.text('New Provider “Brand New Host”'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('picker-provider-new-named')));
      await tester.pumpAndSettle();
      expect(value(tester, 'form-provider'), 'Brand New Host');
      expect(await store.providers(), isEmpty);
      // Reopening shows it as the checked draft.
      await tester.tap(find.byKey(const ValueKey('form-provider')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('picker-provider-draft')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
    });
  });

  group('layout and languages (320px)', () {
    for (final lang in ['en', 'zh']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$lang 320px ${scale}x: lists and pickers fit', (
          tester,
        ) async {
          locale.value = Locale(lang);
          await addServer('a', 1, j: 3);
          await addServer('b', 2, j: 5);
          final pages = <String, Widget Function()>{
            'overview': () => ProvidersPage(ledger: ledger),
            'all providers': () => AllProvidersPage(ledger: ledger),
            'package list': () =>
                PackageListPage(ledger: ledger, catalogId: largeProviderId(1)),
            'provider': () => ProviderDetailsPage(
              ledger: ledger,
              providerId: ledger
                  .localProviderForCatalog(largeProviderId(1))!
                  .id,
            ),
            'provider picker': () => ProviderPickerPage(ledger: ledger),
            'package picker': () => PackagePickerPage(
              ledger: ledger,
              provider: catalog.snapshot.provider(largeProviderId(1))!,
              selected: catalog.snapshot.package('${largeProviderId(1)}-p3'),
            ),
          };
          for (final entry in pages.entries) {
            await mount(tester, entry.value(), width: 320, scale: scale);
            expect(tester.takeException(), isNull, reason: entry.key);
            final scrollable = find
                .byWidgetPredicate(
                  (w) => w is Scrollable && w.axis == Axis.vertical,
                )
                .first;
            for (var i = 0; i < 4; i++) {
              await tester.drag(scrollable, const Offset(0, -700));
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '${entry.key} scrolled',
              );
            }
            if (search().evaluate().isNotEmpty) {
              await tester.enterText(search(), 'a');
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '${entry.key} search',
              );
            }
          }
        });
      }
    }
  });
}
