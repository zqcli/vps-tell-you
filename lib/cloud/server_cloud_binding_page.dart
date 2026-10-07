import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../servers/ledger_controller.dart';
import 'cloud_account.dart';
import 'cloud_widgets.dart';

/// Edits one existing server's local association from saved observations only.
/// Returns true after a successful change. Opening or reloading this page never
/// requests cloud credentials, creates an adapter, or refreshes a remote API.
class ServerCloudBindingPage extends StatefulWidget {
  const ServerCloudBindingPage({
    super.key,
    required this.ledger,
    required this.serverId,
  });
  final LedgerController ledger;
  final String serverId;

  @override
  State<ServerCloudBindingPage> createState() => _ServerCloudBindingPageState();
}

class _ServerCloudBindingPageState extends State<ServerCloudBindingPage> {
  ServerCloudBindingOptions? _options;
  String? _accountId, _error;
  CloudBindingChoice? _selected;
  bool _loading = false,
      _saving = false,
      _confirming = false,
      _expired = false,
      _committed = false,
      _disposed = false;

  bool get _busy =>
      _loading ||
      _saving ||
      _confirming ||
      widget.ledger.busy ||
      widget.ledger.cloud.busy;
  bool get _blocked =>
      _busy ||
      _expired ||
      _committed ||
      widget.ledger.refreshFailed ||
      widget.ledger.cloud.needsReload ||
      _options?.server.archived == true ||
      _options?.server.isDemo == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _loading = true;
      _error = null;
      _options = null;
      _selected = null;
    });
    ServerCloudBindingOptions? loaded;
    try {
      if (widget.ledger.refreshFailed) await widget.ledger.refresh();
      if (widget.ledger.cloud.needsReload) {
        await widget.ledger.cloud.reload();
      }
      if (!widget.ledger.refreshFailed && !widget.ledger.cloud.needsReload) {
        loaded = await widget.ledger.cloud.serverBindingOptions(
          widget.serverId,
        );
      }
    } catch (_) {
      // Storage exceptions may contain paths or private data. Use a closed UI
      // message, and never attempt another write against this incomplete read.
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _options = loaded;
      _selected = loaded?.current;
      _accountId =
          loaded?.current?.accountId ?? loaded?.accounts.firstOrNull?.id;
      _expired = loaded == null;
      if (loaded == null) {
        _error = widget.ledger.cloud.error ?? '无法读取本地关联资料，请重试';
      }
    });
    if (loaded != null && _committed && mounted) {
      Navigator.pop(context, true);
    }
  }

  String _accountName(String id) {
    final account = _options?.accounts.where((a) => a.id == id).firstOrNull;
    return account == null ? '面板账户' : '${account.alias} · ${account.endpoint}';
  }

  String _instanceName(CloudBindingChoice choice) {
    final observation = choice.observation;
    for (final value in [observation.name, observation.hostname]) {
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return observation.serverId == null
        ? '此账户的单台实例'
        : '实例 ${observation.serverId}';
  }

  bool _same(CloudBindingChoice? a, CloudBindingChoice? b) =>
      a?.accountId == b?.accountId && a?.instanceKey == b?.instanceKey;

  bool _available(CloudBindingChoice choice) =>
      !choice.stale &&
      !choice.missing &&
      (choice.serverId == null || choice.serverId == widget.serverId) &&
      _options?.accounts
              .where((a) => a.id == choice.accountId)
              .firstOrNull
              ?.lastFailure ==
          null;

  Future<void> _save({bool unlink = false}) async {
    final options = _options;
    final choice = unlink ? null : _selected;
    if (_blocked ||
        options == null ||
        (!unlink && (choice == null || !_available(choice))) ||
        _same(options.current, choice)) {
      return;
    }
    if (options.current != null) {
      setState(() => _confirming = true);
      final confirmed = await confirmAction(
        context,
        title: unlink ? '解除这台服务器的面板关联？' : '更换这台服务器的面板关联？',
        message:
            '${options.server.name}\n当前：${_accountName(options.current!.accountId)} · ${_instanceName(options.current!)}'
            '${unlink ? '' : '\n更换为：${_accountName(choice!.accountId)} · ${_instanceName(choice)}'}'
            '\n\n仅修改本地关联，保留服务器资料、硬件、费用、付款、SSH、面板账户及授权。不会操作远端实例或停止扣费。',
        action: unlink ? '仅解除这台关联' : '确认更换关联',
        dangerous: unlink,
      );
      if (!mounted) return;
      setState(() => _confirming = false);
      if (!confirmed || _blocked) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.ledger.cloud.setServerBinding(
      options,
      choice: choice,
      isCancelled: () => _disposed,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _committed = saved;
      _expired = !saved;
      _error = widget.ledger.cloud.error;
    });
    if (!saved) return;
    if (widget.ledger.cloud.needsReload) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(unlink ? '已解除这台服务器的面板关联' : '已保存面板账户关联')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger,
    builder: (context, _) {
      final options = _options;
      final current = options?.current;
      final choices = options?.choices
          .where((choice) => choice.accountId == _accountId)
          .toList();
      return PopScope<bool>(
        canPop: !_saving,
        child: Scaffold(
          appBar: AppBar(title: const Text('关联面板账户')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  const InfoNote(
                    '这里只使用已保存的 API 返回信息，不会连接面板。没有可选实例或上次读取失败时，请到“面板账户”手动刷新，再返回重新读取本地列表。',
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_committed) const CloudNotice('关联改动已保存，请先重新读取资料；不要重复提交。'),
                  if (_error != null) CloudNotice(_error!, error: true),
                  if (widget.ledger.refreshFailed)
                    const CloudNotice('台账显示内容尚未更新，请先重新读取。', error: true),
                  TextButton.icon(
                    key: const ValueKey('server-cloud-reload'),
                    onPressed: _busy ? null : _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新读取本地列表'),
                  ),
                  if (options != null) ...[
                    Text(
                      options.server.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (options.server.archived || options.server.isDemo)
                      const CloudNotice('已归档或演示记录不能修改面板关联。', error: true),
                    if (current != null) ...[
                      const SectionTitle('当前关联'),
                      LedgerCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(_accountName(current.accountId)),
                            Text(_instanceName(current)),
                            TextButton.icon(
                              key: const ValueKey('server-cloud-unbind'),
                              onPressed: _blocked
                                  ? null
                                  : () => _save(unlink: true),
                              icon: const Icon(Icons.link_off),
                              label: const Text('解除这台关联'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SectionTitle('选择面板账户'),
                    if (options.accounts.isEmpty)
                      const CloudNotice('还没有已保存的面板账户。请先到“面板账户”添加并验证账户。'),
                    for (final account in options.accounts)
                      ListTile(
                        key: ValueKey('server-cloud-account-${account.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _accountId == account.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        title: Text(account.alias),
                        subtitle: Text(
                          '${cloudProviderName(account.provider)}\n${account.endpoint}',
                        ),
                        selected: _accountId == account.id,
                        onTap: _blocked
                            ? null
                            : () => setState(() {
                                _accountId = account.id;
                                _selected = current?.accountId == account.id
                                    ? current
                                    : null;
                              }),
                      ),
                    if (_accountId != null) ...[
                      const SectionTitle('选择已读取的实例'),
                      if (choices?.isEmpty ?? true)
                        const CloudNotice('这个账户没有已保存的实例信息。请到“面板账户”手动刷新。'),
                      for (final choice in choices!)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: LedgerCard(
                            padding: EdgeInsets.zero,
                            child: CheckboxListTile(
                              key: ValueKey(
                                'server-cloud-instance-${choice.accountId}-${choice.instanceKey}',
                              ),
                              value: _same(_selected, choice),
                              onChanged: _blocked || !_available(choice)
                                  ? null
                                  : (_) => setState(() => _selected = choice),
                              title: Text(_instanceName(choice)),
                              subtitle: Text(
                                [
                                  if (choice.observation.ipv4 != null)
                                    choice.observation.ipv4!,
                                  if (choice.observation.projectName != null)
                                    choice.observation.projectName!,
                                  '读取时间：${cloudTime(choice.observation.observedAt)}',
                                  if (choice.serverId == widget.serverId)
                                    '当前关联',
                                  if (choice.serverId != null &&
                                      choice.serverId != widget.serverId)
                                    '已关联：${widget.ledger.byId(choice.serverId!)?.name ?? '其他服务器'} · 不可覆盖',
                                  if (choice.missing)
                                    '本次未返回 · 请到面板账户手动刷新'
                                  else if (choice.stale ||
                                      !_available(choice) &&
                                          choice.serverId == null)
                                    '上次读取失败 · 请到面板账户手动刷新',
                                ].join('\n'),
                              ),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const ValueKey('server-cloud-save'),
                      onPressed:
                          _blocked ||
                              _selected == null ||
                              !_available(_selected!) ||
                              _same(current, _selected)
                          ? null
                          : _save,
                      icon: const Icon(Icons.link),
                      label: Text(
                        _saving
                            ? '正在保存…'
                            : current == null
                            ? '保存关联'
                            : '更换关联',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const InfoNote('只修改本地关联；服务器资料、硬件、账务及 SSH 保持原样。'),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
