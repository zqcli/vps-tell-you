import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/finance/finance_math.dart';
import 'package:vps_tell_you/finance/finance_models.dart';
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
    'a payment deleted while keeping its term and an edited one round trip',
    () async {
      await source.saveServer(backupServer(), isNew: true);
      Future<PaymentRecord> renew(String id) async {
        final server = (await source.servers()).single;
        return source.recordPayment(
          id: id,
          server: server,
          amount: const Money('USD', 123),
          paidDate: const LedgerDate(2026, 1, 1),
          cycleCount: 1,
          until: renewalDate(server, 1),
          confirmed: true,
        );
      }

      final kept = await renew('kept-term');
      final edited = await renew('edited');
      await source.deletePayment(original: kept);
      await source.editPayment(
        original: edited,
        amount: const Money('CNY', 999),
        paidDate: const LedgerDate(2026, 1, 2),
        note: 'fixed',
      );
      final snapshot = await source.exportLedgerBackup();
      await target.restoreLedgerBackup(snapshot);
      expect((await target.exportLedgerBackup()).encode(), snapshot.encode());
      expect(
        (await target.servicePeriods()).where(
          (p) => p.paymentId == 'kept-term',
        ),
        hasLength(1),
      );
    },
  );

  test('rollbacks and repaired orphan terms (incl. after unrelated edits) round trip through the v1 validator', () async {
    await source.saveServer(backupServer(), isNew: true);
    Future<PaymentRecord> renew(String id) async {
      final server = (await source.servers()).single;
      return source.recordPayment(
        id: id,
        server: server,
        amount: const Money('USD', 123),
        paidDate: const LedgerDate(2026, 1, 1),
        cycleCount: 1,
        until: renewalDate(server, 1),
        confirmed: true,
      );
    }

    var copies = 0;
    Future<void> roundTrip() async {
      final snapshot = await source.exportLedgerBackup();
      final copy = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${directory.path}/copy-${copies++}.sqlite',
        clock: () => backupNow,
      );
      await copy.restoreLedgerBackup(snapshot);
      expect((await copy.exportLedgerBackup()).encode(), snapshot.encode());
      await copy.close();
    }

    final rolled = await renew('rolled');
    await source.setFavorite((await source.servers()).single, true);
    await source.deletePayment(
      original: rolled,
      rollbackRenewal: true,
      expectedServerRevision: (await source.servers()).single.revision,
    );
    await roundTrip();

    final kept = await renew('kept');
    final stacked = await renew('stacked');
    await source.deletePayment(original: stacked);
    await source.deletePayment(original: kept);
    await roundTrip(); // legacy shape: voided payments keep their periods
    for (var i = 0; i < 2; i++) {
      final server = (await source.servers()).single;
      await source.rollbackOrphanTerm(
        serverId: server.id,
        expectedRevision: server.revision,
      );
      await roundTrip();
    }
    final server = (await source.servers()).single;
    expect(
      (await source.servicePeriods()).where((p) => p.paymentId != null),
      isEmpty,
    );
    expect(server.dueDate, backupServer().dueDate);
    await renew('after-repair');
    await roundTrip();
  });

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
