import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/connections/ssh_service.dart';
import 'package:vps_tell_you/connections/terminal_font.dart';
import 'package:vps_tell_you/connections/terminal_widgets.dart';
import 'package:vps_tell_you/core/app_theme.dart';

class _MemorySsh extends SshService {
  @override
  SshStatus status = SshStatus.connected;
  @override
  int generation = 7;
  @override
  String? get error => null;
  @override
  SshTarget? get target => null;
  @override
  Stream<String> get output => const Stream.empty();
  final writes = <String>[];

  @override
  Future<void> connect(
    SshTarget target, {
    required HostVerifier verifyHost,
    KeyPassphraseRequester? requestKeyPassphrase,
  }) => throw UnsupportedError('The layout fixture never connects.');
  @override
  void write(String value) => writes.add(value);
  @override
  void resize(int columns, int rows) {}
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
  }) => throw UnsupportedError('The layout fixture never uses power.');
}

// Isolated layout review. The SSH object is an in-memory spy, every platform
// clipboard call is mocked, and this fixture never opens a database or keyring.
class _PanelFixture {
  _PanelFixture(String initialDraft)
    : draft = TextEditingController(text: initialDraft),
      service = _MemorySsh();

  final TextEditingController draft;
  final _MemorySsh service;
  final submissions = <(String, int, bool)>[];
  String clipboard = 'synthetic clipboard';
  String? pasteError;
  bool rejectSend = false;
  int clipboardReads = 0, snippetOpens = 0;

  Future<bool> send(String exact, int generation, bool appendEnter) async {
    submissions.add((exact, generation, appendEnter));
    if (rejectSend) return false;
    service.write(appendEnter ? '$exact\r' : exact);
    draft.clear();
    return true;
  }

  Future<String?> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (pasteError != null) return pasteError;
    final text = data?.text ?? '';
    final selection = draft.selection;
    final start = selection.isValid ? selection.start : draft.text.length;
    final end = selection.isValid ? selection.end : draft.text.length;
    draft.value = TextEditingValue(
      text: draft.text.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    return null;
  }
}

