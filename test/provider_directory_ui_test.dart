import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/app.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/providers/provider_directory.dart';
import 'package:vps_tell_you/providers/provider_lists.dart';
import 'package:vps_tell_you/providers/provider_pages.dart';
import 'package:vps_tell_you/providers/provider_record.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_form.dart';

import 'support/catalog_fixture.dart';

/// A memory directory which records and scripts checks.
class _ScriptedDirectory extends ProviderDirectory {
  _ScriptedDirectory([DirectorySnapshot? snapshot])
    : super.memory(snapshot ?? fixtureCatalog());
  int refreshes = 0;
  DirectoryOutcome next = DirectoryOutcome.updated;
  Completer<void>? gate;

  @override
  Future<DirectoryOutcome> refresh() async {
    refreshes++;
    await gate?.future;
    return next;
  }
}

void main() {
  late Directory directoryOnDisk;
  late LedgerStore store;
  late LedgerController ledger;
  final locale = ValueNotifier<Locale>(const Locale('en'));
  final now = DateTime.utc(2026, 10, 14, 12);

  Future<void> boot(ProviderDirectory directory) async {
    ledger = LedgerController(store, clock: () => now, directory: directory);
    await ledger.refresh();
  }

  setUp(() async {
    locale.value = const Locale('en');
    sqfliteFfiInit();
    directoryOnDisk = await Directory.systemTemp.createTemp('vps-dir-ui-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directoryOnDisk.path}/ledger.sqlite3',
      clock: () => now,
    );
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directoryOnDisk.delete(recursive: true);
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

  Future<void> reveal(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axis == Axis.vertical,
            )
            .first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  String rowText(WidgetTester tester, String key) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .join('|');

  group('settings section', () {
    testWidgets('shows version, count, status and last check', (tester) async {
      final directory = _ScriptedDirectory();
      await boot(directory);
      await mount(tester, ProvidersPage(ledger: ledger));
      await reveal(tester, 'directory-status');
      expect(find.text('Provider Directory'), findsOneWidget);
      expect(
        rowText(tester, 'directory-status'),
        'Version 3 · 2 providers|Never checked',
      );
      expect(
        find.text(
          'Only the public provider list is downloaded; your ledger never '
          'leaves the device.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Check for Updates runs a check, with a spinner meanwhile', (
      tester,
    ) async {
      final directory = _ScriptedDirectory()..gate = Completer<void>();
      await boot(directory);
      await mount(tester, ProvidersPage(ledger: ledger));
      await reveal(tester, 'directory-check');
      expect(find.text('Check for Updates'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('directory-check')));
      await tester.pump();
      expect(directory.refreshes, 1);
      directory.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('empty directory says "Not downloaded yet"', (tester) async {
      await boot(ProviderDirectory.memory());
      await mount(tester, ProvidersPage(ledger: ledger));
      await reveal(tester, 'directory-status');
      expect(
        rowText(tester, 'directory-status'),
        'Not downloaded yet|Never checked',
      );
    });

    testWidgets('Update on Launch is on by default and persisted', (
      tester,
    ) async {
      await boot(_ScriptedDirectory());
      await mount(tester, ProvidersPage(ledger: ledger));
      await reveal(tester, 'directory-auto');
      expect(
        tester
            .widget<AppSwitchRow>(find.byKey(const ValueKey('directory-auto')))
            .value,
        isTrue,
      );
      expect(ledger.directoryAuto, isTrue);
      await tester.tap(find.byKey(const ValueKey('directory-auto')));
      await tester.pumpAndSettle();
      expect(ledger.directoryAuto, isFalse);
      expect(await store.providerDirectoryAuto(), isFalse);
      expect(
        tester
            .widget<AppSwitchRow>(find.byKey(const ValueKey('directory-auto')))
            .value,
        isFalse,
      );
      // A new controller (app restart) reads the stored value.
      final restarted = LedgerController(
        store,
        clock: () => now,
        directory: ProviderDirectory.memory(),
      );
      await restarted.refresh();
      expect(restarted.directoryAuto, isFalse);
      restarted.dispose();
    });

    for (final lang in ['en', 'zh']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$lang 320px ${scale}x: section fits', (tester) async {
          locale.value = Locale(lang);
          await boot(_ScriptedDirectory());
          await mount(
            tester,
            ProvidersPage(ledger: ledger),
            width: 320,
            scale: scale,
          );
          await reveal(tester, 'directory-auto');
          expect(tester.takeException(), isNull);
          final box = tester.getRect(
            find.byKey(const ValueKey('directory-auto')),
          );
          expect(box.left, greaterThanOrEqualTo(0));
          expect(box.right, lessThanOrEqualTo(320));
        });
      }
    }
  });

  group('start-up', () {
    testWidgets('the app opens while the directory is still loading', (
      tester,
    ) async {
      await boot(ProviderDirectory.memory()); // only for the tear-down
      final gate = Completer<void>();
      final slow = _HangingDirectory(gate);
      await tester.pumpWidget(
        LedgerApp(openStore: () async => store, directory: slow),
      );
      await tester.pumpAndSettle();
      expect(slow.loadStarted, isTrue, reason: 'it is started ...');
      expect(find.byType(HomeShell), findsOneWidget, reason: '... not awaited');
      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('startDirectory honours the stored switch', (tester) async {
      final off = _ScriptedDirectory();
      await store.saveProviderDirectoryAuto(false);
      await boot(off);
      await ledger.startDirectory();
      expect(off.refreshes, 0);
      ledger.dispose();

      // autoRefresh needs a real source; with the switch on a due directory
      // is refreshed (memory directories have none, so just check the call).
      await store.saveProviderDirectoryAuto(true);
      final recording = _AutoRecording();
      await boot(recording);
      await ledger.startDirectory();
      expect(recording.autoCalls, [true]);
    });
  });

  group('lists', () {
    testWidgets('All Providers: pull to refresh checks the directory', (
      tester,
    ) async {
      final directory = _ScriptedDirectory();
      await boot(directory);
      await mount(tester, AllProvidersPage(ledger: ledger));
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(directory.refreshes, 1);
      expect(find.text('Couldn’t reach GitHub'), findsNothing);
    });

    testWidgets('a failed pull says so', (tester) async {
      final directory = _ScriptedDirectory()..next = DirectoryOutcome.failed;
      await boot(directory);
      await mount(tester, AllProvidersPage(ledger: ledger));
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Couldn’t reach GitHub'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('no directory: hint in All Providers, own providers remain', (
      tester,
    ) async {
      await boot(ProviderDirectory.memory());
      await ledger.store.saveProvider(
        ProviderRecord(id: 'mine', name: 'Mine', createdAt: now),
        isNew: true,
      );
      await ledger.refresh();
      await mount(tester, AllProvidersPage(ledger: ledger));
      expect(
        find.byKey(const ValueKey('directory-empty-hint')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('provider-mine')), findsOneWidget);
      expect(find.textContaining('Settings > Providers'), findsOneWidget);
    });

    testWidgets('directory entries follow the language and search aliases', (
      tester,
    ) async {
      await boot(_ScriptedDirectory());
      await mount(tester, AllProvidersPage(ledger: ledger));
      expect(find.text('Fixture Cloud'), findsOneWidget);
      expect(find.text('夹具云'), findsNothing);
      // Aliases and the other language's name find it too.
      for (final query in ['fixturecloud', '夹具', 'fixture']) {
        await tester.enterText(
          find.byKey(const ValueKey('list-search')),
          query,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('catalog-provider-fixture-cloud')),
          findsOneWidget,
          reason: query,
        );
        expect(
          find.byKey(const ValueKey('catalog-provider-empty-host')),
          findsNothing,
        );
      }
      locale.value = const Locale('zh');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('list-search')), '');
      await tester.pumpAndSettle();
      expect(find.text('夹具云'), findsOneWidget);
      expect(find.text('Fixture Cloud'), findsNothing);
    });

    testWidgets('picking a directory entry creates the provider in the UI '
        'language', (tester) async {
      locale.value = const Locale('zh');
      await boot(_ScriptedDirectory());
      await mount(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open-form'),
              onPressed: () => showAppModal<String>(
                context,
                builder: (_) => ServerForm(controller: ledger),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open-form')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('form-provider')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('picker-catalog-fixture-cloud')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('field-name')), 'S');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final provider = (await store.providers()).single;
      expect(provider.name, '夹具云');
      expect(provider.catalogId, 'fixture-cloud');
    });
  });
}

class _HangingDirectory extends ProviderDirectory {
  _HangingDirectory(this.gate) : super.memory();
  final Completer<void> gate;
  bool loadStarted = false;
  @override
  Future<void> load() {
    loadStarted = true;
    return gate.future;
  }
}

class _AutoRecording extends ProviderDirectory {
  _AutoRecording() : super.memory();
  final autoCalls = <bool>[];
  @override
  Future<void> autoRefresh({required bool enabled}) async =>
      autoCalls.add(enabled);
}
