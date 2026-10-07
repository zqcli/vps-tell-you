import '../l10n/locale_preference.dart';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'ledger_controller.dart';

/// The write committed, but the visible snapshot is stale until a read succeeds.
class RefreshFailureNotice extends StatelessWidget {
  const RefreshFailureNotice({super.key, required this.controller});
  final LedgerController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.serverSavedDisplayStale),
          InfoNote(context.l10n.serverReloadBeforeEditing),
          TextButton(
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
            child: Text(context.l10n.serverReload),
          ),
        ],
      ),
    ),
  );
}
