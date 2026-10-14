import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'directory_models.dart';
import 'directory_source.dart';

export 'directory_models.dart';

/// How the last check ended.
enum DirectoryOutcome {
  /// Nothing newer than the cache (also a 304 or an older mirror).
  upToDate,

  /// A newer directory was adopted.
  updated,

  /// No source could be used; the cache (if any) is untouched.
  failed,
}

/// The public provider directory as the app sees it: a validated snapshot kept
/// in memory, backed by a cache on disk and refreshed from [DirectorySource].
///
/// * [load] reads the cache and never touches the network.
/// * [refresh] checks the sources; it never throws and never removes a working
///   cache. Failures are only recorded in [lastOutcome].
/// * Everything written to disk is written to a temporary file first and then
///   renamed, so an interrupted write leaves the previous state intact.
class ProviderDirectory extends ChangeNotifier {
  ProviderDirectory({
    required DirectorySource this.source,
    required Future<Directory> Function() this._cacheDirectory,
    DateTime Function()? clock,
    this.autoInterval = const Duration(hours: 12),
    this.logoConcurrency = 4,
  }) : _clock = clock ?? DateTime.now;

  /// The production directory: GitHub with the jsDelivr mirror, cached below
  /// the application support directory.
  factory ProviderDirectory.remote() => ProviderDirectory(
    source: HttpDirectorySource(),
    cacheDirectory: () async {
      final support = await getApplicationSupportDirectory();
      return Directory(p.join(support.path, 'provider_directory'));
    },
  );

  /// A directory without network or disk: [snapshot] (and [logos]) are all
  /// there is. For tests and for hosts which opt out of downloading.
  ProviderDirectory.memory([
    DirectorySnapshot? snapshot,
    Map<String, File> logos = const {},
  ]) : source = null,
       _cacheDirectory = null,
       _clock = DateTime.now,
       autoInterval = const Duration(hours: 12),
       logoConcurrency = 4,
       _snapshot = snapshot,
       _loaded = true,
       _logos = Map.of(logos);

  final DirectorySource? source;
  final Future<Directory> Function()? _cacheDirectory;
  final DateTime Function() _clock;
  final Duration autoInterval;
  final int logoConcurrency;

  DirectorySnapshot? _snapshot;
  Map<String, File> _logos = {};
  bool _loaded = false;
  bool _checking = false;
  bool _disposed = false;
  DateTime? _checkedAt, _attemptedAt;
  DirectoryOutcome? _lastOutcome;
  String? _etag, _etagBase;
  Future<DirectoryOutcome>? _running;
  int _logoFailures = 0;

  /// False until [load] finished (the first frame never waits for it).
  bool get loaded => _loaded;

  /// The cached or downloaded directory, `null` while there is none.
  DirectorySnapshot? get snapshot => _snapshot;
  List<DirectoryProvider> get providers => _snapshot?.providers ?? const [];
  DirectoryProvider? provider(String id) => _snapshot?.provider(id);
  int get catalogVersion => _snapshot?.catalogVersion ?? 0;

  /// True while a check is running.
  bool get checking => _checking;

  /// When a check last succeeded (including "not modified").
  DateTime? get checkedAt => _checkedAt;
  DateTime? get attemptedAt => _attemptedAt;
  DirectoryOutcome? get lastOutcome => _lastOutcome;

  /// Logos which could not be downloaded or verified in the last check.
  int get logoFailures => _logoFailures;

  /// The cached logo of [id], or `null` (unknown provider, no logo, or not
  /// downloaded yet).
  File? logoFor(String id) => _logos[id];

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ---- disk ---------------------------------------------------------------

  Future<Directory> _root() async {
    final root = await _cacheDirectory!();
    await root.create(recursive: true);
    return root;
  }

