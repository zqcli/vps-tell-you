import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:vps_tell_you/connections/sftp_session.dart';
import 'package:vps_tell_you/connections/sftp_support.dart';

class _Node {
  _Node.dir(this.mtime) : bytes = null, isLink = false;
  _Node.file(this.bytes, this.mtime) : isLink = false;
  _Node.link(this.mtime) : bytes = null, isLink = true;
  Uint8List? bytes;
  DateTime mtime;
  bool isLink;
  String mode = 'rw-r--r--';
  bool get isDir => bytes == null && !isLink;
}

/// In-memory remote file system implementing the full [SftpSession] contract
/// closely enough for UI tests: same typed errors, same overwrite rules.
class FakeSftpSession implements SftpSession {
  FakeSftpSession() {
    _nodes['/'] = _Node.dir(_clock);
  }
  final _nodes = <String, _Node>{};
  var _tick = 0;
  DateTime get _clock =>
      DateTime.utc(2026, 10, 11, 12).add(Duration(minutes: _tick++));
  bool alive = true, closed = false;
  String homePath = '/';

  /// Every call, "op:path".
  final calls = <String>[];

  /// Next call of the named op throws this error once.
  final failNext = <String, SftpErrorKind>{};

  /// Completes to let a download / upload progress past its first chunk.
  Completer<void>? hold;

  Directory? downloadSource;

  FakeSftpSession dir(String path) {
    _nodes[path] = _Node.dir(_clock);
    return this;
  }

  FakeSftpSession file(String path, [String text = '']) {
    _nodes[path] = _Node.file(Uint8List.fromList(utf8.encode(text)), _clock);
    return this;
  }

  FakeSftpSession binary(String path, List<int> bytes) {
    _nodes[path] = _Node.file(Uint8List.fromList(bytes), _clock);
    return this;
  }

  FakeSftpSession link(String path) {
    _nodes[path] = _Node.link(_clock);
    return this;
  }

  /// A file with a size but no content (for the "too large" paths).
  FakeSftpSession big(String path, int size) {
    _nodes[path] = _Node.file(Uint8List(0), _clock);
    _sizes[path] = size;
    return this;
  }

  final _sizes = <String, int>{};

  bool exists(String path) => _nodes.containsKey(path);
  String text(String path) => utf8.decode(_nodes[path]!.bytes!);
  List<int> bytesOf(String path) => _nodes[path]!.bytes!;
  List<String> paths() => _nodes.keys.toList()..sort();

  /// Simulates another client modifying the file.
  void touch(String path, String text) {
    _nodes[path]!
      ..bytes = Uint8List.fromList(utf8.encode(text))
      ..mtime = _clock;
  }

  void _enter(String op, String path) {
    calls.add('$op:$path');
    if (!alive || closed) {
      throw const SftpException(SftpErrorKind.connectionLost);
    }
    final fail = failNext.remove(op);
    if (fail != null) throw SftpException(fail, path);
  }

