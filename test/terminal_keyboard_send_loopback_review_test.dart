import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/connections/ssh_service.dart';
import 'package:vps_tell_you/connections/terminal_page.dart';
import 'package:vps_tell_you/connections/terminal_widgets.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:xterm/xterm.dart';

import 'security_store_test.dart' show FakeDeviceAuth, FakeSecretStore;
import 'support/ssh_fixture.dart';

void main() {
  testWidgets(
    'review: inline buttons and clipboard cross real loopback SSH as exact bytes',
    (tester) async {
      // This fixture binds loopback only, never launches an OS shell, and
      // rejects exec requests. All credentials and host keys are synthetic.
      late Directory directory;
      late LedgerStore store;
      late LedgerController ledger;
      late NativeSshService ssh;
      late SshFixture remote;
      late SshTarget target;
      var mounted = false;
      const pasted = 'paste-你好\\path\nnext\r\t\x03';
      const executed = 'execute-synthetic\r';
      var clipboardReads = 0;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') {
          clipboardReads++;
          return {'text': pasted};
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.runAsync(() async {
        sqfliteFfiInit();
        directory = await Directory.systemTemp.createTemp('keyboard-send-pty-');
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
        remote = await SshFixture.start();
        expect(
          await ledger.security.saveCredential(
            name: 'Synthetic keyboard send loopback',
            kind: CredentialKind.password,
            defaultUsername: 'fixture',
            secret: 'synthetic-password-only',
          ),
          isTrue,
        );
        // Trust is obtained through the independent fixture control channel,
        // never by accepting the key observed from the connection under test.
        expect(await ledger.security.verifyHost(remote.identity), isTrue);
        target = SshTarget(
          name: 'Synthetic inline send PTY',
          host: '127.0.0.1',
          port: remote.port,
          username: 'fixture',
          credentialId: ledger.security.credentials.single.id,
        );
        ssh = NativeSshService(security: ledger.security);
        await ssh.connect(
          target,
          verifyHost: (_) async =>
              fail('Fixture host identity is already pinned'),
        );
        expect(ssh.connected, isTrue, reason: ssh.error);
      });

      Finder keyed(String key) => find.byKey(ValueKey(key));
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      List<int> receivedBytes() => remote.of('input').expand((event) {
        return base64Decode(event['data'] as String);
      }).toList();
      Future<void> expectReceived(String expected) async {
        await tester.runAsync(() async {
          await eventually(
            () => listEquals(receivedBytes(), utf8.encode(expected)),
          );
        });
        expect(receivedBytes(), utf8.encode(expected));
        expect(remote.of('exec_rejected'), isEmpty);
      }

      try {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(),
            home: TerminalPage(
              ledger: ledger,
              target: target,
              serviceFactory: (_) => ssh,
            ),
          ),
        );
        mounted = true;
        await tester.pumpAndSettle();
        final terminal = tester
            .widget<TerminalView>(find.byType(TerminalView))
            .terminal;
        await tester.runAsync(
          () => remote.waitFor(
            'resize',
            where: (event) =>
                event['columns'] == terminal.viewWidth &&
                event['rows'] == terminal.viewHeight,
          ),
        );
        expect(clipboardReads, 0);
        expect(receivedBytes(), isEmpty);

        await tap(keyed('terminal-paste'));
        expect(clipboardReads, 1);
        expect(find.byType(TerminalCommandSheet), findsOneWidget);
        expect(
          tester.widget<TextField>(keyed('terminal-draft')).controller!.text,
          pasted,
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        expect(
          receivedBytes(),
          isEmpty,
          reason: 'Pasting only edits a local draft.',
        );
        await tap(keyed('terminal-send'));
        expect(find.byType(AlertDialog), findsNothing);
        await expectReceived(pasted);

        await tap(keyed('terminal-commands'));
        await tester.ensureVisible(keyed('terminal-draft'));
        await tester.enterText(keyed('terminal-draft'), executed);
        await tester.pumpAndSettle();
        final execute = tester
            .widget<ButtonStyleButton>(keyed('terminal-send-execute'))
            .onPressed!;
        final send = tester
            .widget<ButtonStyleButton>(keyed('terminal-send'))
            .onPressed!;
        execute();
        send();
        execute();
        await tester.pumpAndSettle();
        await expectReceived('$pasted$executed\r');

        final originalRows = terminal.viewHeight;
        await tap(keyed('terminal-keyboard'));
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(terminal.viewHeight, lessThan(originalRows));
        await tester.runAsync(
          () => remote.waitFor(
            'resize',
            where: (event) =>
                event['columns'] == terminal.viewWidth &&
                event['rows'] == terminal.viewHeight,
          ),
        );
        var view = tester.state<TerminalViewState>(find.byType(TerminalView));
        expect(
          view.globalCursorRect.bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(TerminalView)).bottom),
        );

        tester.view.physicalSize = const Size(844, 390);
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => remote.waitFor(
            'resize',
            where: (event) =>
                event['columns'] == terminal.viewWidth &&
                event['rows'] == terminal.viewHeight,
          ),
        );
        view = tester.state<TerminalViewState>(find.byType(TerminalView));
        expect(identical(view.widget.terminal, terminal), isTrue);
        expect(
          view.globalCursorRect.bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(TerminalView)).bottom),
        );
        expect(receivedBytes(), utf8.encode('$pasted$executed\r'));
        expect(remote.of('exec_rejected'), isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        if (mounted) {
          await tester.pumpWidget(const SizedBox.shrink());
        } else {
          ssh.dispose();
        }
        await tester.runAsync(() async {
          await remote.close();
          ledger.dispose();
          await store.close();
          await directory.delete(recursive: true);
        });
      }
    },
  );
}
