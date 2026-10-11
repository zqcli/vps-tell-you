import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/connections/sftp_pages.dart';
import 'package:vps_tell_you/connections/sftp_session.dart';
import 'package:vps_tell_you/connections/ssh_service.dart';
import 'package:vps_tell_you/connections/terminal_page.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/l10n/localized_message.dart';
import 'package:vps_tell_you/security/host_trust.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_detail.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'security_store_test.dart' show FakeSecretStore, FakeDeviceAuth, hostKey;
import 'support/fake_sftp_session.dart';
import 'terminal_widget_test.dart' show SpySshService;

/// Stands in for [NativeSshService.connectSftp]: drives the same callbacks the
/// real one does (passphrase, host verification) and returns a fake session.
class FakeSftpService extends SshService {
  FakeSftpService(this.session);
  final FakeSftpSession session;
  @override
  SshStatus status = SshStatus.idle;
  @override
  String? error;
  @override
  SshTarget? target;
  @override
  int generation = 0;
  Completer<void>? hold;
  HostVerificationRequest? request;
  bool needsPassphrase = false;
  final passphrases = <String>[];
  int connects = 0, disconnects = 0;
  bool disposed = false;
  @override
  Stream<String> get output => const Stream.empty();

  @override
  Future<void> connect(
    SshTarget target, {
    required HostVerifier verifyHost,
    KeyPassphraseRequester? requestKeyPassphrase,
  }) async => throw UnimplementedError('SFTP entry never opens a shell');

  @override
  Future<SftpSession> connectSftp(
    SshTarget requested, {
    required HostVerifier verifyHost,
    KeyPassphraseRequester? requestKeyPassphrase,
  }) async {
    target = requested;
    connects++;
    final epoch = ++generation;
    status = SshStatus.connecting;
    notifyListeners();
    SecurityFailure failure(String Function(AppLocalizations) text) =>
        SecurityFailure(LocalizedText(text));
    if (needsPassphrase) {
      final value = await requestKeyPassphrase!('Synthetic encrypted key');
      if (generation != epoch) throw failure((l) => l.sshConnectionCancelled);
      if (value == null) throw failure((l) => l.sshPassphraseCancelled);
      passphrases.add(value);
    }
    if (hold != null) {
      await hold!.future;
      if (generation != epoch) throw failure((l) => l.sshConnectionCancelled);
    }
    if (request != null) {
      status = SshStatus.verifying;
      notifyListeners();
      final accepted = await verifyHost(request!);
      if (generation != epoch) throw failure((l) => l.sshConnectionCancelled);
      if (!accepted) {
        status = SshStatus.failed;
        notifyListeners();
        throw failure((l) => l.sshHostNotTrusted);
      }
    }
    status = SshStatus.connected;
    notifyListeners();
    return session;
  }

  @override
  void write(String value) => fail('SFTP never writes to a shell');
  @override
  void resize(int columns, int rows) {}
  @override
  void disconnect() {
    disconnects++;
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
    disposed = true;
    super.dispose();
  }
}

class SftpSpySsh extends SpySshService {
  SftpSpySsh(this.session);
  FakeSftpSession session;
  SftpErrorKind? failOpen;
  int sftpOpens = 0;
  @override
  Future<SftpSession> openSftpOnClient() async {
    sftpOpens++;
    if (failOpen != null) throw SftpException(failOpen!);
    if (!connected) throw const SftpException(SftpErrorKind.connectionLost);
    return session;
  }
}

