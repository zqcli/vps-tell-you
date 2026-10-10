// Independent Linux Flutter-engine QA. No socket, SSH, keyring, or command
// execution exists in this fixture. This does not claim GTK or phone IME QA.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/connections/ssh_service.dart';
import 'package:vps_tell_you/connections/terminal_font.dart';
import 'package:vps_tell_you/connections/terminal_page.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/security/secret_store.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:xterm/xterm.dart';

class DeniedSecrets implements SecretStore {
  @override
  Future<String?> read(String reference) async =>
      throw StateError('No secrets');
  @override
  Future<void> write(String reference, String value) async =>
      throw StateError('No secrets');
  @override
  Future<void> delete(String reference) async => throw StateError('No secrets');
}

class DeniedAuthentication implements DeviceAuthenticator {
  @override
  Future<bool> authenticate() async => false;
  @override
  Future<void> cancel() async {}
}

class MemorySsh extends SshService {
  final events = StreamController<String>.broadcast(sync: true);
  final writes = <String>[];
  final writeAttempts = <String>[];
  final sizes = <(int, int)>[];
  bool writable = true, throwWrites = false;
  @override
  SshStatus status = SshStatus.idle;
  @override
  String? get error => null;
  @override
  SshTarget? target;
  @override
  int generation = 0;
  @override
  bool get acceptsInput => connected && writable;
  @override
  Stream<String> get output => events.stream;
  @override
  Future<void> connect(
    SshTarget target, {
    required HostVerifier verifyHost,
    KeyPassphraseRequester? requestKeyPassphrase,
  }) async {
    this.target = target;
    generation++;
    status = SshStatus.connected;
    notifyListeners();
  }

  @override
  void write(String value) {
    writeAttempts.add(value);
    if (throwWrites) throw StateError('Synthetic write failure');
    if (acceptsInput) writes.add(value);
  }

  void setWritable(bool value) {
    writable = value;
    notifyListeners();
  }

  @override
  void resize(int columns, int rows) => sizes.add((columns, rows));
  @override
  void disconnect() {
    generation++;
    status = SshStatus.disconnected;
    notifyListeners();
  }

