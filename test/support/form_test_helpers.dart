import 'package:flutter/cupertino.dart' show CupertinoDatePicker;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/core/ui/ui.dart';

/// Shared interactions for the grouped server form (`ServerForm`) and the
/// hardware group (`ServerResourceFields`).

/// Controller of the single-line field with [key] (an [AppTextField]).
TextEditingController fieldController(WidgetTester tester, String key) =>
    tester.widget<AppTextField>(find.byKey(ValueKey(key))).controller!;

/// Taps the bold nav-bar save action and lets the save finish.
///
/// A route that is not popped (a form used as `home:`) keeps the busy spinner
/// forever, so it must not be waited for with `pumpAndSettle`.
Future<void> tapSave(WidgetTester tester) async {
  await tester.tap(find.text('保存'));
  await tester.pump();
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
    await tester.pumpAndSettle();
  }
}

/// Digits shown by the vCPU stepper; empty while the count is unknown (—).
String vcpuText(WidgetTester tester) {
  final text = tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('resource-vcpu')),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data ?? '')
      .first;
  return text == '—' ? '' : text;
}

/// Sets vCPU through the stepper's exact-entry sheet (`null` = unknown).
Future<void> setVcpu(WidgetTester tester, int? value) async {
  final stepper = find.byKey(const ValueKey('resource-vcpu'));
  await tester.ensureVisible(stepper);
  await tester.pumpAndSettle();
  // The stepper's centre is its number.
  await tester.tap(stepper);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('resource-vcpu-entry')),
    value?.toString() ?? '',
  );
  await tester.tap(
    find.byKey(
      ValueKey(value == null ? 'resource-vcpu-unknown' : 'resource-vcpu-done'),
    ),
  );
  await tester.pumpAndSettle();
}

/// Selects [unit] in the compact segmented control of a capacity row.
Future<void> chooseUnit(WidgetTester tester, String field, String unit) async {
  final segmented = find.byKey(ValueKey('resource-unit-$field'));
  await tester.ensureVisible(segmented);
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: segmented, matching: find.text(unit)));
  await tester.pumpAndSettle();
}

/// Opens a picker row / button and taps option [title] in the bottom sheet.
Future<void> chooseOption(
  WidgetTester tester,
  Finder opener,
  String title,
) async {
  await tester.ensureVisible(opener);
  await tester.pumpAndSettle();
  await tester.tap(opener);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(BottomSheet), matching: find.text(title)),
  );
  await tester.pumpAndSettle();
}

/// Opens the date sheet of [row] and confirms [date] (`null` = "set unknown").
Future<void> pickDate(WidgetTester tester, Finder row, DateTime? date) async {
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
  if (date == null) {
    await tester.tap(find.byKey(const ValueKey('date-sheet-unknown')));
  } else {
    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(date);
    await tester.tap(find.byKey(const ValueKey('date-sheet-done')));
  }
  await tester.pumpAndSettle();
}
