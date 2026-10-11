/// Semantic line tokenizer for the SSH terminal ("smart highlighting").
///
/// Pure Dart, no Flutter/xterm imports. It only decides *which character
/// ranges* of one terminal row deserve a colour; it never changes text. The
/// caller replaces cells that already carry colour or other styling with a
/// space before calling, so remote ANSI colours can never be overridden.
library;

/// What a highlighted range means. [terminalHighlightSlot] maps each kind to
/// one of the 16 ANSI slots, so colours follow the active terminal scheme.
enum HlKind {
  userHost,
  promptPath,
  promptSign,
  promptRoot,
  url,
  ip,
  path,
  number,
  dateTime,
  hex,
  string,
  error,
  warn,
  ok,
  debug,
  key,
  comment,
  http2xx,
  http3xx,
  http4xx,
  http5xx,
  dir,
  exec,
  link,
}

class HlSpan {
  const HlSpan(this.start, this.end, this.kind);

  /// Half-open range of cell indexes `[start, end)`.
  final int start, end;
  final HlKind kind;

  @override
  String toString() => 'HlSpan($start, $end, ${kind.name})';
}

/// ANSI slot (0–15, xterm `NamedColor` numbering) used for [kind].
int terminalHighlightSlot(HlKind kind) => switch (kind) {
  HlKind.userHost => 10,
  HlKind.promptPath => 4,
  HlKind.promptSign => 3,
  HlKind.promptRoot => 1,
  HlKind.url => 4,
  HlKind.ip => 6,
  HlKind.path => 4,
  HlKind.number => 3,
  HlKind.dateTime => 5,
  HlKind.hex => 5,
  HlKind.string => 2,
  HlKind.error => 1,
  HlKind.warn => 3,
  HlKind.ok => 2,
  HlKind.debug => 8,
  HlKind.key => 6,
  HlKind.comment => 8,
  HlKind.http2xx => 2,
  HlKind.http3xx => 6,
  HlKind.http4xx => 3,
  HlKind.http5xx => 1,
  HlKind.dir => 4,
  HlKind.exec => 2,
  HlKind.link => 6,
};

/// Upper bound on cells examined per row; the rest of a longer row stays plain.
const terminalHighlightMaxCells = 400;

const _errorWords = {
  'error',
  'errors',
  'err',
  'fail',
  'failed',
  'failure',
  'failures',
  'fatal',
  'denied',
  'refused',
  'panic',
  'critical',
  'crit',
  'emerg',
  'segfault',
  'aborted',
  'abort',
  'killed',
  'unreachable',
  'invalid',
  'cannot',
  'unable',
  'forbidden',
  'exception',
  'traceback',
  'timeout',
  'rejected',
  'broken',
  'dead',
  'inactive',
  'stopped',
  'unauthorized',
};
const _warnWords = {
  'warn',
  'warning',
  'warnings',
  'deprecated',
  'skipped',
  'degraded',
  'retrying',
  'notice',
};
const _okWords = {
  'ok',
  'success',
  'successful',
  'successfully',
  'succeeded',
  'active',
  'running',
  'enabled',
  'started',
  'done',
  'passed',
  'listening',
  'established',
  'healthy',
  'ready',
  'complete',
  'completed',
  'connected',
  'up',
  'online',
  'available',
};
const _debugWords = {'debug', 'trace', 'verbose'};
const _months = {
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
};
const _units = {
  'b',
  'k',
  'm',
  'g',
  't',
  'p',
  'kb',
  'mb',
  'gb',
  'tb',
  'pb',
  'kib',
  'mib',
  'gib',
  'tib',
  'pib',
  'ki',
  'mi',
  'gi',
  'ti',
  '%',
  'ms',
  'us',
  'ns',
  's',
  'sec',
  'secs',
  'min',
  'mins',
  'h',
  'hr',
  'hrs',
  'd',
  'w',
  'hz',
  'khz',
  'mhz',
  'ghz',
  'kbps',
  'mbps',
  'gbps',
  'bps',
  'rpm',
  'mb/s',
  'kb/s',
  'gb/s',
  'k/s',
  'm/s',
  'g/s',
  'b/s',
};
const _urlSchemes = [
  'http://',
  'https://',
  'ftp://',
  'ssh://',
  'sftp://',
  'ws://',
  'wss://',
  'git://',
  'file://',
];

