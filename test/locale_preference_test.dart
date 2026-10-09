import 'support/provider_fixture.dart';

import 'dart:io';
import 'dart:async';
import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/app.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/l10n/locale_preference.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_form.dart';
import 'package:vps_tell_you/settings/settings_page.dart';

import 'security_store_test.dart' show FakeDeviceAuth, FakeSecretStore;
import 'support/reminder_platform.dart';

class CountingCloudController extends CloudController {
  CountingCloudController({required super.store, required super.secrets});
  int reloads = 0;
  Completer<void>? reloadGate;
  Completer<void>? reloadStarted;
  @override
  Future<bool> reload() async {
    reloads++;
    reloadStarted?.complete();
    await reloadGate?.future;
    return super.reload();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('stable preferences and explicit system fallback', () {
    expect(LocalePreference.fromStorage(null), LocalePreference.chinese);
    expect(
      LocalePreference.fromStorage('unsupported'),
      LocalePreference.chinese,
    );
    expect(LocalePreference.fromStorage('en'), LocalePreference.english);
    expect(
      LocalePreference.chinese.resolve([const Locale('en')]),
      const Locale('zh'),
    );
    expect(
      LocalePreference.english.resolve([const Locale('zh')]),
      const Locale('en'),
    );
    expect(
      LocalePreference.system.resolve([const Locale('zh', 'TW')]),
      const Locale('zh'),
    );
    expect(
      LocalePreference.system.resolve([const Locale('en', 'GB')]),
      const Locale('en'),
    );
    expect(
      LocalePreference.system.resolve([const Locale('fr'), const Locale('zh')]),
      const Locale('zh'),
    );
    expect(
      LocalePreference.system.resolve([const Locale('fr')]),
      const Locale('en'),
    );
    expect(LocalePreference.system.resolve([]), const Locale('en'));
  });

  test(
    'version 8 preference migration preserves ledger data and defaults Chinese',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'locale-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/ledger.db';
      final raw = await databaseFactoryFfiNoIsolate.openDatabase(path);
      await LedgerStore.createSchema(raw);
      await removeProviderSchema(raw);
      await raw.execute('ALTER TABLE app_settings DROP COLUMN language');
      await raw.setVersion(8);
      await raw.insert('server_groups', {
        'id': 'custom-group',
        'name': '用户原始名称',
        'position': 0,
      });
      await raw.close();
      var store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      expect(await store.languagePreference(), LocalePreference.chinese);
      expect((await store.groups()).single.name, '用户原始名称');
      final before = await store.exportLedgerBackup();
      await store.saveLanguagePreference(LocalePreference.english);
      final after = await store.exportLedgerBackup();
      expect(after.groups, before.groups);
      expect(after.fx, before.fx);
      await store.close();
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      expect(await store.languagePreference(), LocalePreference.english);
      expect((await store.groups()).single.name, '用户原始名称');
      await store.close();
    },
  );

  test('changing locale keeps controllers and domain snapshots, without panel reload', () async {
    final directory = await Directory.systemTemp.createTemp(
      'locale-no-reload-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.db',
    );
    final secrets = FakeSecretStore();
    final security = SecurityController(
      store: store,
      secrets: secrets,
      authenticator: FakeDeviceAuth(),
    );
    final cloud = CountingCloudController(store: store, secrets: secrets);
    final controller = LedgerController(
      store,
      security: security,
      cloud: cloud,
      reminderPlatform: FakeReminderPlatform()..supported = false,
    );
    await controller.refresh();
    final records = controller.records;
    final reloads = cloud.reloads;
    await controller.setLanguage(LocalePreference.english);
    expect(controller.languagePreference, LocalePreference.english);
    expect(identical(controller.records, records), isTrue);
    expect(identical(controller.cloud, cloud), isTrue);
    expect(identical(controller.security, security), isTrue);
    expect(cloud.reloads, reloads);
    expect(secrets.values, isEmpty);
    cloud.reloadStarted = Completer<void>();
    cloud.reloadGate = Completer<void>();
    final earlierRefresh = controller.refresh();
    await cloud.reloadStarted!.future;
    await controller.setLanguage(LocalePreference.chinese);
    cloud.reloadGate!.complete();
    await earlierRefresh;
    expect(controller.languagePreference, LocalePreference.chinese);
    expect(await store.languagePreference(), LocalePreference.chinese);
    controller.dispose();
    await store.close();
  });

