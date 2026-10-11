import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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
  const SftpException(this.kind, [this.path]);
  final SftpErrorKind kind;

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

const _posixRename = 'posix-rename@openssh.com';

class DartSshSftpSession implements SftpSession {
  DartSshSftpSession._(
    this._sftp,
    this._client, {
    required this.ownsClient,
    required this.operationTimeout,
    required this.stallTimeout,
    this.onClose,
  });

  /// Opens the SFTP subsystem as a new channel on [client]. Nothing is written
  /// to other channels of the connection. If [ownsClient] the client is closed
  /// together with the session. [onClose] runs once, after the channel closed.
  static Future<DartSshSftpSession> open(
    SSHClient client, {
    bool ownsClient = false,
    Duration openTimeout = const Duration(seconds: 15),
    Duration operationTimeout = const Duration(seconds: 30),
    Duration stallTimeout = const Duration(seconds: 30),
    FutureOr<void> Function()? onClose,
  }) async {
    Future<SftpClient>? opening;
    try {
      final pending = opening = client.sftp();
      final sftp = await pending.timeout(openTimeout);
      try {
        await sftp.handshake.timeout(openTimeout);
      } catch (_) {
        unawaited(sftp.close().catchError((Object _) {}));
        if (client.isClosed) rethrow;
        // dartssh2 ignores a refused subsystem request, so a server that
        // disabled SFTP is only visible as a handshake that never answers.
        throw const SftpException(SftpErrorKind.unavailable);
      }
      return DartSshSftpSession._(
        sftp,
        client,
        ownsClient: ownsClient,
        operationTimeout: operationTimeout,
        stallTimeout: stallTimeout,
        onClose: onClose,
      );
    } on TimeoutException {
      // A late channel must not leak.
      unawaited(
        opening?.then((late) => late.close()).catchError((Object _) {}),
      );
      throw const SftpException(SftpErrorKind.timeout);
    } catch (problem) {
      if (client.isClosed) {
        throw const SftpException(SftpErrorKind.connectionLost);
      }
      // Refusal of the subsystem surfaces as a channel error or abort.
      throw problem is SftpException
          ? problem
          : const SftpException(SftpErrorKind.unavailable);
    }
  }

  final SftpClient _sftp;
  final SSHClient _client;
  final bool ownsClient;
  final Duration operationTimeout, stallTimeout;
  final FutureOr<void> Function()? onClose;
  Future<void>? _closing;
  final _random = Random.secure();

  @override
  bool get isAlive => _closing == null && !_client.isClosed;

  // ---------------------------------------------------------------- plumbing

  void _ready(String? path) {
    if (!isAlive) throw const SftpException(SftpErrorKind.connectionLost);
    if (path != null &&
        (path.isEmpty || path.contains('\u0000') || path.length > 4096)) {
      throw SftpException(SftpErrorKind.invalidPath, path);
    }
  }

  SftpException _map(Object problem, [String? path]) {
    if (problem is SftpException) return problem;
    if (problem is TimeoutException) {
      return SftpException(SftpErrorKind.timeout, path);
    }
    if (problem is FileSystemException) {
      return SftpException(SftpErrorKind.localFile, problem.path ?? path);
    }
    if (problem is SftpStatusError) {
      return SftpException(switch (problem.code) {
        2 => SftpErrorKind.notFound,
        3 => SftpErrorKind.permissionDenied,
        6 || 7 => SftpErrorKind.connectionLost,
        _ => SftpErrorKind.failed,
      }, path);
    }
    if (!isAlive ||
        problem is SftpAbortError ||
        problem is SSHError ||
        problem is SocketException) {
      return SftpException(SftpErrorKind.connectionLost, path);
    }
    return SftpException(SftpErrorKind.failed, path);
  }

  Future<T> _call<T>(
    String? path,
    Future<T> Function() body, {
    Duration? limit,
  }) async {
    _ready(path);
    try {
      return await body().timeout(limit ?? operationTimeout);
    } catch (problem) {
      throw _map(problem, path);
    }
  }

  Future<SftpFileAttrs?> _lstatOrNull(String path) async {
    try {
      return await _sftp.stat(path, followLink: false);
    } on SftpStatusError catch (problem) {
      if (problem.code == 2) return null;
      rethrow;
    }
  }

  Future<bool> _exists(String path) async {
    try {
      return await _lstatOrNull(path) != null;
    } catch (_) {
      return false;
    }
  }