final _ip4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}(:\d{1,5}|/\d{1,2})?$');
final _date = RegExp(
  r'^(\d{4}[-/.]\d\d[-/.]\d\d(T\d\d:\d\d(:\d\d(\.\d+)?)?(Z|[+-]\d\d:?\d\d)?)?'
  r'|\d\d/[A-Za-z]{3}/\d{4}(:\d\d:\d\d:\d\d)?|\d\d[-/.]\d\d[-/.]\d{4})$',
);
final _time = RegExp(r'^\d{1,2}:\d\d(:\d\d)?(\.\d+)?(Z|[AP]M)?$');
final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final _hex0x = RegExp(r'^0[xX][0-9a-fA-F]+$');
final _number = RegExp(r'^[+-]?\d[\d,]*(\.\d+)?([A-Za-z%]{1,4}(/s)?)?$');
final _version = RegExp(r'^v?\d+(\.\d+){2,}([-+][\w.]+)?$');
final _hexRun = RegExp(r'^[0-9a-fA-F]{7,64}$');
final _ip6 = RegExp(r'^[0-9a-fA-F:.]+(%\w+)?(/\d{1,3})?$');
final _perms = RegExp(r'^[-dlcbps][-rwxsStT]{9}[.+@]?$');
final _httpStatus = RegExp(r'^[1-5]\d\d$');
final _tz = RegExp(r'^[+-]\d{4}$');
final _httpTail = RegExp(r'http/\d(\.\d)?$');

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
bool _isAlpha(int c) => (c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a);
bool _isNameChar(int c) =>
    _isAlpha(c) || _isDigit(c) || c == 0x5f || c == 0x2e || c == 0x2d;
bool _isSign(int c) => c == 0x23 || c == 0x24 || c == 0x25 || c == 0x3e;

/// Characters stripped from the front/back of a word before classifying it.
bool _leadPunct(int c) =>
    c == 0x28 ||
    c == 0x5b ||
    c == 0x7b ||
    c == 0x3c ||
    c == 0x22 ||
    c == 0x27 ||
    c == 0x2c ||
    c == 0x3b;
bool _tailPunct(int c) =>
    c == 0x29 ||
    c == 0x5d ||
    c == 0x7d ||
    c == 0x3e ||
    c == 0x22 ||
    c == 0x27 ||
    c == 0x2c ||
    c == 0x3b ||
    c == 0x3a ||
    c == 0x2e ||
    c == 0x21 ||
    c == 0x3f;

/// Tokenizes one terminal row. [text] holds one UTF-16 unit per cell with a
/// space wherever the cell must stay untouched. Returned spans never overlap
/// and are sorted. [cursorLine] disables the "whole line is a comment" rule so
/// a minimal `# ` prompt being typed on is not greyed out.
List<HlSpan> highlightLine(String text, {bool cursorLine = false}) {
  final n = text.length < terminalHighlightMaxCells
      ? text.length
      : terminalHighlightMaxCells;
  final out = <HlSpan>[];
  var i = 0;
  while (i < n && text.codeUnitAt(i) == 0x20) {
    i++;
  }
  if (i >= n) return out;
  if (!cursorLine && _isCommentStart(text, i, n)) {
    var e = n;
    while (e > i && text.codeUnitAt(e - 1) == 0x20) {
      e--;
    }
    out.add(HlSpan(i, e, HlKind.comment));
    return out;
  }
  i = _prompt(text, i, n, out);
  _scanWords(text, i, n, out);
  return out;
}

bool _isCommentStart(String s, int i, int n) {
  final c = s.codeUnitAt(i);
  if (c == 0x23) {
    return i + 1 >= n ||
        s.codeUnitAt(i + 1) == 0x20 ||
        s.codeUnitAt(i + 1) == 0x21;
  }
  return c == 0x2f &&
      i + 2 < n &&
      s.codeUnitAt(i + 1) == 0x2f &&
      s.codeUnitAt(i + 2) == 0x20;
}

