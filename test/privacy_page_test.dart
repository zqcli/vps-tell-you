import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/connections/sftp_support.dart';
import 'package:vps_tell_you/core/app_info.dart';
import 'package:vps_tell_you/providers/directory_source.dart';
import 'package:vps_tell_you/settings/about_page.dart';
import 'package:vps_tell_you/settings/markdown_lite.dart';
import 'package:vps_tell_you/settings/privacy_page.dart';

import 'about_test.dart' show mount;

Future<String> fromRepo(String asset) async => File(asset).readAsString();

String? hookClipboard(WidgetTester tester, void Function(String) onCopy) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        onCopy((call.arguments as Map)['text'] as String);
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
  return null;
}

void main() {
  group('markdown_lite', () {
    test('headings, bullets with continuations, paragraphs, inline markup', () {
      final blocks = parseDoc('''
# Title
Effective **today** · [English](PRIVACY.en.md)

## Part
First line
second line.

- one `code`
  continued
- two [link](https://example.org)

### Sub
Tail
''');
      expect(
        [for (final b in blocks) b.kind],
        [
          DocBlockKind.paragraph,
          DocBlockKind.heading,
          DocBlockKind.paragraph,
          DocBlockKind.bullet,
          DocBlockKind.bullet,
          DocBlockKind.subheading,
          DocBlockKind.paragraph,
        ],
      );
      expect(
        [for (final b in blocks) b.text],
        [
          'Effective **today**',
          'Part',
          'First line second line.',
          'one code continued',
          'two link',
          'Sub',
          'Tail',
        ],
      );
    });
  });

  group('bundled policy files', () {
    final zh = File('PRIVACY.md').readAsStringSync();
    final en = File('PRIVACY.en.md').readAsStringSync();

    test('both languages have the same structure and the effective date', () {
      List<String> kinds(String s) => [
        for (final b in parseDoc(s))
          if (b.kind != DocBlockKind.paragraph || b.text.contains('2026'))
            b.kind.name,
      ];
      expect(
        parseDoc(zh).where((b) => b.kind == DocBlockKind.heading).length,
        parseDoc(en).where((b) => b.kind == DocBlockKind.heading).length,
      );
      expect(kinds(zh).length, kinds(en).length);
      expect(zh, contains('2026-10-20'));
      expect(en, contains('2026-10-20'));
    });

    test('no placeholders and the real contact and public URLs', () {
      for (final text in [zh, en]) {
        expect(text, isNot(contains('TODO')));
        expect(text, isNot(matches(RegExp(r'@[a-z0-9-]+\.(com|org|net)'))));
        expect(text, contains('$kRepoUrl/issues'));
        expect(text, contains('$kRepoUrl/security'));
      }
      expect(zh, contains(privacyUrl('zh')));
      expect(en, contains(privacyUrl('en')));
      expect(privacyUrl('zh'), endsWith('/PRIVACY.md'));
      expect(privacyUrl('en'), endsWith('/PRIVACY.en.md'));
      expect(supportUrl('zh'), endsWith('/SUPPORT.md'));
      expect(supportUrl('en'), endsWith('/SUPPORT.en.md'));
    });

    test('claims match the code: hosts, folder, interval, keychain', () {
      final hosts = {for (final b in kDirectoryBases) Uri.parse(b).host};
      expect(hosts, {'raw.githubusercontent.com', 'cdn.jsdelivr.net'});
      for (final text in [zh, en]) {
        for (final host in hosts) {
          expect(text, contains(host));
        }
        expect(text, contains(sftpDownloadsFolder));
        expect(text, contains('12'));
        expect(text, contains('github-general-privacy-statement'));
        expect(text, contains('jsdelivr.com/terms/privacy-policy'));
      }
      expect(en, contains('Keychain'));
      expect(zh, contains('钥匙串'));
      // Nothing in the policy promises what the app doesn't do.
      expect(en, isNot(contains('end-to-end')));
    });

    test('the support pages exist in both languages and point to issues', () {
      for (final f in ['SUPPORT.md', 'SUPPORT.en.md']) {
        final text = File(f).readAsStringSync();
        expect(text, contains('$kRepoUrl/issues'));
        expect(text, contains('$kRepoUrl/security'));
        expect(text, isNot(contains('TODO')));
      }
    });
  });

  group('privacy page', () {
    testWidgets('en: renders the sections and copies the public link', (
      tester,
    ) async {
      String? copied;
      hookClipboard(tester, (t) => copied = t);
      await mount(tester, PrivacyPolicyPage(load: fromRepo));
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(
        find.text(
          'Effective date: 2026-10-20 · Applies to VPS Tell You 0.6.0 and later',
        ),
        findsOneWidget,
      );
      for (final h in [
        'In short',
        'Network connections',
        'Retention and deletion',
      ]) {
        await tester.ensureVisible(find.text(h));
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('privacy-copy-link')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('privacy-copy-link')));
      await tester.pump();
      expect(copied, privacyUrl('en'));
      expect(find.text('Privacy policy link copied'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('zh: loads the Chinese file and copies the Chinese URL', (
      tester,
    ) async {
      String? copied;
      String? asked;
      hookClipboard(tester, (t) => copied = t);
      await mount(
        tester,
        PrivacyPolicyPage(
          load: (a) {
            asked = a;
            return fromRepo(a);
          },
        ),
        locale: 'zh',
      );
      expect(asked, 'PRIVACY.md');
      expect(find.text('隐私政策'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('privacy-copy-link')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('privacy-copy-link')));
      await tester.pump();
      expect(copied, privacyUrl('zh'));
      expect(find.text('已复制隐私政策地址'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('a load failure still offers the public link', (tester) async {
      await mount(
        tester,
        PrivacyPolicyPage(load: (_) async => throw StateError('no asset')),
      );
      expect(find.text('Couldn’t load the privacy policy.'), findsOneWidget);
      expect(find.byKey(const ValueKey('privacy-copy-link')), findsOneWidget);
    });

    test('asset choice follows the language, Chinese as fallback', () {
      expect(privacyAsset('en'), 'PRIVACY.en.md');
      expect(privacyAsset('zh'), 'PRIVACY.md');
      expect(privacyAsset('fr'), 'PRIVACY.md');
    });
  });

  group('about rows', () {
    for (final (locale, title, support, toast) in [
      ('en', 'Privacy Policy', 'Support', 'Support link copied'),
      ('zh', '隐私政策', '支持', '已复制支持页地址'),
    ]) {
      testWidgets('$locale: privacy opens the page, support copies the URL', (
        tester,
      ) async {
        String? copied;
        hookClipboard(tester, (t) => copied = t);
        await mount(tester, const AboutPage(), locale: locale);
        expect(find.text(title), findsOneWidget);
        expect(find.text(support), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('about-support')));
        await tester.pump();
        expect(copied, supportUrl(locale));
        expect(find.text(toast), findsOneWidget);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await tester.tap(find.byKey(const ValueKey('about-privacy')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(PrivacyPolicyPage), findsOneWidget);
      });
    }
  });
}
