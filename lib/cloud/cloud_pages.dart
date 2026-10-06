import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../servers/ledger_controller.dart';
import '../servers/server_detail.dart';
import 'cloud_controller.dart';
import 'cloud_models.dart';
import 'cloud_widgets.dart';

Future<void> _reloadLedger(LedgerController ledger) =>
    ledger.refreshAfterCloudCommit();

void _cloudMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

class CloudAccountsPage extends StatefulWidget {
  const CloudAccountsPage({super.key, required this.ledger});
  final LedgerController ledger;
  @override
  State<CloudAccountsPage> createState() => _CloudAccountsPageState();
}

class _CloudAccountsPageState extends State<CloudAccountsPage> {
  CloudController get cloud => widget.ledger.cloud;
  bool opening = false;
  @override
  void initState() {
    super.initState();
    unawaited(cloud.initialize());
  }

  Future<void> add() async {
    if (opening) return;
    opening = true;
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CloudTemplatesPage(ledger: widget.ledger),
        ),
      );
    } finally {
      opening = false;
    }
  }

  Future<void> menu(CloudAccount account) async {
    if (opening) return;
    opening = true;
    try {
      await cloudAccountMenu(context, widget.ledger, account);
    } finally {
      opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: cloud,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('云账户'),
        actions: [
          IconButton(
            tooltip: '添加云账户',
            onPressed: cloud.busy || cloud.needsReload ? null : add,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const LedgerBadge('SolusVM 1 / 2 · 面板读取'),
          const SizedBox(height: 16),
          const Text(
            '你的云，统一整理',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const InfoNote('每个连接独立管理授权与实例。\n同一面板可以添加多个独立账户或 VPS 连接。'),
          if (cloud.needsReload) ...[
            const CloudNotice('云账户资料读取未完成，请重读后继续。', error: true),
            OutlinedButton(
              onPressed: cloud.busy ? null : cloud.reload,
              child: const Text('重读云账户资料'),
            ),
          ] else if (cloud.error != null)
            CloudNotice(cloud.error!, error: true),
          if (cloud.cleanupPending) ...[
            const CloudNotice(
              '待清理的旧授权仍可能留在设备安全存储中。请重试清理；远端授权需到面板撤销。',
              error: true,
            ),
            OutlinedButton(
              onPressed: cloud.busy ? null : cloud.retryCleanup,
              child: const Text('重试清理旧授权'),
            ),
          ],
          if (cloud.accounts.isEmpty && !cloud.needsReload)
            LedgerCard(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  const Icon(
                    Icons.cloud_outlined,
                    size: 44,
                    color: AppColors.blue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '添加第一个云账户',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const InfoNote('从内置模板开始，验证面板授权后，再选择要加入台账的实例。'),
                  FilledButton.icon(
                    onPressed: cloud.busy ? null : add,
                    icon: const Icon(Icons.add),
                    label: const Text('选择接入模板'),
                  ),
                ],
              ),
            ),
          for (final account in cloud.accounts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LedgerCard(
                padding: EdgeInsets.zero,
                child: InkWell(
                  key: ValueKey('cloud-account-${account.id}'),
                  onTap: () => menu(account),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.cloud_outlined, color: AppColors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.alias,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                '${cloudProviderName(account.provider)} · ${cloud.bindings.where((b) => b.accountId == account.id).length} 台关联',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                account.endpoint,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              LedgerBadge(
                                cloudAccountStatus(account),
                                warning: account.lastFailure != null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.more_vert, color: AppColors.muted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (cloud.accounts.isNotEmpty)
            OutlinedButton.icon(
              onPressed: cloud.busy || cloud.needsReload ? null : add,
              icon: const Icon(Icons.add),
              label: const Text('添加云账户'),
            ),
          const InfoNote(
            '本 App 仅使用读取能力，不代表 Token 本身只有读取权限。\n云账户授权与 SSH 凭据分开管理。解除关联保留台账、费用、付款与 SSH。',
          ),
        ],
      ),
    ),
  );
}

class CloudTemplatesPage extends StatefulWidget {
  const CloudTemplatesPage({super.key, required this.ledger});
  final LedgerController ledger;
  @override
  State<CloudTemplatesPage> createState() => _CloudTemplatesPageState();
}

class _CloudTemplatesPageState extends State<CloudTemplatesPage> {
  bool opening = false;
  Future<void> choose(BuildContext context, CloudProvider provider) async {
    if (opening) return;
    opening = true;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CloudAuthorizationPage(ledger: widget.ledger, provider: provider),
      ),
    );
    opening = false;
    if (saved == true && context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('添加云账户')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const CloudSteps(1),
        const Text(
          '选择接入模板',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
        ),
        const InfoNote('按面板版本选择授权方式。面板软件不等于销售厂商，真实服务商和费用可稍后补充。'),
        for (final provider in CloudProvider.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: LedgerCard(
              padding: EdgeInsets.zero,
              child: SettingRow(
                icon: Icons.cloud_outlined,
                title: cloudProviderName(provider),
                subtitle: provider == CloudProvider.solusVm1
                    ? 'Client API Key + Hash\n每组凭据只对应单台 VPS'
                    : '用户 API Token\n读取当前用户的项目与实例',
                onTap: () => choose(context, provider),
              ),
            ),
          ),
        const InfoNote('首期支持这两个内置模板。不提供 API 电源控制，也不会修改云资源或厂商扣费。'),
      ],
    ),
  );
}