/// `user@host:path#`, `user@host#`, `[user@host path]$`. Returns the index
/// after the prompt, or [from] when the row does not start with one.
int _prompt(String s, int from, int n, List<HlSpan> out) {
  var j = from;
  var bracket = false;
  if (s.codeUnitAt(j) == 0x5b) {
    bracket = true;
    j++;
  }
  final u = j;
  while (j < n && _isNameChar(s.codeUnitAt(j))) {
    j++;
  }
  if (j == u || j >= n || s.codeUnitAt(j) != 0x40) return from;
  final h = j + 1;
  var k = h;
  while (k < n && _isNameChar(s.codeUnitAt(k))) {
    k++;
  }
  if (k == h) return from;
  final userHost = HlSpan(u, k, HlKind.userHost);
  HlSpan? path;
  j = k;
  if (bracket) {
    if (j < n && s.codeUnitAt(j) == 0x20) {
      final p = j + 1;
      var q = p;
      while (q < n && s.codeUnitAt(q) != 0x5d && s.codeUnitAt(q) != 0x20) {
        q++;
      }
      if (q > p) path = HlSpan(p, q, HlKind.promptPath);
      j = q;
    }
    if (j < n && s.codeUnitAt(j) == 0x5d) {
      j++;
    } else {
      return from;
    }
  } else if (j < n && s.codeUnitAt(j) == 0x3a) {
    final p = j + 1;
    var q = p;
    while (q < n &&
        s.codeUnitAt(q) != 0x20 &&
        !(_isSign(s.codeUnitAt(q)) &&
            (q + 1 >= n || s.codeUnitAt(q + 1) == 0x20))) {
      q++;
    }
    if (q > p) path = HlSpan(p, q, HlKind.promptPath);
    j = q;
  }
  if (j < n &&
      _isSign(s.codeUnitAt(j)) &&
      (j + 1 >= n || s.codeUnitAt(j + 1) == 0x20)) {
    out.add(userHost);
    if (path != null) out.add(path);
    out.add(
      HlSpan(
        j,
        j + 1,
        s.codeUnitAt(j) == 0x23 ? HlKind.promptRoot : HlKind.promptSign,
      ),
    );
    return j + 1;
  }
  return from;
}

bool _quoteOk(String s, int i, int from) {
  if (s.codeUnitAt(i) == 0x22) return true;
  if (i == from) return true;
  final p = s.codeUnitAt(i - 1);
  // An apostrophe after a word character ("don't") is not a quote.
  return !(_isAlpha(p) || _isDigit(p));
}

int _closingQuote(String s, int i, int n) {
  final q = s.codeUnitAt(i);
  for (var j = i + 1; j < n; j++) {
    final c = s.codeUnitAt(j);
    if (c == 0x5c && q == 0x22) {
      j++;
    } else if (c == q) {
      return j;
    }
  }
  return -1;
}

bool _isKey(String core, int end) {
  if (end <= 0) return false;
  final c0 = core.codeUnitAt(0);
  if (!(_isAlpha(c0) || c0 == 0x5f || c0 == 0x2d)) return false;
  for (var i = 1; i < end; i++) {
    if (!_isNameChar(core.codeUnitAt(i))) return false;
  }
  return true;
}

