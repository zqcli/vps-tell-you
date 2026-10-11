import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/providers/provider_catalog.dart';
import 'package:vps_tell_you/providers/provider_record.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'support/catalog_fixture.dart';

const _cloud = CatalogProviderRef(
  catalogId: 'fixture-cloud',
  name: 'Fixture Cloud',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late MemoryCatalog catalog;
  final now = DateTime.utc(2026, 10, 6);

  Future<LedgerStore> open(String name) => LedgerStore.open(
    factory: databaseFactoryFfiNoIsolate,
    path: '${directory.path}/$name.sqlite3',
    clock: () => now,
  );

  ServerRecord server(
    String id, {
    String? providerId,
    CatalogPackage? package,
    String name = 'Server',
  }) => ServerRecord(
    id: id,
    name: '$name $id',
    vendor: 'Fixture Cloud',
    providerId: providerId,
    packageId: package?.id,
    packageSnapshot: package?.encodeSnapshot(),
    createdAt: now,
    updatedAt: now,
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('package-store-');
    store = await open('ledger');
    catalog = MemoryCatalog();
    ledger = LedgerController(store, catalog: catalog);
    await ledger.refresh();
    await ledger.loadCatalog();
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  CatalogPackage small() => catalog.snapshot.package('fc-small')!;

  group('catalog providers', () {
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

    test('renaming keeps the catalog link', () async {
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

    test('user-created providers have no catalog id', () async {
      await store.saveProvider(
        ProviderRecord(id: 'custom', name: 'Custom', createdAt: now),
        isNew: true,
      );
      expect((await store.providers()).single.catalogId, isNull);
    });
  });

  group('server package link', () {
    test(
      'saving creates the catalog provider in the same transaction',
      () async {
        await store.saveServer(
          server('a', package: small()),
          isNew: true,
          catalogProvider: _cloud,
        );
        final provider = (await store.providers()).single;
        final saved = (await store.servers()).single;
        expect(saved.providerId, provider.id);
        expect(saved.packageId, 'fc-small');
        expect(
          CatalogPackage.decodeSnapshot(saved.packageSnapshot!)
              .encodeSnapshot(),
          small().encodeSnapshot(),
        );
      },
    );

    test('a failed save leaves no provider behind', () async {
      final invalid = ServerRecord(
        id: 'bad',
        name: '',
        vendor: 'x',
        packageId: small().id,
        packageSnapshot: small().encodeSnapshot(),
        createdAt: now,
        updatedAt: now,
      );
      await expectLater(
        store.saveServer(invalid, isNew: true, catalogProvider: _cloud),
        throwsA(anything),
      );
      expect(await store.providers(), isEmpty);
      expect(await store.servers(), isEmpty);
      // Fails inside the transaction, after the provider was created.
      await expectLater(
        store.saveServer(
          ServerRecord.fromMap({
            ...server('late', package: small()).toMap(),
            'group_id': 'missing-group',
          }),
          isNew: true,
          catalogProvider: _cloud,
        ),
        throwsA(isA<LedgerConflict>()),
      );
      expect(await store.providers(), isEmpty, reason: 'rolled back');
    });

    test('servers without a package or provider are allowed', () async {
      await store.saveServer(server('plain'), isNew: true);
      final plain = (await store.servers()).single;
      expect(plain.providerId, isNull);
      expect(plain.packageId, isNull);
      expect(plain.packageSnapshot, isNull);
    });

    test(
      'a package needs its snapshot and the matching catalog provider',
      () async {
        final local = await store.addCatalogProvider(_cloud);
        await store.saveProvider(
          ProviderRecord(id: 'custom', name: 'Custom', createdAt: now),
          isNew: true,
        );
        final other = await store.addCatalogProvider(
          const CatalogProviderRef(catalogId: 'empty-host', name: 'Empty Host'),
        );
        final cases = <ServerRecord>[
          // user-created provider has no catalog id
          server('c1', providerId: 'custom', package: small()),
          // package of another catalog provider
          server('c2', providerId: other.id, package: small()),
          // no provider at all
          server('c3', package: small()),
          // id without snapshot / snapshot without id
          ServerRecord(
            id: 'c4',
            name: 'c4',
            vendor: 'x',
            providerId: local.id,
            packageId: 'fc-small',
            createdAt: now,
            updatedAt: now,
          ),
          ServerRecord(
            id: 'c5',
            name: 'c5',
            vendor: 'x',
            providerId: local.id,
            packageSnapshot: small().encodeSnapshot(),
            createdAt: now,
            updatedAt: now,
          ),
          // id differs from the snapshot's
          ServerRecord(
            id: 'c6',
            name: 'c6',
            vendor: 'x',
            providerId: local.id,
            packageId: 'fc-nano',
            packageSnapshot: small().encodeSnapshot(),
            createdAt: now,
            updatedAt: now,
          ),
          // garbage snapshot
          ServerRecord(
            id: 'c7',
            name: 'c7',
            vendor: 'x',
            providerId: local.id,
            packageId: 'fc-small',
            packageSnapshot: '{"x":1}',
            createdAt: now,
            updatedAt: now,
          ),
        ];
        for (final bad in cases) {
          await expectLater(
            store.saveServer(bad, isNew: true),
            throwsA(isA<ArgumentError>()),
            reason: bad.id,
          );
        }
        expect(await store.servers(), isEmpty);
      },
    );

    test(
      'the snapshot, not the catalog, defines what the server saved',
      () async {
        await store.saveServer(
          server('a', package: small()),
          isNew: true,
          catalogProvider: _cloud,
        );
        await store.saveServer(
          server('b', package: small()),
          isNew: true,
          catalogProvider: _cloud,
        );
        await ledger.refresh();
        expect(
          ledger.packageStateFor(ledger.byId('a')!),
          PackageCatalogState.same,
        );
        expect(ledger.serversForPackage('fc-small').map((s) => s.id).toSet(), {
          'a',
          'b',
        });

        // The catalog raises the price: servers keep their saved package.
        catalog.snapshot = fixtureCatalog(version: 4, smallAmount: 1500);
        await ledger.loadCatalog(force: true);
        final before = ledger.byId('a')!.packageSnapshot;
        expect(
          ledger.packageStateFor(ledger.byId('a')!),
          PackageCatalogState.changed,
        );
        expect(
          ledger.packageSnapshotFor(ledger.byId('a')!)!.price!.amountMinor,
          1200,
        );
        expect(
          (await store.servers())
              .firstWhere((s) => s.id == 'a')
              .packageSnapshot,
          before,
        );

        // A removed package is reported as such.
        catalog.snapshot = CatalogSnapshot.parse(
          jsonEncode({
            'schemaVersion': 1,
            'catalogVersion': 5,
            'providers': [
              {'id': 'fixture-cloud', 'name': 'Fixture Cloud'},
            ],
          }),
        );
        await ledger.loadCatalog(force: true);
        expect(
          ledger.packageStateFor(ledger.byId('a')!),
          PackageCatalogState.removed,
        );
      },
    );

    test('an unloaded catalog says nothing about changes', () async {
      final failing = LedgerController(store, catalog: FailingCatalog());
      await store.saveServer(
        server('a', package: small()),
        isNew: true,
        catalogProvider: _cloud,
      );
      await failing.refresh();
      await failing.loadCatalog();
      expect(failing.catalogFailed, isTrue);
      expect(failing.catalog.providers, isEmpty);
      expect(
        failing.packageStateFor(failing.byId('a')!),
        PackageCatalogState.unknown,
      );
      // The ledger itself is unaffected.
      expect(failing.refreshFailed, isFalse);
      expect(failing.records, hasLength(1));
      failing.dispose();
    });

    test('changing provider or clearing the package is a plain edit', () async {
      await store.saveServer(
        server('a', package: small()),
        isNew: true,
        catalogProvider: _cloud,
      );
      final saved = (await store.servers()).single;
      await store.saveServer(
        ServerRecord.fromMap({
          ...saved.toMap(),
          'package_id': null,
          'package_snapshot': null,
        }),
        isNew: false,
      );
      expect((await store.servers()).single.packageId, isNull);
      expect((await store.servers()).single.providerId, saved.providerId);
    });
  });

  group('backup v2', () {
    test('providers, catalog links and package snapshots round trip', () async {
      await store.addCatalogProvider(_cloud);
      await store.saveProvider(
        ProviderRecord(id: 'custom', name: 'Custom', createdAt: now),
        isNew: true,
      );
      await store.saveServer(
        server('a', package: small()),
        isNew: true,
        catalogProvider: _cloud,
      );
      await store.saveServer(server('b', providerId: 'custom'), isNew: true);
      await store.saveServer(server('c'), isNew: true);
      final snapshot = await store.exportLedgerBackup();
      final json = jsonDecode(snapshot.encode()) as Map<String, dynamic>;
      expect(json['version'], 2);
      expect(snapshot.counts['providers'], 2);

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
      expect(servers['a']!.packageId, 'fc-small');
      expect(servers['a']!.packageSnapshot, small().encodeSnapshot());
      expect(
        servers['a']!.providerId,
        (await store.servers()).first.providerId,
      );
      expect(servers['b']!.providerId, 'custom');
      expect(servers['c']!.providerId, isNull);
      expect((await target.exportLedgerBackup()).encode(), snapshot.encode());
      await target.close();
    });

    test('a version 1 file restores with no providers or packages', () async {
      await store.saveServer(server('a'), isNew: true);
      final v2 = jsonDecode(
        (await store.exportLedgerBackup()).encode(),
      ) as Map<String, dynamic>;
      v2['version'] = 1;
      v2.remove('providers');
      for (final row in v2['servers'] as List) {
        (row as Map).remove('provider_id');
        row.remove('package_id');
        row.remove('package_snapshot');
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

    test('invalid provider and package links are rejected', () async {
      await store.saveServer(
        server('a', package: small()),
        isNew: true,
        catalogProvider: _cloud,
      );
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
        }), // duplicate catalog id
        (m) => m['providers'].first['catalog_id'] = 'Bad Id',
        (m) => m['providers'].first['name'] = ' padded ',
        (m) => m['providers'].first['extra'] = 1,
        (m) => m['servers'].first['provider_id'] = 'missing',
        (m) => m['servers'].first['package_snapshot'] = null,
        (m) => m['servers'].first['package_id'] = null,
        (m) => m['servers'].first['package_id'] = 'fc-nano',
        (m) => m['servers'].first['package_snapshot'] = '{"x":1}',
        (m) => m['providers'].first['catalog_id'] = 'empty-host',
        (m) => m['servers'].first['provider_id'] = null,
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