  /// Server "failure" (code 4) is all SFTP v3 says about EEXIST, ENOTEMPTY,
  /// EISDIR..., so refine it by looking.
  Future<void> _refine(String path, SftpStatusError problem, int mode) async {
    // rmdir on a file is reported as "no such file" by some servers.
    if (problem.code != 4 && !(mode == 2 && problem.code == 2)) return;
    switch (mode) {
      case 0: // create: something already there?
        if (await _exists(path)) {
          throw SftpException(SftpErrorKind.exists, path);
        }
      case 1: // remove file: is it a directory?
        if ((await _lstatOrNull(path))?.isDirectory ?? false) {
          throw SftpException(SftpErrorKind.wrongType, path);
        }
      case 2: // remove directory: not a directory, or not empty?
        final attrs = await _lstatOrNull(path);
        if (attrs == null) return;
        if (!attrs.isDirectory) {
          throw SftpException(SftpErrorKind.wrongType, path);
        }
        final names = await _sftp.listdir(path);
        if (names.any((n) => n.filename != '.' && n.filename != '..')) {
          throw SftpException(SftpErrorKind.notEmpty, path);
        }
    }
  }

  static String _modeString(SftpFileAttrs attrs) {
    final value = attrs.mode?.value;
    if (value == null) return '';
    final type = switch (attrs.mode!.type) {
      SftpFileType.directory => 'd',
      SftpFileType.symbolicLink => 'l',
      SftpFileType.regularFile => '-',
      SftpFileType.blockDevice => 'b',
      SftpFileType.characterDevice => 'c',
      SftpFileType.pipe => 'p',
      SftpFileType.socket => 's',
      _ => '?',
    };
    String triple(int shift, int special, String x, String xs) {
      final bits = (value >> shift) & 7;
      final exec = bits & 1 != 0;
      final hasSpecial = value & special != 0;
      return '${bits & 4 != 0 ? 'r' : '-'}${bits & 2 != 0 ? 'w' : '-'}'
          '${hasSpecial ? (exec ? xs : xs.toUpperCase()) : (exec ? 'x' : '-')}';
    }

    return type +
        triple(6, 0x800, 'x', 's') +
        triple(3, 0x400, 'x', 's') +
        triple(0, 0x200, 'x', 't');
  }

  SftpEntry _entry(
    String path,
    String name,
    SftpFileAttrs attrs, {
    SftpFileAttrs? target,
  }) {
    final link = attrs.isSymbolicLink;
    final effective = link && target != null ? target : attrs;
    final seconds = effective.modifyTime;
    return SftpEntry(
      name: name,
      path: path,
      isDir: effective.isDirectory,
      isFile: effective.isFile,
      isLink: link,
      size: effective.size,
      mtime: seconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
      mode: _modeString(attrs),
    );
  }

  Future<SftpFileAttrs?> _followOrNull(String path) async {
    try {
      return await _sftp.stat(path);
    } catch (_) {
      return null; // Broken link: shown as a plain link.
    }
  }

  // ------------------------------------------------------------- navigation

  @override
  Future<String> home() => _call('.', () => _sftp.absolute('.'));

  @override
  Future<String> realpath(String path) =>
      _call(path, () => _sftp.absolute(path));

  @override
  Future<List<SftpEntry>> list(String path) => _call(path, () async {
    final names = await _sftp.listdir(path);
    final entries = <SftpEntry>[];
    final links = <(int, String, SftpName)>[];
    for (final item in names) {
      final name = item.filename;
      if (name == '.' || name == '..' || !SftpPath.isValidName(name)) continue;
      final full = SftpPath.join(path, name);
      if (item.attr.isSymbolicLink) {
        links.add((entries.length, full, item));
        entries.add(_entry(full, name, item.attr));
      } else {
        entries.add(_entry(full, name, item.attr));
      }
    }
    for (var start = 0; start < links.length; start += 16) {
      final batch = links.skip(start).take(16).toList();
      final targets = await Future.wait(batch.map((l) => _followOrNull(l.$2)));
      for (var i = 0; i < batch.length; i++) {
        final (index, full, item) = batch[i];
        entries[index] = _entry(
          full,
          item.filename,
          item.attr,
          target: targets[i],
        );
      }
    }
    entries.sort((a, b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName != 0 ? byName : a.name.compareTo(b.name);
    });
    return entries;
  }, limit: operationTimeout * 2);

  @override
  Future<SftpEntry> stat(String path) => _call(path, () async {
    final attrs = await _sftp.stat(path, followLink: false);
    return _entry(
      path,
      SftpPath.basename(path),
      attrs,
      target: attrs.isSymbolicLink ? await _followOrNull(path) : null,
    );
  });

  // -------------------------------------------------------------- mutations

