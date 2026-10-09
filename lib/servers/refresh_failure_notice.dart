import '../l10n/locale_preference.dart';

import 'package:flutter/material.dart';

import '../core/ui/ui.dart';
import 'ledger_controller.dart';

/// The write committed, but the visible snapshot is stale until a read succeeds.
class RefreshFailureNotice extends StatelessWidget {
  const RefreshFailureNotice({super.key, required this.controller});
  final LedgerController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: AppCard(
        color: p.amberSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 20, color: p.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.serverSavedDisplayStale,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: p.amber,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.serverReloadBeforeEditing,
              style: context.footnoteStyle,
            ),
            const SizedBox(height: 12),
            AppButton(
              label: context.l10n.serverReload,
              kind: AppButtonKind.tonal,
              compact: true,
              onPressed: controller.busy
                  ? null
                  : () async {
                      try {
                        await controller.refresh();
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Builder(
                                builder: (context) =>
                                    Text(context.l10n.serverReloadStillFailed),
                              ),
                            ),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
