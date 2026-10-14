import 'dart:convert';

import 'package:vps_tell_you/providers/provider_catalog.dart';

/// Test-only directory for scale: [providers] providers (300 by default).
/// Names mix English, accents and Chinese so that folding and CJK search can
/// be exercised:
///
/// * provider `n` with `n % 4 == 0` → `Cloud Nine <n>`
/// * `n % 4 == 1` → `云海主机 <n>`
/// * `n % 4 == 2` → `Café Hosting <n>`
/// * `n % 4 == 3` → `Ünited Servers <n>`
///
/// Provider ids are `big-<n>` (zero padded to 3).
String largeProviderName(int n) {
  final id = '$n';
  return switch (n % 4) {
    0 => 'Cloud Nine $id',
    1 => '云海主机 $id',
    2 => 'Café Hosting $id',
    _ => 'Ünited Servers $id',
  };
}

String largeProviderId(int n) => 'big-${n.toString().padLeft(3, '0')}';

CatalogSnapshot largeCatalog({int providers = 300}) => CatalogSnapshot.parse(
  jsonEncode({
    'schemaVersion': 1,
    'catalogVersion': 1,
    'providers': [
      for (var n = 0; n < providers; n++)
        {'id': largeProviderId(n), 'name': largeProviderName(n)},
    ],
  }),
);

class LargeCatalog implements ProviderCatalog {
  LargeCatalog({int providers = 300})
    : snapshot = largeCatalog(providers: providers);
  final CatalogSnapshot snapshot;
  @override
  Future<CatalogSnapshot> load() async => snapshot;
}
