import 'dart:convert';

import 'package:vps_tell_you/providers/provider_catalog.dart';

import 'catalog_fixture.dart';

/// Test-only catalog for scale: [providers] providers × [packages] packages
/// (300 × 40 = 12,000 packages by default). Names mix English, accents and
/// Chinese so that folding and CJK search can be exercised:
///
/// * provider `n` with `n % 4 == 0` → `Cloud Nine <n>`
/// * `n % 4 == 1` → `云海主机 <n>`
/// * `n % 4 == 2` → `Café Hosting <n>`
/// * `n % 4 == 3` → `Ünited Servers <n>`
///
/// Provider ids are `big-<n>` (zero padded to 3), package ids
/// `big-<n>-p<j>`. Package `j` has `1 + j % 8` vCPU, `1 << (j % 5)` GiB RAM,
/// costs `5 + j` USD per month, lives in `Tokyo` when `j % 10 == 0`, and the
/// package with `j == 3` is the provider's default.
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

CatalogSnapshot largeCatalog({int providers = 300, int packages = 40}) =>
    CatalogSnapshot.parse(
      jsonEncode({
        'schemaVersion': 1,
        'catalogVersion': 1,
        'providers': [
          for (var n = 0; n < providers; n++)
            {
              'id': largeProviderId(n),
              'name': largeProviderName(n),
              'packages': [
                for (var j = 0; j < packages; j++)
                  fixturePackage(
                    '${largeProviderId(n)}-p$j',
                    'Plan $j',
                    isDefault: j == 3,
                    vcpu: 1 + j % 8,
                    ramGib: 1 << (j % 5),
                    amountMinor: (5 + j) * 100,
                    region: j % 10 == 0 ? 'Tokyo' : '',
                  ),
              ],
            },
        ],
      }),
    );

class LargeCatalog implements ProviderCatalog {
  LargeCatalog({int providers = 300, int packages = 40})
    : snapshot = largeCatalog(providers: providers, packages: packages);
  final CatalogSnapshot snapshot;
  @override
  Future<CatalogSnapshot> load() async => snapshot;
}
