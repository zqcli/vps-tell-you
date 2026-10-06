import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../servers/ledger_controller.dart';
import 'host_trust.dart';
import 'security_models.dart';
import 'security_pages.dart';

class HostTrustPage extends StatelessWidget {
  const HostTrustPage({super.key, required this.ledger});
  final LedgerController ledger;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ledger.security,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('已信任的主机'),
        actions: [
          IconButton(
            tooltip: '核验主机公钥',
            icon: const Icon(Icons.add),
            onPressed: ledger.security.busy || ledger.security.needsReload
                ? null
                : () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HostTrustForm(ledger: ledger),
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const InfoNote('信任绑定主机地址和端口，并记录算法及完整公钥。登录凭据与服务器主机公钥是两件事。'),
          SecurityNotice(controller: ledger.security),
          if (ledger.security.hostTrusts.isEmpty)
            const LedgerCard(
              child: InfoNote(
                '尚无已信任主机。可录入从独立可信渠道取得的主机公钥进行核验。当前不会连接服务器或获取网络指纹。',
              ),
            ),
          for (final pin in ledger.security.hostTrusts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LedgerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${pin.host}:${pin.port}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    InfoNote(
                      '${pin.algorithm}\n核验于 ${pin.verifiedAt.toLocal().toString().substring(0, 16)}',
                    ),
                    SelectableText(pin.fingerprint),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('完整主机公钥'),
                      children: [
                        SelectableText('${pin.algorithm} ${pin.publicKey}'),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: ledger.security.busy
                              ? null
                              : () => Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => HostTrustForm(
                                      ledger: ledger,
                                      existing: pin,
                                    ),
                                  ),
                                ),
                          child: const Text('重新核实主机'),
                        ),
                        TextButton(
                          onPressed: ledger.security.busy
                              ? null
                              : () async {
                                  final confirmed = await confirmAction(
                                    context,
                                    title: '移除主机信任？',
                                    message:
                                        '${pin.host}:${pin.port}\n${pin.fingerprint}\n\n下次连接必须重新核验身份。不会删除服务器或登录凭据。',
                                    action: '移除信任',
                                    dangerous: true,
                                  );
                                  if (confirmed) {
                                    await ledger.security.removeHostTrust(pin);
                                  }
                                },
                          child: const Text(
                            '移除信任',
                            style: TextStyle(color: AppColors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const InfoNote('若主机密钥变化，必须停止认证并通过独立渠道重新核实。没有“忽略并连接”入口。'),
        ],
      ),
    ),
  );
}

class HostTrustForm extends StatefulWidget {
  const HostTrustForm({
    super.key,
    required this.ledger,
    this.existing,
    this.lookup,
  });
  final Future<HostTrustRecord?> Function(String, int)? lookup;
  final LedgerController ledger;
  final HostTrustRecord? existing;
  @override
  State<HostTrustForm> createState() => _HostTrustFormState();
}

class _HostTrustFormState extends State<HostTrustForm> {
  late final host = TextEditingController(text: widget.existing?.host);
  late final port = TextEditingController(
    text: '${widget.existing?.port ?? 22}',
  );
  final publicKey = TextEditingController();
  String algorithm = 'ssh-ed25519';
  bool busy = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    algorithm = widget.existing?.algorithm ?? 'ssh-ed25519';
  }

  @override
  void dispose() {
    host.dispose();
    port.dispose();
    publicKey.dispose();
    super.dispose();
  }

  Future<void> inspect() async {
    final request = ++generation;
    setState(() => busy = true);
    try {
      final candidate = HostKeyIdentity.validated(
        host: host.text,
        port: int.tryParse(port.text) ?? 0,
        algorithm: algorithm,
        publicKey: publicKey.text,
      );
      final security = widget.ledger.security;
      final previous = await (widget.lookup ?? security.store.hostTrust)(
        candidate.host,
        candidate.port,
      );
      if (!mounted || request != generation) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => HostVerificationPage(
            ledger: widget.ledger,
            identity: candidate,
            previous: previous,
          ),
        ),
      );
    } catch (error) {
      if (mounted && request == generation) {
        securityMessage(
          context,
          error is SecurityFailure ? error.message : '无法读取主机信任资料，请重试',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, result) {
      if (didPop) generation++;
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('核验主机公钥')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const InfoNote(
            '输入从厂商控制台或管理员等独立可信渠道取得的主机公钥。本页面不会向服务器发请求，也不会展示模拟网络结果。',
          ),
          TextField(
            key: const ValueKey('trust-host'),
            controller: host,
            enabled: !busy && widget.existing == null,
            autocorrect: false,
            decoration: const InputDecoration(labelText: '主机地址'),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('trust-port'),
            controller: port,
            enabled: !busy && widget.existing == null,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '端口'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: algorithm,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '主机公钥类型'),
            items: [
              for (final type in [
                'ssh-ed25519',
                'ssh-rsa',
                'ecdsa-sha2-nistp256',
                'ecdsa-sha2-nistp384',
                'ecdsa-sha2-nistp521',
              ])
                DropdownMenuItem(value: type, child: Text(type)),
            ],
            onChanged: busy
                ? null
                : (value) => setState(() => algorithm = value!),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('trust-public-key'),
            controller: publicKey,
            enabled: !busy,
            maxLines: 5,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: '完整主机公钥',
              helperText: '公钥行或完整 Base64；不是私钥，也不只是指纹',
              helperMaxLines: 3,
            ),
          ),
          const InfoNote(
            'rsa-sha2-256 / rsa-sha2-512 是签名算法，其 RSA 公钥类型选择 ssh-rsa。只支持结构完整的受支持主机公钥。',
          ),
          FilledButton(
            onPressed: busy ? null : inspect,
            child: Text(busy ? '校验中…' : '检查并核对指纹'),
          ),
        ],
      ),
    ),
  );
}

