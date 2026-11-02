/// A business provider owned by the user's ledger. It may be linked to one
/// catalog provider ([catalogId]); user-created providers have none. The name
/// is a local display copy: renaming it never changes the catalog link.
class ProviderRecord {
  const ProviderRecord({
    required this.id,
    required this.name,
    required this.createdAt,
    this.revision = 0,
    this.catalogId,
  });

  final String id, name;
  final DateTime createdAt;
  final int revision;
  final String? catalogId;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'created_at': createdAt.toUtc().toIso8601String(),
    'revision': revision,
    'catalog_id': catalogId,
  };

  factory ProviderRecord.fromMap(Map<String, Object?> row) => ProviderRecord(
    id: row['id'] as String,
    name: row['name'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    revision: row['revision'] as int,
    catalogId: row['catalog_id'] as String?,
  );
}

/// Identifies the catalog provider a local provider is created from.
class CatalogProviderRef {
  const CatalogProviderRef({required this.catalogId, required this.name});
  final String catalogId, name;
}

/// What the user picked as the provider of a server. A null route result
/// means cancellation. [provider] is the existing local provider; [catalog] is
/// the catalog provider it belongs to (or, with a null [provider], the catalog
/// provider whose local provider is created when the server is saved). Both
/// null is the explicit "no provider" choice.
class ProviderSelection {
  const ProviderSelection(this.provider, {this.catalog});
  final ProviderRecord? provider;
  final CatalogProviderRef? catalog;

  bool get isPending => provider == null && catalog != null;
  String? get name => provider?.name ?? catalog?.name;
  CatalogProviderRef? get pendingRef => isPending ? catalog : null;
}

/// What the server form's provider picker returns. A null route result means
/// cancelled; [none] is the explicit "no provider".
class ProviderChoice {
  const ProviderChoice.none() : local = null, catalog = null, draft = null;
  const ProviderChoice.local(ProviderRecord this.local)
    : catalog = null,
      draft = null;
  const ProviderChoice.catalog(CatalogProviderRef this.catalog)
    : local = null,
      draft = null;
  const ProviderChoice.draft(ProviderRecord this.draft)
    : local = null,
      catalog = null;

  /// An existing local provider.
  final ProviderRecord? local;

  /// A directory provider that gets its local provider when the server is saved.
  final CatalogProviderRef? catalog;

  /// A new user provider that is created when the server is saved.
  final ProviderRecord? draft;
}
