import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../servers/ledger_controller.dart';
import '../servers/server_detail.dart';
import 'security_controller.dart';
import 'security_models.dart';
import 'host_trust_pages.dart';

final securityRouteObserver = RouteObserver<ModalRoute<dynamic>>();

String credentialKind(CredentialMetadata credential) =>
    credential.kind == CredentialKind.password ? '用户名与密码' : 'SSH 密钥';

void securityMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

class SecurityNotice extends StatelessWidget {
  const SecurityNotice({super.key, required this.controller});
  final SecurityController controller;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (controller.error != null) InfoNote(controller.error!),
      if (controller.needsReload)
        OutlinedButton(
          onPressed: controller.busy ? null : controller.reload,
          child: const Text('重新读取已保存的资料'),
        ),
      if (controller.cleanupPending)
        LedgerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const InfoNote(
                '有未完成的安全存储清理。当前连接引用已保留；请在系统安全存储可用后重试。不会删除仍在使用的秘密。',
              ),
              OutlinedButton(
                onPressed: controller.busy ? null : controller.retryCleanup,
                child: const Text('重试清理未引用秘密'),
              ),
            ],
          ),
        ),
    ],
  );
}

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key, required this.ledger});
  final LedgerController ledger;
  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  String search = '';
  CredentialKind? filter;
  bool loading = true;
  SecurityController get security => widget.ledger.security;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    await security.initialize();
    if (mounted) setState(() => loading = false);
  }

  Future<void> add() async {
    final kind = await showModalBottomSheet<CredentialKind>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle('新增登录凭据'),
              SettingRow(
                icon: Icons.key_outlined,
                title: '导入 SSH 密钥',
                subtitle: '系统文件选择器或粘贴 · 校验格式与口令',
                onTap: () => Navigator.pop(context, CredentialKind.privateKey),
              ),
              SettingRow(
                icon: Icons.person_outline,
                title: '保存用户名与密码',
                subtitle: '可供多台服务器引用',
                onTap: () => Navigator.pop(context, CredentialKind.password),
              ),
            ],
          ),
        ),
      ),
    );
    if (kind != null && mounted) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CredentialForm(ledger: widget.ledger, kind: kind),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: security,
    builder: (context, _) {
      final query = search.trim().toLowerCase();
      final visible = security.credentials.where(
        (c) =>
            (filter == null || c.kind == filter) &&
            '${c.name} ${c.defaultUsername}'.toLowerCase().contains(query),
      );
      return Scaffold(
        appBar: AppBar(
          title: const Text('密钥与安全'),
          actions: [
            IconButton(
              tooltip: '新增凭据',
              onPressed: security.busy || security.needsReload ? null : add,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const InfoNote('凭据独立管理，连接只引用凭据。秘密仅保存在系统安全存储中。'),
                  SecurityNotice(controller: security),
                  TextField(
                    key: const ValueKey('credential-search'),
                    decoration: const InputDecoration(
                      labelText: '搜索名称、默认用户名',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => search = value),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in <CredentialKind?, String>{
                        null: '全部',
                        CredentialKind.privateKey: 'SSH 密钥',
                        CredentialKind.password: '用户名与密码',
                      }.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: filter == entry.key,
                          onSelected: (_) => setState(() => filter = entry.key),
                        ),
                    ],
                  ),
                  SectionTitle('已保存的登录凭据 · ${security.credentials.length} 条'),
                  if (visible.isEmpty)
                    const LedgerCard(child: InfoNote('没有匹配的凭据。可切换筛选或新增。')),
                  for (final c in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LedgerCard(
                        padding: EdgeInsets.zero,
                        child: SettingRow(
                          icon: c.kind == CredentialKind.password
                              ? Icons.person_outline
                              : Icons.key_outlined,
                          title: c.name,
                          subtitle:
                              '${credentialKind(c)}${c.defaultUsername.isEmpty ? '' : ' · ${c.defaultUsername}'}\n${security.sshConfigurations.where((s) => s.credentialId == c.id).length} 台关联',
                          onTap: () =>
                              credentialMenu(context, widget.ledger, c),
                        ),
                      ),
                    ),
                  const SectionTitle('设备与连接安全'),
                  LedgerCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SettingRow(
                          icon: Icons.verified_user_outlined,
                          title: '已信任的主机',
                          subtitle: '主机、端口、算法与完整主机公钥',
                          onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  HostTrustPage(ledger: widget.ledger),
                            ),
                          ),
                        ),
                        const Divider(),
                        SettingRow(
                          icon: Icons.lock_outline,
                          title: '凭据保护',
                          subtitle: '设备验证、短时显示与平台限制',
                          onTap: () => showStage(
                            context,
                            '凭据保护',
                            '密码、私钥和密钥口令不进入台账数据库、导出或日志。密码查看需系统设备验证，20 秒后或离开页面即隐藏。Linux 不支持本应用的设备验证，无法查看秘密。\n\n设备认证是应用显示门禁，不代表秘密被生物识别硬件单独加密。iOS / Android 真机安全行为仍需验证。Dart 不保证内存安全擦除；当前不提供秘密复制或导出。',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const InfoNote(
                    '修改本地凭据不会修改远端密码或 authorized_keys。只有明确发起连接才会使用所选凭据。',
                  ),
                ],
              ),
      );
    },
  );
}

