import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/ui/ui.dart';
import '../l10n/locale_preference.dart';
import 'sftp_support.dart';

/// Compact progress strip above the safe area; tap opens the full list.
class SftpTransferBar extends StatelessWidget {
  const SftpTransferBar({
    super.key,
    required this.queue,
    required this.onShare,
  });
  final SftpTransferQueue queue;
  final void Function(File file) onShare;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: queue,
    builder: (context, _) {
      final l10n = context.l10n;
      final palette = context.palette;
      final items = queue.items;
      if (items.isEmpty) return const SizedBox.shrink();
      final active = queue.active;
      final pending = items.where((i) => !i.finished).length;
      final failed = items
          .where((i) => i.state == SftpTransferState.failed)
          .firstOrNull;
      final IconData icon;
      final String title;
      final String? detail;
      final double? fraction;
      var showProgress = false;
      if (active != null) {
        final up = active.kind == SftpTransferKind.upload;
        icon = up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
        title = up
            ? l10n.r3SftpTransferUp(active.name)
            : l10n.r3SftpTransferDown(active.name);
        final index = items.length - pending + 1;
        final percent = active.fraction == null
            ? ''
            : ' · ${(active.fraction! * 100).floor()}%';
        detail = items.length > 1
            ? '${l10n.r3SftpTransferCount(index, items.length)}$percent'
            : (percent.isEmpty ? null : percent.substring(3));
        fraction = active.fraction;
        showProgress = true;
      } else if (failed != null) {
        icon = Icons.error_outline_rounded;
        title = failed.name;
        detail = sftpErrorText(l10n, failed.error ?? const _Unknown());
        fraction = null;
      } else {
        icon = Icons.check_circle_outline_rounded;
        title = l10n.r3SftpStateDone;
        detail = null;
        fraction = null;
      }
      final tone = active != null
          ? palette.primary
          : failed != null
          ? palette.red
          : palette.green;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showSftpTransfers(context, queue, onShare),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
            child: Row(
              children: [
                Icon(icon, size: 22, color: tone),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: palette.text,
                        ),
                      ),
                      if (detail != null)
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: palette.text2),
                        ),
                      if (showProgress) ...[
                        const SizedBox(height: 6),
                        AppProgressBar(value: fraction ?? 0),
                      ],
                    ],
                  ),
                ),
                AppNavButton.icon(
                  active != null ? Icons.close_rounded : Icons.clear_rounded,
                  key: const ValueKey('sftp-transfer-dismiss'),
                  tooltip: active != null
                      ? l10n.cancel
                      : l10n.r3SftpClearFinished,
                  onPressed: () => active != null
                      ? queue.cancel(active)
                      : queue.clearFinished(),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Unknown {
  const _Unknown();
}

Future<void> showSftpTransfers(
  BuildContext context,
  SftpTransferQueue queue,
  void Function(File file) onShare,
) => showAppSheet<void>(
  context,
  title: context.l10n.r3SftpTransfers,
  builder: (sheetContext) => ListenableBuilder(
    listenable: queue,
    builder: (context, _) {
      final l10n = context.l10n;
      final palette = context.palette;
      final items = queue.items;
      if (items.isEmpty) {
        return AppEmptyState(
          icon: Icons.swap_vert_rounded,
          title: l10n.r3SftpTransfers,
        );
      }
      String status(SftpTransferItem item) => switch (item.state) {
        SftpTransferState.queued => l10n.r3SftpStateQueued,
        SftpTransferState.running =>
          item.fraction == null
              ? '…'
              : '${(item.fraction! * 100).floor()}%'
                    '${item.total == null ? '' : ' · ${formatBytes(item.done)} / ${formatBytes(item.total!)}'}',
        SftpTransferState.done =>
          item.savedPath == null
              ? l10n.r3SftpStateDone
              : l10n.r3SftpSavedTo(
                  '$sftpDownloadsFolder/${p.basename(item.savedPath!)}',
                ),
        SftpTransferState.failed => sftpErrorText(
          l10n,
          item.error ?? const _Unknown(),
        ),
        SftpTransferState.cancelled => l10n.r3SftpStateCancelled,
        SftpTransferState.skipped => l10n.r3SftpStateSkipped,
      };
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSection(
            topSpacing: 4,
            footer: items.any((i) => i.kind == SftpTransferKind.download)
                ? l10n.r3SftpDownloadsWhere
                : null,
            children: [
              for (final item in items)
                AppRow(
                  key: ValueKey('sftp-transfer-${item.id}'),
                  icon: item.kind == SftpTransferKind.upload
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  iconColor: switch (item.state) {
                    SftpTransferState.failed => AppTints.red,
                    SftpTransferState.done => AppTints.green,
                    _ => AppTints.blue,
                  },
                  title: item.name,
                  subtitle: status(item),
                  trailing: switch (item.state) {
                    SftpTransferState.queued ||
                    SftpTransferState.running => AppNavButton.icon(
                      Icons.close_rounded,
                      key: ValueKey('sftp-transfer-cancel-${item.id}'),
                      tooltip: l10n.cancel,
                      color: palette.red,
                      onPressed: () => queue.cancel(item),
                    ),
                    SftpTransferState.done when item.savedPath != null =>
                      AppNavButton.icon(
                        Icons.ios_share_rounded,
                        key: ValueKey('sftp-transfer-share-${item.id}'),
                        tooltip: l10n.r3SftpShare,
                        onPressed: () => onShare(File(item.savedPath!)),
                      ),
                    _ => null,
                  },
                ),
            ],
          ),
          AppSection(
            topSpacing: 12,
            children: [
              if (queue.busy)
                AppRow(
                  key: const ValueKey('sftp-transfer-cancel-all'),
                  title: l10n.r3SftpCancelAll,
                  destructive: true,
                  center: true,
                  onTap: queue.cancelAll,
                ),
              if (items.any((i) => i.finished))
                AppRow(
                  key: const ValueKey('sftp-transfer-clear'),
                  title: l10n.r3SftpClearFinished,
                  center: true,
                  onTap: queue.clearFinished,
                ),
            ],
          ),
        ],
      );
    },
  ),
);
