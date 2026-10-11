import 'support/provider_fixture.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/finance/finance_math.dart';
import 'package:vps_tell_you/finance/finance_models.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

final backupNow = DateTime.utc(2026, 10, 6, 12);
ServerRecord backupServer({
  String id = 'server',
  String? group,
  ServerResources? resources,
}) => ServerRecord(
  id: id,
  name: 'Fixture server',
  vendor: 'Fixture vendor',
  groupId: group,
  host: '192.0.2.12',
  region: 'Fixture region',
  os: 'Debian 12',
  spec: '2 vCPU',
  resources: resources,
  purpose: 'Testing',
  notes: 'excluded-server-note',
  billing: BillingKind.prepaid,
  cycleMonths: 1,
  amountMinor: 0,
  startDate: const LedgerDate(2026, 1, 31),
  dueDate: const LedgerDate(2026, 2, 28),
  createdAt: backupNow,
  updatedAt: backupNow,
);

Future<void> populateBackupFixture(LedgerStore store) async {
  await store.saveGroup('Fixture group');
  await store.saveServer(
    backupServer(group: (await store.groups()).single.id),
    isNew: true,
  );
  Future<void> pay(String id, int cycles) async {
    final server = (await store.servers()).single;
    await store.recordPayment(
      id: id,
      server: server,
      amount: const Money('EUR', 12345),
      paidDate: const LedgerDate(2026, 2, 1),
      cycleCount: cycles,
      until: renewalDate(server, cycles),
      confirmed: true,
      note: 'excluded-payment-note',
    );
  }

  await pay('void-payment', 1);
  await store.undoPayment('void-payment');
  await pay('active-payment', 2);
  await store.recordAccountPayment(
    id: 'account-payment',
    accountLabel: 'Fixture account',
    amount: const Money('CNY', 900),
    paidDate: const LedgerDate(2026, 2, 1),
    note: 'excluded-account-note',
  );
  await store.saveFx(
    const FxSettings(
      displayCurrency: 'EUR',
      usdToCny: '7.1',
      eurToCny: '8.2',
      rateDate: LedgerDate(2026, 2, 1),
    ),
  );
  await store.saveServer(
    ServerRecord(
      id: 'archived',
      name: 'Archived',
      vendor: 'Fixture',
      createdAt: backupNow,
      updatedAt: backupNow,
      archivedAt: backupNow,
      amountMinor: null,
      isDemo: true,
    ),
    isNew: true,
  );
}

