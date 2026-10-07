import '../l10n/locale_preference.dart';

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
    String bytes(int? value) => value == null
        ? context.l10n.serverNotEntered
        : ServerResources.formatBytes(value, exact: true);
    String period(int? months) => switch (months) {
      1 => context.l10n.resourceMonth,
      3 => context.l10n.resourceQuarter,
      12 => context.l10n.resourceYear,
      _ => context.l10n.resourcePeriodNotSet,
    };
    final traffic = data?.trafficUnlimited == true
        ? context.l10n.resourceUnlimitedConfirmed
        : bytes(data?.trafficBytes);
    Widget value(String title, String? content) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          SelectableText(
            content == null || content.isEmpty
                ? context.l10n.serverNotEntered
                : content,
          ),
        ],
      ),
    );
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          value(context.l10n.resourceIpAddress, data?.ip),
          value(context.l10n.resourceHostname, data?.hostname),
          value(context.l10n.resourceDiskCapacity, bytes(data?.diskBytes)),
          value(
            context.l10n.resourceTrafficQuotaLabel,
            '$traffic / ${period(data?.trafficPeriodMonths)}',
          ),
          value(context.l10n.resourceMemoryCapacity, bytes(data?.ramBytes)),
          value(context.l10n.resourceVcpuCount, data?.vcpu?.toString()),
          InfoNote(context.l10n.resourceCardHelp),
        ],
      ),
    );
  }
}
