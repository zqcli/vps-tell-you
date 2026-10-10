import 'dart:ui' show SemanticsValidationResult;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/servers/server_resource_fields.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

import 'support/form_test_helpers.dart';

void main() {
  Future<GlobalKey<ServerResourceFieldsState>> mount(
    WidgetTester tester, {
    bool importing = false,
    ServerResources? initial,
    ValueNotifier<double>? scale,
  }) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final textScale = scale ?? ValueNotifier<double>(2);
    if (scale == null) addTearDown(textScale.dispose);
    final key = GlobalKey<ServerResourceFieldsState>();
    final content = Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ServerResourceFields(
          key: key,
          importing: importing,
          initial: initial,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: ValueListenableBuilder<double>(
          valueListenable: textScale,
          child: content,
          builder: (context, factor, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(factor)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return key;
  }

  Future<void> fill(WidgetTester tester, String id, String value) async {
    final field = find.byKey(ValueKey('resource-$id'));
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
    await tester.pumpAndSettle();
  }

  Future<void> toggleUnlimited(WidgetTester tester) async {
    final field = find.byKey(const ValueKey('resource-traffic-unlimited'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
  }

  testWidgets('row validation recovers after clearing or changing units', (
    tester,
  ) async {
    final key = await mount(tester);
    expect(key.currentState!.validateAndRead(), isNotNull);
    await fill(tester, 'diskBytes', '0');
    expect(key.currentState!.validateAndRead(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('请填写大于 0 的容量，精确到整字节'), findsOneWidget);
    await fill(tester, 'diskBytes', '');
    expect(key.currentState!.validateAndRead()!.diskBytes, isNull);
    await tester.pumpAndSettle();
    expect(find.text('请填写大于 0 的容量，精确到整字节'), findsNothing);

    await fill(tester, 'ramBytes', '1.5');
    expect(key.currentState!.validateAndRead()!.ramBytes, 1572864);
    await chooseUnit(tester, 'ramBytes', 'B');
    expect(key.currentState!.validateAndRead(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('请填写大于 0 的容量，精确到整字节'), findsOneWidget);
    await chooseUnit(tester, 'ramBytes', 'GiB');
    expect(key.currentState!.validateAndRead()!.ramBytes, 1610612736);
    await tester.pumpAndSettle();
    expect(find.text('请填写大于 0 的容量，精确到整字节'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('required traffic error clears for unlimited and returns after', (
    tester,
  ) async {
    final key = await mount(
      tester,
      importing: true,
      initial: ServerResources(
        ip: '192.0.2.1',
        hostname: 'review.example',
        vcpu: 1,
        ramBytes: 1048576,
        diskBytes: 1073741824,
      ),
    );
    expect(key.currentState!.validateAndRead(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('请填写大于 0 的容量，精确到整字节'), findsOneWidget);
    await toggleUnlimited(tester);
    var result = key.currentState!.validateAndRead()!;
    expect(result.trafficUnlimited, isTrue);
    expect(result.trafficBytes, isNull);
    await tester.pumpAndSettle();
    expect(find.text('请填写大于 0 的容量，精确到整字节'), findsNothing);
    await chooseOption(
      tester,
      find.byKey(const ValueKey('resource-traffic-period')),
      '每年',
    );
    expect(key.currentState!.validateAndRead()!.trafficPeriodMonths, 12);
    await toggleUnlimited(tester);
    expect(key.currentState!.validateAndRead(), isNull);
    await chooseUnit(tester, 'trafficBytes', 'B');
    await fill(tester, 'trafficBytes', '9007199254740991');
    result = key.currentState!.validateAndRead()!;
    expect(result.trafficBytes, ServerResources.maxBytes);
    expect(result.trafficPeriodMonths, 12);
    expect(result.trafficUnlimited, isFalse);
    await tester.pumpAndSettle();
    expect(find.text('请填写大于 0 的容量，精确到整字节'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capacity error is associated with the editable semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final key = await mount(tester);
      await fill(tester, 'diskBytes', '0');
      expect(key.currentState!.validateAndRead(), isNull);
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('resource-diskBytes'));
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      final node = tester.getSemantics(field);
      expect(node.label, contains('磁盘容量'));
      expect(node.hint, contains('请填写大于 0 的容量，精确到整字节'));
      expect(
        node.validationResult,
        SemanticsValidationResult.invalid,
        reason: node.toStringDeep(),
      );
      await fill(tester, 'diskBytes', '1');
      expect(key.currentState!.validateAndRead(), isNotNull);
      await tester.pumpAndSettle();
      final valid = tester.getSemantics(field);
      expect(valid.validationResult, SemanticsValidationResult.valid);
      expect(valid.hint, isNot(contains('请填写大于 0 的容量')));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('resizing mid-edit preserves quota, unit, period and cursor', (
    tester,
  ) async {
    final scale = ValueNotifier<double>(1);
    addTearDown(scale.dispose);
    final key = await mount(tester, scale: scale);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    await fill(tester, 'trafficBytes', '1.25');
    await chooseUnit(tester, 'trafficBytes', 'TiB');
    await chooseOption(
      tester,
      find.byKey(const ValueKey('resource-traffic-period')),
      '每季',
    );
    final before = key.currentState!.validateAndRead()!.toJson();
    final input = find.byKey(const ValueKey('resource-trafficBytes'));
    final controller = tester.widget<AppTextField>(input).controller!;
    controller.selection = const TextSelection.collapsed(offset: 2);
    tester.view.physicalSize = const Size(320, 844);
    scale.value = 2;
    await tester.pumpAndSettle();
    await tester.ensureVisible(input);
    expect(tester.widget<AppTextField>(input).controller, same(controller));
    expect(controller.text, '1.25');
    expect(controller.selection.baseOffset, 2);
    expect(key.currentState!.validateAndRead()!.toJson(), before);
    expect(tester.takeException(), isNull);
  });
}
