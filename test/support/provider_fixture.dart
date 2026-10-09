import 'package:sqflite/sqflite.dart';
import 'package:vps_tell_you/cloud/provider_record.dart';
import 'package:vps_tell_you/data/ledger_store.dart';

final testProvider = ProviderRecord(
  id: 'fixture-provider',
  name: 'Local vendor',
  createdAt: DateTime.utc(2026, 10, 6),
);
Future<void> addTestProvider(LedgerStore store) =>
    store.saveProvider(testProvider, isNew: true);

/// Remove only v10 additions when constructing an actual earlier schema.
/// Do not make the production migration idempotent to accommodate test fixtures.
Future<void> removeProviderSchema(Database db) async {
  for (final name in [
    'adapter_provider_insert',
    'adapter_provider_update',
    'binding_provider_insert',
    'binding_provider_update',
    'server_provider_update',
    'singleton_pin_update',
    'singleton_pin_insert',
    'singleton_pin_binding_update',
  ]) {
    await db.execute('DROP TRIGGER IF EXISTS $name');
  }
  await db.execute('ALTER TABLE servers DROP COLUMN provider_id');
  if ((await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'cloud_accounts'",
  )).isNotEmpty) {
    for (final name in [
      'business_provider_id',
      'auth_scope',
      'pinned_server_id',
    ]) {
      await db.execute('ALTER TABLE cloud_accounts DROP COLUMN $name');
    }
  }
  await db.execute('DROP TABLE providers');
}

Map<String, Object?> legacyProviderProjection(Map<String, Object?> row) =>
    Map.of(row)
      ..remove('provider_id')
      ..remove('business_provider_id')
      ..remove('auth_scope')
      ..remove('pinned_server_id');
