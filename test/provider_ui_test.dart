import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/providers/provider_directory.dart';
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
  final locale = ValueNotifier<Locale>(const Locale('en'));
  final now = DateTime.utc(2026, 10, 6);

  Future<void> boot() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('vps-package-ui-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
      clock: () => now,
    );
    ledger = LedgerController(
      store,
      clock: () => now,
      directory: fixtureDirectory(),
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
        find.text('Directory'),
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

    testWidgets('directory provider is linked when the server is saved', (
      tester,
    ) async {
      await startAdd(tester);
      await pick(tester, 'form-provider', 'picker-catalog-fixture-cloud');
      expect(rowValue(tester, 'form-provider'), 'Fixture Cloud');
      // There is no package row any more, and nothing is stored yet.
      expect(find.byKey(const ValueKey('form-package')), findsNothing);
      expect(await store.providers(), isEmpty);
      await fill(tester, 'field-name', 'Linked');
      await save(tester);
      expect(find.byType(ServerDetail), findsOneWidget);
      final provider = (await store.providers()).single;
      expect(provider.catalogId, 'fixture-cloud');
      final server = (await store.servers()).single;
      expect(server.providerId, provider.id);
      expect(server.billing, BillingKind.unknown, reason: 'nothing prefilled');
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

    testWidgets('no provider is allowed', (tester) async {
      await startAdd(tester);
      await fill(tester, 'field-name', 'Loose');
      await save(tester);
      final server = (await store.servers()).single;
      expect(server.providerId, isNull);
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
      expect(row, findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await fill(tester, 'field-name', 'Reuse');
      await save(tester);
      expect(await store.providers(), hasLength(1));
      expect((await store.servers()).single.providerId, local.id);
    });

    testWidgets('without a directory only local providers are offered', (
      tester,
    ) async {
      ledger.dispose();
      ledger = LedgerController(
        store,
        clock: () => now,
        directory: ProviderDirectory.memory(),
      );
      await ledger.refresh();
      await store.saveProvider(
        ProviderRecord(id: 'mine', name: 'Mine', createdAt: now),
        isNew: true,
      );
      await ledger.refresh();
      await startAdd(tester);
      await tap(tester, 'form-provider');
      expect(find.text('Directory'), findsNothing);
      expect(
        find.byKey(const ValueKey('directory-empty-hint')),
        findsOneWidget,
      );
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

    testWidgets('switching provider abandons the pending directory choice', (
      tester,
    ) async {
      await store.saveProvider(
        ProviderRecord(id: 'mine', name: 'Mine', createdAt: now),
        isNew: true,
      );
      await ledger.refresh();
      await startAdd(tester);
      await pick(tester, 'form-provider', 'picker-catalog-fixture-cloud');
      expect(rowValue(tester, 'form-provider'), 'Fixture Cloud');
      await pick(tester, 'form-provider', 'picker-provider-mine');
      await fill(tester, 'field-name', 'Moved');
      await save(tester);
      expect((await store.servers()).single.providerId, 'mine');
      // No provider was created for the abandoned directory choice.
      expect((await store.providers()).single.id, 'mine');
    });
  });

  group('form', () {
    testWidgets('changing the provider of a saved server is a plain edit', (
      tester,
    ) async {
      await store.saveProvider(
        ProviderRecord(id: 'mine', name: 'Mine', createdAt: now),
        isNew: true,
      );
      final provider = await store.addCatalogProvider(_cloudRef);
      await store.saveServer(
        ServerRecord(
          id: 's1',
          name: 'Move me',
          vendor: 'Fixture Cloud',
          providerId: provider.id,
          createdAt: now,
          updatedAt: now,
        ),
        isNew: true,
      );
      await ledger.refresh();
      await openEditForm(tester, 's1');
      expect(rowValue(tester, 'form-provider'), 'Fixture Cloud');
      await pick(tester, 'form-provider', 'picker-provider-mine');
      await save(tester);
      expect((await store.servers()).single.providerId, 'mine');
      await openEditForm(tester, 's1');
      await pick(tester, 'form-provider', 'picker-provider-none');
      await save(tester);
      expect((await store.servers()).single.providerId, isNull);
    });
  });

  group('provider pages', () {
    Future<ServerRecord> addServerOf(String id) async {
      await store.saveServer(
        ServerRecord(
          id: id,
          name: 'Server $id',
          vendor: 'Fixture Cloud',
          host: '192.0.2.${id.length}',
          createdAt: now,
          updatedAt: now,
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
        await addServerOf('a');
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
          find.descendant(of: used, matching: find.text('1 server')),
          findsOneWidget,
        );
        // Mine + Fixture Cloud + Empty Host (directory, not added).
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('providers-all')),
            matching: find.text('3'),
          ),
          findsOneWidget,
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

        // A directory provider page offers adding it.
        await tap(tester, 'catalog-provider-empty-host');
        expect(await store.providers(), hasLength(2));
        await tap(tester, 'provider-add-catalog');
        expect(await store.providers(), hasLength(3));
        expect(
          find.byKey(const ValueKey('provider-add-catalog')),
          findsNothing,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        // Added: moved from the directory section into "my providers".
        expect(
          find.byKey(const ValueKey('catalog-provider-empty-host')),
          findsNothing,
        );
        expect(find.text('Empty Host'), findsOneWidget);
      },
    );

    testWidgets('provider page lists its servers, archived ones too', (
      tester,
    ) async {
      await addServerOf('a');
      await addServerOf('b');
      final b = ledger.byId('b')!;
      await ledger.mutate(() => store.archive(b));
      await mount(
        tester,
        ProviderDetailsPage(ledger: ledger, catalogId: 'fixture-cloud'),
      );
      expect(find.byKey(const ValueKey('provider-badge')), findsOneWidget);
      expect(find.text('Directory'), findsWidgets);
      expect(find.byKey(const ValueKey('provider-device-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('provider-device-b')), findsOneWidget);
      expect(find.textContaining('Archived Records'), findsOneWidget);
      await tap(tester, 'provider-device-a');
      expect(find.byType(ServerDetail), findsOneWidget);
    });

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
      expect(find.byKey(const ValueKey('provider-add-server')), findsOneWidget);
    });

    testWidgets('server detail links to the provider page', (tester) async {
      await addServerOf('a');
      await mount(tester, ServerDetail(controller: ledger, id: 'a'));
      await reveal(tester, 'server-provider-link');
      expect(find.byKey(const ValueKey('server-package-link')), findsNothing);
      expect(find.text('Provider and package'), findsNothing);
      await tap(tester, 'server-provider-link');
      expect(find.byType(ProviderDetailsPage), findsOneWidget);
      expect(find.byKey(const ValueKey('provider-device-a')), findsOneWidget);
    });
  });

  group('layout and languages', () {
    for (final lang in ['en', 'zh']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$lang 320px ${scale}x: provider picker fits', (
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
          await cancelPicker(tester);
          await newProvider(tester, 'Fits');
          expect(rowValue(tester, 'form-provider'), 'Fits');
          expect(tester.takeException(), isNull);
        });
        testWidgets('$lang 320px ${scale}x: provider pages fit', (
          tester,
        ) async {
          locale.value = Locale(lang);
          await store.saveServer(
            ServerRecord(
              id: 'long',
              name: 'A server with a rather long name to wrap on narrow phones',
              vendor: 'Fixture Cloud',
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
            'provider details': () =>
                ProviderDetailsPage(ledger: ledger, catalogId: 'fixture-cloud'),
            'server detail': () => ServerDetail(controller: ledger, id: 'long'),
            'form': () => ServerForm(
              controller: ledger,
              catalogProvider: const CatalogProviderRef(
                catalogId: 'fixture-cloud',
                name: 'Fixture Cloud',
              ),
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
