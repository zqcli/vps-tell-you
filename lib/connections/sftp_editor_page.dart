import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart'
    show CupertinoPageScaffoldBackgroundColor;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ui/ui.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import 'sftp_session.dart';
import 'sftp_support.dart';
import 'syntax_highlight.dart';
import 'terminal_scheme.dart';

/// Plain-text editor for one remote file (UTF-8, up to 512 KiB).
///
/// Saving first compares the file's size and modification time with what was
/// loaded; if the server copy changed, the user decides whether to overwrite.
/// Pops `true` if something was saved.
///
/// Layout: a fixed bar on top and an editor area that fills the rest of the
/// screen. Lines never soft-wrap, so one logical line is one visual line and
/// the line-number gutter stays aligned; long lines scroll horizontally. The
/// text field owns the only vertical scroll position (shared with the gutter),
/// which keeps the caret visible above the keyboard and scales to big files.
class SftpTextEditorPage extends StatefulWidget {
  const SftpTextEditorPage({
    super.key,
    required this.session,
    required this.path,
    required this.name,
    required this.file,
  });
  final SftpSession session;
  final String path, name;
  final SftpTextFile file;

  @override
  State<SftpTextEditorPage> createState() => _SftpTextEditorPageState();
}

class _SftpTextEditorPageState extends State<SftpTextEditorPage> {
  late final SynLang _detected = detectLanguage(
    name: widget.name,
    path: widget.path,
    text: widget.file.text,
  );
  SynLang? _chosen; // null = auto-detect
  late final SyntaxHighlightController _text = SyntaxHighlightController(
    text: widget.file.text,
    language: _detected,
  )..addListener(_edited);
  late String _saved = widget.file.text;
  late int _baseSize = widget.file.size;
  late DateTime? _baseTime = widget.file.mtime;
  bool _saving = false, _wrote = false, _leaving = false;

