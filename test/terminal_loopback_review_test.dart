import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/connections/ssh_service.dart';
import 'package:vps_tell_you/connections/terminal_page.dart';
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
    'review: mobile text client crosses loopback SSH and resizes actual PTY',
    (tester) async {
      // This fixture only echoes bytes, rejects every exec request and binds
      // 127.0.0.1. Its credentials and trust identity are synthetic test data.
      late Directory directory;
      late LedgerStore store;
      late LedgerController ledger;
      late NativeSshService ssh;
      late SshFixture remote;
      late SshTarget target;
      var mounted = false;

      await tester.runAsync(() async {
        sqfliteFfiInit();
        directory = await Directory.systemTemp.createTemp('terminal-loopback-');
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
            name: 'Synthetic widget loopback',
            kind: CredentialKind.password,
            defaultUsername: 'fixture',
            secret: 'synthetic-password-only',
          ),
          isTrue,
        );
        // Independently obtained from the fixture control channel, not from
        // the SSH wire or a permissive runtime host-verification callback.
        expect(await ledger.security.verifyHost(remote.identity), isTrue);
        target = SshTarget(
          name: 'Synthetic loopback terminal',
          host: '127.0.0.1',
          port: remote.port,
          username: 'fixture',
          credentialId: ledger.security.credentials.single.id,
        );
        ssh = NativeSshService(security: ledger.security);
        await ssh.connect(
          target,
          verifyHost: (_) async =>
              fail('The independently verified fixture key must be pinned'),
        );
        expect(ssh.connected, isTrue, reason: ssh.error);
      });

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
        final initialRows = terminal.viewHeight;
        await tester.tap(find.byKey(const ValueKey('terminal-keyboard')));
        await tester.pumpAndSettle();
        expect(tester.testTextInput.hasAnyClients, isTrue);
        const content = 'widget-你好';
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '  $content',
            selection: TextSelection.collapsed(offset: 11),
          ),
        );
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        await tester.runAsync(() async {
          await eventually(() {
            final received = utf8.decode(
              remote.of('input').expand((event) {
                return base64Decode(event['data'] as String);
              }).toList(),
              allowMalformed: true,
            );
            return received == '$content\r';
          });
          await eventually(
            () => terminal.buffer.getText().contains('echo:$content'),
          );
        });
        expect(remote.of('exec_rejected'), isEmpty);

        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(terminal.viewHeight, lessThan(initialRows));
        await tester.runAsync(
          () => remote.waitFor(
            'resize',
            where: (event) =>
                event['columns'] == terminal.viewWidth &&
                event['rows'] == terminal.viewHeight,
          ),
        );
        final receivedBeforeDraft = remote.of('input').length;
        await tester.tap(find.byKey(const ValueKey('terminal-commands')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('builtin-pwd')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('terminal-draft')))
              .controller!
              .text,
          'pwd',
        );
        expect(remote.of('input').length, receivedBeforeDraft);
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