class CloudAuthorizationPage extends StatefulWidget {
  const CloudAuthorizationPage({
    super.key,
    required this.ledger,
    required this.provider,
    this.existing,
  });
  final LedgerController ledger;
  final CloudProvider provider;
  final CloudAccount? existing;
  @override
  State<CloudAuthorizationPage> createState() => _CloudAuthorizationPageState();
}

class _CloudAuthorizationPageState extends State<CloudAuthorizationPage>
    with WidgetsBindingObserver {
  final form = GlobalKey<FormState>();
  late final alias = TextEditingController(
    text:
        widget.existing?.alias ?? '我的 ${cloudProviderName(widget.provider)} 面板',
  );
  late final endpoint = TextEditingController(
    text: widget.existing?.endpoint ?? '',
  );
  final keyField = TextEditingController();
  final hashField = TextEditingController();
  final token = TextEditingController();
  CloudController get cloud => widget.ledger.cloud;
  bool get v1 => widget.provider == CloudProvider.solusVm1;
  bool reading = false, navigating = false;
  int serial = 0;
  String? error;
  CloudEndpoint? get parsedEndpoint {
    try {
      return CloudEndpoint.parse(endpoint.text, allowSolusVm1ConsolePath: v1);
    } on CloudFailure {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void clearSecrets() {
    keyField.clear();
    hashField.clear();
    token.clear();
  }

  void cancel({bool update = true}) {
    serial++;
    cloud.cancelVerification();
    clearSecrets();
    if (mounted && update) {
      setState(() {
        reading = false;
        error = '验证已取消，未保存授权';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (!navigating) cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!navigating) cloud.cancelVerification(notify: false);
    serial++;
    clearSecrets();
    alias.dispose();
    endpoint.dispose();
    keyField.dispose();
    hashField.dispose();
    token.dispose();
    super.dispose();
  }

  Future<void> verify() async {
    if (reading || navigating || !form.currentState!.validate()) return;
    // Long forms lazily unmount offscreen fields. Validate the local alias
    // independently before any network request, not only via FormState.
    if (alias.text.trim().isEmpty || alias.text.trim().length > 80) {
      setState(() => error = '账户别名需为 1–80 个字符');
      return;
    }
    final request = ++serial;
    FocusScope.of(context).unfocus();
    setState(() {
      reading = true;
      error = null;
    });
    CloudVerification? verified;
    try {
      final credentials = v1
          ? SolusVm1Credentials(key: keyField.text, hash: hashField.text)
          : SolusVm2Credentials(token.text);
      verified = await cloud.verifyConnection(
        provider: widget.provider,
        endpoint: endpoint.text,
        credentials: credentials,
        existing: widget.existing,
      );
    } on CloudFailure catch (failure) {
      error = failure.message;
    } catch (_) {
      error = '验证未完成，请检查面板地址、凭据和网络后重试';
    } finally {
      if (mounted && request == serial) clearSecrets();
    }
    if (!mounted || request != serial) return;
    setState(() {
      reading = false;
      error ??= verified == null ? cloud.error ?? '验证未完成，未保存授权' : null;
    });
    if (verified == null) return;
    navigating = true;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CloudImportPage(
          ledger: widget.ledger,
          verification: verified!,
          alias: alias.text.trim(),
        ),
      ),
    );
    navigating = false;
    cloud.cancelVerification();
    if (!mounted) return;
    if (saved == true) {
      Navigator.pop(context, true);
    } else {
      setState(() => error = '未保存授权。需要重新验证后再导入。');
    }
  }

  Widget secretField(
    TextEditingController controller,
    String label,
    String fieldKey,
  ) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: TextFormField(
      key: ValueKey(fieldKey),
      controller: controller,
      enabled: !reading && !kIsWeb,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      keyboardType: TextInputType.visiblePassword,
      decoration: InputDecoration(labelText: label),
      validator: (value) =>
          value == null || value.isEmpty ? '请填写 $label' : null,
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) cancel(update: false);
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? '连接 ${cloudProviderName(widget.provider)}'
              : '重新授权',
        ),
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const CloudSteps(2),
            LedgerCard(
              child: Text(
                '${cloudProviderName(widget.provider)} · ${v1 ? '单台 VPS / Client API' : '用户账户 / API Token'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (kIsWeb)
              const CloudNotice('Web 预览不接受真实 API 凭据，请在原生应用中连接。', error: true),
            const SizedBox(height: 20),
            TextFormField(
              key: const ValueKey('cloud-alias'),
              controller: alias,
              enabled: !reading,
              maxLength: 80,
              decoration: const InputDecoration(labelText: '账户别名'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请填写账户别名' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('cloud-endpoint'),
              controller: endpoint,
              enabled: !reading,
              readOnly: widget.existing != null,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'HTTPS 面板地址',
                hintText: v1
                    ? 'https://panel.example.com:5656'
                    : 'https://panel.example.com',
              ),
              onChanged: (_) => setState(() => error = null),
              validator: (_) => parsedEndpoint == null
                  ? '请输入 HTTPS 面板首页地址，不含凭据、参数或 API 路径'
                  : null,
            ),
            const InfoNote('使用面板首页 HTTPS 地址，可以保留服务商指定端口。不会忽略证书错误或跟随重定向。'),
            if (parsedEndpoint case final target?)
              CloudNotice(
                '${target.normalizedConsolePath ? '已移除 /home.php。\n' : ''}验证将连接：${target.origin}',
              ),
            if (widget.existing != null)
              const InfoNote('面板地址与连接身份绑定。不同面板请另建连接，旧授权不会显示在此处。'),
            if (v1) ...[
              secretField(keyField, 'API Key', 'cloud-key'),
              secretField(hashField, 'API Hash', 'cloud-hash'),
              const InfoNote(
                '填写该 VPS 的 Client API Key / Hash。不是管理员 API 凭据或登录密码；需服务商开放 Client API。每组凭据只读取单台 VPS 的状态。',
              ),
            ] else ...[
              secretField(token, 'API Token', 'cloud-token'),
              const InfoNote(
                '使用 SolusVM 2 用户区 Account → API Tokens 的 Token。不要使用管理员 Token；可读取范围取决于服务商设置。',
              ),
            ],
            if (v1 && widget.existing != null)
              const CloudNotice(
                '此 API 无法证明新凭据仍属于原 VPS。验证后，必须明确确认解除旧关联，再决定是否导入新记录。旧台账、费用和 SSH 会保留。',
                error: true,
              ),
            if (!v1 && widget.existing != null)
              const InfoNote('重新授权必须验证为同一远端用户账户，否则保留原授权与关联。'),
            const CloudNotice(
              '本 App 仅使用读取能力，不代表凭据本身只有读取权限。验证会读取状态或项目与实例；只有下一步保存后，授权才进入设备安全存储。',
            ),
            if (error != null) CloudNotice(error!, error: true),
            if (reading) ...[
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
              const InfoNote('正在验证并读取完整列表。请求有超时限制；返回或取消会停止本次读取。'),
              OutlinedButton(
                key: const ValueKey('cancel-cloud-verify'),
                onPressed: cancel,
                child: const Text('取消验证'),
              ),
            ] else
              FilledButton.icon(
                key: const ValueKey('verify-cloud'),
                onPressed: kIsWeb ? null : verify,
                icon: const Icon(Icons.link),
                label: const Text('验证并读取'),
              ),
            const InfoNote('凭据输入在验证后或离开时清空，不写入台账、日志或导出。Dart 不保证内存安全擦除。'),
          ],
        ),
      ),
    ),
  );
}

