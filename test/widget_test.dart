import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/app.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_detail.dart';
import 'package:vps_tell_you/servers/server_form.dart';
import 'package:vps_tell_you/settings/settings_page.dart';

void main() {
  late Directory directory;
  late LedgerStore store;
  late LedgerController controller;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('vps-widget-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.db',
    );
    controller = LedgerController(store);
    await controller.refresh();
  });
  tearDown(() async {
    controller.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String id, String text) async {
    final target = find.byKey(ValueKey('field-$id'));
    await tester.ensureVisible(target);
    await tester.enterText(target, text);
    await tester.pump();
  }

  testWidgets(
    'default empty ledger, add -> persisted detail, edit cancel and back never save',
    (tester) async {
      await mount(tester, HomeShell(controller: controller));
      expect(find.text('你的第一台 VPS，\n从这里开始'), findsOneWidget);
      expect(controller.records, isEmpty);
      await tester.tap(find.byKey(const ValueKey('add-server')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('choose-provider-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('provider-name')),
        'Custom',
      );
      await tester.tap(find.byKey(const ValueKey('provider-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-manual')));
      await tester.pumpAndSettle();
      await fill(tester, 'name', 'My VPS');
      await fill(tester, 'host', '192.0.2.42');
      await tester.tap(find.text('保存服务器'));
      await tester.pumpAndSettle();
      expect(find.text('服务器详情'), findsOneWidget);
      expect((await store.servers()).single.host, '192.0.2.42');
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await fill(tester, 'name', 'Unsaved edit');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect((await store.servers()).single.name, 'My VPS');
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await fill(tester, 'name', 'Unsaved back');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect((await store.servers()).single.name, 'My VPS');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-server')));
      await tester.pumpAndSettle();
      final provider = (await store.providers()).single;
      await tester.tap(find.byKey(ValueKey('choose-provider-${provider.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-manual')));
      await tester.pumpAndSettle();
      await fill(tester, 'name', 'Cancelled new');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect((await store.servers()).length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'committed edit with failed reload shows a retry notice and blocks stale edits until recovery',
    (tester) async {
      controller.dispose();
      final failing = FailingReadController(store);
      controller = failing;
      await store.loadDemo();
      await controller.refresh();
      final original = controller.active.first;
      await mount(tester, HomeShell(controller: controller));
      await tester.tap(find.byKey(ValueKey('server-${original.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await fill(tester, 'name', 'Committed edit');
      failing.fail = true;
      await tester.tap(find.text('保存服务器'));
      await tester.pumpAndSettle();

      final committed = (await store.servers()).singleWhere(
        (s) => s.id == original.id,
      );
      expect(committed.name, 'Committed edit');
      expect(committed.revision, original.revision + 1);
      expect(controller.byId(original.id)!.name, original.name);
      expect(find.text('服务器详情'), findsOneWidget);
      expect(find.text('写入已保存，显示内容暂未更新'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '编辑'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton &&
                    widget.tooltip == (original.favorite ? '取消常用' : '设为常用'),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .enabled,
        isFalse,
      );

      await tester.tap(find.text('重新读取'));
      await tester.pumpAndSettle();
      expect(controller.refreshFailed, isTrue);
      expect(find.text('写入已保存，显示内容暂未更新'), findsOneWidget);
      expect(find.text('读取仍未完成，已保存的改动保留。请稍后重新读取。'), findsOneWidget);
      failing.fail = false;
      await tester.tap(find.text('重新读取'));
      await tester.pumpAndSettle();
      expect(controller.refreshFailed, isFalse);
      expect(find.text('写入已保存，显示内容暂未更新'), findsNothing);
      expect(find.text('Committed edit'), findsOneWidget);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('field-name')))
            .controller!
            .text,
        'Committed edit',
      );
      await fill(tester, 'name', 'Edited after recovery');
      await tester.tap(find.text('保存服务器'));
      await tester.pumpAndSettle();
      final recovered = (await store.servers()).singleWhere(
        (s) => s.id == original.id,
      );
      expect(recovered.name, 'Edited after recovery');
      expect(recovered.revision, committed.revision + 1);
      expect((await store.servers()).length, 4);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'archive confirmation cancel, archive and snackbar undo act on the same record',
    (tester) async {
      await store.loadDemo();
      await controller.refresh();
      final id = controller.active.first.id;
      await mount(tester, HomeShell(controller: controller));
      await tester.tap(find.byKey(ValueKey('server-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('更多操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('归档本地记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(controller.archived, isEmpty);
      await tester.tap(find.byTooltip('更多操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('归档本地记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('归档本地记录'));
      await tester.pumpAndSettle();
      expect(controller.byId(id)!.archived, isTrue);
      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();
      expect(controller.byId(id)!.archived, isFalse);
      expect(controller.active.length, 4);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      '390px layout and ${scale}x text: tabs, list, detail, form and groups stay within bounds',
      (tester) async {
        await store.loadDemo();
        await controller.refresh();
        await mount(tester, HomeShell(controller: controller), scale: scale);
        expect(tester.takeException(), isNull);
        for (var tab = 1; tab < 4; tab++) {
          await tester.tap(find.byKey(ValueKey('tab-$tab')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'tab $tab');
          await tester.drag(find.byType(ListView).first, const Offset(0, -500));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await mount(
          tester,
          ServerDetail(controller: controller, id: controller.active.first.id),
          scale: scale,
        );
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'detail');
        await mount(
          tester,
          ServerForm(controller: controller, record: controller.active.first),
          scale: scale,
        );
        for (var pass = 0; pass < 8; pass++) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -550),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'form scroll $pass');
        }
        await mount(tester, GroupsPage(controller: controller), scale: scale);
        expect(tester.takeException(), isNull, reason: 'groups');
      },
    );
  }

  testWidgets(
    'group dialog cancel is inert, rename keeps stable ID and delete works',
    (tester) async {
      await mount(tester, GroupsPage(controller: controller));
      await tester.tap(find.byTooltip('新增分组'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('group-name')),
        'Cancelled',
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(await store.groups(), isEmpty);
      await tester.tap(find.byTooltip('新增分组'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('group-name')),
        'Production',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final groupId = controller.groups.single.id;
      await tester.tap(find.byTooltip('Production的操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('group-name')),
        'Renamed',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(controller.groups.single.id, groupId);
      await tester.tap(find.byTooltip('Renamed的操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除分组'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除分组'));
      await tester.pumpAndSettle();
      expect(controller.groups, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'database open failure is recoverable, without auto-loading demo or claiming success',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        LedgerApp(
          openStore: () async {
            attempts++;
            throw StateError('unavailable');
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('无法打开本地台账'), findsOneWidget);
      await tester.tap(find.text('重试打开'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(controller.records, isEmpty);
      expect(find.text('无法打开本地台账'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class FailingReadController extends LedgerController {
  FailingReadController(super.store);
  bool fail = false;

  @override
  Future<void> refresh() async {
    if (fail) throw StateError('simulated reload failure');
    await super.refresh();
  }
}