  @override
  Future<PowerResult> power(
    SshPowerAction action, {
    required int expectedGeneration,
  }) async => PowerResult.failed;
  @override
  void dispose() {
    events.close();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final evidence = Platform.environment['VPS_SSH_LINUX_QA_EVIDENCE'];
  late LedgerStore store;
  late LedgerController ledger;
  late MemorySsh ssh;
  var fontsLoaded = false;
  final metrics = <String, Object?>{};
  const target = SshTarget(
    name: '合成 Linux SSH 测试 · 不联网',
    host: 'synthetic-qa.invalid',
    username: 'qa',
    credentialId: 'memory-only',
  );

  setUp(() async {
    sqfliteFfiInit();
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    final secrets = DeniedSecrets();
    ledger = LedgerController(
      store,
      security: SecurityController(
        store: store,
        secrets: secrets,
        authenticator: DeniedAuthentication(),
      ),
      cloud: CloudController(
        store: store,
        secrets: secrets,
        adapterFactory: (_, _, _) => throw StateError('No cloud network'),
      ),
    );
    await ledger.refresh();
    ssh = MemorySsh();
  });

  tearDown(() async {
    ledger.dispose();
    await store.close();
    if (evidence != null) {
      await Directory(evidence).create(recursive: true);
      await File('$evidence/metrics.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(metrics));
    }
  });

  Finder key(String value) => find.byKey(ValueKey(value));
  TerminalView view(WidgetTester tester) =>
      tester.widget<TerminalView>(find.byType(TerminalView));
  TerminalViewState viewState(WidgetTester tester) =>
      tester.state<TerminalViewState>(find.byType(TerminalView));

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    if (!fontsLoaded) {
      await tester.runAsync(() async {
        final font = FontLoader(terminalFontFamily);
        for (final name in ['DejaVuSansMono.ttf', 'DejaVuSansMono-Bold.ttf']) {
          font.addFont(
            File('assets/fonts/$name').readAsBytes().then(ByteData.sublistView),
          );
        }
        await font.load();
        final cjkFile = File(
          Platform.environment['VPS_TERMINAL_CJK_FONT'] ??
              '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
        );
        if (await cjkFile.exists()) {
          final cjk = await cjkFile.readAsBytes();
          for (final name in [
            'Roboto',
            'Noto Sans CJK SC',
            'Noto Sans Mono CJK SC',
          ]) {
            final font = FontLoader(name);
            font.addFont(Future.value(ByteData.sublistView(cjk)));
            await font.load();
          }
        } else if (evidence != null) {
          fail('Visual evidence requires VPS_TERMINAL_CJK_FONT.');
        }
        final bootstrap = Platform.environment['FLUTTER_BOOTSTRAP_ROOT'];
        if (bootstrap != null) {
          final icons = FontLoader('MaterialIcons');
          icons.addFont(
            File(
              '$bootstrap/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes().then(ByteData.sublistView),
          );
          await icons.load();
        }
      });
      fontsLoaded = true;
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(brightness: Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(key: const ValueKey('qa-image'), child: child),
        ),
        home: TerminalPage(
          ledger: ledger,
          target: target,
          connectOnOpen: true,
          serviceFactory: (_) => ssh,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(ssh.connected, isTrue);
  }

  Future<void> tap(WidgetTester tester, String target) async {
    await tester.ensureVisible(key(target));
    await tester.tap(key(target));
    await tester.pumpAndSettle();
  }

  Map<String, Object?> snapshot(WidgetTester tester) {
    final terminalView = view(tester);
    final render = viewState(tester).renderTerminal;
    final scroll = terminalView.scrollController!.position;
    final top = render
        .getCellOffset(Offset.zero)
        .y
        .clamp(0, terminalView.terminal.buffer.height - 1);
    return {
      'columns': terminalView.terminal.viewWidth,
      'rows': terminalView.terminal.viewHeight,
      'terminalPixels': [render.size.width, render.size.height],
      'cursor': [render.cursorOffset.dx, render.cursorOffset.dy],
      'cell': [render.cellSize.width, render.cellSize.height],
      'scrollPixels': scroll.pixels,
      'scrollMax': scroll.maxScrollExtent,
      'extentAfter': scroll.extentAfter,
      'firstVisibleRow': top,
      'firstVisibleText': terminalView.terminal.buffer.lines[top].getText(),
      'lastResize': [ssh.sizes.last.$1, ssh.sizes.last.$2],
    };
  }

  void expectCursorVisible(WidgetTester tester, String label) {
    final render = viewState(tester).renderTerminal;
    metrics[label] = snapshot(tester);
    expect(render.cursorOffset.dy, greaterThanOrEqualTo(-.1), reason: label);
    expect(
      render.cursorOffset.dy + render.cellSize.height,
      lessThanOrEqualTo(render.size.height + .1),
      reason: label,
    );
    expect(ssh.sizes.last.$1, view(tester).terminal.viewWidth, reason: label);
    expect(ssh.sizes.last.$2, view(tester).terminal.viewHeight, reason: label);
    expect(tester.takeException(), isNull, reason: label);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (evidence == null) return;
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      key('qa-image'),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(evidence).create(recursive: true);
      await File('$evidence/$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> seedHistory(WidgetTester tester) async {
    ssh.events.add(
      '${List.generate(180, (i) => 'L${i.toString().padLeft(3, '0')} synthetic row').join('\r\n')}\r\nqa> ',
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Linux engine: repeated insets and resize retain the live cursor',
    (tester) async {
      await mount(tester);
      await seedHistory(tester);
      await tap(tester, 'terminal-keyboard');
      expectCursorVisible(tester, 'live-initial');
      for (final inset in [120.0, 300.0, 360.0, 180.0, 0.0, 320.0, 0.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pumpAndSettle();
        expectCursorVisible(tester, 'live-inset-$inset');
        if (inset == 300) await capture(tester, 'portrait-keyboard-inset');
      }
      tester.view.physicalSize = const Size(844, 390);
      tester.view.viewInsets = const FakeViewPadding(bottom: 150);
      await tester.pumpAndSettle();
      expectCursorVisible(tester, 'live-landscape-inset');
      await capture(tester, 'landscape-keyboard-inset');
      tester.view.physicalSize = const Size(390, 844);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expectCursorVisible(tester, 'live-portrait-restored');
      expect(ssh.writes, isEmpty);
    },
  );

  testWidgets('Linux engine: reading history survives insets and new output', (
    tester,
  ) async {
    await mount(tester);
    await seedHistory(tester);
    await tap(tester, 'terminal-keyboard');
    expect(view(tester).focusNode!.hasFocus, isTrue);
    final controller = view(tester).scrollController!;
    controller.jumpTo(controller.position.maxScrollExtent - 500);
    await tester.pumpAndSettle();
    final before = snapshot(tester);
    metrics['history-before'] = before;
    for (final inset in [300.0, 0.0, 360.0, 160.0, 0.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pumpAndSettle();
      final after = snapshot(tester);
      metrics['history-inset-$inset'] = after;
      expect(
        after['scrollPixels'],
        closeTo(before['scrollPixels']! as double, 1),
      );
      expect(after['firstVisibleText'], before['firstVisibleText']);
      expect(controller.position.extentAfter, greaterThan(24));
      expect(tester.takeException(), isNull);
    }
    tester.view.physicalSize = const Size(844, 390);
    tester.view.viewInsets = const FakeViewPadding(bottom: 150);
    await tester.pumpAndSettle();
    metrics['focused-history-landscape'] = snapshot(tester);
    expect(snapshot(tester)['firstVisibleText'], before['firstVisibleText']);
    expect(controller.position.extentAfter, greaterThan(24));
    expect(view(tester).focusNode!.hasFocus, isTrue);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    metrics['focused-history-portrait'] = snapshot(tester);
    expect(snapshot(tester)['firstVisibleText'], before['firstVisibleText']);
    expect(controller.position.extentAfter, greaterThan(24));
    expect(view(tester).focusNode!.hasFocus, isTrue);
    ssh.events.add('\r\nnew synthetic output while reading history\r\nqa> ');
    await tester.pumpAndSettle();
    expect(snapshot(tester)['firstVisibleText'], before['firstVisibleText']);
    await capture(tester, 'history-preserved');
    await tap(tester, 'terminal-scroll-bottom');
    expectCursorVisible(tester, 'history-return-live');
    expect(ssh.writes, isEmpty);
  });

  testWidgets(
    'Linux engine: alternate-screen cursor remains visible on shrink',
    (tester) async {
      await mount(tester);
      await seedHistory(tester);
      await tap(tester, 'terminal-keyboard');
      final rows = view(tester).terminal.viewHeight;
      ssh.events.add('\x1b[?1049h\x1b[2J\x1b[$rows;1Hsynthetic TUI> ');
      await tester.pumpAndSettle();
      for (final inset in [280.0, 340.0, 0.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pumpAndSettle();
        expectCursorVisible(tester, 'alternate-inset-$inset');
      }
      ssh.events.add('\x1b[?1049l');
      await tester.pumpAndSettle();
      expectCursorVisible(tester, 'alternate-main-restored');
      expect(ssh.writes, isEmpty);
    },
  );

  testWidgets(
    'Linux engine: inline sends preserve bytes and add exactly one CR',
    (tester) async {
      await mount(tester);
      const payload = '  echo "你好"\nsecond line  ';
      for (final execute in [false, true]) {
        await tap(tester, 'terminal-commands');
        final send = execute ? 'terminal-send-execute' : 'terminal-send';
        final button = tester.widget<ButtonStyleButton>(key(send));
        expect(button.onPressed, isNull);
        await tester.ensureVisible(key('terminal-draft'));
        await tester.enterText(key('terminal-draft'), payload);
        await tester.pumpAndSettle();
        final before = ssh.writes.length;
        await capture(
          tester,
          execute ? 'inline-send-execute' : 'inline-send-exact',
        );
        await tap(tester, send);
        expect(find.byType(AlertDialog), findsNothing);
        expect(ssh.writes.length, before + 1);
        final expected = execute ? '$payload\r' : payload;
        expect(utf8.encode(ssh.writes.last), utf8.encode(expected));
        metrics[send] = {'payloadUtf8': utf8.encode(ssh.writes.last)};
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'Linux engine: Ctrl V and paste button populate an editable draft',
    (tester) async {
      await mount(tester);
      const clipboard = '  pasted 中文\nnot executed  ';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, dynamic>{'text': clipboard}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      ssh.events.add('\x1b[?2004h');
      await tap(tester, 'terminal-keyboard');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(key('terminal-draft')).controller!.text,
        clipboard,
      );
      expect(ssh.writes, isEmpty);
      await tester.ensureVisible(key('terminal-draft'));
      await tester.enterText(key('terminal-draft'), '$clipboard edited');
      await tester.pumpAndSettle();
      expect(ssh.writes, isEmpty);
      await tap(tester, 'terminal-send');
      expect(ssh.writes, ['$clipboard edited']);
      await tap(tester, 'terminal-paste');
      expect(
        tester.widget<TextField>(key('terminal-draft')).controller!.text,
        clipboard,
      );
      expect(ssh.writes.length, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Linux engine: rejected writes retain draft and report inline without retry',
    (tester) async {
      await mount(tester);
      await tap(tester, 'terminal-commands');
      void expectButtonsDisabled() {
        for (final name in ['terminal-send', 'terminal-send-execute']) {
          expect(tester.widget<ButtonStyleButton>(key(name)).onPressed, isNull);
        }
      }

      expectButtonsDisabled();
      const payload = 'synthetic write failure must keep this draft';
      await tester.ensureVisible(key('terminal-draft'));
      await tester.enterText(key('terminal-draft'), payload);
      await tester.pumpAndSettle();
      ssh.setWritable(false);
      await tester.pumpAndSettle();
      expectButtonsDisabled();
      expect(ssh.writeAttempts, isEmpty);
      expect(
        tester.widget<TextField>(key('terminal-draft')).controller!.text,
        payload,
      );

      ssh.setWritable(true);
      ssh.throwWrites = true;
      await tester.pumpAndSettle();
      await tap(tester, 'terminal-send-execute');
      expect(ssh.writeAttempts, ['$payload\r']);
      expect(ssh.writes, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(key('terminal-draft-error'), findsOneWidget);
      expect(
        tester.widget<Text>(key('terminal-draft-error')).data,
        contains('草稿仍保留'),
      );
      expect(
        tester.widget<TextField>(key('terminal-draft')).controller!.text,
        payload,
      );
      await tester.ensureVisible(key('terminal-draft-error'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(key('terminal-draft-error')).bottom,
        lessThanOrEqualTo(844),
      );
      await capture(tester, 'write-failure-draft-preserved');
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(ssh.writeAttempts, ['$payload\r']);
      metrics['write-failure'] = {
        'attempts': ssh.writeAttempts.length,
        'writes': ssh.writes.length,
        'draftRetained': true,
        'inlineErrorVisible': true,
        'automaticRetry': false,
      };

      ssh.disconnect();
      await tester.pumpAndSettle();
      // The ended session closes the panel; the draft is discarded silently.
      expect(key('terminal-send'), findsNothing);
      expect(key('terminal-draft'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(ssh.writeAttempts.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Linux engine: short landscape keeps both inline actions reachable',
    (tester) async {
      await mount(tester, size: const Size(844, 390), scale: 2);
      await tap(tester, 'terminal-commands');
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(key('terminal-draft'));
      await tester.enterText(
        key('terminal-draft'),
        'synthetic short-screen draft',
      );
      await tester.pumpAndSettle();
      for (final name in ['terminal-send', 'terminal-send-execute']) {
        await tester.ensureVisible(key(name));
        await tester.pumpAndSettle();
        expect(
          tester.widget<ButtonStyleButton>(key(name)).onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull, reason: name);
      }
      await capture(tester, 'short-landscape-scaled-draft');
      await tap(tester, 'terminal-send-execute');
      expect(ssh.writes, ['synthetic short-screen draft\r']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
