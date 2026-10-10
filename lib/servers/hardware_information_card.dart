import 'package:flutter/material.dart';

import '../core/ui/ui.dart';
import '../l10n/locale_preference.dart';
import 'server_resources.dart';

/// Reviewed hardware is local, optional and never replaced by cloud refreshes.
///
/// Shown as a grid of small tiles (three per row, fewer at large text sizes);
/// unknown values stay greyed "not entered" and are never rendered as zero.
class HardwareInformationCard extends StatelessWidget {
  const HardwareInformationCard(this.resources, {super.key});
  final ServerResources? resources;

  @override
  Widget build(BuildContext context) {
    final data = resources;
    String bytes(int? value) => value == null
        ? context.l10n.serverNotEntered
        : ServerResources.formatBytes(value);
    String period(int? months) => switch (months) {
      1 => context.l10n.resourceMonth,
      3 => context.l10n.resourceQuarter,
      12 => context.l10n.resourceYear,
      _ => context.l10n.resourcePeriodNotSet,
    };
    final traffic = data?.trafficUnlimited == true
        ? context.l10n.resourceUnlimitedConfirmed
        : bytes(data?.trafficBytes);
    final trafficKnown =
        data?.trafficUnlimited == true || data?.trafficBytes != null;
    final tiles = <_HardwareTile>[
      _HardwareTile(
        icon: Icons.memory_rounded,
        title: context.l10n.resourceVcpuCount,
        value: data?.vcpu?.toString(),
      ),
      _HardwareTile(
        icon: Icons.developer_board_rounded,
        title: context.l10n.resourceMemoryCapacity,
        value: data?.ramBytes == null ? null : bytes(data?.ramBytes),
      ),
      _HardwareTile(
        icon: Icons.storage_rounded,
        title: context.l10n.resourceDiskCapacity,
        value: data?.diskBytes == null ? null : bytes(data?.diskBytes),
      ),
      _HardwareTile(
        icon: Icons.swap_vert_rounded,
        title: context.l10n.resourceTrafficQuotaLabel,
        value: '$traffic / ${period(data?.trafficPeriodMonths)}',
        known: trafficKnown,
      ),
      _HardwareTile(
        icon: Icons.public_rounded,
        title: context.l10n.resourceIpAddress,
        value: data?.ip,
        mono: true,
      ),
      _HardwareTile(
        icon: Icons.sell_outlined,
        title: context.l10n.resourceHostname,
        value: data?.hostname,
      ),
    ];
    // Three columns need ~100 px per tile; large text or narrow screens fall
    // back to two (then one) columns instead of clipping values.
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth - 32;
        final columns = width / scale >= 330 && scale <= 1.3
            ? 3
            : width / scale >= 210
            ? 2
            : 1;
        final rows = <Widget>[];
        for (var start = 0; start < tiles.length; start += columns) {
          final cells = tiles.skip(start).take(columns).toList();
          rows.add(
            Padding(
              padding: EdgeInsets.only(top: start == 0 ? 0 : 8),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < columns; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: i < cells.length
                            ? cells[i]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...rows,
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
                child: Text(
                  context.l10n.resourceCardHelp,
                  style: context.footnoteStyle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HardwareTile extends StatelessWidget {
  const _HardwareTile({
    required this.icon,
    required this.title,
    required this.value,
    this.known = true,
    this.mono = false,
  });
  final IconData icon;
  final String title;

  /// `null` or empty renders the greyed "not entered" placeholder.
  final String? value;

  /// `false` greys a composite value (traffic) whose quota is unknown.
  final bool known;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final empty = value == null || value!.isEmpty;
    final unknown = empty || !known;
    final text = empty ? context.l10n.serverNotEntered : value!;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: p.text2),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: p.text2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: (mono ? kMonoTextStyle : const TextStyle()).copyWith(
                fontSize: mono ? 14 : 16,
                height: 1.25,
                fontWeight: unknown ? FontWeight.w400 : FontWeight.w600,
                color: unknown ? p.text3 : p.text,
                fontFeatures: kTabularFigures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
