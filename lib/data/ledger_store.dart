import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/net_address.dart';
import '../core/value_types.dart';
import '../l10n/locale_preference.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/localized_message.dart';
import '../providers/provider_record.dart';
import '../connections/snippet.dart';
import '../servers/server_record.dart';
import '../finance/finance_models.dart';
import '../finance/finance_math.dart';
import '../security/proxy_models.dart';
import '../security/security_models.dart';
import '../settings/reminder_rule.dart';

part 'ledger_settings.dart';
part 'ledger_backup.dart';
part 'ledger_providers.dart';
part 'ledger_schema.dart';
part 'ledger_servers.dart';
part 'ledger_finance.dart';
part 'ledger_security.dart';
part 'ledger_snippets.dart';

class LedgerConflict implements Exception, LocalizedMessage {
  const LedgerConflict();
  @override
  String toString() => messageFor(defaultLocalizations);
  @override
  String messageFor(AppLocalizations l10n) => l10n.recordChanged;
}

// Historical user-input constraint, never a translated group/state identity.
const legacyReservedGroupName = '未分组';
// Legacy persisted placeholder, also required by the unchanged backup v1 label contract.
const legacyUnknownVendor = '服务商待填写';

class ArchiveUndo {
  const ArchiveUndo(this.id, this.revision);
  final String id;
  final int revision;
}

/// SQLite is the source of truth. All public mutations commit before returning.
/// No delete/recreate or destructive downgrade fallback is permitted.
class LedgerStore {
  LedgerStore._(this._db, this.clock, {this.isNewLedger = false});
  final Database _db;

  /// True when this very `open` created the database file (a first launch).
  /// Existing ledgers, including upgraded ones, are never new.
  final bool isNewLedger;
  final DateTime Function() clock;
  static const schemaVersion = 14;
  // Shared by both credential controllers using this store. A durable journal
  // reservation is not an orphan while its native write/DB commit is active.
  final Set<String> _activeSecretReservations = {};

  static Future<LedgerStore> open({
    required DatabaseFactory factory,
    required String path,
    DateTime Function()? clock,
  }) async {
    var created = false;
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          created = true;
          await createSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) =>
            _upgradeLedgerSchema(db, oldVersion, newVersion, clock),
        onDowngrade: (db, oldVersion, newVersion) async {
          throw StateError('Newer ledger version; upgrade the app');
        },
      ),
    );
    return LedgerStore._(db, clock ?? DateTime.now, isNewLedger: created);
  }

  /// Creates the current schema in an empty database.
  static Future<void> createSchema(DatabaseExecutor db) =>
      _createLedgerSchema(db);

  Future<void> close() => _db.close();
}
