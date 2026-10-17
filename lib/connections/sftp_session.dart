import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

/// SFTP file management over an already authenticated [SSHClient].
///
/// This layer never performs host verification or authentication; those stay
/// in `ssh_service.dart`. It never logs or exposes file contents, credentials
/// or server-provided error text: failures are reduced to [SftpErrorKind].

const sftpDefaultTextLimit = 512 * 1024;
const sftpDefaultRecursiveLimit = 2000;

enum SftpErrorKind {
  permissionDenied,
  notFound,
  exists,
  notEmpty,

  /// A directory where a file was needed, or the other way round.
  wrongType,
  cancelled,
  tooLarge,
  notText,

  /// [SftpSession.deleteRecursive] would touch more entries than allowed.
  tooManyEntries,
  invalidPath,
  timeout,
  connectionLost,

  /// The server refused or could not start the SFTP subsystem.
  unavailable,

  /// The local side of a transfer failed (disk full, missing file, ...).
  localFile,
  failed,
}

class SftpException implements Exception {
  const SftpException(this.kind, [this.path, this.technical]);
  final SftpErrorKind kind;

  /// The original error behind [kind], for the redacted error details only.
  final String? technical;

  /// The remote (or local, for [SftpErrorKind.localFile]) path involved.
  final String? path;
  @override
  String toString() => 'SftpException(${kind.name})';
}

/// Cooperative cancellation for long operations (transfers, recursive delete).
class SftpCancelToken {
  final _completer = Completer<void>();
  bool get isCancelled => _completer.isCompleted;
  Future<void> get whenCancelled => _completer.future;
  void cancel() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}

/// Bytes done so far and the total, when known.
typedef SftpProgress = void Function(int done, int? total);

class SftpEntry {
  const SftpEntry({
    required this.name,
    required this.path,
    required this.isDir,
    required this.isLink,
    required this.isFile,
    required this.size,
    required this.mtime,
    required this.mode,
  });

  final String name, path;

  /// For links this describes the target when it can be resolved.
  final bool isDir, isFile;
  final bool isLink;
  final int? size;
  final DateTime? mtime;

  /// `ls -l` style, for example `drwxr-xr-x`; empty when the server sent none.
  final String mode;
}

class SftpTextFile {
  const SftpTextFile({required this.text, required this.size, this.mtime});
  final String text;
  final int size;
  final DateTime? mtime;
}

abstract final class SftpPath {
  static String join(String directory, String name) =>
      directory.endsWith('/') ? '$directory$name' : '$directory/$name';

  static String basename(String path) {
    final trimmed = path.length > 1 && path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final slash = trimmed.lastIndexOf('/');
    return trimmed == '/' || slash < 0 ? trimmed : trimmed.substring(slash + 1);
  }

  static String parent(String path) {
    final trimmed = path.length > 1 && path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final slash = trimmed.lastIndexOf('/');
    if (slash < 0) return '.';
    return slash == 0 ? '/' : trimmed.substring(0, slash);
  }

  /// A single path component that is safe to append to a directory.
  static bool isValidName(String name) =>
      name.isNotEmpty &&
      name != '.' &&
      name != '..' &&
      !name.contains('/') &&
      !name.contains('\u0000');
}

abstract class SftpSession {
  /// False after [close] or when the SSH transport is gone.
  bool get isAlive;

  /// The server-side home (or chroot root) directory.
  Future<String> home();
  Future<String> realpath(String path);

  /// Directories first, then names case-insensitively; `.`/`..` omitted.
  Future<List<SftpEntry>> list(String path);
  Future<SftpEntry> stat(String path);
  Future<void> mkdir(String path);

  /// Fails with [SftpErrorKind.exists] if anything is already there.
  Future<void> createEmptyFile(String path);

  /// Fails with [SftpErrorKind.exists] rather than replacing [to].
  Future<void> rename(String from, String to);
  Future<void> deleteFile(String path);
  Future<void> deleteEmptyDirectory(String path);

  /// Deletes a tree without following symlinks. The tree is enumerated first;
  /// if it has more than [maxEntries] entries nothing is deleted and
  /// [SftpErrorKind.tooManyEntries] is thrown. Returns the entries removed.
  Future<int> deleteRecursive(
    String path, {
    int maxEntries = sftpDefaultRecursiveLimit,
    SftpCancelToken? cancel,
  });

  /// Strict UTF-8. [SftpErrorKind.tooLarge] above [maxBytes],
  /// [SftpErrorKind.notText] for NUL bytes or invalid UTF-8.
  Future<SftpTextFile> readText(
    String path, {
    int maxBytes = sftpDefaultTextLimit,
  });

  /// Without [overwrite] an existing path yields [SftpErrorKind.exists].
  /// The new content is committed by rename, so a failure never leaves a
  /// half-written target.
  Future<void> writeText(
    String path,
    String content, {
    required bool overwrite,
    int maxBytes = sftpDefaultTextLimit,
  });

  /// Streams to a temporary sibling and moves it into place on success; on
  /// failure or cancel the partial local file is removed.
  Future<void> download(
    String remotePath,
    File localFile, {
    bool overwrite = false,
    SftpProgress? onProgress,
    SftpCancelToken? cancel,
  });

  /// Streams to a temporary remote sibling and renames it into place on
  /// success; on failure or cancel the temporary file is removed and an
  /// existing target is left untouched.
  Future<void> upload(
    File localFile,
    String remotePath, {
    bool overwrite = false,
    SftpProgress? onProgress,
    SftpCancelToken? cancel,
  });

  /// Idempotent. Closes the SFTP channel (and the SSH client only when this
  /// session owns it).
  Future<void> close();
}
