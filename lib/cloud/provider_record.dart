/// A business provider, independent of the panel implementation or credential.
/// A migrated, ambiguous provider is visible but cannot grant new associations.
class ProviderRecord {
  const ProviderRecord({
    required this.id,
    required this.name,
    required this.createdAt,
    this.revision = 0,
    this.needsReview = false,
  });

  final String id, name;
  final DateTime createdAt;
  final int revision;
  final bool needsReview;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'created_at': createdAt.toUtc().toIso8601String(),
    'revision': revision,
    'needs_review': needsReview ? 1 : 0,
  };

  factory ProviderRecord.fromMap(Map<String, Object?> row) => ProviderRecord(
    id: row['id'] as String,
    name: row['name'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    revision: row['revision'] as int,
    needsReview: row['needs_review'] == 1,
  );
}