void _scanWords(String s, int from, int n, List<HlSpan> out) {
  var i = from;
  var prev = '';
  var prevStart = from;
  var pendingKey = '';
  // `ls -l` rows: after the date columns the rest of the row is the file name.
  var lsState = 0; // 0 columns, 1 month, 2 day, 3 iso date, 9 name next
  var lsWords = 0;
  var lsKind = HlKind.path; // path = plain file, nothing to colour
  var lsActive = false;
  var firstWord = true;
  var continuation = false;
  while (i < n) {
    final c = s.codeUnitAt(i);
    if (c == 0x20) {
      i++;
      continue;
    }
    if (lsActive && !continuation) {
      var e0 = i;
      while (e0 < n && s.codeUnitAt(e0) != 0x20) {
        e0++;
      }
      final w = s.substring(i, e0);
      var isName = false;
      switch (lsState) {
        case 0:
          if (_months.contains(w.toLowerCase())) {
            lsState = 1;
          } else if (_date.hasMatch(w)) {
            lsState = 3;
          }
        case 1:
          lsState = 2;
        case 2:
          lsState = 9;
        case 3:
          isName = !(_time.hasMatch(w) || _tz.hasMatch(w));
        default:
          isName = true;
      }
      if (isName) {
        var e = n;
        while (e > i && s.codeUnitAt(e - 1) == 0x20) {
          e--;
        }
        final arrow = s.indexOf(' -> ', i);
        final nameEnd = arrow >= 0 && arrow < e ? arrow : e;
        if (nameEnd > i && lsKind != HlKind.path) {
          out.add(HlSpan(i, nameEnd, lsKind));
        }
        i = nameEnd;
        lsActive = false;
        prev = '';
        continue;
      }
      if (++lsWords > 10) lsActive = false;
    }
    continuation = false;
    if (c == 0x22 || (c == 0x27 && _quoteOk(s, i, from))) {
      final j = _closingQuote(s, i, n);
      if (j > i) {
        out.add(HlSpan(i, j + 1, HlKind.string));
        final inner = s.substring(i + 1, j).toLowerCase();
        prev = _httpTail.hasMatch(inner) ? 'http/' : '';
        prevStart = i;
        pendingKey = '';
        i = j + 1;
        firstWord = false;
        continue;
      }
    }
    var e = i;
    while (e < n && s.codeUnitAt(e) != 0x20) {
      e++;
    }
    var a = i;
    var b = e;
    while (a < b && _leadPunct(s.codeUnitAt(a))) {
      a++;
    }
    while (b > a && _tailPunct(s.codeUnitAt(b - 1))) {
      b--;
    }
    if (a >= b) {
      i = e;
      firstWord = false;
      continue;
    }
    final core = s.substring(a, b);
    // key=value: colour the key, then scan the value as a fresh word.
    final eq = core.indexOf('=');
    if (eq > 0 && _isKey(core, eq) && !_startsWithScheme(core)) {
      out.add(HlSpan(a, a + eq, HlKind.key));
      pendingKey = core.substring(0, eq).toLowerCase();
      i = a + eq + 1;
      continuation = true;
      firstWord = false;
      continue;
    }
    final lower = core.toLowerCase();
    HlKind? kind;
    var spanStart = a;
    if (firstWord && _perms.hasMatch(core)) {
      final t = core.codeUnitAt(0);
      lsKind = t == 0x64
          ? HlKind.dir
          : t == 0x6c
          ? HlKind.link
          : core.contains('x') || core.contains('s')
          ? HlKind.exec
          : HlKind.path;
      lsActive = true;
      // Permission column itself stays plain; only the name is coloured.
    } else {
      kind = _classify(core, lower, prev, pendingKey);
      if (kind == HlKind.error && lower == 'found' && prev == 'not') {
        // "not found": colour the "not" before it too.
        spanStart = prevStart;
      }
      if (kind == null && _months.contains(lower) && _nextIsDay(s, e, n)) {
        kind = HlKind.dateTime;
      }
    }
    if (kind != null) {
      if (out.isNotEmpty && out.last.end > spanStart) spanStart = a;
      out.add(HlSpan(spanStart, b, kind));
    }
    prev = lower;
    prevStart = a;
    pendingKey = '';
    firstWord = false;
    i = e;
  }
}

bool _startsWithScheme(String core) {
  for (final scheme in _urlSchemes) {
    if (core.length >= scheme.length &&
        core.substring(0, scheme.length).toLowerCase() == scheme) {
      return true;
    }
  }
  return false;
}

bool _nextIsDay(String s, int from, int n) {
  var i = from;
  while (i < n && s.codeUnitAt(i) == 0x20) {
    i++;
  }
  final st = i;
  while (i < n && _isDigit(s.codeUnitAt(i))) {
    i++;
  }
  return i > st && i - st <= 2 && (i >= n || s.codeUnitAt(i) == 0x20);
}