void main() {
  late Directory directory;
  late LedgerStore source, target;
  late String sourcePath, targetPath;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('safe-ledger-backup-');
    sourcePath = '${directory.path}/source.sqlite';
    targetPath = '${directory.path}/target.sqlite';
    source = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: sourcePath,
      clock: () => backupNow,
    );
    target = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: targetPath,
      clock: () => backupNow,
    );
  });
  tearDown(() async {
    await source.close();
    await target.close();
    await directory.delete(recursive: true);
  });

  test(
    'whitelist excludes every connection table, notes and note fingerprints',
    () async {
      await populateBackupFixture(source);
      final db = await databaseFactoryFfiNoIsolate.openDatabase(sourcePath);
      final now = backupNow.toIso8601String();
      await db.insert('credentials', {
        'id': 'excluded-credential',
        'name': 'excluded-name',
        'kind': 'password',
        'default_username': 'excluded-user',
        'secret_ref': 'excluded-secret-ref',
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('ssh_configurations', {
        'server_id': 'server',
        'host': 'excluded-ssh.invalid',
        'port': 22,
        'username': 'excluded-user',
        'credential_id': 'excluded-credential',
      });
      await db.insert('host_trust', {
        'generation': 'excluded-generation',
        'host': 'excluded-ssh.invalid',
        'port': 22,
        'algorithm': 'excluded-algorithm',
        'public_key': 'excluded-public-key',
        'fingerprint': 'excluded-fingerprint',
        'verified_at': now,
      });
      await db.insert('secret_cleanup', {
        'secret_ref': 'excluded-cleanup',
        'created_at': now,
      });
      await db.insert('snippets', {
        'id': 'excluded-snippet',
        'name': 'excluded-snippet-name',
        'content': 'excluded-command',
      });
      await addTestProvider(source);
      await db.update('servers', {'provider_id': testProvider.id});
      await source.saveThemeMode('dark');
      final snapshot = await source.exportLedgerBackup();
      expect(snapshot.encode(), isNot(contains('excluded-')));
      expect(snapshot.encode(), isNot(contains('secret_ref')));
      expect(snapshot.encode(), isNot(contains('request_fingerprint')));
      expect(snapshot.encode(), isNot(contains('reminder_rules')));
      expect(snapshot.encode(), isNot(contains('app_settings')));
      expect(
        snapshot.servers.firstWhere((r) => r['id'] == 'server')['os'],
        'Debian 12',
      );
      expect(snapshot.counts, {
        'groups': 1,
        'servers': 2,
        'payments': 3,
        'service_periods': 3,
      });
      expect(
        (await source.servers()).firstWhere((s) => s.id == 'server').notes,
        'excluded-server-note',
      );
    },
  );

  test('round trip retains stable IDs, exact finance, archive, voids and safe retry', () async {
    await populateBackupFixture(source);
    await target.saveThemeMode('dark');
    final snapshot = LedgerBackupSnapshot.decode(
      (await source.exportLedgerBackup()).encode(),
    );
    final preview = await target.previewLedgerRestore(snapshot);
    expect(preview.canRestore, isTrue);
    expect(preview.exclusions, LedgerBackupSnapshot.exclusions);
    await target.restoreLedgerBackup(snapshot);
    await target.close();
    target = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: targetPath,
      clock: () => backupNow,
    );
    final again = await target.exportLedgerBackup();
    expect(again.encode(), snapshot.encode());
    expect(
      (await target.servers()).firstWhere((s) => s.id == 'archived').archived,
      isTrue,
    );
    expect((await target.servers()).every((s) => s.notes.isEmpty), isTrue);
    expect((await target.payments()).every((p) => p.note.isEmpty), isTrue);
    expect((await target.reminderRules()).every((r) => !r.enabled), isTrue);
    expect(await target.themeMode(), 'dark');
    expect(await target.credentials(), isEmpty);
    expect(await target.sshConfigurations(), isEmpty);
    final server = (await target.servers()).firstWhere((s) => s.id == 'server');
    final same = await target.recordPayment(
      id: 'active-payment',
      server: server,
      amount: const Money('EUR', 12345),
      paidDate: const LedgerDate(2026, 2, 1),
      cycleCount: 2,
      until: server.dueDate!,
      confirmed: true,
    );
    expect(same.id, 'active-payment');
    await expectLater(
      target.recordPayment(
        id: 'void-payment',
        server: server,
        amount: const Money('EUR', 12345),
        paidDate: const LedgerDate(2026, 2, 1),
        cycleCount: 1,
        until: const LedgerDate(2026, 3, 28),
        confirmed: true,
      ),
      throwsArgumentError,
    );
    expect((await target.payments()).length, 3);
    await target.undoPayment('active-payment');
    expect(
      (await target.servers()).firstWhere((s) => s.id == 'server').dueDate,
      const LedgerDate(2026, 2, 28),
    );
    expect((await target.servicePeriods()).length, 1);
    final repeatedAccount = await target.recordAccountPayment(
      id: 'account-payment',
      accountLabel: 'Fixture account',
      amount: const Money('CNY', 900),
      paidDate: const LedgerDate(2026, 2, 1),
    );
    expect(repeatedAccount.id, 'account-payment');
  });

  test('v1 backup round-trips local resource values and provenance', () async {
    final resources = ServerResources(
      ip: '2001:db8::4',
      hostname: 'BACKUP-Fixture',
      vcpu: 4,
      ramBytes: 4294967296,
      diskBytes: 64424509440,
      trafficUnlimited: true,
    );
    await source.saveServer(backupServer(resources: resources), isNew: true);
    final encoded = (await source.exportLedgerBackup()).encode();
    final snapshot = LedgerBackupSnapshot.decode(encoded);
    expect(snapshot.servers.single['resources_json'], resources.encode());
    await target.restoreLedgerBackup(snapshot);
    final restored = (await target.servers()).single;
    expect(restored.resources!.toJson(), resources.toJson());
    expect(restored.amountMinor, 0);
    expect(restored.dueDate, const LedgerDate(2026, 2, 28));
  });

  test('partial hardware and independent traffic period survive backup and reopening', () async {
    final resources = ServerResources(
      ip: '192.0.2.41',
      trafficBytes: 1099511627776,
      trafficPeriodMonths: 3,
    );
    await source.saveServer(backupServer(resources: resources), isNew: true);
    await source.close();
    source = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: sourcePath,
    );
    expect(
      (await source.servers()).single.resources!.toJson(),
      resources.toJson(),
    );
    final snapshot = LedgerBackupSnapshot.decode(
      (await source.exportLedgerBackup()).encode(),
    );
    await target.restoreLedgerBackup(snapshot);
    final restored = (await target.servers()).single.resources!;
    expect(restored.toJson(), resources.toJson());
    expect(restored.hostname, isEmpty);
    expect(restored.ramBytes, isNull);
    expect(restored.diskBytes, isNull);
    expect(restored.vcpu, isNull);
    expect(restored.trafficPeriodMonths, 3);
  });

  test('v7 upgrade preserves legacy resources byte-for-byte without inventing a period', () async {
    final resources = ServerResources(
      ip: '192.0.2.42',
      hostname: 'legacy',
      vcpu: 2,
      ramBytes: 2147483648,
      diskBytes: 21474836480,
      trafficBytes: 1099511627776,
    );
    await source.saveServer(backupServer(resources: resources), isNew: true);
    await source.close();
    final legacyJson = jsonEncode(
      {...resources.toJson()}..remove('trafficPeriodMonths'),
    );
    final raw = await databaseFactoryFfiNoIsolate.openDatabase(sourcePath);
    await removeProviderSchema(raw);
    await raw.update('servers', {'resources_json': legacyJson});
    // Reconstruct the actual pre-language v7 preference schema.
    await raw.execute('ALTER TABLE app_settings DROP COLUMN language');
    await raw.setVersion(7);
    final before = await raw.query('servers');
    await raw.close();
    source = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: sourcePath,
    );
    final after = await databaseFactoryFfiNoIsolate.openDatabase(sourcePath);
    expect(await after.getVersion(), LedgerStore.schemaVersion);
    expect(
      (await after.query('servers')).map(legacyProviderProjection).toList(),
      before,
    );
    expect(
      (await source.servers()).single.resources!.trafficPeriodMonths,
      isNull,
    );
    final snapshot = LedgerBackupSnapshot.decode(
      (await source.exportLedgerBackup()).encode(),
    );
    await target.restoreLedgerBackup(snapshot);
    expect(
      (await target.servers()).single.resources!.trafficPeriodMonths,
      isNull,
    );
    expect((await target.servers()).single.resources!.ip, '192.0.2.42');
  });

  test(
    'old v1 backup without optional resources field still restores',
    () async {
      await populateBackupFixture(source);
      final legacy = jsonDecode(
        (await source.exportLedgerBackup()).encode(),
      ) as Map<String, dynamic>;
      for (final row in legacy['servers'] as List) {
        (row as Map).remove('resources_json');
      }
      final snapshot = LedgerBackupSnapshot.decode(jsonEncode(legacy));
      await target.restoreLedgerBackup(snapshot);
      expect(
        (await target.servers()).every((row) => row.resources == null),
        isTrue,
      );
      expect((await target.payments()), hasLength(3));
      expect((await target.servicePeriods()), hasLength(3));
    },
  );

  test(
    'backup rejects invalid resource blobs and nested private fields',
    () async {
      final resources = ServerResources(
        ip: '192.0.2.3',
        hostname: 'fixture',
        vcpu: 2,
        ramBytes: 2147483648,
        diskBytes: 32212254720,
        trafficBytes: 1099511627776,
      );
      await source.saveServer(backupServer(resources: resources), isNew: true);
      final original = (await source.exportLedgerBackup()).encode();
      for (final malformed in <Object?>[
        5,
        '{not json',
        jsonEncode({...resources.toJson(), 'password': 'synthetic-secret'}),
        jsonEncode({...resources.toJson(), 'vcpu': 0}),
        jsonEncode({...resources.toJson(), 'apiFields': 'secret_ref'}),
        jsonEncode({...resources.toJson(), 'trafficUnlimited': true}),
      ]) {
        final modified = jsonDecode(original) as Map<String, dynamic>;
        (modified['servers'] as List).single['resources_json'] = malformed;
        expect(
          () => LedgerBackupSnapshot.decode(jsonEncode(modified)),
          throwsFormatException,
        );
        expect(await target.servers(), isEmpty);
      }
    },
  );

  test('inferred periods and null amounts round trip', () async {
    await source.loadDemo();
    final snapshot = await source.exportLedgerBackup();
    await target.restoreLedgerBackup(snapshot);
    expect((await target.exportLedgerBackup()).encode(), snapshot.encode());
  });

  test('snapshot is deeply immutable', () async {
    await populateBackupFixture(source);
    final snapshot = await source.exportLedgerBackup();
    expect(() => snapshot.servers.add({}), throwsUnsupportedError);
    expect(
      () => snapshot.servers.first['name'] = 'change',
      throwsUnsupportedError,
    );
    expect(
      () => snapshot.fx['display_currency'] = 'USD',
      throwsUnsupportedError,
    );
  });

  test('preview is not authorization to overwrite and transaction rechecks emptiness', () async {
    final snapshot = await source.exportLedgerBackup();
    expect((await target.previewLedgerRestore(snapshot)).canRestore, isTrue);
    await target.saveGroup('Concurrent group');
    final before = (await target.exportLedgerBackup()).encode();
    expect((await target.previewLedgerRestore(snapshot)).canRestore, isFalse);
    await expectLater(target.restoreLedgerBackup(snapshot), throwsStateError);
    expect((await target.exportLedgerBackup()).encode(), before);
  });

  test('voided account payments alone block restore', () async {
    await target.recordAccountPayment(
      id: 'only-void',
      accountLabel: 'Fixture',
      amount: const Money('USD', 0),
      paidDate: const LedgerDate(2026, 1, 1),
    );
    await target.undoPayment('only-void');
    final snapshot = await source.exportLedgerBackup();
    expect((await target.previewLedgerRestore(snapshot)).conflicts, [
      '目标台账已有付款（含撤销）',
    ]);
    await expectLater(target.restoreLedgerBackup(snapshot), throwsStateError);
  });

  test('mid-import failure rolls back ledger, FX, trigger rows and keeps unrelated data', () async {
    await populateBackupFixture(source);
    await target.saveFx(const FxSettings(displayCurrency: 'USD'));
    await target.saveThemeMode('light');
    final db = await databaseFactoryFfiNoIsolate.openDatabase(targetPath);
    await db.insert('snippets', {
      'id': 'kept',
      'name': 'Kept',
      'content': 'synthetic',
    });
    final before = (await target.exportLedgerBackup()).encode();
    final snapshot = await source.exportLedgerBackup();
    await expectLater(
      target.restoreLedgerBackup(
        snapshot,
        afterInsert: (count) async {
          if (count == 5) throw StateError('injected rollback');
        },
      ),
      throwsStateError,
    );
    expect((await target.exportLedgerBackup()).encode(), before);
    expect(await target.reminderRules(), isEmpty);
    expect(await target.themeMode(), 'light');
    expect((await target.snippets()).single.id, 'kept');
    await target.restoreLedgerBackup(snapshot);
    expect((await target.servers()).length, 2);
  });

  test('strictly rejects wrong version, unknown fields, malformed types and relations', () async {
    await populateBackupFixture(source);
    final text = (await source.exportLedgerBackup()).encode();
    final mutations = <void Function(Map<String, dynamic>)>[
      (m) => m['version'] = 2,
      (m) => m['version'] = 1.0,
      (m) => m['credentials'] = [],
      (m) => m.remove('fx'),
      (m) => m['servers'] = {},
      (m) => m['servers'].first['favorite'] = true,
      (m) => m['servers'].first['revision'] = -1,
      (m) => m['servers'].first['amount_minor'] = 0.5,
      (m) => m['servers'].first['amount_minor'] = Money.maxMinor + 1,
      (m) => m['servers'].first['currency'] = 'XXX',
      (m) => m['servers'].first['notes'] = 'injected secret',
      (m) => m['servers'].first['group_id'] = 'missing',
      (m) => m['servers'].add(m['servers'].first),
      (m) => m['servers'].first['created_at'] = '2026-02-30T00:00:00.000Z',
      (m) => m['exported_at'] = '2026-10-06',
      (m) => m['payments'].first['paid_date'] = '2026-02-30',
      (m) => m['payments'].first['paid_date'] = '0000-01-01',
      (m) => m['payments'].first['request_fingerprint'] = 'injected',
      (m) => m['payments'].first['server_id'] = 'missing',
      (m) => m['payments'].first['cycle_count'] = 4,
      (m) => m['service_periods'].first['payment_id'] = 'missing',
      (m) => m['service_periods'].first['server_id'] = 'missing',
      (m) => m['service_periods'].first['end_date'] =
          m['service_periods'].first['start_date'],
      (m) => m['service_periods'].removeAt(0),
      (m) => m['service_periods'].removeWhere((r) => r['payment_id'] == null),
      (m) => m['fx']['usd_to_cny'] = '0',
      (m) => m['fx']['rate_date'] = null,
      (m) => m['groups'].add({...m['groups'].first, 'id': 'duplicate-name'}),
      (m) => m['groups'].first['name'] = 'x' * 41,
    ];
    for (var i = 0; i < mutations.length; i++) {
      final value = jsonDecode(text) as Map<String, dynamic>;
      mutations[i](value);
      expect(
        () => LedgerBackupSnapshot.decode(jsonEncode(value)),
        throwsFormatException,
        reason: 'mutation $i',
      );
    }
    expect(await target.servers(), isEmpty);
  });

  test('rejects oversized input, collections, and invalid JSON', () async {
    expect(
      () => LedgerBackupSnapshot.decode(
        'x' * (LedgerBackupSnapshot.maxBytes + 1),
      ),
      throwsFormatException,
    );
    expect(() => LedgerBackupSnapshot.decode('{broken'), throwsFormatException);
    final value = jsonDecode(
      (await source.exportLedgerBackup()).encode(),
    ) as Map<String, dynamic>;
    value['groups'] = List.filled(LedgerBackupSnapshot.maxRows + 1, {});
    expect(
      () => LedgerBackupSnapshot.decode(jsonEncode(value)),
      throwsFormatException,
    );
  });
}
