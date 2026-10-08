import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'cloud_store_test.dart' show snapshot, cloudTestTime;
import 'cloud_controller_test.dart' show CallbackCloudAdapter, CloudTestSecrets;
import 'support/provider_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  late LedgerStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('provider-review-');
    path = '${directory.path}/ledger.sqlite3';
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: () => cloudTestTime,
    );
    await addTestProvider(store);
  });

  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> device(String id, {bool unspecified = false}) =>
      store.saveServer(
        ServerRecord(
          id: id,
          name: id,
          vendor: unspecified ? '' : testProvider.name,
          providerId: unspecified ? null : testProvider.id,
          createdAt: cloudTestTime,
          updatedAt: cloudTestTime,
        ),
        isNew: true,
      );

  Future<void> adapter(String id, {bool v1 = false}) async {
    final data = snapshot(v1: v1);
    final account = CloudAccount(
      id: id,
      provider: data.provider,
      businessProviderId: testProvider.id,
      authScope: adapterScope(data.provider),
      alias: id,
      endpoint: 'https://panel.example',
      secretRef: 'synthetic-$id',
      remoteAccountId: data.remoteAccountId,
      createdAt: cloudTestTime,
    );
    await store.reserveSecret(account.secretRef);
    await store.saveCloudAccount(
      account: account,
      snapshot: data,
      expected: null,
    );
  }

  Future<void> bind(String deviceId, String adapterId) async {
    final options = await store.serverCloudBindingOptions(deviceId);
    await store.setServerCloudBinding(
      options,
      choice: options.choices.singleWhere((c) => c.accountId == adapterId),
    );
  }

  test('every valid unspecified-provider device remains exportable', () async {
    await device('manual-without-provider', unspecified: true);
    expect((await store.servers()).single.validate(), isNull);
    final backup = await store.exportLedgerBackup();
    expect(backup.servers, hasLength(1));
    expect(backup.servers.single['vendor'], '服务商待填写');
    expect((await store.servers()).single.vendor, isEmpty);
    final incompatible = jsonDecode(backup.encode()) as Map<String, dynamic>;
    (incompatible['servers'] as List).single['vendor'] = '';
    expect(
      () => LedgerBackupSnapshot.decode(jsonEncode(incompatible)),
      throwsFormatException,
    );
    final target = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/restored.sqlite3',
    );
    try {
      await target.restoreLedgerBackup(backup);
      expect((await target.servers()).single.providerId, isNull);
      expect(await target.cloudBindings(), isEmpty);
    } finally {
      await target.close();
    }
  });

  test(
    'whitespace vendor export preserves local text and v1 compatibility',
    () async {
      final record = ServerRecord(
        id: 'whitespace-vendor',
        name: 'Unspecified provider',
        vendor: '  ',
        createdAt: cloudTestTime,
        updatedAt: cloudTestTime,
      );
      await store.saveServer(record, isNew: true);
      final backup = await store.exportLedgerBackup();
      expect(backup.servers.single['vendor'], '服务商待填写');
      expect((await store.servers()).single.vendor, '  ');
      expect(backup.encode(), isNot(contains('provider_id')));
    },
  );

  test(
    'updating a binding into a singleton records its first-device pin',
    () async {
      await device('first');
      await device('second');
      await adapter('account');
      await adapter('single', v1: true);
      await bind('first', 'account');
      final db = await databaseFactoryFfiNoIsolate.openDatabase(path);
      await db.update(
        'cloud_bindings',
        {'account_id': 'single', 'instance_key': 'single'},
        where: 'server_id = ?',
        whereArgs: ['first'],
      );
      await store.setServerCloudBinding(
        await store.serverCloudBindingOptions('first'),
      );
      await expectLater(
        bind('second', 'single'),
        throwsA(isA<CloudAccountFailure>()),
      );
      expect(
        (await store.cloudAccounts())
            .singleWhere((a) => a.id == 'single')
            .pinnedServerId,
        'first',
      );
    },
  );

  test(
    'unknown scope cannot erase a singleton pin without new credentials',
    () async {
      await device('first');
      await adapter('single', v1: true);
      await bind('first', 'single');
      await store.setServerCloudBinding(
        await store.serverCloudBindingOptions('first'),
      );
      final db = await databaseFactoryFfiNoIsolate.openDatabase(path);
      await db.update(
        'cloud_accounts',
        {'auth_scope': 'unknown'},
        where: 'id = ?',
        whereArgs: ['single'],
      );
      await expectLater(
        db.update(
          'cloud_accounts',
          {'pinned_server_id': null},
          where: 'id = ?',
          whereArgs: ['single'],
        ),
        throwsA(isA<DatabaseException>()),
      );
    },
  );

  test(
    'provider rename fences an already verified new credential instance',
    () async {
      final secrets = CloudTestSecrets();
      final controller = CloudController(
        store: store,
        secrets: secrets,
        adapterFactory: (_, _, _) =>
            CallbackCloudAdapter((_) async => snapshot()),
      );
      try {
        final verification = await controller.verifyConnection(
          provider: CloudProvider.solusVm2,
          businessProvider: testProvider,
          endpoint: 'https://panel.example',
          credentials: SolusVm2Credentials('synthetic-token'),
        );
        expect(verification, isNotNull);
        await store.saveProvider(
          ProviderRecord(
            id: testProvider.id,
            name: 'Renamed provider',
            createdAt: testProvider.createdAt,
            revision: testProvider.revision,
          ),
          isNew: false,
        );
        expect(
          await controller.saveAccount(verification!, alias: 'New instance'),
          isFalse,
        );
        expect(await store.cloudAccounts(), isEmpty);
        expect(await store.cloudBindings(), isEmpty);
        expect(await controller.retryCleanup(), isTrue);
        expect(secrets.values, isEmpty);
      } finally {
        controller.dispose();
      }
    },
  );

  test(
    'confirming provider prevents a pending old read from restoring scope',
    () async {
      await device('first');
      await adapter('single', v1: true);
      await bind('first', 'single');
      final db = await databaseFactoryFfiNoIsolate.openDatabase(path);
      await db.update(
        'providers',
        {'needs_review': 1},
        where: 'id = ?',
        whereArgs: [testProvider.id],
      );
      final target = ProviderRecord(
        id: 'confirmed-provider',
        name: 'Confirmed vendor',
        createdAt: cloudTestTime,
      );
      await store.saveProvider(target, isNew: true);
      final reading = await store.beginCloudRead(
        (await store.cloudAccounts()).single,
      );
      await store.confirmAdapterProvider(reading, target);
      await expectLater(
        store.commitCloudSnapshot(reading, snapshot(v1: true)),
        throwsA(isA<LedgerConflict>()),
      );
      final current = (await store.cloudAccounts()).single;
      expect(current.businessProviderId, target.id);
      expect(current.pinnedServerId, 'first');
      expect((await store.servers()).single.providerId, target.id);
      expect((await store.cloudBindings()).single.serverId, 'first');
    },
  );
}
