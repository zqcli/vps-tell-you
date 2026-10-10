import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_form.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resource_fields.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

import 'support/form_test_helpers.dart';

void main() {
  final evidence = Platform.environment['VPS_INLINE_UX_EVIDENCE_DIR'];
  var fontsLoaded = false;
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late ServerRecord record;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('inline-ux-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
    );
    ledger = LedgerController(store);
    record = ServerRecord(
      id: 'ux-fixture',
      name: '合成演示服务器',
      vendor: '合成厂商',
      billing: BillingKind.prepaid,
      amountMinor: 1250,
      cycleMonths: 3,
      startDate: const LedgerDate(2026, 1, 1),
      dueDate: const LedgerDate(2027, 1, 1),
      resources: ServerResources(
        ip: '192.0.2.15',
        hostname: 'synthetic.example',
        ramBytes: 1610612736,
        diskBytes: 21474836480,
        trafficBytes: 1649267441664,
        trafficPeriodMonths: 3,
        vcpu: 2,
      ),
      createdAt: DateTime.utc(2026, 10, 6),
      updatedAt: DateTime.utc(2026, 10, 6),
    );
    await store.saveServer(record, isNew: true);
    await ledger.refresh();
    record = ledger.active.single;
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester,
    double width,
    double scale, {
    bool create = false,
    double height = 844,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (evidence != null && !fontsLoaded) {
      await tester.runAsync(() async {
        final font = FontLoader('Inline UX Noto');
        font.addFont(
          File(
            Platform.environment['VPS_FORM_EVIDENCE_FONT_PATH'] ??
                '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
          ).readAsBytes().then(ByteData.sublistView),
        );
        await font.load();
        final icons = FontLoader('MaterialIcons');
        icons.addFont(
          File(
            '${Platform.environment['FLUTTER_BOOTSTRAP_ROOT']}/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then(ByteData.sublistView),
        );
        await icons.load();
      });
      fontsLoaded = true;
    }
    final theme = appTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: evidence == null
            ? theme
            : theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'Inline UX Noto'),
                appBarTheme: theme.appBarTheme.copyWith(
                  titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
                    fontFamily: 'Inline UX Noto',
                  ),
                ),
              ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: const ValueKey('inline-ux-evidence'),
          child: ServerForm(controller: ledger, record: create ? null : record),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String id, String value) async {
    final field = find.byKey(ValueKey(id));
    await reveal(tester, field);
    await tester.enterText(field, value);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (evidence == null) return;
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('inline-ux-evidence')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(evidence).create(recursive: true);
      await File('$evidence/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'short choices and unlimited remain natural inline at $width / $scale',
        (tester) async {
          await mount(tester, width, scale);
          final billing = find.byKey(const ValueKey('field-billing'));
          await reveal(tester, billing);
          // Label left, compact segmented control right (or below the label
          // when the label and three choices cannot share one line).
          final billingRow = tester.getRect(
            find.byKey(const ValueKey('row-billing')),
          );
          final billingRect = tester.getRect(billing);
          expect(find.text('计费方式'), findsOneWidget);
          expect(billingRect.left, greaterThanOrEqualTo(billingRow.left));
          expect(billingRect.right, lessThanOrEqualTo(billingRow.right));
          expect(
            find.descendant(of: billing, matching: find.text('预付')),
            findsOneWidget,
          );
          final feeRow = find.byKey(const ValueKey('row-fees'));
          await reveal(tester, feeRow);
          final amountRect = tester.getRect(
            find.byKey(const ValueKey('field-amount')),
          );
          final currencyRect = tester.getRect(
            find.byKey(const ValueKey('field-currency')),
          );
          // Amount and currency share one row.
          expect(amountRect.top, closeTo(currencyRect.top, 12));
          expect(amountRect.right, lessThan(currencyRect.left));
          expect(currencyRect.width, greaterThanOrEqualTo(44));
          expect(currencyRect.height, greaterThanOrEqualTo(44));
          expect(currencyRect.right, lessThanOrEqualTo(width));
          expect(amountRect.width, greaterThanOrEqualTo(48));
          final cycleRect = tester.getRect(
            find.byKey(const ValueKey('field-cycle')),
          );
          expect(cycleRect.height, greaterThanOrEqualTo(48));
          expect(cycleRect.right, lessThanOrEqualTo(width));
          for (final entry in {
            'field-start': '2026-01-01',
            'field-due': '2027-01-01',
          }.entries) {
            final row = find.byKey(ValueKey(entry.key));
            await reveal(tester, row);
            final text = find.descendant(
              of: row,
              matching: find.text(entry.value),
            );
            expect(text, findsOneWidget);
            // The complete ISO date stays on one line inside its row.
            expect(
              tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
              isFalse,
            );
            expect(
              tester.getRect(text).right,
              lessThanOrEqualTo(tester.getRect(row).right),
            );
            expect(tester.getRect(row).height, greaterThanOrEqualTo(48));
          }
          await chooseOption(
            tester,
            find.byKey(const ValueKey('field-currency')),
            'EUR',
          );
          await chooseOption(
            tester,
            find.byKey(const ValueKey('field-cycle')),
            '每 36 个月',
          );
          final amount = tester.widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('field-amount')),
              matching: find.byType(TextField),
            ),
          );
          expect(amount.decoration?.suffixText, isNull);
          expect(find.textContaining('每 36 个月续费金额，实付另记'), findsOneWidget);
          await reveal(tester, find.byKey(const ValueKey('row-billing')));
          await capture(tester, 'finance-${width.toInt()}-${scale.toInt()}x');
          final unlimited = find.byKey(
            const ValueKey('resource-traffic-unlimited'),
          );
          await reveal(tester, unlimited);
          final label = find.descendant(
            of: unlimited,
            matching: find.text('流量不限量'),
          );
          final toggle = find.descendant(
            of: unlimited,
            matching: find.byType(CupertinoSwitch),
          );
          expect(
            tester.getRect(label).center.dy,
            closeTo(tester.getRect(toggle).center.dy, 0.01),
          );
          expect(tester.getSize(unlimited).height, greaterThanOrEqualTo(48));
          await tester.tap(unlimited);
          await tester.pumpAndSettle();
          expect(tester.widget<AppSwitchRow>(unlimited).value, isTrue);
          expect(
            tester
                .widget<AppTextField>(
                  find.byKey(const ValueKey('resource-trafficBytes')),
                )
                .enabled,
            isFalse,
          );
          await tester.tap(unlimited);
          await tester.pumpAndSettle();
          final state = tester.state<ServerResourceFieldsState>(
            find.byType(ServerResourceFields),
          );
          expect(
            state.validateAndRead()!.trafficBytes,
            record.resources!.trafficBytes,
          );
          await reveal(
            tester,
            find.byKey(const ValueKey('resource-row-trafficBytes')),
          );
          await capture(tester, 'hardware-${width.toInt()}-${scale.toInt()}x');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'reversed dates reveal the due field from the bottom and retain the draft',
    (tester) async {
      await mount(tester, 320, 2);
      await pickDate(
        tester,
        find.byKey(const ValueKey('field-due')),
        DateTime(2025, 12, 31),
      );
      await fill(tester, 'field-notes', 'Keep this draft');
      await tapSave(tester);
      expect(find.text('到期日必须晚于开始日').hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('field-due')).hitTestable(),
        findsOneWidget,
      );
      expect((await store.servers()).single.notes, isEmpty);
      await capture(tester, 'date-error-320-2x');
      expect(fieldController(tester, 'field-notes').text, 'Keep this draft');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'small viewport reveals invalid IP and keeps the save action reachable',
    (tester) async {
      await mount(tester, 320, 2, height: 560);
      // The IP row only exists next to a domain address.
      await fill(tester, 'field-host', 'gateway.example');
      await fill(tester, 'resource-ip', '0.0.0.0');
      await fill(tester, 'field-notes', 'A draft survives validation');
      await tapSave(tester);
      final error = find.text('请填写有效 IPv4 或 IPv6，不能为全零地址');
      expect(error.hitTestable(), findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(error).didExceedMaxLines,
        isFalse,
      );
      expect(find.text('保存').hitTestable(), findsOneWidget);
      await capture(tester, 'ip-error-small-viewport');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new entry explains required fields and keeps unknown hardware quiet',
    (tester) async {
      await mount(tester, 390, 1, create: true);
      // Only the name is required (asterisk); the help is a single short line.
      expect(find.textContaining('仅保存在本机'), findsOneWidget);
      expect(find.textContaining('名称和厂商必填'), findsNothing);
      expect(find.text('未知可留空，之后可手动补充'), findsNothing);
      expect(find.text('容量单位按 1024 进制'), findsNothing);
      expect(find.textContaining('凭据库将在后续阶段提供'), findsNothing);
      final host = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('field-host')),
          matching: find.byType(TextField),
        ),
      );
      expect(host.autocorrect, isFalse);
      expect(host.textInputAction, TextInputAction.next);
      final notes = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('field-notes')),
          matching: find.byType(TextField),
        ),
      );
      expect(notes.keyboardType, TextInputType.multiline);
      expect(notes.textInputAction, TextInputAction.newline);
      await capture(tester, 'new-server-390-1x');
      expect(tester.takeException(), isNull);
    },
  );
}
