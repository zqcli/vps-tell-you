import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/core/app_info.dart';

void main() {
  test(
    'kAppVersion equals the pubspec.yaml version before the build number',
    () {
      final line = File('pubspec.yaml')
          .readAsLinesSync()
          .firstWhere((l) => l.startsWith('version:'));
      final version = line.substring('version:'.length).trim().split('+').first;
      expect(kAppVersion, version);
    },
  );

  test('product identity constants', () {
    expect(kAppName, 'VPS Tell You');
    expect(kRepoUrl, 'https://github.com/zqcli/vps-tell-you');
    expect(kRepoUrl, endsWith(kRepoDisplay));
  });

  test('the user-facing name is capitalised everywhere it is shown', () {
    for (final path in [
      'ios/Runner/Info.plist',
      'android/app/src/main/AndroidManifest.xml',
      'lib/l10n/app_zh.arb',
      'lib/l10n/app_en.arb',
      'README.md',
    ]) {
      final text = File(path).readAsStringSync();
      expect(text, isNot(contains('vps tell you')), reason: path);
    }
    expect(
      File('ios/Runner/Info.plist').readAsStringSync(),
      contains('<string>VPS Tell You</string>'),
    );
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:label="VPS Tell You"'),
    );
  });

  test('LICENSE is MIT with the project copyright', () {
    final license = File('LICENSE').readAsStringSync();
    expect(license, startsWith('MIT License'));
    expect(license, contains('Copyright (c) 2026 zqcli and contributors'));
  });
}
