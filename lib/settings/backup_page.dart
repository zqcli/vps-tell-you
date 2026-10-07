import '../l10n/locale_preference.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/localized_message.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' as files;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_theme.dart';
import '../data/ledger_store.dart';
import '../servers/ledger_controller.dart';
import '../servers/refresh_failure_notice.dart';

enum BackupShareOutcome {
  selected,
  dismissed,
  unknown,
  unsupported,
  busy,
  failed,
}

typedef BackupShareInvoker = Future<ShareResult> Function(ShareParams);

/// Injectable native boundary. Tests use synthetic bytes and never open a real
/// picker, write a user file, or send data to another application.
class LedgerBackupTransfer {
  LedgerBackupTransfer({BackupShareInvoker? invoke})
    : _invoke = invoke ?? SharePlus.instance.share;
  final BackupShareInvoker _invoke;
  bool _sharing = false;

  bool get canShare =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static files.XTypeGroup get jsonType => jsonTypeFor(defaultLocalizations);
  static files.XTypeGroup jsonTypeFor(AppLocalizations l10n) =>
      files.XTypeGroup(
        label: l10n.jsonLedgerBackup,
        extensions: ['json'],
        mimeTypes: ['application/json'],
        uniformTypeIdentifiers: ['public.json'],
      );

  Future<String?> pickBackup({AppLocalizations? l10n}) async {
    final file = await files.openFile(
      acceptedTypeGroups: [jsonTypeFor(l10n ?? defaultLocalizations)],
    );
    if (file == null) {
      return null;
    }
    return readBackupFile(file);
  }

  Future<String> readBackupFile(files.XFile file) async {
    if (await file.length() > LedgerBackupSnapshot.maxBytes) {
      throw LocalizedFormatException((l10n) => l10n.backupTooLarge);
    }
    // Also bound the stream: a provider's reported size can be stale or wrong.
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (bytes.length + chunk.length > LedgerBackupSnapshot.maxBytes) {
        throw LocalizedFormatException((l10n) => l10n.backupTooLarge);
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }

  String _filename(LedgerBackupSnapshot snapshot) =>
      'vps-tell-you-ledger-${snapshot.exportedAt.substring(0, 10)}.json';

  Future<String?> saveBackup(
    LedgerBackupSnapshot snapshot, {
    AppLocalizations? l10n,
  }) async {
    final location = await files.getSaveLocation(
      suggestedName: _filename(snapshot),
      acceptedTypeGroups: [jsonTypeFor(l10n ?? defaultLocalizations)],
    );
    if (location == null) {
      return null;
    }
    await files.XFile.fromData(
      Uint8List.fromList(utf8.encode(snapshot.encode())),
      mimeType: 'application/json',
      name: _filename(snapshot),
    ).saveTo(location.path);
    return location.path;
  }

  Future<BackupShareOutcome> shareBackup(
    LedgerBackupSnapshot snapshot, {
    Rect? origin,
  }) async {
    if (!canShare) {
      return BackupShareOutcome.unsupported;
    }
    if (_sharing) {
      return BackupShareOutcome.busy;
    }
    if (origin != null && (!origin.isFinite || origin.isEmpty)) {
      throw ArgumentError('Invalid share-sheet origin');
    }
    _sharing = true;
    try {
      final result = await _invoke(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(snapshot.encode())),
              mimeType: 'application/json',
            ),
          ],
          fileNameOverrides: [_filename(snapshot)],
          sharePositionOrigin: origin,
          downloadFallbackEnabled: false,
        ),
      );
      return switch (result.status) {
        ShareResultStatus.success => BackupShareOutcome.selected,
        ShareResultStatus.dismissed => BackupShareOutcome.dismissed,
        ShareResultStatus.unavailable => BackupShareOutcome.unknown,
      };
    } catch (_) {
      return BackupShareOutcome.failed;
    } finally {
      _sharing = false;
    }
  }
}

class BackupPage extends StatefulWidget {
  const BackupPage({super.key, required this.controller, this.transfer});
  final LedgerController controller;
  final LedgerBackupTransfer? transfer;
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  late final transfer = widget.transfer ?? LedgerBackupTransfer();
  LedgerBackupSnapshot? exportSnapshot;
  LedgerRestorePreview? restorePreview;
  bool busy = false;
  LocalizedText? status;