class CloudImportPage extends StatefulWidget {
  const CloudImportPage({
    super.key,
    required this.ledger,
    this.verification,
    this.inventory,
    this.alias,
  }) : assert((verification == null) != (inventory == null));
  final LedgerController ledger;
  final CloudVerification? verification;
  final CloudInventory? inventory;
  final String? alias;
  @override
  State<CloudImportPage> createState() => _CloudImportPageState();
}

class _CloudImportPageState extends State<CloudImportPage>
    with WidgetsBindingObserver {
  CloudController get cloud => widget.ledger.cloud;
  CloudSnapshot get snapshot =>
      widget.verification?.snapshot ?? widget.inventory!.snapshot;
  CloudAccount? get account =>
      widget.verification?.existingAccount ?? widget.inventory?.account;
  bool get v1 => snapshot.provider == CloudProvider.solusVm1;
  bool get rebind => v1 && widget.verification?.existingAccount != null;
  final selected = <String>{};
  final displayName = TextEditingController();
  bool saving = false,
      confirmRebind = false,
      committed = false,
      expired = false;
  String? error;
  String keyFor(CloudInstance instance) =>
      widget.verification?.keyFor(instance) ??
      widget.inventory!.keyFor(instance);
  CloudBinding? linked(CloudInstance instance) => rebind
      ? null
      : cloud.bindings
            .where(
              (b) =>
                  b.accountId == account?.id &&
                  b.instanceKey == keyFor(instance),
            )
            .firstOrNull;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.verification != null &&
        !committed &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      cloud.cancelVerification();
      setState(() {
        expired = true;
        error = '离开应用后已清除本次授权，请返回重新验证。尚未提交的保存已取消。';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.verification != null && !committed) {
      cloud.cancelVerification(notify: false);
    }
    displayName.dispose();
    super.dispose();
  }

  Future<void> save({bool accountOnly = false}) async {
    if (saving || expired || (rebind && !confirmRebind)) return;
    if (!accountOnly && selected.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      error = null;
    });
    final name = displayName.text.trim();
    final picked = accountOnly ? <String>{} : Set<String>.of(selected);
    final ok = widget.verification != null
        ? await cloud.saveAccount(
            widget.verification!,
            alias: widget.alias!,
            selectedInstanceKeys: picked,
            confirmV1Rebind: confirmRebind,
            v1DisplayName: name.isEmpty ? null : name,
          )
        : await cloud.importInstances(
            widget.inventory!,
            selectedInstanceKeys: picked,
            v1DisplayName: name.isEmpty ? null : name,
          );
    if (ok) {
      committed = true;
      await _reloadLedger(widget.ledger);
    }
    if (!mounted) return;
    setState(() {
      saving = false;
      error = ok ? null : cloud.error ?? '保存未完成，请重试';
    });
    if (ok) {
      _cloudMessage(
        context,
        picked.isEmpty ? '账户授权已保存，未导入新实例' : '已保存，所选实例已加入本地台账',
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('选择导入实例')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CloudSteps(3),
          CloudNotice(
            '完整读取已完成 · ${snapshot.instances.length} 台\n观测于 ${cloudTime(snapshot.completedAt)}${widget.verification != null ? '\n尚未保存这次授权' : ''}',
          ),
          Text(
            widget.alias ?? account!.alias,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
          ),
          SelectableText(
            widget.verification?.endpoint.toString() ?? account!.endpoint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          if (snapshot.instances.isEmpty)
            LedgerCard(
              child: Text(
                widget.verification != null
                    ? '当前授权下没有可导入的实例。可仅保存账户，稍后继续导入。'
                    : '本次完整列表没有返回可导入的实例。账户已保存，可稍后重新读取。',
              ),
            ),
          for (final instance in snapshot.instances)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LedgerCard(
                padding: EdgeInsets.zero,
                child: CheckboxListTile(
                  key: ValueKey('cloud-select-${keyFor(instance)}'),
                  value:
                      linked(instance) != null ||
                      selected.contains(keyFor(instance)),
                  onChanged: saving || expired || linked(instance) != null
                      ? null
                      : (checked) => setState(() {
                          if (checked == true) {
                            selected.add(keyFor(instance));
                          } else {
                            selected.remove(keyFor(instance));
                          }
                        }),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  title: Text(
                    v1
                        ? '该凭据对应的单台 VPS'
                        : instance.name ?? '实例 ${instance.serverId}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (linked(instance) != null)
                        const LedgerBadge('已关联 · 跳过重复导入'),
                      if (!v1)
                        Text(
                          '项目 ${instance.projectName ?? instance.projectId} · 实例 ID ${instance.serverId}',
                        ),
                      Text(
                        v1
                            ? '无稳定实例 ID · IP 与规格未知'
                            : [
                                instance.ipv4,
                                instance.ipv6,
                              ].whereType<String>().join(' / ').isEmpty
                            ? 'IP 未提供'
                            : [
                                instance.ipv4,
                                instance.ipv6,
                              ].whereType<String>().join(' / '),
                      ),
                      Text('电源${cloudPowerLabel(instance.power)} · 缓存观测'),
                    ],
                  ),
                ),
              ),
            ),
          if (v1) ...[
            const SizedBox(height: 6),
            TextField(
              key: const ValueKey('cloud-v1-name'),
              controller: displayName,
              enabled: !saving && !expired,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: '本地显示名称（可选）',
                helperText: '仅用于新台账，不作为实例身份',
              ),
            ),
            const InfoNote(
              'SolusVM 1 仅能确认该凭据可读取单台 VPS 状态，不能获得可靠 IP、规格或稳定实例身份。可在导入后手动补充。',
            ),
          ],
          if (rebind) ...[
            const CloudNotice(
              '保存新授权将解除此连接的所有旧实例关联。旧记录、费用、付款和 SSH 原样保留；选择导入会新增本地记录，不自动覆盖或重连旧记录。',
              error: true,
            ),
            CheckboxListTile(
              key: const ValueKey('cloud-confirm-rebind'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: confirmRebind,
              onChanged: saving || expired
                  ? null
                  : (value) => setState(() => confirmRebind = value ?? false),
              title: const Text('我确认解除旧关联，并按本次选择重新绑定'),
            ),
          ],
          const InfoNote(
            '导入不会覆盖已有本地名称、费用、付款、备注或 SSH 配置。去重依据独立连接与远端 ID，不按 IP 或名称合并。已归档的关联也不会重复导入。',
          ),
          if (error != null) CloudNotice(error!, error: true),
          FilledButton.icon(
            key: const ValueKey('cloud-import-submit'),
            onPressed:
                saving ||
                    expired ||
                    selected.isEmpty ||
                    (rebind && !confirmRebind)
                ? null
                : save,
            icon: const Icon(Icons.download_outlined),
            label: Text(
              saving
                  ? '正在保存…'
                  : '${widget.verification == null ? '导入' : '保存账户并导入'} ${selected.length} 台',
            ),
          ),
          if (widget.verification != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              key: const ValueKey('cloud-save-only'),
              onPressed: saving || expired || (rebind && !confirmRebind)
                  ? null
                  : () => save(accountOnly: true),
              child: Text(
                widget.verification!.existingAccount == null
                    ? '仅保存账户'
                    : '仅更新授权',
              ),
            ),
          ],
          if (expired && !saving)
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('返回重新验证'),
            ),
          if (saving) const InfoNote('正在提交到本机，请等待完成后再返回。'),
        ],
      ),
    ),
  );
}

