import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/connections/connection_pages.dart';
import 'package:vps_tell_you/connections/error_details.dart';
import 'package:vps_tell_you/connections/error_details_ui.dart';
import 'package:vps_tell_you/connections/sftp_connect_page.dart';
import 'package:vps_tell_you/connections/sftp_session.dart';
import 'package:vps_tell_you/connections/ssh_service.dart';
import 'package:vps_tell_you/connections/tcp_test.dart';
import 'package:vps_tell_you/connections/tcp_test_page.dart';
import 'package:vps_tell_you/connections/terminal_page.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';
import 'package:vps_tell_you/l10n/localized_message.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'security_store_test.dart' show FakeDeviceAuth, FakeSecretStore;
import 'support/reminder_platform.dart';
import 'terminal_widget_test.dart' show SpySshService;

/// A fake service whose failure carries the original error.
class _DetailedSsh extends SpySshService {
  ErrorDetails? details;
  @override
  ErrorDetails? get errorDetails => details;

  /// [connectSftp] fails like the real service does.
  @override
  Future<SftpSession> connectSftp(
    SshTarget requested, {
    required HostVerifier verifyHost,
    KeyPassphraseRequester? requestKeyPassphrase,
  }) async {
    target = requested;
    throw SecurityFailure(LocalizedText((l10n) => l10n.r3SftpUnavailable));
  }
}

