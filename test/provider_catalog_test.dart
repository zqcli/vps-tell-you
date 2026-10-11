import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/providers/provider_catalog.dart';

import 'support/catalog_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled catalog has two labelled example providers', () async {
    final catalog = await const BuiltinProviderCatalog().load();
    expect(catalog.providers.map((p) => p.name), ['Example Cloud', 'Demo VPS']);
    for (final provider in catalog.providers) {
      expect(provider.packages.length, inInclusiveRange(2, 3));
      expect(provider.packages.where((p) => p.isDefault), hasLength(1));
      for (final package in provider.packages) {
        expect(package.providerId, provider.id);
        expect(package.notes, contains('Sample'));
      }
    }
    expect(catalog.package('example-cloud-small')!.isDefault, isTrue);
    expect(catalog.package('demo-vps-basic')!.price!.currency, 'EUR');
  });

  test('a provider without packages is valid and has no default', () {
    final catalog = fixtureCatalog();
    final empty = catalog.provider('empty-host')!;
    expect(empty.packages, isEmpty);
    expect(empty.defaultPackage, isNull);
    expect(catalog.provider('fixture-cloud')!.defaultPackage!.id, 'fc-small');
  });

  test('every package keeps its provider and catalog version', () {
    final package = fixtureCatalog(version: 9).package('fc-large')!;
    expect(package.providerId, 'fixture-cloud');
    expect(package.catalogVersion, 9);
    expect(package.trafficUnlimited, isTrue);
    expect(package.trafficBytes, isNull);
    expect(package.resources.vcpu, 8);
  });

  group('strict document validation', () {
    String mutate(void Function(Map<String, dynamic>) change) {
      final doc =
          jsonDecode(jsonEncode(fixtureCatalogJson())) as Map<String, dynamic>;
      change(doc);
      return jsonEncode(doc);
    }

    Map<String, dynamic> pkg(Map<String, dynamic> doc, [int i = 0]) =>
        (doc['providers'][0]['packages'] as List)[i] as Map<String, dynamic>;

    final bad = <String, String Function()>{
      'future schemaVersion': () => mutate((d) => d['schemaVersion'] = 2),
      'missing catalogVersion': () => mutate((d) => d.remove('catalogVersion')),
      'no default': () => mutate((d) => pkg(d, 1).remove('default')),
      'two defaults': () => mutate((d) => pkg(d)['default'] = true),
      'duplicate package id': () => mutate((d) => pkg(d)['id'] = 'fc-small'),
      'duplicate provider id': () =>
          mutate((d) => d['providers'][1]['id'] = 'fixture-cloud'),
      'bad package id': () => mutate((d) => pkg(d)['id'] = 'Bad Id'),
      'empty name': () => mutate((d) => pkg(d)['name'] = ' '),
      'zero vcpu': () => mutate((d) => pkg(d)['vcpu'] = 0),
      'string ram': () => mutate((d) => pkg(d)['ramBytes'] = '1'),
      'unlimited with bytes': () =>
          mutate((d) => pkg(d, 2)['traffic'] = {'unlimited': true, 'bytes': 5}),
      'bad period': () =>
          mutate((d) => pkg(d)['traffic'] = {'bytes': 1, 'periodMonths': 5}),
      'unsupported currency': () =>
          mutate((d) => pkg(d)['price']['currency'] = 'JPY'),
      'bad cycle': () => mutate((d) => pkg(d)['price']['cycleMonths'] = 5),
      'negative price': () =>
          mutate((d) => pkg(d)['price']['amountMinor'] = -1),
      'providers not a list': () => mutate((d) => d['providers'] = {}),
      'not json': () => '{nope',
    };
    for (final entry in bad.entries) {
      test('rejects ${entry.key}', () {
        expect(
          () => CatalogSnapshot.parse(entry.value()),
          throwsA(isA<CatalogFormatException>()),
        );
      });
    }

    test('unknown fields are ignored (forward compatible)', () {
      final parsed = CatalogSnapshot.parse(
        mutate((d) {
          d['futureField'] = 1;
          pkg(d)['badge'] = 'new';
        }),
      );
      expect(parsed.providers, hasLength(2));
    });

    test('a free package (price 0) is valid', () {
      final parsed = CatalogSnapshot.parse(
        mutate((d) => pkg(d)['price']['amountMinor'] = 0),
      );
      expect(parsed.package('fc-nano')!.price!.amountMinor, 0);
    });

    test('oversized documents are rejected', () {
      expect(
        () => CatalogSnapshot.parse(' ' * (CatalogSnapshot.maxBytes + 1)),
        throwsA(isA<CatalogFormatException>()),
      );
    });
  });

  group('snapshots', () {
    test('round trip exactly and exclude the default flag', () {
      final package = fixtureCatalog().package('fc-small')!;
      expect(package.isDefault, isTrue);
      final restored = CatalogPackage.decodeSnapshot(package.encodeSnapshot());
      expect(restored.isDefault, isFalse);
      expect(restored.encodeSnapshot(), package.encodeSnapshot());
      expect(restored.sameSpecAs(package), isTrue);
      expect(restored.region, 'Fixture Region');
    });

    test('differences in spec are detected; version and default are not', () {
      final base = fixtureCatalog().package('fc-small')!;
      expect(
        fixtureCatalog(version: 4).package('fc-small')!.sameSpecAs(base),
        isTrue,
      );
      expect(
        fixtureCatalog(smallAmount: 1300).package('fc-small')!.sameSpecAs(base),
        isFalse,
      );
    });

    test('strict reader rejects tampering', () {
      final good = jsonDecode(
        fixtureCatalog().package('fc-small')!.encodeSnapshot(),
      ) as Map<String, dynamic>;
      for (final change in <void Function(Map<String, dynamic>)>[
        (m) => m['snapshotVersion'] = 2,
        (m) => m['extra'] = 1,
        (m) => m['id'] = 'BAD ID',
        (m) => m['price'] = {
          'amountMinor': 1,
          'currency': 'XXX',
          'cycleMonths': 1,
        },
        (m) => m.remove('providerId'),
      ]) {
        final copy = Map<String, dynamic>.from(good);
        change(copy);
        expect(
          () => CatalogPackage.decodeSnapshot(jsonEncode(copy)),
          throwsA(isA<CatalogFormatException>()),
        );
      }
      expect(
        () => CatalogPackage.decodeSnapshot('x' * 5000),
        throwsA(isA<CatalogFormatException>()),
      );
    });
  });
}
