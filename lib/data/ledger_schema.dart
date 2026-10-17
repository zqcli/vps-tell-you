part of 'ledger_store.dart';

/// Add explicit, transactional migrations only when a real schema changes.
Future<void> _createLedgerSchema(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE server_groups (
      id TEXT PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE UNIQUE,
      position INTEGER NOT NULL)''');
  await db.execute('''CREATE TABLE servers (
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
      is_demo INTEGER NOT NULL DEFAULT 0 CHECK(is_demo IN (0,1)))''');
  await db.execute('CREATE INDEX servers_group ON servers(group_id)');
  await db.execute('CREATE INDEX servers_archive ON servers(archived_at)');
  await _addFinanceSchema(db);
  await _addSecuritySchema(db);
  await _addSnippetSchema(db);
  await _addSettingsSchema(db);
  await _addResourcesSchema(db);
  await _addLanguageSchema(db);
  await _createProviderTables(db);
  await _addCatalogLink(db);
  await _addDirectorySettings(db);
  await _addProxySchema(db);
}

/// Nullable by design: old/manual records are not populated with fabricated
/// resource values, and this migration touches no finance or SSH fields.
Future<void> _addResourcesSchema(DatabaseExecutor db) =>
    db.execute('ALTER TABLE servers ADD COLUMN resources_json TEXT');

Future<void> _addFinanceSchema(DatabaseExecutor db) async {
  await db.execute('ALTER TABLE servers ADD COLUMN renewal_anchor_date TEXT');
  await db.execute(
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
  );
  await db.execute(
    '''CREATE UNIQUE INDEX payments_active_until
      ON payments(server_id,until_date) WHERE server_id IS NOT NULL AND voided_at IS NULL''',
  );
  await db.execute('''CREATE TABLE service_periods (
      id TEXT PRIMARY KEY, server_id TEXT NOT NULL REFERENCES servers(id),
      start_date TEXT NOT NULL, end_date TEXT NOT NULL CHECK(end_date > start_date),
      inferred INTEGER NOT NULL CHECK(inferred IN (0,1)),
      payment_id TEXT REFERENCES payments(id))''');
  await db.execute(
    'CREATE INDEX service_periods_server ON service_periods(server_id,start_date)',
  );
  await db.execute('''CREATE TABLE finance_settings (
      id INTEGER PRIMARY KEY CHECK(id=1), display_currency TEXT NOT NULL,
      usd_to_cny TEXT, eur_to_cny TEXT, rate_date TEXT)''');
  await db.insert('finance_settings', const FxSettings().toMap());
  final records = (await db.query('servers')).map(ServerRecord.fromMap);
  for (final record in records) {
    if (record.billing == BillingKind.prepaid && record.dueDate != null) {
      await db.update(
        'servers',
        {'renewal_anchor_date': record.dueDate.toString()},
        where: 'id = ?',
        whereArgs: [record.id],
      );
    }
    await LedgerStore._replaceInitialPeriod(db, record);
  }
}

Future<void> _addSecuritySchema(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE credentials (
      id TEXT PRIMARY KEY, name TEXT NOT NULL,
      kind TEXT NOT NULL CHECK(kind IN ('password','privateKey')),
      default_username TEXT NOT NULL DEFAULT '', secret_ref TEXT NOT NULL UNIQUE,
      key_algorithm TEXT, fingerprint TEXT,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      revision INTEGER NOT NULL DEFAULT 0)''');
  await db.execute('''CREATE TABLE ssh_configurations (
      server_id TEXT PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
      host TEXT NOT NULL, port INTEGER NOT NULL CHECK(port BETWEEN 1 AND 65535),
      username TEXT NOT NULL, credential_id TEXT REFERENCES credentials(id),
      revision INTEGER NOT NULL DEFAULT 0)''');
  await db.execute(
    'CREATE INDEX ssh_credential ON ssh_configurations(credential_id)',
  );
  // Both pre-write reservations and superseded immutable references live here.
  // No secret data is ever written into this recovery journal.
  await db.execute('''CREATE TABLE secret_cleanup (
      secret_ref TEXT PRIMARY KEY, created_at TEXT NOT NULL)''');
  await db.execute('''CREATE TABLE host_trust (
      generation TEXT NOT NULL UNIQUE, host TEXT NOT NULL, port INTEGER NOT NULL CHECK(port BETWEEN 1 AND 65535),
      algorithm TEXT NOT NULL, public_key TEXT NOT NULL, fingerprint TEXT NOT NULL,
      verified_at TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(host, port))''');
}