  testWidgets('settings switches immediately and a relaunch restores English', (
    tester,
  ) async {
    late Directory directory;
    late LedgerStore store;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('locale-settings-');
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${directory.path}/ledger.db',
      );
    });
    addTearDown(() => directory.delete(recursive: true));
    Future<LedgerStore> open() async => store;
    await tester.pumpWidget(
      LedgerApp(
        openStore: open,
        reminderPlatform: FakeReminderPlatform()..supported = false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('服务器'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('tab-3')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('language-setting')));
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    try {
      await tester.tap(find.byKey(const ValueKey('language-setting')));
      await tester.pumpAndSettle();
      for (final preference in LocalePreference.values) {
        final node = tester.getSemantics(
          find.byKey(ValueKey('language-${preference.storageValue}')),
        );
        expect(node.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
        expect(
          node.flagsCollection.isChecked,
          preference == LocalePreference.chinese
              ? CheckedState.isTrue
              : CheckedState.isFalse,
        );
      }
    } finally {
      semantics.dispose();
    }
    await tester.tap(find.byKey(const ValueKey('language-en')));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);
    final current = tester.widget<HomeShell>(find.byType(HomeShell)).controller;
    expect(await current.store.languagePreference(), LocalePreference.english);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await store.close();
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${directory.path}/ledger.db',
      );
    });
    await tester.pumpWidget(
      LedgerApp(
        openStore: open,
        reminderPlatform: FakeReminderPlatform()..supported = false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    final relaunched = tester
        .widget<HomeShell>(find.byType(HomeShell))
        .controller;
    expect(relaunched, isNot(same(current)));
    expect(relaunched.languagePreference, LocalePreference.english);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(store.close);
  });

  testWidgets(
    'switching language preserves an open server form draft and route',
    (tester) async {
      late Directory directory;
      late LedgerStore store;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('locale-draft-');
        store = await LedgerStore.open(
          factory: databaseFactoryFfiNoIsolate,
          path: '${directory.path}/ledger.db',
        );
      });
      addTearDown(() => directory.delete(recursive: true));
      final controller = LedgerController(
        store,
        reminderPlatform: FakeReminderPlatform()..supported = false,
      );
      await controller.refresh();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: controller,
          builder: (_, child) => MaterialApp(
            navigatorKey: navigator,
            locale: controller.languagePreference.resolve(const [Locale('zh')]),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsPage(controller: controller),
          ),
        ),
      );
      navigator.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => ServerForm(controller: controller)),
      );
      await tester.pumpAndSettle();
      final field = find.byType(TextFormField).first;
      await tester.enterText(field, 'User draft 原样保留');
      final state = tester.state(find.byType(ServerForm));
      final input = tester.widget<TextFormField>(field).controller;
      final route = ModalRoute.of(tester.element(find.byType(ServerForm)));
      final navigation = navigator.currentState;
      await controller.setLanguage(LocalePreference.english);
      await tester.pumpAndSettle();
      expect(identical(tester.state(find.byType(ServerForm)), state), isTrue);
      expect(
        tester.widget<ServerForm>(find.byType(ServerForm)).controller,
        same(controller),
      );
      expect(tester.widget<TextFormField>(field).controller, same(input));
      expect(
        ModalRoute.of(tester.element(find.byType(ServerForm))),
        same(route),
      );
      expect(navigator.currentState, same(navigation));
      expect(find.text('User draft 原样保留'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isTrue);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await store.close();
    },
  );
}
