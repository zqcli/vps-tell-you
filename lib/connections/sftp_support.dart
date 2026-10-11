import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart' as selector;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Rect;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/generated/app_localizations.dart';
import 'sftp_session.dart';

/// Above this size a transfer asks before it starts.
const sftpLargeFileBytes = 100 * 1024 * 1024;

/// Folder (inside the app's documents directory) that receives downloads.
const sftpDownloadsFolder = 'SFTP Downloads';

String sftpErrorText(AppLocalizations l10n, Object error, {int? maxEntries}) {
  if (error is! SftpException) return l10n.r3SftpErrFailed;
  return switch (error.kind) {
    SftpErrorKind.permissionDenied => l10n.r3SftpErrPermission,
    SftpErrorKind.notFound => l10n.r3SftpErrNotFound,
    SftpErrorKind.exists => l10n.r3SftpErrExists,
    SftpErrorKind.notEmpty => l10n.r3SftpErrNotEmpty,
    SftpErrorKind.wrongType => l10n.r3SftpErrWrongType,
    SftpErrorKind.cancelled => l10n.r3SftpErrCancelled,
    SftpErrorKind.tooLarge => l10n.r3SftpErrTooLarge,
    SftpErrorKind.notText => l10n.r3SftpErrNotText,
    SftpErrorKind.tooManyEntries => l10n.r3SftpErrTooMany(
      maxEntries ?? sftpDefaultRecursiveLimit,
    ),
    SftpErrorKind.invalidPath => l10n.r3SftpErrInvalidPath,
    SftpErrorKind.timeout => l10n.r3SftpErrTimeout,
    SftpErrorKind.connectionLost => l10n.r3SftpErrConnectionLost,
    SftpErrorKind.unavailable => l10n.r3SftpErrUnavailable,
    SftpErrorKind.localFile => l10n.r3SftpErrLocalFile,
    SftpErrorKind.failed => l10n.r3SftpErrFailed,
  };
}

/// 1024-based, one decimal from KB up: `0 B`, `812 B`, `1.5 KB`, `3.0 GB`.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(1)} ${units[unit]}';
}

String formatModified(DateTime time) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}

/// The phone side of SFTP: picking files to upload, where downloads go and
/// the share sheet. Injectable so tests never open a real picker.
abstract class SftpLocalFiles {
  Future<List<File>> pickUploads();

  /// Directory that receives downloads (created on demand).
  Future<Directory> downloadsDirectory();

  /// Forgets a picked file once its upload is over (picker copies live in the
  /// temporary directory).
  Future<void> discardPicked(File file);

  /// Opens the system share sheet ("Save to Files" on iOS). Returns false when
  /// sharing is not possible on this platform.
  Future<bool> share(File file, {Rect? origin});
}

class SystemSftpLocalFiles implements SftpLocalFiles {
  const SystemSftpLocalFiles();

  @override
  Future<List<File>> pickUploads() async {
    final picked = await selector.openFiles();
    return [for (final item in picked) File(item.path)];
  }

  @override
  Future<Directory> downloadsDirectory() async {
    final Directory root;
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      // iOS: shown in Files > On My iPhone > this app (UIFileSharingEnabled).
      // Android: app-private; the share sheet is the way out.
      root = await getApplicationDocumentsDirectory();
    } else {
      root =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    }
    return Directory(p.join(root.path, sftpDownloadsFolder))
        .create(recursive: true);
  }

  @override
  Future<void> discardPicked(File file) async {
    try {
      final temp = (await getTemporaryDirectory()).path;
      final cache = file.path;
      if (p.isWithin(temp, cache) && await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best effort only; the OS clears temporary directories.
    }
  }

  @override
  Future<bool> share(File file, {Rect? origin}) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          sharePositionOrigin: origin,
          downloadFallbackEnabled: false,
        ),
      );
      return result.status != ShareResultStatus.unavailable;
    } catch (_) {
      return false;
    }
  }
}

enum SftpTransferKind { upload, download }

enum SftpTransferState { queued, running, done, failed, cancelled, skipped }

class SftpTransferItem {
  SftpTransferItem({
    required this.id,
    required this.kind,
    required this.name,
    required this.remotePath,
    this.local,
    this.total,
  });
  final int id;
  final SftpTransferKind kind;
  final String name, remotePath;
  File? local;
  int? total;
  int done = 0;
  SftpTransferState state = SftpTransferState.queued;
  SftpException? error;

  /// Downloads: the local file once finished.
  String? savedPath;
  SftpCancelToken? _cancel;

  bool get finished => switch (state) {
    SftpTransferState.queued || SftpTransferState.running => false,
    _ => true,
  };
  double? get fraction => total == null || total == 0
      ? null
      : (done / total!).clamp(0.0, 1.0).toDouble();
}

/// Resolves an upload name clash: `true` overwrites, `false` skips.
typedef SftpConflictResolver = Future<bool> Function(String name);

