import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'server_resources.dart';

/// Reviewed hardware is local, optional and never replaced by cloud refreshes.
class HardwareInformationCard extends StatelessWidget {
  const HardwareInformationCard(this.resources, {super.key});
  final ServerResources? resources;

  @override
  Widget build(BuildContext context) {
    final data = resources;
    String bytes(int? value) =>
        value == null ? '未填写' : ServerResources.formatBytes(value, exact: true);
    String period(int? months) => switch (months) {
      1 => '月',
      3 => '季',
      12 => '年',
      _ => '周期未设置',
    };
    final traffic = data?.trafficUnlimited == true
        ? '不限量（已确认）'
        : bytes(data?.trafficBytes);
    Widget value(String title, String? content) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          SelectableText(content == null || content.isEmpty ? '未填写' : content),
        ],
      ),
    );
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          value('IP', data?.ip),
          value('Hostname', data?.hostname),
          value('磁盘额度', bytes(data?.diskBytes)),
          value('流量额度', '$traffic / ${period(data?.trafficPeriodMonths)}'),
          value('内存容量', bytes(data?.ramBytes)),
          value('vCPU', data?.vcpu?.toString()),
          const InfoNote('创建后仅手动维护；云账户刷新不会改动硬件信息。未知项可稍后补充。'),
        ],
      ),
    );
  }
}
