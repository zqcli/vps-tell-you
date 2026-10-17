import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/providers/provider_record.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_list.dart';
import 'package:vps_tell_you/servers/server_row.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'support/large_catalog.dart';

/// 1000 servers over 100 providers: the list builds only the rows on screen
/// and a search keystroke stays cheap.
void main() {
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  final now = DateTime.utc(2026, 10, 6);

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('vps-list-scale-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
      clock: () => now,
    );
    for (var i = 0; i < 1000; i++) {
      await store.saveServer(
        ServerRecord(
          id: 's$i',
          name: 'srv-$i',
          vendor: '',
          host: '10.0.${i ~/ 250}.${i % 250}',
          createdAt: now,
          updatedAt: now,
        ),
        isNew: true,
        catalogProvider: CatalogProviderRef(
          catalogId: largeProviderId(i % 100),
          name: largeProviderName(i % 100),
        ),
      );
    }
    ledger = LedgerController(
      store,
      clock: () => now,
      directory: largeDirectory(),
    );
    await ledger.refresh();
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  testWidgets('1000 servers: lazy rows and fast filtering', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: ServerList(controller: ledger),
      ),
    );
    await tester.pump();
    expect(find.byType(ServerRow).evaluate().length, lessThan(60));

    await tester.enterText(
      find.byKey(const ValueKey('server-search')),
      'srv-12',
    );
    await tester.pump();
    expect(ledger.visible.length, 11); // srv-12 and srv-120 .. srv-129
    expect(find.byType(ServerRow).evaluate().length, lessThan(60));
    // One filtered list per state, shared by every read of a frame.
    expect(identical(ledger.visible, ledger.visible), isTrue);
  });
}
