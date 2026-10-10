import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/connections/snippet.dart';
import 'package:vps_tell_you/connections/snippet_pages.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/data/ledger_store.dart';

void main() {
  late Directory directory;
  late LedgerStore store;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('snippet-widget-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
    );
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester, {
    double scale = 1,
    bool select = false,
    void Function(CommandSnippet?)? onResult,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
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
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final result = await Navigator.push<CommandSnippet>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SnippetListPage(store: store, selectForDraft: select),
                  ),
                );
                onResult?.call(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  // The list row beneath shows the same escaped excerpt; look in the sheet.
  Finder inSheet(String text) =>
      find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text).last;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  // The row's "…" action sheet replaced the inline Edit / Delete buttons.
  Future<void> rowAction(WidgetTester tester, String action) async {
    await tester.tap(find.byTooltip('更多操作').last);
    await tester.pumpAndSettle();
    await tap(tester, action);
  }

  testWidgets(
    'CRUD preserves exact controls; dirty cancel and delete confirmation',
    (tester) async {
      await mount(tester);
      await tap(tester, '新增片段');
      await tester.enterText(find.byKey(const Key('snippet-name')), 'Fixture');
      const content = '  printf test\r\nnext\t\x1b\x00  \n';
      await tester.enterText(find.byKey(const Key('snippet-content')), content);
      await tester.pump();
      // The editor shows the full escaped preview inline.
      expect(find.text(escapedCommandPreview(content)), findsOneWidget);
      expect(await store.snippets(), isEmpty);
      await tap(tester, '保存');
      expect((await store.snippets()).single.content, content);
      await rowAction(tester, '编辑');
      expect(
        tester
            .widget<AppTextField>(find.byKey(const Key('snippet-content')))
            .controller!
            .text,
        content,
      );
      await tester.enterText(
        find.byKey(const Key('snippet-content')),
        'unsaved',
      );
      await tap(tester, '取消');
      await tap(tester, '放弃修改');
      expect((await store.snippets()).single.content, content);
      await rowAction(tester, '编辑');
      await tester.enterText(find.byKey(const Key('snippet-name')), 'Renamed');
      await tap(tester, '保存');
      expect((await store.snippets()).single.revision, 1);
      expect(find.text('Renamed'), findsOneWidget);
      await rowAction(tester, '删除');
      await tap(tester, '取消');
      expect(await store.snippets(), hasLength(1));
      await rowAction(tester, '删除');
      await tap(tester, '删除片段');
      expect(await store.snippets(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'picker preview cancel returns nothing; explicit insert returns original DTO only',
    (tester) async {
      const content = 'first\r\nsecond\x1b\x00';
      await store.saveSnippet(
        const CommandSnippet(id: 'fixture', name: 'Fixture', content: content),
        isNew: true,
      );
      var returned = false;
      CommandSnippet? selection;
      await mount(
        tester,
        select: true,
        onResult: (result) {
          returned = true;
          selection = result;
        },
      );
      await tap(tester, 'Fixture');
      expect(inSheet(escapedCommandPreview(content)), findsOneWidget);
      expect(returned, isFalse);
      await tap(tester, '取消');
      expect(returned, isFalse);
      await tap(tester, 'Fixture');
      await tap(tester, '仅插入待发送草稿');
      expect(returned, isTrue);
      expect(selection!.content, content);
      expect(selection!.id, 'fixture');
      expect((await store.snippets()).single.revision, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '390px double text preview and editor remain scrollable without overflow',
    (tester) async {
      const content = 'a\r\n\x1b[31m\tsecond line\u202e';
      await store.saveSnippet(
        CommandSnippet(id: 'fixture', name: '长名称' * 20, content: content),
        isNew: true,
      );
      await mount(tester, scale: 2, select: true);
      await tap(tester, '长名称' * 20);
      expect(inSheet(escapedCommandPreview(content)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tap(tester, '取消');
      await rowAction(tester, '编辑');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('snippet-escaped-preview')),
        300,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'blank form refuses save and cancelling new draft never creates a row',
    (tester) async {
      await mount(tester);
      await tap(tester, '新增片段');
      await tap(tester, '保存');
      expect(find.text('名称需为 1–80 个字符'), findsOneWidget);
      expect(await store.snippets(), isEmpty);
      await tester.enterText(find.byKey(const Key('snippet-name')), 'Draft');
      await tap(tester, '取消');
      await tap(tester, '放弃修改');
      expect(await store.snippets(), isEmpty);
    },
  );
}
