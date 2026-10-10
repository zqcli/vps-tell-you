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
  apiFields: ServerResources.fieldKeys,
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

  test('old eight-key JSON remains strict with an unknown traffic period', () {
    final legacy = _complete().toJson()..remove('trafficPeriodMonths');
    expect(legacy.length, 8);
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

  test(
    'partial resource data cannot claim API provenance for unknown values',
    () {
      for (final key in ServerResources.fieldKeys) {
        expect(ServerResources(apiFields: {key}).validate(), isNotNull);
      }
      expect(
        ServerResources(
          trafficUnlimited: true,
          apiFields: {'trafficBytes'},
        ).validate(),
        isNull,
      );
      expect(
        ServerResources(vcpu: 0).validate(),
        isNotNull,
        reason: 'unknown is null, never a zero placeholder',
      );
    },
  );

  group('reusable manual hardware editor', () {
    Future<GlobalKey<ServerResourceFieldsState>> mount(
      WidgetTester tester, {
      ServerResources? initial,
      bool importing = false,
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
                importing: importing,
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

    testWidgets('all six unknown fields can save manually but not on import', (
      tester,
    ) async {
      final manual = await mount(tester);
      for (final key in ServerResources.fieldKeys) {
        expect(find.byKey(ValueKey('resource-$key')), findsOneWidget);
      }
      final result = manual.currentState!.validateAndRead()!;
      expect(result.toJson(), ServerResources().toJson());
      final importing = await mount(tester, importing: true);
      expect(importing.currentState!.validateAndRead(), isNull);
      await tester.pump();
      expect(find.text('硬件信息 · 六项必填'), findsOneWidget);
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

    for (final target in [('ip', '192.0.2.40'), ('hostname', 'new.example')]) {
      testWidgets('new manual ${target.$1} becomes the default host', (
        tester,
      ) async {
        await mount(tester);
        for (final field in ServerResources.fieldKeys) {
          expect(find.byKey(ValueKey('resource-$field')), findsOneWidget);
        }
        await fill(tester, 'field-name', 'Manual server');
        await fill(tester, 'resource-${target.$1}', target.$2);
        await fill(tester, 'resource-vcpu', '4');
        await tapSave(tester);
        final saved = (await store.servers()).single;
        expect(saved.host, target.$2);
        expect(saved.resources!.vcpu, 4);
        expect(saved.resources!.ramBytes, isNull);
        expect(saved.resources!.trafficPeriodMonths, 1);
        expect(saved.resources!.apiFields, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }

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
          'apiFields': <String>[],
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

    testWidgets('canceling a legacy hardware edit does not materialize data', (
      tester,
    ) async {
      final record = await seed(host: 'legacy.example');
      await mount(tester, record: record);
      await fill(tester, 'resource-ip', '192.0.2.80');
      await fill(tester, 'resource-trafficBytes', '30');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      final saved = (await store.servers()).single;
      expect(saved.resources, isNull);
      expect(saved.host, 'legacy.example');
      expect(saved.revision, record.revision);
    });

    testWidgets('explicit new host stays separate from hardware IP', (
      tester,
    ) async {
      await mount(tester);
      await fill(tester, 'field-name', 'Manual server');
      await fill(tester, 'field-host', 'gateway.example');
      await fill(tester, 'resource-ip', '192.0.2.40');
      await tapSave(tester);
      final saved = (await store.servers()).single;
      expect(saved.host, 'gateway.example');
      expect(saved.resources!.ip, '192.0.2.40');
    });

    testWidgets(
      'legacy server without resources can be edited with all unknown',
      (tester) async {
        final record = await seed(host: 'legacy.example');
        await mount(tester, record: record);
        await fill(tester, 'field-name', 'Edited legacy');
        await tapSave(tester);
        final saved = (await store.servers()).single;
        expect(saved.name, 'Edited legacy');
        expect(saved.host, 'legacy.example');
        expect(saved.resources!.toJson(), ServerResources().toJson());
        expect(tester.takeException(), isNull);
      },
    );

    for (final host in ['192.0.2.45', 'gateway.example', '']) {
      testWidgets('editing hardware does not overwrite existing host "$host"', (
        tester,
      ) async {
        final record = await seed(host: host, resources: _complete());
        await mount(tester, record: record);
        await fill(tester, 'resource-ip', '192.0.2.99');
        await fill(tester, 'resource-hostname', 'changed.example');
        await tapSave(tester);
        final saved = (await store.servers()).single;
        expect(saved.host, host);
        expect(saved.resources!.ip, '192.0.2.99');
        expect(saved.resources!.hostname, 'changed.example');
        expect(saved.resources!.trafficPeriodMonths, isNull);
      });
    }
  });
}
