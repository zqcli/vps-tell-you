import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:vps_tell_you/providers/directory_source.dart';
import 'package:vps_tell_you/providers/provider_directory.dart';

import 'support/catalog_fixture.dart';

final _raw = Uri.parse('https://raw.example.test/catalog/');
final _mirror = Uri.parse('https://mirror.example.test/catalog/');

/// A valid-looking PNG: the real signature followed by [seed]-dependent bytes.
Uint8List png(int seed, {int extra = 64}) => Uint8List.fromList([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, //
  for (var i = 0; i < extra; i++) (seed * 31 + i) & 0xff,
]);

Map<String, Object?> logoMeta(String id, Uint8List bytes) => {
  'path': 'providers/$id/logo.png',
  'sha256': sha256.convert(bytes).toString(),
  'bytes': bytes.length,
};

/// What one base URL serves.
class FakeSite {
  String? index;
  String? etag;
  int status = 200;
  Map<String, Uint8List> files = {};
  Map<String, int> fileStatus = {};
  Duration delay = Duration.zero;
}

/// A scripted network: one [FakeSite] per base, and a log of every request.
class FakeNetwork {
  final sites = {_raw.toString(): FakeSite(), _mirror.toString(): FakeSite()};
  final requests = <http.Request>[];
  int running = 0, maxRunning = 0;
  Object? failure; // thrown for every request when set
  final unreachable = <String>{}; // bases whose requests throw

  FakeSite get raw => sites[_raw.toString()]!;
  FakeSite get mirror => sites[_mirror.toString()]!;

  /// Serves [version] on [site], with a logo per provider id.
  void serve(
    FakeSite site, {
    int version = 1,
    List<String> ids = const ['fixture-cloud', 'empty-host'],
    String? tag,
    Map<String, Uint8List>? logos,
  }) {
    final files = <String, Uint8List>{};
    final entries = <Map<String, Object?>>[];
    for (var i = 0; i < ids.length; i++) {
      final bytes = logos?[ids[i]] ?? png(i + version * 10);
      files['providers/${ids[i]}/logo.png'] = bytes;
      entries.add(directoryEntry(ids[i], logo: logoMeta(ids[i], bytes)));
    }
    site.files = files;
    site.fileStatus = {};
    site.index = jsonEncode(
      directoryIndexJson(version: version, providers: entries),
    );
    site.etag = tag ?? '"v$version"';
    site.status = 200;
  }

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    if (failure != null) throw failure!;
    if (unreachable.any((b) => request.url.toString().startsWith(b))) {
      throw const SocketException('unreachable');
    }
    running++;
    if (running > maxRunning) maxRunning = running;
    try {
      final base = sites.keys.firstWhere(
        (b) => request.url.toString().startsWith(b),
      );
      final site = sites[base]!;
      if (site.delay > Duration.zero) await Future<void>.delayed(site.delay);
      final path = request.url.toString().substring(base.length);
      if (path == 'index.json') {
        if (site.status != 200 || site.index == null) {
          return http.Response('', site.status == 200 ? 404 : site.status);
        }
        if (site.etag != null &&
            request.headers['If-None-Match'] == site.etag) {
          return http.Response('', 304);
        }
        return http.Response.bytes(
          utf8.encode(site.index!),
          200,
          headers: {if (site.etag != null) 'etag': site.etag!},
        );
      }
      final status = site.fileStatus[path];
      if (status != null) return http.Response('', status);
      final bytes = site.files[path];
      return bytes == null
          ? http.Response('', 404)
          : http.Response.bytes(bytes, 200);
    } finally {
      running--;
    }
  }

  List<http.Request> to(Uri base, {String? path}) => [
    for (final r in requests)
      if (r.url.toString().startsWith(base.toString()) &&
          (path == null || r.url.path.endsWith(path)))
        r,
  ];
}