Future<void> credentialMenu(
  BuildContext context,
  LedgerController ledger,
  CredentialMetadata credential,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              credential.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            InfoNote(credentialKind(credential)),
            for (final item in <String, (IconData, String, String)>{
              'detail': (
                Icons.visibility_outlined,
                '查看详情',
                credential.kind == CredentialKind.privateKey
                    ? '公钥指纹与元数据，不显示私钥'
                    : '默认隐藏密码，查看需设备验证',
              ),
              'edit': (Icons.edit_outlined, '编辑凭据', '留空保留已保存的秘密'),
              'references': (Icons.link, '关联服务器', '连接用户名独立保存'),
              'delete': (Icons.delete_outline, '删除凭据', '先确认替换或解除关联影响'),
            }.entries)
              SettingRow(
                icon: item.value.$1,
                title: item.value.$2,
                subtitle: item.value.$3,
                onTap: () => Navigator.pop(context, item.key),
              ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || action == null) return;
  final page = switch (action) {
    'edit' => CredentialForm(
      ledger: ledger,
      kind: credential.kind,
      existing: credential,
    ),
    'references' => CredentialReferencesPage(
      ledger: ledger,
      credential: credential,
    ),
    'delete' => CredentialDeletePage(ledger: ledger, credential: credential),
    _ => CredentialDetailPage(ledger: ledger, credentialId: credential.id),
  };
  await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => page));
}

/// Only the user-selected file is read. No filename/path enters app metadata.
Future<String?> pickPrivateKey() async {
  final file = await openFile();
  if (file == null) return null;
  if (await file.length() > 128 * 1024) throw const FormatException();
  final bytes = await file.readAsBytes();
  if (bytes.length > 128 * 1024) throw const FormatException();
  return utf8.decode(bytes);
}

class CredentialForm extends StatefulWidget {
  const CredentialForm({
    super.key,
    required this.ledger,
    required this.kind,
    this.existing,
    this.pickKey = pickPrivateKey,
  });
  final LedgerController ledger;
  final CredentialKind kind;
  final CredentialMetadata? existing;
  final Future<String?> Function() pickKey;
  @override
  State<CredentialForm> createState() => _CredentialFormState();
}