  Future<void> prepareExport() async {
    if (busy) {
      return;
    }
    setState(() {
      busy = true;
      status = null;
      exportSnapshot = null;
    });
    try {
      final snapshot = await widget.controller.store.exportLedgerBackup();
      if (mounted) {
        setState(() => exportSnapshot = snapshot);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => status = LocalizedText((l10n) => l10n.backupExportInvalid),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> writeExport(BuildContext buttonContext) async {
    final snapshot = exportSnapshot;
    final l10n = context.l10n;
    if (busy || snapshot == null) {
      return;
    }
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      busy = true;
      status = null;
    });
    try {
      LocalizedText result;
      if (transfer.canShare) {
        result = switch (await transfer.shareBackup(snapshot, origin: origin)) {
          BackupShareOutcome.selected => LocalizedText(
            (l10n) => l10n.backupShareSelected,
          ),
          BackupShareOutcome.dismissed => LocalizedText(
            (l10n) => l10n.backupShareCancelled,
          ),
          BackupShareOutcome.unknown => LocalizedText(
            (l10n) => l10n.backupShareUnknown,
          ),
          BackupShareOutcome.unsupported => LocalizedText(
            (l10n) => l10n.systemShareUnsupported,
          ),
          BackupShareOutcome.busy => LocalizedText(
            (l10n) => l10n.completeCurrentShare,
          ),
          BackupShareOutcome.failed => LocalizedText(
            (l10n) => l10n.backupShareFailed,
          ),
        };
      } else {
        final path = await transfer.saveBackup(snapshot, l10n: l10n);
        result = LocalizedText(
          (l10n) => path == null
              ? l10n.backupSaveCancelled
              : l10n.backupSavedPath(path),
        );
      }
      if (mounted) {
        setState(() => status = result);
      }
    } catch (_) {
      if (mounted) {
        setState(() => status = LocalizedText((l10n) => l10n.backupSaveFailed));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> pickRestore() async {
    if (busy) {
      return;
    }
    setState(() {
      busy = true;
      status = null;
      restorePreview = null;
    });
    try {
      final source = await transfer.pickBackup(l10n: context.l10n);
      if (!mounted) {
        return;
      }
      if (source == null) {
        setState(
          () => status = LocalizedText((l10n) => l10n.backupSelectionCancelled),
        );
        return;
      }
      final snapshot = LedgerBackupSnapshot.decode(source);
      final preview = await widget.controller.store.previewLedgerRestore(
        snapshot,
      );
      if (mounted) {
        setState(() => restorePreview = preview);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => status = LocalizedText((l10n) => l10n.backupReadInvalid),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> restore() async {
    final preview = restorePreview;
    if (busy ||
        preview == null ||
        !preview.canRestore ||
        !widget.controller.canMutate) {
      return;
    }
    setState(() {
      busy = true;
      status = null;
    });
    try {
      final confirmed = await confirmAction(
        context,
        title: LocalizedText((l10n) => l10n.restoreEmptyLedgerQuestion),
        message: LocalizedText(
          (l10n) =>
              l10n.restoreConfirmation((_counts(preview.counts)).toString()),
        ),
        action: LocalizedText((l10n) => l10n.confirmRestore),
      );
      if (!confirmed || !mounted) {
        return;
      }
      await widget.controller.mutate(
        () => widget.controller.store.restoreLedgerBackup(preview.snapshot),
      );
      if (mounted) {
        setState(() {
          restorePreview = null;
          exportSnapshot = null;
          status = LocalizedText((l10n) => l10n.ledgerRestored);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => status = LocalizedText((l10n) => l10n.restoreFailed));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  String _backupTime(String value) => context.l10n.deviceTime(
    (DateTime.parse(value).toLocal().toString().substring(0, 19)).toString(),
  );

  String _counts(Map<String, int> counts) => context.l10n.backupCounts(
    (counts['servers']).toString(),
    (counts['groups']).toString(),
    (counts['payments']).toString(),
    (counts['service_periods']).toString(),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(context.l10n.ledgerBackupRestore)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.controller.refreshFailed)
            RefreshFailureNotice(controller: widget.controller),
          LedgerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.plainJsonVersion,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                InfoNote(context.l10n.backupContentsWarning),
                Text(context.l10n.notIncluded),
                for (final item in LedgerBackupSnapshot.exclusionsFor(
                  context.l10n,
                ))
                  InfoNote(item),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: busy || widget.controller.busy ? null : prepareExport,
            icon: const Icon(Icons.backup_outlined),
            label: Text(context.l10n.generateBackupPreview),
          ),
          if (exportSnapshot != null) ...[
            LedgerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.exportPreview),
                  Text(_counts(exportSnapshot!.counts)),
                  Text(
                    context.l10n.backupGeneratedTime(
                      (_backupTime(exportSnapshot!.exportedAt)).toString(),
                    ),
                  ),
                  Builder(
                    builder: (buttonContext) => FilledButton.icon(
                      onPressed: busy ? null : () => writeExport(buttonContext),
                      icon: Icon(
                        transfer.canShare ? Icons.ios_share : Icons.save_alt,
                      ),
                      label: Text(
                        transfer.canShare
                            ? context.l10n.shareUnencryptedBackup
                            : context.l10n.saveJsonBackup,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          InfoNote(context.l10n.restoreEmptyOnlyHelp),
          OutlinedButton.icon(
            onPressed: busy || !widget.controller.canMutate
                ? null
                : pickRestore,
            icon: const Icon(Icons.file_open_outlined),
            label: Text(context.l10n.chooseJsonPreviewRestore),
          ),
          if (restorePreview != null)
            LedgerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.restorePreview),
                  Text(_counts(restorePreview!.counts)),
                  Text(
                    context.l10n.backupTime(
                      (_backupTime(restorePreview!.snapshot.exportedAt))
                          .toString(),
                    ),
                  ),
                  InfoNote(context.l10n.restoreContentsHelp),
                  for (final conflict in restorePreview!.conflictsFor(
                    context.l10n,
                  ))
                    Text(
                      conflict,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  FilledButton(
                    onPressed:
                        busy ||
                            !restorePreview!.canRestore ||
                            !widget.controller.canMutate
                        ? null
                        : restore,
                    child: Text(context.l10n.restoreToEmptyLedger),
                  ),
                ],
              ),
            ),
          if (busy) const LinearProgressIndicator(),
          if (status != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SelectableText(status!.messageFor(context.l10n)),
            ),
        ],
      ),
    ),
  );
}
