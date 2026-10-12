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
import 'package:vps_tell_you/providers/provider_record.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_detail.dart';
import 'package:vps_tell_you/servers/server_form.dart';
import 'package:vps_tell_you/servers/server_list.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'support/catalog_fixture.dart';
import 'support/form_test_helpers.dart' show setVcpu, vcpuText;

const _cloudRef = CatalogProviderRef(
  catalogId: 'fixture-cloud',
  name: 'Fixture Cloud',
);

void main() {
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late MemoryCatalog catalog;
  final locale = ValueNotifier<Locale>(const Locale('en'));
  final now = DateTime.utc(2026, 10, 6);

  Future<void> boot({ProviderCatalog? source}) async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('vps-package-ui-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
      clock: () => now,
    );
    catalog = MemoryCatalog();
    ledger = LedgerController(
      store,
      clock: () => now,
      catalog: source ?? catalog,
    );
    await ledger.refresh();
  }

  setUp(() async {
    locale.value = const Locale('en');
    await boot();
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester,
    Widget home, {
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 900);
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

  /// The list of the topmost sheet (the picker), not the form behind it.
  Finder topScrollable() => find
      .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
      .last;

  Finder verticalScrollable() => find
      .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
      .first;

  Future<void> reveal(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: verticalScrollable(),
      );
    }
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await reveal(tester, key);
    final finder = find.byKey(ValueKey(key));
    expect(finder, findsOneWidget, reason: key);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String key, String text) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<AppTextField>(find.byKey(ValueKey(key))).controller!.text;

  /// Opens the edit form as a sheet over a base page (as the app does), so
  /// saving closes the sheet instead of the only route.
  Future<void> openEditForm(WidgetTester tester, String id) async {
    await mount(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open-form'),
            onPressed: () => showAppModal<String>(
              context,
              builder: (_) =>
                  ServerForm(controller: ledger, record: ledger.byId(id)),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tap(tester, 'open-form');
  }

  Future<void> startAdd(WidgetTester tester) async {
    await mount(tester, Scaffold(body: ServerList(controller: ledger)));
    await tap(tester, 'add-server');
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String row, String item) async {
    await tap(tester, row);
    final target = find.byKey(ValueKey(item));
    await tester.scrollUntilVisible(target, 200, scrollable: topScrollable());
    expect(target, findsOneWidget, reason: '$item in the open picker');
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  String? rowValue(WidgetTester tester, String key) =>
      tester.widget<AppFormRow>(find.byKey(ValueKey(key))).value;

  /// Closes the open picker sheet without choosing.
  Future<void> cancelPicker(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  Future<void> newProvider(WidgetTester tester, String name) async {
    await tap(tester, 'form-provider');
    final item = find.byKey(const ValueKey('picker-provider-new'));
    await tester.scrollUntilVisible(item, 200, scrollable: topScrollable());
    await tester.tap(item);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('provider-name')), name);
    await tester.tap(find.byKey(const ValueKey('provider-save')));
    await tester.pumpAndSettle();
  }

  group('add flow', () {
    testWidgets('adding opens the form directly; provider is a picker row', (
      tester,
    ) async {
      await startAdd(tester);
      expect(find.byType(ServerForm), findsOneWidget);
      expect(find.byKey(const ValueKey('form-provider')), findsOneWidget);
      expect(rowValue(tester, 'form-provider'), isNull);
      // No catalog package list without a catalog provider.
      expect(find.byKey(const ValueKey('form-package')), findsNothing);
      expect(find.byKey(const ValueKey('field-host')), findsNothing);
      // Browsing the picker stores nothing.
      await tap(tester, 'form-provider');
      expect(await store.providers(), isEmpty);
    });

    testWidgets('the provider picker separates in-use, mine and the catalog', (
      tester,
    ) async {
      await store.saveProvider(
        ProviderRecord(id: 'mine', name: 'My Own Host', createdAt: now),
        isNew: true,
      );
      await store.saveProvider(
        ProviderRecord(id: 'busy', name: 'Busy Host', createdAt: now),
        isNew: true,
      );
      await store.saveServer(
        ServerRecord(
          id: 'used',
          name: 'Uses Busy',
          vendor: '',
          providerId: 'busy',
          createdAt: now,
          updatedAt: now,
        ),
        isNew: true,
      );
      await ledger.refresh();
      await startAdd(tester);
      await tap(tester, 'form-provider');
      expect(find.text('Choose a Provider'), findsOneWidget);
      double top(Finder f) => tester.getTopLeft(f).dy;
      final order = [
        find.byKey(const ValueKey('picker-provider-none')),
        // Near the top so a long catalog never hides it.
        find.byKey(const ValueKey('picker-provider-new')),
        find.text('In use'),
        find.byKey(const ValueKey('picker-provider-busy')),
        find.text('My providers'),
        find.byKey(const ValueKey('picker-provider-mine')),
        find.text('Catalog providers'),
        // Sorted by name: Empty Host, Fixture Cloud.
        find.byKey(const ValueKey('picker-catalog-empty-host')),
        find.byKey(const ValueKey('picker-catalog-fixture-cloud')),
      ];
      for (final f in order) {
        expect(f, findsOneWidget);
      }
      for (var i = 1; i < order.length; i++) {
        expect(top(order[i]), greaterThan(top(order[i - 1])));
      }
      // Rows tell what is behind them; "None" is the current choice.
      String subtitleOf(String key) => tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .join('|');
      expect(
        subtitleOf('picker-catalog-fixture-cloud'),
        contains('3 packages'),
      );
      expect(subtitleOf('picker-provider-busy'), contains('1 server'));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('picker-provider-none')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(find.text('New Provider…'), findsOneWidget);
      // Cancelling leaves the selection alone.
      await cancelPicker(tester);
      expect(find.byKey(const ValueKey('picker-provider-new')), findsNothing);
      expect(rowValue(tester, 'form-provider'), isNull);
    });

    testWidgets('provider search narrows the list and offers the typed name', (
      tester,
    ) async {
      await startAdd(tester);
      await tap(tester, 'form-provider');
      await tester.enterText(find.byKey(const ValueKey('list-search')), 'fixt');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('picker-catalog-fixture-cloud')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('picker-catalog-empty-host')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('picker-provider-none')), findsNothing);
      // Not an exact name: the text can become a new provider.
      expect(find.text('New Provider “fixt”'), findsOneWidget);
      // An exact (case-insensitive) name does not offer a duplicate.
      await tester.enterText(
        find.byKey(const ValueKey('list-search')),
        'FIXTURE cloud',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('picker-provider-new-named')),
        findsNothing,
      );
      await tester.enterText(find.byKey(const ValueKey('list-search')), 'zzz');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('picker-provider-new-named')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('picker-provider-new-named')));
      await tester.pumpAndSettle();
      expect(rowValue(tester, 'form-provider'), 'zzz');
      expect(await store.providers(), isEmpty, reason: 'created on save only');
      await fill(tester, 'field-name', 'Named by search');
      await save(tester);
      expect((await store.providers()).single.name, 'zzz');
      expect(
        (await store.servers()).single.providerId,
        (await store.providers()).single.id,
      );
    });

    testWidgets('a no-match search says so', (tester) async {
      await startAdd(tester);
      await tap(tester, 'form-provider');
      await tester.enterText(
        find.byKey(const ValueKey('list-search')),
        'x' * 81,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('picker-no-match')), findsOneWidget);
      expect(find.text('No matches.'), findsOneWidget);
    });

    testWidgets(
      'catalog provider: default package is preselected and prefills the form',
      (tester) async {
        await startAdd(tester);
        await pick(tester, 'form-provider', 'picker-catalog-fixture-cloud');
        expect(rowValue(tester, 'form-provider'), 'Fixture Cloud');
        expect(rowValue(tester, 'form-package'), 'Small');
        expect(fieldText(tester, 'field-amount'), '12.00');
        expect(fieldText(tester, 'field-region'), 'Fixture Region');
        expect(fieldText(tester, 'resource-ramBytes'), '2');
        expect(fieldText(tester, 'resource-diskBytes'), '40');
        // Still nothing in the ledger until the form is saved.
        expect(await store.providers(), isEmpty);

        // The package menu lists "No Package" and every package with its
        // price and hardware; the default one is checked.
        await tap(tester, 'form-package');
        for (final id in ['none', 'fc-nano', 'fc-small', 'fc-large']) {
          expect(find.byKey(ValueKey('picker-package-$id')), findsOneWidget);
        }
        expect(find.text('No Package'), findsOneWidget);
        expect(find.textContaining('12.00 USD'), findsWidgets);
        expect(find.textContaining('2 vCPU'), findsWidgets);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('picker-package-fc-small')),
            matching: find.byIcon(Icons.check_rounded),
          ),
          findsOneWidget,
        );
        await cancelPicker(tester);

        await fill(tester, 'field-name', 'Prefilled');
        await save(tester);
        expect(find.byType(ServerDetail), findsOneWidget);
        final server = (await store.servers()).single;
        expect(server.packageId, 'fc-small');
        expect(server.billing, BillingKind.prepaid);
        expect(server.amountMinor, 1200);
        expect(server.cycleMonths, 1);
        expect(server.resources!.vcpu, 2);
        expect(server.resources!.ramBytes, 2 * 1024 * 1024 * 1024);
        final provider = (await store.providers()).single;
        expect(provider.catalogId, 'fixture-cloud');
        expect(server.providerId, provider.id);
      },
    );

    testWidgets('another package prefills its own values', (tester) async {
      await startAdd(tester);
      await pick(tester, 'form-provider', 'picker-catalog-fixture-cloud');
      await pick(tester, 'form-package', 'picker-package-fc-large');
      expect(rowValue(tester, 'form-package'), 'Large');
      expect(fieldText(tester, 'field-amount'), '96.00');
      await fill(tester, 'field-name', 'Large');
      await save(tester);
      final server = (await store.servers()).single;
      expect(server.packageId, 'fc-large');
      expect(server.cycleMonths, 12);
      expect(server.resources!.trafficUnlimited, isTrue);
      expect(server.resources!.vcpu, 8);
    });

    testWidgets('No Package drops the link and keeps the values', (
      tester,
    ) async {
      await startAdd(tester);
      await pick(tester, 'form-provider', 'picker-catalog-fixture-cloud');
      await pick(tester, 'form-package', 'picker-package-none');
      expect(rowValue(tester, 'form-package'), isNull);
      expect(fieldText(tester, 'field-amount'), '12.00');
      await fill(tester, 'field-name', 'No package');
      await save(tester);
      final server = (await store.servers()).single;
      expect(server.packageId, isNull);
      expect(server.packageSnapshot, isNull);
      expect(server.providerId, (await store.providers()).single.id);
      expect(server.amountMinor, 1200);
    });

    testWidgets('cancelling the form creates no provider and no server', (
      tester,
    ) async {
      await startAdd(tester);
      await pick(tester, 'form-provider', 'picker-catalog-fixture-cloud');
      await newProvider(tester, 'Never Saved');
      expect(rowValue(tester, 'form-provider'), 'Never Saved');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(ServerForm), findsNothing);
      expect(await store.providers(), isEmpty);
      expect(await store.servers(), isEmpty);
    });

    testWidgets('a catalog provider without packages has no package row', (
      tester,
    ) async {
      await startAdd(tester);
      await pick(tester, 'form-provider', 'picker-catalog-empty-host');
      expect(find.byKey(const ValueKey('form-package')), findsNothing);
      expect(find.byKey(const ValueKey('field-amount')), findsNothing);
      await fill(tester, 'field-name', 'Plain');
      await save(tester);
      final server = (await store.servers()).single;
      expect(server.packageId, isNull);
      expect((await store.providers()).single.catalogId, 'empty-host');
    });

    testWidgets('new provider: named in a prompt, created together with the '
        'server', (tester) async {
      await startAdd(tester);
      await newProvider(tester, 'My Host');
      expect(rowValue(tester, 'form-provider'), 'My Host');
      expect(find.byKey(const ValueKey('form-package')), findsNothing);
      // Still only a draft; it shows in the menu as the selected entry.
      expect(await store.providers(), isEmpty);
      await tap(tester, 'form-provider');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('picker-provider-draft')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      await cancelPicker(tester);
      await fill(tester, 'field-name', 'Custom');
      await save(tester);
      final provider = (await store.providers()).single;
      expect(provider.name, 'My Host');
      expect(provider.catalogId, isNull);
      expect((await store.servers()).single.providerId, provider.id);
    });

    testWidgets('the name prompt can be cancelled and rejects bad names', (
      tester,
    ) async {
      await store.saveProvider(
        ProviderRecord(id: 'mine', name: 'Taken', createdAt: now),
        isNew: true,
      );
      await ledger.refresh();
      await startAdd(tester);
      await tap(tester, 'form-provider');
      await tester.tap(find.byKey(const ValueKey('picker-provider-new')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('provider-name')), '  ');
      await tester.tap(find.byKey(const ValueKey('provider-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('provider-name')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('provider-name')),
        'taken',
      );
      await tester.tap(find.byKey(const ValueKey('provider-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('provider-name')), findsOneWidget);
      expect(find.textContaining('already exists'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(rowValue(tester, 'form-provider'), isNull);
      expect(await store.providers(), hasLength(1));
    });

    testWidgets('choosing another provider discards the drafted one', (
      tester,
    ) async {
      await store.saveProvider(
        ProviderRecord(id: 'mine', name: 'Mine', createdAt: now),
        isNew: true,
      );
      await ledger.refresh();
      await startAdd(tester);
      await newProvider(tester, 'Draft');
      await pick(tester, 'form-provider', 'picker-provider-mine');
      await tap(tester, 'form-provider');
      expect(find.byKey(const ValueKey('picker-provider-draft')), findsNothing);
      await cancelPicker(tester);
      await fill(tester, 'field-name', 'Uses Mine');
      await save(tester);
      expect((await store.providers()).single.id, 'mine');
      expect((await store.servers()).single.providerId, 'mine');
    });

    testWidgets('no provider and no package is allowed', (tester) async {
      await startAdd(tester);
      await fill(tester, 'field-name', 'Loose');
      await save(tester);
      final server = (await store.servers()).single;
      expect(server.providerId, isNull);
      expect(server.packageId, isNull);
      expect(await store.providers(), isEmpty);
    });

    testWidgets('an added catalog provider moves to mine and is reused', (
      tester,
    ) async {
      await store.addCatalogProvider(_cloudRef);
      await ledger.refresh();
      await startAdd(tester);
      await tap(tester, 'form-provider');
      expect(
        find.byKey(const ValueKey('picker-catalog-fixture-cloud')),
        findsNothing,
        reason: 'only providers not added yet are listed under the catalog',
      );
      final local = (await store.providers()).single;
      final row = find.byKey(ValueKey('picker-provider-${local.id}'));
      expect(
        find.descendant(of: row, matching: find.text('3 packages')),
        findsOneWidget,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(rowValue(tester, 'form-package'), 'Small', reason: 'default');
      await fill(tester, 'field-name', 'Reuse');
      await save(tester);
      expect(await store.providers(), hasLength(1));
      expect((await store.servers()).single.providerId, local.id);
      expect((await store.servers()).single.packageId, 'fc-small');
    });

    testWidgets('a failed catalog leaves only local providers', (tester) async {
      ledger.dispose();
      ledger = LedgerController(
        store,
        clock: () => now,
        catalog: FailingCatalog(),
      );
      await ledger.refresh();
      await store.saveProvider(
        ProviderRecord(id: 'mine', name: 'Mine', createdAt: now),
        isNew: true,
      );
      await ledger.refresh();
      await startAdd(tester);
      expect(ledger.catalogFailed, isTrue);
      await tap(tester, 'form-provider');
      expect(find.text('Catalog providers'), findsNothing);
      expect(
        find.byKey(const ValueKey('picker-catalog-fixture-cloud')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('picker-provider-mine')));
      await tester.pumpAndSettle();
      await fill(tester, 'field-name', 'Offline');
      await save(tester);
      expect((await store.servers()).single.providerId, 'mine');
    });

    testWidgets('typed hardware is protected when a default package arrives', (
      tester,
    ) async {
      await startAdd(tester);
      await setVcpu(tester, 3);
      await pick(tester, 'form-provider', 'picker-catalog-fixture-cloud');
      expect(find.text('Replace hardware and price?'), findsOneWidget);
      // Declining keeps the provider but neither the package nor its values.
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(rowValue(tester, 'form-provider'), 'Fixture Cloud');
      expect(rowValue(tester, 'form-package'), isNull);
      expect(vcpuText(tester), '3');
      expect(find.byKey(const ValueKey('field-amount')), findsNothing);
      // Picking the package explicitly replaces them without asking again.
      await pick(tester, 'form-package', 'picker-package-fc-small');
      expect(vcpuText(tester), '2');
      expect(fieldText(tester, 'field-amount'), '12.00');
    });

    testWidgets('switching provider replaces the previous package values', (
      tester,
    ) async {
      await store.saveProvider(
        ProviderRecord(id: 'mine', name: 'Mine', createdAt: now),
        isNew: true,
      );
      await ledger.refresh();
      await startAdd(tester);
      await pick(tester, 'form-provider', 'picker-catalog-fixture-cloud');
      expect(rowValue(tester, 'form-package'), 'Small');
      await pick(tester, 'form-provider', 'picker-provider-mine');
      // A package belongs to its provider: row and link are gone ...
      expect(find.byKey(const ValueKey('form-package')), findsNothing);
      await fill(tester, 'field-name', 'Moved');
      await save(tester);
      final server = (await store.servers()).single;
      expect(server.providerId, 'mine');
      expect(server.packageId, isNull);
      // ... and no provider was created for the abandoned catalog choice.
      expect((await store.providers()).single.id, 'mine');
    });
  });

  group('form', () {
    testWidgets(
      'switching the package of a saved server asks, then replaces values',
      (tester) async {
        final provider = await store.addCatalogProvider(_cloudRef);
        final small = catalog.snapshot.package('fc-small')!;
        await store.saveServer(
          ServerRecord(
            id: 's1',
            name: 'Edit me',
            vendor: 'Fixture Cloud',
            providerId: provider.id,
            packageId: small.id,
            packageSnapshot: small.encodeSnapshot(),
            billing: BillingKind.prepaid,
            amountMinor: 1200,
            cycleMonths: 1,
            createdAt: now,
            updatedAt: now,
          ),
          isNew: true,
        );
        await ledger.refresh();
        await openEditForm(tester, 's1');
        expect(rowValue(tester, 'form-package'), 'Small');
        await pick(tester, 'form-package', 'picker-package-fc-nano');
        expect(find.text('Replace hardware and price?'), findsOneWidget);
        await tester.tap(find.text('Replace Values'));
        await tester.pumpAndSettle();
        expect(fieldText(tester, 'field-amount'), '5.00');
        await save(tester);
        final saved = (await store.servers()).single;
        expect(saved.packageId, 'fc-nano');
        expect(saved.amountMinor, 500);
        expect(saved.resources!.vcpu, 1);

        // Clearing the package keeps every value.
        await openEditForm(tester, 's1');
        await pick(tester, 'form-package', 'picker-package-none');
        await save(tester);
        final cleared = (await store.servers()).single;
        expect(cleared.packageId, isNull);
        expect(cleared.amountMinor, 500);
      },
    );

    testWidgets(
      'changing the provider drops a package which belongs to another',
      (tester) async {
        await store.saveProvider(
          ProviderRecord(id: 'mine', name: 'Mine', createdAt: now),
          isNew: true,
        );
        final provider = await store.addCatalogProvider(_cloudRef);
        final small = catalog.snapshot.package('fc-small')!;
        await store.saveServer(
          ServerRecord(
            id: 's1',
            name: 'Move me',
            vendor: 'Fixture Cloud',
            providerId: provider.id,
            packageId: small.id,
            packageSnapshot: small.encodeSnapshot(),
            createdAt: now,
            updatedAt: now,
          ),
          isNew: true,
        );
        await ledger.refresh();
        await openEditForm(tester, 's1');
        await pick(tester, 'form-provider', 'picker-provider-mine');
        // The package belongs to the old provider: its row goes away, and an
        // existing server never gets a default package of the new one.
        expect(find.byKey(const ValueKey('form-package')), findsNothing);
        await save(tester);
        final saved = (await store.servers()).single;
        expect(saved.providerId, 'mine');
        expect(saved.packageId, isNull);
      },
    );
  });

  group('provider and package pages', () {
    Future<ServerRecord> addPackaged(
      String id, {
      String packageId = 'fc-small',
      DateTime? at,
    }) async {
      final package = catalog.snapshot.package(packageId)!;
      await store.saveServer(
        ServerRecord(
          id: id,
          name: 'Server $id',
          vendor: 'Fixture Cloud',
          host: '192.0.2.${id.length}',
          packageId: package.id,
          packageSnapshot: package.encodeSnapshot(),
          createdAt: at ?? now,
          updatedAt: at ?? now,
        ),
        isNew: true,
        catalogProvider: _cloudRef,
      );
      await ledger.refresh();
      return ledger.byId(id)!;
    }

    testWidgets(
      'providers page lists only providers with servers; All Providers has the rest',
      (tester) async {
        await store.saveProvider(
          ProviderRecord(id: 'mine', name: 'Mine', createdAt: now),
          isNew: true,
        );
        await addPackaged('a'); // Fixture Cloud, 1 server, 1 package in use
        await mount(tester, ProvidersPage(ledger: ledger));
        // Only the provider that has a server.
        expect(find.byKey(const ValueKey('provider-mine')), findsNothing);
        final used = find.byKey(
          ValueKey(
            'provider-${ledger.localProviderForCatalog('fixture-cloud')!.id}',
          ),
        );
        expect(used, findsOneWidget);
        expect(
          find.descendant(
            of: used,
            matching: find.text('1 server · 1 package in use'),
          ),
          findsOneWidget,
        );
        // Mine + Fixture Cloud + Empty Host (catalog, not added).
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('providers-all')),
            matching: find.text('3'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('catalog-provider-empty-host')),
          findsNothing,
        );

        await tap(tester, 'providers-all');
        expect(find.byType(AllProvidersPage), findsOneWidget);
        expect(find.byKey(const ValueKey('provider-mine')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('catalog-provider-empty-host')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('catalog-provider-fixture-cloud')),
          findsNothing,
          reason: 'already added, so it is one of mine',
        );

        // A catalog provider page offers adding it, and lists packages behind
        // "All Packages" instead of inline.
        await tap(tester, 'catalog-provider-empty-host');
        expect(
          find.byKey(const ValueKey('provider-all-packages')),
          findsNothing,
        );
        expect(await store.providers(), hasLength(2));
        await tap(tester, 'provider-add-catalog');
        expect(await store.providers(), hasLength(3));
        expect(
          find.byKey(const ValueKey('provider-add-catalog')),
          findsNothing,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        // Added: moved from the catalog section into "my providers".
        expect(
          find.byKey(const ValueKey('catalog-provider-empty-host')),
          findsNothing,
        );
        expect(find.text('Empty Host'), findsOneWidget);
      },
    );

    testWidgets(
      'provider page: packages in use, no-package servers, all packages',
      (tester) async {
        await addPackaged('a'); // fc-small
        await addPackaged('b'); // fc-small again
        await addPackaged('c', packageId: 'fc-large');
        await store.saveServer(
          ServerRecord(
            id: 'plain',
            name: 'No package server',
            vendor: '',
            createdAt: now,
            updatedAt: now,
          ),
          isNew: true,
          catalogProvider: _cloudRef,
        );
        await ledger.refresh();
        await mount(
          tester,
          ProviderDetailsPage(ledger: ledger, catalogId: 'fixture-cloud'),
        );
        expect(find.byKey(const ValueKey('provider-badge')), findsOneWidget);
        expect(find.text('Catalog'), findsWidgets);
        // In use: Small (2 servers) and Large (1); Nano is not listed.
        final small = find.byKey(const ValueKey('provider-package-fc-small'));
        expect(small, findsOneWidget);
        expect(
          find.descendant(of: small, matching: find.text('2 servers')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('provider-package-fc-large')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('provider-package-fc-nano')),
          findsNothing,
        );
        // Servers without a package are listed; packaged servers are not.
        expect(find.text('No package'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('provider-device-plain')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('provider-device-a')), findsNothing);
        await tap(tester, 'provider-package-fc-small');
        expect(find.byType(PackageDetailsPage), findsOneWidget);
        expect(find.byKey(const ValueKey('package-server-a')), findsOneWidget);
        expect(find.byKey(const ValueKey('package-server-b')), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();

        // All Packages: every package, with Default and In use badges.
        await tap(tester, 'provider-all-packages');
        expect(find.byType(PackageListPage), findsOneWidget);
        for (final id in ['fc-nano', 'fc-small', 'fc-large']) {
          expect(find.byKey(ValueKey('package-list-$id')), findsOneWidget);
        }
        final row = find.byKey(const ValueKey('package-list-fc-small'));
        expect(
          find.descendant(of: row, matching: find.text('Default')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.text('In use · 2')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('package-list-fc-nano')),
            matching: find.textContaining('In use'),
          ),
          findsNothing,
        );
        await tester.enterText(
          find.byKey(const ValueKey('list-search')),
          'larg',
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('package-list-fc-large')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('package-list-fc-small')),
          findsNothing,
        );
        await tap(tester, 'package-list-fc-large');
        expect(find.byType(PackageDetailsPage), findsOneWidget);
      },
    );

    testWidgets('a provider without servers still opens with Add Server', (
      tester,
    ) async {
      await store.saveProvider(
        ProviderRecord(id: 'mine', name: 'Mine', createdAt: now),
        isNew: true,
      );
      await ledger.refresh();
      await mount(
        tester,
        ProviderDetailsPage(ledger: ledger, providerId: 'mine'),
      );
      expect(find.text('Custom'), findsOneWidget);
      expect(find.byKey(const ValueKey('provider-badge')), findsOneWidget);
      expect(find.byKey(const ValueKey('provider-all-packages')), findsNothing);
      expect(find.text('No package'), findsNothing);
      expect(find.byKey(const ValueKey('provider-add-server')), findsOneWidget);
    });

    testWidgets('package page shows specs and the linked servers', (
      tester,
    ) async {
      await addPackaged('a');
      await addPackaged('bb');
      await mount(
        tester,
        PackageDetailsPage(ledger: ledger, packageId: 'fc-small'),
      );
      expect(find.text('Small'), findsOneWidget);
      expect(find.text('Fixture Cloud'), findsOneWidget);
      expect(find.text('12.00 USD · Every month'), findsOneWidget);
      expect(find.byKey(const ValueKey('package-server-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('package-server-bb')), findsOneWidget);
      expect(find.byKey(const ValueKey('package-changed-note')), findsNothing);
      await tap(tester, 'package-server-a');
      expect(find.byType(ServerDetail), findsOneWidget);
      expect(find.text('Server a'), findsWidgets);
    });

    testWidgets('package page with no servers says so and can add one', (
      tester,
    ) async {
      await mount(
        tester,
        PackageDetailsPage(ledger: ledger, packageId: 'fc-nano'),
      );
      expect(find.text('No server uses this package yet.'), findsOneWidget);
      await tap(tester, 'package-add-server');
      expect(find.byType(ServerForm), findsOneWidget);
      expect(fieldText(tester, 'field-amount'), '5.00');
      await fill(tester, 'field-name', 'From package');
      await save(tester);
      expect((await store.servers()).single.packageId, 'fc-nano');
    });

    testWidgets(
      'a changed catalog package is flagged and the saved values stay visible',
      (tester) async {
        final server = await addPackaged('a');
        catalog.snapshot = fixtureCatalog(version: 4, smallAmount: 1500);
        await ledger.loadCatalog(force: true);
        await mount(
          tester,
          PackageDetailsPage(
            ledger: ledger,
            packageId: 'fc-small',
            server: server,
          ),
        );
        expect(
          find.byKey(const ValueKey('package-changed-note')),
          findsOneWidget,
        );
        expect(find.text('15.00 USD · Every month'), findsOneWidget);
        expect(find.text('12.00 USD · Every month'), findsOneWidget);
        expect(find.text('As saved on this server'), findsOneWidget);
        expect(find.text('Catalog updated'), findsWidgets);
      },
    );

    testWidgets(
      'a package missing from the catalog is still described by its servers',
      (tester) async {
        await addPackaged('a');
        catalog.snapshot = CatalogSnapshot.parse(
          '{"schemaVersion":1,"catalogVersion":9,"providers":[]}',
        );
        await ledger.loadCatalog(force: true);
        await mount(
          tester,
          PackageDetailsPage(ledger: ledger, packageId: 'fc-small'),
        );
        expect(
          find.byKey(const ValueKey('package-removed-note')),
          findsOneWidget,
        );
        expect(find.text('Small'), findsOneWidget);
        expect(find.byKey(const ValueKey('package-server-a')), findsOneWidget);
        expect(find.byKey(const ValueKey('package-add-server')), findsNothing);
      },
    );

    testWidgets('server detail links provider and package', (tester) async {
      await addPackaged('a');
      await mount(tester, ServerDetail(controller: ledger, id: 'a'));
      await reveal(tester, 'server-package-link');
      final providerRow = find.byKey(const ValueKey('server-provider-link'));
      final packageRow = find.byKey(const ValueKey('server-package-link'));
      await tester.ensureVisible(packageRow);
      expect(providerRow, findsOneWidget);
      expect(find.text('Provider and package'), findsOneWidget);
      expect(
        find.descendant(of: packageRow, matching: find.text('Small')),
        findsOneWidget,
      );
      await tap(tester, 'server-package-link');
      expect(find.byType(PackageDetailsPage), findsOneWidget);
      expect(find.byKey(const ValueKey('package-server-a')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'server-provider-link');
      expect(find.byType(ProviderDetailsPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey('provider-package-fc-small')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('provider-device-a')), findsNothing);
      expect(
        find.byKey(const ValueKey('provider-all-packages')),
        findsOneWidget,
      );
    });

    testWidgets(
      'server detail without a package shows a disabled row; list shows package name',
      (tester) async {
        await store.saveServer(
          ServerRecord(
            id: 'plain',
            name: 'Plain',
            vendor: '',
            createdAt: now,
            updatedAt: now,
          ),
          isNew: true,
        );
        await ledger.refresh();
        await mount(tester, ServerDetail(controller: ledger, id: 'plain'));
        await reveal(tester, 'server-package-link');
        final row = tester.widget<AppRow>(
          find.byKey(const ValueKey('server-package-link')),
        );
        expect(row.title, 'No package');
        expect(row.onTap, isNull);
        await addPackaged('a');
        await mount(tester, Scaffold(body: ServerList(controller: ledger)));
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('server-a')),
            matching: find.textContaining('Fixture Cloud · Small'),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('layout and languages', () {
    for (final lang in ['en', 'zh']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$lang 320px ${scale}x: pickers fit and stay reachable', (
          tester,
        ) async {
          locale.value = Locale(lang);
          await store.saveProvider(
            ProviderRecord(
              id: 'mine',
              name: 'A provider with a rather long name for narrow phones',
              createdAt: now,
            ),
            isNew: true,
          );
          await ledger.refresh();
          await mount(
            tester,
            ServerForm(controller: ledger),
            width: 320,
            scale: scale,
          );
          await tap(tester, 'form-provider');
          expect(tester.takeException(), isNull);
          // The search stays pinned and every row is within the screen; the
          // list scrolls, so the last row can be reached.
          expect(find.byKey(const ValueKey('list-search')), findsOneWidget);
          final last = find.byKey(const ValueKey('picker-provider-new'));
          await tester.scrollUntilVisible(
            last,
            200,
            scrollable: topScrollable(),
          );
          final box = tester.getRect(last);
          expect(box.left, greaterThanOrEqualTo(0));
          expect(box.right, lessThanOrEqualTo(320));
          expect(find.byKey(const ValueKey('list-search')), findsOneWidget);
          await cancelPicker(tester);
          await pick(tester, 'form-provider', 'picker-catalog-fixture-cloud');
          await tap(tester, 'form-package');
          expect(tester.takeException(), isNull);
          for (final id in ['none', 'fc-nano', 'fc-small', 'fc-large']) {
            final target = find.byKey(ValueKey('picker-package-$id'));
            await tester.scrollUntilVisible(
              target,
              200,
              scrollable: topScrollable(),
            );
            final item = tester.getRect(target);
            expect(item.left, greaterThanOrEqualTo(0), reason: id);
            expect(item.right, lessThanOrEqualTo(320), reason: id);
          }
          await cancelPicker(tester);
          await newProvider(tester, 'Fits');
          expect(rowValue(tester, 'form-provider'), 'Fits');
          expect(tester.takeException(), isNull);
        });
        testWidgets('$lang 320px ${scale}x: flow and package pages fit', (
          tester,
        ) async {
          locale.value = Locale(lang);
          final package = catalog.snapshot.package('fc-small')!;
          await store.saveServer(
            ServerRecord(
              id: 'long',
              name: 'A server with a rather long name to wrap on narrow phones',
              vendor: 'Fixture Cloud',
              packageId: package.id,
              packageSnapshot: package.encodeSnapshot(),
              createdAt: now,
              updatedAt: now,
            ),
            isNew: true,
            catalogProvider: _cloudRef,
          );
          await ledger.refresh();
          final pages = <String, Widget Function()>{
            'providers': () => ProvidersPage(ledger: ledger),
            'all providers': () => AllProvidersPage(ledger: ledger),
            'package list': () =>
                PackageListPage(ledger: ledger, catalogId: 'fixture-cloud'),
            'provider details': () =>
                ProviderDetailsPage(ledger: ledger, catalogId: 'fixture-cloud'),
            'package': () => PackageDetailsPage(
              ledger: ledger,
              packageId: 'fc-small',
              server: ledger.byId('long'),
            ),
            'server detail': () => ServerDetail(controller: ledger, id: 'long'),
            'form': () => ServerForm(
              controller: ledger,
              catalogProvider: catalog.snapshot.provider('fixture-cloud'),
              initialPackage: catalog.snapshot.package('fc-large'),
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
            for (var i = 0; i < 6; i++) {
              await tester.drag(scrollable, const Offset(0, -500));
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '${entry.key} scrolled',
              );
            }
          }
        });
      }
    }
  });
}
