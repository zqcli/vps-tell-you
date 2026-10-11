import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'legacy_ledger_fixture.dart';

/// Literal v11 DDL (adapter graph, providers, authority guards). Copied from
/// the last release which wrote it; production code can no longer create it.
const schema11Statements = [
  '''CREATE TABLE providers (
    id TEXT PRIMARY KEY, name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 80),
    revision INTEGER NOT NULL DEFAULT 0,
    needs_review INTEGER NOT NULL DEFAULT 0 CHECK(needs_review IN (0,1)),
    created_at TEXT NOT NULL)''',
  '''CREATE UNIQUE INDEX confirmed_provider_name
    ON providers(name COLLATE NOCASE) WHERE needs_review = 0''',
  'ALTER TABLE servers ADD COLUMN provider_id TEXT REFERENCES providers(id)',
  '''CREATE TABLE cloud_accounts (
    id TEXT PRIMARY KEY, provider TEXT NOT NULL CHECK(provider IN ('solusVm1','solusVm2','rackNerd')),
    alias TEXT NOT NULL, endpoint TEXT NOT NULL, secret_ref TEXT NOT NULL UNIQUE,
    remote_account_id INTEGER, revision INTEGER NOT NULL DEFAULT 0,
    generation INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL,
    last_attempt_at TEXT, last_failure TEXT,
    business_provider_id TEXT REFERENCES providers(id),
    auth_scope TEXT NOT NULL DEFAULT 'unknown'
      CHECK(auth_scope IN ('unknown','singleDevice','account')),
    pinned_server_id TEXT,
    CHECK((provider IN ('solusVm1','rackNerd') AND remote_account_id IS NULL) OR
          (provider = 'solusVm2' AND remote_account_id IS NOT NULL AND remote_account_id > 0)))''',
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
  '''CREATE TRIGGER adapter_provider_insert
    BEFORE INSERT ON cloud_accounts BEGIN
    SELECT CASE WHEN NEW.business_provider_id IS NULL OR NOT EXISTS(
      SELECT 1 FROM providers WHERE id = NEW.business_provider_id)
      THEN RAISE(ABORT, 'adapter provider required') END;
    END''',
  '''CREATE TRIGGER binding_provider_insert
    BEFORE INSERT ON cloud_bindings BEGIN
    SELECT CASE WHEN NOT EXISTS(
      SELECT 1 FROM cloud_accounts a JOIN servers s ON s.id = NEW.server_id
      WHERE a.id = NEW.account_id AND s.provider_id = a.business_provider_id)
      THEN RAISE(ABORT, 'binding outside adapter authority') END;
    END''',
  '''CREATE TRIGGER server_provider_update BEFORE UPDATE OF provider_id ON servers
    WHEN EXISTS(SELECT 1 FROM cloud_bindings b JOIN cloud_accounts a ON a.id = b.account_id
      WHERE b.server_id = NEW.id AND
        (NEW.provider_id IS NULL OR NEW.provider_id != a.business_provider_id))
    BEGIN SELECT RAISE(ABORT, 'unlink before changing provider'); END''',
  '''CREATE TRIGGER singleton_pin_insert AFTER INSERT ON cloud_bindings
    BEGIN UPDATE cloud_accounts SET pinned_server_id = NEW.server_id
      WHERE id = NEW.account_id AND auth_scope = 'singleDevice'; END''',
];

/// A real v9 database (with the v5 cloud tables) populated with synthetic
/// ledger rows. Servers carry the retired `apiFields` marker in resources.
Future<Database> createV9(String path) =>
    databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 9,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: (db, _) async {
          for (final statement in legacyV9Schema) {
            await db.execute(statement);
          }
        },
      ),
    );
