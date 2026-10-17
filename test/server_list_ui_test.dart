import 'package:flutter/cupertino.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_list.dart';

import 'support/provider_fixture.dart';

void main() {
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('vps-server-list-');
    DateTime clock() => DateTime(2026, 10, 6, 8);
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
      clock: clock,
    );
    await addTestProvider(store);
    await store.loadDemo();
    ledger = LedgerController(store, clock: clock);
    await ledger.refresh();
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: ServerList(controller: ledger),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the local ledger list has no pull-to-refresh', (tester) async {
    // The list follows the ledger live; there is no remote state to pull.
    await mount(tester);
    expect(find.byType(CupertinoSliverRefreshControl), findsNothing);
  });

  testWidgets('filter sheet applies group, due status and sort together', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已过期').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('按名称排序').last);
    await tester.pumpAndSettle();
    expect(find.text('显示 1 台'), findsOneWidget);
    // Nothing is applied before the confirm button.
    expect(ledger.dueFilter, DueFilter.all);
    await tester.tap(find.text('显示 1 台'));
    await tester.pumpAndSettle();
    expect(ledger.dueFilter, DueFilter.overdue);
    expect(ledger.sort, ServerSort.name);
    expect(ledger.visible, hasLength(1));
  });

  testWidgets('swipe reveals favourite action and toggles the record', (
    tester,
  ) async {
    await mount(tester);
    final server = ledger.visible.first;
    final row = find.byKey(ValueKey('server-${server.id}'));
    await tester.dragFrom(tester.getCenter(row), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text(server.favorite ? '取消常用' : '常用').last);
    await tester.pumpAndSettle();
    expect(ledger.byId(server.id)!.favorite, !server.favorite);
  });

  testWidgets('long press menu archives after confirmation and can undo', (
    tester,
  ) async {
    await mount(tester);
    final server = ledger.visible.first;
    await tester.longPress(find.byKey(ValueKey('server-${server.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('归档'));
    await tester.pumpAndSettle();
    expect(ledger.byId(server.id)!.archived, isFalse);
    await tester.tap(find.text('归档本地记录'));
    await tester.pumpAndSettle();
    expect(ledger.byId(server.id)!.archived, isTrue);
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(ledger.byId(server.id)!.archived, isFalse);
  });
}
