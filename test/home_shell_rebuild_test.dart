import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/app.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/providers/provider_directory.dart';
import 'package:vps_tell_you/servers/server_list.dart';

/// Rebuild breadth of the app shell: ledger changes and tab switches must not
/// rebuild the whole tree (measured: a tab switch with 300 servers rebuilt
/// ~12 000 elements before the pages were kept as stable widget instances).
void main() {
  late Directory directory;
  late LedgerStore store;

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('vps-shell-rebuild-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
    );
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  testWidgets('tab switches keep page widgets; ledger changes keep the app', (
    tester,
  ) async {
    await tester.pumpWidget(
      LedgerApp(
        openStore: () async => store,
        directory: ProviderDirectory.memory(),
      ),
    );
    await tester.pumpAndSettle();
    final list = tester.widget<ServerList>(find.byType(ServerList));
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-0')));
    await tester.pumpAndSettle();
    expect(
      identical(tester.widget<ServerList>(find.byType(ServerList)), list),
      isTrue,
    );

    final controller = tester
        .widget<HomeShell>(find.byType(HomeShell))
        .controller;
    await tester.runAsync(controller.refresh);
    await tester.pumpAndSettle();
    expect(
      identical(tester.widget<MaterialApp>(find.byType(MaterialApp)), app),
      isTrue,
      reason: 'only a theme or language change rebuilds the MaterialApp',
    );
  });
}
