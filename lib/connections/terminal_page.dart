import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../core/app_theme.dart';
import '../security/host_trust.dart';
import '../security/security_controller.dart';
import '../servers/ledger_controller.dart';
import 'power_action.dart';
import 'snippet.dart';
import 'snippet_pages.dart';
import 'ssh_service.dart';
import 'terminal_widgets.dart';
import 'terminal_font.dart';

typedef SshServiceFactory = SshService Function(SecurityController security);

class TerminalPage extends StatefulWidget {
  const TerminalPage({
    super.key,
    required this.ledger,
    required this.target,
    this.initialDraft = '',
    this.connectOnOpen = false,
    this.powerMode = false,
    this.serviceFactory,
  });
  final LedgerController ledger;
  final SshTarget target;
  final String initialDraft;
  final bool connectOnOpen, powerMode;
  final SshServiceFactory? serviceFactory;
  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage>
    with WidgetsBindingObserver {
  late final SshService _service;
  late Terminal _terminal;
  late final TextEditingController _draft;
  final _terminalFocus = FocusNode();
  var _terminalViewKey = GlobalKey<TerminalViewState>();
  final _terminalController = TerminalController();
  final _terminalScroll = ScrollController();
  bool _commandsOpen = false, _exitPromptOpen = false;
  bool _ctrlArmed = false, _scrolledBack = false, _hasOutput = false;
  int _inputEpoch = 0, _commandsEpoch = 0;
  bool _pasteBusy = false;
  ModalRoute<dynamic>? _commandsRoute;
  Size? _lastViewportSize;
  double? _lastViewportTextSize;
  int _viewportEpoch = 0;
  bool _cursorRevealQueued = false;
  int? _touchPointer;
  Offset? _touchStart;
  Duration? _touchStartedAt;
  bool _touchMoved = false, _touchHadSelection = false;
  StreamSubscription<String>? _output;
  bool _sendBusy = false,
      _powerBusy = false,
      _hasConnected = false,
      _closing = false,
      _targetInvalidated = false;
  int _targetEpoch = 0;
  Object? _notice;
  int? _powerIssuedGeneration;

  @override
  void initState() {
    super.initState();
    registerTerminalFontLicense();
    WidgetsBinding.instance.addObserver(this);
    _draft = TextEditingController(text: widget.initialDraft);
    _terminalScroll.addListener(_scrollChanged);
    _terminalController.addListener(_selectionChanged);
    _service =
        widget.serviceFactory?.call(widget.ledger.security) ??
        NativeSshService(security: widget.ledger.security);
    _createTerminal();
    _service.addListener(_changed);
    _output = _service.output.listen((text) {
      if (!_hasOutput && text.isNotEmpty && mounted) {
        setState(() => _hasOutput = true);
      }
      _terminal.write(text);
    });
    if (widget.connectOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _connect();
        }
      });
    }
  }

  BuildContext get _dialogContext => _terminalViewKey.currentContext ?? context;

  void _createTerminal() {
    _lastViewportSize = null;
    _viewportEpoch++;
    _terminalViewKey = GlobalKey<TerminalViewState>();
    _hasOutput = false;
    _terminal = _MobileTerminal(
      maxLines: 3000,
      consumeControl: _consumeControl,
      inputHandler: _MobileTerminalKeys(
        controlArmed: () => _ctrlArmed,
        consumeControl: _consumeControl,
      ),
    );
    _terminal.onOutput = (text) {
      // Includes terminal protocol replies (DSR/CPR), which must remain
      // available while local dialogs are open. User-input gates live at
      // the keyboard/key-bar entry points rather than in this mixed stream.
      if (_connected) {
        _service.write(text);
      }
    };
    _terminal.onResize = (columns, rows, pixelWidth, pixelHeight) {
      if (!_closing && !_targetInvalidated) {
        _service.resize(columns, rows);
      }
    };
  }

  void _consumeControl() {
    if (_ctrlArmed && mounted) {
      setState(() => _ctrlArmed = false);
    }
  }

  void _changed() {
    if (!mounted) {
      return;
    }
    if (_connected && !_hasConnected) {
      _hasConnected = true;
      _service.resize(_terminal.viewWidth, _terminal.viewHeight);
    }
    if (!_connected) {
      _closeKeyboard();
    }
    setState(() {});
  }

  void _selectionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _scrollChanged() {
    if (!_terminalScroll.hasClients) {
      return;
    }
    final back = _terminalScroll.position.extentAfter > 24;
    if (back != _scrolledBack && mounted) {
      setState(() => _scrolledBack = back);
    }
  }

  void _scrollToBottom() {
    if (_terminalScroll.hasClients) {
      _terminalScroll.jumpTo(_terminalScroll.position.maxScrollExtent);
      // xterm may already have corrected pixels during a view remount without
      // emitting a ScrollController change. An explicit latest/input action
      // clears the old history flag even when jumpTo uses the same pixels.
      if (_scrolledBack && mounted) {
        setState(() => _scrolledBack = false);
      }
    }
  }

  void _revealCursor() {
    final view = _terminalViewKey.currentState;
    if (view == null ||
        !_terminalScroll.hasClients ||
        _terminalScroll.positions.length != 1) {
      return;
    }
    final render = view.renderTerminal;
    if (!render.hasSize || render.size.isEmpty) {
      return;
    }
    final viewport = render.localToGlobal(Offset.zero) & render.size;
    final cursor = view.globalCursorRect;
    final delta = cursor.bottom > viewport.bottom
        ? cursor.bottom - viewport.bottom
        : cursor.top < viewport.top
        ? cursor.top - viewport.top
        : 0.0;
    if (delta.abs() < .1) {
      return;
    }
    final position = _terminalScroll.position;
    _terminalScroll.jumpTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  void _queueCursorReveal() {
    if (_cursorRevealQueued) {
      return;
    }
    _cursorRevealQueued = true;
    final generation = _service.generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cursorRevealQueued = false;
      if (!mounted ||
          !_connected ||
          generation != _service.generation ||
          !_terminalFocus.hasFocus ||
          _commandsOpen ||
          _scrolledBack ||
          _terminalController.selection != null) {
        return;
      }
      _revealCursor();
    });
  }

  void _viewportChanged(Size size, double textSize) {
    if (size == _lastViewportSize && textSize == _lastViewportTextSize) {
      return;
    }
    _lastViewportSize = size;
    _lastViewportTextSize = textSize;
    final ticket = ++_viewportEpoch;
    final terminal = _terminal;
    final generation = _service.generation;
    final view = _terminalViewKey.currentState;
    CellAnchor? anchor;
    var fraction = 0.0;
    // A passive IME/rotation resize must not pull a reader out of history.
    // Anchors survive xterm reflow, unlike an unqualified pixel offset.
    if (view != null &&
        _terminalScroll.hasClients &&
        _terminalScroll.positions.length == 1 &&
        (_terminalScroll.position.extentAfter > 24 ||
            _terminalController.selection != null)) {
      final lineHeight = view.renderTerminal.lineHeight;
      final pixels = _terminalScroll.offset;
      final row = (pixels / lineHeight).floor().clamp(
        0,
        terminal.buffer.height - 1,
      );
      anchor = terminal.buffer.createAnchor(0, row);
      fraction = pixels / lineHeight - row;
    }
    final followCursor = anchor == null && _terminalFocus.hasFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (!mounted ||
            ticket != _viewportEpoch ||
            !identical(terminal, _terminal) ||
            generation != _service.generation ||
            !_terminalScroll.hasClients ||
            _terminalScroll.positions.length != 1) {
          return;
        }
        final currentView = _terminalViewKey.currentState;
        if (currentView == null) {
          return;
        }
        if (anchor?.attached == true) {
          final position = _terminalScroll.position;
          final pixels =
              (anchor!.y + fraction) * currentView.renderTerminal.lineHeight;
          _terminalScroll.jumpTo(
            pixels.clamp(position.minScrollExtent, position.maxScrollExtent),
          );
        } else if (followCursor && _terminalFocus.hasFocus && !_commandsOpen) {
          // This callback is registered during layout, after xterm's raw
          // keyboard observer. It sees the final usable viewport for this frame.
          _revealCursor();
        }
      } finally {
        anchor?.dispose();
      }
    });
  }

  void _requestKeyboard() {
    if (!_connected ||
        _commandsOpen ||
        _closing ||
        _exitPromptOpen ||
        _sendBusy ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    _terminalController.clearSelection();
    final view = _terminalViewKey.currentState;
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      view?.requestKeyboard();
      _scrollToBottom();
      _queueCursorReveal();
      return;
    }
    // xterm 4.0.0 keeps both a logical connection and composing state after
    // onConnectionClosed. Rebuild only its input/view state when explicitly
    // reopening a hidden keyboard; retain the terminal buffer and scroll.
    view?.closeKeyboard();
    _terminalFocus.unfocus();
    final key = GlobalKey<TerminalViewState>();
    final generation = _service.generation;
    setState(() => _terminalViewKey = key);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_connected ||
          _commandsOpen ||
          _exitPromptOpen ||
          generation != _service.generation ||
          !identical(_terminalViewKey, key) ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      key.currentState?.requestKeyboard();
      _scrollToBottom();
      _queueCursorReveal();
    });
  }

  void _terminalPointerDown(PointerDownEvent event) {
    if (event.buttons != 1 || _touchPointer != null) {
      _touchPointer = null;
      return;
    }
    _touchPointer = event.pointer;
    _touchStart = event.position;
    _touchStartedAt = event.timeStamp;
    _touchMoved = false;
    _touchHadSelection = _terminalController.selection != null;
  }

  void _terminalPointerMove(PointerMoveEvent event) {
    if (event.pointer == _touchPointer &&
        _touchStart != null &&
        (event.position - _touchStart!).distance > 18) {
      _touchMoved = true;
    }
  }

  void _terminalPointerUp(PointerUpEvent event) {
    final tap =
        event.pointer == _touchPointer &&
        !_touchMoved &&
        !_touchHadSelection &&
        _terminalController.selection == null &&
        _touchStartedAt != null &&
        event.timeStamp - _touchStartedAt! < const Duration(milliseconds: 300);
    _touchPointer = null;
    // xterm 4.0.0 declares onTapUp but its recognizer never invokes it. A raw
    // pointer observer does not compete with its history/selection gestures.
    if (tap && MediaQuery.viewInsetsOf(context).bottom == 0) {
      _requestKeyboard();
    }
  }

  void _closeKeyboard() {
    _ctrlArmed = false;
    _terminalViewKey.currentState?.closeKeyboard();
    _terminalFocus.unfocus();
  }

  void _toggleKeyboard() {
    if (MediaQuery.viewInsetsOf(context).bottom > 0 &&
        _terminalFocus.hasFocus) {
      setState(_closeKeyboard);
    } else {
      _requestKeyboard();
    }
  }

  void _specialKey(TerminalKey key, {bool ctrl = false}) {
    if (!_connected ||
        _commandsOpen ||
        _exitPromptOpen ||
        _sendBusy ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    _terminalController.clearSelection();
    _terminal.keyInput(key, ctrl: ctrl);
    _scrollToBottom();
    // Touch keys must not take focus from the IME or repeatedly close it.
  }

  Future<void> _copySelection() async {
    final selection = _terminalController.selection;
    if (selection == null) {
      return;
    }
    final text = _terminal.buffer.getText(selection);
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Builder(
            builder: (context) => Text(context.l10n.terminalCopyFailed),
          ),
        ),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    if (_terminalController.selection == selection) {
      _terminalController.clearSelection();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Builder(
          builder: (context) => Text(context.l10n.terminalSelectionCopied),
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  KeyEventResult _terminalKeyEvent(FocusNode node, KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if ((keyboard.isControlPressed || keyboard.isMetaPressed) &&
        event.logicalKey == LogicalKeyboardKey.keyV) {
      if (event is KeyDownEvent) {
        unawaited(_pasteToDraft().then((_) {}));
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<Object?> _pasteToDraft() async {
    if (_pasteBusy || _closing || _targetInvalidated || _exitPromptOpen) {
      return null;
    }
    final route = _commandsOpen ? _commandsRoute : ModalRoute.of(context);
    if (route?.isCurrent != true) {
      return null;
    }
    _consumeControl();
    final epoch = _targetEpoch;
    final generation = _service.generation;
    final commandsEpoch = _commandsEpoch;
    final before = _draft.value;
    setState(() => _pasteBusy = true);
    Object problem(Object message) {
      if (mounted) {
        setState(() => _notice = message);
      }
      return message;
    }

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted ||
          _closing ||
          _targetInvalidated ||
          epoch != _targetEpoch ||
          generation != _service.generation ||
          commandsEpoch != _commandsEpoch ||
          route?.isCurrent != true) {
        return null;
      }
      if (_draft.value != before) {
        return problem(LocalizedText((l10n) => l10n.terminalDraftChangedPaste));
      }
      final pasted = data?.text;
      if (pasted == null || pasted.isEmpty) {
        return problem(LocalizedText((l10n) => l10n.terminalClipboardEmpty));
      }
      final selection = before.selection;
      final start = selection.isValid ? selection.start : before.text.length;
      final end = selection.isValid ? selection.end : before.text.length;
      final next = before.text.replaceRange(start, end, pasted);
      if (next.length > CommandSnippet.maxContentLength) {
        return problem(LocalizedText((l10n) => l10n.terminalPasteTooLong));
      }
      _draft.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: start + pasted.length),
      );
      if (!_commandsOpen) {
        unawaited(_openCommands());
      }
      return null;
    } catch (_) {
      return problem(LocalizedText((l10n) => l10n.terminalClipboardReadFailed));
    } finally {
      if (mounted) {
        setState(() => _pasteBusy = false);
      }
    }
  }

  Future<bool> _replaceDraft(String content) async {
    final before = _draft.value;
    final epoch = _targetEpoch;
    final generation = _service.generation;
    if (_draft.text.isNotEmpty && _draft.text != content) {
      final replace = await confirmAction(
        _dialogContext,
        title: LocalizedText((l10n) => l10n.terminalReplaceDraftQuestion),
        message: LocalizedText((l10n) => l10n.terminalReplaceDraftHelp),
        action: LocalizedText((l10n) => l10n.terminalReplaceDraft),
      );
      if (!replace) {
        return false;
      }
    }
    if (!mounted ||
        _closing ||
        _targetInvalidated ||
        epoch != _targetEpoch ||
        generation != _service.generation ||
        _draft.value != before) {
      return false;
    }
    _draft.value = TextEditingValue(
      text: content,
      selection: TextSelection.collapsed(offset: content.length),
    );
    return true;
  }

  Future<void> _openCommands() async {
    if (_commandsOpen || _closing || _targetInvalidated) {
      return;
    }
    _closeKeyboard();
    setState(() {
      _commandsOpen = true;
      _commandsEpoch++;
    });
    final sent = await showModalBottomSheet<bool>(
      context: _dialogContext,
      backgroundColor: terminalChromeColor,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        _commandsRoute = ModalRoute.of(sheetContext);
        return Theme(
          data: appTheme(brightness: Brightness.dark),
          child: TerminalCommandSheet(
            draft: _draft,
            service: _service,
            insertSnippet: _insertSnippet,
            replaceDraft: _replaceDraft,
            sendDraft: _sendDraft,
            pasteDraft: _pasteToDraft,
            target: widget.target.label,
          ),
        );
      },
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _commandsOpen = false;
      _commandsRoute = null;
      _commandsEpoch++;
    });
    if (sent == true) {
      final generation = _service.generation;
      final epoch = _commandsEpoch;
      // Rebuild readOnly=false before asking an already-visible IME to attach.
      await WidgetsBinding.instance.endOfFrame;
      if (mounted &&
          generation == _service.generation &&
          epoch == _commandsEpoch) {
        _requestKeyboard();
      }
    }
  }

  Future<void> _connectionDetails() async {
    _closeKeyboard();
    await showDialog<void>(
      context: _dialogContext,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(context.l10n.terminalCurrentSession),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              escapedCommandPreview(widget.target.displayNameFor(context.l10n)),
            ),
            const SizedBox(height: 8),
            SelectableText(
              escapedCommandPreview(widget.target.label),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.terminalDimensions(
                (_statusLabel).toString(),
                (_terminal.viewWidth).toString(),
                (_terminal.viewHeight).toString(),
              ),
            ),
            const SizedBox(height: 12),
            Text(context.l10n.terminalSelectionHelp),
            const SizedBox(height: 12),
            Text(context.l10n.terminalInputHelp),
            const SizedBox(height: 12),
            Text(context.l10n.terminalBackgroundHelp),
            const SizedBox(height: 12),
            Text(context.l10n.terminalOfflineFont),
            TextButton(
              onPressed: () => showLicensePage(context: context),
              child: Text(context.l10n.terminalLicenses),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.connectionClose),
          ),
        ],
      ),
    );
  }

  Future<void> _requestLeave({bool disconnectOnly = false}) async {
    if (_closing || _exitPromptOpen) {
      return;
    }
    final active = _connected || _connecting;
    if (active || (!disconnectOnly && _draft.text.isNotEmpty)) {
      setState(() => _exitPromptOpen = true);
      _closeKeyboard();
      final accepted = await confirmAction(
        _dialogContext,
        title: LocalizedText(
          (l10n) => active
              ? l10n.terminalDisconnectQuestion
              : l10n.terminalDiscardExitQuestion,
        ),
        message: LocalizedText(
          (l10n) => active
              ? l10n.terminalDisconnectHelp(
                  (escapedCommandPreview(widget.target.label)).toString(),
                  (disconnectOnly
                          ? l10n.terminalDraftKeptUntilReconnect
                          : l10n.terminalDraftWillClear)
                      .toString(),
                )
              : l10n.terminalUnsentDraftExit,
        ),
        action: LocalizedText(
          (l10n) => disconnectOnly
              ? l10n.terminalDisconnect
              : active
              ? l10n.terminalDisconnectExit
              : l10n.terminalDiscardExit,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() => _exitPromptOpen = false);
      if (!accepted) {
        return;
      }
    }
    if (disconnectOnly) {
      _service.disconnect();
    } else {
      _leave();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _service.disconnect();
      _closeKeyboard();
      if (mounted) {
        setState(
          () => _notice = LocalizedText(
            (l10n) => l10n.terminalBackgroundDisconnected,
          ),
        );
      }
    }
  }

  @override
  void didUpdateWidget(TerminalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target.label != widget.target.label ||
        oldWidget.target.credentialId != widget.target.credentialId) {
      _targetInvalidated = true;
      _inputEpoch++;
      _closeKeyboard();
      final epoch = ++_targetEpoch;
      // Updating a route may happen while another route's dialog is mounted.
      // Disconnect notifications must not rebuild that overlay during build.
      // Block local input synchronously, then invalidate the service generation
      // before the next event can interact with the changed target.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _closing || epoch != _targetEpoch) {
          return;
        }
        _service.disconnect();
        _draft.clear();
        _terminalController.clearSelection();
        _terminal.onOutput = null;
        _terminal.onResize = null;
        _createTerminal();
        setState(() {
          _targetInvalidated = false;
          _notice = LocalizedText((l10n) => l10n.terminalTargetChanged);
        });
      });
    }
  }

  void _leave() {
    if (_closing) {
      return;
    }
    _closing = true;
    _service.disconnect();
    _draft.clear();
    _terminalFocus.unfocus();
    setState(() {});
    Navigator.pop(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.removeListener(_changed);
    _terminal.onOutput = null;
    _terminal.onResize = null;
    _output?.cancel();
    _service.disconnect();
    _service.dispose();
    _draft.dispose();
    _terminalFocus.dispose();
    _terminalController.removeListener(_selectionChanged);
    _terminalController.dispose();
    _terminalScroll.removeListener(_scrollChanged);
    _terminalScroll.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_closing || _targetInvalidated || kIsWeb || _connecting || _connected) {
      return;
    }
    if (_service.status != SshStatus.idle) {
      _inputEpoch++;
      _closeKeyboard();
      _terminalController.clearSelection();
      _draft.clear();
      _terminal.onOutput = null;
      _terminal.onResize = null;
      _createTerminal();
    }
    setState(() {
      _hasConnected = false;
      _notice = widget.powerMode
          ? LocalizedText((l10n) => l10n.terminalPowerMenuHelp)
          : null;
    });
    await _service.connect(
      widget.target,
      verifyHost: _verifyHost,
      requestKeyPassphrase: _requestKeyPassphrase,
    );
  }

  bool get _connected => !_closing && !_targetInvalidated && _service.connected;

  bool get _connecting => switch (_service.status) {
    SshStatus.connecting ||
    SshStatus.verifying ||
    SshStatus.authenticating => true,
    _ => false,
  };

  Future<String?> _requestKeyPassphrase(String credentialName) async {
    if (!mounted || _closing || _targetInvalidated) {
      return null;
    }
    final generation = _service.generation;
    final value = await showDialog<String>(
      context: _dialogContext,
      barrierDismissible: false,
      builder: (_) => _KeyPassphraseDialog(
        service: _service,
        generation: generation,
        credentialName: credentialName,
        target: widget.target.label,
      ),
    );
    if (!mounted ||
        _closing ||
        _targetInvalidated ||
        _service.generation != generation ||
        _service.status != SshStatus.connecting) {
      return null;
    }
    return value;
  }

  Future<bool> _verifyHost(HostVerificationRequest request) async {
    if (!mounted) {
      return false;
    }
    final generation = _service.generation;
    bool current() =>
        mounted &&
        !_closing &&
        !_targetInvalidated &&
        _service.generation == generation &&
        _service.status == SshStatus.verifying;
    if (request.status == HostTrustStatus.changed) {
      final start = await showDialog<bool>(
        context: _dialogContext,
        builder: (_) => AlertDialog(
          scrollable: true,
          title: Text(context.l10n.terminalHostChanged),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(
                  '${request.identity.host}:${request.identity.port}',
                ),
                InfoNote(context.l10n.terminalHostChangedHelp),
                Text(context.l10n.terminalPreviousFingerprint),
                SelectableText(
                  request.previous?.fingerprint ??
                      context.l10n.terminalNoRecord,
                ),
                const SizedBox(height: 12),
                Text(context.l10n.terminalCurrentFingerprint),
                SelectableText(request.identity.fingerprint),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.terminalRejectConnection),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.terminalReverify),
            ),
          ],
        ),
      );
      if (start != true || !current()) {
        return false;
      }
    }
    if (!mounted || !current()) {
      return false;
    }
    final accepted = await showDialog<bool>(
      context: _dialogContext,
      barrierDismissible: false,
      builder: (_) => _VerifyHostDialog(
        service: _service,
        generation: generation,
        request: request,
      ),
    );
    return accepted == true && current();
  }

  Future<void> _insertSnippet() async {
    final generation = _service.generation;
    final selected = await Navigator.push<CommandSnippet>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SnippetListPage(store: widget.ledger.store, selectForDraft: true),
      ),
    );
    if (!mounted ||
        _closing ||
        selected == null ||
        generation != _service.generation) {
      return;
    }
    // This controller has no connection to xterm's onOutput or SSH stdin.
    await _replaceDraft(selected.content);
  }

  Future<bool> _sendDraft(
    String exact,
    int generation,
    bool appendEnter,
  ) async {
    if (_sendBusy ||
        !_connected ||
        !_service.acceptsInput ||
        exact.isEmpty ||
        exact != _draft.text ||
        generation != _service.generation) {
      return false;
    }
    setState(() => _sendBusy = true);
    try {
      // The two visible actions define the exact payload. Existing CR/LF or
      // controls in the draft are never removed or disguised as non-executing.
      final payload = appendEnter ? '$exact\r' : exact;
      _service.write(payload);
      if (!_connected || generation != _service.generation) {
        return false;
      }
      _draft.clear();
      FocusManager.instance.primaryFocus?.unfocus();
      _scrollToBottom();
      return true;
    } catch (_) {
      // Do not log the text or retry a potentially accepted write.
      return false;
    } finally {
      if (mounted) {
        setState(() => _sendBusy = false);
      }
    }
  }

  Future<void> _power(SshPowerAction action) async {
    if (_powerBusy ||
        !_connected ||
        _powerIssuedGeneration == _service.generation) {
      return;
    }
    setState(() => _powerBusy = true);
    try {
      final generation = _service.generation;
      final result = await confirmSshPower(
        _dialogContext,
        service: _service,
        action: action,
      );
      if (!mounted || result == null) {
        return;
      }
      _powerIssuedGeneration = generation;
      setState(
        () => _notice = result == PowerResult.failed
            ? LocalizedText((l10n) => l10n.terminalPowerFailed)
            : LocalizedText((l10n) => l10n.terminalPowerUnknown),
      );
    } finally {
      if (mounted) {
        setState(() => _powerBusy = false);
      }
    }
  }

  String get _statusLabel => switch (_service.status) {
    SshStatus.idle => context.l10n.terminalNotConnected,
    SshStatus.connecting => context.l10n.terminalConnecting,
    SshStatus.verifying => context.l10n.terminalVerifying,
    SshStatus.authenticating => context.l10n.terminalAuthenticating,
    SshStatus.connected => context.l10n.terminalConnected,
    SshStatus.disconnected => context.l10n.terminalDisconnected,
    SshStatus.failed => context.l10n.terminalFailed,
  };

  /// Status chip under the title: green when connected, amber while
  /// connecting, red when failed, grey otherwise.
  Widget _statusPill(BuildContext context) {
    final (Color fg, Color bg) = switch (_service.status) {
      SshStatus.connected => (
        mobileTerminalTheme.green,
        mobileTerminalTheme.green.withValues(alpha: .15),
      ),
      SshStatus.connecting ||
      SshStatus.verifying ||
      SshStatus.authenticating => (
        mobileTerminalTheme.yellow,
        mobileTerminalTheme.yellow.withValues(alpha: .15),
      ),
      SshStatus.failed => (
        mobileTerminalTheme.red,
        mobileTerminalTheme.red.withValues(alpha: .15),
      ),
      _ => (terminalMutedColor, const Color(0x14FFFFFF)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _statusLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                fontSize: 11,
                height: 1.15,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final scale = MediaQuery.textScalerOf(context);
    final media = MediaQuery.of(context);
    final usableHeight =
        media.size.height - media.viewInsets.bottom - media.padding.top;
    final compactChrome = keyboardVisible && usableHeight < 260;
    final headerHeight = compactChrome
        ? 48.0
        : (scale.scale(17) + scale.scale(11) + 20).clamp(56.0, 120.0);
    final hideKeyBar =
        keyboardVisible &&
        usableHeight <
            headerHeight + 49 + (scale.scale(14) * 1.3).ceilToDouble() + 8;
    return Theme(
      data: appTheme(brightness: Brightness.dark),
      child: Builder(
        builder: (context) => PopScope(
          canPop: _closing,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              if (keyboardVisible && _terminalFocus.hasFocus) {
                setState(_closeKeyboard);
              } else {
                unawaited(_requestLeave());
              }
            }
          },
          child: Scaffold(
            key: const ValueKey('terminal-fullscreen'),
            backgroundColor: mobileTerminalTheme.background,
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              toolbarHeight: headerHeight,
              backgroundColor: terminalChromeColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              shape: const Border(
                bottom: BorderSide(color: terminalHairlineColor),
              ),
              actionsIconTheme: const IconThemeData(color: terminalLinkColor),
              centerTitle: false,
              titleSpacing: 0,
              leading: IconButton(
                tooltip: context.l10n.terminalExit,
                onPressed: _requestLeave,
                color: terminalLinkColor,
                icon: const Icon(Icons.close),
              ),
              title: Semantics(
                button: true,
                label: context.l10n.terminalSessionSemantics(
                  (escapedCommandPreview(widget.target.label)).toString(),
                  (_statusLabel).toString(),
                ),
                excludeSemantics: true,
                child: InkWell(
                  onTap: _connectionDetails,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        escapedCommandPreview(
                          widget.target.displayNameFor(context.l10n),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium!
                            .copyWith(
                              fontSize: compactChrome ? 14 : 17,
                              height: 1.15,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (!compactChrome)
                        Row(
                          key: const ValueKey('terminal-status'),
                          children: [
                            Flexible(flex: 2, child: _statusPill(context)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                escapedCommandPreview(widget.target.label),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  fontFamily: terminalFontFamily,
                                  fontSize: 11,
                                  height: 1.15,
                                  color: terminalMutedColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (hideKeyBar)
                  IconButton(
                    key: const ValueKey('terminal-commands'),
                    tooltip: context.l10n.terminalCommandsSnippets,
                    onPressed: _openCommands,
                    icon: const Icon(Icons.code),
                  ),
                IconButton(
                  key: const ValueKey('terminal-keyboard'),
                  tooltip: keyboardVisible && _terminalFocus.hasFocus
                      ? context.l10n.terminalHideKeyboard
                      : context.l10n.terminalOpenKeyboard,
                  onPressed: _connected ? _toggleKeyboard : null,
                  icon: Icon(
                    keyboardVisible && _terminalFocus.hasFocus
                        ? Icons.keyboard_hide_outlined
                        : Icons.keyboard_outlined,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: context.l10n.terminalMenu,
                  color: terminalKeyColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onOpened: () => setState(_closeKeyboard),
                  onSelected: (action) {
                    switch (action) {
                      case 'details':
                        unawaited(_connectionDetails());
                      case 'connect':
                        unawaited(_connect());
                      case 'paste':
                        unawaited(_pasteToDraft().then((_) {}));
                      case 'disconnect':
                        unawaited(_requestLeave(disconnectOnly: true));
                      case 'reboot':
                        unawaited(_power(SshPowerAction.reboot));
                      case 'shutdown':
                        unawaited(_power(SshPowerAction.shutdown));
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'details',
                      child: Builder(
                        builder: (context) =>
                            Text(context.l10n.terminalSessionDetails),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'paste',
                      child: Builder(
                        builder: (context) =>
                            Text(context.l10n.terminalPasteIntoDraft),
                      ),
                    ),
                    if (!_connected && !_connecting)
                      PopupMenuItem(
                        value: 'connect',
                        enabled: !kIsWeb,
                        child: Builder(
                          builder: (context) => Text(
                            _service.status == SshStatus.idle
                                ? context.l10n.serverConnectSsh
                                : context.l10n.terminalReconnectClear,
                          ),
                        ),
                      ),
                    if (_connected || _connecting)
                      PopupMenuItem(
                        value: 'disconnect',
                        child: Builder(
                          builder: (context) => Text(
                            _connecting
                                ? context.l10n.terminalCancelConnection
                                : context.l10n.terminalDisconnect,
                          ),
                        ),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'reboot',
                      enabled:
                          _connected &&
                          !_powerBusy &&
                          _powerIssuedGeneration != _service.generation,
                      child: Builder(
                        builder: (context) =>
                            Text(context.l10n.terminalSshRestart),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'shutdown',
                      enabled:
                          _connected &&
                          !_powerBusy &&
                          _powerIssuedGeneration != _service.generation,
                      child: Builder(
                        builder: (context) =>
                            Text(context.l10n.terminalSshShutdown),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, viewport) {
                        _viewportChanged(viewport.biggest, scale.scale(14));
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: Listener(
                                onPointerDown: _terminalPointerDown,
                                onPointerMove: _terminalPointerMove,
                                onPointerUp: _terminalPointerUp,
                                onPointerCancel: (_) => _touchPointer = null,
                                child: KeyedSubtree(
                                  key: ValueKey('terminal-input-$_inputEpoch'),
                                  child: TerminalView(
                                    _terminal,
                                    key: _terminalViewKey,
                                    controller: _terminalController,
                                    scrollController: _terminalScroll,
                                    focusNode: _terminalFocus,
                                    autofocus: false,
                                    readOnly:
                                        !_connected ||
                                        _commandsOpen ||
                                        _exitPromptOpen ||
                                        _sendBusy,
                                    deleteDetection: true,
                                    keyboardType: TextInputType.multiline,
                                    keyboardAppearance: Brightness.dark,
                                    onKeyEvent: _terminalKeyEvent,
                                    shortcuts: const {
                                      SingleActivator(
                                        LogicalKeyboardKey.keyC,
                                        control: true,
                                        shift: true,
                                      ): CopySelectionTextIntent.copy,
                                      SingleActivator(
                                        LogicalKeyboardKey.keyC,
                                        meta: true,
                                      ): CopySelectionTextIntent.copy,
                                    },
                                    theme: mobileTerminalTheme,
                                    textStyle: const CodingTerminalStyle(),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: compactChrome ? 4 : 8,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_connected && !_hasOutput)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        context.l10n.terminalTypeDirectly,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (!_connected || _notice != null)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: viewport.maxHeight * .45,
                                  ),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!_connected)
                                          _connectionBanner(context),
                                        if (_notice != null)
                                          _noticeBanner(context),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (_terminalController.selection != null)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Material(
                                  color: terminalChromeColor,
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton.icon(
                                        key: const ValueKey(
                                          'terminal-copy-selection',
                                        ),
                                        onPressed: _copySelection,
                                        icon: const Icon(
                                          Icons.copy_outlined,
                                          size: 18,
                                        ),
                                        label: Text(context.l10n.terminalCopy),
                                      ),
                                      IconButton(
                                        tooltip:
                                            context.l10n.terminalClearSelection,
                                        onPressed:
                                            _terminalController.clearSelection,
                                        icon: const Icon(Icons.close, size: 18),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (_scrolledBack)
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: FloatingActionButton.small(
                                  heroTag: null,
                                  backgroundColor: terminalKeyColor,
                                  foregroundColor:
                                      mobileTerminalTheme.foreground,
                                  elevation: 1,
                                  key: const ValueKey('terminal-scroll-bottom'),
                                  tooltip: context.l10n.terminalLatestOutput,
                                  onPressed: _scrollToBottom,
                                  child: const Icon(
                                    Icons.vertical_align_bottom,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (!hideKeyBar)
                    TerminalKeyBar(
                      connected: _connected && !_commandsOpen,
                      controlArmed: _ctrlArmed,
                      onControl: () {
                        setState(() => _ctrlArmed = !_ctrlArmed);
                        _requestKeyboard();
                      },
                      onKey: _specialKey,
                      onCommands: _openCommands,
                      hasDraft: _draft.text.isNotEmpty,
                      onPaste: _pasteBusy
                          ? null
                          : () => unawaited(_pasteToDraft().then((_) {})),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _connectionBanner(BuildContext context) => Container(
    key: const ValueKey('terminal-connection-banner'),
    width: double.infinity,
    color: terminalChromeColor,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .25,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  _connecting
                      ? context.l10n.terminalEstablishingSecure
                      : context.l10n.terminalOffline,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (_connecting)
                  TextButton(
                    key: const ValueKey('terminal-disconnect'),
                    onPressed: _service.disconnect,
                    child: Text(context.l10n.terminalCancelConnection),
                  )
                else
                  TextButton(
                    key: const ValueKey('terminal-connect'),
                    onPressed: kIsWeb ? null : _connect,
                    child: Text(
                      _service.status == SshStatus.idle
                          ? context.l10n.terminalConnect
                          : context.l10n.terminalReconnectShort,
                    ),
                  ),
              ],
            ),
            if (_service.error != null)
              Text(
                _service.errorFor(context.l10n)!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (kIsWeb)
              Text(context.l10n.terminalBrowserUnsupported)
            else if (!_connecting)
              Text(
                _service.status == SshStatus.idle
                    ? context.l10n.terminalConnectedInputHelp
                    : context.l10n.terminalRetainedOutputHelp,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    ),
  );

  Widget _noticeBanner(BuildContext context) => Container(
    color: terminalChromeColor,
    padding: const EdgeInsets.only(left: 16, right: 4),
    child: Row(
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 80),
            child: SingleChildScrollView(
              child: Text(
                localizedText(_notice!, context.l10n),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: context.l10n.terminalDismissNotice,
          onPressed: () => setState(() => _notice = null),
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    ),
  );
}

/// Text committed by an IME may contain several characters and bypass xterm's
/// key handler. It must still consume a one-shot Ctrl modifier, so that the
/// modifier cannot unexpectedly affect a later ASCII key. Protocol replies
/// use onOutput directly and are not changed by this input-only hook.
class _MobileTerminal extends Terminal {
  _MobileTerminal({
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

class _MobileTerminalKeys implements TerminalInputHandler {
  const _MobileTerminalKeys({
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

class _VerifyHostDialog extends StatefulWidget {
  const _VerifyHostDialog({
    required this.service,
    required this.generation,
    required this.request,
  });
  final SshService service;
  final int generation;
  final HostVerificationRequest request;
  @override
  State<_VerifyHostDialog> createState() => _VerifyHostDialogState();
}

class _VerifyHostDialogState extends State<_VerifyHostDialog> {
  bool _checked = false, _submitted = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) {
      final identity = widget.request.identity;
      final changed = widget.request.status == HostTrustStatus.changed;
      final current =
          widget.service.generation == widget.generation &&
          widget.service.status == SshStatus.verifying;
      return AlertDialog(
        scrollable: true,
        title: Text(
          changed
              ? context.l10n.terminalVerifyNewHost
              : context.l10n.terminalFirstHostVerification,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                context.l10n.terminalHostIdentity(
                  (identity.host).toString(),
                  (identity.port).toString(),
                  (identity.algorithm).toString(),
                ),
              ),
              const SizedBox(height: 12),
              Text(context.l10n.terminalSha256Fingerprint),
              SelectableText(identity.fingerprint),
              const SizedBox(height: 12),
              Text(context.l10n.terminalFullHostKey),
              SelectableText('${identity.algorithm} ${identity.publicKey}'),
              InfoNote(context.l10n.terminalIndependentVerificationHelp),
              CheckboxListTile(
                key: const ValueKey('host-verified-check'),
                contentPadding: EdgeInsets.zero,
                value: _checked,
                onChanged: current
                    ? (value) => setState(() => _checked = value == true)
                    : null,
                title: Text(
                  changed
                      ? context.l10n.terminalConfirmedChangedHost
                      : context.l10n.terminalConfirmedHost,
                ),
              ),
              if (!current) InfoNote(context.l10n.terminalVerificationExpired),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.terminalRejectConnection),
          ),
          FilledButton(
            key: const ValueKey('host-verified-confirm'),
            onPressed: current && _checked && !_submitted
                ? () {
                    setState(() => _submitted = true);
                    Navigator.pop(context, true);
                  }
                : null,
            child: Text(
              changed
                  ? context.l10n.terminalUpdateTrustAuthenticate
                  : context.l10n.terminalTrustAuthenticate,
            ),
          ),
        ],
      );
    },
  );
}

/// The passphrase exists only in this obscured prompt and the current connect
/// call. It is never copied to metadata, draft, terminal output or a store.
class _KeyPassphraseDialog extends StatefulWidget {
  const _KeyPassphraseDialog({
    required this.service,
    required this.generation,
    required this.credentialName,
    required this.target,
  });
  final SshService service;
  final int generation;
  final String credentialName, target;
  @override
  State<_KeyPassphraseDialog> createState() => _KeyPassphraseDialogState();
}

class _KeyPassphraseDialogState extends State<_KeyPassphraseDialog>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  bool _submitted = false, _invalidated = false;

  bool get _current =>
      !_invalidated &&
      !_submitted &&
      widget.service.generation == widget.generation &&
      widget.service.status == SshStatus.connecting;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_serviceChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  void _serviceChanged() {
    if (!mounted || _submitted) {
      return;
    }
    if (widget.service.generation != widget.generation ||
        widget.service.status != SshStatus.connecting) {
      _input.clear();
      setState(() => _invalidated = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _input.clear();
      if (mounted) {
        setState(() => _invalidated = true);
      }
    }
  }

  void _cancel() {
    _input.clear();
    Navigator.pop(context);
  }

  void _submit() {
    if (!_current || _input.text.isEmpty) {
      return;
    }
    final value = _input.text;
    _submitted = true;
    _input.clear();
    Navigator.pop(context, value);
  }

  @override
  void dispose() {
    widget.service.removeListener(_serviceChanged);
    WidgetsBinding.instance.removeObserver(this);
    _input.clear();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(context.l10n.terminalUnlockKey),
    content: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            escapedCommandPreview(widget.target),
            textDirection: TextDirection.ltr,
          ),
          Text(
            context.l10n.terminalCredentialName(
              (escapedCommandPreview(widget.credentialName)).toString(),
            ),
          ),
          InfoNote(context.l10n.terminalPassphraseHelp),
          TextField(
            key: const ValueKey('ssh-key-passphrase'),
            controller: _input,
            enabled: _current,
            obscureText: true,
            enableIMEPersonalizedLearning: false,
            autocorrect: false,
            enableSuggestions: false,
            enableInteractiveSelection: false,
            autofillHints: const [],
            maxLength: 4096,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: context.l10n.terminalKeyPassphrase,
            ),
          ),
          if (_invalidated) InfoNote(context.l10n.terminalPassphraseCleared),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _cancel,
        child: Text(context.l10n.terminalCancelConnection),
      ),
      FilledButton(
        key: const ValueKey('ssh-key-passphrase-submit'),
        onPressed: _current && _input.text.isNotEmpty ? _submit : null,
        child: Text(context.l10n.terminalUnlockOnce),
      ),
    ],
  );
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
