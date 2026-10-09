import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/hardware_information_card.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_detail.dart';
import 'package:vps_tell_you/servers/server_form.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

void main() {
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('hardware-detail-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
    );
    ledger = LedgerController(store);
    await store.saveServer(
      ServerRecord(
        id: 'hardware-detail',
        name: 'Synthetic VPS',
        vendor: 'Synthetic vendor',
        createdAt: DateTime.utc(2026, 10, 6),
        updatedAt: DateTime.utc(2026, 10, 6),
      ),
      isNew: true,
    );
    await ledger.refresh();
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  test('precise hardware capacities never round off stored bytes', () {
    expect(ServerResources.formatBytes(1073741824, exact: true), '1 GiB');
    expect(
      ServerResources.formatBytes(1073741825, exact: true),
      '1073741825 B',
    );
    expect(
      ServerResources.formatBytes(9007199254740991, exact: true),
      '9007199254740991 B',
    );
  });

  testWidgets(
    'legacy detail exposes hardware editing directly at the correct section',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: ServerDetail(controller: ledger, id: 'hardware-detail'),
        ),
      );
      await tester.pumpAndSettle();
      final edit = find.text('编辑硬件');
      await tester.scrollUntilVisible(
        edit,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.byType(ServerForm), findsOneWidget);
      final ip = find.byKey(const ValueKey('resource-ip'));
      expect(tester.getRect(ip).top, greaterThan(0));
      expect(tester.getRect(ip).bottom, lessThan(844));
      expect(
        find.descendant(
          of: find.byType(ServerForm),
          matching: find.text('硬件信息'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(ServerForm), findsNothing);
      expect((await store.servers()).single.resources, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hardware card shows exact quota, independent period and unknowns',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final evidence = Platform.environment['VPS_UI_EVIDENCE_DIR'];
      if (evidence != null) {
        await tester.runAsync(() async {
          final font = FontLoader('QA Noto');
          font.addFont(
            File('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc')
                .readAsBytes()
                .then((bytes) => ByteData.sublistView(bytes)),
          );
          await font.load();
        });
      }
      final theme = appTheme();
      await tester.pumpWidget(
        MaterialApp(
          theme: evidence == null
              ? theme
              : theme.copyWith(
                  textTheme: theme.textTheme.apply(fontFamily: 'QA Noto'),
                  appBarTheme: theme.appBarTheme.copyWith(
                    titleTextStyle: const TextStyle(
                      fontFamily: 'QA Noto',
                      fontSize: 20,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
          home: RepaintBoundary(
            key: const ValueKey('hardware-evidence'),
            child: Scaffold(
              appBar: AppBar(title: const Text('硬件信息 · 合成验收')),
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  HardwareInformationCard(
                    ServerResources(
                      ip: '192.0.2.45',
                      hostname: 'synthetic.example',
                      diskBytes: 21474836480,
                      trafficBytes: 1099511627776,
                      trafficPeriodMonths: 3,
                      ramBytes: 1073741824,
                      vcpu: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 TiB / 季'), findsOneWidget);
      expect(find.textContaining('API 观测'), findsNothing);
      if (evidence != null) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('hardware-evidence')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(evidence).create(recursive: true);
          await File('$evidence/hardware-quarter.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: HardwareInformationCard(null))),
      );
      expect(find.text('未填写'), findsNWidgets(5));
      expect(find.text('未填写 / 周期未设置'), findsOneWidget);
    },
  );
}
