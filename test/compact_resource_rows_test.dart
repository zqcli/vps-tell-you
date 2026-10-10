import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/servers/server_resource_fields.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

import 'support/form_test_helpers.dart';

void main() {
  final evidence = Platform.environment['VPS_COMPACT_ROWS_EVIDENCE_DIR'];
  final initial = ServerResources(
    ip: '2001:db8::123',
    hostname: 'long-synthetic-server-name.example',
    vcpu: 2,
    ramBytes: 1610612736,
    diskBytes: 21474836480,
    trafficBytes: 9007199254740991,
    apiFields: ServerResources.fieldKeys,
  );

  Future<GlobalKey<ServerResourceFieldsState>> mount(
    WidgetTester tester, {
    required double width,
    required double scale,
    required bool importing,
    bool enabled = true,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (evidence != null) {
      await tester.runAsync(() async {
        final font = FontLoader('Compact QA Noto');
        font.addFont(
          File('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc')
              .readAsBytes()
              .then(ByteData.sublistView),
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
    }
    final theme = appTheme();
    final key = GlobalKey<ServerResourceFieldsState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: evidence == null
            ? theme
            : theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'Compact QA Noto'),
              ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: const ValueKey('compact-rows-evidence'),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ServerResourceFields(
                key: key,
                initial: initial,
                importing: importing,
                enabled: enabled,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return key;
  }

  /// The unit selector is a compact segmented control; disabled rows absorb
  /// taps with an [IgnorePointer] because the control has no disabled state.
  bool unitIgnoresTaps(WidgetTester tester, String field) => tester
      .widget<IgnorePointer>(
        find
            .ancestor(
              of: find.byKey(ValueKey('resource-unit-$field')),
              matching: find.byType(IgnorePointer),
            )
            .first,
      )
      .ignoring;

  Future<void> capture(WidgetTester tester, String name) async {
    if (evidence == null) return;
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('compact-rows-evidence')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(evidence).create(recursive: true);
      await File('$evidence/$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final importing in [false, true]) {
        testWidgets(
          'capacity rows stay inline at $width px / $scale text, importing=$importing',
          (tester) async {
            final key = await mount(
              tester,
              width: width,
              scale: scale,
              importing: importing,
            );
            expect(
              key.currentState!.validateAndRead()!.toJson(),
              initial.toJson(),
            );
            for (final field in ['diskBytes', 'trafficBytes', 'ramBytes']) {
              final row = find.byKey(ValueKey('resource-row-$field'));
              await tester.ensureVisible(row);
              await tester.pumpAndSettle();
              final value = tester.getRect(
                find.byKey(ValueKey('resource-$field')),
              );
              final unit = tester.getRect(
                find.byKey(ValueKey('resource-unit-$field')),
              );
              // Beside the value when the row is wide enough, otherwise on
              // its own line below it; never clipped or overlapping.
              expect(
                unit.top >= value.bottom - 0.01 || value.right <= unit.left,
                isTrue,
                reason: 'unit selector must not overlap the value field',
              );
              expect(value.width, greaterThanOrEqualTo(48));
              expect(value.height, greaterThanOrEqualTo(40));
              expect(unit.width, greaterThanOrEqualTo(48));
              // The selector scales down (never clips) when four units cannot
              // fit the width at large text sizes.
              expect(unit.height, greaterThanOrEqualTo(20));
              final selectedUnit = find.descendant(
                of: find.byKey(ValueKey('resource-unit-$field')),
                matching: find.text(
                  field == 'ramBytes'
                      ? 'MiB'
                      : field == 'diskBytes'
                      ? 'GiB'
                      : 'B',
                ),
              );
              final unitParagraph = tester.renderObject<RenderParagraph>(
                selectedUnit,
              );
              expect(
                unitParagraph.getBoxesForSelection(
                  TextSelection(
                    baseOffset: 0,
                    extentOffset: field == 'trafficBytes' ? 1 : 3,
                  ),
                ),
                hasLength(1),
                reason:
                    'Selected capacity units must remain complete on one line',
              );
              expect(value.left, greaterThanOrEqualTo(16));
              expect(unit.right, lessThanOrEqualTo(width - 16 + 0.001));
              if (field == 'trafficBytes') {
                final period = tester.getRect(
                  find.byKey(const ValueKey('resource-traffic-period')),
                );
                expect(period.top, greaterThan(unit.top));
                expect(period.right, lessThanOrEqualTo(width - 16 + 0.001));
                expect(period.height, greaterThanOrEqualTo(44));
                if (!importing) {
                  await capture(
                    tester,
                    'traffic-${width.toInt()}-${scale.toInt()}x',
                  );
                }
              }
              expect(tester.takeException(), isNull);
            }
            await chooseUnit(tester, 'ramBytes', 'GiB');
            final ram = find.byKey(const ValueKey('resource-ramBytes'));
            await tester.ensureVisible(ram);
            await tester.enterText(ram, '1.5');
            await tester.pumpAndSettle();
            expect(key.currentState!.validateAndRead()!.ramBytes, 1610612736);
            for (final period in {
              '每月': 1,
              '每季': 3,
              '每年': 12,
              '未设置': null,
            }.entries) {
              await chooseOption(
                tester,
                find.byKey(const ValueKey('resource-traffic-period')),
                period.key,
              );
              final result = key.currentState!.validateAndRead()!;
              expect(result.trafficPeriodMonths, period.value);
              expect(result.trafficBytes, 9007199254740991);
            }
            expect(
              fieldController(tester, 'resource-trafficBytes').text,
              '9007199254740991',
            );
            final unlimited = find.byKey(
              const ValueKey('resource-traffic-unlimited'),
            );
            await tester.ensureVisible(unlimited);
            await tester.tap(unlimited);
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<AppTextField>(
                    find.byKey(const ValueKey('resource-trafficBytes')),
                  )
                  .enabled,
              isFalse,
            );
            expect(unitIgnoresTaps(tester, 'trafficBytes'), isTrue);
            // The quota period stays editable for unlimited traffic.
            await chooseOption(
              tester,
              find.byKey(const ValueKey('resource-traffic-period')),
              '每季',
            );
            expect(key.currentState!.validateAndRead()!.trafficPeriodMonths, 3);
            expect(
              key.currentState!.validateAndRead()!.trafficUnlimited,
              isTrue,
            );
            await tester.ensureVisible(unlimited);
            await tester.tap(unlimited);
            await tester.pumpAndSettle();
            expect(
              key.currentState!.validateAndRead()!.trafficBytes,
              9007199254740991,
            );
            expect(tester.takeException(), isNull);
            if (!importing) {
              await chooseUnit(tester, 'trafficBytes', 'TiB');
              final traffic = find.byKey(
                const ValueKey('resource-trafficBytes'),
              );
              await tester.ensureVisible(traffic);
              await tester.enterText(traffic, '1.5');
              FocusManager.instance.primaryFocus?.unfocus();
              await tester.pumpAndSettle();
              expect(
                key.currentState!.validateAndRead()!.trafficBytes,
                1649267441664,
              );
              await tester.ensureVisible(
                find.byKey(const ValueKey('resource-row-trafficBytes')),
              );
              await capture(
                tester,
                'quarter-${width.toInt()}-${scale.toInt()}x',
              );
            }
          },
        );
      }
    }
  }

  testWidgets(
    'compact controls respect disabled state without losing exact values',
    (tester) async {
      final key = await mount(
        tester,
        width: 320,
        scale: 2,
        importing: true,
        enabled: false,
      );
      for (final field in ['ramBytes', 'diskBytes', 'trafficBytes']) {
        expect(
          tester
              .widget<AppTextField>(find.byKey(ValueKey('resource-$field')))
              .enabled,
          isFalse,
        );
        expect(unitIgnoresTaps(tester, field), isTrue);
      }
      expect(
        tester
            .widget<AppFormRow>(
              find.byKey(const ValueKey('resource-traffic-period')),
            )
            .onTap,
        isNull,
      );
      expect(key.currentState!.validateAndRead()!.toJson(), initial.toJson());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long validation errors remain readable at narrow doubled text', (
    tester,
  ) async {
    final key = await mount(tester, width: 320, scale: 2, importing: false);
    final field = find.byKey(const ValueKey('resource-trafficBytes'));
    await tester.ensureVisible(field);
    await tester.enterText(field, '0.000000001');
    expect(key.currentState!.validateAndRead(), isNull);
    await tester.pumpAndSettle();
    await tester.ensureVisible(field);
    final error = find.text('请填写大于 0 的容量，精确到整字节');
    expect(error, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(error);
    expect(paragraph.didExceedMaxLines, isFalse);
    await capture(tester, 'traffic-320-2x-error');
    expect(tester.takeException(), isNull);
  });
}