  Future<void> _writeAtomic(File target, List<int> bytes) async {
    await target.parent.create(recursive: true);
    final temp = File('${target.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(target.path);
  }

  File _logoFile(Directory root, DirectoryProvider provider) => File(
    p.join(
      root.path,
      'logos',
      '${provider.id}-${provider.logo!.shortHash}.png',
    ),
  );

  /// Cached logo files which exist with the size the index declares.
  Future<Map<String, File>> _scanLogos(
    Directory root,
    DirectorySnapshot snapshot,
  ) async {
    final found = <String, File>{};
    for (final provider in snapshot.providers) {
      if (provider.logo == null) continue;
      final file = _logoFile(root, provider);
      try {
        if (await file.length() == provider.logo!.bytes) {
          found[provider.id] = file;
        }
      } on FileSystemException {
        // Not downloaded (yet).
      }
    }
    return found;
  }

  /// Reads the cache. Safe to call repeatedly; never uses the network and
  /// never throws (a damaged cache is treated as no cache).
  Future<void> load() async {
    if (source == null) return;
    try {
      final root = await _root();
      final meta = await _readMeta(root);
      final index = File(p.join(root.path, 'index.json'));
      DirectorySnapshot? snapshot;
      if (await index.exists()) {
        try {
          snapshot = DirectorySnapshot.parse(await index.readAsString());
        } catch (_) {
          snapshot = null; // The next check replaces it.
        }
      }
      if (snapshot != null) {
        _snapshot = snapshot;
        _logos = await _scanLogos(root, snapshot);
      }
      _etag = snapshot == null ? null : meta['etag'] as String?;
      _etagBase = meta['base'] as String?;
      _checkedAt = snapshot == null ? null : _date(meta['checkedAt']);
      _attemptedAt = _date(meta['attemptedAt']);
      _lastOutcome = DirectoryOutcome.values.asNameMap()[meta['outcome']];
    } catch (_) {
      // No usable cache directory: behave as an empty directory.
    } finally {
      _loaded = true;
      _notify();
    }
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  Future<Map<String, Object?>> _readMeta(Directory root) async {
    try {
      final decoded = jsonDecode(
        await File(p.join(root.path, 'meta.json')).readAsString(),
      );
      return decoded is Map ? Map<String, Object?>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeMeta(Directory root) => _writeAtomic(
    File(p.join(root.path, 'meta.json')),
    utf8.encode(
      jsonEncode({
        'etag': _etag,
        'base': _etagBase,
        'checkedAt': _checkedAt?.toUtc().toIso8601String(),
        'attemptedAt': _attemptedAt?.toUtc().toIso8601String(),
        'outcome': _lastOutcome?.name,
      }),
    ),
  );

  // ---- checking -----------------------------------------------------------

  /// Whether an automatic check is due: never checked, or the last successful
  /// one is older than [autoInterval].
  bool get autoRefreshDue {
    final last = _checkedAt;
    return last == null || _clock().difference(last) >= autoInterval;
  }

  /// The launch-time check: does nothing when [enabled] is false or the cache
  /// is fresh. Never throws.
  Future<void> autoRefresh({required bool enabled}) async {
    if (!enabled || source == null || !autoRefreshDue) return;
    await refresh();
  }

  /// Checks the sources now. Concurrent calls share one check.
  Future<DirectoryOutcome> refresh() {
    if (source == null) return Future.value(DirectoryOutcome.upToDate);
    return _running ??= _check().whenComplete(() {
      _running = null;
      _checking = false;
      _notify();
    });
  }

  Future<DirectoryOutcome> _check() async {
    _checking = true;
    _logoFailures = 0;
    _notify();
    final now = _clock();
    try {
      final root = await _root();
      final cached = _snapshot;
      DirectorySnapshot? fetched;
      Uri? usedBase;
      String? etag, raw;
      Object? error;
      for (final base in source!.bases) {
        try {
          // A validator belongs to the server which issued it.
          final sendEtag = cached != null && _etagBase == base.toString()
              ? _etag
              : null;
          final response = await source!.fetchIndex(base, etag: sendEtag);
          if (response.notModified) {
            if (cached == null) {
              throw const DirectoryFormatException('304 without cache');
            }
            usedBase = base;
            etag = sendEtag;
            break;
          }
          fetched = DirectorySnapshot.parse(response.body!);
          raw = response.body;
          usedBase = base;
          etag = response.etag;
          break;
        } catch (e) {
          if (kDebugMode) debugPrint('Provider directory: $base failed: $e');
          error = e;
        }
      }
      if (usedBase == null) {
        if (kDebugMode) debugPrint('Provider directory unavailable: $error');
        return await _finish(root, DirectoryOutcome.failed, now);
      }

      var outcome = DirectoryOutcome.upToDate;
      var effective = cached;
      if (fetched != null &&
          (cached == null || fetched.catalogVersion >= cached.catalogVersion)) {
        // Same version again is not an update; an older one is ignored.
        outcome =
            cached == null || fetched.catalogVersion > cached.catalogVersion
            ? DirectoryOutcome.updated
            : DirectoryOutcome.upToDate;
        effective = fetched;
      }
      if (effective == null) {
        return await _finish(root, DirectoryOutcome.failed, now);
      }

      // Logos first, then the index which refers to them, then the metadata.
      final logos = await _scanLogos(root, effective);
      await _downloadLogos(root, effective, usedBase, logos);
      if (!identical(effective, cached)) {
        await _writeAtomic(
          File(p.join(root.path, 'index.json')),
          utf8.encode(raw!),
        );
        _snapshot = effective;
        _etag = etag;
        _etagBase = usedBase.toString();
      }
      _logos = logos;
      await _prune(root, effective);
      return await _finish(root, outcome, now);
    } catch (e) {
      if (kDebugMode) debugPrint('Provider directory check failed: $e');
      return _lastOutcome = DirectoryOutcome.failed;
    }
  }

  Future<DirectoryOutcome> _finish(
    Directory root,
    DirectoryOutcome outcome,
    DateTime now,
  ) async {
    _lastOutcome = outcome;
    _attemptedAt = now;
    if (outcome != DirectoryOutcome.failed) _checkedAt = now;
    try {
      await _writeMeta(root);
    } catch (_) {
      // Metadata is advisory; the in-memory state already reflects the check.
    }
    return outcome;
  }

  Future<void> _downloadLogos(
    Directory root,
    DirectorySnapshot snapshot,
    Uri preferred,
    Map<String, File> logos,
  ) async {
    final pending = [
      for (final provider in snapshot.providers)
        if (provider.logo != null && !logos.containsKey(provider.id)) provider,
    ];
    final bases = [
      preferred,
      for (final base in source!.bases)
        if (base != preferred) base,
    ];
    var next = 0;
    Future<void> worker() async {
      while (next < pending.length) {
        final provider = pending[next++];
        final file = await _fetchLogo(root, provider, bases);
        if (file == null) {
          _logoFailures++;
        } else {
          logos[provider.id] = file;
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < logoConcurrency.clamp(1, 16); i++) worker(),
    ]);
  }

  static const _pngMagic = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

  Future<File?> _fetchLogo(
    Directory root,
    DirectoryProvider provider,
    List<Uri> bases,
  ) async {
    final logo = provider.logo!;
    for (final base in bases) {
      try {
        final bytes = await source!.fetchFile(
          base,
          logo.path,
          maxBytes: DirectorySnapshot.maxLogoBytes,
        );
        if (bytes.length != logo.bytes ||
            bytes.length < _pngMagic.length ||
            !_hasPngMagic(bytes) ||
            crypto.sha256.convert(bytes).toString() != logo.sha256) {
          continue; // Wrong content: never stored; try the mirror.
        }
        final file = _logoFile(root, provider);
        await _writeAtomic(file, bytes);
        return file;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static bool _hasPngMagic(Uint8List bytes) {
    for (var i = 0; i < _pngMagic.length; i++) {
      if (bytes[i] != _pngMagic[i]) return false;
    }
    return true;
  }

  /// Removes logo files the current index does not refer to (and leftovers of
  /// interrupted writes).
  Future<void> _prune(Directory root, DirectorySnapshot snapshot) async {
    final keep = {
      for (final provider in snapshot.providers)
        if (provider.logo != null) p.basename(_logoFile(root, provider).path),
    };
    final logos = Directory(p.join(root.path, 'logos'));
    if (!await logos.exists()) return;
    await for (final entity in logos.list()) {
      if (entity is File && !keep.contains(p.basename(entity.path))) {
        try {
          await entity.delete();
        } on FileSystemException {
          // Retried by the next check.
        }
      }
    }
  }
}