  @override
  Future<void> mkdir(String path) => _call(path, () async {
    try {
      await _sftp.mkdir(path);
    } on SftpStatusError catch (problem) {
      await _refine(path, problem, 0);
      rethrow;
    }
  });

  Future<void> _createExclusive(String path) async {
    try {
      final file = await _sftp.open(
        path,
        mode:
            SftpFileOpenMode.write |
            SftpFileOpenMode.create |
            SftpFileOpenMode.exclusive,
      );
      await file.close();
    } on SftpStatusError catch (problem) {
      await _refine(path, problem, 0);
      rethrow;
    }
  }

  @override
  Future<void> createEmptyFile(String path) =>
      _call(path, () => _createExclusive(path));

  @override
  Future<void> rename(String from, String to) async {
    _ready(from);
    return await _call(to, () async {
      if (from == to || await _exists(to)) {
        throw SftpException(SftpErrorKind.exists, to);
      }
      await _sftp.rename(from, to);
    });
  }

  @override
  Future<void> deleteFile(String path) => _call(path, () async {
    try {
      await _sftp.remove(path);
    } on SftpStatusError catch (problem) {
      await _refine(path, problem, 1);
      rethrow;
    }
  });

  @override
  Future<void> deleteEmptyDirectory(String path) => _call(path, () async {
    try {
      await _sftp.rmdir(path);
    } on SftpStatusError catch (problem) {
      await _refine(path, problem, 2);
      rethrow;
    }
  });

  @override
  Future<int> deleteRecursive(
    String path, {
    int maxEntries = sftpDefaultRecursiveLimit,
    SftpCancelToken? cancel,
  }) async {
    _ready(path);
    final segments = path.split('/').where((s) => s.isNotEmpty);
    if (segments.isEmpty || segments.any((s) => s == '.' || s == '..')) {
      // Never delete the root, the cwd or anything relative to a parent.
      throw SftpException(SftpErrorKind.invalidPath, path);
    }
    void checkCancel() {
      if (cancel?.isCancelled ?? false) {
        throw const SftpException(SftpErrorKind.cancelled);
      }
    }

    try {
      // Phase 1: enumerate without following links; delete nothing.
      final order = <(String, bool)>[]; // parents before children
      final pending = <String>[path];
      while (pending.isNotEmpty) {
        checkCancel();
        final current = pending.removeLast();
        final attrs = await _call(
          current,
          () => _sftp.stat(current, followLink: false),
        );
        final isDir = attrs.isDirectory;
        order.add((current, isDir));
        if (order.length > maxEntries) {
          throw SftpException(SftpErrorKind.tooManyEntries, path);
        }
        if (isDir) {
          final names = await _call(current, () => _sftp.listdir(current));
          for (final item in names) {
            if (item.filename == '.' ||
                item.filename == '..' ||
                !SftpPath.isValidName(item.filename)) {
              continue;
            }
            pending.add(SftpPath.join(current, item.filename));
            if (order.length + pending.length > maxEntries) {
              throw SftpException(SftpErrorKind.tooManyEntries, path);
            }
          }
        }
      }
      // Phase 2: children come after their parents in [order].
      var removed = 0;
      for (final (item, isDir) in order.reversed) {
        checkCancel();
        if (isDir) {
          await deleteEmptyDirectory(item);
        } else {
          await deleteFile(item);
        }
        removed++;
      }
      return removed;
    } catch (problem) {
      throw _map(problem, path);
    }
  }

  // ------------------------------------------------------------------- text

