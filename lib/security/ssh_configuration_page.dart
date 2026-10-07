import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../servers/ledger_controller.dart';
import 'security_models.dart';
import 'security_pages.dart';

class SshConfigurationPage extends StatefulWidget {
  const SshConfigurationPage({
    super.key,
    required this.ledger,
    required this.serverId,
  });
  final LedgerController ledger;
  final String serverId;
  @override
  State<SshConfigurationPage> createState() => _SshConfigurationPageState();
}

class _SshConfigurationPageState extends State<SshConfigurationPage> {
  final form = GlobalKey<FormState>();
  final host = TextEditingController(),
      port = TextEditingController(),
      username = TextEditingController();
  String? credentialId;
  int revision = -1;
  bool loading = true, dirty = false, saving = false, allowPop = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    await widget.ledger.security.initialize();
    if (!mounted) return;
    final config = widget.ledger.security.configFor(widget.serverId);
    host.text = config?.host ?? widget.ledger.byId(widget.serverId)?.host ?? '';
    port.text = '${config?.port ?? 22}';
    username.text = config?.username ?? '';
    credentialId = config?.credentialId;
    revision = config?.revision ?? -1;
    setState(() => loading = false);
  }

  @override
  void dispose() {
    host.dispose();
    port.dispose();
    username.dispose();
    super.dispose();
  }

  Future<void> cancel() async {
    if (saving) return;
    if (dirty &&
        !await confirmAction(
          context,
          title: '放弃连接配置？',
          message: '未保存的地址、用户名与凭据选择不会生效。',
          action: '放弃修改',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => allowPop = true);
    Navigator.pop(context);
  }

  Future<void> chooseCredential() async {
    final security = widget.ledger.security;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .55,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(20),
            children: [
              const SectionTitle('选择登录凭据'),
              SettingRow(
                icon: Icons.link_off,
                title: '解除当前凭据关联',
                subtitle: '保留连接配置，之后再选择',
                onTap: () => Navigator.pop(context, ''),
              ),
              for (final c in security.credentials)
                SettingRow(
                  icon: c.kind == CredentialKind.privateKey
                      ? Icons.key_outlined
                      : Icons.person_outline,
                  title: c.name,
                  subtitle:
                      '${credentialKind(c)} · 默认 ${c.defaultUsername.isEmpty ? '未设置' : c.defaultUsername}',
                  onTap: () => Navigator.pop(context, c.id),
                ),
              if (security.credentials.isEmpty)
                const InfoNote('尚无凭据。先返回，使用“管理凭据”新增。'),
            ],
          ),
        ),
      ),
    );
    if (!mounted || chosen == null) return;
    setState(() {
      credentialId = chosen.isEmpty ? null : chosen;
      dirty = true;
    });
    final credential = security.credentials
        .where((c) => c.id == chosen)
        .firstOrNull;
    if (credential == null ||
        credential.defaultUsername.isEmpty ||
        username.text == credential.defaultUsername) {
      return;
    }
    final adopt = await confirmAction(
      context,
      title: '使用凭据的默认用户名？',
      message:
          '当前连接用户名：${username.text.isEmpty ? '未填写' : username.text}\n凭据默认用户名：${credential.defaultUsername}\n\n只影响本台连接；取消将保留当前用户名。',
      action: '采用默认用户名',
    );
    if (mounted && adopt) username.text = credential.defaultUsername;
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() => saving = true);
    final saved = await widget.ledger.security.saveSshConfiguration(
      SshConfiguration(
        serverId: widget.serverId,
        host: host.text,
        port: int.parse(port.text),
        username: username.text,
        credentialId: credentialId,
        revision: revision,
      ),
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (saved) {
      setState(() => allowPop = true);
      Navigator.pop(context);
      securityMessage(context, 'SSH 配置已保存，未建立网络连接');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger.security,
    builder: (context, _) {
      final security = widget.ledger.security;
      final credential = security.credentials
          .where((c) => c.id == credentialId)
          .firstOrNull;
      return PopScope(
        canPop: allowPop || (!dirty && !saving),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) cancel();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('SSH 连接配置'),
            leading: IconButton(
              tooltip: '取消连接配置',
              icon: const Icon(Icons.arrow_back),
              onPressed: saving ? null : cancel,
            ),
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: form,
                  onChanged: () {
                    if (!dirty) setState(() => dirty = true);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        widget.ledger.byId(widget.serverId)?.name ?? '服务器',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const InfoNote('连接配置和台账地址分别保存。不会修改云主机设置。'),
                      SecurityNotice(controller: security),
                      TextFormField(
                        key: const ValueKey('ssh-host'),
                        controller: host,
                        enabled: !saving,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: '主机地址',
                          hintText: 'IPv4 / IPv6 / 域名，不含协议',
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? '请填写主机地址' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('ssh-port'),
                        controller: port,
                        enabled: !saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '端口'),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return n == null || n < 1 || n > 65535
                              ? '端口应为 1–65535'
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('ssh-username'),
                        controller: username,
                        enabled: !saving,
                        autocorrect: false,
                        maxLength: 64,
                        decoration: const InputDecoration(labelText: '当前连接用户名'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? '请填写登录用户名，或使用凭据的默认用户名'
                            : null,
                      ),
                      SectionTitle(
                        '登录凭据',
                        action: TextButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  await Navigator.push<void>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          SecurityPage(ledger: widget.ledger),
                                    ),
                                  );
                                  if (mounted) setState(() {});
                                },
                          child: const Text('管理凭据'),
                        ),
                      ),
                      LedgerCard(
                        padding: EdgeInsets.zero,
                        child: SettingRow(
                          icon: Icons.key_outlined,
                          title: credential?.name ?? '凭据待配置',
                          subtitle: credential == null
                              ? '可先保存配置，连接前必须选择凭据'
                              : '${credentialKind(credential)} · 点击更换或解除',
                          onTap: saving || security.needsReload
                              ? null
                              : chooseCredential,
                        ),
                      ),
                      const InfoNote(
                        '用户名属于本台连接。换凭据时只有明确选择“采用默认用户名”才更改它，取消和相同用户名都不会修改其他连接。',
                      ),
                      const InfoNote(
                        '此页只保存连接配置。建立连接时先核验主机身份，再进行登录认证；主机公钥变化时会暂停认证，等待重新核实。',
                      ),
                      FilledButton(
                        onPressed:
                            saving || security.busy || security.needsReload
                            ? null
                            : save,
                        child: Text(saving ? '保存中…' : '保存 SSH 配置'),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),
      );
    },
  );
}
