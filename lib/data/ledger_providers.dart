part of 'ledger_store.dart';

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

/// The trimmed name of [record] after the length and duplicate checks that
/// every provider write shares.
Future<String> _checkedProviderName(
  DatabaseExecutor txn,
  ProviderRecord record,
) async {
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
  return clean;
}

/// Inserts a brand-new user provider inside the caller's transaction.
Future<ProviderRecord> _insertNewProvider(
  DatabaseExecutor txn,
  ProviderRecord record,
) async {
  final map = record.toMap()
    ..['name'] = await _checkedProviderName(txn, record)
    ..['revision'] = 0
    ..['catalog_id'] = null;
  await txn.insert('providers', map);
  return ProviderRecord.fromMap(map);
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

  /// Deletes a provider. Its servers (archived ones too) stay in the ledger and
  /// become "unspecified": only their provider link is cleared, active servers
  /// get a new revision like any edit. A directory-linked provider simply
  /// returns to the directory list. Fails with [LedgerConflict] when [record]
  /// is outdated.
  Future<void> deleteProvider(ProviderRecord record) =>
      _db.transaction((txn) async {
        final current = await _providerRow(txn, record.id);
        if (current.revision != record.revision) throw const LedgerConflict();
        await txn.rawUpdate(
          'UPDATE servers SET provider_id = NULL, '
          'revision = CASE WHEN archived_at IS NULL THEN revision + 1 ELSE revision END, '
          'updated_at = ? WHERE provider_id = ?',
          [clock().toUtc().toIso8601String(), record.id],
        );
        await txn.delete('providers', where: 'id = ?', whereArgs: [record.id]);
      });

  Future<void> saveProvider(
    ProviderRecord record, {
    required bool isNew,
  }) => _db.transaction((txn) async {
    final clean = await _checkedProviderName(txn, record);
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
