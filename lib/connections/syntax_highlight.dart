import 'package:flutter/material.dart';

import 'terminal_scheme.dart';

/// Small, dependency-free syntax highlighter for the SFTP text editor.
///
/// Line-oriented lexers with a tiny carried state (block comment, triple
/// quote, markdown fence, …) so edits only re-lex the changed lines. Colours
/// come from the terminal scheme palette ([CodeTheme]); the highlighter only
/// styles text, it never alters it.

/// Files above this many UTF-16 units stay plain (a note is shown instead).
const syntaxHighlightMaxChars = 256 * 1024;

enum SynLang {
  plain,
  generic,
  shell,
  yaml,
  json,
  ini,
  nginx,
  dockerfile,
  python,
  javascript,
  markdown,
  markup,
  sql,
}

/// Proper names that need no translation; `null` for [SynLang.plain] and
/// [SynLang.generic], which the UI labels with localized text.
String? synLangName(SynLang lang) => switch (lang) {
  SynLang.plain || SynLang.generic => null,
  SynLang.shell => 'Shell',
  SynLang.yaml => 'YAML',
  SynLang.json => 'JSON',
  SynLang.ini => 'INI / conf',
  SynLang.nginx => 'nginx',
  SynLang.dockerfile => 'Dockerfile',
  SynLang.python => 'Python',
  SynLang.javascript => 'JavaScript / TypeScript',
  SynLang.markdown => 'Markdown',
  SynLang.markup => 'XML / HTML',
  SynLang.sql => 'SQL',
};

enum SynKind {
  keyword,
  string,
  number,
  constant,
  comment,
  builtin,
  variable,
  key,
  type,
  operator,
  tag,
  attribute,
  heading,
  meta,
}

class SynTok {
  const SynTok(this.start, this.end, this.kind);
  final int start, end;
  final SynKind kind;
}

/// Colours for [SynKind], taken from one terminal scheme's ANSI palette.
class CodeTheme {
  const CodeTheme(this.scheme);
  final TerminalScheme scheme;

  /// The scheme to use in an app of [appBrightness]: the user's terminal
  /// scheme when it matches the app's light/dark mode, otherwise the first
  /// curated scheme of the matching mode.
  factory CodeTheme.forApp(TerminalScheme chosen, Brightness appBrightness) {
    if (chosen.brightness == appBrightness) return CodeTheme(chosen);
    return CodeTheme(
      TerminalScheme.all.firstWhere((s) => s.brightness == appBrightness),
    );
  }

  Color get background => scheme.theme.background;
  Color get foreground => scheme.theme.foreground;
  Color get cursor => scheme.theme.cursor;