void main() {
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late FakeSftpSession fake;
  late String credentialId;
  final now = DateTime(2026, 10, 7, 12);

  ServerRecord record(String id, {bool demo = false}) => ServerRecord(
    id: id,
    name: 'Server $id',
    vendor: 'fixture',
    host: '192.0.2.${id.length}',
    createdAt: now,
    updatedAt: now,
    isDemo: demo,
  );

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('sftp-entry-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
      clock: () => now,
    );
    ledger = LedgerController(
      store,
      clock: () => now,
      security: SecurityController(
        store: store,
        secrets: FakeSecretStore(),
        authenticator: FakeDeviceAuth(),
      ),
    );
    await ledger.security.initialize();
    expect(
      await ledger.security.saveCredential(
        name: 'Fixture login',
        kind: CredentialKind.password,
        defaultUsername: 'fixture',
        secret: 'synthetic-password-only',
        passphrase: null,
        savePassphrase: false,
      ),
      isTrue,
    );
    credentialId = ledger.security.credentials.single.id;
    for (final s in [
      record('ready'),
      record('nossh'),
      record('demo', demo: true),
      record('old'),
    ]) {
      await store.saveServer(s, isNew: true);
    }
    await ledger.refresh();
    await ledger.security.saveSshConfiguration(
      SshConfiguration(
        serverId: 'ready',
        host: '192.0.2.5',
        username: 'deploy',
        port: 2222,
        credentialId: credentialId,
      ),
    );
    await ledger.security.saveSshConfiguration(
      const SshConfiguration(
        serverId: 'old',
        host: '192.0.2.3',
        username: 'deploy',
        credentialId: null,
      ),
    );
    fake = FakeSftpSession()
      ..dir('/srv')
      ..file('/hello.txt', 'hi');
  });

  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  // Each connection attempt gets a fresh service, like the real factory.
  late FakeSftpService service;
  HostVerificationRequest? nextRequest;
  bool nextPassphrase = false;
  Completer<void>? nextHold;
  final services = <FakeSftpService>[];

  Future<void> mountDetail(
    WidgetTester tester,
    String id, {
    String locale = 'zh',
  }) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    nextRequest = null;
    nextPassphrase = false;
    nextHold = null;
    services.clear();
    service = FakeSftpService(fake);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: ServerDetail(
          controller: ledger,
          id: id,
          sshServiceFactory: (_) => service = FakeSftpService(fake)
            ..request = nextRequest
            ..needsPassphrase = nextPassphrase
            ..hold = nextHold,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('server-sftp')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapSftp(WidgetTester tester) async {
    final row = find.byKey(const ValueKey('server-sftp'));
    await reveal(tester);
    await tester.tap(row);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('server detail entry', () {
    testWidgets('row sits right after SSH with the same availability', (
      tester,
    ) async {
      await mountDetail(tester, 'ready');
      final ssh = find.byKey(const ValueKey('server-quick-ssh'));
      final sftp = find.byKey(const ValueKey('server-sftp'));
      final tcp = find.byKey(const ValueKey('server-quick-tcp'));
      expect(sftp, findsOneWidget);
      await reveal(tester);
      expect(find.text('SFTP 文件'), findsOneWidget);
      final sshY = tester.getTopLeft(ssh).dy;
      final sftpY = tester.getTopLeft(sftp).dy;
      final tcpY = tester.getTopLeft(tcp).dy;
      expect(sshY, lessThan(sftpY));
      expect(sftpY, lessThan(tcpY));
      double opacity(Finder f) => tester
          .widget<Opacity>(
            find.ancestor(of: f, matching: find.byType(Opacity)).first,
          )
          .opacity;
      expect(opacity(sftp), 1);
      expect(opacity(ssh), 1);
    });

    testWidgets('English title', (tester) async {
      await mountDetail(tester, 'ready', locale: 'en');
      await reveal(tester);
      expect(find.text('SFTP files'), findsOneWidget);
    });

    testWidgets('no SSH configuration: dimmed, offers to set it up', (
      tester,
    ) async {
      await mountDetail(tester, 'nossh');
      final row = find.byKey(const ValueKey('server-sftp'));
      await reveal(tester);
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(of: row, matching: find.byType(Opacity)).first,
            )
            .opacity,
        lessThan(1),
      );
      await tapSftp(tester);
      await tester.pumpAndSettle();
      expect(find.text('尚未配置 SSH'), findsOneWidget);
      expect(service.connects, 0);
    });

    testWidgets('demo servers explain instead of connecting', (tester) async {
      await mountDetail(tester, 'demo');
      await tapSftp(tester);
      expect(find.textContaining('演示'), findsWidgets);
      expect(service.connects, 0);
      expect(find.byType(SftpBrowserPage), findsNothing);
    });

    testWidgets('archived servers explain instead of connecting', (
      tester,
    ) async {
      await store.archive(ledger.byId('old')!);
      await ledger.refresh();
      await mountDetail(tester, 'old');
      await tapSftp(tester);
      expect(find.text('已归档的服务器不能进行此操作。'), findsOneWidget);
      expect(service.connects, 0);
    });

    testWidgets('connects through the same host check, then browses', (
      tester,
    ) async {
      await mountDetail(tester, 'ready');
      nextRequest = HostVerificationRequest(
        identity: hostKey(host: '192.0.2.5', port: 2222),
        status: HostTrustStatus.firstUse,
      );
      await tapSftp(tester);
      // The terminal's own verification dialog, unchanged.
      expect(find.byKey(const ValueKey('host-verified-check')), findsOneWidget);
      expect(service.target!.label, 'deploy@192.0.2.5:2222');
      expect(service.target!.credentialId, credentialId);
      expect(find.byType(SftpBrowserPage), findsNothing);
      await tester.tap(find.byKey(const ValueKey('host-verified-check')));
      // The connecting spinner never settles.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('host-verified-confirm')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byType(SftpBrowserPage), findsOneWidget);
      expect(find.text('hello.txt'), findsOneWidget);
      expect(service.status, SshStatus.connected);
      // Closing the page closes the connection.
      await tester.tap(find.byKey(const ValueKey('app-nav-back')));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(fake.closed, isTrue);
      expect(find.byType(ServerDetail), findsOneWidget);
    });

    testWidgets('refusing the host key ends with a retryable error', (
      tester,
    ) async {
      await mountDetail(tester, 'ready');
      nextRequest = HostVerificationRequest(
        identity: hostKey(host: '192.0.2.5', port: 2222),
        status: HostTrustStatus.firstUse,
      );
      await tapSftp(tester);
      await tester.tap(find.text('拒绝连接'));
      await tester.pumpAndSettle();
      expect(find.text('无法打开 SFTP'), findsOneWidget);
      expect(find.text('主机未获信任，未进行认证'), findsOneWidget);
      expect(find.byType(SftpBrowserPage), findsNothing);
      nextRequest = null;
      await tester.tap(find.byKey(const ValueKey('sftp-connect-retry')));
      await tester.pumpAndSettle();
      expect(find.byType(SftpBrowserPage), findsOneWidget);
    });

    testWidgets('private-key passphrase uses the terminal prompt', (
      tester,
    ) async {
      await mountDetail(tester, 'ready');
      nextPassphrase = true;
      await tapSftp(tester);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('ssh-key-passphrase')),
      );
      expect(field.obscureText, isTrue);
      await tester.enterText(
        find.byKey(const ValueKey('ssh-key-passphrase')),
        'SYNTHETIC-KEY-UNLOCK',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ssh-key-passphrase-submit')));
      await tester.pumpAndSettle();
      expect(service.passphrases, ['SYNTHETIC-KEY-UNLOCK']);
      expect(field.controller!.text, isEmpty);
      expect(find.byType(SftpBrowserPage), findsOneWidget);
    });

    testWidgets('connecting can be cancelled and leaves nothing open', (
      tester,
    ) async {
      await mountDetail(tester, 'ready');
      nextHold = Completer<void>();
      await tapSftp(tester);
      expect(find.byKey(const ValueKey('sftp-connect-status')), findsOneWidget);
      expect(find.text('正在连接 SFTP…'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sftp-connect-cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(ServerDetail), findsOneWidget);
      expect(service.disconnects, greaterThan(0));
      nextHold!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SftpBrowserPage), findsNothing);
      expect(service.disposed, isTrue);
    });

    testWidgets('a missing credential offers the SSH settings', (tester) async {
      await mountDetail(tester, 'old');
      await tapSftp(tester);
      await tester.pumpAndSettle();
      expect(find.text('请先在 SSH 设置中选择凭据。'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('sftp-connect-settings')),
        findsOneWidget,
      );
      expect(service.connects, 0);
    });

    testWidgets('backgrounding the browser returns to the detail with a note', (
      tester,
    ) async {
      await mountDetail(tester, 'ready');
      await tapSftp(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SftpBrowserPage), findsOneWidget);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(find.byType(SftpBrowserPage), findsNothing);
      expect(find.text('应用进入后台，SFTP 已关闭'), findsOneWidget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(fake.closed, isTrue);
    });
  });

  group('terminal sheet', () {
    late SftpSpySsh ssh;
    const target = SshTarget(
      name: 'Synthetic target',
      host: '127.0.0.1',
      username: 'fixture',
      port: 22022,
      credentialId: 'fixture-only',
    );

    Future<void> mountTerminal(
      WidgetTester tester, {
      String draft = '',
      bool connect = true,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ssh = SftpSpySsh(fake);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TerminalPage(
                      ledger: ledger,
                      target: target,
                      initialDraft: draft,
                      connectOnOpen: connect,
                      serviceFactory: (_) => ssh,
                    ),
                  ),
                ),
                child: const Text('Open terminal fixture'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open terminal fixture'));
      await tester.pumpAndSettle();
    }

    Future<void> openSftpFromMenu(WidgetTester tester) async {
      await tester.tap(find.byTooltip('终端菜单'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SFTP 文件'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'menu opens the browser as a sheet without touching the shell',
      (tester) async {
        await mountTerminal(tester, draft: 'echo unsent');
        expect(ssh.connected, isTrue);
        await openSftpFromMenu(tester);
        expect(ssh.sftpOpens, 1);
        expect(find.byType(SftpBrowserPage), findsOneWidget);
        expect(find.text('hello.txt'), findsOneWidget);
        expect(find.byKey(const ValueKey('sftp-close')), findsOneWidget);
        // Same connection: no reconnect, no extra auth, no shell bytes.
        expect(ssh.connections, 1);
        expect(ssh.authentications, 1);
        expect(ssh.writes, isEmpty);
        expect(ssh.disconnections, 0);

        // Doing file work still sends nothing to the shell.
        await tester.tap(find.byKey(const ValueKey('sftp-add')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('sftp-new-folder')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('sftp-name-field')),
          'made',
        );
        await tester.tap(find.byKey(const ValueKey('sftp-name-submit')));
        await tester.pumpAndSettle();
        expect(fake.exists('/made'), isTrue);
        expect(ssh.writes, isEmpty);

        // Closing the sheet closes the channel only.
        await tester.tap(find.byKey(const ValueKey('sftp-close')));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        expect(find.byType(SftpBrowserPage), findsNothing);
        expect(find.byType(TerminalPage), findsOneWidget);
        expect(fake.closed, isTrue);
        expect(ssh.connected, isTrue);
        expect(ssh.disconnections, 0);
        expect(ssh.writes, isEmpty);
        // The command draft survived.
        if (find.byKey(const ValueKey('terminal-draft')).evaluate().isEmpty) {
          await tester.tap(find.byKey(const ValueKey('terminal-commands')));
          await tester.pumpAndSettle();
        }
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('terminal-draft')))
              .controller!
              .text,
          'echo unsent',
        );
      },
    );

    testWidgets('the sheet closes when the SSH session ends', (tester) async {
      await mountTerminal(tester);
      await openSftpFromMenu(tester);
      expect(find.byType(SftpBrowserPage), findsOneWidget);
      ssh.disconnect();
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(find.byType(SftpBrowserPage), findsNothing);
      expect(find.byType(TerminalPage), findsNothing);
      expect(find.text('Open terminal fixture'), findsOneWidget);
      expect(fake.closed, isTrue);
    });

    testWidgets('a refused subsystem is a short toast and the shell stays', (
      tester,
    ) async {
      await mountTerminal(tester);
      fake = FakeSftpSession();
      ssh.failOpen = SftpErrorKind.unavailable;
      await openSftpFromMenu(tester);
      expect(find.text('此连接无法使用 SFTP'), findsOneWidget);
      expect(find.byType(SftpBrowserPage), findsNothing);
      expect(ssh.connected, isTrue);
      expect(ssh.writes, isEmpty);
    });

    testWidgets('the menu entry is disabled while not connected', (
      tester,
    ) async {
      await mountTerminal(tester, connect: false);
      expect(ssh.connected, isFalse);
      await tester.tap(find.byTooltip('终端菜单'));
      await tester.pumpAndSettle();
      final item = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, 'SFTP 文件'),
      );
      expect(item.enabled, isFalse);
      await tester.tap(find.text('SFTP 文件'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(ssh.sftpOpens, 0);
      expect(find.byType(SftpBrowserPage), findsNothing);
    });
  });
}
