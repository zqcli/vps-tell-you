import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/app.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/providers/provider_directory.dart';
import 'package:vps_tell_you/servers/server_record.dart';

void main() {
  testWidgets('bench rebuilds', (tester) async {
    sqfliteFfiInit();
    final now = DateTime.utc(2026, 10, 16);
    late LedgerStore store;
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('bench-');
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${dir.path}/l.sqlite3',
      );
      for (var i = 0; i < 300; i++) {
        await store.saveServer(
          ServerRecord(id: 's$i', name: 'srv-$i', vendor: '', createdAt: now, updatedAt: now),
          isNew: true,
        );
      }
    });
    await tester.pumpWidget(LedgerApp(openStore: () async => store, directory: ProviderDirectory.memory()));
    print("A"); await tester.pumpAndSettle(); print("B");
    final c = tester.widget<HomeShell>(find.byType(HomeShell)).controller;
    var n = 0;
    debugOnRebuildDirtyWidget = (e, builtOnce) => n++;
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(c.refresh);
      await tester.pump();
    }
    debugOnRebuildDirtyWidget = null;
    // ignore: avoid_print
    print('BENCH rebuilt elements for 10 refreshes: $n, ${sw.elapsedMilliseconds}ms');
    await tester.runAsync(() async { await store.close(); });
  });
}
