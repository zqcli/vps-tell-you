import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_form.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/security/security_controller.dart';

import 'cloud_store_test.dart' show completedResources;
import 'security_store_test.dart' show FakeSecretStore, FakeDeviceAuth;

void main() {
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late ServerRecord record;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('vps-resource-editor-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
    );
    record = ServerRecord(
      id: 'resource-editor',
      name: 'Original name',
      vendor: 'Fixture',
      resources: completedResources(),
      billing: BillingKind.prepaid,
      amountMinor: 1200,
      startDate: const LedgerDate(2026, 1, 1),
      dueDate: const LedgerDate(2027, 1, 1),
      createdAt: DateTime.utc(2026, 10, 6),
      updatedAt: DateTime.utc(2026, 10, 6),
    );
    await store.saveServer(record, isNew: true);
    ledger = LedgerController(
      store,
      security: SecurityController(
        store: store,
        secrets: FakeSecretStore(),
        authenticator: FakeDeviceAuth(),
      ),
    );
    await ledger.refresh();
    record = ledger.active.single;
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });
  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: ServerForm(controller: ledger, record: record),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('resource edits survive scrolling away to the notes field', (
    tester,
  ) async {
    await mount(tester);
    final hostname = find.byKey(const ValueKey('resource-hostname'));
    await tester.scrollUntilVisible(
      hostname,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(hostname, 'Changed-Hostname');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final notes = find.byKey(const ValueKey('field-notes'));
    await tester.scrollUntilVisible(
      notes,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(notes, 'Changed notes');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final saved = (await store.servers()).single;
    expect(saved.notes, 'Changed notes');
    expect(saved.resources!.hostname, 'Changed-Hostname');
  });
  testWidgets('resource edits survive scrolling away and back before save', (
    tester,
  ) async {
    await mount(tester);
    final hostname = find.byKey(const ValueKey('resource-hostname'));
    await tester.ensureVisible(hostname);
    await tester.enterText(hostname, 'Changed-Hostname');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final notes = find.byKey(const ValueKey('field-notes'));
    await tester.ensureVisible(notes);
    await tester.enterText(notes, 'Changed notes');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(hostname);
    expect(
      tester.widget<AppTextField>(hostname).controller!.text,
      'Changed-Hostname',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final saved = (await store.servers()).single;
    expect(saved.resources!.hostname, 'Changed-Hostname');
    expect(saved.resources!.apiFields, isNot(contains('hostname')));
    expect(saved.resources!.apiFields, contains('ramBytes'));
  });
  testWidgets('invalid resource edits cannot be hidden by scrolling away', (
    tester,
  ) async {
    await mount(tester);
    // vCPU is a stepper whose cleared state is "unknown", so it cannot hold an
    // invalid value; the disk capacity field exercises the same behaviour.
    final disk = find.byKey(const ValueKey('resource-diskBytes'));
    await tester.ensureVisible(disk);
    await tester.enterText(disk, '0');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final notes = find.byKey(const ValueKey('field-notes'));
    await tester.ensureVisible(notes);
    await tester.enterText(notes, 'Not yet saved');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final saved = (await store.servers()).single;
    expect(saved.notes, isEmpty);
    expect(saved.resources!.toJson(), record.resources!.toJson());
    await tester.ensureVisible(disk);
    expect(tester.widget<AppTextField>(disk).controller!.text, '0');
    expect(find.text('请填写大于 0 的容量，精确到整字节'), findsOneWidget);
  });
  testWidgets(
    'editing a name can save before resource fields scroll into view',
    (tester) async {
      await mount(tester);
      await tester.enterText(
        find.byKey(const ValueKey('field-name')),
        'Changed name',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final saved = (await store.servers()).single;
      expect(saved.name, 'Changed name');
      expect(saved.resources!.toJson(), record.resources!.toJson());
    },
  );
}
