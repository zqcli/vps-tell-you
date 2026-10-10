import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/connections/snippet.dart';
import 'package:vps_tell_you/connections/ssh_service.dart';
import 'package:vps_tell_you/connections/terminal_font.dart';
import 'package:vps_tell_you/connections/terminal_page.dart';
import 'package:vps_tell_you/connections/terminal_widgets.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:xterm/xterm.dart';

import 'security_store_test.dart' show FakeDeviceAuth, FakeSecretStore;
import 'terminal_widget_test.dart' show SpySshService;

// Independent review fixtures: no network, keyring, power API, or user data.
void main() {
  final evidence = Platform.environment['VPS_TERMINAL_EVIDENCE_DIR'];
  var fontsLoaded = false;
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late SpySshService ssh;

  const target = SshTarget(
    name: '键盘与发送审查',
    host: '127.0.0.1',
    username: 'review',
    port: 22022,
    credentialId: 'synthetic-review-only',
  );
  const alternate = SshTarget(
    name: '另一台合成目标',
    host: '::1',
    username: 'other',
    port: 22023,
    credentialId: 'another-synthetic-only',
  );

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('keyboard-send-review-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
    );
    ledger = LedgerController(
      store,
      security: SecurityController(
        store: store,
        secrets: FakeSecretStore(),
        authenticator: FakeDeviceAuth(),
      ),
    );
    await ledger.refresh();
    ssh = SpySshService();
  });

  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Finder keyed(String key) => find.byKey(ValueKey(key));
  TextEditingController draft(WidgetTester tester) =>
      tester.widget<TextField>(keyed('terminal-draft')).controller!;
  TerminalViewState terminalView(WidgetTester tester) =>
      tester.state<TerminalViewState>(find.byType(TerminalView));

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    String initialDraft = '',
    ValueNotifier<SshTarget>? targets,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    if (!fontsLoaded) {
      await tester.runAsync(() async {
        final mono = FontLoader(terminalFontFamily);
        for (final filename in [
          'DejaVuSansMono.ttf',
          'DejaVuSansMono-Bold.ttf',
        ]) {
          mono.addFont(
            File('assets/fonts/$filename')
                .readAsBytes()
                .then(ByteData.sublistView),
          );
        }
        await mono.load();
        final cjk = File(
          Platform.environment['VPS_TERMINAL_CJK_FONT'] ??
              '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
        );
        if (await cjk.exists()) {
          final bytes = ByteData.sublistView(await cjk.readAsBytes());
          for (final family in [
            'Roboto',
            'Noto Sans CJK SC',
            'Noto Sans Mono CJK SC',
          ]) {
            final loader = FontLoader(family);
            loader.addFont(Future.value(bytes));
            await loader.load();
          }
        } else if (evidence != null) {
          fail('Visual evidence requires the configured real CJK font.');
        }
        final root = Platform.environment['FLUTTER_BOOTSTRAP_ROOT'];
        if (root != null) {
          final icons = FontLoader('MaterialIcons');
          icons.addFont(
            File(
              '$root/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes().then(ByteData.sublistView),
          );
          await icons.load();
        }
        fontsLoaded = true;
      });
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: const ValueKey('keyboard-send-evidence'),
            child: child,
          ),
        ),
        home: targets == null
            ? TerminalPage(
                ledger: ledger,
                target: target,
                initialDraft: initialDraft,
                connectOnOpen: true,
                serviceFactory: (_) => ssh,
              )
            : ValueListenableBuilder<SshTarget>(
                valueListenable: targets,
                builder: (_, value, _) => TerminalPage(
                  ledger: ledger,
                  target: value,
                  initialDraft: initialDraft,
                  connectOnOpen: true,
                  serviceFactory: (_) => ssh,
                ),
              ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (evidence == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      keyed('keyboard-send-evidence'),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(evidence).create(recursive: true);
      await File('$evidence/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  void expectCursorVisible(WidgetTester tester, {required String reason}) {
    final state = terminalView(tester);
    final terminalRect = tester.getRect(find.byType(TerminalView));
    final cursor = state.globalCursorRect;
    expect(cursor.top, greaterThanOrEqualTo(terminalRect.top), reason: reason);
    expect(
      cursor.bottom,
      lessThanOrEqualTo(terminalRect.bottom),
      reason: reason,
    );
    expect(
      cursor.left,
      greaterThanOrEqualTo(terminalRect.left),
      reason: reason,
    );
    expect(cursor.right, lessThanOrEqualTo(terminalRect.right), reason: reason);
    final keyBar = tester.getRect(find.byType(TerminalKeyBar));
    final keyboardTop =
        tester.view.physicalSize.height - tester.view.viewInsets.bottom;
    expect(keyBar.bottom, lessThanOrEqualTo(keyboardTop), reason: reason);
    expect(terminalRect.bottom, lessThanOrEqualTo(keyBar.top), reason: reason);
    expect(ssh.sizes.last.$2, state.widget.terminal.viewHeight, reason: reason);
  }

  Future<void> mockClipboard(
    WidgetTester tester,
    Future<Object?> Function(MethodCall call) handler,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, handler);
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  testWidgets(
    'review: inline exact send preserves hazardous bytes without dialog',
    (tester) async {
      const exact = 'echo synthetic\\path\nnext\r\t\x1b[2K\x03\u202e';
      await mount(tester, initialDraft: exact);
      await tap(tester, keyed('terminal-commands'));
      expect(find.text('发送'), findsOneWidget);
      expect(find.text('发送并执行'), findsOneWidget);
      // The top bar subtitle shows the same address; look in the panel.
      expect(
        find.descendant(
          of: keyed('terminal-command-scroll'),
          matching: find.text(escapedCommandPreview(target.label)),
        ),
        findsOneWidget,
      );
      expect(find.text(escapedCommandPreview(exact)), findsOneWidget);
      expect(keyed('draft-exact-preview'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(ssh.writes, isEmpty);
      await capture(tester, 'inline-hazardous-draft-390x844');
      await tap(tester, keyed('terminal-send'));
      expect(ssh.writes, [exact]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TerminalCommandSheet), findsNothing);
      await tap(tester, keyed('terminal-commands'));
      expect(draft(tester).text, isEmpty);
    },
  );

  testWidgets('review: send and execute appends exactly one CR even after CR', (
    tester,
  ) async {
    const exact = 'echo synthetic\r';
    await mount(tester, initialDraft: exact);
    await tap(tester, keyed('terminal-commands'));
    await tap(tester, keyed('terminal-send-execute'));
    expect(ssh.writes, ['$exact\r']);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'review: mixed repeated send callbacks submit one current draft',
    (tester) async {
      await mount(tester, initialDraft: 'first');
      await tap(tester, keyed('terminal-commands'));
      await tester.enterText(keyed('terminal-draft'), 'edited');
      await tester.pumpAndSettle();
      expect(find.text(escapedCommandPreview('edited')), findsWidgets);
      final send = tester
          .widget<ButtonStyleButton>(keyed('terminal-send'))
          .onPressed!;
      final execute = tester
          .widget<ButtonStyleButton>(keyed('terminal-send-execute'))
          .onPressed!;
      send();
      execute();
      send();
      await tester.pumpAndSettle();
      expect(ssh.writes, ['edited']);
      expect(tester.takeException(), isNull);
    },
  );

  for (final execute in [false, true]) {
    testWidgets(
      'review: ${execute ? 'execute' : 'send'} restores the terminal IME with retained inset',
      (tester) async {
        await mount(tester);
        await tap(tester, keyed('terminal-commands'));
        await tester.ensureVisible(keyed('terminal-draft'));
        await tester.enterText(keyed('terminal-draft'), 'from-draft');
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tap(
          tester,
          keyed(execute ? 'terminal-send-execute' : 'terminal-send'),
        );
        expect(find.byType(TerminalCommandSheet), findsNothing);
        expect(terminalView(tester).hasInputConnection, isTrue);
        expect(tester.testTextInput.hasAnyClients, isTrue);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '  x',
            selection: TextSelection.collapsed(offset: 3),
          ),
        );
        await tester.pump();
        expect(ssh.writes, [execute ? 'from-draft\r' : 'from-draft', 'x']);
        expectCursorVisible(tester, reason: 'Restored input after draft send');
      },
    );
  }

  testWidgets(
    'review: stale send callback cannot submit after target changes',
    (tester) async {
      final targets = ValueNotifier(target);
      addTearDown(targets.dispose);
      await mount(tester, initialDraft: 'old-target-only', targets: targets);
      await tap(tester, keyed('terminal-commands'));
      final execute = tester
          .widget<ButtonStyleButton>(keyed('terminal-send-execute'))
          .onPressed!;
      targets.value = alternate;
      await tester.pumpAndSettle();
      execute();
      await tester.pumpAndSettle();
      expect(ssh.writes, isEmpty);
      expect(ssh.connected, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'review: Ctrl V reads on click once and never writes or executes',
    (tester) async {
      var reads = 0;
      final clipboard = Completer<Object?>();
      await mockClipboard(tester, (call) {
        if (call.method == 'Clipboard.getData') {
          reads++;
          return clipboard.future;
        }
        return Future.value();
      });
      await mount(tester);
      expect(reads, 0);
      final paste = tester
          .widget<TextButton>(keyed('terminal-paste'))
          .onPressed!;
      paste();
      paste();
      await tester.pump();
      expect(
        reads,
        1,
        reason: 'One in-flight user paste must not race another.',
      );
      const content = 'echo synthetic\nnext\r\x03';
      clipboard.complete({'text': content});
      await tester.pumpAndSettle();
      expect(draft(tester).text, content);
      expect(ssh.writes, isEmpty);
      expect(ssh.writes, isNot(contains('\x16')));
      expect(find.byType(TerminalCommandSheet), findsOneWidget);
    },
  );

  testWidgets(
    'review: touch paste consumes armed Ctrl and leaves a local draft',
    (tester) async {
      await mockClipboard(
        tester,
        (call) async => call.method == 'Clipboard.getData'
            ? {'text': 'synthetic-only'}
            : null,
      );
      await mount(tester);
      await tap(tester, keyed('terminal-control'));
      expect(
        tester.widget<TerminalKeyBar>(find.byType(TerminalKeyBar)).controlArmed,
        isTrue,
      );
      await tap(tester, keyed('terminal-paste'));
      expect(draft(tester).text, 'synthetic-only');
      expect(ssh.writes, isEmpty);
      await tap(tester, keyed('terminal-commands-close'));
      expect(
        tester.widget<TerminalKeyBar>(find.byType(TerminalKeyBar)).controlArmed,
        isFalse,
      );
      await tap(tester, keyed('terminal-keyboard'));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '  c',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await tester.pump();
      expect(ssh.writes, ['c']);
    },
  );

  for (final transition in ['target', 'disconnect', 'dispose']) {
    testWidgets('review: pending clipboard is invalidated by $transition', (
      tester,
    ) async {
      final clipboard = Completer<Object?>();
      await mockClipboard(
        tester,
        (call) => call.method == 'Clipboard.getData'
            ? clipboard.future
            : Future.value(),
      );
      final targets = ValueNotifier(target);
      addTearDown(targets.dispose);
      await mount(tester, targets: targets);
      await tester.ensureVisible(keyed('terminal-paste'));
      await tester.tap(keyed('terminal-paste'));
      await tester.pump();
      if (transition == 'target') {
        targets.value = alternate;
      } else if (transition == 'disconnect') {
        ssh.disconnect();
      } else {
        await tester.pumpWidget(const SizedBox.shrink());
      }
      await tester.pumpAndSettle();
      clipboard.complete({'text': 'must-not-follow-transition\r'});
      await tester.pumpAndSettle();
      expect(find.byType(TerminalCommandSheet), findsNothing);
      expect(ssh.writes, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'review: repeated paste inserts at the draft selection after Ctrl V opens it',
    (tester) async {
      var reads = 0;
      await mockClipboard(tester, (call) async {
        if (call.method != 'Clipboard.getData') return null;
        reads++;
        return {'text': reads == 1 ? 'first' : 'NEXT'};
      });
      await mount(tester);
      await tap(tester, keyed('terminal-paste'));
      expect(draft(tester).text, 'first');
      await tap(tester, keyed('terminal-draft-paste'));
      expect(
        reads,
        2,
        reason: 'Opening the drawer must release the paste lock.',
      );
      expect(draft(tester).text, 'firstNEXT');
      draft(tester).selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      await tester.pumpAndSettle();
      await tap(tester, keyed('terminal-draft-paste'));
      expect(reads, 3);
      expect(draft(tester).text, 'NEXTNEXT');
      expect(ssh.writes, isEmpty);
    },
  );

  testWidgets('review: late clipboard cannot overwrite newer draft edits', (
    tester,
  ) async {
    final clipboard = Completer<Object?>();
    await mockClipboard(
      tester,
      (call) => call.method == 'Clipboard.getData'
          ? clipboard.future
          : Future.value(),
    );
    await mount(tester);
    await tester.ensureVisible(keyed('terminal-paste'));
    await tester.tap(keyed('terminal-paste'));
    await tester.pump();
    await tap(tester, keyed('terminal-commands'));
    await tester.enterText(keyed('terminal-draft'), 'new local edits');
    clipboard.complete({'text': 'clipboard data'});
    await tester.pumpAndSettle();
    expect(draft(tester).text, 'new local edits');
    expect(ssh.writes, isEmpty);
    if (find.text('替换当前草稿？').evaluate().isNotEmpty) {
      await tap(tester, find.text('取消'));
    }
    expect(draft(tester).text, 'new local edits');
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final scale in [1.0, 2.0]) {
      final name =
          '${size.width.toInt()}x${size.height.toInt()}-${scale.toInt()}x';
      testWidgets('review: real-font cursor and keybar stay above IME at $name', (
        tester,
      ) async {
        await mount(tester, size: size, scale: scale);
        ssh.events.add(
          '${List.generate(120, (i) => 'row-${i.toString().padLeft(3, '0')} synthetic output').join('\r\n')}\r\nreview@fixture:\$ cursor-tail',
        );
        await tester.pumpAndSettle();
        await tap(tester, keyed('terminal-keyboard'));
        final terminal = terminalView(tester).widget.terminal;
        final rows = terminal.viewHeight;
        final maxInset = size.width > size.height ? 180.0 : 300.0;
        for (final inset in [maxInset / 3, maxInset * 2 / 3, maxInset]) {
          tester.view.viewInsets = FakeViewPadding(bottom: inset);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$name inset $inset');
          expectCursorVisible(tester, reason: '$name inset $inset');
          expect(terminal.buffer.getText(), contains('cursor-tail'));
        }
        expect(terminal.viewHeight, lessThan(rows));
        await capture(tester, 'cursor-ime-$name');
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        expectCursorVisible(tester, reason: '$name keyboard hidden');
        await tap(tester, keyed('terminal-keyboard'));
        tester.view.viewInsets = FakeViewPadding(bottom: maxInset);
        await tester.pumpAndSettle();
        expectCursorVisible(tester, reason: '$name keyboard reopened');
        expect(ssh.writes, isEmpty);
      });
    }
  }

  testWidgets(
    'review: history scroll survives while focused input reveals cursor',
    (tester) async {
      await mount(tester);
      ssh.events.add(
        '${List.generate(200, (i) => 'history-$i synthetic output').join('\r\n')}\r\nreview@fixture:\$ ',
      );
      await tester.pumpAndSettle();
      final scroll = terminalView(tester).widget.scrollController!;
      await tester.drag(find.byType(TerminalView), const Offset(0, 280));
      await tester.pumpAndSettle();
      expect(scroll.position.extentAfter, greaterThan(100));
      ssh.events.add('remote-output-without-forcing-user-scroll');
      await tester.pumpAndSettle();
      expect(scroll.position.extentAfter, greaterThan(100));
      await tap(tester, keyed('terminal-keyboard'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expectCursorVisible(
        tester,
        reason: 'Explicit keyboard request after history',
      );
      expect(scroll.position.extentAfter, lessThan(1));
      await tester.drag(find.byType(TerminalView), const Offset(0, 220));
      await tester.pumpAndSettle();
      expect(scroll.position.extentAfter, greaterThan(100));
      await tap(tester, keyed('terminal-scroll-bottom'));
      expectCursorVisible(tester, reason: 'Return-to-latest button');
      expect(ssh.writes, isEmpty);
    },
  );

  testWidgets(
    'review: inset rotation retains terminal, history and visible cursor',
    (tester) async {
      await mount(tester, size: const Size(320, 568), scale: 2);
      ssh.events.add(
        '${List.generate(100, (i) => 'rotate-$i').join('\r\n')}\r\n\$ ',
      );
      await tester.pumpAndSettle();
      await tap(tester, keyed('terminal-keyboard'));
      final terminal = terminalView(tester).widget.terminal;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expectCursorVisible(tester, reason: 'Portrait before rotation');
      tester.view.physicalSize = const Size(844, 390);
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      await tester.pumpAndSettle();
      expect(identical(terminalView(tester).widget.terminal, terminal), isTrue);
      expectCursorVisible(tester, reason: 'Landscape after rotation');
      expect(terminal.buffer.getText(), contains('rotate-99'));
      await capture(tester, 'cursor-rotation-844x390-2x');
      tester.view.physicalSize = const Size(320, 568);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expectCursorVisible(tester, reason: 'Portrait after rotation back');
      expect(ssh.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'review: both inline actions remain reachable at 320px 2x with IME',
    (tester) async {
      await mount(
        tester,
        size: const Size(320, 568),
        scale: 2,
        initialDraft: 'pwd',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tap(tester, keyed('terminal-commands'));
      await tester.ensureVisible(keyed('terminal-draft'));
      await tester.enterText(keyed('terminal-draft'), 'pwd\nnext');
      await tester.pumpAndSettle();
      for (final key in ['terminal-send', 'terminal-send-execute']) {
        await tester.ensureVisible(keyed(key));
        await tester.pumpAndSettle();
        expect(keyed(key).hitTestable(), findsOneWidget);
        final rect = tester.getRect(keyed(key));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(rect.bottom, lessThanOrEqualTo(268));
        expect(tester.takeException(), isNull);
      }
      await capture(tester, 'inline-actions-ime-320x568-2x');
      expect(ssh.writes, isEmpty);
    },
  );
}
