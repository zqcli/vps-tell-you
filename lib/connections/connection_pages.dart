import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../security/host_trust.dart';
import '../security/security_pages.dart';
import '../security/ssh_configuration_page.dart';
import '../servers/ledger_controller.dart';
import 'ssh_service.dart';
import 'terminal_page.dart';

/// Saved configurations and temporary targets use the same terminal flow.
/// Opening this page only reads metadata; the connect button is the network gate.
class SshConnectPage extends StatefulWidget {
  const SshConnectPage({
    super.key,
    required this.ledger,
    this.initialServerId,
    this.initialDraft = '',
    this.powerMode = false,
    this.serviceFactory,
  });
  final LedgerController ledger;
  final String? initialServerId;
  final String initialDraft;
  final bool powerMode;
  final SshServiceFactory? serviceFactory;

  @override
  State<SshConnectPage> createState() => _SshConnectPageState();
}

class _SshConnectPageState extends State<SshConnectPage> {
  final _form = GlobalKey<FormState>();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '22');
  final _username = TextEditingController();
  String? _serverId, _credentialId;
  String? _error;
  bool _loading = true, _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await widget.ledger.security.initialize();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = loaded ? null : '无法读取连接资料，请重试';
      if (loaded) _selectServer(widget.initialServerId);
    });
  }

  void _selectServer(String? id) {
    _serverId = id;
    final config = id == null ? null : widget.ledger.security.configFor(id);
    _host.text = config?.host ?? widget.ledger.byId(id ?? '')?.host ?? '';
    _port.text = '${config?.port ?? 22}';
    _username.text = config?.username ?? '';
    _credentialId = config?.credentialId;
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_opening || kIsWeb || !_form.currentState!.validate()) return;
    final server = widget.ledger.byId(_serverId ?? '');
    if (server?.isDemo == true || server?.archived == true) return;
    setState(() => _opening = true);
    try {
      final target = SshTarget(
        name: server?.name ?? '临时连接',
        host: normalizedHost(_host.text),
        port: int.parse(_port.text),
        username: _username.text.trim(),
        credentialId: _credentialId!,
        serverId: _serverId,
      );
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => TerminalPage(
            ledger: widget.ledger,
            target: target,
            initialDraft: widget.initialDraft,
            powerMode: widget.powerMode,
            connectOnOpen: true,
            serviceFactory: widget.serviceFactory,
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _error = '连接资料无效，请检查地址、端口和凭据');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = widget.ledger.security;
    final server = widget.ledger.byId(_serverId ?? '');
    final credential = security.credentials
        .where((item) => item.id == _credentialId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(widget.powerMode ? '选择单机电源目标' : 'SSH 快速连接')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const InfoNote('一次只连接一台。核对主机身份后，才向服务器发送所选凭据的认证信息。'),
                  if (kIsWeb)
                    const InfoNote('Web 预览不支持原生 SSH / TCP，也不接受真实秘密。请使用原生应用。'),
                  if (_error != null) ...[
                    InfoNote(_error!),
                    TextButton(onPressed: _load, child: const Text('重新读取连接资料')),
                  ],
                  DropdownButtonFormField<String>(
                    key: const ValueKey('connect-target'),
                    initialValue: _serverId ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '目标服务器'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('临时目标 · 不保存配置'),
                      ),
                      for (final item in widget.ledger.active)
                        DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            '${item.name}${item.isDemo ? ' · 演示，不连接' : ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _selectServer(value == '' ? null : value);
                    }),
                  ),
                  if (server?.isDemo == true)
                    const InfoNote('演示服务器使用保留地址，不允许建立网络连接。'),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('connect-host'),
                    controller: _host,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: '主机地址',
                      hintText: 'IPv4 / IPv6 / 域名',
                    ),
                    validator: (value) {
                      try {
                        normalizedHost(value ?? '');
                        return null;
                      } catch (_) {
                        return '请输入有效主机，不含协议、用户名或端口';
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('connect-port'),
                    controller: _port,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '端口'),
                    validator: (value) {
                      final port = int.tryParse(value ?? '');
                      return port == null || port < 1 || port > 65535
                          ? '端口应为 1–65535'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('connect-user'),
                    controller: _username,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: 64,
                    decoration: const InputDecoration(labelText: '登录用户名'),
                    validator: (value) =>
                        value == null ||
                            value.trim().isEmpty ||
                            RegExp(r'[\x00-\x20\x7f]').hasMatch(value.trim())
                        ? '请显式填写有效用户名'
                        : null,
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'connect-credential-$_serverId-$_credentialId',
                    ),
                    initialValue: credential?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '已保存的登录凭据'),
                    items: [
                      for (final item in security.credentials)
                        DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            '${item.name} · ${credentialKind(item)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) => setState(() => _credentialId = id),
                    validator: (_) => credential == null ? '请选择登录凭据' : null,
                  ),
                  if (credential != null &&
                      credential.defaultUsername.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(
                        () => _username.text = credential.defaultUsername,
                      ),
                      child: Text('显式采用默认用户名：${credential.defaultUsername}'),
                    ),
                  TextButton(
                    onPressed: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SecurityPage(ledger: widget.ledger),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                    child: const Text('管理凭据'),
                  ),
                  if (_serverId != null)
                    TextButton(
                      onPressed: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SshConfigurationPage(
                              ledger: widget.ledger,
                              serverId: _serverId!,
                            ),
                          ),
                        );
                        if (mounted) setState(() => _selectServer(_serverId));
                      },
                      child: const Text('编辑并保存此服务器的 SSH 配置'),
                    ),
                  const InfoNote(
                    '本页改动只用于本次连接。秘密从原生凭据库读取，不在这里输入或另存。后台可能断开；长任务建议在远端使用 tmux / screen。',
                  ),
                  if (widget.initialDraft.isNotEmpty)
                    const InfoNote('片段将放入独立待发送区。连接、核验、认证都不会发送片段。'),
                  if (widget.powerMode)
                    const InfoNote(
                      '连接后才能选择重启 / 关机，并再次完成两次确认。没有 SSH 开机或 API 电源功能。',
                    ),
                  FilledButton.icon(
                    key: const ValueKey('connect-start'),
                    onPressed:
                        _opening ||
                            kIsWeb ||
                            server?.isDemo == true ||
                            security.needsReload ||
                            _error != null
                        ? null
                        : _connect,
                    icon: const Icon(Icons.terminal),
                    label: const Text('核对并连接'),
                  ),
                ],
              ),
            ),
    );
  }
}
