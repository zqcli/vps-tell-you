import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

/// Fixed clock for fixtures and stores.
final fixtureTime = DateTime.utc(2026, 10, 6);

ServerResources completedResources({bool unlimited = false}) => ServerResources(
  ip: '192.0.2.40',
  hostname: 'VPS-Fixture.example',
  vcpu: 2,
  ramBytes: 2 * 1024 * 1024 * 1024,
  diskBytes: 30 * 1024 * 1024 * 1024,
  trafficBytes: unlimited ? null : 1024 * 1024 * 1024 * 1024,
  trafficUnlimited: unlimited,
);

Future<Database> openRawLedger(String path) =>
    databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
      ),
    );

// This is the real v9 DDL, including its original provider/remote-ID CHECKs.
// Never construct this fixture with LedgerStore.createSchema or by relabeling
// a newly created database: doing so would hide the required migration.
const legacyV9Schema = [
  '''CREATE TABLE server_groups (
    id TEXT PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE UNIQUE,
    position INTEGER NOT NULL)''',
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
    is_demo INTEGER NOT NULL DEFAULT 0 CHECK(is_demo IN (0,1)),
    renewal_anchor_date TEXT, resources_json TEXT)''',
  'CREATE INDEX servers_group ON servers(group_id)',
  'CREATE INDEX servers_archive ON servers(archived_at)',
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
  '''CREATE UNIQUE INDEX payments_active_until
    ON payments(server_id,until_date) WHERE server_id IS NOT NULL AND voided_at IS NULL''',
  '''CREATE TABLE service_periods (
    id TEXT PRIMARY KEY, server_id TEXT NOT NULL REFERENCES servers(id),
    start_date TEXT NOT NULL, end_date TEXT NOT NULL CHECK(end_date > start_date),
    inferred INTEGER NOT NULL CHECK(inferred IN (0,1)),
    payment_id TEXT REFERENCES payments(id))''',
  'CREATE INDEX service_periods_server ON service_periods(server_id,start_date)',
  '''CREATE TABLE finance_settings (
    id INTEGER PRIMARY KEY CHECK(id=1), display_currency TEXT NOT NULL,
    usd_to_cny TEXT, eur_to_cny TEXT, rate_date TEXT)''',
  '''CREATE TABLE credentials (
    id TEXT PRIMARY KEY, name TEXT NOT NULL,
    kind TEXT NOT NULL CHECK(kind IN ('password','privateKey')),
    default_username TEXT NOT NULL DEFAULT '', secret_ref TEXT NOT NULL UNIQUE,
    key_algorithm TEXT, fingerprint TEXT,
    created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
    revision INTEGER NOT NULL DEFAULT 0)''',
  '''CREATE TABLE ssh_configurations (
    server_id TEXT PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
    host TEXT NOT NULL, port INTEGER NOT NULL CHECK(port BETWEEN 1 AND 65535),
    username TEXT NOT NULL, credential_id TEXT REFERENCES credentials(id),
    revision INTEGER NOT NULL DEFAULT 0)''',
  'CREATE INDEX ssh_credential ON ssh_configurations(credential_id)',
  '''CREATE TABLE secret_cleanup (
    secret_ref TEXT PRIMARY KEY, created_at TEXT NOT NULL)''',
  '''CREATE TABLE host_trust (
    generation TEXT NOT NULL UNIQUE, host TEXT NOT NULL,
    port INTEGER NOT NULL CHECK(port BETWEEN 1 AND 65535),
    algorithm TEXT NOT NULL, public_key TEXT NOT NULL, fingerprint TEXT NOT NULL,
    verified_at TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(host, port))''',
  '''CREATE TABLE snippets (
    id TEXT PRIMARY KEY, name TEXT NOT NULL, content TEXT NOT NULL,
    revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0))''',
  '''CREATE TABLE cloud_accounts (
    id TEXT PRIMARY KEY, provider TEXT NOT NULL CHECK(provider IN ('solusVm1','solusVm2')),
    alias TEXT NOT NULL, endpoint TEXT NOT NULL, secret_ref TEXT NOT NULL UNIQUE,
    remote_account_id INTEGER, revision INTEGER NOT NULL DEFAULT 0,
    generation INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL,
    last_attempt_at TEXT, last_failure TEXT,
    CHECK((provider = 'solusVm1' AND remote_account_id IS NULL) OR
          (provider = 'solusVm2' AND remote_account_id > 0)))''',
  '''CREATE TABLE cloud_observations (
    account_id TEXT NOT NULL REFERENCES cloud_accounts(id) ON DELETE CASCADE,
    instance_key TEXT NOT NULL, identity_uuid TEXT, observation TEXT NOT NULL,
    stale INTEGER NOT NULL DEFAULT 0 CHECK(stale IN (0,1)),
    missing INTEGER NOT NULL DEFAULT 0 CHECK(missing IN (0,1)),
    PRIMARY KEY(account_id, instance_key))''',
  '''CREATE TABLE cloud_bindings (
    server_id TEXT PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
    account_id TEXT NOT NULL, instance_key TEXT NOT NULL,
    UNIQUE(account_id, instance_key),
    FOREIGN KEY(account_id, instance_key)
      REFERENCES cloud_observations(account_id, instance_key) ON DELETE CASCADE)''',
  '''CREATE TABLE app_settings (
    id INTEGER PRIMARY KEY CHECK(id=1),
    theme_mode TEXT NOT NULL CHECK(theme_mode IN ('system','light','dark')),
    language TEXT NOT NULL DEFAULT 'zh' CHECK(language IN ('zh','en','system')))''',
  '''CREATE TABLE reminder_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT CHECK(id BETWEEN 1 AND 268435455),
    server_id TEXT NOT NULL UNIQUE REFERENCES servers(id) ON DELETE CASCADE,
    enabled INTEGER NOT NULL DEFAULT 1 CHECK(enabled IN (0,1)),
    lead_days TEXT NOT NULL DEFAULT '[7,3,1]',
    minute_of_day INTEGER NOT NULL DEFAULT 540 CHECK(minute_of_day BETWEEN 0 AND 1439),
    usage_plan TEXT NOT NULL DEFAULT 'continueUsing'
      CHECK(usage_plan IN ('continueUsing','undecided','stopAtExpiry')),
    revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0))''',
  '''CREATE TRIGGER server_reminder AFTER INSERT ON servers
    BEGIN INSERT INTO reminder_rules (server_id) VALUES (NEW.id); END''',
];
