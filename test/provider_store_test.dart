import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/providers/provider_record.dart';
import 'package:vps_tell_you/servers/server_record.dart';

const _cloud = CatalogProviderRef(
  catalogId: 'fixture-cloud',
  name: 'Fixture Cloud',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late LedgerStore store;
  final now = DateTime.utc(2026, 10, 6);

  Future<LedgerStore> open(String name) => LedgerStore.open(
    factory: databaseFactoryFfiNoIsolate,
    path: '${directory.path}/$name.sqlite3',
    clock: () => now,
  );

  ServerRecord server(String id, {String? providerId}) => ServerRecord(
    id: id,
    name: 'Server $id',
    vendor: 'Fixture Cloud',
    providerId: providerId,
    createdAt: now,
    updatedAt: now,
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('provider-store-');
    store = await open('ledger');
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  group('directory providers', () {
    test('adding is idempotent and keeps a stable local id', () async {
      final first = await store.addCatalogProvider(_cloud);
      final second = await store.addCatalogProvider(_cloud);
      expect(second.id, first.id);
      expect(first.catalogId, 'fixture-cloud');
      expect(await store.providers(), hasLength(1));
    });

    test('a same-named user provider is linked, not duplicated', () async {
      await store.saveProvider(
        ProviderRecord(id: 'mine', name: 'fixture CLOUD', createdAt: now),
        isNew: true,
      );
      final linked = await store.addCatalogProvider(_cloud);
      expect(linked.id, 'mine');
      expect(linked.name, 'fixture CLOUD', reason: 'local name is kept');
      expect(linked.catalogId, 'fixture-cloud');
      expect(linked.revision, 1);
      expect(await store.providers(), hasLength(1));
    });

    test('renaming keeps the directory link', () async {
      final provider = await store.addCatalogProvider(_cloud);
      await store.saveProvider(
        ProviderRecord(
          id: provider.id,
          name: 'My cloud',
          createdAt: provider.createdAt,
          revision: provider.revision,
          catalogId: null, // a caller cannot unlink or relink through rename
        ),
        isNew: false,
      );
      final renamed = (await store.providers()).single;
      expect(renamed.name, 'My cloud');
      expect(renamed.catalogId, 'fixture-cloud');
    });

    test('user-created providers have no directory id', () async {
      await store.saveProvider(
        ProviderRecord(id: 'custom', name: 'Custom', createdAt: now),
        isNew: true,
      );
      expect((await store.providers()).single.catalogId, isNull);
    });
  });

  group('server provider link', () {
    test(
      'saving creates the directory provider in the same transaction',
      () async {
        await store.saveServer(
          server('a'),
          isNew: true,
          catalogProvider: _cloud,
        );
        final provider = (await store.providers()).single;
        expect((await store.servers()).single.providerId, provider.id);
        expect(provider.catalogId, 'fixture-cloud');
      },
    );

    test('a failed save leaves no provider behind', () async {
      await expectLater(
        store.saveServer(
          ServerRecord(
            id: 'bad',
            name: '',
            vendor: 'x',
            createdAt: now,
            updatedAt: now,
          ),
          isNew: true,
          catalogProvider: _cloud,
        ),
        throwsA(anything),
      );
      expect(await store.providers(), isEmpty);
      // Fails inside the transaction, after the provider was created.
      await expectLater(
        store.saveServer(
          ServerRecord.fromMap({
            ...server('late').toMap(),
            'group_id': 'missing-group',
          }),
          isNew: true,
          catalogProvider: _cloud,
        ),
        throwsA(isA<LedgerConflict>()),
      );
      expect(await store.providers(), isEmpty, reason: 'rolled back');
      expect(await store.servers(), isEmpty);
    });

    test('servers without a provider are allowed', () async {
      await store.saveServer(server('plain'), isNew: true);
      expect((await store.servers()).single.providerId, isNull);
    });

    test('server rows never carry package data', () async {
      await store.saveServer(server('a'), isNew: true, catalogProvider: _cloud);
      expect(server('a').toMap().keys, isNot(contains('package_id')));
      expect(server('a').toMap().keys, isNot(contains('package_snapshot')));
    });
  });

  group('backup v2', () {
    test(
      'providers and directory links round trip; no package fields',
      () async {
        await store.addCatalogProvider(_cloud);
        await store.saveProvider(
          ProviderRecord(id: 'custom', name: 'Custom', createdAt: now),
          isNew: true,
        );
        await store.saveServer(
          server('a'),
          isNew: true,
          catalogProvider: _cloud,
        );
        await store.saveServer(server('b', providerId: 'custom'), isNew: true);
        await store.saveServer(server('c'), isNew: true);
        final snapshot = await store.exportLedgerBackup();
        final json = jsonDecode(snapshot.encode()) as Map<String, dynamic>;
        expect(json['version'], 2);
        expect(snapshot.counts['providers'], 2);
        for (final row in json['servers'] as List) {
          expect((row as Map).keys, contains('provider_id'));
          expect(row.keys, isNot(contains('package_id')));
          expect(row.keys, isNot(contains('package_snapshot')));
        }

        final target = await open('target');
        final decoded = LedgerBackupSnapshot.decode(snapshot.encode());
        expect((await target.previewLedgerRestore(decoded)).canRestore, isTrue);
        await target.restoreLedgerBackup(decoded);
        final providers = {for (final p in await target.providers()) p.id: p};
        expect(providers.length, 2);
        expect(providers.values.map((p) => p.catalogId).toSet(), {
          'fixture-cloud',
          null,
        });
        final servers = {for (final s in await target.servers()) s.id: s};
        expect(
          servers['a']!.providerId,
          (await store.servers()).firstWhere((s) => s.id == 'a').providerId,
        );
        expect(servers['b']!.providerId, 'custom');
        expect(servers['c']!.providerId, isNull);
        expect((await target.exportLedgerBackup()).encode(), snapshot.encode());
        await target.close();
      },
    );

    test('a version 1 file restores with no providers', () async {
      await store.saveServer(server('a'), isNew: true);
      final v2 = jsonDecode(
        (await store.exportLedgerBackup()).encode(),
      ) as Map<String, dynamic>;
      v2['version'] = 1;
      v2.remove('providers');
      for (final row in v2['servers'] as List) {
        (row as Map).remove('provider_id');
      }
      final v1 = LedgerBackupSnapshot.decode(jsonEncode(v2));
      expect(v1.providers, isEmpty);
      expect(jsonDecode(v1.encode())['version'], 2, reason: 'rewritten as v2');
      final target = await open('target');
      await target.restoreLedgerBackup(v1);
      expect((await target.servers()).single.providerId, isNull);
      expect(await target.providers(), isEmpty);
      await target.close();
    });

    test('package fields of round 6–8 version 2 files are ignored', () async {
      await store.addCatalogProvider(_cloud);
      await store.saveServer(server('a'), isNew: true, catalogProvider: _cloud);
      await store.saveServer(server('b'), isNew: true);
      final plain = (await store.exportLedgerBackup()).encode();
      final old = jsonDecode(plain) as Map<String, dynamic>;
      final rows = old['servers'] as List;
      // What the old writer emitted: both keys on every row, valid or not.
      (rows[0] as Map)
        ..['package_id'] = 'fc-small'
        ..['package_snapshot'] = '{"snapshotVersion":1,"anything":"goes"}';
      (rows[1] as Map)
        ..['package_id'] = null
        ..['package_snapshot'] = null;
      final decoded = LedgerBackupSnapshot.decode(jsonEncode(old));
      expect(decoded.encode(), plain, reason: 'dropped without a trace');
      final target = await open('target');
      await target.restoreLedgerBackup(decoded);
      final servers = await target.servers();
      expect(servers, hasLength(2));
      expect(servers.map((s) => s.name).toSet(), {'Server a', 'Server b'});
      await target.close();

      // Only the two retired keys are tolerated, not arbitrary extras.
      (rows[0] as Map)['extra'] = 1;
      expect(
        () => LedgerBackupSnapshot.decode(jsonEncode(old)),
        throwsFormatException,
      );
      // And a version 1 file never had them.
      final v1 = jsonDecode(plain) as Map<String, dynamic>
        ..['version'] = 1
        ..remove('providers');
      for (final row in v1['servers'] as List) {
        (row as Map)
          ..remove('provider_id')
          ..['package_id'] = null;
      }
      expect(
        () => LedgerBackupSnapshot.decode(jsonEncode(v1)),
        throwsFormatException,
      );
    });

    test('invalid provider links are rejected', () async {
      await store.saveServer(server('a'), isNew: true, catalogProvider: _cloud);
      final text = (await store.exportLedgerBackup()).encode();
      final mutations = <void Function(Map<String, dynamic>)>[
        (m) => m['providers'].add(m['providers'].first), // duplicate id
        (m) => m['providers'].add({
          ...m['providers'].first,
          'id': 'other',
          'name': 'FIXTURE cloud',
          'catalog_id': null,
        }), // duplicate name
        (m) => m['providers'].add({
          ...m['providers'].first,
          'id': 'other',
          'name': 'Other',
        }), // duplicate directory id
        (m) => m['providers'].first['catalog_id'] = 'Bad Id',
        (m) => m['providers'].first['name'] = ' padded ',
        (m) => m['providers'].first['extra'] = 1,
        (m) => m['servers'].first['provider_id'] = 'missing',
        (m) => m['servers'].first.remove('provider_id'),
      ];
      for (var i = 0; i < mutations.length; i++) {
        final doc = jsonDecode(text) as Map<String, dynamic>;
        mutations[i](doc);
        expect(
          () => LedgerBackupSnapshot.decode(jsonEncode(doc)),
          throwsFormatException,
          reason: 'mutation $i',
        );
      }
    });

    test('restoring providers needs a ledger without providers', () async {
      await store.addCatalogProvider(_cloud);
      final snapshot = await store.exportLedgerBackup();
      final target = await open('target');
      await target.saveProvider(
        ProviderRecord(id: 'existing', name: 'Existing', createdAt: now),
        isNew: true,
      );
      final preview = await target.previewLedgerRestore(snapshot);
      expect(preview.canRestore, isFalse);
      await expectLater(target.restoreLedgerBackup(snapshot), throwsStateError);
      expect(await target.providers(), hasLength(1));
      await target.close();
    });
  });
}
