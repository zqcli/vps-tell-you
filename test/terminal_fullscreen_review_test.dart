import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/connections/ssh_service.dart';
import 'package:vps_tell_you/connections/terminal_font.dart';
import 'package:vps_tell_you/connections/terminal_page.dart';
import 'package:vps_tell_you/connections/terminal_widgets.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/app_viewport.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:xterm/xterm.dart';

import 'security_store_test.dart' show FakeDeviceAuth, FakeSecretStore;
import 'terminal_widget_test.dart' show SpySshService;

/// Review fixtures never connect to SSH, inspect a keyring, or execute commands.
class _ReviewSshService extends SpySshService {
  (int, int)? sizeBeforeConnect;

  @override
  Future<void> connect(
    SshTarget target, {
    required HostVerifier verifyHost,
    KeyPassphraseRequester? requestKeyPassphrase,
  }) {
    sizeBeforeConnect = sizes.isEmpty ? null : sizes.last;
    return super.connect(
      target,
      verifyHost: verifyHost,
      requestKeyPassphrase: requestKeyPassphrase,
    );
  }
}

void main() {
  final evidence = Platform.environment['VPS_TERMINAL_EVIDENCE_DIR'];
  var fontsLoaded = false;
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late _ReviewSshService ssh;

  const target = SshTarget(
    name: '合成终端审查目标',
    host: '127.0.0.1',
    username: 'review',
    port: 22022,
    credentialId: 'synthetic-review-only',
  );

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('terminal-review-');
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
    ssh = _ReviewSshService();
  });

  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Finder keyed(String key) => find.byKey(ValueKey(key));

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool connect = true,
    ValueNotifier<SshTarget>? targetSource,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final viewport = AppViewportObserver();
    addTearDown(viewport.dispose);
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
        if (evidence != null) {
          final cjk = await File(
            Platform.environment['VPS_TERMINAL_CJK_FONT'] ??
                '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
          ).readAsBytes();
          for (final name in [
            'Roboto',
            'Noto Sans CJK SC',
            'Noto Sans Mono CJK SC',
          ]) {
            final loader = FontLoader(name);
            loader.addFont(Future.value(ByteData.sublistView(cjk)));
            await loader.load();
          }
          final icons = FontLoader('MaterialIcons');
          icons.addFont(
            File(
              '${Platform.environment['FLUTTER_BOOTSTRAP_ROOT']}/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
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
        navigatorObservers: [viewport],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: ValueListenableBuilder<bool>(
            valueListenable: viewport.fullWidth,
            builder: (context, fullWidth, child) => Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: fullWidth ? double.infinity : 760,
                ),
                child: child,
              ),
            ),
            child: RepaintBoundary(
              key: const ValueKey('terminal-review-evidence'),
              child: child,
            ),
          ),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            key: const ValueKey('review-ledger-home'),
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: sshTerminalRouteName),
                  builder: (_) {
                    Widget page(SshTarget value) => TerminalPage(
                      ledger: ledger,
                      target: value,
                      connectOnOpen: connect,
                      serviceFactory: (_) => ssh,
                    );
                    return targetSource == null
                        ? page(target)
                        : ValueListenableBuilder<SshTarget>(
                            valueListenable: targetSource,
                            builder: (_, value, _) => page(value),
                          );
                  },
                ),
              ),
              child: const Text('Open review terminal'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open review terminal'));
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
      keyed('terminal-review-evidence'),
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

  Future<void> keyboard(WidgetTester tester) async {
    await tap(tester, keyed('terminal-keyboard'));
    expect(tester.testTextInput.hasAnyClients, isTrue);
  }

  void insert(WidgetTester tester, String text) {
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: '  $text',
        selection: TextSelection.collapsed(offset: text.length + 2),
      ),
    );
  }

  testWidgets('review: full display width restores after leaving terminal', (
    tester,
  ) async {
    await mount(tester, size: const Size(1200, 700), connect: false);
    expect(tester.getSize(keyed('terminal-fullscreen')).width, 1200);
    expect(tester.getSize(find.byType(TerminalView)).width, 1200);
    await tap(tester, find.byTooltip('退出终端'));
    expect(tester.getSize(keyed('review-ledger-home')).width, 760);
    expect(ssh.connections, 0);
    expect(ssh.writes, isEmpty);
  });

  testWidgets(
    'review: viewport feeds PTY before connect and after IME resize',
    (tester) async {
      await mount(tester);
      final terminal = tester.widget<TerminalView>(find.byType(TerminalView));
      expect(ssh.sizeBeforeConnect, isNotNull);
      expect(ssh.sizeBeforeConnect!.$1, lessThan(80));
      final rows = terminal.terminal.viewHeight;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(terminal.terminal.viewHeight, lessThan(rows));
      expect(ssh.sizes.last.$2, terminal.terminal.viewHeight);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('review: actual text client commits CJK, deletion and Enter', (
    tester,
  ) async {
    await mount(tester);
    await keyboard(tester);
    insert(tester, 'ls');
    await tester.pump();
    expect(ssh.writes, ['ls']);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '  ni',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 2, end: 4),
      ),
    );
    await tester.pump();
    expect(ssh.writes, ['ls']);
    insert(tester, '你');
    await tester.pump();
    expect(ssh.writes, ['ls', '你']);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: ' ',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    expect(ssh.writes.last, '\x7f');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(ssh.writes.last, '\r');
    await tap(tester, keyed('terminal-key-enter'));
    expect(ssh.writes.where((value) => value == '\r').length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review: touch Ctrl is one-shot and retains text client focus', (
    tester,
  ) async {
    await mount(tester);
    await keyboard(tester);
    await tap(tester, keyed('terminal-control'));
    expect(tester.testTextInput.hasAnyClients, isTrue);
    insert(tester, 'c');
    await tester.pump();
    insert(tester, 'd');
    await tester.pump();
    expect(ssh.writes, ['\x03', 'd']);
    expect(tester.testTextInput.hasAnyClients, isTrue);
  });

  testWidgets(
    'review: IME commits consume Ctrl while protocol replies do not',
    (tester) async {
      await mount(tester);
      await keyboard(tester);
      for (final commit in ['你好', 'ab', ' ']) {
        await tap(tester, keyed('terminal-control'));
        ssh.events.add('\x1b[5n');
        await tester.pump();
        expect(
          tester
              .widget<TerminalKeyBar>(find.byType(TerminalKeyBar))
              .controlArmed,
          isTrue,
        );
        expect(ssh.writes.last, '\x1b[0n');
        insert(tester, commit);
        await tester.pump();
        expect(ssh.writes.last, commit);
        expect(
          tester
              .widget<TerminalKeyBar>(find.byType(TerminalKeyBar))
              .controlArmed,
          isFalse,
        );
        insert(tester, 'c');
        await tester.pump();
        expect(ssh.writes.last, 'c');
      }
      expect(ssh.writes, isNot(contains('\x03')));
    },
  );

  testWidgets('review: hidden platform keyboard can reopen on retained focus', (
    tester,
  ) async {
    await mount(tester);
    await keyboard(tester);
    TerminalViewState view() =>
        tester.state<TerminalViewState>(find.byType(TerminalView));
    tester.testTextInput.hide();
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(view().hasInputConnection, isTrue);
    await keyboard(tester);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(view().hasInputConnection, isTrue);
    insert(tester, 'x');
    await tester.pump();
    expect(ssh.writes, ['x']);
    tester.testTextInput.closeConnection();
    tester.testTextInput.hide();
    await tester.pump();
    final clientCallsBefore = tester.testTextInput.log
        .where((call) => call.method == 'TextInput.setClient')
        .length;
    await keyboard(tester);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(
      tester.testTextInput.log
          .where((call) => call.method == 'TextInput.setClient')
          .length,
      greaterThan(clientCallsBefore),
    );
    insert(tester, 'y');
    await tester.pump();
    expect(ssh.writes, ['x', 'y']);
  });

  testWidgets('review: reopening IME abandons unfinished composing state', (
    tester,
  ) async {
    await mount(tester);
    await keyboard(tester);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '  ni',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 2, end: 4),
      ),
    );
    await tester.pump();
    expect(ssh.writes, isEmpty);
    tester.testTextInput.closeConnection();
    tester.testTextInput.hide();
    await tester.pump();
    await keyboard(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(ssh.writes, ['\x1b[A']);
    insert(tester, 'x');
    await tester.pump();
    expect(ssh.writes, ['\x1b[A', 'x']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review: tapping with visible IME preserves CJK composition', (
    tester,
  ) async {
    await mount(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await keyboard(tester);
    final view = tester.state<TerminalViewState>(find.byType(TerminalView));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '  ni',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 2, end: 4),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(TerminalView));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(
      tester.state<TerminalViewState>(find.byType(TerminalView)),
      same(view),
    );
    expect(ssh.writes, isEmpty);
    insert(tester, '你');
    await tester.pump();
    expect(ssh.writes, ['你']);
  });

  testWidgets(
    'review: body tap after closed composing IME starts fresh client',
    (tester) async {
      await mount(tester);
      await keyboard(tester);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '  ni',
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange(start: 2, end: 4),
        ),
      );
      await tester.pump();
      expect(ssh.writes, isEmpty);
      tester.testTextInput.closeConnection();
      tester.testTextInput.hide();
      await tester.pump();
      final previousClients = tester.testTextInput.log
          .where((call) => call.method == 'TextInput.setClient')
          .length;
      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        tester.testTextInput.log
            .where((call) => call.method == 'TextInput.setClient')
            .length,
        greaterThan(previousClients),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(ssh.writes, ['\x1b[A']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('review: repeated exit is debounced and cancel keeps session', (
    tester,
  ) async {
    await mount(tester);
    final terminal = tester
        .widget<TerminalView>(find.byType(TerminalView))
        .terminal;
    ssh.events.add('output-before-cancel\r\n');
    await tester.pump();
    final leave = tester
        .widget<IconButton>(
          find.byWidgetPredicate(
            (widget) => widget is IconButton && widget.tooltip == '退出终端',
          ),
        )
        .onPressed!;
    leave();
    leave();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(ssh.connected, isTrue);
    await tap(tester, find.text('取消'));
    expect(ssh.connected, isTrue);
    expect(
      tester.widget<TerminalView>(find.byType(TerminalView)).terminal,
      same(terminal),
    );
    expect(terminal.buffer.getText(), contains('output-before-cancel'));
    expect(ssh.writes, isEmpty);
    await tap(tester, find.byTooltip('退出终端'));
    await tap(tester, find.text('断开并退出'));
    expect(ssh.disposed, isTrue);
    expect(find.text('Open review terminal'), findsOneWidget);
  });

  testWidgets('review: command sheet survives short landscape and IME', (
    tester,
  ) async {
    await mount(tester, size: const Size(844, 390), scale: 2);
    await tap(tester, keyed('terminal-commands'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tap(tester, keyed('builtin-pwd'));
    await tester.ensureVisible(keyed('terminal-draft'));
    await tester.enterText(keyed('terminal-draft'), 'echo review\n');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(ssh.writes, isEmpty);
    await tap(tester, keyed('terminal-send'));
    expect(tester.takeException(), isNull, reason: 'Opening exact-send dialog');
    expect(find.text('确认发送到单台 SSH'), findsOneWidget);
    expect(ssh.writes, isEmpty);
    await tap(tester, find.text('取消'));
    expect(
      tester.takeException(),
      isNull,
      reason: 'Cancelling exact-send dialog',
    );
    expect(ssh.writes, isEmpty);
    await tap(tester, keyed('terminal-commands-close'));
    expect(find.byType(TerminalCommandSheet), findsNothing);
    expect(ssh.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review: disconnect banners fit keyboard-shrunken landscape', (
    tester,
  ) async {
    await mount(tester, size: const Size(844, 390), scale: 2);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    ssh.error = '合成的连接结束说明；请在重连后核实远端任务状态。';
    ssh.disconnect();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(TerminalView)).height, greaterThan(0));
    expect(ssh.writes, isEmpty);
  });

  testWidgets('review: private-key prompt fits short landscape with IME', (
    tester,
  ) async {
    ssh.needsPassphrase = true;
    await mount(tester, size: const Size(844, 390), scale: 2);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(keyed('ssh-key-passphrase'));
    await tester.enterText(
      keyed('ssh-key-passphrase'),
      'synthetic-unlock-only',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(ssh.authentications, 0);
    expect(ssh.writes, isEmpty);
    await capture(tester, 'private-key-inset-844x390-2x');
    await tap(tester, find.text('取消连接').last);
    expect(ssh.passphrases, isEmpty);
    expect(ssh.authentications, 0);
  });

  testWidgets(
    'review: power target confirmation fits short landscape with IME',
    (tester) async {
      await mount(tester, size: const Size(844, 390), scale: 2);
      await tap(tester, find.byTooltip('终端菜单'));
      await tap(tester, find.text('SSH 重启'));
      await tap(tester, find.text('了解影响，继续核对'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(keyed('power-confirm-target'));
      await tester.enterText(keyed('power-confirm-target'), target.label);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(ssh.powers, isEmpty);
      expect(ssh.writes, isEmpty);
      await capture(tester, 'power-target-inset-844x390-2x');
      await tap(tester, find.text('取消'));
      expect(ssh.powers, isEmpty);
    },
  );

  testWidgets('review: hardware paste enters local draft without executing', (
    tester,
  ) async {
    const clipboard = 'echo synthetic\nnext-line\r';
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': clipboard};
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await mount(tester);
    await keyboard(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byType(TerminalCommandSheet), findsOneWidget);
    expect(
      tester.widget<TextField>(keyed('terminal-draft')).controller!.text,
      clipboard,
    );
    expect(ssh.writes, isEmpty);
  });

  testWidgets(
    'review: modal input isolation preserves terminal protocol replies',
    (tester) async {
      await mount(tester);
      final staleControlC = tester
          .widget<TextButton>(keyed('terminal-key-keyC'))
          .onPressed!;
      await tap(tester, keyed('terminal-commands'));
      ssh.events.add('\x1b[5n');
      await tester.pump();
      expect(ssh.writes, ['\x1b[0n']);
      await tester.ensureVisible(keyed('terminal-draft'));
      await tester.enterText(keyed('terminal-draft'), 'local-only\n');
      await tester.pumpAndSettle();
      staleControlC();
      await tester.pump();
      expect(ssh.writes, ['\x1b[0n']);
      await tap(tester, keyed('terminal-commands-close'));
      await tap(tester, find.byTooltip('退出终端'));
      expect(find.text('断开 SSH 会话？'), findsOneWidget);
      ssh.events.add('\x1b[5n');
      await tester.pump();
      staleControlC();
      await tester.pump();
      expect(ssh.writes, ['\x1b[0n', '\x1b[0n']);
      await tap(tester, find.text('取消'));
      expect(ssh.connected, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('review: deferred clipboard cannot cross a target change', (
    tester,
  ) async {
    final clipboard = Completer<Object?>();
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) {
      if (call.method == 'Clipboard.getData') return clipboard.future;
      return Future<Object?>.value();
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final targets = ValueNotifier(target);
    addTearDown(targets.dispose);
    await mount(tester, targetSource: targets);
    await keyboard(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    targets.value = const SshTarget(
      name: '另一台合成目标',
      host: '::1',
      username: 'other',
      credentialId: 'another-synthetic-only',
    );
    await tester.pumpAndSettle();
    clipboard.complete({'text': 'must-not-follow-target'});
    await tester.pumpAndSettle();
    expect(find.byType(TerminalCommandSheet), findsNothing);
    expect(ssh.writes, isEmpty);
    expect(ssh.connections, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review: long press selection copies without sending SSH input', (
    tester,
  ) async {
    String? copied;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await mount(tester);
    ssh.events.add('reviewcopy\r\n');
    await tester.pumpAndSettle();
    await tester.longPressAt(
      tester.getTopLeft(find.byType(TerminalView)) + const Offset(30, 16),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<TerminalView>(find.byType(TerminalView))
        .controller!;
    expect(controller.selection, isNotNull);
    await capture(tester, 'terminal-long-press-copy');
    await tap(tester, keyed('terminal-copy-selection'));
    expect(copied, contains('reviewcopy'));
    expect(controller.selection, isNull);
    expect(ssh.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review: reconnect drops unfinished IME composition', (
    tester,
  ) async {
    await mount(tester);
    await keyboard(tester);
    final original = tester.state<TerminalViewState>(find.byType(TerminalView));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '  dangerous-uncommitted',
        selection: TextSelection.collapsed(offset: 23),
        composing: TextRange(start: 2, end: 23),
      ),
    );
    await tester.pump();
    expect(ssh.writes, isEmpty);
    ssh.disconnect();
    await tester.pumpAndSettle();
    await tap(tester, keyed('terminal-connect'));
    expect(
      tester.state<TerminalViewState>(find.byType(TerminalView)),
      isNot(same(original)),
    );
    expect(ssh.writes, isEmpty);
    expect(tester.testTextInput.hasAnyClients, isFalse);
    await keyboard(tester);
    insert(tester, 'n');
    await tester.pump();
    expect(ssh.writes, ['n']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review: bundled coding glyphs align across regular and bold', (
    tester,
  ) async {
    await mount(tester);
    final view = tester.widget<TerminalView>(find.byType(TerminalView));
    expect(view.textStyle, isA<CodingTerminalStyle>());
    for (final bold in [false, true]) {
      final style = view.textStyle.toTextStyle(bold: bold);
      expect(style.fontFamily, terminalFontFamily);
      expect(
        style.fontFeatures!.map(
          (feature) => '${feature.feature}:${feature.value}',
        ),
        containsAll(['liga:0', 'clig:0', 'dlig:0', 'kern:0']),
      );
      for (final glyph in '0O1lI┌─┬┐│└┴┘'.split('')) {
        final painter = TextPainter(
          text: TextSpan(text: glyph, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        expect(painter.width, closeTo(14 * 1233 / 2048, .05));
        painter.dispose();
      }
    }
    view.terminal.write('A中B');
    expect(view.terminal.buffer.cursorX, 4);
    expect(view.terminal.buffer.lines[0].getWidth(1), 2);
    ssh.events.add(
      '\r\n0 O 1 l I  / \\ |\r\n'
      '\x1b[1m0 O 1 l I  / \\ |\x1b[0m\r\n'
      '!= == => -> && ||\r\n'
      '┌────┬────┐\r\n'
      '│ABCD│1234│\r\n'
      '│中文│测试│\r\n'
      '└────┴────┘\r\n'
      '|A中B|\r\n'
      '|1234|\r\n',
    );
    await tester.pumpAndSettle();
    await capture(tester, 'terminal-coding-font-glyphs');
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final scale in [1.0, 2.0]) {
      final name =
          '${size.width.toInt()}x${size.height.toInt()}-${scale.toInt()}x';
      testWidgets('review: terminal and command controls fit $name', (
        tester,
      ) async {
        await mount(tester, size: size, scale: scale);
        ssh.events.add(
          '\x1b[32mreview@synthetic-fixture\x1b[0m:~\$ uptime\r\n'
          ' 12:34:56 up 12 days, 3:21, 1 user, load average: 0.03\r\n'
          '\x1b[32mreview@synthetic-fixture\x1b[0m:~\$ df -h\r\n'
          'Filesystem      Size  Used Avail Use% Mounted on\r\n'
          '/dev/synthetic   40G   12G   28G  30% /\r\n'
          '\x1b[32mreview@synthetic-fixture\x1b[0m:~\$ ',
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(TerminalView)).height,
          greaterThan(0),
        );
        final commandRect = tester.getRect(keyed('terminal-commands'));
        expect(commandRect.height, greaterThanOrEqualTo(48));
        expect(commandRect.width, greaterThanOrEqualTo(48));
        await capture(tester, 'terminal-$name');

        tester.view.viewInsets = FakeViewPadding(
          bottom: size.width > size.height ? 180 : 300,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(TerminalView)).height,
          greaterThan(0),
        );
        await capture(tester, 'terminal-inset-$name');

        await tap(tester, keyed('terminal-commands'));
        await tap(tester, keyed('builtin-df'));
        expect(
          tester.widget<TextField>(keyed('terminal-draft')).controller!.text,
          'df -h',
        );
        expect(ssh.writes, isEmpty);
        expect(tester.takeException(), isNull);
        await capture(tester, 'commands-inset-$name');
        await tap(tester, keyed('terminal-commands-close'));
        expect(ssh.writes, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
