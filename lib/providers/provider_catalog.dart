import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../core/value_types.dart';
import '../servers/server_resources.dart';

/// Thrown for any catalog document which does not satisfy the contract in
/// docs/PROVIDERS_AND_PACKAGES.md. The whole document is rejected; there is no
/// partial adoption. The detail is for logs/tests, never shown to the user.
class CatalogFormatException implements Exception {
  const CatalogFormatException(this.detail);
  final String detail;
  @override
  String toString() => 'CatalogFormatException: $detail';
}

/// Where providers and packages come from. A bundled asset today, a cached
/// remote document later; callers never depend on the origin.
abstract interface class ProviderCatalog {
  Future<CatalogSnapshot> load();
}

class CatalogPrice {
  const CatalogPrice({
    required this.amountMinor,
    required this.currency,
    required this.cycleMonths,
  });
  final int amountMinor, cycleMonths;
  final String currency;
  Money get money => Money(currency, amountMinor);

  Map<String, Object?> toJson() => {
    'amountMinor': amountMinor,
    'currency': currency,
    'cycleMonths': cycleMonths,
  };

  @override
  bool operator ==(Object other) =>
      other is CatalogPrice &&
      other.amountMinor == amountMinor &&
      other.currency == currency &&
      other.cycleMonths == cycleMonths;
  @override
  int get hashCode => Object.hash(amountMinor, currency, cycleMonths);
}

/// One purchasable plan of a catalog provider. Every spec field is optional:
/// a missing value is unknown and pre-fills nothing.
class CatalogPackage {
  const CatalogPackage({
    required this.id,
    required this.providerId,
    required this.name,
    this.vcpu,
    this.ramBytes,
    this.diskBytes,
    this.trafficBytes,
    this.trafficUnlimited = false,
    this.trafficPeriodMonths,
    this.price,
    this.region = '',
    this.notes = '',
    this.isDefault = false,
    this.catalogVersion = 0,
  });

  final String id, providerId, name, region, notes;
  final int? vcpu, ramBytes, diskBytes, trafficBytes, trafficPeriodMonths;
  final bool trafficUnlimited;
  final CatalogPrice? price;

  /// Preselected in the package picker. Never stored on a server.
  final bool isDefault;

  /// Catalog document version this value was read from.
  final int catalogVersion;

  static const snapshotVersion = 1;
  static final _idPattern = RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$');
  static const _cycles = [1, 3, 6, 12, 24, 36];

  /// Hardware pre-fill for the server form (addresses are never part of a
  /// package).
  ServerResources get resources => ServerResources(
    vcpu: vcpu,
    ramBytes: ramBytes,
    diskBytes: diskBytes,
    trafficBytes: trafficBytes,
    trafficUnlimited: trafficUnlimited,
    trafficPeriodMonths: trafficPeriodMonths,
  );

  bool get hasHardware =>
      vcpu != null ||
      ramBytes != null ||
      diskBytes != null ||
      trafficBytes != null ||
      trafficUnlimited;

  /// The fields which describe the plan itself; `default` and the catalog
  /// version do not count as a change of the plan.
  Map<String, Object?> _specJson() => {
    'id': id,
    'providerId': providerId,
    'name': name,
    'vcpu': vcpu,
    'ramBytes': ramBytes,
    'diskBytes': diskBytes,
    'trafficBytes': trafficBytes,
    'trafficUnlimited': trafficUnlimited,
    'trafficPeriodMonths': trafficPeriodMonths,
    'price': price?.toJson(),
    'region': region,
    'notes': notes,
  };

  bool sameSpecAs(CatalogPackage other) =>
      jsonEncode(_specJson()) == jsonEncode(other._specJson());

  /// What a server stores when this package is chosen.
  Map<String, Object?> toSnapshotJson() => {
    'snapshotVersion': snapshotVersion,
    'catalogVersion': catalogVersion,
    ..._specJson(),
  };

  String encodeSnapshot() => jsonEncode(toSnapshotJson());