/// Sequential transfer queue for one [SftpSession]. One item runs at a time;
/// every item can be cancelled; partial files are cleaned up by the session.
class SftpTransferQueue extends ChangeNotifier {
  SftpTransferQueue({
    required this.session,
    required this.local,
    required this.resolveConflict,
    this.onFinished,
  });
  final SftpSession session;
  final SftpLocalFiles local;
  final SftpConflictResolver resolveConflict;

  /// Called after each item ended (any state).
  final void Function(SftpTransferItem item)? onFinished;
  final items = <SftpTransferItem>[];
  var _next = 1;
  Future<void>? _pump;
  var _running = false;
  var _disposed = false;
  var _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  bool get busy => items.any((item) => !item.finished);
  SftpTransferItem? get active =>
      items.where((i) => i.state == SftpTransferState.running).firstOrNull ??
      items.where((i) => i.state == SftpTransferState.queued).firstOrNull;

  SftpTransferItem enqueueUpload(File file, String remoteDirectory) {
    final name = p.basename(file.path);
    final item = SftpTransferItem(
      id: _next++,
      kind: SftpTransferKind.upload,
      name: name,
      remotePath: SftpPath.join(remoteDirectory, name),
      local: file,
    );
    return _add(item);
  }

  SftpTransferItem enqueueDownload(SftpEntry entry) => _add(
    SftpTransferItem(
      id: _next++,
      kind: SftpTransferKind.download,
      name: entry.name,
      remotePath: entry.path,
      total: entry.size,
    ),
  );

  SftpTransferItem _add(SftpTransferItem item) {
    items.add(item);
    _change(force: true);
    if (!_running) {
      _running = true;
      _pump = _run();
    }
    return item;
  }

  void cancel(SftpTransferItem item) {
    if (item.state == SftpTransferState.queued) {
      item.state = SftpTransferState.cancelled;
      _change(force: true);
      _discard(item);
    } else if (item.state == SftpTransferState.running) {
      item._cancel?.cancel();
    }
  }

  void cancelAll() {
    for (final item in List.of(items)) {
      cancel(item);
    }
  }

  void clearFinished() {
    items.removeWhere((item) => item.finished);
    _change(force: true);
  }

  /// Cancels everything and waits (bounded) for the running item to clean up.
  Future<void> shutdown() async {
    cancelAll();
    final pump = _pump;
    if (pump != null) {
      await pump.timeout(const Duration(seconds: 5), onTimeout: () {});
    }
  }

  void _change({bool force = false}) {
    if (_disposed) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastNotify).inMilliseconds < 80) return;
    _lastNotify = now;
    notifyListeners();
  }

  void _discard(SftpTransferItem item) {
    final file = item.local;
    if (item.kind == SftpTransferKind.upload && file != null) {
      unawaited(local.discardPicked(file));
    }
  }

  Future<void> _run() async {
    try {
      while (!_disposed) {
        final item = items
            .where((i) => i.state == SftpTransferState.queued)
            .firstOrNull;
        if (item == null) break;
        await _process(item);
        if (!_disposed) onFinished?.call(item);
      }
    } finally {
      _running = false;
      _pump = null;
    }
  }

  Future<void> _process(SftpTransferItem item) async {
    final token = item._cancel = SftpCancelToken();
    item.state = SftpTransferState.running;
    _change(force: true);
    void progress(int done, int? total) {
      item.done = done;
      item.total = total ?? item.total;
      _change(force: done >= (item.total ?? -1));
    }

    try {
      if (item.kind == SftpTransferKind.upload) {
        final file = item.local!;
        item.total = await file.length();
        var overwrite = false;
        SftpException? probe;
        try {
          await session.stat(item.remotePath);
          overwrite = await resolveConflict(item.name);
          if (!overwrite) {
            item.state = SftpTransferState.skipped;
            return;
          }
        } on SftpException catch (problem) {
          if (problem.kind != SftpErrorKind.notFound) probe = problem;
        }
        if (probe != null) throw probe;
        if (token.isCancelled) {
          throw const SftpException(SftpErrorKind.cancelled);
        }
        await session.upload(
          file,
          item.remotePath,
          overwrite: overwrite,
          onProgress: progress,
          cancel: token,
        );
      } else {
        final directory = await local.downloadsDirectory();
        final target = _uniqueFile(directory, item.name);
        await session.download(
          item.remotePath,
          target,
          onProgress: progress,
          cancel: token,
        );
        item.savedPath = target.path;
      }
      item.state = SftpTransferState.done;
    } on SftpException catch (problem) {
      item.error = problem;
      item.state = problem.kind == SftpErrorKind.cancelled
          ? SftpTransferState.cancelled
          : SftpTransferState.failed;
    } catch (_) {
      item.error = const SftpException(SftpErrorKind.failed);
      item.state = SftpTransferState.failed;
    } finally {
      item._cancel = null;
      _discard(item);
      _change(force: true);
    }
  }

  static File _uniqueFile(Directory directory, String name) {
    var candidate = File(p.join(directory.path, name));
    final stem = p.basenameWithoutExtension(name);
    final extension = p.extension(name);
    for (var i = 1; candidate.existsSync(); i++) {
      candidate = File(p.join(directory.path, '$stem ($i)$extension'));
    }
    return candidate;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
