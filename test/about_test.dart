import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_info.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/settings/about_page.dart';
import 'package:vps_tell_you/settings/changelog.dart';
import 'package:vps_tell_you/settings/changelog_page.dart';
import 'package:vps_tell_you/settings/open_source_page.dart';
import 'package:vps_tell_you/settings/settings_page.dart';

import 'security_store_test.dart' show FakeDeviceAuth, FakeSecretStore;
import 'support/reminder_platform.dart';

/// Asset reads finish in real time, which `pumpAndSettle` never waits for
/// (the loading spinner would animate forever): poll until it is gone.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 200; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (find.byType(CupertinoActivityIndicator).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle();
}

Future<void> mount(
  WidgetTester tester,
  Widget home, {
  String locale = 'en',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: appTheme(),
      home: home,
    ),
  );
  await settle(tester);
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await settle(tester);
}

/// Registry with a few synthetic packages (the flutter_test binding has no
/// NOTICES asset).
void fakeRegistry() {
  LicenseRegistry.reset();
  LicenseRegistry.addLicense(
    () => Stream.fromIterable([
      LicenseEntryWithLineBreaks(['intl'], 'FAKE INTL LICENSE TEXT'),
      LicenseEntryWithLineBreaks(['alpha_pkg'], 'Alpha license body'),
      LicenseEntryWithLineBreaks([
        'beta_pkg',
        'gamma_pkg',
      ], 'Shared beta gamma text'),
    ]),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(fakeRegistry);
  tearDown(LicenseRegistry.reset);

  group('changelog parser', () {
    test(
      'releases, sections, bullets, continuations, paragraphs, comments',
      () {
        final releases = parseChangelog('''
# Title

<!-- hidden
- not a bullet
-->
## 1.0.0 — Unreleased

Intro paragraph
over two lines.

### Added

- First **bold** item
  continued here
- Second item <!-- inline --> kept

### Removed

- Gone

## 0.9.0

### Added

- Old
''');
        expect(releases.map((r) => r.title), ['1.0.0 — Unreleased', '0.9.0']);
        final first = releases.first.sections;
        expect(first.map((s) => s.title), [null, 'Added', 'Removed']);
        expect(first[0].items.single.bullet, isFalse);
        expect(first[0].items.single.text, 'Intro paragraph over two lines.');
        expect(first[1].items.map((i) => i.text), [
          'First **bold** item continued here',
          'Second item  kept',
        ]);
        expect(first[2].items.single.text, 'Gone');
        expect(releases.last.sections.single.items.single.text, 'Old');
      },
    );

    test('parseBold splits at ** markers and keeps unmatched ones literal', () {
      expect(parseBold('a **b** c'), [
        ('a ', false),
        ('b', true),
        (' c', false),
      ]);
      expect(parseBold('a ** b'), [('a ** b', false)]);
    });

    for (final (file, titles) in [
      ('CHANGELOG.md', ['新增', '变更', '移除']),
      ('CHANGELOG.en.md', ['Added', 'Changed', 'Removed']),
    ]) {
      test(
        '$file: newest release is well formed, 0.5.0 keeps 15–25 bullets',
        () {
          final releases = parseChangelog(File(file).readAsStringSync());
          expect(releases, isNotEmpty);
          // Newest first; every release only uses the known section titles.
          for (final release in releases) {
            expect(
              release.sections.map((s) => s.title),
              everyElement(isIn(titles)),
            );
            expect(release.sections, isNotEmpty);
          }
          expect(releases.first.title, matches(RegExp(r'^\d+\.\d+\.\d+ — ')));
          final v05 = releases.singleWhere(
            (r) => r.title.startsWith('0.5.0 — '),
          );
          expect(v05.sections.map((s) => s.title), titles);
          final bullets = v05.sections.fold<int>(
            0,
            (n, s) => n + s.items.where((i) => i.bullet).length,
          );
          expect(bullets, inInclusiveRange(15, 25));
          // The how-to comment never leaks into the content.
          expect(
            releases
                .expand((r) => r.sections)
                .expand((s) => s.items)
                .map((i) => i.text),
            everyElement(isNot(contains('<!--'))),
          );
        },
      );
    }
  });

  test('releases sort by version and expose tag, label and counts', () {
    final releases = parseChangelog(
      '## 0.9.0 — 2026-01-01\n- a\n## 0.10.0 — Unreleased\n### Added\n- b\n- c\n'
      '## 0.2.0 — 2025-01-01\n- d\n',
    );
    expect(releases.map((r) => r.version), ['0.10.0', '0.9.0', '0.2.0']);
    expect(releases.first.label, 'Unreleased');
    expect(releases.first.released, isFalse);
    expect(releases.first.bulletCount, 2);
    expect(releases[1].released, isTrue);
    expect(releases[1].tag, 'v0.9.0');
  });

  group('changelog page (real assets)', () {
    testWidgets('zh: versions newest first, a version opens its details', (
      tester,
    ) async {
      await mount(tester, const ChangelogPage(), locale: 'zh');
      expect(find.text('更新记录'), findsOneWidget);
      double top(String v) =>
          tester.getTopLeft(find.byKey(ValueKey('changelog-$v'))).dy;
      expect(top('0.6.0'), lessThan(top('0.5.0')));
      expect(find.text('2026-10-16'), findsOneWidget);
      expect(find.text('2026-10-20'), findsOneWidget);
      expect(find.text('当前版本'), findsOneWidget); // kAppVersion's row
      await tester.tap(find.byKey(const ValueKey('changelog-0.5.0')));
      await tester.pumpAndSettle();
      expect(find.byType(ChangelogReleasePage), findsOneWidget);
      expect(find.text('新增'), findsWidgets);
      expect(find.textContaining('服务器台账', findRichText: true), findsOneWidget);
      // Released versions point at their GitHub tag (last row of the page).
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('changelog-github-release')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('v0.5.0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('en: the store build is dated and has no unreleased entry', (
      tester,
    ) async {
      await mount(tester, const ChangelogPage(), locale: 'en');
      expect(find.text('What’s New'), findsOneWidget);
      expect(find.text('Unreleased'), findsNothing);
      expect(find.text('2026-10-20'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('changelog-0.6.0')));
      await tester.pumpAndSettle();
      expect(find.byType(ChangelogReleasePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unsupported locale falls back to Chinese', (tester) async {
      expect(changelogAsset('fr'), 'CHANGELOG.md');
      expect(changelogAsset('en'), 'CHANGELOG.en.md');
    });

    testWidgets('a failing load shows the message', (tester) async {
      await mount(
        tester,
        ChangelogPage(load: (_) async => throw StateError('no asset')),
      );
      expect(find.text('Couldn’t load the changelog.'), findsOneWidget);
    });
  });

  group('about page', () {
    testWidgets('header, rows and footnotes', (tester) async {
      await mount(tester, const AboutPage());
      expect(find.byType(AppLogo), findsOneWidget);
      expect(find.text('VPS Tell You'), findsOneWidget);
      expect(find.text('Version 0.6.0'), findsOneWidget);
      expect(find.text('Know every VPS at a glance'), findsOneWidget);
      expect(find.text('What’s New'), findsOneWidget);
      expect(find.text('Source Code'), findsOneWidget);
      expect(find.text('github.com/zqcli/vps-tell-you'), findsOneWidget);
      expect(find.text('License'), findsOneWidget);
      expect(find.text('MIT'), findsOneWidget);
      expect(find.text('Open-Source Components'), findsOneWidget);
      expect(
        find.textContaining('No ads, no purchases, no account'),
        findsOneWidget,
      );
      expect(
        find.textContaining('SSH, SFTP, or TCP connection'),
        findsOneWidget,
      );
      expect(find.textContaining('donation'), findsNothing);
      expect(find.textContaining('belong to their owners'), findsOneWidget);
    });

    testWidgets('source code row copies the repo URL and toasts', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await mount(tester, const AboutPage());
      await tester.tap(find.byKey(const ValueKey('about-source')));
      await tester.pump();
      expect(copied, kRepoUrl);
      expect(find.text('Source code link copied'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    // Only navigation is checked here (no waiting for the asset reads, which
    // the page tests below cover): the flutter_test asset channel does not
    // answer a second read of the same asset reliably.
    testWidgets('rows navigate to changelog, license and components', (
      tester,
    ) async {
      Future<void> open(String key, Type page) async {
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(page), findsOneWidget);
        Navigator.pop(tester.element(find.byType(page)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(page), findsNothing);
      }

      await mount(tester, const AboutPage());
      await open('about-changelog', ChangelogPage);
      await open('about-license', LicenseTextPage);
      await open('about-open-source', OpenSourcePage);
    });

    testWidgets('licence page shows the bundled MIT text, selectable', (
      tester,
    ) async {
      await mount(tester, const LicenseTextPage());
      final text = tester.widget<SelectableText>(
        find.byKey(const ValueKey('license-text')),
      );
      final body = text.data!;
      expect(body, startsWith('MIT License'));
      expect(body, contains('Copyright (c) 2026 zqcli and contributors'));
      expect(body, contains('Permission is hereby granted, free of charge'));
      expect(body, contains('THE SOFTWARE IS PROVIDED "AS IS"'));
      // Paragraph lines are re-flowed; paragraphs stay separate.
      expect(body, isNot(contains('copy\nof this')));
      expect(body.split('\n\n'), hasLength(5));
      expect(text.style?.fontFamily, kMonoTextStyle.fontFamily);
    });

    testWidgets('licence page reports a load failure', (tester) async {
      await mount(
        tester,
        LicenseTextPage(load: () async => throw StateError('x')),
      );
      expect(find.text('Couldn’t load the license text.'), findsOneWidget);
    });
  });

  group('open-source components', () {
    test('curated list covers every direct dependency and the font', () {
      final names = kOpenSourceComponents.map((c) => c.name).toSet();
      expect(kOpenSourceComponents, hasLength(20));
      expect(names, hasLength(20));
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final dependencies = RegExp(r'^  ([a-z_0-9]+):', multiLine: true)
          .allMatches(
            pubspec.substring(
              pubspec.indexOf('\ndependencies:'),
              pubspec.indexOf('\ndev_dependencies:'),
            ),
          )
          .map((m) => m[1]!);
      // local_auth_android / local_auth_darwin are listed under local_auth.
      final covered = {
        ...names,
        ...kOpenSourceComponents.expand((c) => c.lookup),
        'flutter',
      };
      for (final dependency in dependencies) {
        if (dependency == 'sdk') continue;
        expect(covered, contains(dependency), reason: dependency);
      }
      expect(names, contains('DejaVu Sans Mono'));
      expect(
        kOpenSourceComponents
            .firstWhere((c) => c.name == 'flutter_timezone')
            .license,
        'Apache-2.0',
      );
      for (final c in kOpenSourceComponents) {
        expect(c.purpose(AppLocalizationsZh()), isNotEmpty, reason: c.name);
        expect(c.purpose(AppLocalizationsEn()), isNotEmpty, reason: c.name);
      }
    });

    testWidgets('list shows names, purposes and licence ids', (tester) async {
      await mount(tester, OpenSourcePage(index: LicenseIndex()));
      expect(find.text('Open-Source Components'), findsOneWidget);
      expect(find.text('intl'), findsOneWidget);
      expect(find.text('Date, number and message formatting'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('oss-all-licenses')));
      expect(find.text('All Licenses (4)'), findsOneWidget);
    });

    testWidgets('a component opens its licence text from the registry', (
      tester,
    ) async {
      await mount(tester, OpenSourcePage(index: LicenseIndex()));
      await tester.tap(find.byKey(const ValueKey('oss-intl')));
      await settle(tester);
      expect(find.byType(ComponentLicensePage), findsOneWidget);
      expect(find.text('FAKE INTL LICENSE TEXT'), findsOneWidget);
      expect(find.text('BSD-3-Clause'), findsOneWidget);
    });

    testWidgets('a component missing from the registry says so', (
      tester,
    ) async {
      await mount(tester, OpenSourcePage(index: LicenseIndex()));
      await reveal(tester, find.byKey(const ValueKey('oss-xterm')));
      await tester.tap(find.byKey(const ValueKey('oss-xterm')));
      await settle(tester);
      expect(find.textContaining('No license text was found'), findsOneWidget);
    });

    testWidgets('all licences: grouped by package, searchable', (tester) async {
      await mount(tester, OpenSourcePage(index: LicenseIndex()));
      await reveal(tester, find.byKey(const ValueKey('oss-all-licenses')));
      await tester.tap(find.byKey(const ValueKey('oss-all-licenses')));
      await settle(tester);
      for (final name in ['alpha_pkg', 'beta_pkg', 'gamma_pkg', 'intl']) {
        expect(find.byKey(ValueKey('license-$name')), findsOneWidget);
      }

      await tester.enterText(find.byType(EditableText), 'BETA');
      await settle(tester);
      expect(find.byKey(const ValueKey('license-beta_pkg')), findsOneWidget);
      expect(find.byKey(const ValueKey('license-alpha_pkg')), findsNothing);

      await tester.enterText(find.byType(EditableText), 'zzz');
      await settle(tester);
      expect(find.text('No matching components.'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'gamma');
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('license-gamma_pkg')));
      await settle(tester);
      expect(find.text('Shared beta gamma text'), findsOneWidget);
    });

    testWidgets('a failing registry shows the load error', (tester) async {
      LicenseRegistry.reset();
      LicenseRegistry.addLicense(() => Stream.error(StateError('broken')));
      await mount(tester, AllLicensesPage(index: LicenseIndex()));
      expect(find.text('Couldn’t load the license list.'), findsOneWidget);
    });

    testWidgets('zh strings', (tester) async {
      await mount(tester, OpenSourcePage(index: LicenseIndex()), locale: 'zh');
      expect(find.text('开源组件'), findsOneWidget);
      expect(find.text('日期、数字和消息格式化'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('oss-all-licenses')));
      expect(find.text('全部许可证（4）'), findsOneWidget);
    });
  });

  group('settings', () {
    late Directory directory;
    late LedgerStore store;
    late LedgerController ledger;

    setUp(() async {
      sqfliteFfiInit();
      directory = await Directory.systemTemp.createTemp('about-test-');
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${directory.path}/ledger.db',
        clock: () => DateTime(2026, 10, 7, 12),
      );
      ledger = LedgerController(
        store,
        clock: () => DateTime(2026, 10, 7, 12),
        reminderPlatform: FakeReminderPlatform()..supported = false,
        security: SecurityController(
          store: store,
          secrets: FakeSecretStore(),
          authenticator: FakeDeviceAuth(),
        ),
      );
      await ledger.refresh();
    });
    tearDown(() async {
      ledger.dispose();
      await store.close();
      await directory.delete(recursive: true);
    });

    testWidgets('the banner shows the shared version and opens About', (
      tester,
    ) async {
      await mount(tester, Scaffold(body: SettingsPage(controller: ledger)));
      expect(find.text(kAppName), findsOneWidget);
      expect(find.text('Version $kAppVersion'), findsOneWidget);
      expect(find.byType(AppChevron), findsWidgets);
      await tester.tap(find.text(kAppName));
      await settle(tester);
      expect(find.byType(AboutPage), findsOneWidget);
    });

    testWidgets('the About row in the last section opens About', (
      tester,
    ) async {
      await mount(tester, Scaffold(body: SettingsPage(controller: ledger)));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-about')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('settings-about')));
      await settle(tester);
      expect(find.byType(AboutPage), findsOneWidget);
      expect(find.text('Open-Source Components'), findsOneWidget);
    });
  });
}
