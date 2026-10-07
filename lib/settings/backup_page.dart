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

  static const jsonType = files.XTypeGroup(
    label: 'JSON 台账备份',
    extensions: ['json'],
    mimeTypes: ['application/json'],
    uniformTypeIdentifiers: ['public.json'],
  );

  Future<String?> pickBackup() async {
    final file = await files.openFile(acceptedTypeGroups: [jsonType]);
    if (file == null) return null;
    return readBackupFile(file);
  }

  Future<String> readBackupFile(files.XFile file) async {
    if (await file.length() > LedgerBackupSnapshot.maxBytes) {
      throw const FormatException('备份超过 10 MiB 上限');
    }
    // Also bound the stream: a provider's reported size can be stale or wrong.
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (bytes.length + chunk.length > LedgerBackupSnapshot.maxBytes) {
        throw const FormatException('备份超过 10 MiB 上限');
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }

  String _filename(LedgerBackupSnapshot snapshot) =>
      'vps-tell-you-ledger-${snapshot.exportedAt.substring(0, 10)}.json';

  Future<String?> saveBackup(LedgerBackupSnapshot snapshot) async {
    final location = await files.getSaveLocation(
      suggestedName: _filename(snapshot),
      acceptedTypeGroups: [jsonType],
    );
    if (location == null) return null;
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
    if (!canShare) return BackupShareOutcome.unsupported;
    if (_sharing) return BackupShareOutcome.busy;
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
  String? status;

  Future<void> prepareExport() async {
    if (busy) return;
    setState(() {
      busy = true;
      status = null;
      exportSnapshot = null;
    });
    try {
      final snapshot = await widget.controller.store.exportLedgerBackup();
      if (mounted) setState(() => exportSnapshot = snapshot);
    } catch (_) {
      if (mounted) setState(() => status = '导出校验失败，未保存或分享备份。台账未改动。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> writeExport(BuildContext buttonContext) async {
    final snapshot = exportSnapshot;
    if (busy || snapshot == null) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      busy = true;
      status = null;
    });
    try {
      String result;
      if (transfer.canShare) {
        result = switch (await transfer.shareBackup(snapshot, origin: origin)) {
          BackupShareOutcome.selected => '已选择系统分享操作，请在目标应用核对文件是否保存或送达。',
          BackupShareOutcome.dismissed => '已取消分享，备份预览仍保留。',
          BackupShareOutcome.unknown => '未收到系统分享结果，备份预览仍保留。',
          BackupShareOutcome.unsupported => '此平台不支持系统分享。',
          BackupShareOutcome.busy => '请先完成当前分享操作。',
          BackupShareOutcome.failed => '分享未完成，备份预览仍保留。',
        };
      } else {
        final path = await transfer.saveBackup(snapshot);
        result = path == null ? '已取消保存，备份预览仍保留。' : '备份已保存：\n$path';
      }
      if (mounted) setState(() => status = result);
    } catch (_) {
      if (mounted) setState(() => status = '备份保存未完成，请检查空间与权限后重试。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pickRestore() async {
    if (busy) return;
    setState(() {
      busy = true;
      status = null;
      restorePreview = null;
    });
    try {
      final source = await transfer.pickBackup();
      if (!mounted) return;
      if (source == null) {
        setState(() => status = '已取消选择备份。');
        return;
      }
      final snapshot = LedgerBackupSnapshot.decode(source);
      final preview = await widget.controller.store.previewLedgerRestore(
        snapshot,
      );
      if (mounted) setState(() => restorePreview = preview);
    } catch (_) {
      if (mounted) {
        setState(
          () => status = '读取或校验失败。请选择格式 v1、10 MiB 以内的完整 JSON 台账备份；现有数据未改动。',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
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
        title: '恢复到当前空台账？',
        message:
            '${_counts(preview.counts)}\n保留原始 ID、金额和付款撤销状态；替换手动参考汇率。备注、连接、安全资料和提醒规则不恢复，导入服务器的提醒保持关闭。恢复不会连接或续费服务器。',
        action: '确认恢复',
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
          status = '台账已恢复。请重新配置连接与提醒；本次未连接任何服务器。';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => status = '恢复未完成，现有数据未改动。恢复仅支持空台账，请重新选择备份并核对。');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _backupTime(String value) =>
      '${DateTime.parse(value).toLocal().toString().substring(0, 19)}（设备时间）';

  String _counts(Map<String, int> counts) =>
      '${counts['servers']} 台服务器 · ${counts['groups']} 个分组\n'
      '${counts['payments']} 笔付款（含撤销） · ${counts['service_periods']} 个服务期';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('台账备份与恢复')),
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
                  '明文 JSON · 格式 v1',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                InfoNote(
                  '包含服务器名称、厂商、地址、地区、用途、系统、规格、硬件信息、分组、金额、日期、付款和手动汇率。文件未加密，请妥善保管，只分享到可信位置。上述字段若填写了敏感内容，也会随文件导出。',
                ),
                Text('不包含：'),
                for (final item in LedgerBackupSnapshot.exclusions)
                  InfoNote(item),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: busy || widget.controller.busy ? null : prepareExport,
            icon: const Icon(Icons.backup_outlined),
            label: const Text('生成导出预览'),
          ),
          if (exportSnapshot != null) ...[
            LedgerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('导出预览'),
                  Text(_counts(exportSnapshot!.counts)),
                  Text('备份生成时间：${_backupTime(exportSnapshot!.exportedAt)}'),
                  Builder(
                    builder: (buttonContext) => FilledButton.icon(
                      onPressed: busy ? null : () => writeExport(buttonContext),
                      icon: Icon(
                        transfer.canShare ? Icons.ios_share : Icons.save_alt,
                      ),
                      label: Text(transfer.canShare ? '分享未加密备份' : '保存 JSON 备份'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const InfoNote(
            '仅支持恢复到没有服务器、分组、付款和服务期的空台账。不会覆盖或合并现有数据。导入服务器的提醒默认关闭，应用偏好保持不变。',
          ),
          OutlinedButton.icon(
            onPressed: busy || !widget.controller.canMutate
                ? null
                : pickRestore,
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('选择 JSON 并预览恢复'),
          ),
          if (restorePreview != null)
            LedgerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('恢复预览'),
                  Text(_counts(restorePreview!.counts)),
                  Text(
                    '备份时间：${_backupTime(restorePreview!.snapshot.exportedAt)}',
                  ),
                  const InfoNote('将导入上述台账记录与手动汇率。上方列出的安全资料、备注、提醒和应用偏好均不在备份内。'),
                  for (final conflict in restorePreview!.conflicts)
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
                    child: const Text('恢复到空台账'),
                  ),
                ],
              ),
            ),
          if (busy) const LinearProgressIndicator(),
          if (status != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SelectableText(status!),
            ),
        ],
      ),
    ),
  );
}
