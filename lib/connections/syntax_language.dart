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