HlKind? _classify(String core, String lower, String prev, String pendingKey) {
  final c0 = core.codeUnitAt(0);
  if (_startsWithScheme(core)) return HlKind.url;
  if (prev.startsWith('http/') && _httpStatus.hasMatch(core)) {
    return _httpKind(core);
  }
  if (lower.startsWith('http/')) return null;
  if ((c0 == 0x76 || c0 == 0x56) && _version.hasMatch(lower)) {
    return HlKind.number;
  }
  if (pendingKey.isNotEmpty &&
      (pendingKey == 'status' ||
          pendingKey == 'code' ||
          pendingKey == 'status_code') &&
      _httpStatus.hasMatch(core)) {
    return _httpKind(core);
  }
  if (_isDigit(c0) ||
      ((c0 == 0x2b || c0 == 0x2d) &&
          core.length > 1 &&
          _isDigit(core.codeUnitAt(1)))) {
    if (_ip4.hasMatch(core)) return HlKind.ip;
    if (_date.hasMatch(core) || _time.hasMatch(core)) return HlKind.dateTime;
    if (_uuid.hasMatch(core) || _hex0x.hasMatch(core)) return HlKind.hex;
    if (_ip6.hasMatch(core) && _looksIp6(core)) return HlKind.ip;
    if (_version.hasMatch(core)) return HlKind.number;
    final m = _number.firstMatch(core);
    if (m != null) {
      final unit = m.group(2);
      if (unit == null) return HlKind.number;
      if (_units.contains(unit.toLowerCase())) return HlKind.number;
    }
    if (_hexRun.hasMatch(core) && _mixedHex(core)) return HlKind.hex;
    return null;
  }
  if (c0 == 0x2f) {
    // "/", "//" and bare slashes are not paths.
    if (core.length > 1 && core.codeUnitAt(1) != 0x2f) return HlKind.path;
    return null;
  }
  if (c0 == 0x7e) {
    if (core.length == 1 || core.codeUnitAt(1) == 0x2f) return HlKind.path;
    return null;
  }
  if (c0 == 0x2e && core.length > 2) {
    final c1 = core.codeUnitAt(1);
    if (c1 == 0x2f || (c1 == 0x2e && core.codeUnitAt(2) == 0x2f)) {
      return HlKind.path;
    }
  }
  if (core.contains(':') && _ip6.hasMatch(core) && _looksIp6(core)) {
    return HlKind.ip;
  }
  final at = core.indexOf('@');
  if (at > 0 && at < core.length - 1) {
    if (_isKey(core, at) && _allName(core, at + 1)) return HlKind.userHost;
  }
  if (_errorWords.contains(lower)) return HlKind.error;
  if (lower == 'found' && prev == 'not') return HlKind.error;
  if (_warnWords.contains(lower)) return HlKind.warn;
  if (_okWords.contains(lower)) return HlKind.ok;
  if (_debugWords.contains(lower)) return HlKind.debug;
  if (_hexRun.hasMatch(core) && _mixedHex(core)) return HlKind.hex;
  if (core.contains('/') && _relativePath(core)) return HlKind.path;
  return null;
}

HlKind _httpKind(String code) => switch (code.codeUnitAt(0)) {
  0x32 => HlKind.http2xx,
  0x33 => HlKind.http3xx,
  0x34 => HlKind.http4xx,
  0x35 => HlKind.http5xx,
  _ => HlKind.number,
};

bool _allName(String s, int from) {
  for (var i = from; i < s.length; i++) {
    if (!_isNameChar(s.codeUnitAt(i))) return false;
  }
  return from < s.length;
}

bool _looksIp6(String core) {
  var colons = 0;
  for (var i = 0; i < core.length; i++) {
    if (core.codeUnitAt(i) == 0x3a) colons++;
  }
  return core.contains('::') || colons >= 5;
}

bool _mixedHex(String s) {
  var digit = false, letter = false;
  for (var i = 0; i < s.length; i++) {
    _isDigit(s.codeUnitAt(i)) ? digit = true : letter = true;
  }
  return digit && letter;
}

/// `src/main.rs`, `etc/nginx/x`: has a letter, only path characters, and a
/// dot in the last segment or at least two slashes (so `and/or` stays plain).
bool _relativePath(String core) {
  var slashes = 0;
  var letter = false;
  for (var i = 0; i < core.length; i++) {
    final c = core.codeUnitAt(i);
    if (c == 0x2f) {
      slashes++;
    } else if (_isAlpha(c)) {
      letter = true;
    } else if (!(_isDigit(c) ||
        c == 0x5f ||
        c == 0x2e ||
        c == 0x2d ||
        c == 0x40 ||
        c == 0x2b ||
        c == 0x7e ||
        c == 0x25 ||
        c == 0x3a)) {
      return false;
    }
  }
  if (!letter) return false;
  return slashes >= 2 || core.substring(core.lastIndexOf('/')).contains('.');
}