void main() {
  final en = AppLocalizationsEn(), zh = AppLocalizationsZh();

  group('redaction', () {
    const pem =
        '-----BEGIN OPENSSH PRIVATE KEY-----\n'
        'b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW\n'
        'QyNTUxOQAAACD0Zk2m9Y1r3m0m2Zn8m1Z0o2n3m4p5q6r7s8t9u0v1wAAAAIj\n'
        '-----END OPENSSH PRIVATE KEY-----';
    test('PEM blocks, whole and truncated', () {
      final out = redactSecrets('failed to parse:\n$pem\nrest');
      expect(out, 'failed to parse:\n[REDACTED PEM]\nrest');
      expect(
        redactSecrets('x -----BEGIN RSA PRIVATE KEY-----\nMIIEow'),
        'x [REDACTED PEM]',
      );
    });

    test('known secrets, longest first; short ones only as whole tokens', () {
      expect(
        redactSecrets(
          'bad hunter2hunter2 and hunter2',
          secrets: ['hunter2', 'hunter2hunter2', ''],
        ),
        'bad [REDACTED] and [REDACTED]',
      );
      expect(
        redactSecrets('abc ab cab', secrets: ['ab']),
        'abc [REDACTED] cab',
      );
    });

    test('Authorization and Proxy-Authorization values', () {
      expect(
        redactSecrets(
          'CONNECT x HTTP/1.1\r\nProxy-Authorization: Basic dTpw\r\nHost: x',
        ),
        'CONNECT x HTTP/1.1\r\nProxy-Authorization: [REDACTED]\r\nHost: x',
      );
      expect(
        redactSecrets('sent authorization: Bearer abc.def and more'),
        'sent authorization: [REDACTED]',
      );
    });

    test('credentials in URLs and key=value pairs', () {
      expect(
        redactSecrets('GET https://alice:s3cret@proxy.example:8080/x'),
        'GET https://[REDACTED]@proxy.example:8080/x',
      );
      expect(
        redactSecrets('socks5://bob@h failed; password=abc123, user=bob'),
        'socks5://[REDACTED]@h failed; password=[REDACTED], user=bob',
      );
      expect(
        redactSecrets('passphrase = "a b c" next'),
        'passphrase = [REDACTED] next',
      );
    });

    test('key bodies that escaped a PEM frame, and FormatException source', () {
      final body = 'A' * 64;
      expect(redactSecrets('x $body y'), 'x [REDACTED BASE64] y');
      expect(
        describeError(const FormatException('Invalid key', 'SECRETSOURCE', 3)),
        'FormatException: Invalid key',
      );
    });

    test('ordinary diagnostics survive untouched', () {
      const text =
          'SocketException: Connection refused (OS Error: Connection '
          'refused, errno = 61), address = 203.0.113.10, port = 22';
      expect(redactSecrets(text), text);
      const fingerprint = 'SHA256:XhNqca+sae/S3LbmMGJ/fEKdHddx3NlGKid1sOszhP8';
      expect(redactSecrets(fingerprint), fingerprint);
    });

    test('ErrorDetails redacts on construction and in the report', () {
      final d = ErrorDetails(
        stage: ErrorStage.proxy,
        technical: 'Proxy-Authorization: Basic Zm9v\nbad hunter22',
        secrets: ['hunter22'],
        proxy: 'Office · SOCKS5 10.0.0.1:1080',
        target: 'root@[2001:db8::1]:22',
        time: DateTime.utc(2026, 10, 17, 1, 2, 3),
      );
      final report = d.report(en);
      expect(d.technical, isNot(contains('Zm9v')));
      expect(report, isNot(contains('hunter22')));
      expect(report, startsWith('Error Details\nWhat failed: Proxy\n'));
      expect(report, contains('Target: root@[2001:db8::1]:22'));
      expect(report, contains('Proxy: Office · SOCKS5 10.0.0.1:1080'));
      expect(d.report(zh), contains('失败环节: 代理'));
    });
  });

  group('widgets', () {
    late Directory directory;
    late LedgerStore store;
    late LedgerController ledger;
    String? clipboard;

    final details = ErrorDetails(
      stage: ErrorStage.connect,
      technical:
          'SocketException: Connection refused (OS Error: Connection '
          'refused, errno = 61), address = 203.0.113.10, port = 22',
      target: 'root@203.0.113.10:22',
      time: DateTime(2026, 10, 17, 9, 30, 5),
    );

    setUp(() async {
      sqfliteFfiInit();
      directory = await Directory.systemTemp.createTemp('error-details-ui-');
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
      clipboard = null;
    });
    tearDown(() async {
      ledger.dispose();
      await store.close();
      await directory.delete(recursive: true);
    });

    Future<void> mount(
      WidgetTester tester,
      Widget home, {
      String locale = 'en',
      double width = 390,
      double scale = 1,
    }) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = Size(width * 2, 1688);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
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
          home: home,
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder button() => find.byKey(const ValueKey('error-details-button'));

    testWidgets('the banner shows the headline and a 44 pt ⓘ with a label', (
      tester,
    ) async {
      await mount(
        tester,
        Scaffold(
          body: ErrorBanner(
            text: 'Connection could not be completed.',
            details: details,
          ),
        ),
      );
      expect(find.text('Connection could not be completed.'), findsOneWidget);
      expect(button(), findsOneWidget);
      final box = tester.getSize(
        find.descendant(of: button(), matching: find.byType(SizedBox)).first,
      );
      expect(box.width, greaterThanOrEqualTo(44));
      expect(box.height, greaterThanOrEqualTo(44));
      expect(
        tester.getSemantics(button()),
        isSemantics(label: 'Error Details', isButton: true, hasTapAction: true),
      );
    });

    testWidgets('no ⓘ without details', (tester) async {
      await mount(
        tester,
        const Scaffold(body: ErrorBanner(text: 'Cancelled.')),
      );
      expect(button(), findsNothing);
    });

    testWidgets('the sheet shows stage, target, time and the raw error; Copy '
        'puts the plain-text report on the clipboard', (tester) async {
      await mount(
        tester,
        Scaffold(
          body: ErrorBanner(text: 'Failed.', details: details),
        ),
      );
      await tester.tap(button());
      await tester.pumpAndSettle();
      expect(find.text('Error Details'), findsWidgets);
      String valueOf(String key) => tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .whereType<String>()
          .last;
      expect(valueOf('error-details-stage'), 'DNS / TCP connect');
      expect(valueOf('error-details-target'), 'root@203.0.113.10:22');
      expect(valueOf('error-details-time'), startsWith('2026-10-17 09:30:05 '));
      expect(find.byKey(const ValueKey('error-details-proxy')), findsNothing);
      final technical = tester.widget<SelectableText>(
        find.byKey(const ValueKey('error-details-technical')),
      );
      expect(technical.data, details.technical);
      expect(technical.style!.fontFamily, 'Menlo');
      await tester.tap(find.byKey(const ValueKey('error-details-copy')));
      await tester.pumpAndSettle();
      expect(clipboard, details.report(en));
      expect(clipboard, contains('SocketException: Connection refused'));
      expect(find.text('Copied'), findsOneWidget);
    });

    for (final locale in ['zh', 'en']) {
      testWidgets('sheet and banner fit at 320px / 2x ($locale)', (
        tester,
      ) async {
        final long = ErrorDetails(
          stage: ErrorStage.setup,
          technical:
              'SSHAuthAbortError(Connection closed before authentication)\n'
              'Host key changed: ssh-ed25519 '
              'SHA256:XhNqca+sae/S3LbmMGJ/fEKdHddx3NlGKid1sOszhP8\n'
              'Pinned host key: ssh-rsa '
              'SHA256:5lMYf5wT+/Qmube1W15H5Wus9q19LjZc5DPLMweB/K4\n'
              '${List.filled(5, 'x' * 80).join('\n')}',
          target: 'administrator@[2001:db8:85a3::8a2e:370:7334]:2222',
          proxy: 'Office proxy with a rather long name · SOCKS5 10.0.0.1:1080',
          time: DateTime(2026, 10, 17, 9, 30, 5),
        );
        await mount(
          tester,
          Scaffold(
            body: ErrorBanner(
              text: locale == 'zh' ? '连接未能完成，请检查地址、端口和网络。' : 'The connection could not be completed. Check the address, port and network.',
              details: long,
            ),
          ),
          locale: locale,
          width: 320,
          scale: 2,
        );
        expect(tester.takeException(), isNull);
        expect(tester.getRect(button()).right, lessThanOrEqualTo(320));
        await tester.tap(button());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('error-details-copy')),
          findsOneWidget,
        );
        expect(
          tester
              .getRect(find.byKey(const ValueKey('error-details-target')))
              .right,
          lessThanOrEqualTo(320),
        );
      });
    }

    // ---- real pages ------------------------------------------------------

    Future<String> prepareServer() async {
      await store.saveServer(
        ServerRecord(
          id: 'srv',
          name: 'Tokyo',
          vendor: '',
          resources: null,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        isNew: true,
      );
      expect(
        await ledger.security.saveCredential(
          name: 'Fixture',
          kind: CredentialKind.password,
          defaultUsername: 'root',
          secret: 'synthetic-password-only',
        ),
        isTrue,
      );
      await store.saveSshConfiguration(
        SshConfiguration(
          serverId: 'srv',
          host: '203.0.113.10',
          username: 'root',
          credentialId: ledger.security.credentials.single.id,
        ),
      );
      await ledger.refresh();
      await ledger.security.reload();
      return 'srv';
    }

    testWidgets('SSH connect page: failed attempt shows ⓘ, cancel does not', (
      tester,
    ) async {
      final id = await prepareServer();
      final ssh = _DetailedSsh()
        ..failWith = 'Connection could not be completed.'
        ..details = details;
      await mount(
        tester,
        SshConnectPage(
          ledger: ledger,
          initialServerId: id,
          serviceFactory: (_) => ssh,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('connect-start')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('connect-session-error')),
        findsOneWidget,
      );
      expect(find.text('Connection could not be completed.'), findsOneWidget);
      expect(button(), findsOneWidget);
      await tester.tap(button());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('error-details-technical')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close').first);
      await tester.pumpAndSettle();

      // A failure without details (what a user cancellation looks like).
      final cancelled = _DetailedSsh()..failWith = 'Passphrase entry canceled.';
      await mount(
        tester,
        SshConnectPage(
          ledger: ledger,
          initialServerId: id,
          serviceFactory: (_) => cancelled,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('connect-start')));
      await tester.pumpAndSettle();
      expect(find.text('Passphrase entry canceled.'), findsOneWidget);
      expect(button(), findsNothing);
    });

    testWidgets(
      'terminal: an ended session offers the details from the toast',
      (tester) async {
        final id = await prepareServer();
        final ssh = _DetailedSsh();
        await mount(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const ValueKey('open'),
                onPressed: () => Navigator.push<TerminalFailure>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TerminalPage(
                      ledger: ledger,
                      target: SshTarget(
                        name: 'Tokyo',
                        host: '203.0.113.10',
                        username: 'root',
                        credentialId: ledger.security.credentials.single.id,
                        serverId: id,
                      ),
                      connectOnOpen: true,
                      serviceFactory: (_) => ssh,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('open')));
        await tester.pumpAndSettle();
        expect(ssh.connected, isTrue);
        ssh
          ..error = 'SSH session ended.'
          ..details = ErrorDetails(
            stage: ErrorStage.session,
            technical: 'The server closed the session.\nExit status: 130',
            target: 'root@203.0.113.10:22',
          )
          ..status = SshStatus.disconnected
          ..notifyListeners();
        await tester.pumpAndSettle();
        expect(find.text('SSH session ended.'), findsOneWidget);
        await tester.tap(find.text('Error Details'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Exit status: 130'), findsOneWidget);
      },
    );

    testWidgets('SFTP connect page: ⓘ next to the failure message', (
      tester,
    ) async {
      final id = await prepareServer();
      final ssh = _DetailedSsh()
        ..details = ErrorDetails(
          stage: ErrorStage.sftp,
          technical:
              'SftpException(unavailable)\nSFTP handshake: StateError: x',
          target: 'root@203.0.113.10:22',
        );
      await mount(
        tester,
        SftpConnectPage(
          ledger: ledger,
          serverId: id,
          serviceFactory: (_) => ssh,
        ),
      );
      expect(find.text(en.r3SftpUnavailable), findsOneWidget);
      expect(button(), findsOneWidget);
      await tester.tap(button());
      await tester.pumpAndSettle();
      expect(find.textContaining('SFTP handshake'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const ValueKey('error-details-stage')),
                matching: find.text('SFTP subsystem'),
              ),
            )
            .data,
        'SFTP subsystem',
      );
    });

    TcpConnector refusing() =>
        (host, port) async => throw const SocketException(
          'Connection refused',
          osError: OSError('Connection refused', 61),
          address: null,
        );

    testWidgets('TCP test: refused result has ⓘ, a cancelled one does not', (
      tester,
    ) async {
      final controller = TcpTestController(connector: refusing());
      addTearDown(controller.dispose);
      await mount(
        tester,
        TcpTestPage(
          controller: controller,
          initialHost: '203.0.113.10',
          initialPort: 22,
        ),
      );
      await tester.tap(find.text(en.tcpStart));
      await tester.pumpAndSettle();
      expect(controller.result?.outcome, TcpOutcome.refused);
      expect(button(), findsOneWidget);
      await tester.tap(button());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('SocketException: Connection refused'),
        findsOneWidget,
      );
    });

    testWidgets('TCP test: a cancelled result has no ⓘ', (tester) async {
      final pending = Completer<ConnectionTask<Socket>>();
      final controller = TcpTestController(connector: (h, p) => pending.future);
      addTearDown(controller.dispose);
      await mount(
        tester,
        TcpTestPage(
          controller: controller,
          initialHost: '203.0.113.10',
          initialPort: 22,
        ),
      );
      await tester.tap(find.text(en.tcpStart));
      await tester.pump();
      controller.cancel();
      await tester.pumpAndSettle();
      expect(controller.result?.outcome, TcpOutcome.cancelled);
      expect(button(), findsNothing);
    });
  });
}
