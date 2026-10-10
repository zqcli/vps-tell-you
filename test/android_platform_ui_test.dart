import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/app.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/server_detail.dart';
import 'package:vps_tell_you/servers/server_form.dart';

import 'support/reminder_platform.dart';

/// The iOS-style design is shared by Android; these checks make sure the
/// Android system back action still unwinds sheets, page sheets and pushed
/// pages in order.
void main() {
  late Directory directory;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('vps-android-ui-');
  });
  tearDown(() => directory.delete(recursive: true));

  testWidgets('Android back closes filter sheet, form sheet and detail page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late LedgerStore store;
    await tester.runAsync(() async {
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${directory.path}/ledger.sqlite3',
      );
      await store.loadDemo();
    });
    await tester.pumpWidget(
      LedgerApp(
        openStore: () async => store,
        reminderPlatform: FakeReminderPlatform(),
      ),
    );
    for (var i = 0; i < 20 && find.byType(HomeShell).evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);

    // Filter sheet.
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);

    // Pushed detail page, then the edit page sheet above it.
    await tester.tap(find.textContaining('HK-01').first);
    await tester.pumpAndSettle();
    expect(find.byType(ServerDetail), findsOneWidget);
    await tester.tap(find.text('编辑').first);
    await tester.pumpAndSettle();
    expect(find.byType(ServerForm), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ServerForm), findsNothing);
    expect(find.byType(ServerDetail), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ServerDetail), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(store.close);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