  SftpEntry _entry(String path, _Node node) {
    final size = _sizes[path] ?? node.bytes?.length;
    return SftpEntry(
      name: path == '/' ? '/' : SftpPath.basename(path),
      path: path,
      isDir: node.isDir,
      isFile: !node.isDir && !node.isLink,
      isLink: node.isLink,
      size: node.isDir ? 4096 : size,
      mtime: node.mtime,
      mode:
          '${node.isDir
              ? 'd'
              : node.isLink
              ? 'l'
              : '-'}${node.mode}',
    );
  }

  _Node _need(String path) {
    final node = _nodes[path];
    if (node == null) throw SftpException(SftpErrorKind.notFound, path);
    return node;
  }

  void _needParent(String path) {
    final parent = _nodes[SftpPath.parent(path)];
    if (parent == null || !parent.isDir) {
      throw SftpException(SftpErrorKind.notFound, path);
    }
  }

  Iterable<String> _children(String path) sync* {
    final prefix = path == '/' ? '/' : '$path/';
    for (final key in _nodes.keys) {
      if (key != path &&
          key.startsWith(prefix) &&
          !key.substring(prefix.length).contains('/')) {
        yield key;
      }
    }
  }

  @override
  bool get isAlive => alive && !closed;

  @override
  Future<String> home() async {
    _enter('home', '.');
    return homePath;
  }

  @override
  Future<String> realpath(String path) async {
    _enter('realpath', path);
    return path;
  }

  @override
  Future<List<SftpEntry>> list(String path) async {
    _enter('list', path);
    final node = _need(path);
    if (!node.isDir) throw SftpException(SftpErrorKind.wrongType, path);
    return [for (final child in _children(path)) _entry(child, _nodes[child]!)];
  }

  @override
  Future<SftpEntry> stat(String path) async {
    _enter('stat', path);
    return _entry(path, _need(path));
  }

  @override
  Future<void> mkdir(String path) async {
    _enter('mkdir', path);
    _needParent(path);
    if (exists(path)) throw SftpException(SftpErrorKind.exists, path);
    _nodes[path] = _Node.dir(_clock);
  }

  @override
  Future<void> createEmptyFile(String path) async {
    _enter('create', path);
    _needParent(path);
    if (exists(path)) throw SftpException(SftpErrorKind.exists, path);
    _nodes[path] = _Node.file(Uint8List(0), _clock);
  }

  @override
  Future<void> rename(String from, String to) async {
    _enter('rename', '$from>$to');
    final node = _need(from);
    _needParent(to);
    if (exists(to)) throw SftpException(SftpErrorKind.exists, to);
    final moved = {
      for (final key in _nodes.keys)
        if (key == from || key.startsWith('$from/')) key,
    };
    for (final key in moved) {
      _nodes[to + key.substring(from.length)] = _nodes.remove(key)!;
    }
    node.mtime = _clock;
  }

  @override
  Future<void> deleteFile(String path) async {
    _enter('deleteFile', path);
    final node = _need(path);
    if (node.isDir) throw SftpException(SftpErrorKind.wrongType, path);
    _nodes.remove(path);
  }

  @override
  Future<void> deleteEmptyDirectory(String path) async {
    _enter('deleteDir', path);
    final node = _need(path);
    if (!node.isDir) throw SftpException(SftpErrorKind.wrongType, path);
    if (_children(path).isNotEmpty) {
      throw SftpException(SftpErrorKind.notEmpty, path);
    }
    _nodes.remove(path);
  }

  @override
  Future<int> deleteRecursive(
    String path, {
    int maxEntries = sftpDefaultRecursiveLimit,
    SftpCancelToken? cancel,
  }) async {
    _enter('deleteRecursive', path);
    _need(path);
    final doomed = _nodes.keys
        .where((key) => key == path || key.startsWith('$path/'))
        .toList();
    if (doomed.length > maxEntries) {
      throw SftpException(SftpErrorKind.tooManyEntries, path);
    }
    doomed.forEach(_nodes.remove);
    return doomed.length;
  }

  @override
  Future<SftpTextFile> readText(
    String path, {
    int maxBytes = sftpDefaultTextLimit,
  }) async {
    _enter('readText', path);
    final node = _need(path);
    if (node.isDir) throw SftpException(SftpErrorKind.wrongType, path);
    if ((_sizes[path] ?? node.bytes!.length) > maxBytes) {
      throw SftpException(SftpErrorKind.tooLarge, path);
    }
    try {
      final text = utf8.decode(node.bytes!);
      if (text.contains('\u0000')) throw const FormatException();
      return SftpTextFile(
        text: text,
        size: node.bytes!.length,
        mtime: node.mtime,
      );
    } on FormatException {
      throw SftpException(SftpErrorKind.notText, path);
    }
  }

  @override
  Future<void> writeText(
    String path,
    String content, {
    required bool overwrite,
    int maxBytes = sftpDefaultTextLimit,
  }) async {
    _enter('writeText', path);
    _needParent(path);
    if (!overwrite && exists(path)) {
      throw SftpException(SftpErrorKind.exists, path);
    }
    _nodes[path] = _Node.file(Uint8List.fromList(utf8.encode(content)), _clock);
  }

  @override
  Future<void> download(
    String remotePath,
    File localFile, {
    bool overwrite = false,
    SftpProgress? onProgress,
    SftpCancelToken? cancel,
  }) async {
    _enter('download', remotePath);
    final node = _need(remotePath);
    if (node.isDir) throw SftpException(SftpErrorKind.wrongType, remotePath);
    if (!overwrite && localFile.existsSync()) {
      throw SftpException(SftpErrorKind.exists, localFile.path);
    }
    final total = _sizes[remotePath] ?? node.bytes!.length;
    onProgress?.call(total ~/ 2, total);
    await _wait(cancel);
    await localFile.parent.create(recursive: true);
    await localFile.writeAsBytes(node.bytes!);
    onProgress?.call(total, total);
  }

  @override
  Future<void> upload(
    File localFile,
    String remotePath, {
    bool overwrite = false,
    SftpProgress? onProgress,
    SftpCancelToken? cancel,
  }) async {
    _enter('upload', remotePath);
    _needParent(remotePath);
    if (!overwrite && exists(remotePath)) {
      throw SftpException(SftpErrorKind.exists, remotePath);
    }
    final bytes = await localFile.readAsBytes();
    onProgress?.call(bytes.length ~/ 2, bytes.length);
    await _wait(cancel);
    _nodes[remotePath] = _Node.file(bytes, _clock);
    onProgress?.call(bytes.length, bytes.length);
  }

  Future<void> _wait(SftpCancelToken? cancel) async {
    final gate = hold;
    if (gate != null) {
      await Future.any([gate.future, ?cancel?.whenCancelled]);
    }
    if (cancel?.isCancelled ?? false) {
      throw const SftpException(SftpErrorKind.cancelled);
    }
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

/// Picker / share boundary for tests: nothing opens a real UI.
class FakeLocalFiles implements SftpLocalFiles {
  FakeLocalFiles(this.root);
  final Directory root;
  List<File> picks = [];
  final shared = <String>[];
  final discarded = <String>[];
  int picked = 0;

  @override
  Future<List<File>> pickUploads() async {
    picked++;
    return picks;
  }

  @override
  Future<Directory> downloadsDirectory() async =>
      Directory('${root.path}/$sftpDownloadsFolder').create(recursive: true);

  @override
  Future<void> discardPicked(File file) async => discarded.add(file.path);

  @override
  Future<bool> share(File file, {Rect? origin}) async {
    shared.add(file.path);
    return true;
  }
}
