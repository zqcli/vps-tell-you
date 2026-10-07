import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';
import 'generated/app_localizations_zh.dart';

/// Stable persisted values, independent of translated labels or device region.
enum LocalePreference {
  chinese('zh'),
  english('en'),
  system('system');

  const LocalePreference(this.storageValue);
  final String storageValue;

  static LocalePreference fromStorage(Object? value) =>
      values.where((entry) => entry.storageValue == value).firstOrNull ??
      chinese;

  Locale resolve(Iterable<Locale> systemLocales) {
    if (this == chinese) return const Locale('zh');
    if (this == english) return const Locale('en');
    // Honor the first supported device language, with an explicit English
    // fallback. Chinese region/script variants use our Simplified Chinese UI.
    for (final locale in systemLocales) {
      if (locale.languageCode == 'zh') return const Locale('zh');
      if (locale.languageCode == 'en') return const Locale('en');
    }
    return const Locale('en');
  }
}

/// The Chinese fallback preserves isolated widget/model test behavior and the
/// existing interface before a ledger can be opened. Production routes obtain
/// their messages from MaterialApp's standard Localizations delegate.
final AppLocalizations defaultLocalizations = AppLocalizationsZh();

extension LedgerLocalizations on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      defaultLocalizations;
}