/// Owns one cancellable saved-account read. Leaving cannot open a late result.
class CloudReadPage extends StatefulWidget {
  const CloudReadPage({
    super.key,
    required this.ledger,
    required this.account,
    required this.importAfterRead,
  });
  final LedgerController ledger;
  final CloudAccount account;
  final bool importAfterRead;
  @override
  State<CloudReadPage> createState() => _CloudReadPageState();
}

class _CloudReadPageState extends State<CloudReadPage>
    with WidgetsBindingObserver {
  CloudController get cloud => widget.ledger.cloud;
  bool reading = true;
  CloudInventory? result;
  String? error;
  int serial = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initialSerial = serial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && serial == initialSerial) unawaited(read());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (reading &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    serial++;
    cloud.cancelAccount(widget.account.id, notify: false);
    super.dispose();
  }

  void cancel({bool update = true}) {
    serial++;
    cloud.cancelAccount(widget.account.id);
    if (update && mounted) {
      setState(() {
        reading = false;
        error = '读取已取消，原有观测保留';
      });
    }
  }

  Future<void> read() async {
    final request = ++serial;
    setState(() {
      reading = true;
      error = null;
    });
    final current = cloud.accounts
        .where((a) => a.id == widget.account.id)
        .firstOrNull;
    if (current == null) {
      setState(() {
        reading = false;
        error = '账户关联已解除，请返回';
      });
      return;
    }
    final inventory = await cloud.refreshAccount(current);
    if (!mounted || request != serial) return;
    setState(() {
      reading = false;
      result = inventory;
      error = inventory == null ? cloud.error ?? '读取未完成，原有观测保留' : null;
    });
    if (inventory != null && widget.importAfterRead) {
      final imported = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CloudImportPage(ledger: widget.ledger, inventory: inventory),
        ),
      );
      if (mounted) Navigator.pop(context, imported);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) cancel(update: false);
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.importAfterRead ? '读取可导入实例' : '刷新账户状态'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.account.alias,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
          ),
          SelectableText(widget.account.endpoint),
          if (reading) ...[
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            ),
            const InfoNote('正在读取完整列表与状态，有超时限制。取消或返回会停止本次读取，不改变台账、费用或 SSH。'),
            OutlinedButton(onPressed: cancel, child: const Text('取消读取')),
          ],
          if (error != null) ...[
            CloudNotice(error!, error: true),
            OutlinedButton(onPressed: read, child: const Text('重新读取')),
          ],
          if (result != null && !reading && error == null) ...[
            CloudNotice(
              '完整读取已完成 · ${result!.snapshot.instances.length} 台\n观测于 ${cloudTime(result!.snapshot.completedAt)}',
            ),
            const InfoNote('只更新此账户的 API 观测。本地资料、费用、付款与 SSH 没有被覆盖。'),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ],
        ],
      ),
    ),
  );
}

