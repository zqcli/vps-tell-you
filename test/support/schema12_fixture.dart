import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The literal schema-12 DDL (`sqlite_master` of a database created by the
/// schema-12 app, in creation order). It must never be built with
/// `LedgerStore.createSchema`: that would hide the migration under test.
const schema12Statements = [
  // table server_groups
  '''CREATE TABLE server_groups (
      id TEXT PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE UNIQUE,
      position INTEGER NOT NULL)''',
  // table servers
  '''CREATE TABLE servers (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, vendor TEXT NOT NULL,
      host TEXT NOT NULL DEFAULT '', region TEXT NOT NULL DEFAULT '',
      purpose TEXT NOT NULL DEFAULT '', os TEXT NOT NULL DEFAULT '',
      spec TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '',
      group_id TEXT REFERENCES server_groups(id) ON DELETE SET NULL,
      favorite INTEGER NOT NULL DEFAULT 0 CHECK(favorite IN (0,1)),
      billing TEXT NOT NULL CHECK(billing IN ('unknown','prepaid','metered')),
      currency TEXT NOT NULL CHECK(currency IN ('USD','CNY','EUR')),
      amount_minor INTEGER CHECK(amount_minor >= 0), cycle_months INTEGER NOT NULL,
      start_date TEXT, due_date TEXT, archived_at TEXT,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      revision INTEGER NOT NULL DEFAULT 0,
      is_demo INTEGER NOT NULL DEFAULT 0 CHECK(is_demo IN (0,1)), renewal_anchor_date TEXT, resources_json TEXT, provider_id TEXT REFERENCES providers(id), package_id TEXT, package_snapshot TEXT)''',
  // index servers_group
  '''CREATE INDEX servers_group ON servers(group_id)''',
  // index servers_archive
  '''CREATE INDEX servers_archive ON servers(archived_at)''',
  // table payments
  '''CREATE TABLE payments (
      id TEXT PRIMARY KEY,
      server_id TEXT REFERENCES servers(id), target_name TEXT NOT NULL,
      account_label TEXT, amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0),
      currency TEXT NOT NULL CHECK(currency IN ('USD','CNY','EUR')),
      paid_date TEXT NOT NULL, from_date TEXT, until_date TEXT,
      cycle_count INTEGER NOT NULL, note TEXT NOT NULL,
      previous_due TEXT, applied_server_revision INTEGER,
      created_at TEXT NOT NULL, voided_at TEXT, request_fingerprint TEXT NOT NULL,
      CHECK((server_id IS NULL AND account_label IS NOT NULL AND cycle_count=0)
        OR (server_id IS NOT NULL AND account_label IS NULL AND cycle_count BETWEEN 1 AND 3)))''',
  // index payments_active_until
  '''CREATE UNIQUE INDEX payments_active_until
      ON payments(server_id,until_date) WHERE server_id IS NOT NULL AND voided_at IS NULL''',
  // table service_periods
  '''CREATE TABLE service_periods (
      id TEXT PRIMARY KEY, server_id TEXT NOT NULL REFERENCES servers(id),
      start_date TEXT NOT NULL, end_date TEXT NOT NULL CHECK(end_date > start_date),
      inferred INTEGER NOT NULL CHECK(inferred IN (0,1)),
      payment_id TEXT REFERENCES payments(id))''',
  // index service_periods_server
  '''CREATE INDEX service_periods_server ON service_periods(server_id,start_date)''',
  // table finance_settings
  '''CREATE TABLE finance_settings (
      id INTEGER PRIMARY KEY CHECK(id=1), display_currency TEXT NOT NULL,
      usd_to_cny TEXT, eur_to_cny TEXT, rate_date TEXT)''',
  // table credentials
  '''CREATE TABLE credentials (
      id TEXT PRIMARY KEY, name TEXT NOT NULL,
      kind TEXT NOT NULL CHECK(kind IN ('password','privateKey')),
      default_username TEXT NOT NULL DEFAULT '', secret_ref TEXT NOT NULL UNIQUE,
      key_algorithm TEXT, fingerprint TEXT,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      revision INTEGER NOT NULL DEFAULT 0)''',
  // table ssh_configurations
  '''CREATE TABLE ssh_configurations (
      server_id TEXT PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
      host TEXT NOT NULL, port INTEGER NOT NULL CHECK(port BETWEEN 1 AND 65535),
      username TEXT NOT NULL, credential_id TEXT REFERENCES credentials(id),
      revision INTEGER NOT NULL DEFAULT 0)''',
  // index ssh_credential
  '''CREATE INDEX ssh_credential ON ssh_configurations(credential_id)''',
  // table secret_cleanup
  '''CREATE TABLE secret_cleanup (
      secret_ref TEXT PRIMARY KEY, created_at TEXT NOT NULL)''',
  // table host_trust
  '''CREATE TABLE host_trust (
      generation TEXT NOT NULL UNIQUE, host TEXT NOT NULL, port INTEGER NOT NULL CHECK(port BETWEEN 1 AND 65535),
      algorithm TEXT NOT NULL, public_key TEXT NOT NULL, fingerprint TEXT NOT NULL,
      verified_at TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(host, port))''',
  // table snippets
  '''CREATE TABLE snippets (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, content TEXT NOT NULL,
      revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0))''',
  // table app_settings
  '''CREATE TABLE app_settings (
    id INTEGER PRIMARY KEY CHECK(id=1),
    theme_mode TEXT NOT NULL CHECK(theme_mode IN ('system','light','dark')), language TEXT NOT NULL DEFAULT 'zh' CHECK(language IN ('zh','en','system')))''',
  // table reminder_rules
  '''CREATE TABLE reminder_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT CHECK(id BETWEEN 1 AND 268435455),
    server_id TEXT NOT NULL UNIQUE REFERENCES servers(id) ON DELETE CASCADE,
    enabled INTEGER NOT NULL DEFAULT 1 CHECK(enabled IN (0,1)),
    lead_days TEXT NOT NULL DEFAULT '[7,3,1]',
    minute_of_day INTEGER NOT NULL DEFAULT 540 CHECK(minute_of_day BETWEEN 0 AND 1439),
    usage_plan TEXT NOT NULL DEFAULT 'continueUsing'
      CHECK(usage_plan IN ('continueUsing','undecided','stopAtExpiry')),
    revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0))''',
  // trigger server_reminder
  '''CREATE TRIGGER server_reminder AFTER INSERT ON servers
    BEGIN INSERT INTO reminder_rules (server_id) VALUES (NEW.id); END''',
  // table providers
  '''CREATE TABLE providers (
    id TEXT PRIMARY KEY, name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 80),
    revision INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, catalog_id TEXT)''',
  // index providers_name
  '''CREATE UNIQUE INDEX providers_name ON providers(name COLLATE NOCASE)''',
  // index providers_catalog_id
  '''CREATE UNIQUE INDEX providers_catalog_id
    ON providers(catalog_id) WHERE catalog_id IS NOT NULL''',
  // index servers_package
  '''CREATE INDEX servers_package ON servers(package_id)''',
];

/// Creates an empty schema-12 database at [path] (user_version 12) with the
/// two singleton rows a real one has.
Future<Database> createV12(String path) async {
  final db = await databaseFactoryFfiNoIsolate.openDatabase(
    path,
    options: OpenDatabaseOptions(
      onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
    ),
  );
  for (final sql in schema12Statements) {
    await db.execute(sql);
  }
  await db.insert('finance_settings', {
    'id': 1,
    'display_currency': 'CNY',
    'usd_to_cny': null,
    'eur_to_cny': null,
    'rate_date': null,
  });
  await db.insert('app_settings', {'id': 1, 'theme_mode': 'system'});
  await db.setVersion(12);
  return db;
}