  Color color(SynKind kind) {
    final t = scheme.theme;
    return switch (kind) {
      SynKind.keyword => t.magenta,
      SynKind.string => t.green,
      SynKind.number => t.yellow,
      SynKind.constant => t.yellow,
      SynKind.comment => t.brightBlack,
      SynKind.builtin => t.blue,
      SynKind.variable => t.cyan,
      SynKind.key => t.blue,
      SynKind.type => t.cyan,
      SynKind.operator => t.cyan,
      SynKind.tag => t.red,
      SynKind.attribute => t.yellow,
      SynKind.heading => t.red,
      SynKind.meta => t.brightBlue,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is CodeTheme && other.scheme == scheme;
  @override
  int get hashCode => scheme.hashCode;
}

// ---------------------------------------------------------------------------
// Language detection

SynLang detectLanguage({required String name, String? path, String text = ''}) {
  final lower = name.toLowerCase();
  final dot = lower.lastIndexOf('.');
  final ext = dot >= 0 ? lower.substring(dot + 1) : '';
  final lowerPath = (path ?? name).toLowerCase();
  if (lower == 'dockerfile' ||
      lower.startsWith('dockerfile.') ||
      lower == 'containerfile' ||
      ext == 'dockerfile') {
    return SynLang.dockerfile;
  }
  const shellNames = {
    '.bashrc',
    '.bash_profile',
    '.bash_aliases',
    '.bash_logout',
    '.profile',
    '.zshrc',
    '.zprofile',
    '.zshenv',
    '.shrc',
    '.envrc',
    'bashrc',
    'profile',
  };
  if (shellNames.contains(lower)) return SynLang.shell;
  if (lower == '.env' || lower.startsWith('.env.') || ext == 'env') {
    return SynLang.ini;
  }
  switch (ext) {
    case 'sh' || 'bash' || 'zsh' || 'ksh' || 'ash' || 'dash' || 'fish':
      return SynLang.shell;
    case 'yml' || 'yaml':
      return SynLang.yaml;
    case 'json' || 'jsonc' || 'json5' || 'webmanifest' || 'geojson':
      return SynLang.json;
    case 'py' || 'pyw' || 'pyi':
      return SynLang.python;
    case 'js' || 'mjs' || 'cjs' || 'jsx' || 'ts' || 'tsx' || 'mts' || 'cts':
      return SynLang.javascript;
    case 'md' || 'markdown':
      return SynLang.markdown;
    case 'xml' || 'html' || 'htm' || 'xhtml' || 'svg' || 'plist' || 'xsl':
      return SynLang.markup;
    case 'sql':
      return SynLang.sql;
    case 'nginx':
      return SynLang.nginx;
    case 'conf' || 'cfg':
      if (lowerPath.contains('nginx') ||
          lowerPath.contains('sites-available') ||
          lowerPath.contains('sites-enabled') ||
          _looksNginx(text)) {
        return SynLang.nginx;
      }
      return SynLang.ini;
    case 'ini' ||
        'properties' ||
        'toml' ||
        'service' ||
        'timer' ||
        'socket' ||
        'mount' ||
        'target' ||
        'path' ||
        'desktop' ||
        'repo' ||
        'rules' ||
        'container':
      return SynLang.ini;
  }
  if (lower == 'nginx.conf' || lowerPath.contains('/nginx/')) {
    return SynLang.nginx;
  }
  if (const {
    'sshd_config',
    'ssh_config',
    'fstab',
    'crontab',
    'hosts',
    'resolv.conf',
    'sudoers',
  }.contains(lower)) {
    return SynLang.ini;
  }
  // Shebang, then a cheap content sniff for files without a telling name.
  final head = text.length > 2048 ? text.substring(0, 2048) : text;
  if (head.startsWith('#!')) {
    final eol = head.indexOf('\n');
    final line = (eol < 0 ? head : head.substring(0, eol)).toLowerCase();
    if (RegExp(r'(\bba|z|k|da|a)?sh\b|fish').hasMatch(line)) {
      return SynLang.shell;
    }
    if (line.contains('python')) return SynLang.python;
    if (line.contains('node') ||
        line.contains('deno') ||
        line.contains('bun')) {
      return SynLang.javascript;
    }
    return SynLang.generic;
  }
  final trimmed = head.trimLeft();
  if (ext.isEmpty) {
    if (trimmed.startsWith('<?xml') || trimmed.startsWith('<!DOCTYPE')) {
      return SynLang.markup;
    }
    if ((trimmed.startsWith('{') || trimmed.startsWith('[')) &&
        trimmed.contains('"')) {
      return SynLang.json;
    }
    if (_looksNginx(head)) return SynLang.nginx;
  }
  return SynLang.generic;
}

bool _looksNginx(String head) =>
    RegExp(
      r'^\s*(server|location|upstream)\s[^;]*\{',
      multiLine: true,
    ).hasMatch(head) ||
    head.contains('proxy_pass') ||
    head.contains('worker_processes');

// ---------------------------------------------------------------------------
// Lexers

class LexResult {
  const LexResult(this.toks, this.state);
  final List<SynTok> toks;
  final int state;
}

// Carried states (`inState` of the next line).
const _sNormal = 0;
const _sBlock = 1; // /* … */
const _sTripleSingle = 2;
const _sTripleDouble = 3;
const _sFence = 4; // markdown ```
const _sXmlComment = 5;
const _sTemplate = 6; // JS `…`
const _sContinued = 7; // previous line ended with a backslash
const _sXmlTag = 10;
const _sBlockScalar = 100; // YAML | or >: 100 + parent indent

class _Spec {
  const _Spec({
    this.lineComments = const [],
    this.commentAtWordStart = false,
    this.blockStart,
    this.blockEnd,
    this.quotes = '\'"',
    this.rawSingle = false,
    this.apostropheRule = false,
    this.triple = false,
    this.keywords = const {},
    this.builtins = const {},
    this.constants = const {},
    this.types = const {},
    this.selfNames = const {},
    this.ci = false,
    this.dollar = false,
    this.decorators = false,
    this.dashIdent = false,
    this.calls = false,
    this.camelTypes = false,
    this.jsonKeys = false,
    this.shellOps = false,
    this.stmtKeywords = const {},
    this.directives = false,
    this.dashFlags = false,
    this.defNames = const {},
    this.classNames = const {},
  });
  final List<String> lineComments;
  final bool commentAtWordStart;
  final String? blockStart, blockEnd;
  final String quotes;
  final bool rawSingle, apostropheRule, triple;
  final Set<String> keywords, builtins, constants, types, selfNames;
  final bool ci, dollar, decorators, dashIdent, calls, camelTypes, jsonKeys;
  final bool shellOps, directives, dashFlags;
  final Set<String> stmtKeywords, defNames, classNames;
}

Set<String> _words(String s) => s.split(RegExp(r'\s+')).toSet()..remove('');

final _shellSpec = _Spec(
  lineComments: const ['#'],
  commentAtWordStart: true,
  rawSingle: true,
  dollar: true,
  dashIdent: true,
  shellOps: true,
  dashFlags: true,
  keywords: _words(
    'if then else elif fi for while until do done case esac in function select '
    'return exit break continue local export readonly declare unset set source '
    'alias eval exec shift trap time',
  ),
  builtins: _words(
    'echo printf cd pwd read test sudo cat grep sed awk ls cp mv rm mkdir chmod '
    'chown touch find xargs curl wget tar ssh scp systemctl docker git apt '
    'apt-get yum dnf pip npm kill ps head tail sort uniq wc tee cut tr date '
    'sleep which type command true false',
  ),
);

final _pythonSpec = _Spec(
  lineComments: const ['#'],
  triple: true,
  decorators: true,
  calls: true,
  camelTypes: true,
  keywords: _words(
    'False None True and as assert async await break class continue def del '
    'elif else except finally for from global if import in is lambda nonlocal '
    'not or pass raise return try while with yield match case',
  ),
  constants: _words('True False None'),
  builtins: _words(
    'print len range int str float bool list dict set tuple open isinstance '
    'enumerate zip map filter sorted sum min max abs any all super type input '
    'repr id iter next reversed round format getattr setattr hasattr',
  ),
  selfNames: _words('self cls'),
  defNames: _words('def'),
  classNames: _words('class'),
);

final _jsSpec = _Spec(
  lineComments: const ['//'],
  blockStart: '/*',
  blockEnd: '*/',
  quotes: '\'"`',
  calls: true,
  camelTypes: true,
  decorators: true,
  keywords: _words(
    'async await break case catch class const continue debugger default delete '
    'do else enum export extends finally for from function if implements import '
    'in instanceof interface let new of package private protected public '
    'readonly return static super switch throw try type typeof var void while '
    'with yield as is keyof namespace declare abstract get set',
  ),
  constants: _words('true false null undefined NaN Infinity this'),
  builtins: _words(
    'console require module exports Promise Array Object JSON Math Map Set '
    'Date Error window document process Buffer parseInt parseFloat setTimeout '
    'setInterval fetch',
  ),
  types: _words('string number boolean any unknown never object symbol bigint'),
  defNames: _words('function'),
  classNames: _words('class interface enum'),
);

final _sqlSpec = _Spec(
  lineComments: const ['--'],
  blockStart: '/*',
  blockEnd: '*/',
  quotes: '\'"`',
  ci: true,
  calls: true,
  keywords: _words(
    'select from where and or not in is null like between join inner left right '
    'full outer cross on as group by order having limit offset union all '
    'distinct insert into values update set delete create alter drop table '
    'index view database schema primary key foreign references default unique '
    'constraint check exists case when then else end begin commit rollback '
    'transaction grant revoke to with recursive asc desc using explain analyze '
    'truncate add column if returning',
  ),
  types: _words(
    'int integer bigint smallint tinyint serial varchar char text boolean bool '
    'date datetime timestamp time decimal numeric float double real blob json '
    'jsonb uuid',
  ),
  constants: _words('true false null'),
);

final _nginxSpec = _Spec(
  lineComments: const ['#'],
  commentAtWordStart: true,
  dollar: true,
  directives: true,
  stmtKeywords: _words(
    'server location http events upstream map if types stream geo limit_except '
    'include',
  ),
  constants: _words('on off true false yes no'),
);

final _dockerSpec = _Spec(
  lineComments: const ['#'],
  dollar: true,
  dashFlags: true,
  stmtKeywords: _words(
    'from run cmd label maintainer expose env add copy entrypoint volume user '
    'workdir arg onbuild stopsignal healthcheck shell',
  ),
  keywords: _words('as'),
  ci: true,
);

const _jsonSpec = _Spec(
  quotes: '"',
  jsonKeys: true,
  constants: {'true', 'false', 'null'},
);

final _yamlValueSpec = _Spec(
  lineComments: const ['#'],
  commentAtWordStart: true,
  dollar: true,
  constants: _words(
    'true false null yes no on off True False Null Yes No On Off TRUE FALSE NULL ~',
  ),
);

final _iniValueSpec = _Spec(
  lineComments: const ['#', ';'],
  commentAtWordStart: true,
  dollar: true,
  constants: _words('true false yes no on off enable disable True False'),
);

final _genericSpec = _Spec(
  lineComments: const ['#', '//'],
  commentAtWordStart: true,
  blockStart: '/*',
  blockEnd: '*/',
  apostropheRule: true,
);

bool _isIdentStart(int c) =>
    (c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a) || c == 0x5f;
bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
bool _isIdentChar(int c) => _isIdentStart(c) || _isDigit(c);
bool _isSpace(int c) => c == 0x20 || c == 0x09 || c == 0x0d;

LexResult lexLine(SynLang lang, String line, int state) {
  final out = <SynTok>[];
  final end = switch (lang) {
    SynLang.plain => _sNormal,
    SynLang.generic => _scan(line, 0, line.length, _genericSpec, state, out),
    SynLang.shell => _lexShell(line, state, out),
    SynLang.python => _lexPython(line, state, out),
    SynLang.javascript => _scan(line, 0, line.length, _jsSpec, state, out),
    SynLang.sql => _scan(line, 0, line.length, _sqlSpec, state, out),
    SynLang.json => _scan(line, 0, line.length, _jsonSpec, state, out),
    SynLang.nginx => _scan(line, 0, line.length, _nginxSpec, state, out),
    SynLang.dockerfile => _lexDocker(line, state, out),
    SynLang.yaml => _lexYaml(line, state, out),
    SynLang.ini => _lexIni(line, out),
    SynLang.markdown => _lexMarkdown(line, state, out),
    SynLang.markup => _lexMarkup(line, state, out),
  };
  return LexResult(out, end);
}

int _lexShell(String s, int state, List<SynTok> out) {
  if (s.startsWith('#!')) {
    out.add(SynTok(0, s.length, SynKind.meta));
    return _sNormal;
  }
  return _scan(s, 0, s.length, _shellSpec, state, out);
}

int _lexPython(String s, int state, List<SynTok> out) {
  if (s.startsWith('#!') && state == _sNormal) {
    out.add(SynTok(0, s.length, SynKind.meta));
    return _sNormal;
  }
  return _scan(s, 0, s.length, _pythonSpec, state, out);
}

int _lexDocker(String s, int state, List<SynTok> out) {
  final next = _scan(
    s,
    0,
    s.length,
    _dockerSpec,
    state,
    out,
    stmtStart: state != _sContinued,
  );
  if (next != _sNormal) return next;
  return s.trimRight().endsWith('\\') ? _sContinued : _sNormal;
}

/// Scans [s] between [from] and [to]; returns the state to carry.
int _scan(
  String s,
  int from,
  int to,
  _Spec sp,
  int state,
  List<SynTok> out, {
  bool stmtStart = true,
}) {
  var i = from;
  // Resume a construct that began on an earlier line.
  if (state == _sBlock && sp.blockEnd != null) {
    final e = s.indexOf(sp.blockEnd!, i);
    if (e < 0) {
      if (to > i) out.add(SynTok(i, to, SynKind.comment));
      return _sBlock;
    }
    i = e + sp.blockEnd!.length;
    out.add(SynTok(from, i, SynKind.comment));
  } else if (state == _sTripleSingle || state == _sTripleDouble) {
    final q = state == _sTripleSingle ? "'''" : '"""';
    final e = _findClose(s, i, q);
    if (e < 0) {
      if (to > i) out.add(SynTok(i, to, SynKind.string));
      return state;
    }
    i = e + 3;
    out.add(SynTok(from, i, SynKind.string));
  } else if (state == _sTemplate) {
    final e = _findClose(s, i, '`');
    if (e < 0) {
      if (to > i) out.add(SynTok(i, to, SynKind.string));
      return _sTemplate;
    }
    i = e + 1;
    out.add(SynTok(from, i, SynKind.string));
  }
  var prevWord = '';
  var atStmt = stmtStart;
  while (i < to) {
    final c = s.codeUnitAt(i);
    if (_isSpace(c)) {
      i++;
      continue;
    }
    // Comments
    if (sp.blockStart != null && s.startsWith(sp.blockStart!, i)) {
      final e = s.indexOf(sp.blockEnd!, i + sp.blockStart!.length);
      if (e < 0) {
        out.add(SynTok(i, to, SynKind.comment));
        return _sBlock;
      }
      out.add(SynTok(i, e + sp.blockEnd!.length, SynKind.comment));
      i = e + sp.blockEnd!.length;
      continue;
    }
    var commented = false;
    for (final lc in sp.lineComments) {
      if (s.startsWith(lc, i) &&
          (!sp.commentAtWordStart ||
              i == from ||
              _isSpace(s.codeUnitAt(i - 1)) ||
              s.codeUnitAt(i - 1) == 0x3b)) {
        commented = true;
        break;
      }
    }
    if (commented) {
      out.add(SynTok(i, to, SynKind.comment));
      return _sNormal;
    }
    // Strings
    if (sp.quotes.contains(String.fromCharCode(c)) &&
        !(sp.apostropheRule &&
            c == 0x27 &&
            i > from &&
            _isIdentChar(s.codeUnitAt(i - 1)))) {
      if (sp.triple &&
          (c == 0x27 || c == 0x22) &&
          s.startsWith(String.fromCharCode(c) * 3, i)) {
        final q = String.fromCharCode(c) * 3;
        final e = _findClose(s, i + 3, q);
        if (e < 0) {
          out.add(SynTok(i, to, SynKind.string));
          return c == 0x27 ? _sTripleSingle : _sTripleDouble;
        }
        out.add(SynTok(i, e + 3, SynKind.string));
        i = e + 3;
        atStmt = false;
        continue;
      }
      final raw = sp.rawSingle && c == 0x27;
      var j = i + 1;
      var closed = false;
      while (j < to) {
        final d = s.codeUnitAt(j);
        if (d == 0x5c && !raw) {
          j += 2;
          continue;
        }
        if (d == c) {
          closed = true;
          break;
        }
        j++;
      }
      final stop = closed ? j + 1 : to;
      if (!closed && c == 0x60 && sp.quotes.contains('`')) {
        out.add(SynTok(i, to, SynKind.string));
        return _sTemplate;
      }
      var kind = SynKind.string;
      if (sp.jsonKeys && closed) {
        var k = stop;
        while (k < to && _isSpace(s.codeUnitAt(k))) {
          k++;
        }
        if (k < to && s.codeUnitAt(k) == 0x3a) kind = SynKind.key;
      }
      if (sp.dollar && c == 0x22) {
        _emitStringWithVars(s, i, stop, out);
      } else if (c == 0x60 && sp.ci) {
        out.add(SynTok(i, stop, SynKind.variable));
      } else {
        out.add(SynTok(i, stop, kind));
      }
      i = stop;
      atStmt = false;
      prevWord = '';
      continue;
    }
    // Shell-ish variables
    if (sp.dollar && c == 0x24) {
      final e = _varEnd(s, i, to);
      if (e > i + 1) {
        out.add(SynTok(i, e, SynKind.variable));
        i = e;
        atStmt = false;
        continue;
      }
    }
    // Decorators / meta
    if (sp.decorators &&
        c == 0x40 &&
        i + 1 < to &&
        _isIdentStart(s.codeUnitAt(i + 1))) {
      var e = i + 1;
      while (e < to &&
          (_isIdentChar(s.codeUnitAt(e)) || s.codeUnitAt(e) == 0x2e)) {
        e++;
      }
      out.add(SynTok(i, e, SynKind.meta));
      i = e;
      continue;
    }
    // Numbers
    if ((_isDigit(c) ||
            (c == 0x2e && i + 1 < to && _isDigit(s.codeUnitAt(i + 1)))) &&
        (i == from || !_isIdentChar(s.codeUnitAt(i - 1)))) {
      var e = i + 1;
      if (c == 0x30 && e < to && (s.codeUnitAt(e) | 0x20) == 0x78) {
        e++;
        while (e < to && _isHex(s.codeUnitAt(e))) {
          e++;
        }
      } else {
        while (e < to) {
          final d = s.codeUnitAt(e);
          if (_isDigit(d) || d == 0x2e || d == 0x5f) {
            e++;
          } else if ((d | 0x20) == 0x65 &&
              e + 1 < to &&
              (_isDigit(s.codeUnitAt(e + 1)) ||
                  s.codeUnitAt(e + 1) == 0x2d ||
                  s.codeUnitAt(e + 1) == 0x2b)) {
            e += 2;
          } else {
            break;
          }
        }
      }
      while (e < to && _isIdentChar(s.codeUnitAt(e))) {
        e++; // unit / type suffix: 10px, 5s, 100L
      }
      out.add(SynTok(i, e, SynKind.number));
      i = e;
      atStmt = false;
      continue;
    }
    // Shell options and operators
    if (sp.dashFlags &&
        c == 0x2d &&
        i + 1 < to &&
        (s.codeUnitAt(i + 1) == 0x2d || _isIdentStart(s.codeUnitAt(i + 1))) &&
        (i == from || _isSpace(s.codeUnitAt(i - 1)))) {
      var e = i + 1;
      while (e < to &&
          (_isIdentChar(s.codeUnitAt(e)) || s.codeUnitAt(e) == 0x2d)) {
        e++;
      }
      out.add(SynTok(i, e, SynKind.attribute));
      i = e;
      atStmt = false;
      continue;
    }
    if (sp.shellOps &&
        (c == 0x7c || c == 0x26 || c == 0x3b || c == 0x3e || c == 0x3c)) {
      var e = i + 1;
      while (e < to &&
          (s.codeUnitAt(e) == c || (c == 0x3e && s.codeUnitAt(e) == 0x26))) {
        e++;
      }
      out.add(SynTok(i, e, SynKind.operator));
      i = e;
      atStmt = c != 0x3e && c != 0x3c;
      continue;
    }
    if (sp.directives && (c == 0x3b || c == 0x7b || c == 0x7d)) {
      atStmt = true;
      i++;
      continue;
    }
    // Identifiers
    if (_isIdentStart(c) || (c == 0x24 && !sp.dollar)) {
      var e = i + 1;
      while (e < to) {
        final d = s.codeUnitAt(e);
        if (_isIdentChar(d) || d == 0x24 || (sp.dashIdent && d == 0x2d)) {
          e++;
        } else {
          break;
        }
      }
      final word = s.substring(i, e);
      final key = sp.ci ? word.toLowerCase() : word;
      SynKind? kind;
      if (sp.shellOps && e < to && s.codeUnitAt(e) == 0x3d && atStmt) {
        kind = SynKind.variable; // NAME=value
      } else if (sp.stmtKeywords.contains(key) && atStmt) {
        kind = SynKind.keyword;
      } else if (sp.directives && atStmt) {
        kind = SynKind.builtin;
      } else if (sp.defNames.contains(prevWord)) {
        kind = SynKind.builtin;
      } else if (sp.classNames.contains(prevWord)) {
        kind = SynKind.type;
      } else if (sp.keywords.contains(key)) {
        kind = SynKind.keyword;
      } else if (sp.constants.contains(key)) {
        kind = SynKind.constant;
      } else if (sp.selfNames.contains(key)) {
        kind = SynKind.variable;
      } else if (sp.types.contains(key)) {
        kind = SynKind.type;
      } else if (sp.builtins.contains(key)) {
        kind = SynKind.builtin;
      } else if (sp.calls && _nextIs(s, e, to, 0x28)) {
        kind = SynKind.builtin;
      } else if (sp.camelTypes && _isCamel(word)) {
        kind = SynKind.type;
      }
      if (kind != null) out.add(SynTok(i, e, kind));
      prevWord = key;
      i = e;
      // `export NAME=value`: the assignment after a declaring keyword.
      atStmt = sp.shellOps && _declarers.contains(word);
      continue;
    }
    i++;
  }
  return _sNormal;
}

const _declarers = {'export', 'local', 'readonly', 'declare'};

bool _isHex(int c) =>
    _isDigit(c) || ((c | 0x20) >= 0x61 && (c | 0x20) <= 0x66) || c == 0x5f;

bool _nextIs(String s, int from, int to, int code) {
  var i = from;
  while (i < to && _isSpace(s.codeUnitAt(i))) {
    i++;
  }
  return i < to && s.codeUnitAt(i) == code;
}

bool _isCamel(String w) {
  final c = w.codeUnitAt(0);
  if (c < 0x41 || c > 0x5a || w.length < 2) return false;
  for (var i = 1; i < w.length; i++) {
    final d = w.codeUnitAt(i);
    if (d >= 0x61 && d <= 0x7a) return true;
  }
  return false;
}

/// Index of the closing [q] at or after [from], honouring backslash escapes.
int _findClose(String s, int from, String q) {
  var i = from;
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    if (c == 0x5c) {
      i += 2;
      continue;
    }
    if (s.startsWith(q, i)) return i;
    i++;
  }
  return -1;
}

/// End of `$NAME`, `${…}`, `$(`, `$1`, `$?` starting at [i].
int _varEnd(String s, int i, int to) {
  if (i + 1 >= to) return i + 1;
  final c = s.codeUnitAt(i + 1);
  if (c == 0x7b) {
    final e = s.indexOf('}', i + 2);
    return e < 0 || e >= to ? to : e + 1;
  }
  if (c == 0x28) return i + 2;
  if (_isIdentStart(c)) {
    var e = i + 2;
    while (e < to && _isIdentChar(s.codeUnitAt(e))) {
      e++;
    }
    return e;
  }
  if (_isDigit(c) ||
      c == 0x3f ||
      c == 0x40 ||
      c == 0x23 ||
      c == 0x2a ||
      c == 0x24 ||
      c == 0x21) {
    return i + 2;
  }
  return i + 1;
}

/// A double-quoted string whose `$vars` are coloured separately.
void _emitStringWithVars(String s, int from, int to, List<SynTok> out) {
  var seg = from;
  var i = from + 1;
  while (i < to) {
    final c = s.codeUnitAt(i);
    if (c == 0x5c) {
      i += 2;
      continue;
    }
    if (c == 0x24) {
      final e = _varEnd(s, i, to);
      if (e > i + 1) {
        if (i > seg) out.add(SynTok(seg, i, SynKind.string));
        out.add(SynTok(i, e, SynKind.variable));
        seg = e;
        i = e;
        continue;
      }
    }
    i++;
  }
  if (to > seg) out.add(SynTok(seg, to, SynKind.string));
}

// --- YAML -----------------------------------------------------------------

int _lexYaml(String s, int state, List<SynTok> out) {
  final n = s.length;
  var indent = 0;
  while (indent < n && s.codeUnitAt(indent) == 0x20) {
    indent++;
  }
  final blank = s.trim().isEmpty;
  if (state >= _sBlockScalar) {
    final parent = state - _sBlockScalar;
    if (blank) return state;
    if (indent > parent) {
      out.add(SynTok(indent, n, SynKind.string));
      return state;
    }
  }
  if (blank) return _sNormal;
  if (s.codeUnitAt(indent) == 0x23) {
    out.add(SynTok(indent, n, SynKind.comment));
    return _sNormal;
  }
  if (indent == 0 && (s.startsWith('---') || s.startsWith('...'))) {
    out.add(SynTok(0, 3, SynKind.meta));
    if (n > 3) _scan(s, 3, n, _yamlValueSpec, _sNormal, out);
    return _sNormal;
  }
  var i = indent;
  // sequence dashes: "- ", "- - "
  while (i < n &&
      s.codeUnitAt(i) == 0x2d &&
      (i + 1 >= n || s.codeUnitAt(i + 1) == 0x20)) {
    out.add(SynTok(i, i + 1, SynKind.operator));
    i++;
    while (i < n && s.codeUnitAt(i) == 0x20) {
      i++;
    }
  }
  if (i >= n) return _sNormal;
  // key
  var keyEnd = -1;
  final c = s.codeUnitAt(i);
  if (c == 0x22 || c == 0x27) {
    final close = s.indexOf(String.fromCharCode(c), i + 1);
    if (close > 0 && _colonAfter(s, close + 1)) keyEnd = close + 1;
  } else if (c != 0x5b &&
      c != 0x7b &&
      c != 0x23 &&
      c != 0x7c &&
      c != 0x3e &&
      c != 0x26 &&
      c != 0x2a &&
      c != 0x21) {
    for (var j = i; j < n; j++) {
      final d = s.codeUnitAt(j);
      if (d == 0x23 && j > i && s.codeUnitAt(j - 1) == 0x20) break;
      if (d == 0x3a && (j + 1 >= n || s.codeUnitAt(j + 1) == 0x20)) {
        keyEnd = j;
        break;
      }
    }
  }
  if (keyEnd < 0) {
    _yamlValue(s, i, n, out);
    return _sNormal;
  }
  var kEnd = keyEnd;
  while (kEnd > i && s.codeUnitAt(kEnd - 1) == 0x20) {
    kEnd--;
  }
  out.add(SynTok(i, kEnd, SynKind.key));
  var v = s.indexOf(':', keyEnd) + 1;
  while (v < n && s.codeUnitAt(v) == 0x20) {
    v++;
  }
  if (v >= n) return _sNormal;
  if (s.codeUnitAt(v) == 0x7c || s.codeUnitAt(v) == 0x3e) {
    out.add(SynTok(v, v + 1, SynKind.operator));
    if (v + 1 < n) _scan(s, v + 1, n, _yamlValueSpec, _sNormal, out);
    return _sBlockScalar + indent;
  }
  _yamlValue(s, v, n, out);
  return _sNormal;
}

bool _colonAfter(String s, int from) {
  var i = from;
  while (i < s.length && s.codeUnitAt(i) == 0x20) {
    i++;
  }
  return i < s.length && s.codeUnitAt(i) == 0x3a;
}

/// A YAML value: quoted/flow content goes through the generic scanner; plain
/// scalars are strings unless they are numbers or constants.
void _yamlValue(String s, int from, int n, List<SynTok> out) {
  final c = s.codeUnitAt(from);
  if (c == 0x26 || c == 0x2a || c == 0x21) {
    // anchor, alias or tag, then the value proper
    var e = from + 1;
    while (e < n && s.codeUnitAt(e) != 0x20) {
      e++;
    }
    out.add(SynTok(from, e, c == 0x21 ? SynKind.meta : SynKind.variable));
    _yamlValue2(s, e, n, out);
    return;
  }
  if (c == 0x22 ||
      c == 0x27 ||
      c == 0x5b ||
      c == 0x7b ||
      c == 0x23 ||
      c == 0x7c ||
      c == 0x3e) {
    _scan(s, from, n, _yamlValueSpec, _sNormal, out);
    return;
  }
  // plain scalar up to an inline comment
  var end = n;
  for (var j = from + 1; j < n; j++) {
    if (s.codeUnitAt(j) == 0x23 && s.codeUnitAt(j - 1) == 0x20) {
      end = j;
      break;
    }
  }
  var e = end;
  while (e > from && s.codeUnitAt(e - 1) == 0x20) {
    e--;
  }
  final text = s.substring(from, e);
  if (text.contains(r'${')) {
    _scan(s, from, e, _yamlValueSpec, _sNormal, out);
  } else if (_yamlValueSpec.constants.contains(text)) {
    out.add(SynTok(from, e, SynKind.constant));
  } else if (_yamlNumber.hasMatch(text) || _hexNumber.hasMatch(text)) {
    out.add(SynTok(from, e, SynKind.number));
  } else {
    out.add(SynTok(from, e, SynKind.string));
  }
  if (end < n) out.add(SynTok(end, n, SynKind.comment));
}

final _yamlNumber = RegExp(r'^[-+]?(\d[\d_]*)(\.\d+)?([eE][-+]?\d+)?$');
final _hexNumber = RegExp(r'^0x[0-9a-fA-F]+$');

void _yamlValue2(String s, int from, int n, List<SynTok> out) {
  var i = from;
  while (i < n && s.codeUnitAt(i) == 0x20) {
    i++;
  }
  if (i < n) _yamlValue(s, i, n, out);
}

// --- INI / conf / env / systemd --------------------------------------------

int _lexIni(String s, List<SynTok> out) {
  final n = s.length;
  var i = 0;
  while (i < n && _isSpace(s.codeUnitAt(i))) {
    i++;
  }
  if (i >= n) return _sNormal;
  final c = s.codeUnitAt(i);
  if (c == 0x23 || c == 0x3b) {
    out.add(SynTok(i, n, SynKind.comment));
    return _sNormal;
  }
  if (c == 0x5b) {
    var e = s.indexOf(']', i);
    e = e < 0 ? n : e + 1;
    out.add(SynTok(i, e, SynKind.heading));
    if (e < n) _scan(s, e, n, _iniValueSpec, _sNormal, out);
    return _sNormal;
  }
  if (s.startsWith('export ', i)) {
    out.add(SynTok(i, i + 6, SynKind.keyword));
    i += 7;
    while (i < n && _isSpace(s.codeUnitAt(i))) {
      i++;
    }
  }
  final eq = s.indexOf('=', i);
  var sep = -1; // end of key
  var valueFrom = -1;
  if (eq > 0) {
    sep = eq;
    valueFrom = eq + 1;
  } else {
    var j = i;
    while (j < n && !_isSpace(s.codeUnitAt(j)) && s.codeUnitAt(j) != 0x3a) {
      j++;
    }
    sep = j;
    valueFrom = j;
    if (j < n && s.codeUnitAt(j) == 0x3a) valueFrom = j + 1;
  }
  var kEnd = sep;
  while (kEnd > i && _isSpace(s.codeUnitAt(kEnd - 1))) {
    kEnd--;
  }
  if (kEnd > i) out.add(SynTok(i, kEnd, SynKind.key));
  if (eq > 0) out.add(SynTok(eq, eq + 1, SynKind.operator));
  if (valueFrom < n) _scan(s, valueFrom, n, _iniValueSpec, _sNormal, out);
  return _sNormal;
}

// --- Markdown ----------------------------------------------------------------

final _mdHeading = RegExp(r'^#{1,6}(\s|$)');
final _mdBullet = RegExp(r'^([-*+]|\d+[.)])\s+');
final _mdRule = RegExp(r'^([-*_])(\s*\1){2,}\s*$');

int _lexMarkdown(String s, int state, List<SynTok> out) {
  final n = s.length;
  final t = s.trimLeft();
  final lead = n - t.length;
  if (t.startsWith('```') || t.startsWith('~~~')) {
    out.add(SynTok(lead, n, SynKind.meta));
    return state == _sFence ? _sNormal : _sFence;
  }
  if (state == _sFence) {
    if (n > 0) out.add(SynTok(0, n, SynKind.string));
    return _sFence;
  }
  if (t.isEmpty) return _sNormal;
  if (_mdHeading.hasMatch(t)) {
    out.add(SynTok(lead, n, SynKind.heading));
    return _sNormal;
  }
  var i = lead;
  final bullet = _mdBullet.firstMatch(t);
  if (bullet != null) {
    out.add(SynTok(i, i + bullet.group(1)!.length, SynKind.operator));
    i += bullet.end;
  } else if (t.startsWith('>')) {
    out.add(SynTok(i, i + 1, SynKind.operator));
    i++;
  } else if (_mdRule.hasMatch(t)) {
    out.add(SynTok(lead, n, SynKind.operator));
    return _sNormal;
  }
  _mdInline(s, i, n, out);
  return _sNormal;
}

void _mdInline(String s, int from, int n, List<SynTok> out) {
  var i = from;
  while (i < n) {
    final c = s.codeUnitAt(i);
    if (c == 0x60) {
      final e = s.indexOf('`', i + 1);
      if (e > 0) {
        out.add(SynTok(i, e + 1, SynKind.string));
        i = e + 1;
        continue;
      }
    } else if ((c == 0x2a || c == 0x5f) &&
        i + 1 < n &&
        s.codeUnitAt(i + 1) == c) {
      final e = s.indexOf(String.fromCharCode(c) * 2, i + 2);
      if (e > i + 2) {
        out.add(SynTok(i, e + 2, SynKind.keyword));
        i = e + 2;
        continue;
      }
    } else if (c == 0x5b) {
      final e = s.indexOf(']', i + 1);
      if (e > 0 && e + 1 < n && s.codeUnitAt(e + 1) == 0x28) {
        final close = s.indexOf(')', e + 2);
        if (close > 0) {
          out.add(SynTok(i, e + 1, SynKind.key));
          out.add(SynTok(e + 1, close + 1, SynKind.variable));
          i = close + 1;
          continue;
        }
      }
    } else if (c == 0x68 &&
        (s.startsWith('http://', i) || s.startsWith('https://', i))) {
      var e = i;
      while (e < n &&
          !_isSpace(s.codeUnitAt(e)) &&
          s.codeUnitAt(e) != 0x29 &&
          s.codeUnitAt(e) != 0x3e) {
        e++;
      }
      out.add(SynTok(i, e, SynKind.variable));
      i = e;
      continue;
    }
    i++;
  }
}

// --- XML / HTML ----------------------------------------------------------------

int _lexMarkup(String s, int state, List<SynTok> out) {
  final n = s.length;
  var i = 0;
  while (i < n) {
    if (state == _sXmlComment) {
      final e = s.indexOf('-->', i);
      if (e < 0) {
        out.add(SynTok(i, n, SynKind.comment));
        return _sXmlComment;
      }
      out.add(SynTok(i, e + 3, SynKind.comment));
      i = e + 3;
      state = _sNormal;
      continue;
    }
    if (state == _sXmlTag) {
      i = _markupAttrs(s, i, n, out);
      if (i < 0) return _sXmlTag;
      state = _sNormal;
      continue;
    }
    final lt = s.indexOf('<', i);
    final textEnd = lt < 0 ? n : lt;
    _markupEntities(s, i, textEnd, out);
    if (lt < 0) return _sNormal;
    i = lt;
    if (s.startsWith('<!--', i)) {
      state = _sXmlComment;
      final e = s.indexOf('-->', i + 4);
      if (e < 0) {
        out.add(SynTok(i, n, SynKind.comment));
        return _sXmlComment;
      }
      out.add(SynTok(i, e + 3, SynKind.comment));
      i = e + 3;
      state = _sNormal;
      continue;
    }
    if (s.startsWith('<?', i) || s.startsWith('<!', i)) {
      final e = s.indexOf('>', i);
      final stop = e < 0 ? n : e + 1;
      out.add(SynTok(i, stop, SynKind.meta));
      i = stop;
      continue;
    }
    var j = i + 1;
    if (j < n && s.codeUnitAt(j) == 0x2f) j++;
    final nameStart = j;
    while (j < n &&
        (_isIdentChar(s.codeUnitAt(j)) ||
            s.codeUnitAt(j) == 0x2d ||
            s.codeUnitAt(j) == 0x3a ||
            s.codeUnitAt(j) == 0x2e)) {
      j++;
    }
    if (j == nameStart) {
      i++;
      continue;
    }
    out.add(SynTok(i, j, SynKind.tag));
    i = _markupAttrs(s, j, n, out);
    if (i < 0) return _sXmlTag;
  }
  return _sNormal;
}

/// Attributes up to and including `>`; returns the index after it, or -1 if
/// the tag continues on the next line.
int _markupAttrs(String s, int from, int n, List<SynTok> out) {
  var i = from;
  while (i < n) {
    final c = s.codeUnitAt(i);
    if (c == 0x3e) {
      out.add(SynTok(i, i + 1, SynKind.tag));
      return i + 1;
    }
    if (c == 0x2f && i + 1 < n && s.codeUnitAt(i + 1) == 0x3e) {
      out.add(SynTok(i, i + 2, SynKind.tag));
      return i + 2;
    }
    if (c == 0x22 || c == 0x27) {
      final e = s.indexOf(String.fromCharCode(c), i + 1);
      final stop = e < 0 ? n : e + 1;
      out.add(SynTok(i, stop, SynKind.string));
      i = stop;
      continue;
    }
    if (_isSpace(c) || c == 0x3d) {
      i++;
      continue;
    }
    var e = i;
    while (e < n) {
      final d = s.codeUnitAt(e);
      if (_isSpace(d) ||
          d == 0x3d ||
          d == 0x3e ||
          (d == 0x2f && e + 1 < n && s.codeUnitAt(e + 1) == 0x3e)) {
        break;
      }
      e++;
    }
    if (e == i) {
      i++;
      continue;
    }
    out.add(SynTok(i, e, SynKind.attribute));
    i = e;
  }
  return -1;
}

void _markupEntities(String s, int from, int to, List<SynTok> out) {
  var i = from;
  while (i < to) {
    if (s.codeUnitAt(i) == 0x26) {
      final e = s.indexOf(';', i);
      if (e > i && e < to && e - i <= 10) {
        out.add(SynTok(i, e + 1, SynKind.constant));
        i = e + 1;
        continue;
      }
    }
    i++;
  }
}

// ---------------------------------------------------------------------------
// Controller

/// [TextEditingController] that colours its text. The visible text is exactly
/// [text]; only [TextSpan] styles differ.
class SyntaxHighlightController extends TextEditingController {
  SyntaxHighlightController({
    super.text,
    SynLang language = SynLang.generic,
    CodeTheme? theme,
  }) {
    _language = language;
    _theme = theme;
  }

