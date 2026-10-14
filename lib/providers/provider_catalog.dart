import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// Thrown for any directory document which does not satisfy the contract in
/// docs/PROVIDERS.md. The detail is for logs/tests, never shown to the user.
class CatalogFormatException implements Exception {
  const CatalogFormatException(this.detail);
  final String detail;
  @override
  String toString() => 'CatalogFormatException: $detail';
}

/// Where the provider directory comes from.
abstract interface class ProviderCatalog {
  Future<CatalogSnapshot> load();
}

/// One provider of the directory. Local providers link to it by [id].
class CatalogProvider {
  const CatalogProvider({required this.id, required this.name});
  final String id, name;

  static final idPattern = RegExp(r'^[a-z0-9][a-z0-9-]{0,39}$');
}

/// An immutable, validated directory document.
class CatalogSnapshot {
  CatalogSnapshot({
    required this.catalogVersion,
    required Iterable<CatalogProvider> providers,
    this.etag,
    this.generatedAt,
  }) : providers = List.unmodifiable(providers);

  static const schemaVersion = 1;
  static const maxBytes = 8 * 1024 * 1024;
  static const maxProviders = 1000;

  final int catalogVersion;
  final String? etag;
  final DateTime? generatedAt;
  final List<CatalogProvider> providers;

  static CatalogSnapshot get empty =>
      CatalogSnapshot(catalogVersion: 0, providers: const []);

  CatalogProvider? provider(String id) =>
      providers.where((p) => p.id == id).firstOrNull;

  /// Parses a directory document strictly. Unknown fields are ignored.
  factory CatalogSnapshot.parse(String source, {String? etag}) {
    if (source.length > maxBytes || utf8.encode(source).length > maxBytes) {
      throw const CatalogFormatException('document too large');
    }
    final Object? root;
    try {
      root = jsonDecode(source);
    } catch (_) {
      throw const CatalogFormatException('not JSON');
    }
    if (root is! Map) throw const CatalogFormatException('root');
    if (root['schemaVersion'] != schemaVersion) {
      throw const CatalogFormatException('unsupported schemaVersion');
    }
    final version = root['catalogVersion'];
    if (version is! int || version < 0) {
      throw const CatalogFormatException('catalogVersion');
    }
    DateTime? generated;
    if (root['generatedAt'] != null) {
      generated = root['generatedAt'] is String
          ? DateTime.tryParse(root['generatedAt'] as String)
          : null;
      if (generated == null) throw const CatalogFormatException('generatedAt');
    }
    final list = root['providers'];
    if (list is! List || list.length > maxProviders) {
      throw const CatalogFormatException('providers');
    }
    final ids = <String>{};
    final providers = <CatalogProvider>[];
    for (final item in list) {
      if (item is! Map) throw const CatalogFormatException('provider');
      final id = item['id'];
      final name = item['name'];
      if (id is! String ||
          !CatalogProvider.idPattern.hasMatch(id) ||
          !ids.add(id) ||
          name is! String ||
          name.trim().isEmpty ||
          name.length > 80 ||
          name != name.trim()) {
        throw const CatalogFormatException('provider id or name');
      }
      providers.add(CatalogProvider(id: id, name: name));
    }
    return CatalogSnapshot(
      catalogVersion: version,
      providers: providers,
      etag: etag,
      generatedAt: generated,
    );
  }
}

/// The example list shipped inside the app (`assets/catalog/providers.json`).
class BuiltinProviderCatalog implements ProviderCatalog {
  const BuiltinProviderCatalog({
    this.assetPath = 'assets/catalog/providers.json',
    this.bundle,
  });
  final String assetPath;
  final AssetBundle? bundle;

  @override
  Future<CatalogSnapshot> load() async =>
      CatalogSnapshot.parse(await (bundle ?? rootBundle).loadString(assetPath));
}
