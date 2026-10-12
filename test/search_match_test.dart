import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/core/search_match.dart';

bool hit(String haystack, String query) =>
    matchesTokens(searchHaystack([haystack]), searchTokens(query));

void main() {
  test('folds case, accents, ligatures and full-width characters', () {
    expect(foldSearch('Café Ünited ÅÄÖ Straße'), 'cafe united aao strasse');
    expect(foldSearch('ＡＢＣ１２３　x'), 'abc123 x');
    expect(foldSearch('Œuvre Æon'), 'oeuvre aeon');
    expect(foldSearch('云海 Host'), '云海 host');
  });

  test('every word must match; order does not matter', () {
    expect(hit('Cloud Nine 12', 'nine cloud'), isTrue);
    expect(hit('Cloud Nine 12', 'cloud tokyo'), isFalse);
    expect(hit('Cloud Nine 12', '   '), isTrue, reason: 'no words');
  });

  test('accent-insensitive in both directions', () {
    expect(hit('Café Hosting', 'cafe'), isTrue);
    expect(hit('Cafe Hosting', 'CAFÉ'), isTrue);
    expect(hit('Ünited', 'united'), isTrue);
  });

  test('Chinese matches anywhere in the text', () {
    expect(hit('云海主机 7', '海主'), isTrue);
    expect(hit('云海主机 7', '主机 7'), isTrue);
    expect(hit('云海主机 7', '雪'), isFalse);
  });

  test('numbers glue to their units and never start mid-number', () {
    expect(searchTokens('2 GB  RAM'), ['2gb', 'ram']);
    expect(hit('2 GiB · 40 GiB', '2 gib'), isTrue);
    expect(hit('12gb', '2gb'), isFalse, reason: 'would be a different size');
    expect(hit('1.5gb', '5gb'), isFalse, reason: 'after a decimal point');
    expect(hit('x 2gb', '2gb'), isTrue);
    expect(hit('plan 12', '12'), isTrue);
    expect(hit('plan 12', '2'), isFalse);
  });

  test('names sort with numbers by value', () {
    final names = [
      'Plan 10',
      'plan 2',
      'Plan 02b',
      'Café 1',
      'cafe 1',
      'Plan 1',
    ];
    names.sort(compareNames);
    expect(names, [
      'Café 1',
      'cafe 1',
      'Plan 1',
      'plan 2',
      'Plan 02b',
      'Plan 10',
    ]);
  });
}
