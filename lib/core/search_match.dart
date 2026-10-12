/// Forgiving text search for long lists (providers, packages).
///
/// Both sides are *folded* first: lower case, accents removed (`Café` finds
/// `cafe`), width-folded (full-width Latin / digits), and a number glued to
/// its unit (`2 GB` → `2gb`). A query is several words that must all occur;
/// CJK text matches anywhere inside the haystack, so `海` finds `云海主机`.
library;

// One entry per base letter: the letter followed by its accented forms.
const _groups = [
  'aàáâãäåāăą',
  'cçćĉċč',
  'dďđ',
  'eèéêëēĕėęě',
  'gĝğġģ',
  'hĥħ',
  'iìíîïĩīĭįı',
  'jĵ',
  'kķ',
  'lĺļľŀł',
  'nñńņň',
  'oòóôõöøōŏő',
  'rŕŗř',
  'sśŝşš',
  'tţťŧ',
  'uùúûüũūŭůűų',
  'wŵ',
  'yýÿŷ',
  'zźżž',
];

final _foldMap = <int, String>{
  for (final group in _groups)
    for (final rune in group.runes.skip(1)) rune: group[0],
  0xdf: 'ss',
  0xe6: 'ae',
  0x153: 'oe',
};

/// Lower-cased, accent-free, width-folded copy of [input].
String foldSearch(String input) {
  final out = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    if (rune >= 0xff01 && rune <= 0xff5e) {
      out.writeCharCode(rune - 0xfee0); // full-width ASCII
    } else if (rune == 0x3000) {
      out.write(' ');
    } else {
      out.write(_foldMap[rune] ?? String.fromCharCode(rune));
    }
  }
  return out.toString();
}

final _numberUnit = RegExp(r'(\d)\s+(?=[a-z])');

/// Folded haystack text for [parts]: fold, then glue numbers to units.
String searchHaystack(Iterable<String> parts) => parts
    .map((part) => foldSearch(part).replaceAllMapped(_numberUnit, (m) => m[1]!))
    .join(' ');

/// The words of a folded query (numbers glued to their units).
List<String> searchTokens(String query) =>
    foldSearch(query)
        .replaceAllMapped(_numberUnit, (m) => m[1]!)
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList(growable: false);

bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;

/// Whether every token of [tokens] occurs in the folded [haystack]. A token
/// that starts with a digit must not start in the middle of a number, so
/// `2gb` finds `2 GiB`-style text but not `12gb`.
bool matchesTokens(String haystack, List<String> tokens) {
  for (final token in tokens) {
    var from = 0;
    var found = false;
    while (true) {
      final at = haystack.indexOf(token, from);
      if (at < 0) break;
      if (!_isDigit(token.codeUnitAt(0)) ||
          at == 0 ||
          !(_isDigit(haystack.codeUnitAt(at - 1)) ||
              haystack.codeUnitAt(at - 1) == 0x2e)) {
        found = true;
        break;
      }
      from = at + 1;
    }
    if (!found) return false;
  }
  return true;
}
