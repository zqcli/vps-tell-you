import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_form.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resource_fields.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

import 'support/form_test_helpers.dart';

ServerResources _complete() => ServerResources(
  ip: '192.0.2.45',
  hostname: 'fixture.example',
  diskBytes: 21474836480,
  trafficBytes: 1099511627776,
  ramBytes: 1073741824,
  vcpu: 2,
);

void main() {
  test(
    'partial local resources round-trip without inventing unknown values',
    () {
      for (final resources in [
        ServerResources(),
        ServerResources(ip: '192.0.2.1'),
        ServerResources(hostname: 'manual.example', vcpu: 4),
        ServerResources(trafficUnlimited: true, trafficPeriodMonths: 3),
      ]) {
        expect(resources.validate(), isNull);
        expect(resources.validate(requireComplete: true), isNotNull);
        final restored = ServerResources.decode(resources.encode());
        expect(restored.toJson(), resources.toJson());
        expect(restored.ramBytes, isNull);
        expect(restored.diskBytes, isNull);
        expect(restored.specSummary, isNot(contains('null')));
        expect(restored.specSummary, isNot(contains('0 GiB')));
      }
    },
  );

  test('old seven-key JSON remains strict with an unknown traffic period', () {
    final legacy = _complete().toJson()..remove('trafficPeriodMonths');
    expect(legacy.length, 7);
    final restored = ServerResources.decode(jsonEncode(legacy));
    expect(restored.trafficPeriodMonths, isNull);
    expect(restored.trafficPeriodLabel, '未设置');
    expect(restored.trafficSummary, contains('周期未设置'));
    expect(restored.toJson(), _complete().toJson());
    for (final entry in {
      'ip': '',
      'hostname': '',
      'vcpu': null,
      'ramBytes': null,
      'diskBytes': null,
      'trafficBytes': null,
    }.entries) {
      expect(
        () => ServerResources.fromJson({...legacy, entry.key: entry.value}),
        throwsFormatException,
        reason: entry.key,
      );
    }
  });

  test('period is strictly nullable month, quarter or year', () {
    for (final period in [null, 1, 3, 12]) {
      final resources = ServerResources(
        trafficBytes: 1073741824,
        trafficPeriodMonths: period,
      );
      expect(resources.validate(), isNull);
      expect(
        ServerResources.decode(resources.encode()).trafficPeriodMonths,
        period,
      );
      expect(resources.trafficSummary, contains('1 GiB 流量'));
    }
    final json = ServerResources().toJson();
    for (final period in [0, -1, 6, 24, 'month', 1.0, false]) {
      expect(
        () =>
            ServerResources.fromJson({...json, 'trafficPeriodMonths': period}),
        throwsFormatException,
      );
    }
    expect(
      () => ServerResources.fromJson({...json, 'periodMonths': 1}),
      throwsFormatException,
    );
  });

  test('unknown is null, never a zero placeholder', () {
    expect(ServerResources(vcpu: 0).validate(), isNotNull);
    expect(ServerResources(trafficUnlimited: true).validate(), isNull);
  });

  group('reusable manual hardware editor', () {
    Future<GlobalKey<ServerResourceFieldsState>> mount(
      WidgetTester tester, {
      ServerResources? initial,
      int? defaultPeriod,
    }) async {
      final key = GlobalKey<ServerResourceFieldsState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ServerResourceFields(
                key: key,
                initial: initial,
                defaultTrafficPeriodMonths: defaultPeriod,
              ),
            ),
          ),
        ),
      );
      return key;
    }

    Future<void> fill(WidgetTester tester, String key, String value) async {
      if (key == 'vcpu') {
        // vCPU is a stepper; an empty value is its explicit unknown state.
        await setVcpu(tester, value.isEmpty ? null : int.parse(value));
        return;
      }
      final field = find.byKey(ValueKey('resource-$key'));
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
      await tester.pump();
    }

    testWidgets('all six unknown fields can be saved', (tester) async {
      final manual = await mount(tester);
      for (final key in ServerResources.fieldKeys) {
        expect(find.byKey(ValueKey('resource-$key')), findsOneWidget);
      }
      final result = manual.currentState!.validateAndRead()!;
      expect(result.toJson(), ServerResources().toJson());
    });

    testWidgets(
      'clearing API values makes them unknown and removes provenance',
      (tester) async {
        final key = await mount(tester, initial: _complete());
        for (final field in ServerResources.fieldKeys) {
          await fill(tester, field, '');
        }
        final result = key.currentState!.validateAndRead()!;
        expect(result.toJson(), ServerResources().toJson());
      },
    );

    testWidgets('capacity unit and quota period remain independent', (
      tester,
    ) async {
      final key = await mount(tester, defaultPeriod: 1);
      expect(key.currentState!.validateAndRead()!.trafficPeriodMonths, 1);
      await fill(tester, 'trafficBytes', '2');
      final period = find.byKey(const ValueKey('resource-traffic-period'));
      await chooseOption(tester, period, '每季');
      expect(key.currentState!.validateAndRead()!.trafficPeriodMonths, 3);
      expect(key.currentState!.validateAndRead()!.trafficBytes, 2147483648);
      await chooseUnit(tester, 'trafficBytes', 'TiB');
      expect(key.currentState!.validateAndRead()!.trafficPeriodMonths, 3);
      expect(key.currentState!.validateAndRead()!.trafficBytes, 2199023255552);
      await chooseOption(tester, period, '未设置');
      expect(key.currentState!.validateAndRead()!.trafficPeriodMonths, isNull);
      expect(key.currentState!.validateAndRead()!.trafficBytes, 2199023255552);
      expect(tester.takeException(), isNull);
    });

    testWidgets('editing an old unknown period never applies a new default', (
      tester,
    ) async {
      final key = await mount(tester, initial: _complete(), defaultPeriod: 1);
      expect(key.currentState!.validateAndRead()!.trafficPeriodMonths, isNull);
    });

    testWidgets('invalid supplied manual values still block saving', (
      tester,
    ) async {
      final key = await mount(tester);
      await fill(tester, 'ramBytes', '0');
      expect(key.currentState!.validateAndRead(), isNull);
      await fill(tester, 'ramBytes', '');
      await fill(tester, 'ip', '0.0.0.0');
      expect(key.currentState!.validateAndRead(), isNull);
      await fill(tester, 'ip', '');
      await fill(tester, 'hostname', 'https://wrong.example');
      expect(key.currentState!.validateAndRead(), isNull);
      await fill(tester, 'hostname', '');
      // A stepper cannot hold 0; "unknown" is its cleared state and is valid.
      await fill(tester, 'vcpu', '');
      expect(key.currentState!.validateAndRead(), isNotNull);
    });
  });

  group('manual server form persistence', () {
    late Directory directory;
    late LedgerStore store;
    late LedgerController ledger;
    setUp(() async {
      sqfliteFfiInit();
      directory = await Directory.systemTemp.createTemp('hardware-form-');
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

    Future<void> mount(WidgetTester tester, {ServerRecord? record}) async {
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

    Future<void> fill(WidgetTester tester, String key, String value) async {
      if (key == 'resource-vcpu') {
        await setVcpu(tester, value.isEmpty ? null : int.parse(value));
        return;
      }
      final field = find.byKey(ValueKey(key));
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    }

    Future<ServerRecord> seed({
      String host = '',
      ServerResources? resources,
    }) async {
      await store.saveServer(
        ServerRecord(
          id: 'legacy',
          name: 'Existing',
          vendor: 'Fixture',
          host: host,
          resources: resources,
          createdAt: DateTime.utc(2026, 10, 6),
          updatedAt: DateTime.utc(2026, 10, 6),
        ),
        isNew: true,
      );
      await ledger.refresh();
      return ledger.active.single;
    }

    testWidgets('there is no host address field; the three addresses are '
        'independent and optional', (tester) async {
      await mount(tester);
      expect(find.byKey(const ValueKey('field-host')), findsNothing);
      expect(find.text('主机地址'), findsNothing);
      expect(find.text('与主机地址相同'), findsNothing);
      for (final field in [...ServerResources.fieldKeys, 'ipv6']) {
        expect(find.byKey(ValueKey('resource-$field')), findsOneWidget);
      }
      // Nothing but the name is needed.
      await fill(tester, 'field-name', 'No address');
      await tapSave(tester);
      final saved = (await store.servers()).single;
      expect(saved.host, isEmpty);
      expect(saved.resources!.ip, isEmpty);
      expect(saved.resources!.ipv6, isEmpty);
      expect(saved.primaryAddress, isEmpty);
    });

    for (final target in [
      ('ip', '192.0.2.40'),
      ('ipv6', '2001:0DB8::0008'),
      ('hostname', 'new.example'),
    ]) {
      testWidgets('a new ${target.$1} is stored on its own, host stays empty', (
        tester,
      ) async {
        await mount(tester);
        await fill(tester, 'field-name', 'Manual server');
        await fill(tester, 'resource-${target.$1}', target.$2);
        // Typing one family never touches the others (no mirroring).
        for (final other in ['ip', 'ipv6', 'hostname']) {
          if (other != target.$1) {
            expect(fieldController(tester, 'resource-$other').text, isEmpty);
          }
        }
        await fill(tester, 'resource-vcpu', '4');
        await tapSave(tester);
        final saved = (await store.servers()).single;
        expect(saved.host, isEmpty);
        final json = saved.resources!.toJson();
        expect(
          json[target.$1 == 'ip' ? 'ip' : target.$1],
          target.$1 == 'ipv6' ? '2001:db8::8' : target.$2,
          reason: 'IPv6 is stored in its canonical spelling',
        );
        expect(saved.resources!.vcpu, 4);
        expect(saved.resources!.ramBytes, isNull);
        expect(saved.resources!.trafficPeriodMonths, 1);
        expect(saved.primaryAddress, json[target.$1]);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('IPv4, IPv6 and hostname can all be set together', (
      tester,
    ) async {
      await mount(tester);
      await fill(tester, 'field-name', 'dual stack');
      await fill(tester, 'resource-hostname', 'Gateway.Example');
      await fill(tester, 'resource-ip', '192.0.2.8');
      await fill(tester, 'resource-ipv6', '2001:0DB8::0008');
      await tapSave(tester);
      final saved = (await store.servers()).single;
      expect(saved.host, isEmpty);
      expect(saved.resources!.ip, '192.0.2.8');
      expect(saved.resources!.ipv6, '2001:db8::8');
      expect(saved.resources!.hostname, 'Gateway.Example');
      expect(saved.primaryAddress, '192.0.2.8', reason: 'IPv4 wins');
    });

    testWidgets(
      'all six fields and a selected year survive closing the store',
      (tester) async {
        await mount(tester);
        await fill(tester, 'field-name', 'Full hardware');
        for (final entry in {
          'ip': '192.0.2.50',
          'hostname': 'full.example',
          'diskBytes': '30',
          'trafficBytes': '1024',
          'ramBytes': '1536',
          'vcpu': '3',
        }.entries) {
          await fill(tester, 'resource-${entry.key}', entry.value);
        }
        final period = find.byKey(const ValueKey('resource-traffic-period'));
        await chooseOption(tester, period, '每年');
        await fill(tester, 'field-notes', 'Only local hardware');
        await tapSave(tester);
        final first = (await store.servers()).single;
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          ledger.dispose();
          await store.close();
          store = await LedgerStore.open(
            factory: databaseFactoryFfiNoIsolate,
            path: '${directory.path}/ledger.sqlite3',
          );
          ledger = LedgerController(store);
          await ledger.refresh();
        });
        final reopened = ledger.active.single;
        expect(reopened.id, first.id);
        expect(reopened.resources!.toJson(), {
          'ip': '192.0.2.50',
          'hostname': 'full.example',
          'diskBytes': 32212254720,
          'trafficBytes': 1099511627776,
          'ramBytes': 1610612736,
          'vcpu': 3,
          'trafficUnlimited': false,
          'trafficPeriodMonths': 12,
        });
        await mount(tester, record: reopened);
        final fields = tester.state<ServerResourceFieldsState>(
          find.byType(ServerResourceFields),
        );
        expect(
          fields.validateAndRead()!.toJson(),
          reopened.resources!.toJson(),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('manual creation can retain every hardware field as unknown', (
      tester,
    ) async {
      await mount(tester);
      await fill(tester, 'field-name', 'Unknown hardware');
      await tapSave(tester);
      final saved = (await store.servers()).single;
      expect(saved.host, isEmpty);
      expect(
        saved.resources!.toJson(),
        ServerResources(trafficPeriodMonths: 1).toJson(),
      );
    });

    testWidgets('canceling a legacy edit changes nothing, not even host', (
      tester,
    ) async {
      final record = await seed(host: 'legacy.example');
      await mount(tester, record: record);
      // The legacy value is prefilled for review ...
      expect(
        fieldController(tester, 'resource-hostname').text,
        'legacy.example',
      );
      await fill(tester, 'resource-ip', '192.0.2.80');
      await fill(tester, 'resource-trafficBytes', '30');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      // ... but only saving moves it.
      final saved = (await store.servers()).single;
      expect(saved.resources, isNull);
      expect(saved.host, 'legacy.example');
      expect(saved.revision, record.revision);
    });

    group('legacy host carry-over', () {
      for (final legacy in [
        ('IPv4', '192.0.2.45', 'ip', '192.0.2.45'),
        ('IPv6', '2001:DB8:0:0:0:0:0:1', 'ipv6', '2001:db8::1'),
        ('domain', 'legacy.example', 'hostname', 'legacy.example'),
      ]) {
        testWidgets('${legacy.$1} moves into the ${legacy.$3} field on save', (
          tester,
        ) async {
          final record = await seed(host: legacy.$2);
          await mount(tester, record: record);
          // Prefilled, canonical, and the other two stay empty.
          expect(
            fieldController(tester, 'resource-${legacy.$3}').text,
            legacy.$4,
          );
          for (final other in ['ip', 'ipv6', 'hostname']) {
            if (other != legacy.$3) {
              expect(fieldController(tester, 'resource-$other').text, isEmpty);
            }
          }
          await fill(tester, 'field-name', 'Edited legacy');
          await tapSave(tester);
          final saved = (await store.servers()).single;
          expect(saved.name, 'Edited legacy');
          expect(saved.host, isEmpty, reason: 'carried over, not duplicated');
          expect(saved.resources!.toJson()[legacy.$3], legacy.$4);
          expect(saved.primaryAddress, legacy.$4);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('already stored in the same field: host is just cleared', (
        tester,
      ) async {
        final record = await seed(host: '192.0.2.45', resources: _complete());
        await mount(tester, record: record);
        expect(find.byKey(const ValueKey('resource-ip')), findsOneWidget);
        await fill(tester, 'resource-hostname', 'changed.example');
        await tapSave(tester);
        final saved = (await store.servers()).single;
        expect(saved.host, isEmpty);
        expect(saved.resources!.ip, '192.0.2.45');
        expect(saved.resources!.hostname, 'changed.example');
        expect(saved.resources!.trafficPeriodMonths, isNull);
      });

      for (final conflict in [
        ('IPv4', '192.0.2.99', 'resource-ip', '192.0.2.45'),
        ('domain', 'gateway.example', 'resource-hostname', 'fixture.example'),
      ]) {
        testWidgets('${conflict.$1} with a different value in its field stays '
            'in host', (tester) async {
          final record = await seed(host: conflict.$2, resources: _complete());
          await mount(tester, record: record);
          // The user's own value is shown and kept; nothing is overwritten.
          expect(fieldController(tester, conflict.$3).text, conflict.$4);
          await fill(tester, 'field-name', 'Conflict');
          await tapSave(tester);
          final saved = (await store.servers()).single;
          expect(saved.host, conflict.$2);
          expect(saved.resources!.ip, '192.0.2.45');
          expect(saved.resources!.hostname, 'fixture.example');
        });
      }

      testWidgets('a zoned link-local address fits no field and stays', (
        tester,
      ) async {
        final record = await seed(host: 'fe80::1%en0');
        await mount(tester, record: record);
        expect(fieldController(tester, 'resource-ipv6').text, isEmpty);
        await fill(tester, 'field-name', 'lan box');
        await tapSave(tester);
        final saved = (await store.servers()).single;
        expect(saved.host, 'fe80::1%en0');
        expect(saved.resources!.ipv6, isEmpty);
      });

      testWidgets('blanking the prefilled field keeps host (no data loss)', (
        tester,
      ) async {
        final record = await seed(host: 'legacy.example');
        await mount(tester, record: record);
        await fill(tester, 'resource-hostname', '');
        await tapSave(tester);
        final saved = (await store.servers()).single;
        expect(saved.host, 'legacy.example');
        expect(saved.resources!.hostname, isEmpty);
      });

      testWidgets('changing the prefilled value replaces it deliberately', (
        tester,
      ) async {
        final record = await seed(host: '192.0.2.45');
        await mount(tester, record: record);
        await fill(tester, 'resource-ip', '192.0.2.99');
        await tapSave(tester);
        final saved = (await store.servers()).single;
        expect(saved.host, isEmpty);
        expect(saved.resources!.ip, '192.0.2.99');
      });

      testWidgets('a server without any host or resources opens empty', (
        tester,
      ) async {
        final record = await seed();
        await mount(tester, record: record);
        for (final field in ['ip', 'ipv6', 'hostname']) {
          expect(fieldController(tester, 'resource-$field').text, isEmpty);
        }
        await fill(tester, 'field-name', 'Still nothing');
        await tapSave(tester);
        final saved = (await store.servers()).single;
        expect(saved.host, isEmpty);
        expect(saved.resources!.toJson(), ServerResources().toJson());
      });
    });

    testWidgets('address validation: IPv4, IPv6 and hostname are checked', (
      tester,
    ) async {
      await mount(tester);
      await fill(tester, 'field-name', 'validation');
      for (final bad in [
        ('resource-ip', '1.2.3'),
        ('resource-ip', '0.0.0.0'),
        ('resource-ip', '2001:db8::1'),
        ('resource-ipv6', '2001:db8::1::2'),
        ('resource-ipv6', '[2001:db8::1]:22'),
        ('resource-ipv6', '192.0.2.1'),
        ('resource-hostname', 'a b'),
        ('resource-hostname', 'https://wrong.example'),
      ]) {
        await fill(tester, bad.$1, bad.$2);
        await tapSave(tester);
        expect(await store.servers(), isEmpty, reason: '${bad.$1} ${bad.$2}');
        await fill(tester, bad.$1, '');
      }
      await fill(tester, 'resource-ipv6', '2001:db8::2');
      await tapSave(tester);
      expect((await store.servers()).single.resources!.ipv6, '2001:db8::2');
    });
  });
}
