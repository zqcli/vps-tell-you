import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/servers/server_resource_fields.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

import 'support/form_review_harness.dart';
import 'support/form_test_helpers.dart';

void main() {
  final harness = FormReviewHarness(
    boundaryKey: const ValueKey('compact-rows-evidence'),
    fontFamily: 'Compact QA Noto',
    fontPath: '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    evidenceDirectory: Platform.environment['VPS_COMPACT_ROWS_EVIDENCE_DIR'],
  );
  final initial = ServerResources(
    ip: '192.0.2.123',
    ipv6: '2001:db8::123',
    hostname: 'long-synthetic-server-name.example',
    vcpu: 2,
    ramBytes: 1610612736,
    diskBytes: 21474836480,
    trafficBytes: 9007199254740991,
  );

  Future<GlobalKey<ServerResourceFieldsState>> mount(
    WidgetTester tester, {
    required double width,
    required double scale,
    bool enabled = true,
  }) async {
    final key = GlobalKey<ServerResourceFieldsState>();
    await harness.mount(
      tester,
      size: Size(width, 844),
      scale: scale,
      captureRoutes: false,
      page: (_) => Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ServerResourceFields(key: key, initial: initial, enabled: enabled),
        ),
      ),
    );
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

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('capacity rows stay inline at $width px / $scale text', (
        tester,
      ) async {
        final key = await mount(tester, width: width, scale: scale);
        expect(key.currentState!.validateAndRead()!.toJson(), initial.toJson());
        for (final field in ['diskBytes', 'trafficBytes', 'ramBytes']) {
          final row = find.byKey(ValueKey('resource-row-$field'));
          await tester.ensureVisible(row);
          await tester.pumpAndSettle();
          final value = tester.getRect(find.byKey(ValueKey('resource-$field')));
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
            reason: 'Selected capacity units must remain complete on one line',
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

            await harness.capture(tester, 'traffic-${width.toInt()}-${scale.toInt()}x');
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
        // Shown in the best unit (8192 TiB); the exact stored bytes are
        // kept (asserted above) because the field was not edited.
        expect(fieldController(tester, 'resource-trafficBytes').text, '8192');
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
        expect(key.currentState!.validateAndRead()!.trafficUnlimited, isTrue);
        await tester.ensureVisible(unlimited);
        await tester.tap(unlimited);
        await tester.pumpAndSettle();
        expect(
          key.currentState!.validateAndRead()!.trafficBytes,
          9007199254740991,
        );
        expect(tester.takeException(), isNull);

        await chooseUnit(tester, 'trafficBytes', 'TiB');
        final traffic = find.byKey(const ValueKey('resource-trafficBytes'));
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
        await harness.capture(tester, 'quarter-${width.toInt()}-${scale.toInt()}x');
      });
    }
  }

  testWidgets(
    'compact controls respect disabled state without losing exact values',
    (tester) async {
      final key = await mount(tester, width: 320, scale: 2, enabled: false);
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
    final key = await mount(tester, width: 320, scale: 2);
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
    await harness.capture(tester, 'traffic-320-2x-error');
    expect(tester.takeException(), isNull);
  });
}
