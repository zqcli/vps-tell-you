import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/servers/server_resource_fields.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

import 'support/form_test_helpers.dart';

void main() {
  Future<GlobalKey<ServerResourceFieldsState>> mount(
    WidgetTester tester, {
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
              child: ServerResourceFields(key: key, initial: initial),
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

  final complete = ServerResources(
    ip: '192.0.2.20',
    hostname: 'Test-VM',
    vcpu: 2,
    ramBytes: 1073741824,
    diskBytes: 21474836480,
    trafficBytes: 1649267441664,
  );

  testWidgets('decimal units are exact; malformed quotas, IPs and hostnames '
      'are rejected', (tester) async {
    final key = await mount(tester, initial: complete, scale: 2);
    await fill(tester, 'diskBytes', '1.5');
    expect(key.currentState!.validateAndRead()!.diskBytes, 1610612736);
    for (final invalid in [
      'NaN',
      '-1',
      '0',
      '1e4',
      '0.000000001',
      '1.234',
      '9007199254740992',
    ]) {
      await fill(tester, 'diskBytes', invalid);
      expect(key.currentState!.validateAndRead(), isNull, reason: invalid);
    }
    // Bytes are whole numbers: a fraction of a byte is never rounded.
    await chooseUnit(tester, 'diskBytes', 'B');
    await fill(tester, 'diskBytes', '1.5');
    expect(key.currentState!.validateAndRead(), isNull);
    await fill(tester, 'diskBytes', '1536');
    expect(key.currentState!.validateAndRead()!.diskBytes, 1536);
    await chooseUnit(tester, 'diskBytes', 'GiB');
    await fill(tester, 'diskBytes', '20');

    for (final invalid in ['0.0.0.0', '256.1.1.1', '1.2.3', '2001:db8::1']) {
      await fill(tester, 'ip', invalid);
      expect(key.currentState!.validateAndRead(), isNull, reason: invalid);
    }
    await fill(tester, 'ip', '192.0.2.20');
    for (final invalid in ['2001:db8:::1', '192.0.2.1', 'fe80::1%eth0']) {
      await fill(tester, 'ipv6', invalid);
      expect(key.currentState!.validateAndRead(), isNull, reason: invalid);
    }
    await fill(tester, 'ipv6', '2001:0DB8:0:0:0:0:0:123');
    await fill(tester, 'hostname', 'https://server.test');
    expect(key.currentState!.validateAndRead(), isNull);
    await fill(tester, 'hostname', 'Valid-Name');
    final result = key.currentState!.validateAndRead()!;
    expect(result.ipv6, '2001:db8::123');
    expect(result.hostname, 'Valid-Name');
    expect(result.diskBytes, 21474836480);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing persisted values preserves exact bytes until edited', (
    tester,
  ) async {
    final initial = ServerResources(
      ip: '192.0.2.2',
      ipv6: '2001:db8::2',
      hostname: 'Saved-VM',
      vcpu: 3,
      ramBytes: 1048577,
      diskBytes: 1073741825,
      trafficBytes: 1099511627777,
      trafficPeriodMonths: 3,
    );
    final key = await mount(tester, initial: initial);
    expect(key.currentState!.validateAndRead()!.toJson(), initial.toJson());
    // Shown as a short number in the best unit, not as raw bytes...
    expect(fieldController(tester, 'resource-ramBytes').text, '1');
    expect(fieldController(tester, 'resource-diskBytes').text, '1');
    expect(fieldController(tester, 'resource-trafficBytes').text, '1');
    // ...while the untouched exact values survive an edit of another field.
    await fill(tester, 'hostname', 'Renamed-VM');
    var updated = key.currentState!.validateAndRead()!;
    expect(updated.hostname, 'Renamed-VM');
    expect(updated.ramBytes, 1048577);
    expect(updated.diskBytes, 1073741825);
    expect(updated.trafficBytes, 1099511627777);
    // Only the edited capacity is converted.
    await chooseUnit(tester, 'diskBytes', 'B');
    await fill(tester, 'diskBytes', '1073741826');
    updated = key.currentState!.validateAndRead()!;
    expect(updated.diskBytes, 1073741826);
    expect(updated.ramBytes, 1048577);
    expect(updated.trafficBytes, 1099511627777);
    expect(updated.trafficPeriodMonths, 3);
  });

  testWidgets(
    'stored sizes open in the best unit with a short rounded number',
    (tester) async {
      // 2 000 000 000 B is "2 GB" decimal: 1.86 GiB, not 2000000000 B.
      final initial = ServerResources(
        ip: '192.0.2.9',
        hostname: 'saved.example',
        vcpu: 2,
        ramBytes: 2000000000,
        diskBytes: 53687091200,
        trafficBytes: 1500000000000,
      );
      final key = await mount(tester, initial: initial);
      expect(fieldController(tester, 'resource-ramBytes').text, '1.86');
      expect(fieldController(tester, 'resource-diskBytes').text, '50');
      expect(fieldController(tester, 'resource-trafficBytes').text, '1.36');
      final untouched = key.currentState!.validateAndRead()!;
      expect(untouched.ramBytes, 2000000000);
      expect(untouched.diskBytes, 53687091200);
      expect(untouched.trafficBytes, 1500000000000);
      // Typing the same text again keeps the exact value; a different number is
      // a real edit and converts.
      await fill(tester, 'ramBytes', '1.86');
      expect(key.currentState!.validateAndRead()!.ramBytes, 2000000000);
      await fill(tester, 'ramBytes', '1.87');
      final edited = key.currentState!.validateAndRead()!;
      expect(edited.ramBytes, isNot(2000000000));
      expect(edited.ramBytes, (1.87 * 1073741824).round());
      expect(edited.trafficBytes, 1500000000000);
    },
  );

  testWidgets('vCPU stepper has an explicit unknown state and exact entry', (
    tester,
  ) async {
    final key = await mount(
      tester,
      initial: ServerResources(
        ip: '192.0.2.20',
        hostname: 'Test-VM',
        ramBytes: 1073741824,
        diskBytes: 21474836480,
        trafficBytes: 1649267441664,
      ),
    );
    final stepper = find.byKey(const ValueKey('resource-vcpu'));
    expect(
      find.descendant(of: stepper, matching: find.text('—')),
      findsOneWidget,
    );
    expect(vcpuText(tester), isEmpty);
    // Unknown is a valid, explicit state: it is stored as null, never as 0.
    expect(key.currentState!.validateAndRead()!.vcpu, isNull);

    Future<void> step(String id) async {
      final button = find.byKey(ValueKey('resource-vcpu-$id'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
    }

    await step('increase');
    expect(key.currentState!.validateAndRead()!.vcpu, 1);
    await step('decrease');
    expect(vcpuText(tester), isEmpty);
    expect(key.currentState!.validateAndRead()!.vcpu, isNull);

    await setVcpu(tester, 64);
    expect(vcpuText(tester), '64');
    expect(key.currentState!.validateAndRead()!.vcpu, 64);
    await setVcpu(tester, 65536);
    expect(key.currentState!.validateAndRead()!.vcpu, 65536);
    await setVcpu(tester, 70000);
    expect(key.currentState!.validateAndRead()!.vcpu, 65536);
    await setVcpu(tester, null);
    expect(vcpuText(tester), isEmpty);
    expect(key.currentState!.validateAndRead()!.vcpu, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unlimited traffic is explicit and clears the quota', (
    tester,
  ) async {
    final key = await mount(
      tester,
      initial: ServerResources(
        ip: '192.0.2.20',
        hostname: 'Test-VM',
        vcpu: 2,
        ramBytes: 1073741824,
        diskBytes: 21474836480,
      ),
    );
    // An empty quota is "unknown", not unlimited.
    var result = key.currentState!.validateAndRead()!;
    expect(result.trafficBytes, isNull);
    expect(result.trafficUnlimited, isFalse);
    final unlimited = find.byKey(const ValueKey('resource-traffic-unlimited'));
    await tester.ensureVisible(unlimited);
    await tester.tap(unlimited);
    await tester.pump();
    result = key.currentState!.validateAndRead()!;
    expect(result.trafficUnlimited, isTrue);
    expect(result.trafficBytes, isNull);
    expect(result.toJson()['trafficUnlimited'], isTrue);
    // Turning it off again returns to an unknown quota that can be filled.
    await tester.tap(unlimited);
    await tester.pump();
    result = key.currentState!.validateAndRead()!;
    expect(result.trafficUnlimited, isFalse);
    expect(result.trafficBytes, isNull);
    await fill(tester, 'trafficBytes', '1.5');
    result = key.currentState!.validateAndRead()!;
    expect(result.trafficUnlimited, isFalse);
    expect(result.trafficBytes, 1610612736);
  });
}