void main() {
  final evidence = Platform.environment['VPS_COMMAND_PANEL_EVIDENCE_DIR'];
  var fontsLoaded = false;
  const exact = '  echo 中文\nnext\r\t\x03\u202e  ';
  const fullTarget =
      'synthetic-review-account@[2001:db8:1234:5678:abcd:ef01:2345:6789]:22022';
  Finder keyed(String value) => find.byKey(ValueKey(value));

  Future<void> loadFonts(WidgetTester tester) async {
    if (fontsLoaded) return;
    await tester.runAsync(() async {
      final mono = FontLoader(terminalFontFamily);
      for (final name in ['DejaVuSansMono.ttf', 'DejaVuSansMono-Bold.ttf']) {
        mono.addFont(
          File('assets/fonts/$name').readAsBytes().then(ByteData.sublistView),
        );
      }
      await mono.load();
      final cjk = File(
        Platform.environment['VPS_TERMINAL_CJK_FONT'] ??
            '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
      );
      if (await cjk.exists()) {
        final bytes = ByteData.sublistView(await cjk.readAsBytes());
        for (final name in [
          'Roboto',
          'Noto Sans CJK SC',
          'Noto Sans Mono CJK SC',
        ]) {
          final loader = FontLoader(name)..addFont(Future.value(bytes));
          await loader.load();
        }
      } else if (evidence != null) {
        fail('Real CJK font is required for layout evidence.');
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
      } else if (evidence != null) {
        fail('Real MaterialIcons font is required for layout evidence.');
      }
      fontsLoaded = true;
    });
  }

  Future<_PanelFixture> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    String initialDraft = exact,
  }) async {
    final fixture = _PanelFixture(initialDraft);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        fixture.clipboardReads++;
        return <String, Object>{'text': fixture.clipboard};
      }
      return null;
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      fixture.draft.dispose();
      fixture.service.dispose();
    });
    await loadFonts(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(brightness: Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: const ValueKey('command-panel-review-evidence'),
            child: child,
          ),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open-review-panel'),
                onPressed: () => showModalBottomSheet<bool>(
                  context: context,
                  backgroundColor: TerminalScheme.defaultScheme.chrome,
                  clipBehavior: Clip.antiAlias,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => TerminalCommandSheet(
                    draft: fixture.draft,
                    service: fixture.service,
                    target: fullTarget,
                    insertSnippet: () async {
                      fixture.snippetOpens++;
                      fixture.draft.text = 'synthetic selected snippet';
                    },
                    replaceDraft: (text) async {
                      fixture.draft.text = text;
                      return true;
                    },
                    pasteDraft: fixture.paste,
                    sendDraft: fixture.send,
                  ),
                ),
                child: const Text('合成终端'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(keyed('open-review-panel'));
    await tester.pumpAndSettle();
    return fixture;
  }

  // Drag the outer gutter, so neither the multiline editor nor the nested
  // escaped preview can silently substitute for the sheet's own scrolling.
  Future<void> dragTo(WidgetTester tester, Finder target) async {
    for (var step = 0; step < 60; step++) {
      final viewport = tester.getRect(keyed('terminal-command-scroll'));
      final rect = tester.getRect(target);
      final fits = rect.top >= viewport.top && rect.bottom <= viewport.bottom;
      if (fits && target.hitTestable().evaluate().length == 1) return;
      final direction = rect.top < viewport.top ? 1.0 : -1.0;
      await tester.dragFrom(
        Offset(viewport.left + 6, viewport.center.dy),
        Offset(0, direction * viewport.height * .65),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    fail('The sheet did not make $target fully reachable by dragging.');
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (evidence == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      keyed('command-panel-review-evidence'),
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

  void expectLogicalOrder(WidgetTester tester) {
    final choices = tester.getRect(keyed('terminal-command-choices'));
    final snippets = tester.getRect(keyed('terminal-insert-snippet'));
    final editor = tester.getRect(keyed('terminal-draft'));
    final paste = tester.getRect(keyed('terminal-draft-paste'));
    final target = tester.getRect(keyed('terminal-send-target'));
    final warning = tester.getRect(keyed('draft-control-warning'));
    final preview = tester.getRect(keyed('draft-exact-preview'));
    final description = tester.getRect(
      find.text('“发送”不追加回车；“发送并执行”追加回车，由当前终端程序处理。'),
    );
    final send = tester.getRect(keyed('terminal-send'));
    final execute = tester.getRect(keyed('terminal-send-execute'));
    expect(choices.bottom, lessThanOrEqualTo(snippets.top));
    for (final command in terminalQuickCommands) {
      final chip = tester.getRect(keyed(command.id));
      expect(chip.top, greaterThanOrEqualTo(choices.bottom));
      expect(chip.bottom, lessThanOrEqualTo(snippets.top));
    }
    expect(snippets.bottom, lessThan(editor.top));
    expect(editor.bottom, lessThanOrEqualTo(paste.top));
    expect(paste.bottom, lessThanOrEqualTo(target.top));
    expect(target.bottom, lessThanOrEqualTo(warning.top));
    expect(warning.bottom, lessThanOrEqualTo(preview.top));
    expect(preview.bottom, lessThanOrEqualTo(description.top));
    expect(description.bottom, lessThan(send.top));
    expect(description.bottom, lessThan(execute.top));
    expect(
      tester.widget<SelectableText>(keyed('terminal-send-target')).data,
      fullTarget,
    );
    expect(
      tester.widget<SelectableText>(keyed('terminal-send-target')).maxLines,
      isNull,
    );
  }

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final scale in [1.0, 2.0]) {
      final name =
          '${size.width.toInt()}x${size.height.toInt()}-${scale.toInt()}x';
      testWidgets('panel review: real-font order and IME actions at $name', (
        tester,
      ) async {
        final fixture = await mount(tester, size: size, scale: scale);
        expectLogicalOrder(tester);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byType(ExpansionTile), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        expect(fixture.clipboardReads, 0);
        expect(fixture.service.writes, isEmpty);
        await capture(tester, 'choices-$name');

        await dragTo(tester, keyed('terminal-draft-paste'));
        await capture(tester, 'draft-$name');
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.width > size.height ? 180 : 300,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final action in ['terminal-send', 'terminal-send-execute']) {
          await dragTo(tester, keyed(action));
          final rect = tester.getRect(keyed(action));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(
            rect.bottom,
            lessThanOrEqualTo(size.height - tester.view.viewInsets.bottom),
          );
          expect(keyed(action).hitTestable(), findsOneWidget);
          await capture(tester, '$action-ime-$name');
        }
        expect(fixture.draft.text, exact);
        expect(fixture.service.writes, isEmpty);
        await tester.tap(keyed('terminal-send-execute'));
        await tester.pumpAndSettle();
        expect(fixture.submissions, [(exact, 7, true)]);
        expect(fixture.service.writes, ['$exact\r']);
        expect(find.byType(TerminalCommandSheet), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('panel review: choices and adjacent paste only edit the draft', (
    tester,
  ) async {
    final fixture = await mount(tester, initialDraft: '');
    await capture(tester, 'normal-empty-390x844-1x');
    await tester.tap(keyed('builtin-pwd'));
    await tester.pumpAndSettle();
    expect(fixture.draft.text, 'pwd');
    await capture(tester, 'normal-pwd-390x844-1x');
    await tester.tap(keyed('terminal-insert-snippet'));
    await tester.pumpAndSettle();
    expect(fixture.snippetOpens, 1);
    expect(fixture.draft.text, 'synthetic selected snippet');
    await dragTo(tester, keyed('terminal-draft-paste'));
    fixture.draft.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 9,
    );
    fixture.clipboard = '  中文\n';
    await tester.pumpAndSettle();
    await tester.tap(keyed('terminal-draft-paste'));
    await tester.pumpAndSettle();
    expect(fixture.clipboardReads, 1);
    expect(fixture.draft.text, '  中文\n selected snippet');
    expect(fixture.service.writes, isEmpty);
    await tester.enterText(keyed('terminal-draft'), '  edited 中文\n  ');
    await tester.pumpAndSettle();
    await dragTo(tester, keyed('terminal-send'));
    await tester.tap(keyed('terminal-send'));
    await tester.pumpAndSettle();
    expect(fixture.submissions, [('  edited 中文\n  ', 7, false)]);
    expect(fixture.service.writes, ['  edited 中文\n  ']);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'panel review: failed send remains editable and errors precede actions',
    (tester) async {
      final fixture = await mount(tester, size: const Size(320, 568), scale: 2);
      fixture.rejectSend = true;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await dragTo(tester, keyed('terminal-send'));
      await tester.tap(keyed('terminal-send'));
      await tester.pumpAndSettle();
      expect(fixture.submissions, [(exact, 7, false)]);
      expect(fixture.draft.text, exact);
      expect(fixture.service.writes, isEmpty);
      expect(keyed('terminal-draft-error'), findsOneWidget);
      expect(
        tester.getRect(keyed('terminal-draft-error')).bottom,
        lessThan(tester.getRect(keyed('terminal-send')).top),
      );
      expect(tester.widget<TextField>(keyed('terminal-draft')).enabled, isTrue);
      await dragTo(tester, keyed('terminal-send-execute'));
      await capture(tester, 'failed-send-ime-320x568-2x');
      await tester.pump(const Duration(seconds: 10));
      expect(fixture.submissions.length, 1);
      await tester.tap(keyed('terminal-commands-close'));
      await tester.pumpAndSettle();
      expect(fixture.draft.text, exact);
      expect(find.byType(TerminalCommandSheet), findsNothing);
    },
  );
}