  // Vertical offset shared by the text field and the line-number gutter.
  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'sftp-editor');
  final _areaKey = GlobalKey();

  // Derived from the text only when it changes (selection moves are frequent).
  late _TextShape _shape = _TextShape.of(_text.text);
  String _shapeOf = '';
  _EditorMetrics? _metrics;
  ({_TextShape shape, _EditorMetrics metrics, double width})? _widest;

  bool get _dirty => _text.text != _saved;

  @override
  void initState() {
    super.initState();
    _shapeOf = _text.text;
    _focus.addListener(_edited);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppRouteTitles.register(context, widget.name);
  }

  void _edited() {
    if (!mounted) return;
    final text = _text.text;
    if (text != _shapeOf) {
      _shapeOf = text;
      _shape = _TextShape.of(text);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _text.removeListener(_edited);
    _focus.removeListener(_edited);
    _text.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _keyboardShown(BuildContext context) =>
      _focus.hasFocus && MediaQuery.viewInsetsOf(context).bottom > 0;

  EditableTextState? _editable() {
    EditableTextState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is EditableTextState) {
        found = element.state as EditableTextState;
        return;
      }
      element.visitChildren(visit);
    }

    (_areaKey.currentContext as Element?)?.visitChildren(visit);
    return found;
  }

  /// Shows the keyboard (focusing the field) or hides it (dropping focus).
  void _toggleKeyboard() {
    if (_keyboardShown(context)) {
      _focus.unfocus();
    } else if (_focus.hasFocus) {
      // Focused but the keyboard was swiped away: ask for it again.
      _editable()?.requestKeyboard();
    } else {
      _focus.requestFocus();
    }
  }

  String _langLabel(AppLocalizations l10n, SynLang lang) =>
      synLangName(lang) ??
      (lang == SynLang.plain ? l10n.r4HlPlain : l10n.r4HlGeneric);

  Future<void> _pickLanguage() async {
    final l10n = context.l10n;
    final picked = await showAppPicker<String>(
      context,
      title: l10n.r4HlLanguage,
      selected: _chosen?.name ?? 'auto',
      footnote: _text.tooLarge ? l10n.r4HlTooLarge : null,
      options: [
        AppPickerOption(
          key: const ValueKey('sftp-lang-auto'),
          value: 'auto',
          title: l10n.r4HlAuto,
          subtitle: _langLabel(l10n, _detected),
        ),
        AppPickerOption(
          key: const ValueKey('sftp-lang-plain'),
          value: SynLang.plain.name,
          title: l10n.r4HlPlain,
        ),
        for (final lang in SynLang.values)
          if (lang != SynLang.plain)
            AppPickerOption(
              key: ValueKey('sftp-lang-${lang.name}'),
              value: lang.name,
              title: _langLabel(l10n, lang),
            ),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() {
      _chosen = picked == 'auto' ? null : SynLang.values.byName(picked);
      _text.language = _chosen ?? _detected;
    });
  }

  Future<bool> _changedOnServer() async {
    try {
      final now = await widget.session.stat(widget.path);
      return now.size != _baseSize || now.mtime != _baseTime;
    } on SftpException catch (problem) {
      // Deleted in the meantime: saving simply recreates it.
      if (problem.kind == SftpErrorKind.notFound) return false;
      rethrow;
    }
  }

  Future<void> _save() async {
    if (_saving || !_dirty) return;
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      if (await _changedOnServer()) {
        if (!mounted) return;
        final overwrite = await showAppConfirm(
          context,
          title: l10n.r3SftpConflictTitle,
          message: l10n.r3SftpConflictMessage,
          action: l10n.r3SftpOverwrite,
          dangerous: true,
        );
        if (!overwrite || !mounted) return;
      }
      final content = _text.text;
      await widget.session.writeText(widget.path, content, overwrite: true);
      SftpEntry? after;
      try {
        after = await widget.session.stat(widget.path);
      } on SftpException {
        // The next save will see a changed file and ask; that is safe.
      }
      if (!mounted) return;
      setState(() {
        _saved = content;
        _baseSize = after?.size ?? utf8.encode(content).length;
        _baseTime = after?.mtime;
        _wrote = true;
      });
      showAppToast(context, l10n.r3SftpSaved);
    } on SftpException catch (problem) {
      if (mounted) showAppToast(context, sftpErrorText(l10n, problem));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _close() async {
    if (_leaving) return;
    if (_dirty) {
      final l10n = context.l10n;
      final discard = await showAppConfirm(
        context,
        title: l10n.r3SftpUnsavedTitle,
        message: l10n.r3SftpUnsavedMessage,
        action: l10n.r3SftpDiscard,
        dangerous: true,
      );
      if (!discard || !mounted) return;
    }
    _leaving = true;
    Navigator.of(context).pop(_wrote);
  }

  _EditorMetrics _metricsFor(BuildContext context, TextStyle style) {
    final scaler = MediaQuery.textScalerOf(context);
    final known = _metrics;
    if (known != null && known.scaler == scaler && known.style == style) {
      return known;
    }
    return _metrics = _EditorMetrics.measure(style, scaler);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final code = CodeTheme.forApp(
      terminalSchemeChoice.value,
      Theme.brightnessOf(context),
    );
    _text.applyThemeQuietly(code);
    final styled = _text.highlighting;
    final language = _langLabel(l10n, _chosen ?? _detected);
    final background = styled ? code.background : palette.bg;
    final foreground = styled ? code.foreground : palette.text;
    final textStyle = kMonoTextStyle.copyWith(
      fontSize: _kFontSize,
      height: _kLineHeight,
      // The Material text style would add tracking, and with it a width that
      // the cell arithmetic of the field and gutter does not know about.
      letterSpacing: 0,
      color: foreground,
    );
    final metrics = _metricsFor(context, textStyle);
    final shown = _keyboardShown(context);
    final caretLine = _caretLine();
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_close());
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value:
            (palette.isDark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark)
                .copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: background,
                ),
        child: CupertinoPageScaffoldBackgroundColor(
          color: palette.bg,
          child: Scaffold(
            backgroundColor: palette.bg,
            // Shrinks the editor area above the keyboard; the text field then
            // keeps the caret inside what is left.
            resizeToAvoidBottomInset: true,
            body: Column(
              children: [
                _EditorBar(
                  title: widget.name,
                  subtitle:
                      '${_text.tooLarge ? l10n.r4HlTooLarge : language} · '
                      '${l10n.r3SftpEditorSize(formatBytes(utf8.encode(_text.text).length))}',
                  leading: AppNavButton.text(
                    l10n.r3SftpClose,
                    key: const ValueKey('sftp-editor-close'),
                    onPressed: _close,
                  ),
                  actions: [
                    AppNavButton.icon(
                      shown
                          ? Icons.keyboard_hide_outlined
                          : Icons.keyboard_outlined,
                      key: const ValueKey('sftp-editor-keyboard'),
                      tooltip: shown
                          ? l10n.terminalHideKeyboard
                          : l10n.terminalOpenKeyboard,
                      onPressed: _toggleKeyboard,
                    ),
                    AppNavButton.icon(
                      Icons.more_horiz,
                      key: const ValueKey('sftp-editor-more'),
                      tooltip: l10n.r4HlLanguage,
                      onPressed: _pickLanguage,
                    ),
                    _saving
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : AppNavButton.text(
                            l10n.save,
                            key: const ValueKey('sftp-editor-save'),
                            bold: true,
                            onPressed: _dirty ? _save : null,
                          ),
                  ],
                ),
                Expanded(
                  child: ColoredBox(
                    color: background,
                    child: SafeArea(
                      top: false,
                      child: _editorArea(
                        context,
                        metrics: metrics,
                        textStyle: textStyle,
                        foreground: foreground,
                        background: background,
                        cursor: styled ? code.cursor : palette.primary,
                        caretLine: caretLine,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Width of the longest line. Counting cells is exact for a monospace font;
  /// where a glyph falls back to a proportional one, laying the longest line
  /// out catches the difference (skipped for absurdly long lines).
  double _widestLine(_EditorMetrics metrics) {
    final known = _widest;
    if (known != null &&
        identical(known.shape, _shape) &&
        identical(known.metrics, metrics)) {
      return known.width;
    }
    var width = _shape.cells * metrics.advance;
    if (_shape.widestEnd - _shape.widestStart <= 4000) {
      final probe = TextPainter(
        text: TextSpan(
          text: _text.text.substring(_shape.widestStart, _shape.widestEnd),
          style: metrics.style,
        ),
        strutStyle: metrics.strut,
        textScaler: metrics.scaler,
        textDirection: TextDirection.ltr,
      )..layout();
      width = math.max(width, probe.width);
      probe.dispose();
    }
    _widest = (shape: _shape, metrics: metrics, width: width);
    return width;
  }

  /// Zero-based line holding the caret (`-1` when there is no selection).
  int _caretLine() {
    final selection = _text.selection;
    if (!selection.isValid) return -1;
    final text = _text.text;
    final end = math.min(selection.extentOffset, text.length);
    var line = 0;
    for (
      var i = text.indexOf('\n');
      i >= 0 && i < end;
      i = text.indexOf('\n', i + 1)
    ) {
      line++;
    }
    return line;
  }

  Widget _editorArea(
    BuildContext context, {
    required _EditorMetrics metrics,
    required TextStyle textStyle,
    required Color foreground,
    required Color background,
    required Color cursor,
    required int caretLine,
  }) {
    final digits = math.max(2, '${_shape.lines}'.length);
    final gutterWidth =
        digits * metrics.advance + _kGutterPadLeft + _kGutterPadRight;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Gutter(
          key: const ValueKey('sftp-editor-gutter'),
          width: gutterWidth,
          scroll: _scroll,
          lines: _shape.lines,
          caretLine: caretLine,
          metrics: metrics,
          foreground: foreground,
          background: background,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              // No soft wrap: the field is as wide as its longest line.
              final width = math.max(
                box.maxWidth,
                _kTextPadLeft +
                    _widestLine(metrics) +
                    2 * metrics.advance +
                    _kTextPadRight,
              );
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  key: _areaKey,
                  width: width,
                  child: TextField(
                    key: const ValueKey('sftp-editor-field'),
                    controller: _text,
                    focusNode: _focus,
                    scrollController: _scroll,
                    scrollPhysics: const BouncingScrollPhysics(),
                    scrollPadding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    keyboardAppearance: Theme.brightnessOf(context),
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    enableSuggestions: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    style: textStyle,
                    strutStyle: metrics.strut,
                    cursorColor: cursor,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.fromLTRB(
                        _kTextPadLeft,
                        _kVerticalPad,
                        _kTextPadRight,
                        _kVerticalPad,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

const double _kFontSize = 14, _kLineHeight = 1.4;
const double _kVerticalPad = 8;
const double _kTextPadLeft = 10, _kTextPadRight = 24;
const double _kGutterPadLeft = 8, _kGutterPadRight = 8;

/// Line count and widest line (in monospace cells) of a text.
class _TextShape {
  const _TextShape(this.lines, this.cells, this.widestStart, this.widestEnd);

  final int lines, cells;

  /// Range of the line with the most cells in the source text.
  final int widestStart, widestEnd;

  factory _TextShape.of(String text) {
    var lines = 1, current = 0, widest = -1, start = 0;
    var widestStart = 0, widestEnd = 0;
    void endLine(int end) {
      if (current > widest) {
        widest = current;
        widestStart = start;
        widestEnd = end;
      }
    }

    for (var i = 0; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      if (unit == 0x0A) {
        lines++;
        endLine(i);
        current = 0;
        start = i + 1;
      } else {
        // Latin, Greek and Cyrillic are one cell in the mono font; tabs and
        // everything beyond (CJK, emoji, scripts the font lacks) are counted
        // generously so a line never reaches the field's width and wraps.
        current += unit == 0x09 || unit >= 0x0590 ? 2 : 1;
      }
    }
    endLine(text.length);
    return _TextShape(lines, widest, widestStart, widestEnd);
  }
}

/// Font metrics of the editor at the current text scale.
class _EditorMetrics {
  const _EditorMetrics._(
    this.style,
    this.scaler,
    this.strut,
    this.advance,
    this.lineHeight,
  );

  final TextStyle style;
  final TextScaler scaler;

  /// Forces every line to the same height whichever fallback font a glyph
  /// comes from, so gutter rows and text lines cannot drift apart.
  final StrutStyle strut;

  /// Width of one monospace cell and height of one line (both scaled).
  final double advance, lineHeight;

  factory _EditorMetrics.measure(TextStyle style, TextScaler scaler) {
    final strut = StrutStyle.fromTextStyle(style, forceStrutHeight: true);
    final probe = TextPainter(
      text: TextSpan(text: '0' * 20, style: style),
      strutStyle: strut,
      textScaler: scaler,
      textDirection: TextDirection.ltr,
    )..layout();
    final metrics = _EditorMetrics._(
      style,
      scaler,
      strut,
      probe.width / 20,
      probe.height,
    );
    probe.dispose();
    return metrics;
  }
}

class _EditorBar extends StatelessWidget {
  const _EditorBar({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.actions,
  });

  final String title, subtitle;
  final Widget leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // With large text the buttons leave no room beside the title: give the
    // file name its own row instead.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final name = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: p.text,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.barBg,
        border: Border(bottom: BorderSide(color: p.separator, width: .5)),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 44,
              child: NavigationToolbar(
                leading: leading,
                middle: stacked ? null : Semantics(header: true, child: name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions,
                ),
                centerMiddle: true,
                middleSpacing: 8,
              ),
            ),
            if (stacked)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Semantics(header: true, child: name),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, height: 1.4, color: p.text2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Line numbers, painted for the visible rows only and driven by the same
/// [ScrollController] as the text field.
class _Gutter extends StatelessWidget {
  const _Gutter({
    super.key,
    required this.width,
    required this.scroll,
    required this.lines,
    required this.caretLine,
    required this.metrics,
    required this.foreground,
    required this.background,
  });

  final double width;
  final ScrollController scroll;
  final int lines, caretLine;
  final _EditorMetrics metrics;
  final Color foreground, background;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Dragging the numbers scrolls the text, like touching the text.
        onVerticalDragUpdate: (details) {
          if (!scroll.hasClients) return;
          final position = scroll.position;
          scroll.jumpTo(
            (position.pixels - details.delta.dy).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            ),
          );
        },
        child: ClipRect(
          child: CustomPaint(
            size: Size(width, 0),
            painter: SftpGutterPainter(
              scroll: scroll,
              lines: lines,
              caretLine: caretLine,
              lineHeight: metrics.lineHeight,
              top: _kVerticalPad,
              bottom: _kVerticalPad,
              numberStyle: metrics.style.copyWith(fontSize: _kFontSize - 2),
              strut: metrics.strut,
              textScaler: metrics.scaler,
              color: foreground.withValues(alpha: .45),
              caretColor: foreground,
              fill: Color.alphaBlend(
                foreground.withValues(alpha: .05),
                background,
              ),
              rightPad: _kGutterPadRight,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the numbers of the visible lines. Row `i` sits at
/// `top + i * lineHeight - scroll offset`, exactly where the text field
/// draws line `i`.
class SftpGutterPainter extends CustomPainter {
  SftpGutterPainter({
    required this.scroll,
    required this.lines,
    required this.caretLine,
    required this.lineHeight,
    required this.top,
    required this.bottom,
    required this.numberStyle,
    required this.strut,
    required this.textScaler,
    required this.color,
    required this.caretColor,
    required this.fill,
    required this.rightPad,
  }) : super(repaint: scroll);

  final ScrollController scroll;
  final int lines, caretLine;
  final double lineHeight, top, bottom, rightPad;
  final TextStyle numberStyle;
  final StrutStyle strut;
  final TextScaler textScaler;
  final Color color, caretColor, fill;

  final _painted = <int, double>{};

  /// Zero-based line → top of its row (relative to the gutter), as drawn by
  /// the last paint.
  @visibleForTesting
  Map<int, double> get paintedRows => Map.unmodifiable(_painted);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = fill);
    canvas.drawRect(
      Rect.fromLTWH(size.width - .5, 0, .5, size.height),
      Paint()..color = caretColor.withValues(alpha: .12),
    );
    _painted.clear();
    final offset = scroll.hasClients ? scroll.position.pixels : 0.0;
    final viewport = size.height - top - bottom;
    if (viewport <= 0 || lineHeight <= 0) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, top, size.width, viewport));
    final first = math.max(0, (offset / lineHeight).floor());
    final last = math.min(lines - 1, ((offset + viewport) / lineHeight).ceil());
    for (var line = first; line <= last; line++) {
      final y = top + line * lineHeight - offset;
      final current = line == caretLine;
      if (current) {
        canvas.drawRect(
          Rect.fromLTWH(0, y, size.width, lineHeight),
          Paint()..color = caretColor.withValues(alpha: .08),
        );
      }
      final painter = TextPainter(
        text: TextSpan(
          text: '${line + 1}',
          style: numberStyle.copyWith(
            color: current ? caretColor : color,
            fontWeight: current ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        strutStyle: strut,
        textScaler: textScaler,
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(size.width - rightPad - painter.width, y));
      painter.dispose();
      _painted[line] = y;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SftpGutterPainter old) =>
      old.scroll != scroll ||
      old.lines != lines ||
      old.caretLine != caretLine ||
      old.lineHeight != lineHeight ||
      old.numberStyle != numberStyle ||
      old.textScaler != textScaler ||
      old.color != color ||
      old.caretColor != caretColor ||
      old.fill != fill ||
      old.rightPad != rightPad;
}