void main() {
  late Directory cache;
  late FakeNetwork net;
  late DateTime now;
  final created = <ProviderDirectory>[];

  ProviderDirectory open({
    Duration timeout = const Duration(seconds: 10),
    int logoConcurrency = 4,
    int maxIndexBytes = 1024 * 1024,
  }) {
    final directory = ProviderDirectory(
      source: HttpDirectorySource(
        client: MockClient(net.handle),
        bases: [_raw, _mirror],
        timeout: timeout,
        maxIndexBytes: maxIndexBytes,
      ),
      cacheDirectory: () async => Directory(p.join(cache.path, 'directory')),
      clock: () => now,
      logoConcurrency: logoConcurrency,
    );
    created.add(directory);
    return directory;
  }

  Directory logos() => Directory(p.join(cache.path, 'directory', 'logos'));
  List<String> logoNames() => logos().existsSync()
      ? (logos().listSync().map((e) => p.basename(e.path)).toList()..sort())
      : [];

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('directory-');
    net = FakeNetwork();
    now = DateTime.utc(2026, 10, 14, 8);
  });
  tearDown(() async {
    for (final directory in created) {
      directory.dispose();
    }
    created.clear();
    await cache.delete(recursive: true);
  });

  group('first fetch', () {
    test('downloads the index and the logos into the cache', () async {
      net.serve(net.raw);
      final directory = open();
      await directory.load();
      expect(directory.loaded, isTrue);
      expect(directory.snapshot, isNull, reason: 'nothing cached yet');

      expect(await directory.refresh(), DirectoryOutcome.updated);
      expect(directory.catalogVersion, 1);
      expect(directory.providers.map((p) => p.id), [
        'fixture-cloud',
        'empty-host',
      ]);
      expect(directory.lastOutcome, DirectoryOutcome.updated);
      expect(directory.checkedAt, now);
      final file = directory.logoFor('fixture-cloud')!;
      expect(file.existsSync(), isTrue);
      expect(
        p.basename(file.path),
        startsWith('fixture-cloud-'),
        reason: 'logos/<id>-<sha8>.png',
      );
      expect(file.readAsBytesSync(), net.raw.files.values.first);
      expect(logoNames(), hasLength(2));
      expect(
        File(p.join(cache.path, 'directory', 'index.json')).existsSync(),
        isTrue,
      );
      // Only the three kinds of file; nothing half written is left behind.
      expect(
        Directory(p.join(cache.path, 'directory'))
            .listSync(recursive: true)
            .map((e) => e.path)
            .where((path) => path.endsWith('.tmp')),
        isEmpty,
      );
    });

    test('requests carry no credentials and the right headers', () async {
      net.serve(net.raw);
      await open().refresh();
      final index = net.to(_raw, path: 'index.json').single;
      expect(index.method, 'GET');
      expect(index.headers['Accept'], 'application/json');
      expect(index.headers.containsKey('If-None-Match'), isFalse);
      for (final request in net.requests) {
        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(anyOf(contains('cookie'), contains('authorization'))),
        );
        expect(request.url.query, isEmpty, reason: 'no identifiers');
        expect(request.url.scheme, 'https');
      }
      expect(net.to(_mirror), isEmpty, reason: 'the mirror is only a fallback');
    });

    test('the cache survives a restart and needs no network', () async {
      net.serve(net.raw);
      await open().refresh();
      net.requests.clear();
      net.failure = const SocketException('offline');

      final next = open();
      expect(next.snapshot, isNull);
      await next.load();
      expect(next.catalogVersion, 1);
      expect(next.providers, hasLength(2));
      expect(next.logoFor('empty-host'), isNotNull);
      expect(next.lastOutcome, DirectoryOutcome.updated);
      expect(next.checkedAt, now);
      expect(net.requests, isEmpty);
    });
  });

  group('conditional requests', () {
    test('304 keeps the cache and downloads nothing', () async {
      net.serve(net.raw, tag: '"abc"');
      final directory = open();
      await directory.refresh();
      net.requests.clear();
      now = now.add(const Duration(hours: 13));

      expect(await directory.refresh(), DirectoryOutcome.upToDate);
      final request = net.requests.single;
      expect(request.headers['If-None-Match'], '"abc"');
      expect(directory.lastOutcome, DirectoryOutcome.upToDate);
      expect(directory.checkedAt, now, reason: 'a 304 is a successful check');
      expect(directory.catalogVersion, 1);
      expect(directory.logoFor('fixture-cloud'), isNotNull);
    });

    test('the validator is persisted across restarts', () async {
      net.serve(net.raw, tag: '"persist"');
      await open().refresh();
      net.requests.clear();
      final next = open();
      await next.load();
      expect(await next.refresh(), DirectoryOutcome.upToDate);
      expect(net.requests.single.headers['If-None-Match'], '"persist"');
    });

    test('a changed document replaces the cache', () async {
      net.serve(net.raw);
      final directory = open();
      await directory.refresh();
      net.serve(net.raw, version: 2, ids: ['fixture-cloud', 'new-one']);
      expect(await directory.refresh(), DirectoryOutcome.updated);
      expect(directory.catalogVersion, 2);
      expect(directory.provider('new-one'), isNotNull);
      expect(directory.provider('empty-host'), isNull);
    });
  });

  group('mirrors', () {
    test('an unreachable first base falls back to the mirror', () async {
      net.raw.status = 503;
      net.serve(net.mirror);
      net.raw.index = null;
      net.raw.status = 503;
      final directory = open();
      expect(await directory.refresh(), DirectoryOutcome.updated);
      expect(net.to(_raw, path: 'index.json'), hasLength(1));
      expect(net.to(_mirror, path: 'index.json'), hasLength(1));
      expect(net.to(_mirror, path: 'logo.png'), hasLength(2));
      expect(directory.logoFor('fixture-cloud'), isNotNull);
    });

    test('a network error on the first base also falls back', () async {
      net.serve(net.mirror);
      net.unreachable.add(_raw.toString());
      final directory = open();
      expect(await directory.refresh(), DirectoryOutcome.updated);
      expect(directory.providers, hasLength(2));
    });

    test('bad JSON from the first base falls back to the mirror', () async {
      net.serve(net.raw);
      net.raw.index = '{nope';
      net.serve(net.mirror, version: 4);
      final directory = open();
      expect(await directory.refresh(), DirectoryOutcome.updated);
      expect(directory.catalogVersion, 4);
    });

    test('a validator is only sent to the server which issued it', () async {
      net.raw.status = 500;
      net.serve(net.mirror, tag: '"mirror-tag"');
      final directory = open();
      await directory.refresh();
      net.requests.clear();
      // Raw GitHub recovers and serves the same version with its own tag.
      net.serve(net.raw, tag: '"raw-tag"');
      expect(await directory.refresh(), DirectoryOutcome.upToDate);
      final toRaw = net.to(_raw, path: 'index.json').single;
      expect(
        toRaw.headers.containsKey('If-None-Match'),
        isFalse,
        reason: 'the mirror\'s tag is meaningless to raw GitHub',
      );
      net.requests.clear();
      expect(await directory.refresh(), DirectoryOutcome.upToDate);
      expect(
        net.to(_raw, path: 'index.json').single.headers['If-None-Match'],
        '"raw-tag"',
      );
    });

    test('every source failing is recorded and keeps the cache', () async {
      net.serve(net.raw);
      final directory = open();
      await directory.refresh();
      final checked = directory.checkedAt;
      now = now.add(const Duration(days: 2));
      net.raw.status = 500;
      net.mirror.status = 404;
      expect(await directory.refresh(), DirectoryOutcome.failed);
      expect(directory.lastOutcome, DirectoryOutcome.failed);
      expect(directory.checkedAt, checked, reason: 'only successes count');
      expect(directory.attemptedAt, now);
      expect(directory.catalogVersion, 1);
      expect(directory.logoFor('fixture-cloud'), isNotNull);
      // The failure survives a restart for the settings row.
      final next = open();
      await next.load();
      expect(next.lastOutcome, DirectoryOutcome.failed);
      expect(next.providers, hasLength(2));
    });
  });

  group('validation', () {
    test('bad entries are skipped, the rest is used', () async {
      final good = png(1);
      final goodLogo = logoMeta('good-one', good);
      net.raw.files = {'providers/good-one/logo.png': good};
      net.raw.etag = '"x"';
      net.raw.index = jsonEncode(
        directoryIndexJson(
          providers: [
            directoryEntry('good-one', logo: goodLogo),
            directoryEntry('Bad_ID'),
            directoryEntry('x'), // too short
            {
              ...directoryEntry('plain-http'),
              'website': 'http://insecure.test',
            },
            {...directoryEntry('bad-kind'), 'kind': 'saas'},
            {...directoryEntry('bad-region'), 'region': 'mars'},
            {
              ...directoryEntry('no-en'),
              'name': {'zh': '只有中文'},
            },
            directoryEntry(
              'bad-path',
              logo: {...logoMeta('bad-path', good), 'path': '../escape.png'},
            ),
            directoryEntry(
              'bad-sha',
              logo: {...logoMeta('bad-sha', good), 'sha256': 'zz'},
            ),
            directoryEntry(
              'huge-logo',
              logo: {...logoMeta('huge-logo', good), 'bytes': 1 << 20},
            ),
            'not an object',
            directoryEntry('good-one'), // duplicate id
          ],
        ),
      );
      final directory = open();
      expect(await directory.refresh(), DirectoryOutcome.updated);
      expect(directory.providers.map((p) => p.id), ['good-one']);
      expect(directory.snapshot!.skipped, 11);
      expect(directory.logoFor('good-one'), isNotNull);
    });

    test(
      'unsupported schemaVersion or missing catalogVersion is rejected',
      () async {
        for (final bad in [
          {...directoryIndexJson(), 'schemaVersion': 2},
          {...directoryIndexJson()}..remove('catalogVersion'),
          {...directoryIndexJson(), 'providers': {}},
          {...directoryIndexJson(), 'generatedAt': 5},
        ]) {
          net.raw.index = jsonEncode(bad);
          net.raw.etag = null;
          net.mirror.status = 500;
          final directory = open();
          expect(await directory.refresh(), DirectoryOutcome.failed);
          expect(directory.snapshot, isNull);
          created.remove(directory);
          directory.dispose();
          await cache.delete(recursive: true);
          await cache.create();
        }
      },
    );

    test('unknown fields are ignored', () async {
      final bytes = png(2);
      net.raw.files = {'providers/fixture-cloud/logo.png': bytes};
      net.raw.index = jsonEncode({
        ...directoryIndexJson(
          providers: [
            {
              ...directoryEntry(
                'fixture-cloud',
                logo: logoMeta('fixture-cloud', bytes),
              ),
              'futureField': {'a': 1},
            },
          ],
        ),
        'another': true,
      });
      final directory = open();
      expect(await directory.refresh(), DirectoryOutcome.updated);
      expect(directory.providers, hasLength(1));
      expect(directory.snapshot!.skipped, 0);
    });

    test('a logo whose sha256 does not match is never stored', () async {
      net.serve(net.raw);
      final tampered = png(99);
      net.raw.files['providers/fixture-cloud/logo.png'] = tampered;
      final directory = open();
      expect(await directory.refresh(), DirectoryOutcome.updated);
      expect(directory.logoFor('fixture-cloud'), isNull);
      expect(directory.logoFor('empty-host'), isNotNull);
      expect(directory.logoFailures, 1);
      expect(
        directory.provider('fixture-cloud'),
        isNotNull,
        reason: 'the provider is listed, with initials',
      );
      expect(logoNames(), hasLength(1));

      // The next check repairs it even though the index is unchanged (304).
      net.serve(net.raw, tag: net.raw.etag);
      final good = net.raw.files['providers/fixture-cloud/logo.png']!;
      expect(good, isNot(tampered));
      expect(await directory.refresh(), DirectoryOutcome.upToDate);
      expect(directory.logoFor('fixture-cloud'), isNotNull);
      expect(directory.logoFailures, 0);
    });

    test(
      'a logo which is not a PNG is rejected even with a matching hash',
      () async {
        final notPng = Uint8List.fromList(utf8.encode('GIF89a-not-a-png'));
        net.serve(net.raw, logos: {'fixture-cloud': notPng});
        final directory = open();
        await directory.refresh();
        expect(directory.logoFor('fixture-cloud'), isNull);
        expect(directory.logoFailures, 1);
      },
    );

    test(
      'a logo is tried on the mirror when the first base serves junk',
      () async {
        net.serve(net.raw);
        net.serve(net.mirror);
        net.raw.files['providers/fixture-cloud/logo.png'] = png(77);
        net.mirror.etag = '"m"';
        final directory = open();
        await directory.refresh();
        expect(directory.logoFor('fixture-cloud'), isNotNull);
        expect(net.to(_mirror, path: 'logo.png'), hasLength(1));
      },
    );
  });

  group('size caps', () {
    test('an index above the cap is rejected (declared length)', () async {
      net.serve(net.raw);
      net.raw.index = jsonEncode(
        directoryIndexJson(
          providers: [
            for (var i = 0; i < 4000; i++)
              directoryEntry(
                'filler-${i.toString().padLeft(4, '0')}',
                descriptionEn: 'x' * 300,
              ),
          ],
        ),
      );
      expect(net.raw.index!.length, greaterThan(1024 * 1024));
      net.mirror.status = 500;
      final directory = open();
      expect(await directory.refresh(), DirectoryOutcome.failed);
      expect(directory.snapshot, isNull);
      expect(
        Directory(p.join(cache.path, 'directory')).existsSync() &&
            File(p.join(cache.path, 'directory', 'index.json')).existsSync(),
        isFalse,
      );
    });

    test(
      'an index without a Content-Length is cut off while streaming',
      () async {
        var sent = 0;
        final client = MockClient.streaming((request, _) async {
          Stream<List<int>> chunks() async* {
            for (var i = 0; i < 64; i++) {
              sent += 64 * 1024;
              yield Uint8List(64 * 1024);
            }
          }

          return http.StreamedResponse(chunks(), 200);
        });
        final source = HttpDirectorySource(client: client, bases: [_raw]);
        await expectLater(
          source.fetchIndex(_raw),
          throwsA(isA<DirectoryFetchException>()),
        );
        expect(sent, lessThan(4 * 1024 * 1024), reason: 'aborted early');
      },
    );

    test('a logo above 128 KiB is rejected', () async {
      final big = Uint8List(130 * 1024)..setRange(0, 8, png(0));
      net.serve(net.raw, logos: {'fixture-cloud': big});
      // Declared size lies: the index promises a small file.
      final doc = jsonDecode(net.raw.index!) as Map<String, dynamic>;
      (doc['providers'] as List)[0]['logo']['bytes'] = 100;
      net.raw.index = jsonEncode(doc);
      final directory = open();
      await directory.refresh();
      expect(directory.logoFor('fixture-cloud'), isNull);
      expect(directory.logoFailures, 1);
      expect(directory.logoFor('empty-host'), isNotNull);
    });
  });

  group('version regression', () {
    test('an older catalogVersion is ignored', () async {
      net.serve(net.raw, version: 5);
      final directory = open();
      await directory.refresh();
      final index = File(p.join(cache.path, 'directory', 'index.json'));
      final before = index.readAsStringSync();
      net.serve(net.raw, version: 3, ids: ['stale-host']);
      expect(await directory.refresh(), DirectoryOutcome.upToDate);
      expect(directory.catalogVersion, 5);
      expect(directory.provider('stale-host'), isNull);
      expect(index.readAsStringSync(), before);
      // And after a restart too.
      final next = open();
      await next.load();
      expect(next.catalogVersion, 5);
    });

    test('the same version again is not an update', () async {
      net.serve(net.raw, version: 2, tag: '"a"');
      final directory = open();
      await directory.refresh();
      net.serve(net.raw, version: 2, tag: '"b"');
      expect(await directory.refresh(), DirectoryOutcome.upToDate);
    });
  });

  group('offline', () {
    test('network errors keep the cache and are recorded', () async {
      net.serve(net.raw);
      final directory = open();
      await directory.refresh();
      net.failure = const SocketException('Network is unreachable');
      now = now.add(const Duration(hours: 20));
      expect(await directory.refresh(), DirectoryOutcome.failed);
      expect(directory.lastOutcome, DirectoryOutcome.failed);
      expect(directory.providers, hasLength(2));
      expect(directory.logoFor('fixture-cloud'), isNotNull);
      expect(directory.checking, isFalse);
    });

    test('no cache and offline: empty, never an exception', () async {
      net.failure = const SocketException('offline');
      final directory = open();
      await directory.load();
      expect(await directory.refresh(), DirectoryOutcome.failed);
      expect(directory.providers, isEmpty);
      expect(directory.snapshot, isNull);
      expect(directory.loaded, isTrue);
    });

    test('a hanging server times out', () async {
      net.serve(net.raw);
      net.raw.delay = const Duration(seconds: 5);
      net.mirror.status = 500;
      final directory = open(timeout: const Duration(milliseconds: 80));
      final stopwatch = Stopwatch()..start();
      expect(await directory.refresh(), DirectoryOutcome.failed);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
    });

    test('a damaged cache is treated as no cache and is repaired', () async {
      net.serve(net.raw);
      await open().refresh();
      File(p.join(cache.path, 'directory', 'index.json'))
          .writeAsStringSync('{ truncated');
      File(p.join(cache.path, 'directory', 'meta.json'))
          .writeAsStringSync('garbage');
      final next = open();
      await next.load();
      expect(next.providers, isEmpty);
      expect(next.loaded, isTrue);
      expect(await next.refresh(), DirectoryOutcome.updated);
      expect(next.providers, hasLength(2));
    });

    test('a logo file with the wrong size is not used', () async {
      net.serve(net.raw);
      final directory = open();
      await directory.refresh();
      final file = directory.logoFor('fixture-cloud')!;
      file.writeAsBytesSync([1, 2, 3]);
      final next = open();
      await next.load();
      expect(next.logoFor('fixture-cloud'), isNull);
      expect(next.logoFor('empty-host'), isNotNull);
      expect(await next.refresh(), DirectoryOutcome.upToDate);
      expect(next.logoFor('fixture-cloud'), isNotNull, reason: 're-downloaded');
    });
  });

  group('automatic updates', () {
    test('off: nothing is requested, a manual check still works', () async {
      net.serve(net.raw);
      final directory = open();
      await directory.load();
      await directory.autoRefresh(enabled: false);
      expect(net.requests, isEmpty);
      expect(directory.snapshot, isNull);
      expect(await directory.refresh(), DirectoryOutcome.updated);
    });

    test('on: only when never checked or older than 12 hours', () async {
      net.serve(net.raw, tag: '"t"');
      final directory = open();
      await directory.load();
      expect(directory.autoRefreshDue, isTrue);
      await directory.autoRefresh(enabled: true);
      expect(net.to(_raw, path: 'index.json'), hasLength(1));

      now = now.add(const Duration(hours: 11, minutes: 59));
      expect(directory.autoRefreshDue, isFalse);
      await directory.autoRefresh(enabled: true);
      expect(net.to(_raw, path: 'index.json'), hasLength(1), reason: 'fresh');

      now = now.add(const Duration(minutes: 1));
      expect(directory.autoRefreshDue, isTrue);
      await directory.autoRefresh(enabled: true);
      expect(net.to(_raw, path: 'index.json'), hasLength(2));
      expect(net.requests.last.headers['If-None-Match'], '"t"');
    });

    test('a failed check does not postpone the next automatic one', () async {
      net.serve(net.raw);
      final directory = open();
      await directory.refresh();
      now = now.add(const Duration(hours: 13));
      net.failure = const SocketException('offline');
      await directory.autoRefresh(enabled: true);
      expect(directory.lastOutcome, DirectoryOutcome.failed);
      expect(directory.autoRefreshDue, isTrue);
    });

    test('concurrent checks share one run', () async {
      net.serve(net.raw);
      final directory = open();
      final results = await Future.wait([
        directory.refresh(),
        directory.refresh(),
        directory.refresh(),
      ]);
      expect(results.toSet(), {DirectoryOutcome.updated});
      expect(net.to(_raw, path: 'index.json'), hasLength(1));
    });

    test('listeners hear about the check starting and ending', () async {
      net.serve(net.raw);
      final directory = open();
      final states = <bool>[];
      directory.addListener(() => states.add(directory.checking));
      await directory.refresh();
      expect(states.first, isTrue);
      expect(states.last, isFalse);
    });
  });

  group('cache', () {
    test('logos are downloaded at most four at a time', () async {
      final ids = [
        for (var i = 0; i < 14; i++) 'host-${i.toString().padLeft(2, '0')}',
      ];
      net.serve(net.raw, ids: ids);
      // Slow the files only: the index itself must not be delayed.
      net.raw.delay = const Duration(milliseconds: 20);
      final directory = open();
      await directory.refresh();
      expect(directory.providers, hasLength(14));
      expect(net.maxRunning, lessThanOrEqualTo(4));
      expect(net.maxRunning, greaterThan(1), reason: 'they do run in parallel');
      expect(logoNames(), hasLength(14));
    });

    test('unreferenced logos and leftovers are pruned', () async {
      net.serve(net.raw, version: 1, ids: ['aaa-host', 'bbb-host', 'ccc-host']);
      final directory = open();
      await directory.refresh();
      expect(logoNames(), hasLength(3));
      File(p.join(logos().path, 'aaa-host-deadbeef.png.tmp'))
          .writeAsBytesSync([1]);
      File(p.join(logos().path, 'zzz-gone-00000000.png')).writeAsBytesSync([1]);
      final oldA = directory.logoFor('aaa-host')!;

      // v2: ccc is gone, aaa has a new logo (new hash, new file name).
      net.serve(
        net.raw,
        version: 2,
        ids: ['aaa-host', 'bbb-host'],
        logos: {'aaa-host': png(200)},
      );
      await directory.refresh();
      final names = logoNames();
      expect(names, hasLength(2));
      expect(names.where((n) => n.startsWith('aaa-host-')), hasLength(1));
      expect(names.any((n) => n.startsWith('ccc-host')), isFalse);
      expect(names.any((n) => n.endsWith('.tmp')), isFalse);
      expect(names.any((n) => n.startsWith('zzz-gone')), isFalse);
      expect(oldA.existsSync(), isFalse);
      expect(directory.logoFor('aaa-host')!.existsSync(), isTrue);
    });

    test('writes go through a temporary file', () async {
      net.serve(net.raw);
      final directory = open();
      await directory.refresh();
      final root = Directory(p.join(cache.path, 'directory'));
      final all = root.listSync(recursive: true).whereType<File>();
      expect(
        all.map((f) => p.basename(f.path)).toSet(),
        containsAll(['index.json', 'meta.json']),
      );
      expect(all.where((f) => f.path.endsWith('.tmp')), isEmpty);
      final meta = jsonDecode(
        File(p.join(root.path, 'meta.json')).readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(meta['etag'], '"v1"');
      expect(meta['base'], _raw.toString());
      expect(meta['outcome'], 'updated');
    });
  });

  group('models', () {
    test('names and descriptions follow the language, falling back', () {
      final snapshot = fixtureCatalog();
      final cloud = snapshot.provider('fixture-cloud')!;
      expect(cloud.nameFor('zh'), '夹具云');
      expect(cloud.nameFor('en'), 'Fixture Cloud');
      expect(cloud.nameFor('fr'), 'Fixture Cloud');
      expect(cloud.descriptionFor('zh'), '用于测试的云服务商。');
      expect(cloud.descriptionFor('en'), 'A cloud provider for tests.');
      expect(cloud.searchNames, containsAll(['夹具云', 'Fixture Cloud', '夹具']));
      const onlyZh = DirectoryProvider(
        id: 'only-zh',
        nameZh: '甲',
        nameEn: 'A',
        kind: ProviderKind.vps,
        region: ProviderRegion.cn,
        website: 'https://a.example.com',
        descriptionZh: '中文说明',
      );
      expect(onlyZh.descriptionFor('en'), '中文说明', reason: 'en → zh');
      const none = DirectoryProvider(
        id: 'none',
        nameZh: '乙',
        nameEn: 'B',
        kind: ProviderKind.vps,
        region: ProviderRegion.global,
        website: 'https://b.example.com',
      );
      expect(none.descriptionFor('zh'), isEmpty);
    });

    test(
      'the default bases are the GitHub raw URL and the jsDelivr mirror',
      () {
        final bases = defaultDirectoryBases();
        expect(bases.map((b) => b.host), [
          'raw.githubusercontent.com',
          'cdn.jsdelivr.net',
        ]);
        expect(bases.every((b) => b.path.endsWith('/catalog/')), isTrue);
        expect(bases.every((b) => b.scheme == 'https'), isTrue);
      },
    );

    test('a memory directory never touches network or disk', () async {
      final directory = ProviderDirectory.memory(fixtureCatalog());
      expect(directory.loaded, isTrue);
      expect(await directory.refresh(), DirectoryOutcome.upToDate);
      await directory.autoRefresh(enabled: true);
      expect(directory.providers, hasLength(2));
    });
  });
}