class HostVerificationPage extends StatefulWidget {
  const HostVerificationPage({
    super.key,
    required this.ledger,
    required this.identity,
    this.previous,
  });
  final LedgerController ledger;
  final HostKeyIdentity identity;
  final HostTrustRecord? previous;
  @override
  State<HostVerificationPage> createState() => _HostVerificationPageState();
}

class _HostVerificationPageState extends State<HostVerificationPage> {
  bool verified = false, reverifying = false, saving = false;
  bool get changed =>
      widget.previous != null &&
      (widget.previous!.algorithm != widget.identity.algorithm ||
          widget.previous!.publicKey != widget.identity.publicKey);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger.security,
    builder: (context, _) => PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: saving ? null : () => Navigator.maybePop(context),
          ),
          title: Text(
            changed
                ? '主机密钥已变化'
                : widget.previous == null
                ? '首次主机核验'
                : '重新核实主机',
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            LedgerBadge(
              changed ? '已阻断认证 · 必须独立重新核实' : '发送任何登录凭据前先核实身份',
              danger: changed,
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.identity.host}:${widget.identity.port}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (widget.previous != null) ...[
              const SectionTitle('已保存的主机指纹'),
              LedgerCard(
                child: SelectableText(
                  '${widget.previous!.algorithm}\n${widget.previous!.fingerprint}',
                ),
              ),
            ],
            const SectionTitle('待核验的主机指纹'),
            LedgerCard(
              child: SelectableText(
                '${widget.identity.algorithm}\n${widget.identity.fingerprint}',
              ),
            ),
            const SectionTitle('完整主机公钥'),
            LedgerCard(
              child: SelectableText(
                '${widget.identity.algorithm} ${widget.identity.publicKey}',
              ),
            ),
            const InfoNote(
              '请通过独立渠道核对完整指纹和目标地址。变化可能来自重装，也可能是错误主机或中间人攻击。无法确认时应拒绝。',
            ),
            if (changed && !reverifying)
              OutlinedButton(
                onPressed: () => setState(() {
                  reverifying = true;
                  verified = false;
                }),
                child: const Text('开始独立重新核实'),
              ),
            if (!changed || reverifying) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: verified,
                onChanged: saving
                    ? null
                    : (value) => setState(() => verified = value ?? false),
                title: const Text('我已通过独立渠道核对主机、端口和完整指纹'),
              ),
              FilledButton(
                onPressed:
                    !verified ||
                        saving ||
                        widget.ledger.security.busy ||
                        widget.ledger.security.needsReload
                    ? null
                    : () async {
                        setState(() => saving = true);
                        final saved = await widget.ledger.security.verifyHost(
                          widget.identity,
                          expected: widget.previous,
                        );
                        if (!mounted) return;
                        setState(() => saving = false);
                        if (saved && context.mounted) {
                          Navigator.pop(context);
                          securityMessage(context, '主机信任已保存；没有发起连接或认证');
                        }
                      },
                child: Text(changed ? '重新核实并替换信任' : '保存已核验的主机信任'),
              ),
            ],
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('拒绝并返回'),
            ),
            if (saving) const InfoNote('正在保存已确认的信任。完成前暂时不能返回。'),
            SecurityNotice(controller: widget.ledger.security),
            const InfoNote('只记录本机信任，当前不会连接服务器。拒绝、取消和返回均不保存，也不发送认证资料。'),
          ],
        ),
      ),
    ),
  );
}