/// Saved proxies. The password lives only in secure storage ([secret_ref]);
/// deleting a referenced proxy is refused (RESTRICT), so a connection can
/// never silently turn into a direct one.
Future<void> _addProxySchema(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE proxies (
      id TEXT PRIMARY KEY, name TEXT NOT NULL,
      kind TEXT NOT NULL CHECK(kind IN ('socks5','http','https')),
      host TEXT NOT NULL, port INTEGER NOT NULL CHECK(port BETWEEN 1 AND 65535),
      username TEXT, secret_ref TEXT UNIQUE,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      revision INTEGER NOT NULL DEFAULT 0,
      CHECK(secret_ref IS NULL OR username IS NOT NULL))''');
  await db.execute(
    'ALTER TABLE ssh_configurations ADD COLUMN proxy_id TEXT '
    'REFERENCES proxies(id) ON DELETE RESTRICT',
  );
  await db.execute('CREATE INDEX ssh_proxy ON ssh_configurations(proxy_id)');
}

Future<void> _addSnippetSchema(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE snippets (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, content TEXT NOT NULL,
      revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0))''');
}

/// A non-destructive preference migration. Existing ledgers stay in Chinese;
/// billing data, IDs, user text, backup v1 and all other defaults are unchanged.
Future<void> _addLanguageSchema(DatabaseExecutor db) => db.execute(
  "ALTER TABLE app_settings ADD COLUMN language TEXT NOT NULL DEFAULT 'zh' "
  "CHECK(language IN ('zh','en','system'))",
);

/// Whether the provider directory refreshes itself on launch (default on).
Future<void> _addDirectorySettings(DatabaseExecutor db) => db.execute(
  'ALTER TABLE app_settings ADD COLUMN provider_directory_auto '
  'INTEGER NOT NULL DEFAULT 1',
);

