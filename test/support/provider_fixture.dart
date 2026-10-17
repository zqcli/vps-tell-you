import 'package:sqflite/sqflite.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/providers/provider_record.dart';

final testProvider = ProviderRecord(
  id: 'fixture-provider',
  name: 'Local vendor',
  createdAt: DateTime.utc(2026, 10, 6),
);
Future<void> addTestProvider(LedgerStore store) =>
    store.saveProvider(testProvider, isNew: true);

/// Reduce a current database to the shape before providers existed, so that
/// reopening it runs the real upgrade. Do not make the production migration
/// idempotent to accommodate test fixtures.
/// Reconstructs the pre-v14 SSH tables (no `proxies`, no `proxy_id`) so older
/// schemas can be rebuilt from a fresh database. Foreign keys must be off.
Future<void> removeProxySchema(Database db) async {
  await db.execute('DROP INDEX ssh_proxy');
  await db.execute('ALTER TABLE ssh_configurations RENAME TO ssh_new');
  await db.execute('''CREATE TABLE ssh_configurations (
      server_id TEXT PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
      host TEXT NOT NULL, port INTEGER NOT NULL CHECK(port BETWEEN 1 AND 65535),
      username TEXT NOT NULL, credential_id TEXT REFERENCES credentials(id),
      revision INTEGER NOT NULL DEFAULT 0)''');
  await db.execute('''INSERT INTO ssh_configurations
      SELECT server_id, host, port, username, credential_id, revision
      FROM ssh_new''');
  await db.execute('DROP TABLE ssh_new');
  await db.execute(
    'CREATE INDEX ssh_credential ON ssh_configurations(credential_id)',
  );
  await db.execute('DROP TABLE proxies');
}

Future<void> removeProviderSchema(Database db) async {
  await removeProxySchema(db);
  await db.execute('ALTER TABLE servers DROP COLUMN provider_id');
  await db.execute('DROP TABLE providers');
  await db.execute(
    'ALTER TABLE app_settings DROP COLUMN provider_directory_auto',
  );
}

Map<String, Object?> legacyProviderProjection(Map<String, Object?> row) =>
    Map.of(row)
      ..remove('provider_id')
      ..remove('package_id')
      ..remove('package_snapshot');
