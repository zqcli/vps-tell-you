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
  StreamSubscription<String>? _output;
  bool _sendBusy = false,
      _powerBusy = false,
      _hasConnected = false,
      _closing = false,
      _targetInvalidated = false;
  int _targetEpoch = 0;
  String? _notice;
  int? _powerIssuedGeneration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draft = TextEditingController(text: widget.initialDraft);
    _service =
        widget.serviceFactory?.call(widget.ledger.security) ??
        NativeSshService(security: widget.ledger.security);
    _createTerminal();
    _service.addListener(_changed);
    _output = _service.output.listen((text) => _terminal.write(text));
    if (widget.connectOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _connect();
      });
    }
  }

  void _createTerminal() {
    _terminal = Terminal(
      maxLines: 3000,
      inputHandler: const CascadeInputHandler([
        _CursorKeysHandler(),
        defaultInputHandler,
      ]),
    );
    _terminal.onOutput = (text) {
      if (_connected) _service.write(text);
    };
    _terminal.onResize = (columns, rows, pixelWidth, pixelHeight) {
      if (_connected) _service.resize(columns, rows);
    };
  }

  void _changed() {
    if (!mounted) return;
    if (_connected && !_hasConnected) {
      _hasConnected = true;
      _service.resize(_terminal.viewWidth, _terminal.viewHeight);
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _service.disconnect();
      _terminalFocus.unfocus();
      if (mounted) setState(() => _notice = '应用进入后台，连接已清理。需要手动重连，不会重放输入。');
    }
  }

  @override
  void didUpdateWidget(TerminalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target.label != widget.target.label ||
        oldWidget.target.credentialId != widget.target.credentialId) {
      _targetInvalidated = true;
      final epoch = ++_targetEpoch;
      // Updating a route may happen while another route's dialog is mounted.
      // Disconnect notifications must not rebuild that overlay during build.
      // Block local input synchronously, then invalidate the service generation
      // before the next event can interact with the changed target.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _closing || epoch != _targetEpoch) return;
        _service.disconnect();
        _draft.clear();
        _terminal.onOutput = null;
        _terminal.onResize = null;
        _createTerminal();
        setState(() {
          _targetInvalidated = false;
          _notice = '目标已变化，连接和草稿已清空。请显式连接新目标。';
        });
      });
    }
  }

  void _leave() {
    if (_closing) return;
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
    super.dispose();
  }

  Future<void> _connect() async {
    if (_closing || _targetInvalidated || kIsWeb || _connecting || _connected) {
      return;
    }
    if (_service.status != SshStatus.idle) {
      _draft.clear();
      _terminal.onOutput = null;
      _terminal.onResize = null;
      _createTerminal();
    }
    setState(() {
      _hasConnected = false;
      _notice = widget.powerMode ? '连接后使用“单机电源”，选择操作并完成两次确认。' : null;
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
    if (!mounted || _closing || _targetInvalidated) return null;
    final generation = _service.generation;
    final value = await showDialog<String>(
      context: context,
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
    if (!mounted) return false;
    final generation = _service.generation;
    bool current() =>
        mounted &&
        !_closing &&
        !_targetInvalidated &&
        _service.generation == generation &&
        _service.status == SshStatus.verifying;
    if (request.status == HostTrustStatus.changed) {
      final start = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('主机密钥变化 · 已阻断认证'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(
                  '${request.identity.host}:${request.identity.port}',
                ),
                const InfoNote('这可能是重装或中间人攻击。尚未发送登录凭据。请通过厂商控制台等独立渠道核实原因与新公钥。'),
                const Text('此前指纹'),
                SelectableText(request.previous?.fingerprint ?? '无记录'),
                const SizedBox(height: 12),
                const Text('本次指纹'),
                SelectableText(request.identity.fingerprint),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('拒绝连接'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('开始独立重新核实'),
            ),
          ],
        ),
      );
      if (start != true || !current()) return false;
    }
    if (!mounted || !current()) return false;
    final accepted = await showDialog<bool>(
      context: context,
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
    _draft.text = selected.content;
    setState(() => _notice = '片段仅放入待发送草稿，向 SSH 发送了 0 字节。');
  }

  Future<void> _sendDraft() async {
    if (_sendBusy || !_connected || _draft.text.isEmpty) return;
    final generation = _service.generation;
    final exact = _draft.text;
    setState(() => _sendBusy = true);
    try {
      final payload = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SendDraftDialog(
          service: _service,
          generation: generation,
          target: widget.target.label,
          exact: exact,
        ),
      );
      if (payload == null ||
          !mounted ||
          !_connected ||
          _closing ||
          _service.generation != generation) {
        return;
      }
      _service.write(payload);
      _draft.clear();
      setState(() => _notice = '已向当前 SSH 会话写入确认的内容；远端执行结果请查看终端。');
    } finally {
      if (mounted) setState(() => _sendBusy = false);
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
        context,
        service: _service,
        action: action,
      );
      if (!mounted || result == null) return;
      _powerIssuedGeneration = generation;
      setState(
        () => _notice = result == PowerResult.failed
            ? '电源指令未提交或被拒绝。请核实连接、远端权限及厂商控制台状态；不会自动重发。'
            : '电源指令已尝试提交，结果未知。连接断开不证明操作完成；请到厂商控制台核实，不会自动重发。',
      );
    } finally {
      if (mounted) setState(() => _powerBusy = false);
    }
  }

  String get _statusLabel => switch (_service.status) {
    SshStatus.idle => '未连接',
    SshStatus.connecting => '连接中',
    SshStatus.verifying => '核验主机身份中',
    SshStatus.authenticating => '认证中',
    SshStatus.connected => '已连接 · SSH PTY',
    SshStatus.disconnected => '已断开',
    SshStatus.failed => '连接失败',
  };

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _closing,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '退出终端',
          onPressed: _leave,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          widget.target.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          PopupMenuButton<SshPowerAction>(
            tooltip: '单机电源',
            enabled:
                _connected &&
                !_powerBusy &&
                _powerIssuedGeneration != _service.generation,
            icon: const Icon(Icons.power_settings_new),
            onSelected: _power,
            itemBuilder: (_) => [
              const PopupMenuItem(
                enabled: false,
                child: Text('开机不可用 · 需厂商控制台'),
              ),
              const PopupMenuItem(
                value: SshPowerAction.reboot,
                child: Text('SSH 重启'),
              ),
              const PopupMenuItem(
                value: SshPowerAction.shutdown,
                child: Text('SSH 关机'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  escapedCommandPreview(widget.target.label),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  children: [
                    Text(
                      _statusLabel,
                      key: const ValueKey('terminal-status'),
                      style: TextStyle(
                        color: _connected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_connecting || _connected)
                      TextButton(
                        key: const ValueKey('terminal-disconnect'),
                        onPressed: _service.disconnect,
                        child: Text(_connecting ? '取消连接' : '断开连接'),
                      )
                    else
                      TextButton(
                        key: const ValueKey('terminal-connect'),
                        onPressed: kIsWeb ? null : _connect,
                        child: Text(
                          _service.status == SshStatus.idle
                              ? '连接'
                              : '重新连接 · 清空草稿',
                        ),
                      ),
                  ],
                ),
                if (_service.error != null) InfoNote(_service.error!),
                if (_notice != null) InfoNote(_notice!),
                if (kIsWeb) const InfoNote('Web 预览不支持原生 SSH。请使用原生应用。'),
                SizedBox(
                  height: (constraints.maxHeight * .48).clamp(160.0, 460.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: TerminalView(
                      _terminal,
                      key: const ValueKey('ssh-terminal'),
                      focusNode: _terminalFocus,
                      autofocus: false,
                      readOnly: !_connected,
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    for (final key
                        in const <(String, TerminalKey, bool, IconData?)>[
                          ('Esc', TerminalKey.escape, false, null),
                          ('Tab', TerminalKey.tab, false, null),
                          ('Ctrl+C', TerminalKey.keyC, true, null),
                          (
                            '向上方向键',
                            TerminalKey.arrowUp,
                            false,
                            Icons.keyboard_arrow_up,
                          ),
                          (
                            '向下方向键',
                            TerminalKey.arrowDown,
                            false,
                            Icons.keyboard_arrow_down,
                          ),
                          (
                            '向左方向键',
                            TerminalKey.arrowLeft,
                            false,
                            Icons.keyboard_arrow_left,
                          ),
                          (
                            '向右方向键',
                            TerminalKey.arrowRight,
                            false,
                            Icons.keyboard_arrow_right,
                          ),
                        ])
                      Tooltip(
                        message: key.$1,
                        excludeFromSemantics: true,
                        child: OutlinedButton(
                          key: ValueKey('terminal-key-${key.$2.name}'),
                          onPressed: _connected
                              ? () => _terminal.keyInput(key.$2, ctrl: key.$3)
                              : null,
                          child: key.$4 == null
                              ? Text(key.$1)
                              : Icon(key.$4, semanticLabel: key.$1, size: 20),
                        ),
                      ),
                  ],
                ),
                const InfoNote('终端键盘与快捷键直接发送。下方草稿独立，需预览确认后才发送。'),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '待发送草稿',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: _insertSnippet,
                      child: const Text('插入片段'),
                    ),
                  ],
                ),
                TextField(
                  key: const ValueKey('terminal-draft'),
                  controller: _draft,
                  maxLength: CommandSnippet.maxContentLength,
                  inputFormatters: [
                    TextInputFormatter.withFunction(
                      (oldValue, newValue) =>
                          newValue.text.length <=
                              CommandSnippet.maxContentLength
                          ? newValue
                          : oldValue,
                    ),
                  ],
                  minLines: 2,
                  maxLines: 5,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.multiline,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '仅为草稿，编辑不会写入 SSH',
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const ValueKey('terminal-send'),
                  onPressed: _connected && !_sendBusy && _draft.text.isNotEmpty
                      ? _sendDraft
                      : null,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('预览并发送'),
                ),
                const InfoNote(
                  '取消、退出、换目标和重连不会自动发送或重放草稿。后台可能断开，长任务建议使用远端 tmux / screen。',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
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
        title: Text(changed ? '重新核实新的主机公钥' : '首次连接 · 核对主机身份'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                '主机：${identity.host}\n端口：${identity.port}\n算法：${identity.algorithm}',
              ),
              const SizedBox(height: 12),
              const Text('SHA-256 指纹'),
              SelectableText(identity.fingerprint),
              const SizedBox(height: 12),
              const Text('完整主机公钥'),
              SelectableText('${identity.algorithm} ${identity.publicKey}'),
              const InfoNote('请从厂商控制台或其他独立可信渠道核对。仅看见这个弹窗不代表身份可信。'),
              CheckboxListTile(
                key: const ValueKey('host-verified-check'),
                contentPadding: EdgeInsets.zero,
                value: _checked,
                onChanged: current
                    ? (value) => setState(() => _checked = value == true)
                    : null,
                title: Text(
                  changed ? '我已独立重新核实变化原因与完整新公钥' : '我已通过独立渠道核实本次完整主机身份',
                ),
              ),
              if (!current) const InfoNote('连接已取消或超时，此核验已失效。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('拒绝连接'),
          ),
          FilledButton(
            key: const ValueKey('host-verified-confirm'),
            onPressed: current && _checked && !_submitted
                ? () {
                    setState(() => _submitted = true);
                    Navigator.pop(context, true);
                  }
                : null,
            child: Text(changed ? '确认更新此主机信任' : '确认信任并认证'),
          ),
        ],
      );
    },
  );
}