class _CredentialFormState extends State<CredentialForm>
    with WidgetsBindingObserver {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.existing?.name);
  late final username = TextEditingController(
    text: widget.existing?.defaultUsername,
  );
  final secret = TextEditingController();
  final passphrase = TextEditingController();
  bool savePassphrase = false;
  bool dirty = false,
      saving = false,
      picking = false,
      pasting = false,
      allowPop = false;
  int generation = 0;
  SecurityController get security => widget.ledger.security;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (!picking) generation++;
      secret.clear();
      passphrase.clear();
    }
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    name.dispose();
    username.dispose();
    secret.dispose();
    passphrase.dispose();
    super.dispose();
  }

  Future<void> cancel() async {
    if (saving) return;
    final discard =
        !dirty ||
        await confirmAction(
          context,
          title: '放弃本次编辑？',
          message: '尚未保存的凭据内容会被清除。',
          action: '放弃修改',
          dangerous: true,
        );
    if (!discard || !mounted) return;
    setState(() => allowPop = true);
    Navigator.pop(context);
  }

  Future<void> import() async {
    final request = ++generation;
    setState(() => picking = true);
    try {
      final content = await widget.pickKey();
      if (!mounted || request != generation || content == null) return;
      secret.text = content;
      setState(() => dirty = true);
      securityMessage(context, '已导入待保存的私钥；保存时校验格式与口令');
    } catch (_) {
      if (mounted && request == generation) {
        securityMessage(context, '无法读取私钥文件。请选择不超过 128 KB 的 UTF-8 私钥文件。');
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> pasteKey() async {
    final request = ++generation;
    setState(() => pasting = true);
    try {
      final content = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (!mounted || request != generation || content == null) return;
      if (content.isEmpty || utf8.encode(content).length > 128 * 1024) {
        throw const FormatException();
      }
      // Assign directly: Flutter's single-line obscured input formatter would
      // otherwise remove PEM newlines from a normal keyboard/menu paste.
      secret.text = content;
      setState(() => dirty = true);
      securityMessage(context, '已粘贴待保存的私钥；内容保持隐藏，保存时校验');
    } catch (_) {
      if (mounted && request == generation) {
        securityMessage(context, '无法粘贴私钥。请复制不超过 128 KB 的完整私钥内容。');
      }
    } finally {
      if (mounted) setState(() => pasting = false);
    }
  }

  Future<void> save() async {
    if (saving || picking || pasting || !form.currentState!.validate()) return;
    setState(() => saving = true);
    final saved = await security.saveCredential(
      existing: widget.existing,
      name: name.text,
      kind: widget.kind,
      defaultUsername: username.text,
      secret: secret.text.isEmpty && widget.existing != null
          ? null
          : secret.text,
      passphrase: passphrase.text,
      savePassphrase: savePassphrase,
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (saved) {
      secret.clear();
      passphrase.clear();
      setState(() => allowPop = true);
      Navigator.pop(context);
      securityMessage(context, '凭据已保存，远端认证资料未改变');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: security,
    builder: (context, _) => PopScope(
      canPop: allowPop || (!dirty && !saving),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          cancel();
        } else {
          generation++;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.existing == null ? '新增凭据' : '编辑凭据'),
          leading: IconButton(
            tooltip: '取消编辑凭据',
            onPressed: saving ? null : cancel,
            icon: const Icon(Icons.close),
          ),
        ),
        body: Form(
          key: form,
          onChanged: () {
            if (!dirty) setState(() => dirty = true);
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              InfoNote(
                widget.kind == CredentialKind.password ? '用户名与密码' : '导入 SSH 密钥',
              ),
              SecurityNotice(controller: security),
              TextFormField(
                key: const ValueKey('credential-name'),
                controller: name,
                enabled: !saving,
                maxLength: 80,
                decoration: const InputDecoration(labelText: '凭据名称'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请填写凭据名称' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('credential-username'),
                controller: username,
                enabled: !saving,
                maxLength: 64,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: widget.kind == CredentialKind.password
                      ? '默认登录用户名'
                      : '默认用户名（可选）',
                ),
                validator: (value) =>
                    widget.kind == CredentialKind.password &&
                        (value == null || value.trim().isEmpty)
                    ? '请填写默认用户名'
                    : null,
              ),
              const SizedBox(height: 14),
              if (widget.kind == CredentialKind.privateKey) ...[
                OutlinedButton.icon(
                  onPressed: saving || picking || pasting ? null : import,
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(picking ? '选择文件中…' : '选择私钥文件'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('credential-paste-key'),
                  onPressed: saving || picking || pasting ? null : pasteKey,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('粘贴完整私钥'),
                ),
                const InfoNote(
                  '支持 OpenSSH / PEM 私钥。只读取所选文件，不保存文件路径。也可用“粘贴完整私钥”保留换行；内容始终隐藏。',
                ),
              ],
              TextFormField(
                key: const ValueKey('credential-secret'),
                controller: secret,
                enabled: !saving && !picking && !pasting,
                readOnly: widget.kind == CredentialKind.privateKey,
                enableInteractiveSelection:
                    widget.kind != CredentialKind.privateKey,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                autofillHints: const [],
                decoration: InputDecoration(
                  labelText: widget.kind == CredentialKind.password
                      ? '登录密码'
                      : '私钥内容',
                  helperText: widget.existing == null
                      ? null
                      : '留空保留已保存内容，旧秘密不会回显',
                ),
                validator: (value) =>
                    widget.existing == null && (value == null || value.isEmpty)
                    ? widget.kind == CredentialKind.password
                          ? '请填写登录密码'
                          : '请选择私钥文件或粘贴完整私钥'
                    : null,
              ),
              if (widget.kind == CredentialKind.privateKey) ...[
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('credential-passphrase'),
                  validator: (value) =>
                      widget.existing != null &&
                          secret.text.isEmpty &&
                          (value?.isNotEmpty ?? false)
                      ? '更新已保存的口令时，请同时重新导入对应私钥'
                      : null,
                  controller: passphrase,
                  enabled: !saving,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  autofillHints: const [],
                  decoration: const InputDecoration(
                    labelText: '私钥加密口令（如有）',
                    helperText: '用于解密所选私钥，不是服务器登录密码。本页不会更改私钥的加密口令',
                    helperMaxLines: 3,
                  ),
                ),
                CheckboxListTile(
                  key: const ValueKey('credential-save-passphrase'),
                  contentPadding: EdgeInsets.zero,
                  value: savePassphrase,
                  onChanged: saving
                      ? null
                      : (value) => setState(() {
                          savePassphrase = value == true;
                          dirty = true;
                        }),
                  title: const Text('在设备安全存储中保存私钥口令'),
                  subtitle: const Text(
                    '默认不保存。加密私钥未保存口令时，每次连接都需输入。取消或口令错误会停止连接。仅在导入私钥时应用此选项。',
                  ),
                ),
              ],
              const InfoNote(
                '用户名只作为新连接的候选值，不覆盖已有连接。更新凭据只影响以后登录，不修改服务器端密码或密钥。离开到后台会清空未保存秘密。',
              ),
              if (widget.existing != null) ...[
                const SectionTitle('当前关联影响'),
                for (final config in security.sshConfigurations.where(
                  (s) => s.credentialId == widget.existing!.id,
                ))
                  InfoNote(
                    '${widget.ledger.byId(config.serverId)?.name ?? '服务器'} · ${config.username} @ ${config.host}:${config.port}',
                  ),
              ],
              FilledButton(
                onPressed:
                    saving ||
                        picking ||
                        pasting ||
                        security.busy ||
                        security.needsReload
                    ? null
                    : save,
                child: Text(saving ? '保存中…' : '保存凭据'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}

class CredentialDetailPage extends StatefulWidget {
  const CredentialDetailPage({
    super.key,
    required this.ledger,
    required this.credentialId,
  });
  final LedgerController ledger;
  final String credentialId;
  @override
  State<CredentialDetailPage> createState() => _CredentialDetailPageState();
}

class _CredentialDetailPageState extends State<CredentialDetailPage>
    with WidgetsBindingObserver, RouteAware {
  bool foreground = true;
  ModalRoute<dynamic>? subscribedRoute;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != subscribedRoute) {
      securityRouteObserver.unsubscribe(this);
      subscribedRoute = route;
      if (route != null) securityRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() => security.hideSensitive();
  @override
  void didPop() => security.hideSensitive();
  SecurityController get security => widget.ledger.security;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => foreground = state == AppLifecycleState.resumed);
    if (state != AppLifecycleState.resumed) {
      security.hideSensitive(
        cancelAuthentication: state != AppLifecycleState.inactive,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    securityRouteObserver.unsubscribe(this);
    security.hideSensitive();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: security,
    builder: (context, _) {
      final c = security.credentials
          .where((c) => c.id == widget.credentialId)
          .firstOrNull;
      final revealed =
          foreground &&
          security.revealedCredentialId == c?.id &&
          security.revealedSecret != null;
      return PopScope(
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) security.hideSensitive();
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('凭据详情')),
          body: c == null
              ? const Center(child: Text('凭据已删除'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      c.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    InfoNote(
                      '${credentialKind(c)}\n默认用户名：${c.defaultUsername.isEmpty ? '由连接单独指定' : c.defaultUsername}',
                    ),
                    SecurityNotice(controller: security),
                    if (c.kind == CredentialKind.privateKey) ...[
                      const SectionTitle('公钥指纹'),
                      LedgerCard(
                        child: SelectableText(
                          '${c.keyAlgorithm ?? ''}\n${c.fingerprint ?? ''}',
                        ),
                      ),
                      const InfoNote('这里不展示或导出私钥。公钥指纹用于辨认登录密钥，与服务器主机指纹不同。'),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await Clipboard.setData(
                              ClipboardData(text: c.fingerprint ?? ''),
                            );
                            if (context.mounted) {
                              securityMessage(context, '公钥指纹已复制');
                            }
                          } catch (_) {
                            if (context.mounted) {
                              securityMessage(context, '复制未完成，请重试');
                            }
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('复制公钥指纹'),
                      ),
                    ] else ...[
                      const SectionTitle('受保护的密码'),
                      LedgerCard(
                        child: Text(
                          revealed
                              ? security.revealedSecret!
                              : '••••••••••••••••',
                          key: const ValueKey('revealed-secret'),
                        ),
                      ),
                      InfoNote(
                        revealed
                            ? '20 秒后隐藏；离开页面或转入后台立即隐藏。'
                            : '验证成功后仅短时显示。无设备认证能力时保持隐藏；Linux 暂不可查看。',
                      ),
                      FilledButton.icon(
                        onPressed: security.busy
                            ? null
                            : () {
                                if (revealed) {
                                  security.hideSensitive();
                                } else {
                                  security.reveal(c);
                                }
                              },
                        icon: Icon(
                          revealed
                              ? Icons.lock_outline
                              : Icons.visibility_outlined,
                        ),
                        label: Text(revealed ? '隐藏密码' : '设备验证后查看密码'),
                      ),
                      TextButton(
                        onPressed: () => security.hideSensitive(),
                        child: const Text('取消验证并隐藏'),
                      ),
                    ],
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: security.busy
                          ? null
                          : () async {
                              security.hideSensitive();
                              await Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CredentialForm(
                                    ledger: widget.ledger,
                                    kind: c.kind,
                                    existing: c,
                                  ),
                                ),
                              );
                            },
                      child: const Text('编辑凭据'),
                    ),
                  ],
                ),
        ),
      );
    },
  );
}

class CredentialReferencesPage extends StatelessWidget {
  const CredentialReferencesPage({
    super.key,
    required this.ledger,
    required this.credential,
  });
  final LedgerController ledger;
  final CredentialMetadata credential;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('关联服务器')),
    body: ListenableBuilder(
      listenable: ledger.security,
      builder: (context, _) {
        final configs = ledger.security.sshConfigurations
            .where((s) => s.credentialId == credential.id)
            .toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              credential.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            InfoNote('${configs.length} 台引用此凭据，包含已归档记录。连接用户名分别保存。'),
            for (final config in configs)
              LedgerCard(
                padding: EdgeInsets.zero,
                child: SettingRow(
                  icon: Icons.dns_outlined,
                  title: ledger.byId(config.serverId)?.name ?? '服务器',
                  subtitle:
                      '${config.username} @ ${config.host}:${config.port}',
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ServerDetail(controller: ledger, id: config.serverId),
                    ),
                  ),
                ),
              ),
            if (configs.isEmpty) const InfoNote('尚未关联。可在服务器详情的 SSH 配置中选择。'),
          ],
        );
      },
    ),
  );
}

