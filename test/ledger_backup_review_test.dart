import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/finance/finance_math.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'ledger_backup_test.dart' show backupNow, backupServer;

void main() {
  late Directory directory;
  late LedgerStore source, target;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('review-backup-');
    source = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/source.sqlite',
      clock: () => backupNow,
    );
    target = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/target.sqlite',
      clock: () => backupNow,
    );
  });
  tearDown(() async {
    await source.close();
    await target.close();
    await directory.delete(recursive: true);
  });

  test(
    'voided history remains exportable after a permitted terms change',
    () async {
      await source.saveServer(backupServer(), isNew: true);
      var server = (await source.servers()).single;
      await source.recordPayment(
        id: 'renewal',
        server: server,
        amount: const Money('USD', 123),
        paidDate: const LedgerDate(2026, 1, 1),
        cycleCount: 1,
        until: renewalDate(server, 1),
        confirmed: true,
      );
      await source.undoPayment('renewal');
      server = (await source.servers()).single;
      await source.saveServer(
        ServerRecord.fromMap({...server.toMap(), 'billing': 'metered'}),
        isNew: false,
      );
      final snapshot = await source.exportLedgerBackup();
      await target.restoreLedgerBackup(snapshot);
      expect((await target.exportLedgerBackup()).encode(), snapshot.encode());
    },
  );

  test(
    'date lower-bound history can renew and round trip without initial period',
    () async {
      await source.saveServer(
        ServerRecord.fromMap({
          ...backupServer().toMap(),
          'start_date': null,
          'due_date': '0001-01-01',
        }),
        isNew: true,
      );
      final server = (await source.servers()).single;
      await source.recordPayment(
        id: 'ancient-renewal',
        server: server,
        amount: const Money('USD', 123),
        paidDate: const LedgerDate(2026, 1, 1),
        cycleCount: 3,
        until: renewalDate(server, 3),
        confirmed: true,
      );
      final snapshot = await source.exportLedgerBackup();
      await target.restoreLedgerBackup(snapshot);
      expect((await target.exportLedgerBackup()).encode(), snapshot.encode());
    },
  );

  test(
    'every valid stored descriptive field can be exported without truncation',
    () async {
      final server = ServerRecord.fromMap({
        ...backupServer().toMap(),
        'spec': 'x' * 4001,
      });
      expect(server.validate(), isNull);
      await source.saveServer(server, isNew: true);
      final snapshot = await source.exportLedgerBackup();
      await target.restoreLedgerBackup(snapshot);
      expect((await target.servers()).single.spec, server.spec);
    },
  );
}
