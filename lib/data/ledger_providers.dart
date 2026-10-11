part of 'ledger_store.dart';

/// Providers plus the package link columns (schema v12). Fresh databases
/// create this directly; [_migrateToCatalogSchema] upgrades older ones.
Future<void> _createProviderTables(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE providers (
    id TEXT PRIMARY KEY, name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 80),
    revision INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)''');
  await db.execute(
    'CREATE UNIQUE INDEX providers_name ON providers(name COLLATE NOCASE)',
  );
  await db.execute(
    'ALTER TABLE servers ADD COLUMN provider_id TEXT REFERENCES providers(id)',
  );
}

/// Nullable catalog link and package reference. Existing rows stay empty: the
/// ledger never invents a catalog relationship for old data.
Future<void> _addCatalogColumns(DatabaseExecutor db) async {
  await db.execute('ALTER TABLE providers ADD COLUMN catalog_id TEXT');
  await db.execute('''CREATE UNIQUE INDEX providers_catalog_id
    ON providers(catalog_id) WHERE catalog_id IS NOT NULL''');
  await db.execute('ALTER TABLE servers ADD COLUMN package_id TEXT');
  await db.execute('ALTER TABLE servers ADD COLUMN package_snapshot TEXT');
  await db.execute('CREATE INDEX servers_package ON servers(package_id)');
}

const _retiredAdapterTriggers = [
  'adapter_provider_insert',
  'adapter_provider_update',
  'binding_provider_insert',
  'binding_provider_update',
  'server_provider_update',
  'singleton_pin_update',
  'singleton_pin_insert',
  'singleton_pin_binding_update',
];

/// Schema v12 upgrade for every older version. It runs inside sqflite's
/// version-change transaction: any exception rolls everything back and the
/// database keeps its old version. Servers, payments, SSH configurations and
/// credentials are never deleted. It never opens the OS secret store.
Future<void> _migrateToCatalogSchema(DatabaseExecutor db, DateTime now) async {
  Future<bool> hasTable(String name) async => (await db.rawQuery(
    "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",
    [name],
  )).isNotEmpty;
  Future<Set<String>> columns(String table) async =>
      (await db.rawQuery('PRAGMA table_info($table)'))
          .map((row) => row['name'] as String)
          .toSet();

  // 1. Every adapter secret reference joins the existing cleanup journal so the
  // device secure-storage items are removed by the ordinary retry path.
  if (await hasTable('cloud_accounts')) {
    for (final row in await db.query(
      'cloud_accounts',
      columns: ['secret_ref'],
    )) {
      final ref = row['secret_ref'];
      if (ref is! String || ref.isEmpty) {
        throw StateError('Invalid adapter secret reference');
      }
      await db.insert('secret_cleanup', {
        'secret_ref': ref,
        'created_at': now.toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // 2. Drop the adapter graph. Guards go first: one of them lives on servers
  // and references the cloud tables.
  for (final name in _retiredAdapterTriggers) {
    await db.execute('DROP TRIGGER IF EXISTS $name');
  }
  for (final table in [
    'cloud_bindings',
    'cloud_observations',
    'cloud_accounts',
  ]) {
    await db.execute('DROP TABLE IF EXISTS $table');
  }

  // 3. Providers: create them from legacy vendor text for databases which
  // predate them, otherwise make every migrated provider an ordinary one.
  final providersExist = await hasTable('providers');
  final serverColumns = await columns('servers');
  if (providersExist != serverColumns.contains('provider_id')) {
    throw StateError('Incomplete ledger provider schema');
  }
  String fold(String value) =>
      value.replaceAllMapped(RegExp('[A-Z]'), (m) => m[0]!.toLowerCase());
  if (!providersExist) {
    await _createProviderTables(db);
    final byName = <String, String>{};
    for (final server in await db.query(
      'servers',
      columns: ['id', 'vendor', 'created_at'],
      orderBy: 'created_at, id',
    )) {
      final vendor = (server['vendor'] as String).trim();
      if (vendor.isEmpty || vendor == legacyUnknownVendor) continue;
      // SQLite NOCASE folds ASCII only; mirror that to avoid merging labels
      // with a different normalization algorithm.
      var providerId = byName[fold(vendor)];
      if (providerId == null) {
        providerId = byName[fold(vendor)] = newLocalId();
        await db.insert('providers', {
          'id': providerId,
          'name': vendor,
          'created_at': server['created_at'],
        });
      }
      await db.update(
        'servers',
        {'provider_id': providerId},
        where: 'id = ?',
        whereArgs: [server['id']],
      );
    }
  } else {
    await db.execute('DROP INDEX IF EXISTS confirmed_provider_name');
    if ((await columns('providers')).contains('needs_review')) {
      final rows = await db.query(
        'providers',
        orderBy: 'needs_review, created_at, id',
      );
      final taken = {
        for (final row in rows)
          if (row['needs_review'] == 0) fold(row['name'] as String),
      };
      for (final row in rows.where((r) => r['needs_review'] != 0)) {
        final id = row['id'];
        final used = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM servers WHERE provider_id = ?',
            [id],
          ),
        )!;
        if (used == 0) {
          // A placeholder derived from an adapter alias which owns nothing.
          await db.delete('providers', where: 'id = ?', whereArgs: [id]);
          continue;
        }
        final base = row['name'] as String;
        var name = base;
        for (var n = 2; taken.contains(fold(name)); n++) {
          final suffix = ' ($n)';
          var cut = 80 - suffix.length;
          if (base.length <= cut) cut = base.length;
          // Keep a surrogate pair intact when truncating.
          if (cut > 0 && cut < base.length) {
            final unit = base.codeUnitAt(cut - 1);
            if (unit >= 0xd800 && unit <= 0xdbff) cut--;
          }
          name = '${base.substring(0, cut)}$suffix';
        }
        taken.add(fold(name));
        await db.update(
          'providers',
          {'name': name, 'needs_review': 0},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
    await db.execute(
      'CREATE UNIQUE INDEX providers_name ON providers(name COLLATE NOCASE)',
    );
  }

  // 4. Catalog link and package reference columns.
  await _addCatalogColumns(db);

  // 5. Remove API provenance markers, keeping every value byte for byte.
  for (final row in await db.query(
    'servers',
    columns: ['id', 'resources_json'],
    where: 'resources_json IS NOT NULL',
  )) {
    final source = row['resources_json'] as String;
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (_) {
      continue; // Unreadable data is left untouched, never rewritten.
    }
    if (decoded is! Map || !decoded.containsKey('apiFields')) continue;
    await db.update(
      'servers',
      {'resources_json': jsonEncode(Map.of(decoded)..remove('apiFields'))},
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }

  if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
    throw StateError('Invalid ledger migration references');
  }
}

Future<ProviderRecord> _providerRow(DatabaseExecutor db, String id) async {
  final rows = await db.query('providers', where: 'id = ?', whereArgs: [id]);
  if (rows.length != 1) throw const LedgerConflict();
  return ProviderRecord.fromMap(rows.single);
}

/// The local provider for a catalog provider: the linked one, else an
/// unlinked one with the same name (the user already created "the same"
/// provider; it only gains the link), else a new one.
Future<ProviderRecord> _ensureCatalogProvider(
  DatabaseExecutor txn,
  CatalogProviderRef ref,
  DateTime now,
) async {
  final name = ref.name.trim();
  if (name.isEmpty || name.length > 80) {
    throw LocalizedArgumentError((l10n) => l10n.providerNameRange);
  }
  final linked = await txn.query(
    'providers',
    where: 'catalog_id = ?',
    whereArgs: [ref.catalogId],
  );
  if (linked.isNotEmpty) return ProviderRecord.fromMap(linked.single);
  final sameName = await txn.query(
    'providers',
    where: 'name = ? COLLATE NOCASE',
    whereArgs: [name],
  );
  if (sameName.isNotEmpty) {
    final existing = ProviderRecord.fromMap(sameName.single);
    if (existing.catalogId != null) {
      throw LocalizedArgumentError((l10n) => l10n.providerAlreadyExists);
    }
    await txn.update(
      'providers',
      {'catalog_id': ref.catalogId, 'revision': existing.revision + 1},
      where: 'id = ?',
      whereArgs: [existing.id],
    );
    return (await _providerRow(txn, existing.id));
  }
  final created = ProviderRecord(
    id: newLocalId(),
    name: name,
    createdAt: now,
    catalogId: ref.catalogId,
  );
  await txn.insert('providers', created.toMap());
  return created;
}

/// A server's package must come with its snapshot and belong to the server's
/// (catalog) provider. Ledger values themselves are never checked against it.
Future<void> _checkPackageLink(
  DatabaseExecutor txn,
  ServerRecord record,
  String? providerId,
) async {
  if (record.packageId == null && record.packageSnapshot == null) return;
  final CatalogPackage snapshot;
  try {
    snapshot = CatalogPackage.decodeSnapshot(record.packageSnapshot ?? '');
  } on CatalogFormatException {
    throw LocalizedArgumentError((l10n) => l10n.r6CatPackageInvalid);
  }
  if (snapshot.id != record.packageId || providerId == null) {
    throw LocalizedArgumentError((l10n) => l10n.r6CatPackageInvalid);
  }
  final provider = await _providerRow(txn, providerId);
  if (provider.catalogId != snapshot.providerId) {
    throw LocalizedArgumentError((l10n) => l10n.r6CatPackageInvalid);
  }
}

extension LedgerProviders on LedgerStore {
  Future<List<ProviderRecord>> providers() async => (await _db.query(
    'providers',
    orderBy: 'name COLLATE NOCASE, id',
  )).map(ProviderRecord.fromMap).toList(growable: false);

  /// Creates (or links, see [_ensureCatalogProvider]) the local provider of a
  /// catalog provider. Idempotent.
  Future<ProviderRecord> addCatalogProvider(CatalogProviderRef ref) =>
      _db.transaction((txn) => _ensureCatalogProvider(txn, ref, clock()));

  Future<void> saveProvider(
    ProviderRecord record, {
    required bool isNew,
  }) => _db.transaction((txn) async {
    final clean = record.name.trim();
    if (clean.isEmpty || clean.length > 80) {
      throw LocalizedArgumentError((l10n) => l10n.providerNameRange);
    }
    if ((await txn.query(
      'providers',
      where: 'name = ? COLLATE NOCASE AND id != ?',
      whereArgs: [clean, record.id],
    )).isNotEmpty) {
      throw LocalizedArgumentError((l10n) => l10n.providerAlreadyExists);
    }
    final map = record.toMap()..['name'] = clean;
    if (isNew) {
      map['revision'] = 0;
      await txn.insert('providers', map);
    } else {
      final current = await _providerRow(txn, record.id);
      if (current.revision != record.revision) throw const LedgerConflict();
      // Only the display name is editable; the catalog link is immutable here.
      map
        ..remove('created_at')
        ..remove('catalog_id');
      map['revision'] = current.revision + 1;
      await txn.update(
        'providers',
        map,
        where: 'id = ?',
        whereArgs: [record.id],
      );
    }
  });
}
