part of 'ledger_store.dart';

extension LedgerSettings on LedgerStore {
  Future<LocalePreference> languagePreference() async =>
      LocalePreference.fromStorage(
        (await _db.query(
          'app_settings',
          columns: ['language'],
        )).single['language'],
      );

  Future<void> saveLanguagePreference(LocalePreference preference) async {
    final changed = await _db.update('app_settings', {
      'language': preference.storageValue,
    }, where: 'id=1');
    if (changed != 1) {
      throw StateError('Language preference row is missing');
    }
  }

  Future<bool> providerDirectoryAuto() async =>
      (await _db.query(
        'app_settings',
        columns: ['provider_directory_auto'],
      )).single['provider_directory_auto'] ==
      1;

  Future<void> saveProviderDirectoryAuto(bool enabled) async {
    final changed = await _db.update('app_settings', {
      'provider_directory_auto': enabled ? 1 : 0,
    }, where: 'id=1');
    if (changed != 1) {
      throw StateError('Settings row is missing');
    }
  }

  Future<String> themeMode() async =>
      (await _db.query('app_settings')).single['theme_mode'] as String;

  Future<void> saveThemeMode(String mode) async {
    if (!const ['system', 'light', 'dark'].contains(mode)) {
      throw ArgumentError('Invalid theme');
    }
    await _db.update('app_settings', {'theme_mode': mode}, where: 'id=1');
  }

  Future<List<ReminderRule>> reminderRules() async => [
    for (final row in await _db.query('reminder_rules', orderBy: 'id'))
      ReminderRule(
        id: row['id'] as int,
        serverId: row['server_id'] as String,
        enabled: row['enabled'] == 1,
        leadDays: (jsonDecode(row['lead_days'] as String) as List).cast<int>(),
        minuteOfDay: row['minute_of_day'] as int,
        usagePlan: UsagePlan.values.byName(row['usage_plan'] as String),
        revision: row['revision'] as int,
      ),
  ];

  Future<void> saveReminderRule(ReminderRule rule) async {
    await _db.transaction((txn) async {
      final server = await txn.query(
        'servers',
        columns: ['archived_at'],
        where: 'id = ?',
        whereArgs: [rule.serverId],
      );
      if (server.isEmpty || server.single['archived_at'] != null) {
        throw const LedgerConflict();
      }
      final changed = await txn.update(
        'reminder_rules',
        {
          'enabled': rule.enabled ? 1 : 0,
          'lead_days': jsonEncode(rule.leadDays),
          'minute_of_day': rule.minuteOfDay,
          'usage_plan': rule.usagePlan.name,
          'revision': rule.revision + 1,
        },
        where: 'id = ? AND server_id = ? AND revision = ?',
        whereArgs: [rule.id, rule.serverId, rule.revision],
      );
      if (changed != 1) {
        throw const LedgerConflict();
      }
    });
  }
}
