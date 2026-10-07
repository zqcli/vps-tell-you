part of 'ledger_store.dart';

/// A non-destructive preference migration. Existing ledgers stay in Chinese;
/// billing data, IDs, user text, backup v1 and all other defaults are unchanged.
Future<void> _addLanguageSchema(DatabaseExecutor db) => db.execute(
  "ALTER TABLE app_settings ADD COLUMN language TEXT NOT NULL DEFAULT 'zh' "
  "CHECK(language IN ('zh','en','system'))",
);

Future<void> _addSettingsSchema(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE app_settings (
    id INTEGER PRIMARY KEY CHECK(id=1),
    theme_mode TEXT NOT NULL CHECK(theme_mode IN ('system','light','dark')))
  ''');
  await db.insert('app_settings', {'id': 1, 'theme_mode': 'system'});
  await db.execute('''CREATE TABLE reminder_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT CHECK(id BETWEEN 1 AND 268435455),
    server_id TEXT NOT NULL UNIQUE REFERENCES servers(id) ON DELETE CASCADE,
    enabled INTEGER NOT NULL DEFAULT 1 CHECK(enabled IN (0,1)),
    lead_days TEXT NOT NULL DEFAULT '[7,3,1]',
    minute_of_day INTEGER NOT NULL DEFAULT 540 CHECK(minute_of_day BETWEEN 0 AND 1439),
    usage_plan TEXT NOT NULL DEFAULT 'continueUsing'
      CHECK(usage_plan IN ('continueUsing','undecided','stopAtExpiry')),
    revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0))''');
  await db.execute('''INSERT INTO reminder_rules (server_id)
    SELECT id FROM servers ORDER BY id''');
  // Covers manual creation, cloud import and backup restore in their existing
  // transactions, without teaching each feature about reminder implementation.
  await db.execute('''CREATE TRIGGER server_reminder AFTER INSERT ON servers
    BEGIN INSERT INTO reminder_rules (server_id) VALUES (NEW.id); END''');
}

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