  @override
  Future<SftpTextFile> readText(
    String path, {
    int maxBytes = sftpDefaultTextLimit,
  }) => _call(path, () async {
    final attrs = await _sftp.stat(path);
    if (attrs.isDirectory) {
      throw SftpException(SftpErrorKind.wrongType, path);
    }
    if ((attrs.size ?? 0) > maxBytes) {
      throw SftpException(SftpErrorKind.tooLarge, path);
    }
    final file = await _sftp.open(path);
    final builder = BytesBuilder(copy: false);
    try {
      // One byte more than allowed proves "too large" even if stat lied.
      await for (final chunk in file.read(length: maxBytes + 1)) {
        builder.add(chunk);
        if (builder.length > maxBytes) {
          throw SftpException(SftpErrorKind.tooLarge, path);
        }
      }
    } finally {
      unawaited(file.close().catchError((Object _) {}));
    }
    final bytes = builder.takeBytes();
    if (bytes.contains(0)) {
      throw SftpException(SftpErrorKind.notText, path);
    }
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw SftpException(SftpErrorKind.notText, path);
    }
    final seconds = attrs.modifyTime;
    return SftpTextFile(
      text: text,
      size: bytes.length,
      mtime: seconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
    );
  });

  @override
  Future<void> writeText(
    String path,
    String content, {
    required bool overwrite,
    int maxBytes = sftpDefaultTextLimit,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    if (bytes.length > maxBytes) {
      throw SftpException(SftpErrorKind.tooLarge, path);
    }
    return await _put(
      Stream.value(bytes),
      bytes.length,
      path,
      overwrite: overwrite,
      onProgress: null,
      cancel: null,
    );
  }

  // -------------------------------------------------------------- transfers

  String _suffix() =>
      List.generate(8, (_) => _random.nextInt(16).toRadixString(16)).join();

  @override
  Future<void> upload(
    File localFile,
    String remotePath, {
    bool overwrite = false,
    SftpProgress? onProgress,
    SftpCancelToken? cancel,
  }) async {
    final int total;
    try {
      total = await localFile.length();
    } catch (problem) {
      throw _map(problem, localFile.path);
    }
    return _put(
      localFile.openRead().map(
        (chunk) => chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
      ),
      total,
      remotePath,
      overwrite: overwrite,
      onProgress: onProgress,
      cancel: cancel,
    );
  }

  Future<void> _put(
    Stream<Uint8List> source,
    int total,
    String remotePath, {
    required bool overwrite,
    required SftpProgress? onProgress,
    required SftpCancelToken? cancel,
  }) async {
    _ready(remotePath);
    if (cancel?.isCancelled ?? false) {
      throw const SftpException(SftpErrorKind.cancelled);
    }
    final stall = _Stall(stallTimeout, cancel);
    String? reservation; // zero-byte placeholder created for !overwrite
    String? temp;
    SftpFile? handle;
    var committed = false;
    try {
      var finalPath = remotePath;
      SftpFileAttrs? existingMode;
      if (overwrite) {
        final existing = await _call(
          remotePath,
          () => _lstatOrNull(remotePath),
        );
        if (existing != null) {
          if (existing.isDirectory) {
            throw SftpException(SftpErrorKind.wrongType, remotePath);
          }
          if (existing.isSymbolicLink) {
            // Replace the file the link points to, not the link itself.
            try {
              finalPath = await _call(
                remotePath,
                () => _sftp.absolute(remotePath),
              );
            } on SftpException {
              finalPath = remotePath;
            }
          }
          existingMode = await _call(finalPath, () async {
            try {
              return await _sftp.stat(finalPath);
            } on SftpStatusError {
              return null;
            }
          });
          if (existingMode?.isDirectory ?? false) {
            throw SftpException(SftpErrorKind.wrongType, remotePath);
          }
        }
      } else {
        await _call(remotePath, () => _createExclusive(remotePath));
        reservation = remotePath;
      }
      final partial =
          '${SftpPath.parent(finalPath) == '/' ? '' : SftpPath.parent(finalPath)}'
          '/.${SftpPath.basename(finalPath)}.${_suffix()}.part';
      temp = partial;
      final opened = await _call(
        partial,
        () => _sftp.open(
          partial,
          mode:
              SftpFileOpenMode.write |
              SftpFileOpenMode.create |
              SftpFileOpenMode.exclusive,
        ),
      );
      handle = opened;
      final mode = existingMode?.mode;
      if (mode != null) {
        try {
          // Keep permission bits of the file being replaced (best effort).
          await _sftp
              .setStat(
                partial,
                SftpFileAttrs(mode: SftpFileMode.value(mode.value & 0xfff)),
              )
              .timeout(operationTimeout);
        } catch (_) {}
      }
      stall.arm();
      final writer = opened.write(
        source,
        onProgress: (done) {
          stall.arm();
          onProgress?.call(done, total);
        },
      );
      final stopped = await Future.any<Object?>([
        writer.done.then<Object?>((_) => null),
        stall.stopped,
      ]);
      if (stopped != null) {
        unawaited(writer.abort().catchError((Object _) {}));
        throw stopped;
      }
      onProgress?.call(total, total);
      await _call(partial, () => handle!.close());
      handle = null;
      if (cancel?.isCancelled ?? false) {
        throw const SftpException(SftpErrorKind.cancelled);
      }
      final from = partial;
      final to = finalPath;
      await _call(to, () async {
        try {
          await _sftp.rename(from, to);
        } on SftpStatusError {
          // Servers without posix-rename refuse to replace: remove, retry.
          if ((await _sftp.handshake).extensions.containsKey(_posixRename)) {
            rethrow;
          }
          await _sftp.remove(to);
          await _sftp.rename(from, to);
        }
      });
      committed = true;
      temp = null;
      reservation = null;
    } catch (problem) {
      throw _map(problem, remotePath);
    } finally {
      stall.dispose();
      if (!committed) {
        await _cleanupRemote(handle, temp, reservation);
      }
    }
  }

  Future<void> _cleanupRemote(
    SftpFile? handle,
    String? temp,
    String? reservation,
  ) async {
    if (!isAlive) return;
    const limit = Duration(seconds: 5);
    Future<void> quietly(Future<void> Function() action) async {
      try {
        await action().timeout(limit);
      } catch (_) {}
    }

    if (handle != null) await quietly(handle.close);
    if (temp != null) await quietly(() => _sftp.remove(temp));
    if (reservation != null) await quietly(() => _sftp.remove(reservation));
  }

  @override
  Future<void> download(
    String remotePath,
    File localFile, {
    bool overwrite = false,
    SftpProgress? onProgress,
    SftpCancelToken? cancel,
  }) async {
    _ready(remotePath);
    if (cancel?.isCancelled ?? false) {
      throw const SftpException(SftpErrorKind.cancelled);
    }
    final stall = _Stall(stallTimeout, cancel);
    File? partial;
    RandomAccessFile? output;
    SftpFile? handle;
    StreamIterator<Uint8List>? iterator;
    var committed = false;
    try {
      if (!overwrite && await localFile.exists()) {
        throw SftpException(SftpErrorKind.exists, localFile.path);
      }
      final attrs = await _call(remotePath, () => _sftp.stat(remotePath));
      if (attrs.isDirectory) {
        throw SftpException(SftpErrorKind.wrongType, remotePath);
      }
      final total = attrs.size;
      final opened = await _call(remotePath, () => _sftp.open(remotePath));
      handle = opened;
      await localFile.parent.create(recursive: true);
      final scratch = partial = File('${localFile.path}.${_suffix()}.part');
      final sink = output = await scratch.open(mode: FileMode.writeOnly);
      final chunks = iterator = StreamIterator(
        opened.read(maxPendingRequests: 32),
      );
      var received = 0;
      stall.arm();
      while (true) {
        // Future.any prefers an already-completed chunk over the stop signal.
        final reason = stall.reason;
        if (reason != null) throw reason;
        final next = await Future.any<Object?>([
          chunks.moveNext(),
          stall.stopped,
        ]);
        if (next is! bool) {
          throw next!;
        }
        if (!next) break;
        final chunk = chunks.current;
        await sink.writeFrom(chunk);
        received += chunk.length;
        stall.arm();
        onProgress?.call(received, total);
      }
      iterator = null;
      if (total != null && received < total) {
        // The file shrank or the stream ended early.
        throw SftpException(SftpErrorKind.failed, remotePath);
      }
      await sink.flush();
      await sink.close();
      output = null;
      if (cancel?.isCancelled ?? false) {
        throw const SftpException(SftpErrorKind.cancelled);
      }
      await scratch.rename(localFile.path);
      committed = true;
    } catch (problem) {
      throw _map(problem, remotePath);
    } finally {
      stall.dispose();
      if (!committed) {
        if (iterator != null) {
          unawaited(iterator.cancel().catchError((Object _) {}));
        }
        try {
          await output?.close();
        } catch (_) {}
        try {
          if (partial != null && await partial.exists()) await partial.delete();
        } catch (_) {}
      }
      if (handle != null && isAlive) {
        unawaited(
          handle.close().timeout(operationTimeout).catchError((Object _) {}),
        );
      }
    }
  }

  // ------------------------------------------------------------------ close

  @override
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    try {
      await _sftp.close().timeout(const Duration(seconds: 3));
    } catch (_) {}
    try {
      await onClose?.call();
    } catch (_) {}
    if (ownsClient) {
      try {
        await _client.close().timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
  }
}

/// Inactivity watchdog plus cancel token as one "stop" signal that completes
/// with the [SftpException] to throw.
class _Stall {
  _Stall(this.limit, SftpCancelToken? cancel) {
    cancel?.whenCancelled.then((_) {
      _stop(const SftpException(SftpErrorKind.cancelled));
    });
  }
  final Duration limit;
  final _stopped = Completer<Object?>();
  Timer? _timer;
  bool _disposed = false;

  Future<Object?> get stopped => _stopped.future;
  SftpException? reason;

  void arm() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(
      limit,
      () => _stop(const SftpException(SftpErrorKind.timeout)),
    );
  }

  void _stop(SftpException reason) {
    if (!_disposed && !_stopped.isCompleted) {
      this.reason = reason;
      _stopped.complete(reason);
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}
