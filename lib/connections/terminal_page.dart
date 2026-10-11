import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../core/app_theme.dart';
import '../core/ui/ui.dart';
import '../security/security_controller.dart';
import '../servers/ledger_controller.dart';
import 'power_action.dart';
import 'snippet.dart';
import 'sftp_pages.dart';
import 'sftp_session.dart';
import 'sftp_support.dart';
import 'snippet_pages.dart';
import 'ssh_prompts.dart';
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
  bool _pasteBusy = false, _sftpOpening = false;
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
  bool _endQueued = false;
  // Why the local side ends the session (background, target change); shown as
  // a toast on the previous page. Remote/network ends use the service error.
  LocalizedMessage? _endReason;
  Object? _notice;
  int? _powerIssuedGeneration;

  @override
  void initState() {
    super.initState();
    registerTerminalFontLicense();
    terminalSchemeChoice.addListener(_schemeChanged);
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

  TerminalScheme get _scheme => terminalSchemeChoice.value;

  // Colours only: no bytes are sent and the session is not touched.
  void _schemeChanged() {
    if (mounted) {
      setState(() {});
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
    _queueSessionEnd();
  }

  /// A session that ended (remote close, network drop, cancel, failure) closes
  /// the page; there is no offline state to linger in. Never pops from inside
  /// the notification: it may arrive while another route is building.
  void _queueSessionEnd() {
    if (_endQueued || _closing) {
      return;
    }
    final status = _service.status;
    if (status != SshStatus.disconnected && status != SshStatus.failed) {
      return;
    }
    _endQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _endQueued = false;
      if (mounted) {
        _sessionEnded();
      }
    });
  }

  void _sessionEnded() {
    if (_closing || _connected || _connecting) {
      return;
    }
    final l10n = context.l10n;
    final error = _service.errorFor(l10n);
    if (_hasConnected) {
      // Established session ended: say so on the page we return to.
      showAppToast(
        context,
        error ??
            localizedText(
              _endReason ?? LocalizedText((l) => l.terminalDisconnected),
              l10n,
            ),
      );
      _leave();
    } else if (_service.status == SshStatus.failed || error != null) {
      // Never established (auth, host key, timeout): the connect page shows it.
      _leave(failure: error ?? l10n.terminalFailed);
    } else {
      _leave();
    }
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
      backgroundColor: _scheme.chrome,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        _commandsRoute = ModalRoute.of(sheetContext);
        return TerminalSchemeScope(
          scheme: _scheme,
          child: Theme(
            data: appTheme(brightness: _scheme.brightness),
            child: TerminalCommandSheet(
              draft: _draft,
              service: _service,
              insertSnippet: _insertSnippet,
              replaceDraft: _replaceDraft,
              sendDraft: _sendDraft,
              pasteDraft: _pasteToDraft,
              target: widget.target.label,
            ),
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

  /// File manager as a page sheet on this live connection: a new SFTP channel
  /// next to the shell. No bytes go to the shell, nothing reconnects, the draft
  /// stays. Closing the sheet closes only that channel; if the session ends
  /// meanwhile, [_leave] pops everything stacked above the terminal.
  Future<void> _openSftp() async {
    if (_sftpOpening || !_connected) {
      return;
    }
    _closeKeyboard();
    final generation = _service.generation;
    setState(() => _sftpOpening = true);
    SftpSession? session;
    try {
      session = await _service.openSftpOnClient();
    } on SftpException catch (problem) {
      if (mounted) {
        showAppToast(
          _dialogContext,
          sftpErrorText(_dialogContext.l10n, problem),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sftpOpening = false);
      }
    }
    if (session == null) {
      return;
    }
    if (!mounted || _closing || generation != _service.generation) {
      await session.close();
      return;
    }
    await showAppModal<void>(
      _dialogContext,
      builder: (_) => SftpBrowserPage(session: session!, sheet: true),
    );
    await session.close();
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

  /// Close button / system back. Only a live session asks, once, because
  /// leaving ends the remote shell; a draft is simply discarded.
  Future<void> _requestLeave() async {
    if (_closing || _exitPromptOpen) {
      return;
    }
    if (_connected) {
      setState(() => _exitPromptOpen = true);
      _closeKeyboard();
      final accepted = await confirmAction(
        _dialogContext,
        title: LocalizedText((l10n) => l10n.terminalDisconnectQuestion),
        message: LocalizedText(
          (l10n) => l10n.r2ConnDisconnectHelp(
            escapedCommandPreview(widget.target.label),
          ),
        ),
        action: LocalizedText((l10n) => l10n.terminalDisconnectExit),
      );
      if (!mounted) {
        return;
      }
      setState(() => _exitPromptOpen = false);
      if (!accepted || _closing) {
        return;
      }
    }
    _leave();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _endReason = LocalizedText((l10n) => l10n.terminalBackgroundDisconnected);
      _service.disconnect();
      _closeKeyboard();
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
        _endReason = LocalizedText((l10n) => l10n.terminalTargetChanged);
        _service.disconnect();
        _draft.clear();
        _terminalController.clearSelection();
        _terminal.onOutput = null;
        _terminal.onResize = null;
        _createTerminal();
        setState(() => _targetInvalidated = false);
        showAppToast(context, localizedText(_endReason!, context.l10n));
        _leave();
      });
    }
  }

  /// Closes the page (and anything stacked above it, e.g. the command panel
  /// or a confirmation) and discards the draft. [failure] is returned to the
  /// connect page when the session was never established.
  void _leave({String? failure}) {
    if (_closing) {
      return;
    }
    _closing = true;
    _service.disconnect();
    _draft.clear();
    _terminalFocus.unfocus();
    setState(() {});
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    if (route != null) {
      navigator.popUntil((candidate) => candidate == route);
    }
    navigator.pop(failure);
  }

  @override
  void dispose() {
    terminalSchemeChoice.removeListener(_schemeChanged);
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
      return;
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

  bool get _showBanner =>
      !_closing && (_connecting || _service.status == SshStatus.idle);

  bool get _connected => !_closing && !_targetInvalidated && _service.connected;

  bool get _connecting => switch (_service.status) {
    SshStatus.connecting ||
    SshStatus.verifying ||
    SshStatus.authenticating => true,
    _ => false,
  };

  late final SshPrompts _prompts = SshPrompts(
    service: _service,
    dialogContext: () => _dialogContext,
    targetLabel: widget.target.label,
    isOpen: () => mounted && !_closing && !_targetInvalidated,
  );

  Future<String?> _requestKeyPassphrase(String credentialName) =>
      _prompts.requestKeyPassphrase(credentialName);

  Future<bool> _verifyHost(HostVerificationRequest request) =>
      _prompts.verifyHost(request);

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
        _scheme.theme.green,
        _scheme.theme.green.withValues(alpha: .15),
      ),
      SshStatus.connecting || SshStatus.verifying || SshStatus.authenticating =>
        (_scheme.theme.yellow, _scheme.theme.yellow.withValues(alpha: .15)),
      SshStatus.failed => (
        _scheme.theme.red,
        _scheme.theme.red.withValues(alpha: .15),
      ),
      _ => (_scheme.muted, _scheme.muted.withValues(alpha: .12)),
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
    final scheme = _scheme;
    return Theme(
      data: appTheme(brightness: scheme.brightness),
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
            backgroundColor: scheme.theme.background,
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              toolbarHeight: headerHeight,
              backgroundColor: scheme.chrome,
              systemOverlayStyle: scheme.isDark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              shape: Border(bottom: BorderSide(color: scheme.hairline)),
              actionsIconTheme: IconThemeData(color: scheme.link),
              centerTitle: false,
              titleSpacing: 0,
              leading: IconButton(
                tooltip: context.l10n.terminalExit,
                onPressed: _requestLeave,
                color: scheme.link,
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
                              color: scheme.theme.foreground,
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
                                style: TextStyle(
                                  fontFamily: terminalFontFamily,
                                  fontSize: 11,
                                  height: 1.15,
                                  color: scheme.muted,
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
                  color: scheme.key,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onOpened: () => setState(_closeKeyboard),
                  onSelected: (action) {
                    switch (action) {
                      case 'details':
                        unawaited(_connectionDetails());
                      case 'paste':
                        unawaited(_pasteToDraft().then((_) {}));
                      case 'sftp':
                        unawaited(_openSftp());
                      case 'scheme':
                        unawaited(showTerminalSchemePicker(_dialogContext));
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
                    PopupMenuItem(
                      value: 'sftp',
                      enabled: _connected && !_sftpOpening,
                      child: Builder(
                        builder: (context) => Text(context.l10n.r3SftpTitle),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'scheme',
                      child: Builder(
                        builder: (context) =>
                            Text(context.l10n.r3TermColorScheme),
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
                                    keyboardAppearance: scheme.brightness,
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
                                    theme: scheme.theme,
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
                            if (_showBanner || _notice != null)
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
                                        if (_showBanner)
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
                                  color: scheme.chrome,
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
                                  backgroundColor: scheme.key,
                                  foregroundColor: scheme.theme.foreground,
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
                    TerminalSchemeScope(
                      scheme: scheme,
                      child: TerminalKeyBar(
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
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Only before a session exists: connecting (with cancel) or the idle
  /// "connect" prompt. Once a session has ended the page closes instead.
  Widget _connectionBanner(BuildContext context) => Container(
    key: const ValueKey('terminal-connection-banner'),
    width: double.infinity,
    color: _scheme.chrome,
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
                    child: Text(context.l10n.terminalConnect),
                  ),
              ],
            ),
            if (kIsWeb) Text(context.l10n.terminalBrowserUnsupported),
          ],
        ),
      ),
    ),
  );

  Widget _noticeBanner(BuildContext context) => Container(
    color: _scheme.chrome,
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
