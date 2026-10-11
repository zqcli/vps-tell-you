import 'dart:convert';

import 'package:vps_tell_you/providers/provider_catalog.dart';

const _gib = 1024 * 1024 * 1024;

Map<String, Object?> fixturePackage(
  String id,
  String name, {
  bool isDefault = false,
  int vcpu = 2,
  int ramGib = 2,
  int amountMinor = 1200,
  String currency = 'USD',
  int cycleMonths = 1,
  String region = '',
  bool unlimited = false,
}) => {
  'id': id,
  'name': name,
  if (isDefault) 'default': true,
  'vcpu': vcpu,
  'ramBytes': ramGib * _gib,
  'diskBytes': 40 * _gib,
  'traffic': {
    if (unlimited) 'unlimited': true else 'bytes': 1024 * _gib,
    'periodMonths': 1,
  },
  'price': {
    'amountMinor': amountMinor,
    'currency': currency,
    'cycleMonths': cycleMonths,
  },
  if (region.isNotEmpty) 'region': region,
};

/// Document with a provider which has three packages and one with none.
Map<String, Object?> fixtureCatalogJson({
  int version = 3,
  int smallAmount = 1200,
}) => {
  'schemaVersion': 1,
  'catalogVersion': version,
  'providers': [
    {
      'id': 'fixture-cloud',
      'name': 'Fixture Cloud',
      'packages': [
        fixturePackage('fc-nano', 'Nano', vcpu: 1, ramGib: 1, amountMinor: 500),
        fixturePackage(
          'fc-small',
          'Small',
          isDefault: true,
          amountMinor: smallAmount,
          region: 'Fixture Region',
        ),
        fixturePackage(
          'fc-large',
          'Large',
          vcpu: 8,
          ramGib: 16,
          amountMinor: 9600,
          cycleMonths: 12,
          unlimited: true,
        ),
      ],
    },
    {'id': 'empty-host', 'name': 'Empty Host'},
  ],
};

CatalogSnapshot fixtureCatalog({int version = 3, int smallAmount = 1200}) =>
    CatalogSnapshot.parse(
      jsonEncode(
        fixtureCatalogJson(version: version, smallAmount: smallAmount),
      ),
    );

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
