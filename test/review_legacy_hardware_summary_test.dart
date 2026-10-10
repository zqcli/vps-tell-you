import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_form.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

import 'support/form_test_helpers.dart';

void main() {
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('review-legacy-summary-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
    );
    ledger = LedgerController(store);
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });
  for (final customSummary in [false, true]) {
    testWidgets(
      customSummary
          ? 'hardware edits preserve a custom legacy specification'
          : 'hardware edits update the auto-generated v7 specification',
      (tester) async {
        final legacyResources = ServerResources.fromJson({
          'ip': '192.0.2.10',
          'hostname': 'legacy.example',
          'vcpu': 2,
          'ramBytes': 2147483648,
          'diskBytes': 21474836480,
          'trafficBytes': 1099511627776,
          'trafficUnlimited': false,
          'apiFields': <String>[],
        });
        const automatic = '2 vCPU · 2 GiB RAM · 20 GiB 硬盘 · 1 TiB 流量';
        const custom = 'User-maintained specification';
        await store.saveServer(
          ServerRecord(
            id: 'legacy-summary',
            name: 'Legacy server',
            vendor: 'Fixture',
            spec: customSummary ? custom : automatic,
            resources: legacyResources,
            createdAt: DateTime.utc(2026, 10, 6),
            updatedAt: DateTime.utc(2026, 10, 6),
          ),
          isNew: true,
        );
        await ledger.refresh();
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(),
            home: ServerForm(controller: ledger, record: ledger.active.single),
          ),
        );
        await tester.pumpAndSettle();
        await setVcpu(tester, 4);
        await tapSave(tester);
        final saved = (await store.servers()).single;
        expect(saved.resources!.vcpu, 4);
        expect(saved.resources!.trafficPeriodMonths, isNull);
        expect(
          saved.spec,
          customSummary ? custom : saved.resources!.specSummary,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
