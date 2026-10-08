part of 'ledger_store.dart';

/// The upgrade runs in SQLite's version-change transaction. It never opens the
/// OS secret store and never rewrites a legacy user field or relationship.
Future<void> _addProviderSchema(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE providers (
    id TEXT PRIMARY KEY, name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 80),
    revision INTEGER NOT NULL DEFAULT 0,
    needs_review INTEGER NOT NULL DEFAULT 0 CHECK(needs_review IN (0,1)),
    created_at TEXT NOT NULL)''');
  await db.execute('''CREATE UNIQUE INDEX confirmed_provider_name
    ON providers(name COLLATE NOCASE) WHERE needs_review = 0''');
  await db.execute(
    'ALTER TABLE servers ADD COLUMN provider_id TEXT REFERENCES providers(id)',
  );
  await db.execute('''ALTER TABLE cloud_accounts ADD COLUMN
    business_provider_id TEXT REFERENCES providers(id)''');
  await db.execute('''ALTER TABLE cloud_accounts ADD COLUMN auth_scope TEXT
    NOT NULL DEFAULT 'unknown'
    CHECK(auth_scope IN ('unknown','singleDevice','account'))''');
  // Intentionally not ON DELETE SET NULL: a deleted local record cannot free a
  // singleton credential for a different device in the same authority epoch.
  await db.execute(
    'ALTER TABLE cloud_accounts ADD COLUMN pinned_server_id TEXT',
  );
  final servers = await db.query('servers', orderBy: 'id');
  final accounts = await db.query('cloud_accounts', orderBy: 'id');
  final bindings = await db.query('cloud_bindings', orderBy: 'server_id');
  final byServer = {for (final row in servers) row['id'] as String: row};
  final linkedIds = bindings.map((row) => row['server_id']).toSet();
  final names = <String, String>{};
  bool knownName(String value) =>
      value.trim().isNotEmpty && value.trim() != legacyUnknownVendor;
  Future<String> providerFor(String name, String createdAt) async {
    final clean = name.trim();
    // SQLite NOCASE is ASCII-only. Preserve non-ASCII names exactly rather
    // than silently merging labels using a different normalization algorithm.
    final key = clean.replaceAllMapped(
      RegExp('[A-Z]'),
      (m) => m[0]!.toLowerCase(),
    );
    if (names[key] case final existing?) return existing;
    final id = newLocalId();
    await db.insert('providers', {
      'id': id,
      'name': clean,
      'created_at': createdAt,
    });
    names[key] = id;
    return id;
  }

  for (final account in accounts) {
    final linked = bindings
        .where((b) => b['account_id'] == account['id'])
        .toList();
    final v1 = account['provider'] == CloudProvider.solusVm1.name;
    if (v1 &&
        (linked.length > 1 ||
            linked.any((b) => b['instance_key'] != 'single'))) {
      throw StateError('Ambiguous legacy singleton; migration was not applied');
    }
    final vendors = linked
        .map((b) => byServer[b['server_id']]!['vendor'] as String)
        .toSet();
    final consistent = vendors.length == 1 && knownName(vendors.single);
    final String providerId;
    if (consistent) {
      providerId = await providerFor(
        vendors.single,
        account['created_at'] as String,
      );
    } else {
      providerId = newLocalId();
      await db.insert('providers', {
        'id': providerId,
        'name': account['alias'],
        'needs_review': 1,
        'created_at': account['created_at'],
      });
    }
    final scope = v1
        ? AdapterAuthScope.singleDevice
        : (account['remote_account_id'] as int? ?? 0) > 0
        ? AdapterAuthScope.account
        : AdapterAuthScope.unknown;
    await db.update(
      'cloud_accounts',
      {
        'business_provider_id': providerId,
        'auth_scope': scope.name,
        'pinned_server_id': v1 && linked.isNotEmpty
            ? linked.first['server_id']
            : null,
      },
      where: 'id = ?',
      whereArgs: [account['id']],
    );
    for (final binding in linked) {
      await db.update(
        'servers',
        {'provider_id': providerId},
        where: 'id = ?',
        whereArgs: [binding['server_id']],
      );
    }
  }
  for (final server in servers) {
    if (linkedIds.contains(server['id'])) continue;
    final vendor = server['vendor'] as String;
    if (!knownName(vendor)) continue;
    final providerId = await providerFor(
      vendor,
      server['created_at'] as String,
    );
    await db.update(
      'servers',
      {'provider_id': providerId},
      where: 'id = ?',
      whereArgs: [server['id']],
    );
  }
  await _addProviderGuards(db);
}

Future<void> _addProviderGuards(DatabaseExecutor db) async {
  for (final operation in ['INSERT', 'UPDATE']) {
    await db.execute(
      '''CREATE TRIGGER adapter_provider_${operation.toLowerCase()}
      BEFORE $operation ON cloud_accounts BEGIN
      SELECT CASE WHEN NEW.business_provider_id IS NULL OR NOT EXISTS(
        SELECT 1 FROM providers WHERE id = NEW.business_provider_id)
        THEN RAISE(ABORT, 'adapter provider required') END;
      SELECT CASE WHEN NOT (
        NEW.auth_scope = 'unknown' OR
        (NEW.provider = 'solusVm1' AND NEW.auth_scope = 'singleDevice') OR
        (NEW.provider = 'solusVm2' AND NEW.auth_scope = 'account'
          AND NEW.remote_account_id IS NOT NULL AND NEW.remote_account_id > 0))
        THEN RAISE(ABORT, 'invalid adapter scope') END;
      SELECT CASE WHEN EXISTS(
        SELECT 1 FROM cloud_bindings b JOIN servers s ON s.id = b.server_id
        WHERE b.account_id = NEW.id AND
          (s.provider_id IS NULL OR s.provider_id != NEW.business_provider_id))
        THEN RAISE(ABORT, 'provider relationship mismatch') END;
      END''',
    );
    await db.execute(
      '''CREATE TRIGGER binding_provider_${operation.toLowerCase()}
      BEFORE $operation ON cloud_bindings BEGIN
      SELECT CASE WHEN NOT EXISTS(
        SELECT 1 FROM cloud_accounts a JOIN servers s ON s.id = NEW.server_id
        JOIN providers p ON p.id = a.business_provider_id
        WHERE a.id = NEW.account_id AND s.provider_id = a.business_provider_id
          AND p.needs_review = 0 AND a.auth_scope != 'unknown'
          AND (a.auth_scope != 'singleDevice' OR
            (NEW.instance_key = 'single' AND
             (a.pinned_server_id IS NULL OR a.pinned_server_id = NEW.server_id))))
        THEN RAISE(ABORT, 'binding outside adapter authority') END;
      END''',
    );
  }
  await db.execute('''CREATE TRIGGER server_provider_update BEFORE UPDATE OF provider_id ON servers
    WHEN EXISTS(SELECT 1 FROM cloud_bindings b JOIN cloud_accounts a ON a.id = b.account_id
      WHERE b.server_id = NEW.id AND
        (NEW.provider_id IS NULL OR NEW.provider_id != a.business_provider_id))
    BEGIN SELECT RAISE(ABORT, 'unlink before changing provider'); END''');
  await db.execute('''CREATE TRIGGER singleton_pin_update
    BEFORE UPDATE OF pinned_server_id ON cloud_accounts
    WHEN OLD.pinned_server_id IS NOT NULL
      AND NEW.secret_ref = OLD.secret_ref
      AND (NEW.pinned_server_id IS NULL OR NEW.pinned_server_id != OLD.pinned_server_id)
    BEGIN SELECT RAISE(ABORT, 'singleton authority is pinned'); END''');
  await db.execute(
    '''CREATE TRIGGER singleton_pin_insert AFTER INSERT ON cloud_bindings
    BEGIN UPDATE cloud_accounts SET pinned_server_id = NEW.server_id
      WHERE id = NEW.account_id AND auth_scope = 'singleDevice'; END''',
  );
  await db.execute('''CREATE TRIGGER singleton_pin_binding_update
    AFTER UPDATE OF server_id, account_id, instance_key ON cloud_bindings
    BEGIN UPDATE cloud_accounts SET pinned_server_id = NEW.server_id
      WHERE id = NEW.account_id AND auth_scope = 'singleDevice'; END''');
}

Future<ProviderRecord> _providerRow(
  DatabaseExecutor db,
  String id, {
  bool confirmed = true,
}) async {
  final rows = await db.query('providers', where: 'id = ?', whereArgs: [id]);
  if (rows.length != 1) throw const LedgerConflict();
  final provider = ProviderRecord.fromMap(rows.single);
  if (confirmed && provider.needsReview) {
    throw CloudAccountFailure(
      LocalizedText((l10n) => l10n.providerReviewRequired),
    );
  }
  return provider;
}

extension LedgerProviders on LedgerStore {
  Future<List<ProviderRecord>> providers() async => (await _db.query(
    'providers',
    orderBy: 'needs_review, name COLLATE NOCASE, id',
  )).map(ProviderRecord.fromMap).toList(growable: false);

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
      where: 'name = ? COLLATE NOCASE AND id != ? AND needs_review = 0',
      whereArgs: [clean, record.id],
    )).isNotEmpty) {
      throw LocalizedArgumentError((l10n) => l10n.providerAlreadyExists);
    }
    final map = record.toMap()..['name'] = clean;
    if (isNew) {
      if (record.needsReview) throw const LedgerConflict();
      map['revision'] = 0;
      await txn.insert('providers', map);
    } else {
      final current = await _providerRow(txn, record.id, confirmed: false);
      if (current.revision != record.revision ||
          current.needsReview != record.needsReview) {
        throw const LedgerConflict();
      }
      // Renaming cannot silently confirm a migrated provider or alter scope.
      map.remove('created_at');
      map['revision'] = current.revision + 1;
      await txn.update(
        'providers',
        map,
        where: 'id = ?',
        whereArgs: [record.id],
      );
      await txn.rawUpdate(
        'UPDATE cloud_accounts SET generation = generation + 1 WHERE business_provider_id = ?',
        [record.id],
      );
    }
  });

  Future<ProviderRecord> verifiedProvider(String id) => _providerRow(_db, id);

  /// Explicit device ownership edit. It grants no adapter authority. The caller
  /// must disclose the old link and authorize its removal before setting true.
  Future<void> setServerProvider(
    ServerCloudBindingOptions expected,
    String? providerId, {
    bool confirmUnlink = false,
  }) => _db.transaction((txn) async {
    final rows = await txn.query(
      'servers',
      where: 'id = ?',
      whereArgs: [expected.server.id],
    );
    if (rows.length != 1) throw const LedgerConflict();
    final current = ServerRecord.fromMap(rows.single);
    if (current.revision != expected.server.revision ||
        current.providerId != expected.server.providerId ||
        current.archived ||
        current.isDemo) {
      throw const LedgerConflict();
    }
    final accounts = await txn.query('cloud_accounts');
    if (accounts.length != expected.accounts.length) {
      throw const LedgerConflict();
    }
    for (final account in expected.accounts) {
      await LedgerStore._currentCloud(txn, account);
    }
    if (providerId == current.providerId) return;
    if (providerId != null) await _providerRow(txn, providerId);
    final links = await txn.query(
      'cloud_bindings',
      where: 'server_id = ?',
      whereArgs: [current.id],
    );
    final old = links.firstOrNull;
    if (old?['account_id'] != expected.current?.accountId ||
        old?['instance_key'] != expected.current?.instanceKey) {
      throw const LedgerConflict();
    }
    if (links.isNotEmpty && !confirmUnlink) {
      throw CloudAccountFailure(
        LocalizedText((l10n) => l10n.providerChangeNeedsUnlink),
      );
    }
    await txn.delete(
      'cloud_bindings',
      where: 'server_id = ?',
      whereArgs: [current.id],
    );
    await txn.update(
      'servers',
      {
        'provider_id': providerId,
        'revision': current.revision + 1,
        'updated_at': clock().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [current.id],
    );
    await txn.rawUpdate(
      'UPDATE cloud_accounts SET generation = generation + 1',
    );
  });

  /// Resolves one ambiguous migrated instance and all its current local links.
  /// It never reads a credential, changes endpoint, or imports another device.
  Future<void> confirmAdapterProvider(
    CloudAccount expected,
    ProviderRecord target,
  ) => _db.transaction((txn) async {
    final current = await LedgerStore._currentCloud(txn, expected);
    final previous = await _providerRow(
      txn,
      current.businessProviderId,
      confirmed: false,
    );
    final confirmed = await _providerRow(txn, target.id);
    if (!previous.needsReview || target.revision != confirmed.revision) {
      throw const LedgerConflict();
    }
    final bindings = await txn.query(
      'cloud_bindings',
      where: 'account_id = ?',
      whereArgs: [current.id],
    );
    // Temporarily remove and restore the identical rows within the transaction
    // so both sides can move together under the cross-table provider guards.
    await txn.delete(
      'cloud_bindings',
      where: 'account_id = ?',
      whereArgs: [current.id],
    );
    await txn.update(
      'cloud_accounts',
      {
        'business_provider_id': target.id,
        'revision': current.revision + 1,
        'generation': current.generation + 1,
      },
      where: 'id = ?',
      whereArgs: [current.id],
    );
    for (final binding in bindings) {
      await txn.rawUpdate(
        'UPDATE servers SET provider_id = ?, revision = revision + 1 WHERE id = ?',
        [target.id, binding['server_id']],
      );
      await txn.insert('cloud_bindings', binding);
    }
    await txn.rawUpdate(
      'UPDATE cloud_accounts SET generation = generation + 1 WHERE id != ?',
      [current.id],
    );
    if ((await txn.query(
          'cloud_accounts',
          where: 'business_provider_id = ?',
          whereArgs: [previous.id],
        )).isEmpty &&
        (await txn.query(
          'servers',
          where: 'provider_id = ?',
          whereArgs: [previous.id],
        )).isEmpty) {
      await txn.delete('providers', where: 'id = ?', whereArgs: [previous.id]);
    }
  });
}