Future<void> cloudAccountMenu(
  BuildContext context,
  LedgerController ledger,
  CloudAccount account,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account.alias,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            InfoNote(
              '${cloudProviderName(account.provider)} · ${account.endpoint}',
            ),
            for (final row in const <(String, IconData, String)>[
              ('detail', Icons.info_outline, '查看账户详情'),
              ('rename', Icons.edit_outlined, '编辑账户名称'),
              ('reauthorize', Icons.key_outlined, '重新授权'),
              ('import', Icons.download_outlined, '继续导入实例'),
              ('servers', Icons.dns_outlined, '关联服务器'),
              ('refresh', Icons.refresh, '刷新账户状态'),
              ('unbind', Icons.link_off, '解除账户关联'),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  row.$2,
                  color: row.$1 == 'unbind' ? AppColors.red : AppColors.blue,
                ),
                title: Text(row.$3),
                onTap: () => Navigator.pop(context, row.$1),
              ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || action == null) return;
  final cloud = ledger.cloud;
  final current = cloud.accounts.where((a) => a.id == account.id).firstOrNull;
  if (current == null) return;
  if (action == 'detail' || action == 'servers') {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CloudAccountDetailsPage(
          ledger: ledger,
          accountId: current.id,
          associationsOnly: action == 'servers',
        ),
      ),
    );
  } else if (action == 'reauthorize') {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CloudAuthorizationPage(
          ledger: ledger,
          provider: current.provider,
          existing: current,
        ),
      ),
    );
  } else if (action == 'rename') {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _CloudRenameDialog(alias: current.alias),
    );
    if (name == null) return;
    final ok = await cloud.renameAccount(current, name);
    if (context.mounted) {
      _cloudMessage(context, ok ? '账户别名已保存' : cloud.error ?? '名称未保存，请重试');
    }
  } else if (action == 'import' || action == 'refresh') {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CloudReadPage(
          ledger: ledger,
          account: current,
          importAfterRead: action == 'import',
        ),
      ),
    );
  } else if (action == 'unbind') {
    final ok = await confirmAction(
      context,
      title: '解除云账户关联？',
      message:
          '${current.alias}\n\n仅解除此连接，保留服务器、费用、付款与 SSH 配置。不会销毁云资源或停止扣费。\n\n${current.provider == CloudProvider.solusVm1 ? '还需到面板禁用该 VPS 的 Client API 或重置 Key / Hash。' : '还需到面板撤销已签发的 Token。'}',
      action: '解除本地关联',
      dangerous: true,
    );
    if (!ok) return;
    final saved = await cloud.unbindAccount(current);
    if (saved) await _reloadLedger(ledger);
    if (context.mounted) {
      _cloudMessage(
        context,
        saved ? '已解除关联，台账、费用与 SSH 保留' : cloud.error ?? '解除关联未完成，请重试',
      );
    }
  }
}

