import 'dart:convert';
import 'dart:io';

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

  test('parsed logo metadata matches the committed index', () {
    final entries = {
      for (final entry in raw['providers'] as List) entry['id']: entry,
    };
    for (final p in snapshot.providers) {
      final logo = p.logo;
      expect(
        logo == null
            ? null
            : {'path': logo.path, 'sha256': logo.sha256, 'bytes': logo.bytes},
        entries[p.id]['logo'],
        reason: p.id,
      );
    }
  });
}
