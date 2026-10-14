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
Future<void> removeProviderSchema(Database db) async {
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
