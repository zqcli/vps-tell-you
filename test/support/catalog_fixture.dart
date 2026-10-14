import 'dart:convert';

import 'package:vps_tell_you/providers/provider_catalog.dart';

/// Document with two providers.
Map<String, Object?> fixtureCatalogJson({int version = 3}) => {
  'schemaVersion': 1,
  'catalogVersion': version,
  'providers': [
    {'id': 'fixture-cloud', 'name': 'Fixture Cloud'},
    {'id': 'empty-host', 'name': 'Empty Host'},
  ],
};

CatalogSnapshot fixtureCatalog({int version = 3}) =>
    CatalogSnapshot.parse(jsonEncode(fixtureCatalogJson(version: version)));

class MemoryCatalog implements ProviderCatalog {
  MemoryCatalog([CatalogSnapshot? snapshot])
    : snapshot = snapshot ?? fixtureCatalog();
  CatalogSnapshot snapshot;
  int loads = 0;
  @override
  Future<CatalogSnapshot> load() async {
    loads++;
    return snapshot;
  }
}

class FailingCatalog implements ProviderCatalog {
  @override
  Future<CatalogSnapshot> load() async =>
      throw const CatalogFormatException('synthetic failure');
}
