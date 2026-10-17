import 'package:flutter/material.dart';

import 'syntax_highlight.dart';

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
    var state = lexNormal;
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