class _SendDraftDialog extends StatefulWidget {
  const _SendDraftDialog({
    required this.service,
    required this.generation,
    required this.target,
    required this.exact,
  });
  final SshService service;
  final int generation;
  final String target, exact;
  @override
  State<_SendDraftDialog> createState() => _SendDraftDialogState();
}

class _SendDraftDialogState extends State<_SendDraftDialog> {
  bool _enter = false, _submitted = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) {
      final current =
          widget.service.connected &&
          widget.service.generation == widget.generation;
      final payload = '${widget.exact}${_enter ? '\r' : ''}';
      return AlertDialog(
        title: const Text('确认发送到单台 SSH'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                escapedCommandPreview(widget.target),
                textDirection: TextDirection.ltr,
              ),
              const InfoNote('以下是将发送的完整内容。反斜杠、换行、回车及控制字符以转义形式展示；它们可能立即执行命令。'),
              SelectableText(
                escapedCommandPreview(payload),
                key: const ValueKey('draft-exact-preview'),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              CheckboxListTile(
                key: const ValueKey('draft-append-enter'),
                contentPadding: EdgeInsets.zero,
                value: _enter,
                onChanged: current
                    ? (value) => setState(() => _enter = value == true)
                    : null,
                title: const Text('额外追加 Enter（\\r）'),
                subtitle: const Text('默认不追加；正文中已有的换行和控制字符原样保留'),
              ),
              if (!current) const InfoNote('连接已变化，本次确认作废。没有发送草稿。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('draft-confirm-send'),
            onPressed: current && !_submitted
                ? () {
                    setState(() => _submitted = true);
                    Navigator.pop(context, payload);
                  }
                : null,
            child: const Text('发送完整内容'),
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
    if (!mounted || _submitted) return;
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
      if (mounted) setState(() => _invalidated = true);
    }
  }

  void _cancel() {
    _input.clear();
    Navigator.pop(context);
  }

  void _submit() {
    if (!_current || _input.text.isEmpty) return;
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
    title: const Text('解锁本次 SSH 私钥'),
    content: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            escapedCommandPreview(widget.target),
            textDirection: TextDirection.ltr,
          ),
          Text('凭据：${escapedCommandPreview(widget.credentialName)}'),
          const InfoNote('这是私钥解密口令，不是服务器登录密码。仅用于本次连接，不会保存；下次连接需重新输入。'),
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
            decoration: const InputDecoration(labelText: '本次私钥口令'),
          ),
          if (_invalidated) const InfoNote('连接已取消或页面进入后台，口令已清空。请取消并重新连接。'),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: _cancel, child: const Text('取消连接')),
      FilledButton(
        key: const ValueKey('ssh-key-passphrase-submit'),
        onPressed: _current && _input.text.isNotEmpty ? _submit : null,
        child: const Text('仅解锁本次连接'),
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
    if (event.ctrl || event.alt || event.shift) return null;
    final suffix = switch (event.key) {
      TerminalKey.arrowUp => 'A',
      TerminalKey.arrowDown => 'B',
      TerminalKey.arrowRight => 'C',
      TerminalKey.arrowLeft => 'D',
      _ => null,
    };
    if (suffix == null) return null;
    return '${event.state.cursorKeysMode ? '\x1bO' : '\x1b['}$suffix';
  }
}
