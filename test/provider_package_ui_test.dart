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

  group('add flow', () {
    testWidgets(
      'catalog provider: default package is preselected and prefills the form',
      (tester) async {
        await startAdd(tester);
        expect(find.byType(AddServerPage), findsOneWidget);
        expect(
          find.byKey(const ValueKey('choose-catalog-fixture-cloud')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('choose-catalog-empty-host')),
          findsOneWidget,
        );
        // Nothing is stored just by browsing.
        expect(await store.providers(), isEmpty);

        await tap(tester, 'choose-catalog-fixture-cloud');
        expect(find.byType(PackageChoicePage), findsOneWidget);
        final small = find.byKey(const ValueKey('choose-package-fc-small'));
        expect(
          find.descendant(of: small, matching: find.text('Default')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: small,
            matching: find.byIcon(Icons.check_rounded),
          ),
          findsOneWidget,
        );
        expect(find.text('No Package'), findsOneWidget);
        // Specs and price are visible on the row.
        expect(find.textContaining('12.00 USD'), findsWidgets);
        expect(find.textContaining('2 vCPU'), findsWidgets);

        await tap(tester, 'package-continue');
        expect(find.byType(ServerForm), findsOneWidget);
        expect(
          tester
              .widget<AppFormRow>(find.byKey(const ValueKey('form-provider')))
              .value,
          'Fixture Cloud',
        );
        expect(
          tester
              .widget<AppFormRow>(find.byKey(const ValueKey('form-package')))
              .value,
          'Small',
        );
        expect(fieldText(tester, 'field-amount'), '12.00');
        expect(fieldText(tester, 'field-region'), 'Fixture Region');
        expect(fieldText(tester, 'resource-ramBytes'), '2');
        expect(fieldText(tester, 'resource-diskBytes'), '40');
        // Still nothing in the ledger until the form is saved.
        expect(await store.providers(), isEmpty);

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
      await tap(tester, 'choose-catalog-fixture-cloud');
      await tap(tester, 'choose-package-fc-large');
      await tap(tester, 'package-continue');
      expect(fieldText(tester, 'field-amount'), '96.00');
      await fill(tester, 'field-name', 'Large');
      await save(tester);
      final server = (await store.servers()).single;
      expect(server.packageId, 'fc-large');
      expect(server.cycleMonths, 12);
      expect(server.resources!.trafficUnlimited, isTrue);
      expect(server.resources!.vcpu, 8);
    });

    testWidgets('No Package keeps the provider but leaves the form empty', (
      tester,
    ) async {
      await startAdd(tester);
      await tap(tester, 'choose-catalog-fixture-cloud');
      await tap(tester, 'choose-package-none');
      await tap(tester, 'package-continue');
      expect(
        tester
            .widget<AppFormRow>(find.byKey(const ValueKey('form-package')))
            .value,
        isNull,
      );
      expect(find.byKey(const ValueKey('field-amount')), findsNothing);
      await fill(tester, 'field-name', 'No package');
      await save(tester);
      final server = (await store.servers()).single;
      expect(server.packageId, isNull);
      expect(server.packageSnapshot, isNull);
      expect(server.providerId, (await store.providers()).single.id);
      expect(server.billing, BillingKind.unknown);
    });

    testWidgets(
      'cancelling the form leaves the package page and creates nothing',
      (tester) async {
        await startAdd(tester);
        await tap(tester, 'choose-catalog-fixture-cloud');
        await tap(tester, 'package-continue');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(PackageChoicePage), findsOneWidget);
        expect(await store.providers(), isEmpty);
        expect(await store.servers(), isEmpty);
      },
    );

    testWidgets(
      'a catalog provider without packages goes straight to the form',
      (tester) async {
        await startAdd(tester);
        await tap(tester, 'choose-catalog-empty-host');
        expect(find.byType(PackageChoicePage), findsNothing);
        expect(find.byType(ServerForm), findsOneWidget);
        final row = tester.widget<AppFormRow>(
          find.byKey(const ValueKey('form-package')),
        );
        expect(row.placeholder, 'No package list');
        expect(row.onTap, isNull);
        await fill(tester, 'field-name', 'Plain');
        await save(tester);
        final server = (await store.servers()).single;
        expect(server.packageId, isNull);
        expect((await store.providers()).single.catalogId, 'empty-host');
      },
    );

    testWidgets('a user-created provider has no package step', (tester) async {
      await startAdd(tester);
      await tap(tester, 'choose-provider-add');
      await fill(tester, 'provider-name', 'My Host');
      await tap(tester, 'provider-save');
      expect(find.byType(PackageChoicePage), findsNothing);
      expect(find.byType(ServerForm), findsOneWidget);
      expect(
        tester
            .widget<AppFormRow>(find.byKey(const ValueKey('form-provider')))
            .value,
        'My Host',
      );
      await fill(tester, 'field-name', 'Custom');
      await save(tester);
      final provider = (await store.providers()).single;
      expect(provider.catalogId, isNull);
      expect((await store.servers()).single.providerId, provider.id);
    });

    testWidgets('no provider and no package is allowed', (tester) async {
      await startAdd(tester);
      await tap(tester, 'choose-provider-unspecified');
      await fill(tester, 'field-name', 'Loose');
      await save(tester);
      final server = (await store.servers()).single;
      expect(server.providerId, isNull);
      expect(server.packageId, isNull);
      expect(await store.providers(), isEmpty);
    });

    testWidgets('an existing local provider is reused, not duplicated', (
      tester,
    ) async {
      await store.addCatalogProvider(_cloudRef);
      await ledger.refresh();
      await startAdd(tester);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget, reason: 'added');
      await tap(tester, 'choose-catalog-fixture-cloud');
      await tap(tester, 'package-continue');
      await fill(tester, 'field-name', 'Reuse');
      await save(tester);
      expect(await store.providers(), hasLength(1));
      expect(
        (await store.servers()).single.providerId,
        (await store.providers()).single.id,
      );
    });

    testWidgets('a failed catalog leaves only local providers, with retry', (
      tester,
    ) async {
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
      expect(
        find.textContaining('package catalog couldn’t be loaded'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('catalog-retry')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('choose-catalog-fixture-cloud')),
        findsNothing,
      );
      await tap(tester, 'choose-provider-mine');
      expect(find.byType(ServerForm), findsOneWidget);
      await fill(tester, 'field-name', 'Offline');
      await save(tester);
      expect((await store.servers()).single.providerId, 'mine');
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
        expect(
          tester
              .widget<AppFormRow>(find.byKey(const ValueKey('form-package')))
              .value,
          'Small',
        );
        await tap(tester, 'form-package');
        await tap(tester, 'form-package-fc-nano');
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
        await tap(tester, 'form-package');
        await tap(tester, 'form-package-none');
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
        await tap(tester, 'form-provider');
        await tap(tester, 'choose-provider-mine');
        expect(
          tester
              .widget<AppFormRow>(find.byKey(const ValueKey('form-package')))
              .value,
          isNull,
        );
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
      'providers page lists mine and the catalog providers not yet added',
      (tester) async {
        await store.saveProvider(
          ProviderRecord(id: 'mine', name: 'Mine', createdAt: now),
          isNew: true,
        );
        await ledger.refresh();
        await mount(tester, ProvidersPage(ledger: ledger));
        expect(find.byKey(const ValueKey('provider-mine')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('catalog-provider-fixture-cloud')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('catalog-provider-empty-host')),
          findsOneWidget,
        );
        expect(find.text('3 packages'), findsOneWidget);

        // The catalog provider page shows its packages and offers adding it.
        await tap(tester, 'catalog-provider-fixture-cloud');
        expect(
          find.byKey(const ValueKey('provider-package-fc-small')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('provider-package-fc-small')),
            matching: find.text('Default'),
          ),
          findsOneWidget,
        );
        expect(await store.providers(), hasLength(1));
        await tap(tester, 'provider-add-catalog');
        expect(await store.providers(), hasLength(2));
        expect(
          find.byKey(const ValueKey('provider-add-catalog')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('provider-package-fc-small')),
          findsOneWidget,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        // Added: moved from the catalog section into "my providers".
        expect(
          find.byKey(const ValueKey('catalog-provider-fixture-cloud')),
          findsNothing,
        );
        expect(find.text('Fixture Cloud'), findsOneWidget);
      },
    );

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
      expect(find.byKey(const ValueKey('provider-device-a')), findsOneWidget);
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
            'add': () => AddServerPage(ledger: ledger),
            'package choice': () => PackageChoicePage(
              ledger: ledger,
              selection: ProviderSelection(
                ledger.localProviderForCatalog('fixture-cloud'),
                catalog: catalog.snapshot.provider('fixture-cloud'),
              ),
            ),
            'providers': () => ProvidersPage(ledger: ledger),
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