class CloudAccountDetailsPage extends StatelessWidget {
  const CloudAccountDetailsPage({
    super.key,
    required this.ledger,
    required this.accountId,
    this.associationsOnly = false,
  });
  final LedgerController ledger;
  final String accountId;
  final bool associationsOnly;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ledger.cloud,
    builder: (context, _) {
      final account = ledger.cloud.accounts
          .where((a) => a.id == accountId)
          .firstOrNull;
      final bindings = ledger.cloud.bindings
          .where((b) => b.accountId == accountId)
          .toList();
      return Scaffold(
        appBar: AppBar(title: Text(associationsOnly ? '关联服务器' : '云账户详情')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (account == null)
              const CloudNotice('账户已解除关联，原有台账仍保留。')
            else ...[
              Text(
                account.alias,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!associationsOnly) ...[
                const SizedBox(height: 18),
                LedgerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CloudValue('接入模板', cloudProviderName(account.provider)),
                      CloudValue('面板地址', account.endpoint),
                      CloudValue('连接状态', cloudAccountStatus(account)),
                      CloudValue(
                        '最近读取尝试',
                        account.lastAttemptAt == null
                            ? '尚无记录'
                            : cloudTime(account.lastAttemptAt!),
                      ),
                      CloudValue(
                        '授权范围',
                        account.provider == CloudProvider.solusVm1
                            ? '单台 VPS · Client API，无稳定实例身份'
                            : '已验证用户账户 ${account.remoteAccountId} · 项目与实例',
                      ),
                      const CloudValue('App 能力', '仅使用读取能力；无 API 电源控制'),
                      const CloudValue('授权存储', '设备安全存储；不显示或导出秘密'),
                    ],
                  ),
                ),
                const InfoNote(
                  'Token 本身可能拥有更多权限，请在服务商面板核对。没有后台持续监控，读取结果只代表观测时刻。',
                ),
              ],
              SectionTitle('已关联 ${bindings.length} 台'),
              if (bindings.isEmpty)
                const LedgerCard(child: Text('暂无关联实例，可从账户菜单继续导入。')),
              for (final binding in bindings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: LedgerCard(
                    padding: EdgeInsets.zero,
                    child: SettingRow(
                      icon: Icons.dns_outlined,
                      title:
                          '${ledger.byId(binding.serverId)?.name ?? '本地记录'}${ledger.byId(binding.serverId)?.archived == true ? ' · 已归档' : ''}',
                      subtitle:
                          '${cloudBindingSummary(binding)}\n观测于 ${cloudTime(binding.observedAt)}',
                      onTap: ledger.byId(binding.serverId) == null
                          ? null
                          : () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ServerDetail(
                                  controller: ledger,
                                  id: binding.serverId,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

class _CloudRenameDialog extends StatefulWidget {
  const _CloudRenameDialog({required this.alias});
  final String alias;
  @override
  State<_CloudRenameDialog> createState() => _CloudRenameDialogState();
}

class _CloudRenameDialogState extends State<_CloudRenameDialog> {
  late final field = TextEditingController(text: widget.alias);
  String? error;
  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('编辑账户名称'),
    content: TextField(
      key: const ValueKey('cloud-rename'),
      controller: field,
      maxLength: 80,
      autofocus: true,
      decoration: InputDecoration(labelText: '账户别名', errorText: error),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          final value = field.text.trim();
          if (value.isEmpty || value.length > 80) {
            setState(() => error = '请输入 1–80 字的账户别名');
            return;
          }
          Navigator.pop(context, value);
        },
        child: const Text('保存名称'),
      ),
    ],
  );
}
