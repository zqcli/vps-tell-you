import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/connections/connection_pages.dart';
import 'package:vps_tell_you/connections/power_action.dart';
import 'package:vps_tell_you/connections/snippet.dart';
import 'package:vps_tell_you/connections/snippet_pages.dart';
import 'package:vps_tell_you/connections/ssh_service.dart';
import 'package:vps_tell_you/connections/tcp_test.dart';
import 'package:vps_tell_you/connections/tcp_test_page.dart';
import 'package:vps_tell_you/connections/terminal_page.dart';
import 'package:vps_tell_you/connections/terminal_widgets.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';
import 'package:vps_tell_you/l10n/localized_message.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';

import 'security_store_test.dart' show FakeDeviceAuth, FakeSecretStore;
import 'support/reminder_platform.dart';
import 'terminal_widget_test.dart' show SpySshService;

void main() {
  final evidence = Platform.environment['VPS_CONNECTION_I18N_EVIDENCE_DIR'];
  var fontsLoaded = false;

  final en = AppLocalizationsEn(), zh = AppLocalizationsZh();
  test(
    'built-in command names translate without changing IDs or exact bytes',
    () {
      final english = terminalQuickCommandsFor(en),
          chinese = terminalQuickCommandsFor(zh);
      expect(english.map((c) => c.id), chinese.map((c) => c.id));
      expect(english.map((c) => c.content), [
        'pwd',
        'ls -lah',
        'uptime',
        'df -h',
        'free -h',
      ]);
      expect(chinese.map((c) => c.content), english.map((c) => c.content));
      expect(english.first.name, 'Current directory');
      expect(chinese.first.name, '当前目录');
    },
  );
  test(
    'TCP outcomes and safe errors translate without changing raw targets',
    () {
      final target = TcpTarget(host: '[2001:db8::1]', port: 22);
      final result = TcpTestResult(
        target: target,
        outcome: TcpOutcome.timedOut,
        finishedAt: DateTime.utc(2026),
        elapsed: const Duration(seconds: 1),
      );
      expect(result.labelFor(en), 'Connection timed out');
      expect(result.labelFor(zh), '连接超时');
      expect(target.label, '[2001:db8::1]:22');
      expect(result.sourceFor(en), contains('this device'));
      try {
        TcpTarget(host: 'https://invalid.example', port: 22);
        fail('Expected validation');
      } on LocalizedArgumentError catch (error) {
        expect(error.messageFor(en), contains('without a protocol'));
        expect(error.messageFor(zh), contains('不含协议'));
      }
      expect(
        const CommandSnippet(
          id: 'test',
          name: '',
          content: '',
        ).validate(l10n: en),
        contains('1–80'),
      );
    },
  );

  group('localized connection views', () {
    late Directory directory;
    late LedgerStore store;
    late LedgerController ledger;
    late SpySshService ssh;
    late ValueNotifier<Locale> locale;
    const target = SshTarget(
      name: '用户目标 Original',
      host: '192.0.2.10',
      username: 'fixture',
      credentialId: 'synthetic',
    );
    setUp(() async {
      sqfliteFfiInit();
      directory = await Directory.systemTemp.createTemp('connection-l10n-');
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${directory.path}/ledger.db',
      );
      ledger = LedgerController(
        store,
        security: SecurityController(
          store: store,
          secrets: FakeSecretStore(),
          authenticator: FakeDeviceAuth(),
        ),
        reminderPlatform: FakeReminderPlatform()..supported = false,
      );
      await ledger.refresh();
      ssh = SpySshService();
      locale = ValueNotifier(const Locale('en'));
    });
    tearDown(() async {
      locale.dispose();
      ledger.dispose();
      await store.close();
      await directory.delete(recursive: true);
    });
    Future<void> mount(
      WidgetTester tester,
      Widget page, {
      double scale = 1,
      Size size = const Size(390, 844),
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      if (evidence != null && !fontsLoaded) {
        await tester.runAsync(() async {
          final bytes = await File(
            Platform.environment['VPS_I18N_FONT'] ??
                'assets/fonts/DejaVuSansMono.ttf',
          ).readAsBytes();
          for (final name in [
            'Roboto',
            'Noto Sans CJK SC',
            'Noto Sans Mono CJK SC',
          ]) {
            final font = FontLoader(name)
              ..addFont(Future.value(ByteData.sublistView(bytes)));
            await font.load();
          }
          final mono = FontLoader('TerminalDejaVu');
          for (final name in [
            'DejaVuSansMono.ttf',
            'DejaVuSansMono-Bold.ttf',
          ]) {
            mono.addFont(
              File('assets/fonts/$name')
                  .readAsBytes()
                  .then(ByteData.sublistView),
            );
          }
          await mono.load();
          if (Platform.environment['FLUTTER_BOOTSTRAP_ROOT'] case final sdk?) {
            final icons = FontLoader('MaterialIcons')
              ..addFont(
                File(
                  '$sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
                ).readAsBytes().then(ByteData.sublistView),
              );
            await icons.load();
          }
          fontsLoaded = true;
        });
      }
      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (_, current, child) => MaterialApp(
            theme: appTheme(),
            locale: current,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(
                key: const ValueKey('connection-l10n-evidence'),
                child: child!,
              ),
            ),
            home: page,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(WidgetTester tester, String name) async {
      if (evidence == null) return;
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('connection-l10n-evidence')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$evidence/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> change(WidgetTester tester, String language) async {
      locale.value = Locale(language);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> scan(WidgetTester tester) async {
      for (var i = 0; i < 100; i++) {
        final scrolling = tester
            .stateList<ScrollableState>(find.byType(Scrollable))
            .where(
              (s) =>
                  s.position.axis == Axis.vertical &&
                  s.position.extentAfter > 1,
            )
            .toList();
        if (scrolling.isEmpty) return;
        final position = scrolling.first.position;
        position.jumpTo(
          (position.pixels + 240).clamp(0, position.maxScrollExtent),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      fail('Did not visit all scrollable content');
    }

    testWidgets(
      'locale switch preserves SSH service, session generation, and unsent exact bytes',
      (tester) async {
        await mount(
          tester,
          TerminalPage(
            ledger: ledger,
            target: target,
            initialDraft: 'printf "raw 用户 text"',
            connectOnOpen: true,
            serviceFactory: (_) => ssh,
          ),
        );
        final generation = ssh.generation;
        await tester.tap(find.byKey(const ValueKey('terminal-commands')));
        await tester.pumpAndSettle();
        final draft = tester
            .widget<TextField>(find.byKey(const ValueKey('terminal-draft')))
            .controller!;
        final oldController = draft;
        final before = List<String>.of(ssh.writes);
        await change(tester, 'zh');
        expect(ssh.connections, 1);
        expect(ssh.authentications, 1);
        expect(ssh.disconnections, 0);
        expect(ssh.generation, generation);
        expect(ssh.writes, before);
        expect(
          identical(
            tester
                .widget<TextField>(find.byKey(const ValueKey('terminal-draft')))
                .controller,
            oldController,
          ),
          isTrue,
        );
        expect(draft.text, 'printf "raw 用户 text"');
        expect(find.text('发送'), findsOneWidget);
        expect(find.text('发送并执行'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('terminal-send')));
        await tester.pumpAndSettle();
        expect(ssh.writes, ['printf "raw 用户 text"']);
        await tester.tap(find.byKey(const ValueKey('terminal-commands')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('terminal-draft')),
          'echo second',
        );
        await change(tester, 'en');
        expect(find.text('Send and execute'), findsOneWidget);
        expect(ssh.writes, ['printf "raw 用户 text"']);
        expect(ssh.powers, isEmpty);
        await tester.tap(find.byKey(const ValueKey('terminal-send-execute')));
        await tester.pumpAndSettle();
        expect(ssh.writes, ['printf "raw 用户 text"', 'echo second\r']);
        expect(ssh.connections, 1);
        expect(ssh.authentications, 1);
        expect(ssh.disconnections, 0);
        expect(ssh.generation, generation);
        expect(ssh.powers, isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      'power confirmation translates in place and keeps exact target without sending',
      (tester) async {
        ssh.target = target;
        ssh.status = SshStatus.connected;
        ssh.generation = 7;
        await mount(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => unawaited(
                  confirmSshPower(
                    context,
                    service: ssh,
                    action: SshPowerAction.shutdown,
                  ),
                ),
                child: const Text('Open power'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open power'));
        await tester.pumpAndSettle();
        expect(find.text('Shut down (1/2)'), findsOneWidget);
        await change(tester, 'zh');
        expect(find.text('关机影响确认（1/2）'), findsOneWidget);
        expect(ssh.powers, isEmpty);
        await tester.tap(find.text('了解影响，继续核对'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('power-confirm-target')),
          target.label.substring(0, 5),
        );
        await change(tester, 'en');
        expect(find.text('Shut down (2/2)'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('power-confirm-target')),
              )
              .controller!
              .text,
          target.label.substring(0, 5),
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('power-confirm-submit')),
              )
              .onPressed,
          isNull,
        );
        expect(ssh.powers, isEmpty);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      },
    );
    testWidgets('TCP invalid draft retranslates without opening a socket', (
      tester,
    ) async {
      var requests = 0;
      final tcp = TcpTestController(
        connector: (host, port) {
          requests++;
          throw StateError('No network permitted');
        },
      );
      await mount(tester, TcpTestPage(controller: tcp));
      await tester.enterText(
        find.byKey(const Key('tcp-host')),
        'https://invalid.example',
      );
      await tester.tap(find.text('Start test'));
      await tester.pumpAndSettle();
      expect(find.text(en.tcpValidHost), findsOneWidget);
      await change(tester, 'zh');
      expect(find.text(zh.tcpValidHost), findsOneWidget);
      expect(find.text('https://invalid.example'), findsOneWidget);
      expect(requests, 0);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets(
      'English power confirmations remain reachable at 320px 2x without executing',
      (tester) async {
        ssh.target = target;
        ssh.status = SshStatus.connected;
        ssh.generation = 9;
        await mount(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => unawaited(
                  confirmSshPower(
                    context,
                    service: ssh,
                    action: SshPowerAction.shutdown,
                  ),
                ),
                child: const Text('Open power'),
              ),
            ),
          ),
          scale: 2,
          size: const Size(320, 568),
        );
        await tester.tap(find.text('Open power'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(tester, 'en-power-impact-320x2');
        final next = find.text(en.powerUnderstandContinue);
        await tester.ensureVisible(next);
        await tester.pumpAndSettle();
        expect(next.hitTestable(), findsOneWidget);
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('power-confirm-submit')),
              )
              .onPressed,
          isNull,
        );
        await capture(tester, 'en-power-target-320x2');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(ssh.powers, isEmpty);
        expect(ssh.writes, isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );

    for (final size in [const Size(320, 844), const Size(844, 320)]) {
      for (final language in ['zh', 'en']) {
        testWidgets(
          '$language terminal and command panel at ${size.width}x${size.height} 2x',
          (tester) async {
            locale.value = Locale(language);
            await mount(
              tester,
              TerminalPage(
                ledger: ledger,
                target: target,
                initialDraft: 'echo safe synthetic draft',
                connectOnOpen: true,
                serviceFactory: (_) => ssh,
              ),
              size: size,
              scale: 2,
            );
            expect(tester.takeException(), isNull);
            await tester.tap(find.byKey(const ValueKey('terminal-commands')));
            await tester.pumpAndSettle();
            await scan(tester);
            await capture(
              tester,
              '$language-commands-${size.width.toInt()}x${size.height.toInt()}-2x',
            );
            expect(ssh.writes, isEmpty);
            await change(tester, language == 'en' ? 'zh' : 'en');
            await scan(tester);
            expect(ssh.connections, 1);
            expect(ssh.writes, isEmpty);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
    for (final entry in <String, Widget Function()>{
      'SSH connect': () => SshConnectPage(ledger: ledger),
      'TCP test': () => const TcpTestPage(),
      'snippet list': () => SnippetListPage(store: store),
      'snippet editor': () => SnippetEditorPage(store: store),
    }.entries) {
      testWidgets('English ${entry.key} at 320px 2x', (tester) async {
        await mount(
          tester,
          entry.value(),
          size: const Size(320, 844),
          scale: 2,
        );
        await scan(tester);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });
}
