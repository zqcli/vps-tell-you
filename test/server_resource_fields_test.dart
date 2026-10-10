import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/servers/server_resource_fields.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

import 'support/form_test_helpers.dart';

void main() {
  Future<GlobalKey<ServerResourceFieldsState>> mount(
    WidgetTester tester, {
    Map<String, Object?> observed = const {},
    ServerResources? initial,
    double scale = 1,
  }) async {
    final key = GlobalKey<ServerResourceFieldsState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: ServerResourceFields(
                key: key,
                observed: observed,
                initial: initial,
              ),
            ),
          ),
        ),
      ),
    );
    return key;
  }

  Future<void> fill(WidgetTester tester, String id, String text) async {
    final field = find.byKey(ValueKey('resource-$id'));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.pump();
  }

  Future<void> stepVcpu(WidgetTester tester, int delta) async {
    final button = find.byKey(
      ValueKey(delta > 0 ? 'resource-vcpu-increase' : 'resource-vcpu-decrease'),
    );
    for (var i = 0; i < delta.abs(); i++) {
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
    }
  }

  final observed = <String, Object?>{
    'ip': '192.0.2.20',
    'hostname': 'Test-VM',
    'vcpu': 2,
    'ramBytes': 1073741824,
    'diskBytes': 21474836480,
    'trafficBytes': 1649267441664,
  };

  testWidgets(
    'all six valid API fields prefill exactly and overrides lose API provenance',
    (tester) async {
      final key = await mount(tester, observed: observed, scale: 2);
      var result = key.currentState!.validateAndRead()!;
      expect(result.apiFields, ServerResources.fieldKeys);
      expect(result.trafficBytes, 1649267441664);
      await fill(tester, 'hostname', 'Local-Override');
      await stepVcpu(tester, 2);
      result = key.currentState!.validateAndRead()!;
      expect(result.hostname, 'Local-Override');
      expect(result.vcpu, 4);
      expect(result.apiFields, isNot(contains('hostname')));
      expect(result.apiFields, isNot(contains('vcpu')));
      expect(result.apiFields, contains('diskBytes'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing memory/CPU block completion and manual unlimited is explicit',
    (tester) async {
      final key = await mount(
        tester,
        observed: {
          ...observed,
          'vcpu': null,
          'ramBytes': null,
          'trafficBytes': null,
        },
      );
      expect(key.currentState!.validateAndRead(), isNull);
      await tester.pump();
      await fill(tester, 'ramBytes', '0');
      await fill(tester, 'trafficBytes', '0');
      expect(key.currentState!.validateAndRead(), isNull);
      await stepVcpu(tester, 2);
      await fill(tester, 'ramBytes', '1536');
      final unlimited = find.byKey(
        const ValueKey('resource-traffic-unlimited'),
      );
      await tester.ensureVisible(unlimited);
      await tester.tap(unlimited);
      await tester.pump();
      final result = key.currentState!.validateAndRead()!;
      expect(result.trafficUnlimited, isTrue);
      expect(result.trafficBytes, isNull);
      expect(result.ramBytes, 1610612736);
      expect(result.apiFields, {'ip', 'hostname', 'diskBytes'});
    },
  );

  testWidgets(
    'decimal units are exact, malformed quotas and IP/hostname are rejected',
    (tester) async {
      final key = await mount(tester, observed: observed);
      await fill(tester, 'diskBytes', '1.5');
      expect(key.currentState!.validateAndRead()!.diskBytes, 1610612736);
      for (final invalid in [
        'NaN',
        '-1',
        '1e4',
        '0.000000001',
        '9007199254740992',
      ]) {
        await fill(tester, 'diskBytes', invalid);
        expect(key.currentState!.validateAndRead(), isNull, reason: invalid);
      }
      await fill(tester, 'diskBytes', '20');
      await fill(tester, 'ip', '0.0.0.0');
      expect(key.currentState!.validateAndRead(), isNull);
      await fill(tester, 'ip', '2001:db8::123');
      await fill(tester, 'hostname', 'https://server.test');
      expect(key.currentState!.validateAndRead(), isNull);
      await fill(tester, 'hostname', 'Valid-Name');
      expect(key.currentState!.validateAndRead()!.ip, '2001:db8::123');
    },
  );

  testWidgets(
    'editing persisted values preserves exact bytes and prior manual provenance',
    (tester) async {
      final initial = ServerResources(
        ip: '2001:db8::2',
        hostname: 'Saved-VM',
        vcpu: 3,
        ramBytes: 1048577,
        diskBytes: 1073741825,
        trafficBytes: 1099511627777,
        apiFields: {'ip', 'hostname', 'diskBytes'},
      );
      final key = await mount(tester, initial: initial);
      expect(key.currentState!.validateAndRead()!.toJson(), initial.toJson());
      // Shown as a short number in the best unit, not as raw bytes...
      expect(fieldController(tester, 'resource-ramBytes').text, '1');
      expect(fieldController(tester, 'resource-diskBytes').text, '1');
      expect(fieldController(tester, 'resource-trafficBytes').text, '1');
      // ...while the untouched exact values (and API provenance) survive.
      await chooseUnit(tester, 'diskBytes', 'B');
      await fill(tester, 'diskBytes', '1073741826');
      final updated = key.currentState!.validateAndRead()!;
      expect(updated.diskBytes, 1073741826);
      expect(updated.apiFields, {'ip', 'hostname'});
      expect(updated.ramBytes, 1048577);
      expect(updated.trafficBytes, 1099511627777);
    },
  );

  testWidgets('API sizes open in the best unit with a short rounded number', (
    tester,
  ) async {
    // 2 000 000 000 B is "2 GB" decimal: 1.86 GiB, not 2000000000 B.
    final initial = ServerResources(
      ip: '192.0.2.9',
      hostname: 'api.example',
      vcpu: 2,
      ramBytes: 2000000000,
      diskBytes: 53687091200,
      trafficBytes: 1500000000000,
      apiFields: {'ramBytes', 'diskBytes', 'trafficBytes'},
    );
    final key = await mount(tester, initial: initial);
    expect(fieldController(tester, 'resource-ramBytes').text, '1.86');
    expect(fieldController(tester, 'resource-diskBytes').text, '50');
    expect(fieldController(tester, 'resource-trafficBytes').text, '1.36');
    final untouched = key.currentState!.validateAndRead()!;
    expect(untouched.ramBytes, 2000000000);
    expect(untouched.trafficBytes, 1500000000000);
    expect(untouched.apiFields, {'ramBytes', 'diskBytes', 'trafficBytes'});
    // Typing the same text again keeps the exact value; a different number is
    // a manual edit and drops the API provenance.
    await fill(tester, 'ramBytes', '1.86');
    expect(key.currentState!.validateAndRead()!.ramBytes, 2000000000);
    await fill(tester, 'ramBytes', '1.87');
    final edited = key.currentState!.validateAndRead()!;
    expect(edited.ramBytes, isNot(2000000000));
    expect(edited.apiFields, {'diskBytes', 'trafficBytes'});
  });

  testWidgets('vCPU stepper has an explicit unknown state and exact entry', (
    tester,
  ) async {
    final key = await mount(tester, observed: {...observed, 'vcpu': null});
    final stepper = find.byKey(const ValueKey('resource-vcpu'));
    expect(
      find.descendant(of: stepper, matching: find.text('—')),
      findsOneWidget,
    );
    expect(key.currentState!.validateAndRead(), isNull);
    await tester.pump();
    expect(find.text('请填写 1–65536 的整数核数'), findsOneWidget);
    await stepVcpu(tester, 1);
    expect(key.currentState!.validateAndRead()!.vcpu, 1);
    await stepVcpu(tester, -1);
    expect(
      find.descendant(of: stepper, matching: find.text('—')),
      findsOneWidget,
    );
    // Tapping the number opens an exact entry sheet; clamping keeps it valid.
    await tester.tap(find.descendant(of: stepper, matching: find.text('—')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('resource-vcpu-entry')),
      '64',
    );
    await tester.tap(find.byKey(const ValueKey('resource-vcpu-done')));
    await tester.pumpAndSettle();
    expect(key.currentState!.validateAndRead()!.vcpu, 64);
    await tester.tap(find.descendant(of: stepper, matching: find.text('64')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('resource-vcpu-unknown')));
    await tester.pumpAndSettle();
    expect(key.currentState!.validateAndRead(), isNull);
    expect(tester.takeException(), isNull);
  });
}