  SynLang _language = SynLang.generic;
  CodeTheme? _theme;

  _LineCache? _cache;
  int _lexedLines = 0;

  // The span of the last build: a selection move or focus change rebuilds
  // with the same text and style, and the identical span spares the field a
  // re-layout of the whole file.
  String? _spanText;
  TextStyle? _spanStyle;
  TextSpan? _span;

  /// Number of lines lexed by the last [buildTextSpan] (for tests).
  int get lexedLines => _lexedLines;

  SynLang get language => _language;
  set language(SynLang value) {
    if (value == _language) return;
    _language = value;
    _cache = _span = null;
    notifyListeners();
  }

  /// Sets the colours without notifying, for use while a widget is building
  /// (the surrounding TextField rebuilds in the same frame anyway).
  void applyThemeQuietly(CodeTheme value) {
    if (value == _theme) return;
    _theme = value;
    _cache = _span = null;
  }

  CodeTheme? get theme => _theme;
  set theme(CodeTheme? value) {
    if (value == _theme) return;
    _theme = value;
    _cache = _span = null;
    notifyListeners();
  }

  /// Whether the current text is being coloured.
  bool get highlighting =>
      _language != SynLang.plain &&
      _theme != null &&
      text.length <= syntaxHighlightMaxChars;

  bool get tooLarge => text.length > syntaxHighlightMaxChars;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (!highlighting || (withComposing && value.isComposingRangeValid)) {
      // IME composition keeps the framework's underline behaviour.
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final known = _span;
    if (known != null && identical(text, _spanText) && style == _spanStyle) {
      _lexedLines = 0;
      return known;
    }
    final cache = _cache ??= _LineCache(_language, _theme!);
    _lexedLines = cache.update(text.split('\n'));
    _spanText = text;
    _spanStyle = style;
    return _span = TextSpan(
      style: style,
      children: [
        for (var i = 0; i < cache.lines.length; i++) ...[
          cache.lines[i].span!,
          if (i < cache.lines.length - 1) _newline,
        ],
      ],
    );
  }
}

const _newline = TextSpan(text: '\n');

class _Line {
  _Line(this.text, this.inState);
  final String text;
  final int inState;
  int outState = 0;
  TextSpan? span;
}

class _LineCache {
  _LineCache(this.language, this.theme);
  final SynLang language;
  final CodeTheme theme;
  List<_Line> lines = [];

