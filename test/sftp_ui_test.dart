import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/connections/sftp_editor_page.dart';
import 'package:vps_tell_you/connections/sftp_pages.dart';
import 'package:vps_tell_you/connections/sftp_session.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/background_grace.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';

import 'support/fake_sftp_session.dart';

Future<void> _settle(WidgetTester tester) async {
  // Spinners (busy overlay, progress) never settle, and real file IO needs
  // real time next to the fake clock.
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  late Directory work;
  late FakeSftpSession fake;
  late FakeLocalFiles local;

  setUp(() async {
    work = await Directory.systemTemp.createTemp('sftp-ui-');
    fake = FakeSftpSession()
      ..dir('/etc')
      ..dir('/home')
      ..dir('/home/user')
      ..file('/home/user/notes.txt', 'hello\nworld')
      ..file('/home/user/.profile', 'export A=1')
      ..binary('/home/user/blob.bin', [0, 1, 2, 3])
      ..big('/home/user/huge.iso', 200 * 1024 * 1024)
      ..big('/home/user/log.txt', 600 * 1024)
      ..link('/home/user/shortcut')
      ..file('/etc/hosts', '127.0.0.1 localhost')
      ..file('/readme', 'top');
    fake.homePath = '/home/user';
    local = FakeLocalFiles(work);
  });

  tearDown(() async {
    await work.delete(recursive: true);
  });

  /// Opens the browser from a launcher page so that closing pops back to it.
  Future<void> open(
    WidgetTester tester, {
    String locale = 'zh',
    double scale = 1,
    Size size = const Size(390, 844),
    bool sheet = false,
    FakeSftpSession? session,
    String? initialPath,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => SftpBrowserPage(
                    session: session ?? fake,
                    sheet: sheet,
                    localFiles: local,
                    initialPath: initialPath,
                  ),
                ),
              ),
              child: const Text('launcher'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('launcher'));
    await tester.pumpAndSettle();
  }

  Finder entry(String name) => find.byKey(ValueKey('sftp-entry-$name'));

  /// Pause, stay away for [stay] (fake time), come back. Since 0.6.0 the
  /// session is kept for a grace period, so the length of the stay matters.
  Future<void> background(
    WidgetTester tester, {
    Duration stay = Duration.zero,
  }) async {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(stay);
    // Frames only run again once the app is back.
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  /// For buttons that show a spinner while their work (or a dialog) is open.
  Future<void> tapBusy(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await _settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String value) async {
    await tester.enterText(find.byKey(ValueKey(key)), value);
    await tester.pump();
  }

  group('browse', () {
    testWidgets('starts at home with folders first, details and breadcrumb', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('user'), findsWidgets); // title and breadcrumb
      expect(fake.calls, containsAllInOrder(['home:.', 'list:/home/user']));
      // Hidden file is not shown by default; folders first, then name.
      expect(entry('.profile'), findsNothing);
      final names = tester
          .widgetList<Widget>(
            find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key as ValueKey<String>).value.startsWith('sftp-entry-'),
            ),
          )
          .map((w) => (w.key as ValueKey<String>).value.substring(11))
          .toList();
      expect(names, [
        'blob.bin',
        'huge.iso',
        'log.txt',
        'notes.txt',
        'shortcut',
      ]);
      expect(find.textContaining('11 B ·'), findsOneWidget); // notes.txt size
      expect(find.textContaining('200.0 MB'), findsOneWidget);
      expect(find.textContaining('2026-10-11'), findsWidgets);
      expect(find.textContaining('rw-r--r--'), findsWidgets);
      // Breadcrumb: root > home > user, tappable except the last.
      expect(find.byKey(const ValueKey('sftp-crumb-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('sftp-crumb-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('sftp-up')), findsOneWidget);
    });

    testWidgets('folders open, up row and breadcrumb navigate', (tester) async {
      await open(tester, initialPath: '/');
      expect(find.byKey(const ValueKey('sftp-up')), findsNothing);
      expect(find.text('根目录'), findsOneWidget);
      await tester.tap(entry('home'));
      await tester.pumpAndSettle();
      await tester.tap(entry('user'));
      await tester.pumpAndSettle();
      expect(entry('notes.txt'), findsOneWidget);
      await tapKey(tester, 'sftp-up');
      expect(entry('user'), findsOneWidget);
      expect(entry('notes.txt'), findsNothing);
      await tapKey(tester, 'sftp-crumb-0');
      expect(entry('etc'), findsOneWidget);
      expect(fake.calls.where((c) => c == 'list:/').length, 2);
    });

    testWidgets('a failing folder keeps the current one and reports why', (
      tester,
    ) async {
      await open(tester, initialPath: '/');
      fake.failNext['list'] = SftpErrorKind.permissionDenied;
      await tester.tap(entry('etc'));
      await tester.pumpAndSettle();
      expect(find.text('没有权限'), findsOneWidget);
      expect(entry('etc'), findsOneWidget);
    });

    testWidgets('search, hidden files and sort', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(EditableText).first, 'NOTE');
      await tester.pumpAndSettle();
      expect(entry('notes.txt'), findsOneWidget);
      expect(entry('blob.bin'), findsNothing);
      await tester.enterText(find.byType(EditableText).first, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('没有匹配项'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).first, '');
      await tester.pumpAndSettle();

      await tapKey(tester, 'sftp-more');
      await tapKey(tester, 'sftp-hidden');
      await tapKey(tester, 'sftp-sort-size');
      await tester.tap(find.byKey(const ValueKey('app-sheet-close')));
      await tester.pumpAndSettle();
      expect(entry('.profile'), findsOneWidget);
      double top(String name) => tester.getTopLeft(entry(name)).dy;
      // Size, largest first: huge.iso, log.txt, notes.txt, .profile, blob.bin.
      expect(top('huge.iso'), lessThan(top('log.txt')));
      expect(top('log.txt'), lessThan(top('notes.txt')));
      expect(top('notes.txt'), lessThan(top('.profile')));
      expect(top('.profile'), lessThan(top('blob.bin')));
    });

    testWidgets('pull to refresh reloads the folder', (tester) async {
      await open(tester);
      fake.file('/home/user/new.txt', 'n');
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(entry('new.txt'), findsOneWidget);
    });

    testWidgets('a long folder is paged', (tester) async {
      for (var i = 0; i < 230; i++) {
        fake.file('/many/f${i.toString().padLeft(3, '0')}', '');
      }
      fake.dir('/many');
      await open(tester, initialPath: '/many');
      expect(find.byKey(const ValueKey('sftp-more-rows')), findsOneWidget);
      expect(find.text('显示更多（30）'), findsOneWidget);
    });

    testWidgets('an empty folder and a failed first load', (tester) async {
      fake.dir('/empty');
      await open(tester, initialPath: '/empty');
      expect(find.text('此文件夹为空'), findsOneWidget);
    });

    testWidgets('first load failure offers retry', (tester) async {
      fake.failNext['list'] = SftpErrorKind.notFound;
      await open(tester);
      expect(find.text('无法加载此文件夹'), findsOneWidget);
      expect(find.text('未找到，可能已被移动或删除'), findsOneWidget);
      await tapKey(tester, 'sftp-retry');
      expect(entry('notes.txt'), findsOneWidget);
    });

    testWidgets('connection loss shows an ended state', (tester) async {
      await open(tester);
      fake.alive = false;
      await tester.tap(entry('notes.txt'));
      await tester.pumpAndSettle();
      await tapText(tester, '删除');
      await tapText(tester, '删除');
      expect(find.text('SFTP 连接已断开'), findsOneWidget);
      expect(find.byKey(const ValueKey('sftp-add')), findsNothing);
      await tapKey(tester, 'sftp-ended-close');
      expect(find.text('launcher'), findsOneWidget);
      expect(fake.closed, isTrue);
    });
  });

  group('mutations', () {
    testWidgets('new folder and new file validate names and create', (
      tester,
    ) async {
      await open(tester);
      await tapKey(tester, 'sftp-add');
      await tapKey(tester, 'sftp-new-folder');
      await enter(tester, 'sftp-name-field', 'a/b');
      await tapKey(tester, 'sftp-name-submit');
      expect(find.text('名称不能为空或包含“/”'), findsOneWidget);
      expect(fake.exists('/home/user/a/b'), isFalse);
      await enter(tester, 'sftp-name-field', 'projects');
      await tapKey(tester, 'sftp-name-submit');
      expect(fake.exists('/home/user/projects'), isTrue);
      expect(entry('projects'), findsOneWidget);

      await tapKey(tester, 'sftp-add');
      await tapKey(tester, 'sftp-new-file');
      await enter(tester, 'sftp-name-field', 'todo.txt');
      await tapKey(tester, 'sftp-name-submit');
      expect(fake.text('/home/user/todo.txt'), '');
      expect(entry('todo.txt'), findsOneWidget);

      // Existing names are reported, not replaced.
      await tapKey(tester, 'sftp-add');
      await tapKey(tester, 'sftp-new-file');
      await enter(tester, 'sftp-name-field', 'notes.txt');
      await tapKey(tester, 'sftp-name-submit');
      expect(find.text('已存在同名项目'), findsOneWidget);
      expect(fake.text('/home/user/notes.txt'), 'hello\nworld');
    });

    testWidgets('rename and move from the action sheet', (tester) async {
      await open(tester);
      await tester.tap(entry('notes.txt'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sftp-action-rename');
      expect(find.text('重命名或移动'), findsOneWidget);
      await enter(tester, 'sftp-name-field', 'journal.txt');
      await tapKey(tester, 'sftp-name-submit');
      expect(fake.exists('/home/user/journal.txt'), isTrue);
      expect(fake.exists('/home/user/notes.txt'), isFalse);

      await tester.tap(entry('journal.txt'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sftp-action-rename');
      await enter(tester, 'sftp-folder-field', 'relative');
      await tapKey(tester, 'sftp-name-submit');
      expect(find.text('文件夹须为以 / 开头的绝对路径'), findsOneWidget);
      await enter(tester, 'sftp-folder-field', '/etc');
      await tapKey(tester, 'sftp-name-submit');
      expect(fake.exists('/etc/journal.txt'), isTrue);
      expect(entry('journal.txt'), findsNothing);

      // Clobbering is refused with the typed message.
      await tester.tap(entry('blob.bin'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sftp-action-rename');
      await enter(tester, 'sftp-name-field', 'log.txt');
      await tapKey(tester, 'sftp-name-submit');
      expect(find.text('已存在同名项目'), findsOneWidget);
      expect(fake.exists('/home/user/blob.bin'), isTrue);
    });

    testWidgets('copy path puts the full path on the clipboard', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await open(tester);
      await tester.tap(entry('notes.txt'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sftp-action-copy');
      expect(copied, '/home/user/notes.txt');
      expect(find.text('已复制路径'), findsOneWidget);
    });

    testWidgets('delete file asks first, then deletes', (tester) async {
      await open(tester);
      await tester.longPress(entry('notes.txt'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sftp-action-delete');
      expect(find.text('删除“notes.txt”？'), findsOneWidget);
      expect(find.text('将在服务器上永久删除该文件。'), findsOneWidget);
      await tapText(tester, '取消');
      expect(fake.exists('/home/user/notes.txt'), isTrue);
      await tester.longPress(entry('notes.txt'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sftp-action-delete');
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();
      expect(fake.exists('/home/user/notes.txt'), isFalse);
      expect(entry('notes.txt'), findsNothing);
    });

    testWidgets('deleting a link removes the link only', (tester) async {
      await open(tester);
      await tester.longPress(entry('shortcut'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sftp-action-delete');
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();
      expect(fake.calls, contains('deleteFile:/home/user/shortcut'));
      expect(fake.exists('/home/user/shortcut'), isFalse);
    });

    testWidgets('empty folders go with one confirmation', (tester) async {
      fake.dir('/home/user/empty');
      await open(tester);
      await tester.longPress(entry('empty'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sftp-action-delete');
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();
      expect(fake.exists('/home/user/empty'), isFalse);
      expect(fake.calls.where((c) => c.startsWith('deleteRecursive')), isEmpty);
    });

    testWidgets('non-empty folder needs a second, recursive confirmation', (
      tester,
    ) async {
      fake
        ..dir('/home/user/proj')
        ..dir('/home/user/proj/src')
        ..file('/home/user/proj/src/a.dart', 'a')
        ..file('/home/user/proj/b.md', 'b');
      await open(tester);
      await tester.longPress(entry('proj'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sftp-action-delete');
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();
      expect(find.text('删除文件夹及其全部内容？'), findsOneWidget);
      expect(find.textContaining('递归删除'), findsOneWidget);
      expect(find.textContaining('2000'), findsOneWidget);
      // Backing out leaves everything.
      await tapText(tester, '取消');
      expect(fake.exists('/home/user/proj/src/a.dart'), isTrue);
      expect(fake.calls.where((c) => c.startsWith('deleteRecursive')), isEmpty);

      await tester.longPress(entry('proj'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sftp-action-delete');
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();
      await tapText(tester, '全部删除');
      expect(fake.exists('/home/user/proj'), isFalse);
      expect(fake.exists('/home/user/proj/src/a.dart'), isFalse);
      expect(find.text('已删除 4 项'), findsOneWidget);
      expect(entry('proj'), findsNothing);
    });

    testWidgets(
      'recursive delete over the limit reports it and deletes nothing',
      (tester) async {
        fake.dir('/home/user/huge');
        for (var i = 0; i < 2100; i++) {
          fake.file('/home/user/huge/f$i', '');
        }
        await open(tester);
        await tester.longPress(entry('huge'));
        await tester.pumpAndSettle();
        await tapKey(tester, 'sftp-action-delete');
        await tester.tap(find.text('删除').last);
        await tester.pumpAndSettle();
        await tapText(tester, '全部删除');
        expect(find.text('项目过多（上限 2000），未删除任何内容'), findsOneWidget);
        expect(fake.exists('/home/user/huge/f0'), isTrue);
      },
    );

    testWidgets('swipe reveals rename and delete', (tester) async {
      await open(tester);
      await tester.drag(entry('notes.txt'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('sftp-swipe-rename-notes.txt')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('sftp-swipe-delete-notes.txt')),
      );
      await tester.pumpAndSettle();
      expect(find.text('删除“notes.txt”？'), findsOneWidget);
      await tapText(tester, '取消');
      await tester.drag(entry('notes.txt'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('sftp-swipe-rename-notes.txt')),
      );
      await tester.pumpAndSettle();
      expect(find.text('重命名或移动'), findsOneWidget);
    });

    testWidgets('typed errors become short messages in both languages', (
      tester,
    ) async {
      const zh = {
        SftpErrorKind.permissionDenied: '没有权限',
        SftpErrorKind.timeout: '服务器响应超时',
        SftpErrorKind.failed: '操作失败',
        SftpErrorKind.exists: '已存在同名项目',
        SftpErrorKind.localFile: '无法读写本地文件',
      };
      await open(tester);
      for (final item in zh.entries) {
        fake.failNext['mkdir'] = item.key;
        await tapKey(tester, 'sftp-add');
        await tapKey(tester, 'sftp-new-folder');
        await enter(tester, 'sftp-name-field', 'x');
        await tapKey(tester, 'sftp-name-submit');
        expect(find.text(item.value), findsOneWidget, reason: '${item.key}');
        await tester.pump(const Duration(seconds: 6));
      }
    });

    testWidgets('English messages', (tester) async {
      await open(tester, locale: 'en');
      fake.failNext['mkdir'] = SftpErrorKind.permissionDenied;
      await tapKey(tester, 'sftp-add');
      await tapKey(tester, 'sftp-new-folder');
      await enter(tester, 'sftp-name-field', 'x');
      await tapKey(tester, 'sftp-name-submit');
      expect(find.text('Permission denied'), findsOneWidget);
    });
  });

  group('editor', () {
    testWidgets('edit, save, and the list refreshes', (tester) async {
      await open(tester);
      await tester.tap(entry('notes.txt'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sftp-action-edit');
      final field = find.byKey(const ValueKey('sftp-editor-field'));
      expect(tester.widget<TextField>(field).controller!.text, 'hello\nworld');
      await tester.enterText(field, 'hello\nmoon');
      await tester.pump();
      await tapKey(tester, 'sftp-editor-save');
      expect(fake.text('/home/user/notes.txt'), 'hello\nmoon');
      expect(find.text('已保存'), findsOneWidget);
      await tapKey(tester, 'sftp-editor-close'); // clean: closes without asking
      expect(find.byKey(const ValueKey('sftp-editor-field')), findsNothing);
      expect(entry('notes.txt'), findsOneWidget);
    });

    testWidgets('a changed server copy asks before overwriting', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(entry('notes.txt'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sftp-action-edit');
      fake.touch('/home/user/notes.txt', 'someone else');
      await tester.enterText(
        find.byKey(const ValueKey('sftp-editor-field')),
        'mine',
      );
      await tester.pump();
      await tapBusy(tester, 'sftp-editor-save');
      expect(find.text('服务器上的文件已变化'), findsOneWidget);
      await tapText(tester, '取消');
      expect(fake.text('/home/user/notes.txt'), 'someone else');
      await tapBusy(tester, 'sftp-editor-save');
      await tapText(tester, '覆盖');
      expect(fake.text('/home/user/notes.txt'), 'mine');
      // The baseline moved on: a second save does not ask again.
      await tester.enterText(
        find.byKey(const ValueKey('sftp-editor-field')),
        'mine2',
      );
      await tester.pump();
      await tapBusy(tester, 'sftp-editor-save');
      expect(find.text('服务器上的文件已变化'), findsNothing);
      expect(fake.text('/home/user/notes.txt'), 'mine2');
    });

    testWidgets('closing with unsaved edits asks', (tester) async {
      await open(tester);
      await tester.tap(entry('notes.txt'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sftp-action-edit');
      await tester.enterText(
        find.byKey(const ValueKey('sftp-editor-field')),
        'edited',
      );
      await tester.pump();
      await tapKey(tester, 'sftp-editor-close');
      expect(find.text('放弃未保存的修改？'), findsOneWidget);
      await tapText(tester, '取消');
      expect(find.byKey(const ValueKey('sftp-editor-field')), findsOneWidget);
      await tapKey(tester, 'sftp-editor-close');
      await tapText(tester, '放弃');
      expect(find.byKey(const ValueKey('sftp-editor-field')), findsNothing);
      expect(fake.text('/home/user/notes.txt'), 'hello\nworld');
    });

    /// Pumps the editor page on its own with [text] as the file content.
    Future<void> openEditor(
      WidgetTester tester,
      String text, {
      String locale = 'zh',
      double scale = 1,
      Size size = const Size(390, 844),
      String name = 'a.txt',
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      fake.file('/home/user/$name', text);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          locale: Locale(locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: SftpTextEditorPage(
            session: fake,
            path: '/home/user/$name',
            name: name,
            file: SftpTextFile(text: text, size: text.length),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final fieldFinder = find.byKey(const ValueKey('sftp-editor-field'));
    TextField fieldWidget(WidgetTester tester) =>
        tester.widget<TextField>(fieldFinder);
    ScrollPosition position(WidgetTester tester) =>
        fieldWidget(tester).scrollController!.position;
    SftpGutterPainter gutter(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byKey(const ValueKey('sftp-editor-gutter')),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as SftpGutterPainter;

    /// Global top of the text field's line [line] / gutter row [line].
    double textTop(WidgetTester tester, String text, int line) {
      final render = tester
          .state<EditableTextState>(find.byType(EditableText))
          .renderEditable;
      var offset = 0;
      for (var i = 0; i < line; i++) {
        offset = text.indexOf('\n', offset) + 1;
      }
      final rect = render.getLocalRectForCaret(TextPosition(offset: offset));
      return render.localToGlobal(Offset(0, rect.top)).dy;
    }

    double gutterTop(WidgetTester tester, int line) {
      final box = tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byKey(const ValueKey('sftp-editor-gutter')),
          matching: find.byType(CustomPaint),
        ),
      );
      return box.localToGlobal(Offset(0, gutter(tester).paintedRows[line]!)).dy;
    }

    String lines(int n) => List.generate(n, (i) => 'line ${i + 1}').join('\n');

    testWidgets('the gutter numbers every line and follows the scroll', (
      tester,
    ) async {
      final text = lines(120);
      await openEditor(tester, text);
      expect(gutter(tester).lines, 120);
      expect(gutter(tester).paintedRows.keys.first, 0);
      expect(gutter(tester).paintedRows.keys, isNot(contains(119)));
      for (final line in gutter(tester).paintedRows.keys) {
        expect(
          gutterTop(tester, line),
          closeTo(textTop(tester, text, line), .5),
          reason: 'line ${line + 1} at rest',
        );
      }
      await tester.dragFrom(const Offset(250, 600), const Offset(0, -900));
      await tester.pumpAndSettle();
      final rows = gutter(tester).paintedRows;
      expect(position(tester).pixels, greaterThan(500));
      expect(rows.keys.first, greaterThan(20));
      for (final line in rows.keys) {
        expect(
          gutterTop(tester, line),
          closeTo(textTop(tester, text, line), .5),
          reason: 'line ${line + 1} after scrolling',
        );
      }
      // Dragging the numbers scrolls the text too.
      final before = position(tester).pixels;
      await tester.dragFrom(const Offset(15, 500), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(position(tester).pixels, greaterThan(before));
    });

    testWidgets('the gutter stays aligned at large text scale', (tester) async {
      final text = lines(60);
      await openEditor(tester, text, scale: 2, size: const Size(320, 700));
      await tester.dragFrom(const Offset(250, 500), const Offset(0, -700));
      await tester.pumpAndSettle();
      for (final line in gutter(tester).paintedRows.keys) {
        expect(
          gutterTop(tester, line),
          closeTo(textTop(tester, text, line), .5),
        );
      }
    });

    testWidgets('a 3000 line file scrolls to its last line', (tester) async {
      final text = lines(3000);
      await openEditor(tester, text);
      final pos = position(tester);
      expect(pos.maxScrollExtent, greaterThan(50000));
      for (var i = 0; i < 80 && pos.pixels < pos.maxScrollExtent - 1; i++) {
        await tester.fling(fieldFinder, const Offset(0, -2500), 6000);
        await tester.pumpAndSettle();
      }
      expect(pos.pixels, closeTo(pos.maxScrollExtent, 1));
      final rows = gutter(tester).paintedRows;
      expect(rows.keys.last, 2999);
      final bottom = textTop(tester, text, 2999);
      final area = tester.getRect(fieldFinder);
      expect(bottom, greaterThan(area.top));
      expect(
        bottom + gutter(tester).lineHeight,
        lessThanOrEqualTo(area.bottom),
      );
      expect(gutterTop(tester, 2999), closeTo(bottom, .5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('opening a file does not open the keyboard', (tester) async {
      await openEditor(tester, lines(10));
      expect(fieldWidget(tester).focusNode!.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.byIcon(Icons.keyboard_outlined), findsOneWidget);
      // Tapping into the text is what opens it.
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
      expect(fieldWidget(tester).focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('the nav button shows and hides the keyboard', (tester) async {
      await openEditor(tester, lines(10), locale: 'en');
      final focus = fieldWidget(tester).focusNode!;
      await tapKey(tester, 'sftp-editor-keyboard');
      expect(focus.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      // The platform reports the keyboard once it is up.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.keyboard_hide_outlined), findsOneWidget);
      expect(find.byTooltip('Hide Keyboard'), findsOneWidget);
      await tapKey(tester, 'sftp-editor-keyboard');
      expect(focus.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.keyboard_outlined), findsOneWidget);
      expect(find.byTooltip('Open Keyboard'), findsOneWidget);
      // Swiped away by the user while focus stayed: the button brings it back.
      await tapKey(tester, 'sftp-editor-keyboard');
      expect(focus.hasFocus, isTrue);
      tester.testTextInput.hide();
      await tester.pump();
      await tapKey(tester, 'sftp-editor-keyboard');
      expect(focus.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('typing at the end keeps the caret above the keyboard', (
      tester,
    ) async {
      final text = lines(500);
      await openEditor(tester, text);
      await tapKey(tester, 'sftp-editor-keyboard');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.enterText(fieldFinder, '$text\nnew last line');
      await tester.pumpAndSettle();
      final render = tester
          .state<EditableTextState>(find.byType(EditableText))
          .renderEditable;
      final caret = render.getLocalRectForCaret(
        TextPosition(offset: text.length + '\nnew last line'.length),
      );
      final y = render.localToGlobal(caret.bottomLeft).dy;
      expect(y, lessThanOrEqualTo(844 - 300));
      expect(y, greaterThan(300));
      expect(
        position(tester).pixels,
        closeTo(position(tester).maxScrollExtent, 1),
      );
    });

    testWidgets('long lines scroll sideways instead of wrapping', (
      tester,
    ) async {
      final text = 'short\n${'x' * 300}\nshort';
      await openEditor(tester, text);
      // Still three visual lines: the gutter would drift if this wrapped.
      final area = tester.getRect(fieldFinder);
      expect(area.width, greaterThan(300 * 8));
      expect(
        gutterTop(tester, 2) - gutterTop(tester, 0),
        closeTo(2 * gutter(tester).lineHeight, .5),
      );
      expect(
        textTop(tester, text, 2) - textTop(tester, text, 0),
        closeTo(2 * gutter(tester).lineHeight, .5),
      );
      final sideways = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(sideways.position.axis, Axis.horizontal);
      expect(sideways.position.maxScrollExtent, greaterThan(1500));
    });

    testWidgets('binary and oversized files are not opened as text', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(entry('blob.bin'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sftp-action-edit');
      expect(find.text('不是 UTF-8 文本文件'), findsOneWidget);
      expect(find.byKey(const ValueKey('sftp-editor-field')), findsNothing);
      await tester.pump(const Duration(seconds: 6));
      // Known size above 512 KiB: the action is not offered at all.
      await tester.tap(entry('log.txt'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sftp-action-edit')), findsNothing);
      expect(
        find.byKey(const ValueKey('sftp-action-download')),
        findsOneWidget,
      );
    });
  });

  group('transfers', () {
    File picked(String name, String content) =>
        File('${work.path}/$name')..writeAsStringSync(content);

    testWidgets('uploads queue sequentially and conflicts ask', (tester) async {
      local.picks = [
        picked('one.txt', '1'),
        picked('notes.txt', 'replacement'), // exists remotely
        picked('three.txt', '3'),
      ];
      fake.hold = Completer<void>();
      await open(tester);
      await tapKey(tester, 'sftp-add');
      await tapKey(tester, 'sftp-upload');
      await _settle(tester);
      expect(local.picked, 1);
      // First upload is running (held), the others wait.
      expect(find.byKey(const ValueKey('sftp-transfer-bar')), findsOneWidget);
      expect(find.text('正在上传 one.txt'), findsOneWidget);
      expect(find.textContaining('第 1 / 3 项'), findsOneWidget);
      expect(fake.calls.where((c) => c.startsWith('upload:')), [
        'upload:/home/user/one.txt',
      ]);
      fake.hold!.complete();
      await _settle(tester);
      // The second one clashes: the user is asked, here to skip.
      expect(find.text('“notes.txt”已存在'), findsOneWidget);
      await tapText(tester, '取消');
      await _settle(tester);
      expect(fake.text('/home/user/notes.txt'), 'hello\nworld');
      expect(fake.text('/home/user/one.txt'), '1');
      expect(fake.text('/home/user/three.txt'), '3');
      expect(entry('three.txt'), findsOneWidget);
      // Picker copies are discarded when done.
      expect(local.discarded, hasLength(3));
    });

    testWidgets('overwrite answer replaces the remote file', (tester) async {
      local.picks = [picked('notes.txt', 'replacement')];
      await open(tester);
      await tapKey(tester, 'sftp-add');
      await tapKey(tester, 'sftp-upload');
      await _settle(tester);
      await tapText(tester, '覆盖');
      await _settle(tester);
      expect(fake.text('/home/user/notes.txt'), 'replacement');
    });

    testWidgets('a running upload can be cancelled from the bar', (
      tester,
    ) async {
      local.picks = [picked('slow.bin', 'x' * 100)];
      fake.hold = Completer<void>();
      await open(tester);
      await tapKey(tester, 'sftp-add');
      await tapKey(tester, 'sftp-upload');
      await _settle(tester);
      expect(find.text('正在上传 slow.bin'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sftp-transfer-dismiss')));
      await _settle(tester);
      expect(fake.exists('/home/user/slow.bin'), isFalse);
      // Finished state: the bar shows it can be cleared.
      await tester.tap(find.byKey(const ValueKey('sftp-transfer-dismiss')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('sftp-transfer-bar')), findsNothing);
    });

    testWidgets('failed uploads report the typed reason', (tester) async {
      local.picks = [picked('a.txt', 'a')];
      fake.failNext['upload'] = SftpErrorKind.permissionDenied;
      await open(tester);
      await tapKey(tester, 'sftp-add');
      await tapKey(tester, 'sftp-upload');
      await _settle(tester);
      expect(find.text('a.txt: 没有权限'), findsOneWidget);
      expect(find.byKey(const ValueKey('sftp-transfer-bar')), findsOneWidget);
    });

    testWidgets('download saves into the downloads folder and offers share', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(entry('notes.txt'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sftp-action-download');
      await _settle(tester);
      final saved = File('${work.path}/SFTP Downloads/notes.txt');
      expect(saved.readAsStringSync(), 'hello\nworld');
      expect(find.text('已保存到 SFTP Downloads/notes.txt'), findsOneWidget);
      await tester.tap(find.text('分享'));
      await tester.pumpAndSettle();
      expect(local.shared, [saved.path]);

      // A second download never overwrites: it gets a new name.
      await tester.pump(const Duration(seconds: 6));
      await tester.tap(entry('notes.txt'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sftp-action-download');
      await _settle(tester);
      expect(
        File('${work.path}/SFTP Downloads/notes (1).txt').readAsStringSync(),
        'hello\nworld',
      );
    });

    testWidgets('the transfer sheet lists items, shares and clears', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(entry('notes.txt'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sftp-action-download');
      await _settle(tester);
      await tester.pump(const Duration(seconds: 6));
      await tester.tap(find.byKey(const ValueKey('sftp-transfer-bar')));
      await tester.pumpAndSettle();
      expect(find.text('传输'), findsOneWidget);
      expect(find.textContaining('SFTP Downloads'), findsWidgets);
      await tapKey(tester, 'sftp-transfer-share-1');
      expect(local.shared, hasLength(1));
      await tapKey(tester, 'sftp-transfer-clear');
      expect(find.byKey(const ValueKey('sftp-transfer-bar')), findsNothing);
    });

    testWidgets('large downloads warn first', (tester) async {
      await open(tester);
      await tester.tap(entry('huge.iso'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sftp-action-download');
      expect(find.text('大文件'), findsOneWidget);
      expect(find.textContaining('200.0 MB'), findsWidgets);
      await tapText(tester, '取消');
      await _settle(tester);
      expect(fake.calls.where((c) => c.startsWith('download')), isEmpty);
      expect(find.byKey(const ValueKey('sftp-transfer-bar')), findsNothing);
      await tester.tap(entry('huge.iso'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sftp-action-download');
      await tapText(tester, '继续');
      await _settle(tester);
      expect(fake.calls, contains('download:/home/user/huge.iso'));
    });

    testWidgets('closing during a transfer asks and cancels it', (
      tester,
    ) async {
      local.picks = [picked('slow.bin', 'x')];
      fake.hold = Completer<void>();
      await open(tester, sheet: true);
      await tapKey(tester, 'sftp-add');
      await tapKey(tester, 'sftp-upload');
      await _settle(tester);
      await tapKey(tester, 'sftp-close');
      expect(find.text('传输进行中'), findsOneWidget);
      await tapText(tester, '取消');
      expect(find.byKey(const ValueKey('sftp-close')), findsOneWidget);
      await tapKey(tester, 'sftp-close');
      await tapText(tester, '取消传输并关闭');
      await _settle(tester);
      expect(find.text('launcher'), findsOneWidget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(fake.closed, isTrue);
      expect(fake.exists('/home/user/slow.bin'), isFalse);
    });
  });

  group('lifecycle', () {
    testWidgets('leaving the page closes the session it owns', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('app-nav-back')));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(fake.closed, isTrue);
    });

    testWidgets('a short trip to the background keeps the session', (
      tester,
    ) async {
      await open(tester);
      await background(tester, stay: const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sftp-add')), findsOneWidget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(fake.closed, isFalse);
    });

    testWidgets('staying past the grace period closes a standalone session', (
      tester,
    ) async {
      await open(tester);
      await background(
        tester,
        stay: fixedBackgroundGrace + const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(find.text('launcher'), findsOneWidget);
      expect(
        find.text('应用进入后台，SFTP 已关闭'),
        findsNothing,
      ); // toast is the caller's
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(fake.closed, isTrue);
    });

    testWidgets(
      'a running transfer continues in the grace period, then is cancelled',
      (tester) async {
        local.picks = [File('${work.path}/slow.bin')..writeAsStringSync('x')];
        fake.hold = Completer<void>();
        await open(tester);
        await tapKey(tester, 'sftp-add');
        await tapKey(tester, 'sftp-upload');
        await _settle(tester);
        await background(tester, stay: const Duration(seconds: 10));
        await tester.pump();
        expect(find.byKey(const ValueKey('sftp-add')), findsOneWidget);
        expect(fake.closed, isFalse);
        await background(
          tester,
          stay: fixedBackgroundGrace + const Duration(seconds: 1),
        );
        await _settle(tester);
        expect(find.text('launcher'), findsOneWidget);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        expect(fake.closed, isTrue);
        expect(fake.exists('/home/user/slow.bin'), isFalse);
      },
    );

    testWidgets('backgrounding while a picker is open does not close it', (
      tester,
    ) async {
      final gate = Completer<List<File>>();
      final slow = _GatedLocalFiles(work, gate.future);
      local = slow;
      await open(tester);
      await tapKey(tester, 'sftp-add');
      await tapKey(tester, 'sftp-upload');
      await background(tester);
      await tester.pump();
      expect(find.byKey(const ValueKey('sftp-add')), findsOneWidget);
      gate.complete([]);
      await tester.pumpAndSettle();
      expect(fake.closed, isFalse);
    });

    testWidgets('a sheet stays open when the app is backgrounded', (
      tester,
    ) async {
      await open(tester, sheet: true);
      await background(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sftp-close')), findsOneWidget);
      expect(fake.closed, isFalse);
    });
  });

  group('layout', () {
    for (final locale in ['zh', 'en']) {
      testWidgets('editor at 320px and 2x text has no overflow ($locale)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final text =
            '${List.generate(1200, (i) => 'row $i ${'ab' * 40}').join('\n')}\n中文行很长很长很长';
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(),
            locale: Locale(locale),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: SftpTextEditorPage(
              session: fake,
              path: '/home/user/notes.txt',
              name: 'an-extremely-long-file-name-for-the-editor.sh',
              file: SftpTextFile(text: text, size: text.length),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('sftp-editor-keyboard')));
        tester.view.viewInsets = const FakeViewPadding(bottom: 560);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('sftp-editor-more')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    for (final locale in ['zh', 'en']) {
      testWidgets('320px at 2x text has no overflow ($locale)', (tester) async {
        fake
          ..dir('/home/user/a-very-long-folder-name-that-keeps-going-and-going')
          ..file(
            '/home/user/an-extremely-long-file-name-without-any-spaces-in-it.tar.gz',
            'x',
          );
        local.picks = [];
        await open(
          tester,
          locale: locale,
          scale: 2,
          size: const Size(320, 700),
          initialPath: '/home/user',
        );
        expect(tester.takeException(), isNull);
        for (final key in ['sftp-add', 'sftp-more']) {
          await tapKey(tester, key);
          expect(tester.takeException(), isNull, reason: key);
          final close = find.byKey(const ValueKey('app-sheet-close'));
          if (close.evaluate().isNotEmpty) {
            await tester.tap(close);
          } else {
            await tester.tap(find.text(locale == 'zh' ? '取消' : 'Cancel').last);
          }
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(entry('notes.txt'));
        await tester.pumpAndSettle();
        await tester.tap(entry('notes.txt'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(locale == 'zh' ? '取消' : 'Cancel').last);
        await tester.pumpAndSettle();
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}

class _GatedLocalFiles extends FakeLocalFiles {
  _GatedLocalFiles(super.root, this.gate);
  final Future<List<File>> gate;
  @override
  Future<List<File>> pickUploads() => gate;
}
