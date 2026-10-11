import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/connections/ssh_service.dart';
import 'package:vps_tell_you/connections/terminal_highlighter.dart';
import 'package:vps_tell_you/connections/terminal_page.dart';
import 'package:vps_tell_you/connections/terminal_widgets.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:xterm/xterm.dart';

import 'security_store_test.dart' show FakeDeviceAuth, FakeSecretStore;
import 'support/ssh_fixture.dart';
import 'terminal_widget_test.dart' show SpySshService;

/// Foreground words of every cell, row by row, for before/after comparisons.
List<List<int>> foregrounds(Terminal t) => [
  for (var r = 0; r < t.buffer.height; r++)
    [
      for (var c = 0; c < t.buffer.lines[r].length; c++)
        t.buffer.lines[r].getForeground(c),
    ],
];

bool hasOurs(Terminal t) =>
    foregrounds(t)
        .any((row) => row.any((v) => v & TerminalHighlighter.oursFlag != 0));

void main() {
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late SpySshService ssh;
  final zh = AppLocalizationsZh();
  const target = SshTarget(
    name: 'Synthetic target',
    host: '127.0.0.1',
    username: 'fixture',
    port: 22022,
    credentialId: 'fixture-only',
  );

  setUp(() async {
    terminalSmartHighlight.value = true;
    terminalSchemeChoice.value = TerminalScheme.defaultScheme;
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('vps-highlight-ui-');
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
    terminalSmartHighlight.value = true;
    terminalSchemeChoice.value = TerminalScheme.defaultScheme;
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  testWidgets('plain output is highlighted live; toggle and scheme are pure '
      'repaints: no bytes written, text and cells identical', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: TerminalPage(
          ledger: ledger,
          target: target,
          connectOnOpen: true,
          serviceFactory: (_) => ssh,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final terminal = tester
        .widget<TerminalView>(find.byType(TerminalView))
        .terminal;
    const output =
        'root@hk:~# ls\r\nerror 10.0.0.1 12%\r\n'
        '\x1b[31mred 10.0.0.2\x1b[0m\r\n';
    ssh.events.add(output);
    await tester.pump(const Duration(milliseconds: 100));
    final plain = Terminal(maxLines: 3000)
      ..resize(terminal.viewWidth, terminal.viewHeight)
      ..write(output);
    expect(terminal.buffer.getText(), plain.buffer.getText());
    expect(hasOurs(terminal), isTrue);
    final row = terminal.buffer.scrollBack + 1;
    int fg(int r, int c) => terminal.buffer.lines[r].getForeground(c);
    expect(fg(row, 0) & TerminalHighlighter.oursFlag, isNonZero); // error
    expect(fg(row, 6) & TerminalHighlighter.oursFlag, isNonZero); // 10.0.0.1
    // remote colour on the next row is left alone
    expect(fg(row + 1, 0), CellColor.named | 1);
    final coloured = foregrounds(terminal);

    Future<void> toggle() async {
      await tester.tap(find.byTooltip(zh.terminalMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.text(zh.r3TermColorScheme));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('terminal-smart-highlight')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app-sheet-close')));
      await tester.pumpAndSettle();
    }

    await toggle();
    expect(terminalSmartHighlight.value, isFalse);
    expect(hasOurs(terminal), isFalse);
    expect(terminal.buffer.getText(), plain.buffer.getText());
    // off == what the remote sent, cell for cell
    expect(foregrounds(terminal), foregrounds(plain));
    ssh.events.add('fresh error 10.9.9.9\r\n');
    await tester.pump(const Duration(milliseconds: 100));
    expect(hasOurs(terminal), isFalse, reason: 'stays off for new output');

    await toggle();
    expect(terminalSmartHighlight.value, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(hasOurs(terminal), isTrue);
    final again = foregrounds(terminal);

    // A scheme change only swaps the palette: cell data does not change.
    await tester.tap(find.byTooltip(zh.terminalMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.r3TermColorScheme));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('terminal-scheme-dracula')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    expect(foregrounds(terminal), again);
    expect(
      tester.widget<TerminalView>(find.byType(TerminalView)).theme,
      dracula.theme,
    );

    expect(coloured, isNotEmpty);
    expect(ssh.writes, isEmpty, reason: 'highlighting never sends bytes');
    expect(ssh.connections, 1);
    expect(ssh.disconnections, 0);
  });

  testWidgets('loopback SSH: typed bytes arrive unchanged, echoed output is '
      'highlighted, text is identical', (tester) async {
    late LedgerStore lstore;
    late LedgerController lledger;
    late NativeSshService real;
    late SshFixture remote;
    late SshTarget loopTarget;
    late Directory dir;
    var mounted = false;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('highlight-loopback-');
      lstore = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${dir.path}/ledger.sqlite3',
      );
      lledger = LedgerController(
        lstore,
        security: SecurityController(
          store: lstore,
          secrets: FakeSecretStore(),
          authenticator: FakeDeviceAuth(),
        ),
      );
      await lledger.refresh();
      remote = await SshFixture.start();
      expect(
        await lledger.security.saveCredential(
          name: 'Synthetic highlight loopback',
          kind: CredentialKind.password,
          defaultUsername: 'fixture',
          secret: 'synthetic-password-only',
        ),
        isTrue,
      );
      expect(await lledger.security.verifyHost(remote.identity), isTrue);
      loopTarget = SshTarget(
        name: 'Synthetic loopback',
        host: '127.0.0.1',
        port: remote.port,
        username: 'fixture',
        credentialId: lledger.security.credentials.single.id,
      );
      real = NativeSshService(security: lledger.security);
      await real.connect(
        loopTarget,
        verifyHost: (_) async => fail('fixture key must be pinned'),
      );
      expect(real.connected, isTrue, reason: real.error);
    });
    try {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: TerminalPage(
            ledger: lledger,
            target: loopTarget,
            serviceFactory: (_) => real,
          ),
        ),
      );
      mounted = true;
      await tester.pumpAndSettle();
      final terminal = tester
          .widget<TerminalView>(find.byType(TerminalView))
          .terminal;
      await tester.tap(find.byKey(const ValueKey('terminal-keyboard')));
      await tester.pumpAndSettle();
      const typed = 'error 10.0.0.1 /etc/hosts';
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '  $typed',
          selection: TextSelection.collapsed(offset: 2 + typed.length),
        ),
      );
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.runAsync(() async {
        await eventually(() {
          final received = utf8.decode(
            remote
                .of('input')
                .expand((e) => base64Decode(e['data'] as String))
                .toList(),
            allowMalformed: true,
          );
          return received == '$typed\r';
        });
        await eventually(() => terminal.buffer.getText().contains('echo:'));
      });
      await tester.pump(const Duration(milliseconds: 100));
      // Exactly the typed text plus Enter reached the server: nothing from us.
      final sent = utf8.decode(
        remote
            .of('input')
            .expand((e) => base64Decode(e['data'] as String))
            .toList(),
      );
      expect(sent, '$typed\r');
      expect(terminal.buffer.getText(), contains('echo:$typed'));
      final line = [
        for (var r = 0; r < terminal.buffer.height; r++)
          terminal.buffer.lines[r],
      ].firstWhere((l) => l.getText().startsWith('echo:'));
      expect(
        line.getText(),
        startsWith('echo:error 10.0.0.1'),
        reason: 'text identical',
      );
      // "echo:error" is one word; the address starts at cell 11, the path at 20.
      for (final col in [11, 20]) {
        expect(
          line.getForeground(col) & TerminalHighlighter.oursFlag,
          isNonZero,
          reason: 'cell $col',
        );
      }
      expect(line.getForeground(0), 0);
      expect(remote.of('exec_rejected'), isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      if (mounted) {
        await tester.pumpWidget(const SizedBox.shrink());
      } else {
        real.dispose();
      }
      await tester.runAsync(() async {
        await remote.close();
        lledger.dispose();
        await lstore.close();
        await dir.delete(recursive: true);
      });
    }
  });
}