  /// Re-lexes only what changed; returns how many lines were lexed.
  int update(List<String> next) {
    final old = lines;
    final out = <_Line>[];
    var lexed = 0;
    var state = _sNormal;
    var prefix = 0;
    while (prefix < next.length &&
        prefix < old.length &&
        old[prefix].text == next[prefix] &&
        old[prefix].inState == state) {
      state = old[prefix].outState;
      out.add(old[prefix]);
      prefix++;
    }
    // Unchanged trailing lines that do not overlap the reused prefix.
    var suffix = 0;
    while (suffix < next.length - prefix &&
        suffix < old.length - prefix &&
        old[old.length - 1 - suffix].text == next[next.length - 1 - suffix]) {
      suffix++;
    }
    for (var i = prefix; i < next.length; i++) {
      final remaining = next.length - i;
      if (remaining <= suffix) {
        final oldIndex = old.length - remaining;
        if (old[oldIndex].inState == state) {
          // Same text and same carried state: the rest is already lexed.
          out.addAll(old.sublist(oldIndex));
          lines = out;
          return lexed;
        }
      }
      final line = _Line(next[i], state);
      final result = lexLine(language, next[i], state);
      line.outState = result.state;
      line.span = _spanFor(next[i], result.toks);
      out.add(line);
      state = result.state;
      lexed++;
    }
    lines = out;
    return lexed;
  }

  TextSpan _spanFor(String text, List<SynTok> toks) {
    final children = <TextSpan>[];
    var pos = 0;
    for (final t in toks) {
      if (t.start < pos || t.end <= t.start) continue;
      if (t.start > pos) {
        children.add(TextSpan(text: text.substring(pos, t.start)));
      }
      children.add(
        TextSpan(
          text: text.substring(t.start, t.end),
          style: TextStyle(color: theme.color(t.kind)),
        ),
      );
      pos = t.end;
    }
    if (pos < text.length) children.add(TextSpan(text: text.substring(pos)));
    return TextSpan(children: children);
  }
}
