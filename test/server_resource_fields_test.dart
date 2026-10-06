import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/servers/server_resource_fields.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

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
      await fill(tester, 'vcpu', '4');
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
      await fill(tester, 'vcpu', '0');
      await fill(tester, 'ramBytes', '0');
      await fill(tester, 'trafficBytes', '0');
      expect(key.currentState!.validateAndRead(), isNull);
      await fill(tester, 'vcpu', '2');
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
      await fill(tester, 'diskBytes', '1073741826');
      final updated = key.currentState!.validateAndRead()!;
      expect(updated.diskBytes, 1073741826);
      expect(updated.apiFields, {'ip', 'hostname'});
    },
  );
}
