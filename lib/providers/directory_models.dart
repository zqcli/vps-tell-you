import 'dart:convert';

/// Thrown for a directory document which cannot be used at all. The detail is
/// for logs and tests, never shown to the user.
class DirectoryFormatException implements Exception {
  const DirectoryFormatException(this.detail);
  final String detail;
  @override
  String toString() => 'DirectoryFormatException: $detail';
}

/// The logo file of a provider: path inside the directory, and the size and
/// SHA-256 the downloaded file must match.
class DirectoryLogo {
  const DirectoryLogo({
    required this.path,
    required this.sha256,
    required this.bytes,
  });
  final String path, sha256;
  final int bytes;

  /// First eight hex digits: part of the cached file name, so a changed logo
  /// is a new file.
  String get shortHash => sha256.substring(0, 8);
}

enum ProviderKind { cloud, vps }

enum ProviderRegion { cn, global }

/// One provider of the public directory. Local providers link to it by [id].
class DirectoryProvider {
  const DirectoryProvider({
    required this.id,
    required this.nameZh,
    required this.nameEn,
    required this.kind,
    required this.region,
    required this.website,
    this.aliases = const [],
    this.descriptionZh = '',
    this.descriptionEn = '',
    this.logo,
  });

  final String id, nameZh, nameEn, website, descriptionZh, descriptionEn;
  final List<String> aliases;
  final ProviderKind kind;
  final ProviderRegion region;
  final DirectoryLogo? logo;

  static final idPattern = RegExp(r'^[a-z0-9-]{2,40}$');

  /// Name for a language code (`zh` / `en`); other languages read English.
  String nameFor(String language) => language == 'zh' ? nameZh : nameEn;

  /// Description for [language], falling back en → zh when missing.
  String descriptionFor(String language) {
    final preferred = language == 'zh' ? descriptionZh : descriptionEn;
    if (preferred.isNotEmpty) return preferred;
    return descriptionEn.isNotEmpty ? descriptionEn : descriptionZh;
  }

  /// Everything a search may match: both names and all aliases.
  List<String> get searchNames => [nameZh, nameEn, ...aliases];

  /// Strict reader of one `index.json` entry; throws on any violation. Unknown
  /// fields are ignored.
  factory DirectoryProvider.fromJson(Object? json) {
    Never bad(String field) =>
        throw DirectoryFormatException('provider $field');
    if (json is! Map) bad('entry');
    final id = json['id'];
    if (id is! String || !idPattern.hasMatch(id)) bad('id');

    String text(Object? value, String field, {required int max}) {
      if (value is! String ||
          value.trim().isEmpty ||
          value != value.trim() ||
          value.length > max ||
          value.contains('\u0000')) {
        bad(field);
      }
      return value;
    }

    String optionalText(Object? value, String field, {required int max}) {
      if (value == null) return '';
      if (value is! String || value.length > max || value.contains('\u0000')) {
        bad(field);
      }
      return value.trim();
    }

    final name = json['name'];
    if (name is! Map) bad('name');
    final description = json['description'] ?? const {};
    if (description is! Map) bad('description');

    final aliases = json['aliases'] ?? const [];
    if (aliases is! List || aliases.length > 20) bad('aliases');

    final website = text(json['website'], 'website', max: 200);
    final uri = Uri.tryParse(website);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      bad('website');
    }

    final kind = ProviderKind.values.asNameMap()[json['kind']];
    final region = ProviderRegion.values.asNameMap()[json['region']];
    if (kind == null) bad('kind');
    if (region == null) bad('region');

    DirectoryLogo? logo;
    final rawLogo = json['logo'];
    if (rawLogo != null) {
      if (rawLogo is! Map) bad('logo');
      final path = rawLogo['path'], hash = rawLogo['sha256'];
      final bytes = rawLogo['bytes'];
      if (path != 'providers/$id/logo.png' ||
          hash is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash) ||
          bytes is! int ||
          bytes < 1 ||
          bytes > DirectorySnapshot.maxLogoBytes) {
        bad('logo');
      }
      logo = DirectoryLogo(path: path as String, sha256: hash, bytes: bytes);
    }

    return DirectoryProvider(
      id: id,
      nameZh: text(name['zh'], 'name.zh', max: 80),
      nameEn: text(name['en'], 'name.en', max: 80),
      aliases: [for (final alias in aliases) text(alias, 'alias', max: 80)],
      kind: kind,
      region: region,
      website: website,
      // The app is more forgiving than the authoring script (40 / 120).
      descriptionZh: optionalText(
        description['zh'],
        'description.zh',
        max: 120,
      ),
      descriptionEn: optionalText(
        description['en'],
        'description.en',
        max: 360,
      ),
      logo: logo,
    );
  }
}

/// An immutable, validated `index.json`.
class DirectorySnapshot {
  DirectorySnapshot({
    required this.catalogVersion,
    required Iterable<DirectoryProvider> providers,
    this.generatedAt,
    this.skipped = 0,
  }) : providers = List.unmodifiable(providers),
       _byId = {for (final p in providers) p.id: p};

  static const schemaVersion = 1;
  static const maxIndexBytes = 1024 * 1024;
  static const maxLogoBytes = 128 * 1024;
  static const maxProviders = 1000;

  final int catalogVersion;
  final DateTime? generatedAt;
  final List<DirectoryProvider> providers;

  /// Entries which were left out because they were invalid.
  final int skipped;
  final Map<String, DirectoryProvider> _byId;

  DirectoryProvider? provider(String id) => _byId[id];

  /// Parses a document. A wrong `schemaVersion`, a missing `catalogVersion` or
  /// a malformed list rejects the whole document; invalid or duplicate entries
  /// are skipped and counted in [skipped].
  factory DirectorySnapshot.parse(String source) {
    if (source.length > maxIndexBytes ||
        utf8.encode(source).length > maxIndexBytes) {
      throw const DirectoryFormatException('index too large');
    }
    final Object? root;
    try {
      root = jsonDecode(source);
    } catch (_) {
      throw const DirectoryFormatException('not JSON');
    }
    if (root is! Map) throw const DirectoryFormatException('root');
    if (root['schemaVersion'] != schemaVersion) {
      throw const DirectoryFormatException('unsupported schemaVersion');
    }
    final version = root['catalogVersion'];
    if (version is! int || version < 0) {
      throw const DirectoryFormatException('catalogVersion');
    }
    DateTime? generated;
    if (root['generatedAt'] != null) {
      final raw = root['generatedAt'];
      generated = raw is String ? DateTime.tryParse(raw) : null;
      if (generated == null) {
        throw const DirectoryFormatException('generatedAt');
      }
    }
    final list = root['providers'];
    if (list is! List || list.length > maxProviders) {
      throw const DirectoryFormatException('providers');
    }
    final seen = <String>{};
    final providers = <DirectoryProvider>[];
    var skipped = 0;
    for (final item in list) {
      try {
        final provider = DirectoryProvider.fromJson(item);
        if (!seen.add(provider.id)) throw const DirectoryFormatException('dup');
        providers.add(provider);
      } on DirectoryFormatException {
        skipped++;
      }
    }
    return DirectorySnapshot(
      catalogVersion: version,
      providers: providers,
      generatedAt: generated,
      skipped: skipped,
    );
  }
}
