import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'cloud_account.dart';
import 'cloud_models.dart';

String cloudProviderName(CloudProvider provider) => switch (provider) {
  CloudProvider.solusVm1 => 'SolusVM 1',
  CloudProvider.solusVm2 => 'SolusVM 2',
};

String cloudPowerLabel(CloudPower power) => switch (power) {
  CloudPower.running => '运行中',
  CloudPower.stopped => '已停止',
  CloudPower.unknown => '未知',
};

String cloudTime(DateTime time) => time.toLocal().toString().substring(0, 16);

String cloudBindingSummary(CloudBinding binding) {
  final freshness = binding.missing
      ? '本次未返回 · 旧观测'
      : binding.stale
      ? '读取失败 · 旧观测'
      : '缓存观测';
  return '$freshness · 电源${cloudPowerLabel(binding.power)}';
}

String cloudAccountStatus(CloudAccount account) =>
    account.lastFailure == CloudFailureKind.unauthorized
    ? '授权失效 · 原台账保留'
    : account.lastFailure != null
    ? '读取失败 · 保留上次观测'
    : '已验证 · 手动读取';

class CloudSteps extends StatelessWidget {
  const CloudSteps(this.step, {super.key});
  final int step;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (var i = 0; i < 3; i++)
          Text(
            '0${i + 1} ${['选模板', '填授权', '选实例'][i]}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: i + 1 == step ? FontWeight.w700 : FontWeight.normal,
              color: i + 1 == step ? AppColors.blue : AppColors.muted,
            ),
          ),
      ],
    ),
  );
}

class CloudNotice extends StatelessWidget {
  const CloudNotice(this.message, {super.key, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: error ? AppColors.amberBackground : AppColors.soft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: TextStyle(
            fontSize: 12,
            color: error ? AppColors.amber : AppColors.ink,
          ),
        ),
      ),
    ),
  );
}

class CloudValue extends StatelessWidget {
  const CloudValue(this.label, this.value, {super.key});
  final String label;
  final String? value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 3),
        SelectableText(
          value == null || value!.isEmpty ? '未知（API 未提供）' : value!,
        ),
      ],
    ),
  );
}

/// API observations never become editable local fields or a live-health claim.
class CloudObservationCard extends StatelessWidget {
  const CloudObservationCard({
    super.key,
    required this.binding,
    required this.account,
  });
  final CloudBinding binding;
  final CloudAccount? account;
  @override
  Widget build(BuildContext context) {
    final observation = binding.observation;
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              LedgerBadge(
                cloudBindingSummary(binding),
                warning: binding.stale || binding.missing,
              ),
              if (observation.suspended == true)
                const LedgerBadge('面板标记暂停', warning: true),
            ],
          ),
          CloudValue(
            '来源',
            account == null
                ? '云账户暂不可用'
                : '${account!.alias} · ${cloudProviderName(account!.provider)}',
          ),
          CloudValue('观测时间', cloudTime(binding.observedAt)),
          if (account?.lastFailure != null)
            CloudNotice(
              CloudFailure(account!.lastFailure!).message,
              error: true,
            ),
          if (binding.missing)
            const CloudNotice(
              '本次完整列表没有返回该实例。保留旧观测与本地台账，不推断已销毁或关机。',
              error: true,
            ),
          const Divider(),
          CloudValue('API 名称', observation.name),
          CloudValue('API IPv4', observation.ipv4),
          CloudValue('API IPv6', observation.ipv6),
          CloudValue('API 位置', observation.location),
          CloudValue('API 系统镜像', observation.osImage),
          CloudValue('API vCPU', observation.vcpu?.toString()),
          CloudValue(
            'API 内存',
            observation.ramBytes == null ? null : '${observation.ramBytes} 字节',
          ),
          CloudValue(
            'API 磁盘',
            observation.diskGiB == null ? null : '${observation.diskGiB} GiB',
          ),
          if (account?.provider == CloudProvider.solusVm1)
            const InfoNote(
              'SolusVM 1 Client API 仅返回单台 VPS 的状态，不提供稳定实例身份、IP 或规格。',
            ),
          const InfoNote(
            '以上是面板在该时间返回的观测，不是实时状态。API 不覆盖本地资料、费用、付款或 SSH；SSH / TCP 连通性也不等于开机状态或业务健康。',
          ),
        ],
      ),
    );
  }
}
