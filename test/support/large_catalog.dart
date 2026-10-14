import 'dart:convert';

import 'package:vps_tell_you/providers/provider_directory.dart';

import 'catalog_fixture.dart';

/// Test-only directory for scale: [providers] providers (300 by default).
/// Names mix English, accents and Chinese so that folding and CJK search can
/// be exercised:
///
/// * provider `n` with `n % 4 == 0` → `Cloud Nine <n>`
/// * `n % 4 == 1` → `云海主机 <n>`
/// * `n % 4 == 2` → `Café Hosting <n>`
/// * `n % 4 == 3` → `Ünited Servers <n>`
///
/// Provider ids are `big-<n>` (zero padded to 3). Both language names are the
/// same text, so the tests do not depend on the interface language.
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

DirectorySnapshot largeCatalog({int providers = 300}) =>
    DirectorySnapshot.parse(
      jsonEncode(
        directoryIndexJson(
          version: 1,
          providers: [
            for (var n = 0; n < providers; n++)
              directoryEntry(
                largeProviderId(n),
                zh: largeProviderName(n),
                en: largeProviderName(n),
              ),
          ],
        ),
      ),
    );

ProviderDirectory largeDirectory({int providers = 300}) =>
    ProviderDirectory.memory(largeCatalog(providers: providers));
