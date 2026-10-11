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
