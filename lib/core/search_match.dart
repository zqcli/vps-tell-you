/// Forgiving text search for long lists (providers).
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
  if (_isAscii(input)) return input.toLowerCase();
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

bool _isAscii(String input) {
  for (var i = 0; i < input.length; i++) {
    if (input.codeUnitAt(i) > 0x7f) return false;
  }
  return true;
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

int _digitRunEnd(String s, int from) {
  var end = from;
  while (end < s.length && _isDigit(s.codeUnitAt(end))) {
    end++;
  }
  return end;
}

// A sort compares every name O(log n) times; folding non-ASCII text (CJK,
// accents) each time dominates, so remember recent results.
final _nameFolds = <String, String>{};

String _foldedName(String name) {
  if (_nameFolds.length >= 4096) _nameFolds.clear();
  return _nameFolds[name] ??= foldSearch(name);
}

/// Orders names by folded text with digit runs compared by value, so
/// "Plan 2" sorts before "Plan 10". Ties fall back to the raw strings.
int compareNames(String a, String b) {
  final x = _foldedName(a), y = _foldedName(b);
  var i = 0, j = 0;
  while (i < x.length && j < y.length) {
    final cx = x.codeUnitAt(i), cy = y.codeUnitAt(j);
    if (_isDigit(cx) && _isDigit(cy)) {
      final endX = _digitRunEnd(x, i), endY = _digitRunEnd(y, j);
      // Compare by value: skip leading zeros (keeping the last digit), then
      // the longer run is larger.
      var startX = i, startY = j;
      while (startX < endX - 1 && x.codeUnitAt(startX) == 0x30) {
        startX++;
      }
      while (startY < endY - 1 && y.codeUnitAt(startY) == 0x30) {
        startY++;
      }
      final lengthX = endX - startX, lengthY = endY - startY;
      final c = lengthX != lengthY
          ? lengthX.compareTo(lengthY)
          : x.substring(startX, endX).compareTo(y.substring(startY, endY));
      if (c != 0) return c;
      i = endX;
      j = endY;
      continue;
    }
    final c = cx.compareTo(cy);
    if (c != 0) return c;
    i++;
    j++;
  }
  final c = (x.length - i).compareTo(y.length - j);
  return c != 0 ? c : a.compareTo(b);
}