  /// Strict reader for [encodeSnapshot] output (database and backups).
  factory CatalogPackage.decodeSnapshot(String source) {
    if (source.length > 4096) {
      throw const CatalogFormatException('snapshot too large');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (_) {
      throw const CatalogFormatException('snapshot is not JSON');
    }
    if (decoded is! Map ||
        decoded['snapshotVersion'] != snapshotVersion ||
        decoded['catalogVersion'] is! int ||
        decoded['providerId'] is! String) {
      throw const CatalogFormatException('snapshot header');
    }
    final package = _fromJson(
      {
        ...decoded,
        'price': decoded['price'],
        'traffic': {
          'bytes': decoded['trafficBytes'],
          'unlimited': decoded['trafficUnlimited'],
          'periodMonths': decoded['trafficPeriodMonths'],
        },
      },
      providerId: decoded['providerId'] as String,
      catalogVersion: decoded['catalogVersion'] as int,
      snapshot: true,
    );
    // The canonical form must match: no unknown or reordered content.
    if (package.encodeSnapshot() != jsonEncode(decoded)) {
      throw const CatalogFormatException('snapshot is not canonical');
    }
    return package;
  }

  static CatalogPackage _fromJson(
    Map<Object?, Object?> json, {
    required String providerId,
    required int catalogVersion,
    bool snapshot = false,
  }) {
    Never bad(String field) => throw CatalogFormatException('package $field');
    String text(String key, {required int max, bool required = false}) {
      final value = json[key];
      if (value == null && !required) return '';
      if (value is! String ||
          value.length > max ||
          (required && value.trim().isEmpty) ||
          value.contains('\u0000')) {
        bad(key);
      }
      return value;
    }

    int? integer(Object? value, String key, int min, int max) {
      if (value == null) return null;
      if (value is! int || value < min || value > max) bad(key);
      return value;
    }

    final id = text('id', max: 64, required: true);
    if (!_idPattern.hasMatch(id)) bad('id');
    final traffic = json['traffic'];
    if (traffic != null && traffic is! Map) bad('traffic');
    final trafficMap = (traffic as Map?) ?? const {};
    final unlimitedRaw = trafficMap['unlimited'];
    if (unlimitedRaw != null && unlimitedRaw is! bool) bad('traffic.unlimited');
    final unlimited = unlimitedRaw == true;
    final trafficBytes = integer(
      trafficMap['bytes'],
      'traffic.bytes',
      1,
      ServerResources.maxBytes,
    );
    if (unlimited && trafficBytes != null) bad('traffic.bytes');
    final period = integer(
      trafficMap['periodMonths'],
      'traffic.periodMonths',
      1,
      12,
    );
    if (period != null && !ServerResources.trafficPeriods.containsKey(period)) {
      bad('traffic.periodMonths');
    }
    CatalogPrice? price;
    final priceJson = json['price'];
    if (priceJson != null) {
      if (priceJson is! Map) bad('price');
      final amount = integer(
        priceJson['amountMinor'],
        'price.amountMinor',
        0,
        Money.maxMinor,
      );
      final cycle = priceJson['cycleMonths'];
      final currency = priceJson['currency'];
      if (amount == null ||
          currency is! String ||
          !Money.currencies.contains(currency) ||
          cycle is! int ||
          !_cycles.contains(cycle)) {
        bad('price');
      }
      price = CatalogPrice(
        amountMinor: amount,
        currency: currency,
        cycleMonths: cycle,
      );
    }
    final isDefault = json['default'];
    if (isDefault != null && isDefault is! bool) bad('default');
    return CatalogPackage(
      id: id,
      providerId: providerId,
      name: text('name', max: 80, required: true),
      vcpu: integer(json['vcpu'], 'vcpu', 1, ServerResources.maxVcpu),
      ramBytes: integer(
        json['ramBytes'],
        'ramBytes',
        1,
        ServerResources.maxBytes,
      ),
      diskBytes: integer(
        json['diskBytes'],
        'diskBytes',
        1,
        ServerResources.maxBytes,
      ),
      trafficBytes: trafficBytes,
      trafficUnlimited: unlimited,
      trafficPeriodMonths: period,
      price: price,
      region: text('region', max: 80),
      notes: text('notes', max: 500),
      isDefault: !snapshot && isDefault == true,
      catalogVersion: catalogVersion,
    );
  }
}

class CatalogProvider {
  const CatalogProvider({
    required this.id,
    required this.name,
    this.packages = const [],
  });
  final String id, name;
  final List<CatalogPackage> packages;

  static final _idPattern = RegExp(r'^[a-z0-9][a-z0-9-]{0,39}$');

  CatalogPackage? get defaultPackage =>
      packages.where((p) => p.isDefault).firstOrNull;
  CatalogPackage? package(String id) =>
      packages.where((p) => p.id == id).firstOrNull;
}

/// An immutable, fully validated catalog document.
class CatalogSnapshot {
  CatalogSnapshot({
    required this.catalogVersion,
    required Iterable<CatalogProvider> providers,
    this.etag,
    this.generatedAt,
  }) : providers = List.unmodifiable(providers);

  static const schemaVersion = 1;
  static const maxBytes = 1024 * 1024;
  static const maxProviders = 200;
  static const maxPackages = 200;

  final int catalogVersion;
  final String? etag;
  final DateTime? generatedAt;
  final List<CatalogProvider> providers;

  static CatalogSnapshot get empty =>
      CatalogSnapshot(catalogVersion: 0, providers: const []);

  CatalogProvider? provider(String id) =>
      providers.where((p) => p.id == id).firstOrNull;
  CatalogPackage? package(String id) {
    for (final provider in providers) {
      final found = provider.package(id);
      if (found != null) return found;
    }
    return null;
  }

  /// Parses a catalog document (bundled or, later, remote) strictly.
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
    final providerIds = <String>{}, packageIds = <String>{};
    final providers = <CatalogProvider>[];
    for (final item in list) {
      if (item is! Map) throw const CatalogFormatException('provider');
      final id = item['id'];
      final name = item['name'];
      if (id is! String ||
          !CatalogProvider._idPattern.hasMatch(id) ||
          !providerIds.add(id) ||
          name is! String ||
          name.trim().isEmpty ||
          name.length > 80 ||
          name != name.trim()) {
        throw const CatalogFormatException('provider id or name');
      }
      final rawPackages = item['packages'] ?? const [];
      if (rawPackages is! List || rawPackages.length > maxPackages) {
        throw const CatalogFormatException('packages');
      }
      final packages = <CatalogPackage>[];
      for (final raw in rawPackages) {
        if (raw is! Map) throw const CatalogFormatException('package');
        final package = CatalogPackage._fromJson(
          raw,
          providerId: id,
          catalogVersion: version,
        );
        if (!packageIds.add(package.id)) {
          throw const CatalogFormatException('duplicate package id');
        }
        packages.add(package);
      }
      if (packages.isNotEmpty &&
          packages.where((p) => p.isDefault).length != 1) {
        throw const CatalogFormatException('exactly one default package');
      }
      providers.add(CatalogProvider(id: id, name: name, packages: packages));
    }
    return CatalogSnapshot(
      catalogVersion: version,
      providers: providers,
      etag: etag,
      generatedAt: generated,
    );
  }
}

/// The catalog shipped inside the app (`assets/catalog/providers.json`).
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
