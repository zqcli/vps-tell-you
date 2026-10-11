import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';

void main() {
  test('both ARB catalogs have complete matching message coverage', () {
    Map<String, Object?> read(String locale) =>
        (jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map)
            .cast<String, Object?>();
    final zh = read('zh'), en = read('en');
    Set<String> keys(Map<String, Object?> value) =>
        value.keys.where((key) => !key.startsWith('@')).toSet();
    expect(keys(en), keys(zh));
    expect(keys(en).length, greaterThan(1300));
    for (final key in keys(en)) {
      expect(en[key], isA<String>(), reason: key);
      expect((en[key] as String).trim(), isNotEmpty, reason: key);
      if (!{'languageChinese', 'invalidGroupName'}.contains(key)) {
        expect(
          RegExp(r'[\u3400-\u9fff]').hasMatch(en[key] as String),
          isFalse,
          reason: 'Untranslated English message: $key',
        );
      }
    }
    if (File('untranslated_messages.json').existsSync()) {
      expect(
        jsonDecode(File('untranslated_messages.json').readAsStringSync()),
        isEmpty,
      );
    }
  });

  test(
    'production Chinese literals are only stable persisted user-data defaults',
    () {
      // These values are legacy input constraints or saved/demo data. They must
      // never be rewritten when the interface language changes.
      const allowed = {
        '未分组',
        '演示',
        '搬瓦工',
        '香港',
        '生产主站',
        '美国',
        'API 服务',
        '日本',
        '开发环境',
        '自定义厂商',
        '新加坡',
        '备用',
        '仅演示：地址使用文档保留地址，不连接真实服务器。',
        '服务商待填写',
      };
      final literal = RegExp(r"'([^'\n]*[\u3400-\u9fff][^'\n]*)'");
      for (final file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart') || file.path.contains('/l10n/')) {
          continue;
        }
        for (final match in literal.allMatches(file.readAsStringSync())) {
          expect(
            file.path,
            'lib/data/ledger_store.dart',
            reason: 'Hardcoded UI text in ${file.path}',
          );
          expect(
            allowed,
            contains(match.group(1)),
            reason: 'Unexpected literal in ${file.path}',
          );
        }
      }
    },
  );

  test('English singular/plural and exact terminal button semantics', () {
    final en = AppLocalizationsEn(), zh = AppLocalizationsZh();
    expect(en.reminderDaysBefore(1), '1 day before');
    expect(en.reminderDaysBefore(3), '3 days before');
    expect(en.serverDueInDays(1), 'Expires in 1 day');
    expect(en.serverDueInDays(2), 'Expires in 2 days');
    expect(en.billingMonthlyAmount('10.00 USD', 1), '10.00 USD/1 month');
    expect(en.billingMonthlyAmount('10.00 USD', 3), '10.00 USD/3 months');
    expect(en.terminalSend, 'Send');
    expect(en.terminalSendExecute, 'Send and Execute');
    expect(zh.terminalSend, '发送');
    expect(zh.terminalSendExecute, '发送并执行');
    expect(en.snippetEscapeLegend, contains(r'\u{…}'));
  });
}
