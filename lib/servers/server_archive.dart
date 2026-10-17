import 'package:flutter/material.dart';

import '../core/app_theme.dart' show showFailure;
import '../core/ui/ui.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import 'ledger_controller.dart';
import 'server_record.dart';

/// Confirms, archives [record] and offers the once-only undo toast.
///
/// Shared by the list row menu and the detail page. [popOnSuccess] closes the
/// calling page (the detail page) after the archive committed.
Future<void> confirmAndArchiveServer(
  BuildContext context,
  LedgerController controller,
  ServerRecord record, {
  bool popOnSuccess = false,
}) async {
  // The list row that started this may be gone once the archive refreshes.
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showAppConfirm(
    context,
    title: LocalizedText((l10n) => l10n.serverArchiveQuestion),
    message: LocalizedText((l10n) => l10n.serverArchiveHelp(record.name)),
    action: LocalizedText((l10n) => l10n.serverArchiveLocal),
    dangerous: true,
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  try {
    final token = await controller.mutate(
      () => controller.store.archive(record),
    );
    final canUndo = !controller.refreshFailed;
    if (popOnSuccess && context.mounted) {
      Navigator.pop(context);
    }
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        // The standard action remains persistent and once-only even though
        // it lives in localized content so an open/queued label can rebuild.
        persist: canUndo,
        content: Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.serverArchived),
              if (canUndo)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: SnackBarAction(
                    label: context.l10n.serverUndo,
                    onPressed: () async {
                      try {
                        await controller.mutate(
                          () => controller.store.undoArchive(token),
                        );
                      } catch (_) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Builder(
                              builder: (context) =>
                                  Text(context.l10n.serverUndoArchiveFailed),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  } catch (error) {
    if (context.mounted) {
      showFailure(context, error);
    }
  }
}
