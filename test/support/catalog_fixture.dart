import 'dart:convert';

import 'package:vps_tell_you/providers/provider_directory.dart';

/// One `index.json` entry (without a logo unless [logo] is given).
Map<String, Object?> directoryEntry(
  String id, {
  String? zh,
  String? en,
  List<String> aliases = const [],
  String kind = 'cloud',
  String region = 'global',
  String? descriptionZh,
  String? descriptionEn,
  Map<String, Object?>? logo,
}) => {
  'id': id,
  'name': {'zh': zh ?? '$id 中文', 'en': en ?? id},
  'aliases': aliases,
  'kind': kind,
  'region': region,
  'website': 'https://$id.example.com',
  'description': {
    'zh': descriptionZh ?? '$id 的说明。',
    'en': descriptionEn ?? 'About $id.',
  },
  'logo': ?logo,
};

Map<String, Object?> directoryIndexJson({
  int version = 3,
  List<Object?>? providers,
}) => {
  'schemaVersion': 1,
  'catalogVersion': version,
  'generatedAt': '2026-10-12T00:00:00Z',
  'providers':
      providers ??
      [
        directoryEntry(
          'fixture-cloud',
          zh: '夹具云',
          en: 'Fixture Cloud',
          aliases: ['FixtureCloud', '夹具'],
          descriptionZh: '用于测试的云服务商。',
          descriptionEn: 'A cloud provider for tests.',
        ),
        directoryEntry('empty-host', zh: '空主机', en: 'Empty Host'),
      ],
};

DirectorySnapshot fixtureCatalog({int version = 3}) =>
    DirectorySnapshot.parse(jsonEncode(directoryIndexJson(version: version)));

/// A directory with the two fixture providers and no network or disk.
ProviderDirectory fixtureDirectory({int version = 3}) =>
    ProviderDirectory.memory(fixtureCatalog(version: version));
