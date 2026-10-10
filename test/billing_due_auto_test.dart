import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_form.dart';

import 'support/form_test_helpers.dart';

/// Due date = start date + cycle (the renewal month-anchor rules), refreshed
/// when the start or the cycle changes unless the user typed a due date.
void main() {
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('due-auto-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
    );
    ledger = LedgerController(store);
    await ledger.refresh();
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: ServerForm(controller: ledger),
      ),
    );
    await tester.pumpAndSettle();
    final billing = find.byKey(const ValueKey('field-billing'));
    await tester.ensureVisible(billing);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: billing, matching: find.text('预付')));
    await tester.pumpAndSettle();
  }

  Finder row(String id) => find.byKey(ValueKey('field-$id'));
  String shown(WidgetTester tester, String id) => tester
      .widgetList<Text>(
        find.descendant(of: row(id), matching: find.byType(Text)),
      )
      .map((t) => t.data ?? '')
      .firstWhere(
        (t) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t),
        orElse: () => '',
      );
  Future<void> cycle(WidgetTester tester, String title) =>
      chooseOption(tester, row('cycle'), title);

  testWidgets('start date fills the due date from the chosen cycle', (
    tester,
  ) async {
    await mount(tester);
    expect(shown(tester, 'due'), isEmpty);
    await cycle(tester, '每年');
    await pickDate(tester, row('start'), DateTime(2026, 3, 15));
    expect(shown(tester, 'due'), '2027-03-15');
    await cycle(tester, '每 6 个月');
    expect(shown(tester, 'due'), '2026-09-15');
    await cycle(tester, '每 3 个月');
    expect(shown(tester, 'due'), '2026-06-15');
    await pickDate(tester, row('start'), DateTime(2026, 4, 1));
    expect(shown(tester, 'due'), '2026-07-01');
    for (final entry in {
      'field-name': 'Auto due',
      'field-amount': '5',
    }.entries) {
      await tester.ensureVisible(find.byKey(ValueKey(entry.key)));
      await tester.enterText(find.byKey(ValueKey(entry.key)), entry.value);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    }
    await tapSave(tester);
    final saved = (await store.servers()).single;
    expect(saved.startDate, const LedgerDate(2026, 4, 1));
    expect(saved.dueDate, const LedgerDate(2026, 7, 1));
    expect(saved.cycleMonths, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('month ends and leap days follow the renewal anchor rules', (
    tester,
  ) async {
    await mount(tester);
    await cycle(tester, '每 6 个月');
    await pickDate(tester, row('start'), DateTime(2026, 8, 31));
    expect(shown(tester, 'due'), '2027-02-28');
    await cycle(tester, '每年');
    await pickDate(tester, row('start'), DateTime(2024, 2, 29));
    expect(shown(tester, 'due'), '2025-02-28');
    await cycle(tester, '每 24 个月');
    expect(shown(tester, 'due'), '2026-02-28');
    expect(
      shown(tester, 'due'),
      const LedgerDate(2024, 2, 29).addMonths(24).toString(),
    );
  });

  testWidgets('a manually chosen due date is never overwritten', (
    tester,
  ) async {
    await mount(tester);
    await pickDate(tester, row('start'), DateTime(2026, 3, 15));
    expect(shown(tester, 'due'), '2027-03-15');
    await pickDate(tester, row('due'), DateTime(2030, 1, 1));
    await cycle(tester, '每 6 个月');
    expect(shown(tester, 'due'), '2030-01-01');
    await pickDate(tester, row('start'), DateTime(2026, 5, 5));
    expect(shown(tester, 'due'), '2030-01-01');
    // Setting it back to the derived value re-enables following the cycle.
    await pickDate(tester, row('due'), DateTime(2026, 11, 5));
    await cycle(tester, '每年');
    expect(shown(tester, 'due'), '2027-05-05');
    // Clearing the due date also hands it back to the automatic rule.
    await pickDate(tester, row('due'), null);
    expect(shown(tester, 'due'), isEmpty);
    await pickDate(tester, row('start'), DateTime(2026, 6, 6));
    expect(shown(tester, 'due'), '2027-06-06');
  });
}
