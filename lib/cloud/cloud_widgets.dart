import 'package:flutter/material.dart';

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
              color: i + 1 == step
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
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
          color: error
              ? Theme.of(context).colorScheme.tertiaryContainer
              : Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: TextStyle(
            fontSize: 12,
            color: error
                ? Theme.of(context).colorScheme.onTertiaryContainer
                : Theme.of(context).colorScheme.onPrimaryContainer,
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
