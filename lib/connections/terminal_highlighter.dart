import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:xterm/xterm.dart';

import 'terminal_highlight.dart';

/// Applies [highlightLine] colours to an xterm [Terminal] without touching
/// what is received, sent or stored as text.
///
/// xterm 4.0 paints straight from `BufferLine` cells and offers no paint hook,
/// so the colour is written into the cell's foreground word, in the same
/// `NamedColor` encoding the parser uses for `ESC[31m`. That has three useful
/// consequences: the palette resolves it, so a scheme change recolours
/// existing output at once; selection and copy read code points only; and a
/// cell the remote overwrites later simply gets its new style.
///
/// Rules:
/// * only cells whose foreground is the terminal default, with no background,
///   inverse or invisible attribute, are ever coloured. Anything the remote
///   styled is shown untouched and also splits tokens;
/// * cells coloured here carry [oursFlag] (a bit the xterm palette ignores), so
///   they can be recognised and reverted when a row changes or the feature is
///   switched off;
/// * only rows near the viewport are processed, each only when its cells
///   changed, within a per-pass time budget, and at most every
///   [minInterval]; the alternate screen (vim/top/htop) is never touched.
class TerminalHighlighter {
  TerminalHighlighter(
    this.terminal, {
    this.visibleLines,
    bool enabled = true,
    this.minInterval = const Duration(milliseconds: 40),
    this.budget = const Duration(milliseconds: 6),
    this.margin = 6,
  }) {
    terminal.addListener(schedule);
    _clock.start();
    _enabled = enabled;
    if (enabled) schedule();
  }

  /// Bit in a cell's foreground word marking a colour applied by this class.
  /// xterm resolves colours with `typeMask` and `valueMask` only.
  static const oursFlag = 1 << 28;

  final Terminal terminal;

  /// First/last absolute buffer row currently on screen; defaults to the
  /// bottom [Terminal.viewHeight] rows.
  final ({int first, int last})? Function()? visibleLines;
  final Duration minInterval, budget;
  final int margin;

  final _clock = Stopwatch();
  var _enabled = false;
  var _scheduled = false;
  var _disposed = false;
  var _muted = false;
  Timer? _timer;
  Duration _lastRun = Duration(milliseconds: -1000000);
  Expando<int> _seen = Expando<int>('terminal highlight');

  /// Rows tokenized so far (for tests and diagnostics).
  int processedRows = 0;

  bool get enabled => _enabled;
  set enabled(bool value) {
    if (value == _enabled || _disposed) return;
    _enabled = value;
    if (value) {
      schedule();
    } else {
      _timer?.cancel();
      _scheduled = false;
      clear();
    }
  }

  /// Call when the scroll position changed.
  void notifyScrolled() => schedule();

  void schedule() {
    if (!_enabled || _scheduled || _disposed || _muted) return;
    _scheduled = true;
    final wait = minInterval - (_clock.elapsed - _lastRun);
    if (wait <= Duration.zero) {
      scheduleMicrotask(_run);
    } else {
      _timer = Timer(wait, _run);
    }
  }

  void _run() {
    _scheduled = false;
    if (!_enabled || _disposed) return;
    _lastRun = _clock.elapsed;
    if (!runPass()) {
      schedule();
    }
  }

  /// One synchronous pass over the rows near the viewport. Returns false if
  /// the time budget ran out before every row was up to date.
  bool runPass() {
    if (!_enabled || terminal.isUsingAltBuffer) return true;
    final buffer = terminal.buffer;
    final height = buffer.height;
    if (height == 0) return true;
    var first = buffer.scrollBack;
    var last = height - 1;
    final visible = visibleLines?.call();
    if (visible != null) {
      first = visible.first;
      last = visible.last;
    }
    first = math.max(0, first - margin);
    last = math.min(height - 1, last + margin);
    final cursorRow = buffer.absoluteCursorY;
    final deadline = _clock.elapsed + budget;
    var mutated = false;
    var complete = true;
    for (var row = first; row <= last; row++) {
      if (processRow(buffer.lines[row], cursorLine: row == cursorRow)) {
        mutated = true;
      }
      if (_clock.elapsed > deadline && row < last) {
        complete = false;
        break;
      }
    }
    if (mutated) _repaint();
    return complete;
  }

  /// xterm repaints on its own notification, not when cells change under it.
  void _repaint() {
    _muted = true;
    try {
      terminal.notifyListeners();
    } finally {
      _muted = false;
    }
  }

  /// Colours one row. Safe to call repeatedly; unchanged rows are skipped.
  /// Returns whether any cell colour changed.
  bool processRow(BufferLine line, {bool cursorLine = false}) {
    final cells = math.min(
      line.getTrimmedLength(terminal.viewWidth),
      terminalHighlightMaxCells,
    );
    if (cells == 0) {
      return false;
    }
    final before = _hash(line, cells, cursorLine);
    if (_seen[line] == before) return false;
    var mutated = false;
    processedRows++;
    final codes = Uint16List(cells);
    final eligible = Uint8List(cells);
    for (var i = 0; i < cells; i++) {
      var fg = line.getForeground(i);
      if (fg & oursFlag != 0) {
        fg = 0;
        line.setForeground(i, 0);
        mutated = true;
      }
      final ok =
          fg == 0 &&
          line.getBackground(i) & CellColor.typeMask == CellColor.normal &&
          line.getAttributes(i) & (CellFlags.inverse | CellFlags.invisible) ==
              0;
      final cp = line.getCodePoint(i);
      eligible[i] = ok ? 1 : 0;
      codes[i] = ok && cp >= 0x20 && cp <= 0x7e ? cp : 0x20;
    }
    final spans = highlightLine(
      String.fromCharCodes(codes),
      cursorLine: cursorLine,
    );
    for (final span in spans) {
      final value =
          oursFlag | CellColor.named | terminalHighlightSlot(span.kind);
      for (var i = span.start; i < span.end && i < cells; i++) {
        if (eligible[i] == 1 && line.getCodePoint(i) != 0) {
          line.setForeground(i, value);
          mutated = true;
        }
      }
    }
    _seen[line] = _hash(line, cells, cursorLine);
    return mutated;
  }

  int _hash(BufferLine line, int cells, bool cursorLine) {
    final data = line.data;
    final end = math.min(cells * 4, data.length);
    var h = cursorLine ? 7 : 3;
    for (var i = 0; i < end; i++) {
      h = (h * 31 + data[i]) & 0x3fffffff;
    }
    return h;
  }

  /// Removes every colour applied by this class from both buffers.
  void clear() {
    var mutated = false;
    for (final buffer in [terminal.mainBuffer, terminal.altBuffer]) {
      for (var row = 0; row < buffer.height; row++) {
        final line = buffer.lines[row];
        for (var i = 0; i < line.length; i++) {
          if (line.getForeground(i) & oursFlag != 0) {
            line.setForeground(i, 0);
            mutated = true;
          }
        }
      }
    }
    _seen = Expando<int>('terminal highlight');
    if (mutated) _repaint();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    terminal.removeListener(schedule);
  }
}