Future<void> _addSettingsSchema(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE app_settings (
    id INTEGER PRIMARY KEY CHECK(id=1),
    theme_mode TEXT NOT NULL CHECK(theme_mode IN ('system','light','dark')))
  ''');
  await db.insert('app_settings', {'id': 1, 'theme_mode': 'system'});
  await db.execute('''CREATE TABLE reminder_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT CHECK(id BETWEEN 1 AND 268435455),
    server_id TEXT NOT NULL UNIQUE REFERENCES servers(id) ON DELETE CASCADE,
    enabled INTEGER NOT NULL DEFAULT 1 CHECK(enabled IN (0,1)),
    lead_days TEXT NOT NULL DEFAULT '[7,3,1]',
    minute_of_day INTEGER NOT NULL DEFAULT 540 CHECK(minute_of_day BETWEEN 0 AND 1439),
    usage_plan TEXT NOT NULL DEFAULT 'continueUsing'
      CHECK(usage_plan IN ('continueUsing','undecided','stopAtExpiry')),
    revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0))''');
  await db.execute('''INSERT INTO reminder_rules (server_id)
    SELECT id FROM servers ORDER BY id''');
  // Covers manual creation, cloud import and backup restore in their existing
  // transactions, without teaching each feature about reminder implementation.
  await db.execute('''CREATE TRIGGER server_reminder AFTER INSERT ON servers
    BEGIN INSERT INTO reminder_rules (server_id) VALUES (NEW.id); END''');
}

/// Providers with their directory link. Fresh databases create this directly;
/// [_migrateToCatalogSchema] upgrades older ones.
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

/// Nullable directory link. Existing rows stay empty: the ledger never invents
/// a directory relationship for old data.
Future<void> _addCatalogLink(DatabaseExecutor db) async {
  await db.execute('ALTER TABLE providers ADD COLUMN catalog_id TEXT');
  await db.execute('''CREATE UNIQUE INDEX providers_catalog_id
    ON providers(catalog_id) WHERE catalog_id IS NOT NULL''');
}

/// Columns of schema v12 which schema v13 retires. SQLite cannot reliably
/// DROP COLUMN on older Android versions, so they stay in migrated databases
/// (always NULL, never read or written by the app). Fresh v13 databases do not
/// have them; only the upgrade path through v12 creates them.
Future<void> _addRetiredPackageColumns(DatabaseExecutor db) async {
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

/// Schema v12 upgrade for every older version (v13 follows it). It runs inside sqflite's
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

  // 4. Catalog link (and the package columns v13 retires again right after).
  await _addCatalogLink(db);
  await _addRetiredPackageColumns(db);

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

/// Schema v13 (providers only). Runs in sqflite's version-change transaction
/// after every older step; any exception rolls the whole upgrade back.
///
/// * Package links are cleared; the columns stay (see
///   [_addRetiredPackageColumns]) and are never touched again.
/// * The round-6 sample directory ids no longer exist anywhere.
/// * The provider directory auto-update preference gets its column.
///
/// Servers' other data, payments and credentials are never touched.
Future<void> _migrateToProviderDirectorySchema(DatabaseExecutor db) async {
  await db.execute(
    'UPDATE servers SET package_id = NULL, package_snapshot = NULL',
  );
  await db.execute(
    "UPDATE providers SET catalog_id = NULL "
    "WHERE catalog_id IN ('example-cloud','demo-vps')",
  );
  await _addDirectorySettings(db);
}

/// Upgrades an older ledger one step at a time. sqflite runs this in a single
/// version-change transaction: any exception rolls everything back. The
/// migrations are kept forever; never delete or edit an old step.
Future<void> _upgradeLedgerSchema(
  DatabaseExecutor db,
  int oldVersion,
  int newVersion,
  DateTime Function()? clock,
) async {
  if (oldVersion < 1 ||
      oldVersion > LedgerStore.schemaVersion ||
      newVersion != LedgerStore.schemaVersion) {
    throw StateError('Unsupported ledger migration');
  }
  if (oldVersion < 2) {
    await _addFinanceSchema(db);
  }
  if (oldVersion < 3) {
    await _addSecuritySchema(db);
  }
  if (oldVersion < 4) {
    await _addSnippetSchema(db);
  }
  if (oldVersion < 6) {
    await _addSettingsSchema(db);
  }
  if (oldVersion < 7) {
    await _addResourcesSchema(db);
  }
  // v8 permits partial local resources and a traffic period in JSON.
  // Existing v7 rows are already valid and must not be rewritten; the
  // version fence prevents older readers from accepting the new shape.
  if (oldVersion < 9) {
    await _addLanguageSchema(db);
  }
  // v5 once added the panel-adapter tables. They are dropped again in
  // v12, so older databases skip them and go straight to v12.
  if (oldVersion < 12) {
    await _migrateToCatalogSchema(db, (clock ?? DateTime.now)());
  }
  // v13 removes packages: providers only, with a remote directory.
  if (oldVersion < 13) {
    await _migrateToProviderDirectorySchema(db);
  }
  // v14 adds saved proxies and ssh_configurations.proxy_id. sqflite
  // runs onUpgrade in one transaction, so a failure rolls both back.
  if (oldVersion < 14) {
    await _addProxySchema(db);
  }
}