class CredentialDeletePage extends StatefulWidget {
  const CredentialDeletePage({
    super.key,
    required this.ledger,
    required this.credential,
  });
  final LedgerController ledger;
  final CredentialMetadata credential;
  @override
  State<CredentialDeletePage> createState() => _CredentialDeletePageState();
}

class _CredentialDeletePageState extends State<CredentialDeletePage> {
  String? replacementId;
  bool confirmed = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger.security,
    builder: (context, _) {
      final security = widget.ledger.security;
      final references = security.sshConfigurations
          .where((s) => s.credentialId == widget.credential.id)
          .toList();
      return Scaffold(
        appBar: AppBar(title: const Text('删除凭据')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.credential.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            InfoNote('${references.length} 台服务器将受影响，包含归档记录。请核对下面的每一项。'),
            for (final s in references)
              LedgerCard(
                child: Text(
                  '${widget.ledger.byId(s.serverId)?.name ?? '服务器'}\n${s.username} @ ${s.host}:${s.port}',
                ),
              ),
            if (references.isNotEmpty) ...[
              const SectionTitle('如何处理关联'),
              DropdownButtonFormField<String>(
                initialValue: replacementId ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: '替换或解除'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('解除所有关联')),
                  for (final c in security.credentials.where(
                    (c) => c.id != widget.credential.id,
                  ))
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        '替换为 ${c.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: security.busy
                    ? null
                    : (value) => setState(() {
                        replacementId = value == '' ? null : value;
                        confirmed = false;
                      }),
              ),
            ],
            InfoNote(
              replacementId == null
                  ? '解除后服务器、用户名和付款保留，下次连接需重新选择凭据。'
                  : '仅替换凭据引用，所有服务器当前用户名保持不变。',
            ),
            const InfoNote('仅删除本机凭据，不能从本页面恢复。不修改远端密码或 authorized_keys，不取消云服务。'),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: confirmed,
              onChanged: security.busy
                  ? null
                  : (value) => setState(() => confirmed = value ?? false),
              title: const Text('我已确认关联影响，删除本地凭据'),
            ),
            SecurityNotice(controller: security),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: !confirmed || security.busy || security.needsReload
                  ? null
                  : () async {
                      final saved = await security.deleteCredential(
                        widget.credential,
                        replacementId: replacementId,
                      );
                      if (saved && context.mounted) {
                        Navigator.pop(context);
                        securityMessage(context, '本地凭据已删除，远端认证资料未改变');
                      }
                    },
              child: const Text('确认删除'),
            ),
          ],
        ),
      );
    },
  );
}
