import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/providers/directory_models.dart';

/// The repository's own `catalog/index.json` must be accepted by the app's
/// strict parser, entry for entry. Other tests use fixtures, not this content.
void main() {
  final index = File('catalog/index.json');
  late String text;
  late DirectorySnapshot snapshot;
  late Map<String, dynamic> raw;

  setUpAll(() {
    text = index.readAsStringSync();
    snapshot = DirectorySnapshot.parse(text);
    raw = jsonDecode(text) as Map<String, dynamic>;
  });

  test('every entry is accepted, none skipped, ids unique', () {
    final entries = raw['providers'] as List;
    expect(entries, isNotEmpty);
    expect(snapshot.skipped, 0);
    expect(snapshot.providers, hasLength(entries.length));
    final ids = snapshot.providers.map((p) => p.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids, [...ids]..sort(), reason: 'sorted by id');
    expect(index.lengthSync(), lessThan(DirectorySnapshot.maxIndexBytes));
  });

  test('names and aliases point to one provider each', () {
    final owner = <String, String>{};
    for (final p in snapshot.providers) {
      for (final term in {...p.searchNames.map((n) => n.toLowerCase())}) {
        expect(owner.putIfAbsent(term, () => p.id), p.id, reason: term);
      }
    }
  });

  test('logo hashes, sizes and PNG headers match the files', () {
    var withLogo = 0;
    for (final p in snapshot.providers) {
      final dir = Directory('catalog/providers/${p.id}');
      expect(dir.existsSync(), isTrue, reason: p.id);
      final logo = p.logo;
      final file = File('${dir.path}/logo.png');
      if (logo == null) {
        expect(file.existsSync(), isFalse, reason: '${p.id} has no logo');
        continue;
      }
      withLogo++;
      final bytes = file.readAsBytesSync();
      expect(logo.path, 'providers/${p.id}/logo.png');
      expect(bytes.length, logo.bytes, reason: p.id);
      expect(bytes.length, lessThanOrEqualTo(64 * 1024), reason: p.id);
      expect(sha256.convert(bytes).toString(), logo.sha256, reason: p.id);
      expect(bytes.sublist(0, 8), [
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
      ]);
      final data = ByteData.sublistView(bytes);
      expect(
        [data.getUint32(16), data.getUint32(20)],
        [256, 256],
        reason: '${p.id} is 256x256',
      );
    }
    expect(withLogo, greaterThan(0));
    expect(
      withLogo,
      lessThan(snapshot.providers.length),
      reason: 'some have none',
    );
  });

  test('entries without a logo are valid and fall back to initials', () {
    final none = snapshot.providers.where((p) => p.logo == null);
    expect(none, isNotEmpty);
    for (final p in none) {
      expect(p.nameEn, isNotEmpty);
    }
  });
}
