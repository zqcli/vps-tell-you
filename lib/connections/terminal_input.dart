import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:xterm/xterm.dart';

/// Text committed by an IME may contain several characters and bypass xterm's
/// key handler. It must still consume a one-shot Ctrl modifier, so that the
/// modifier cannot unexpectedly affect a later ASCII key. Protocol replies
/// use onOutput directly and are not changed by this input-only hook.
class MobileTerminal extends Terminal {
  MobileTerminal({
    required super.maxLines,
    required super.inputHandler,
    required this.consumeControl,
  });
  final VoidCallback consumeControl;
  @override
  void textInput(String text) {
    if (text.isNotEmpty) {
      consumeControl();
    }
    super.textInput(text);
  }
}

class MobileTerminalKeys implements TerminalInputHandler {
  const MobileTerminalKeys({
    required this.controlArmed,
    required this.consumeControl,
  });
  final bool Function() controlArmed;
  final VoidCallback consumeControl;
  @override
  String? call(TerminalKeyboardEvent event) {
    if (controlArmed()) {
      consumeControl();
      event = event.copyWith(ctrl: true);
    }
    return const _CursorKeysHandler()(event) ?? defaultInputHandler(event);
  }
}

/// xterm 4.0.0's public default keytab handler mistakenly consults keypad mode
/// for AppCuKeys. Correct only unmodified arrows using xterm's parsed DECCKM
/// state; all ANSI parsing, modified keys, and other input stay with xterm.
class _CursorKeysHandler implements TerminalInputHandler {
  const _CursorKeysHandler();
  @override
  String? call(TerminalKeyboardEvent event) {
    if (event.ctrl || event.alt || event.shift) {
      return null;
    }
    final suffix = switch (event.key) {
      TerminalKey.arrowUp => 'A',
      TerminalKey.arrowDown => 'B',
      TerminalKey.arrowRight => 'C',
      TerminalKey.arrowLeft => 'D',
      _ => null,
    };
    if (suffix == null) {
      return null;
    }
    return '${event.state.cursorKeysMode ? '\x1bO' : '\x1b['}$suffix';
  }
}

/// Recognises a short touch that neither moved nor involved a selection.
///
/// xterm 4.0.0 declares onTapUp but its recognizer never invokes it. A raw
/// pointer observer does not compete with its history/selection gestures.
class TerminalTapTracker {
  TerminalTapTracker({required this.hasSelection, required this.onTap});
  final bool Function() hasSelection;
  final VoidCallback onTap;
  int? _pointer;
  Offset? _start;
  Duration? _startedAt;
  bool _moved = false, _hadSelection = false;

  void down(PointerDownEvent event) {
    if (event.buttons != 1 || _pointer != null) {
      _pointer = null;
      return;
    }
    _pointer = event.pointer;
    _start = event.position;
    _startedAt = event.timeStamp;
    _moved = false;
    _hadSelection = hasSelection();
  }

  void move(PointerMoveEvent event) {
    if (event.pointer == _pointer &&
        _start != null &&
        (event.position - _start!).distance > 18) {
      _moved = true;
    }
  }

  void up(PointerUpEvent event) {
    final tap =
        event.pointer == _pointer &&
        !_moved &&
        !_hadSelection &&
        !hasSelection() &&
        _startedAt != null &&
        event.timeStamp - _startedAt! < const Duration(milliseconds: 300);
    _pointer = null;
    if (tap) onTap();
  }

  void cancel() => _pointer = null;
}
