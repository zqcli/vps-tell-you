import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/app.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/locale_preference.dart';

import 'support/reminder_platform.dart';

/// A new ledger starts in the device language; an existing one never changes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'forNewLedger: Chinese devices get Chinese, everything else English',
    () {
      LocalePreference of(List<Locale> l) => LocalePreference.forNewLedger(l);
      expect(of([const Locale('zh')]), LocalePreference.chinese);
      expect(
        of([const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')]),
        LocalePreference.chinese,
      );
      expect(
        of([const Locale('zh', 'TW'), const Locale('en')]),
        LocalePreference.chinese,
      );
      expect(of([const Locale('en', 'US')]), LocalePreference.english);
      expect(
        of([const Locale('fr'), const Locale('de')]),
        LocalePreference.english,
      );
      expect(
        of([const Locale('fr'), const Locale('zh')]),
        LocalePreference.chinese,
      );
      expect(of([]), LocalePreference.english);
      // Never the live "system" choice: the stored value is concrete.
      expect(of([const Locale('ja')]), isNot(LocalePreference.system));
    },
  );

  test(
    'the store only calls a ledger new on the launch that created it',
    () async {
      final dir = await Directory.systemTemp.createTemp('new-ledger-');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/ledger.db';
      var store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      expect(store.isNewLedger, isTrue);
      // The schema default is still Chinese until the app applies the device's.
      expect(await store.languagePreference(), LocalePreference.chinese);
      await store.close();
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      expect(store.isNewLedger, isFalse);
      await store.close();
    },
  );

  Future<LedgerStore> open(String path) =>
      LedgerStore.open(factory: databaseFactoryFfiNoIsolate, path: path);

  Future<void> launch(
    WidgetTester tester,
    LedgerStore store,
    List<Locale>? device,
  ) async {
    await tester.pumpWidget(
      LedgerApp(
        openStore: () async => store,
        deviceLocales: device,
        reminderPlatform: FakeReminderPlatform()..supported = false,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('first launch on an English device stores and shows English', (
    tester,
  ) async {
    late Directory dir;
    late LedgerStore store;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('new-ledger-en-');
      store = await open('${dir.path}/ledger.db');
    });
    addTearDown(() => dir.delete(recursive: true));
    await launch(tester, store, [const Locale('en', 'US')]);
    expect(find.text('Servers'), findsWidgets);
    expect(find.text('服务器'), findsNothing);
    await tester.runAsync(() async {
      expect(await store.languagePreference(), LocalePreference.english);
    });
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(store.close);
  });

  testWidgets('first launch on a Chinese device stays Chinese', (tester) async {
    late Directory dir;
    late LedgerStore store;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('new-ledger-zh-');
      store = await open('${dir.path}/ledger.db');
    });
    addTearDown(() => dir.delete(recursive: true));
    await launch(tester, store, [const Locale('zh', 'CN')]);
    expect(find.text('服务器'), findsWidgets);
    await tester.runAsync(() async {
      expect(await store.languagePreference(), LocalePreference.chinese);
    });
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(store.close);
  });

  testWidgets('an existing ledger keeps its choice on any device language', (
    tester,
  ) async {
    late Directory dir;
    late LedgerStore store;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('old-ledger-');
      store = await open('${dir.path}/ledger.db');
      await store.close();
      store = await open('${dir.path}/ledger.db'); // no longer new
    });
    addTearDown(() => dir.delete(recursive: true));
    expect(store.isNewLedger, isFalse);
    await launch(tester, store, [const Locale('en', 'US')]);
    expect(find.text('服务器'), findsWidgets);
    await tester.runAsync(() async {
      expect(await store.languagePreference(), LocalePreference.chinese);
    });
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(store.close);
  });

  testWidgets('without device locales (tests, embedders) nothing changes', (
    tester,
  ) async {
    late Directory dir;
    late LedgerStore store;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('new-ledger-none-');
      store = await open('${dir.path}/ledger.db');
    });
    addTearDown(() => dir.delete(recursive: true));
    await launch(tester, store, null);
    expect(find.text('服务器'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(store.close);
  });
}
