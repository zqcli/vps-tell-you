import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xterm/xterm.dart';
import 'package:vps_tell_you/connections/connection_pages.dart';
import 'package:vps_tell_you/connections/snippet.dart';
import 'package:vps_tell_you/connections/ssh_service.dart';
import 'package:vps_tell_you/connections/terminal_page.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/security/host_trust.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'security_store_test.dart' show FakeSecretStore, FakeDeviceAuth, hostKey;

/// Never opens a socket or executes a real command, including power commands.
class SpySshService extends SshService {
  @override
  SshStatus status = SshStatus.idle;
  @override
  String? error;
  @override
  SshTarget? target;
  @override
  int generation = 0;
  final writes = <String>[];
  final sizes = <(int, int)>[];
  final powers = <SshPowerAction>[];
  final events = StreamController<String>.broadcast(sync: true);
  HostVerificationRequest? request;
  int connections = 0, authentications = 0, disconnections = 0;
  bool disposed = false;
  bool holdConnecting = false, needsPassphrase = false;
  final passphrases = <String>[];
  @override
  Stream<String> get output => events.stream;
  @override
  Future<void> connect(
    SshTarget target, {
    required HostVerifier verifyHost,
    KeyPassphraseRequester? requestKeyPassphrase,
  }) async {
    this.target = target;
    final epoch = ++generation;
    connections++;
    status = SshStatus.connecting;
    notifyListeners();
    if (needsPassphrase) {
      final passphrase = await requestKeyPassphrase?.call(
        'Synthetic encrypted key',
      );
      if (disposed || generation != epoch) return;
      if (passphrase == null) {
        status = SshStatus.disconnected;
        notifyListeners();
        return;
      }
      passphrases.add(passphrase);
    }
    if (holdConnecting) return;
    if (request != null) {
      status = SshStatus.verifying;
      notifyListeners();
      final accepted = await verifyHost(request!);
      if (disposed || generation != epoch) return;
      if (!accepted) {
        status = SshStatus.failed;
        notifyListeners();
        return;
      }
    }
    authentications++;
    status = SshStatus.connected;
    notifyListeners();
  }

  @override
  void write(String value) {
    if (connected) writes.add(value);
  }

  @override
  void resize(int columns, int rows) => sizes.add((columns, rows));
  @override
  void disconnect() {
    if (disposed) return;
    disconnections++;
    generation++;
    status = SshStatus.disconnected;
    notifyListeners();
  }

  @override
  Future<PowerResult> power(
    SshPowerAction action, {
    required int expectedGeneration,
  }) async {
    if (!connected || generation != expectedGeneration) {
      return PowerResult.failed;
    }
    powers.add(action);
    return PowerResult.unknown;
  }

  @override
  void dispose() {
    disposed = true;
    events.close();
    super.dispose();
  }
}

void main() {
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late SpySshService ssh;
  const target = SshTarget(
    name: 'Synthetic target',
    host: '127.0.0.1',
    username: 'fixture',
    port: 22022,
    credentialId: 'fixture-only',
  );

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('vps-terminal-widget-');
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

  Future<void> mount(
    WidgetTester tester, {
    Widget? child,
    String draft = '',
    bool connect = true,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      child ??
                      TerminalPage(
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

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> textTap(WidgetTester tester, String label) =>
      tap(tester, find.text(label).last);
  Future<void> draft(WidgetTester tester, String value) async {
    await tester.ensureVisible(find.byKey(const ValueKey('terminal-draft')));
    await tester.enterText(find.byKey(const ValueKey('terminal-draft')), value);
    await tester.pump();
  }

  String currentDraft(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const ValueKey('terminal-draft')))
      .controller!
      .text;

  testWidgets(
    'opening terminal is offline unless an explicit connect was requested; exit cleans immediately',
    (tester) async {
      await mount(tester, connect: false);
      expect(ssh.connections, 0);
      expect(find.byType(TerminalView), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('terminal-connect')));
      expect(ssh.connections, 1);
      expect(ssh.authentications, 1);
      expect(ssh.writes, isEmpty);
      expect(ssh.sizes, isNotEmpty);
      await tester.tap(find.byTooltip('退出终端'));
      await tester.pump();
      expect(ssh.connected, isFalse);
      await tester.pumpAndSettle();
      expect(ssh.disposed, isTrue);
      expect(find.text('Open terminal fixture'), findsOneWidget);
    },
  );

  testWidgets(
    'draft controls remain separate from xterm and exact bytes need final Send',
    (tester) async {
      const content = 'echo one\nwhoami\r\x03\\r';
      await mount(tester, draft: content);
      expect(ssh.writes, isEmpty);
      await tap(tester, find.byKey(const ValueKey('terminal-send')));
      expect(find.text(target.label), findsWidgets);
      expect(find.text(escapedCommandPreview(content)), findsOneWidget);
      expect(ssh.writes, isEmpty);
      await textTap(tester, '取消');
      expect(ssh.writes, isEmpty);
      expect(currentDraft(tester), content);
      await tap(tester, find.byKey(const ValueKey('terminal-send')));
      await tap(tester, find.byKey(const ValueKey('draft-confirm-send')));
      expect(ssh.writes, [content]);
      expect(currentDraft(tester), isEmpty);
    },
  );

  testWidgets('append Enter is opt-in and included in full escaped preview', (
    tester,
  ) async {
    await mount(tester, draft: 'printf ready');
    await tap(tester, find.byKey(const ValueKey('terminal-send')));
    final checkbox = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('draft-append-enter')),
    );
    expect(checkbox.value, isFalse);
    await tap(tester, find.byKey(const ValueKey('draft-append-enter')));
    expect(find.text(escapedCommandPreview('printf ready\r')), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('draft-confirm-send')));
    expect(ssh.writes, ['printf ready\r']);
  });

  testWidgets(
    'snippet preview and insert send zero bytes; reconnect clears without replay',
    (tester) async {
      const content = 'echo one\r\necho two\x1b[2J';
      await store.saveSnippet(
        const CommandSnippet(
          id: 'fixture-snippet',
          name: 'Synthetic multiline',
          content: content,
        ),
        isNew: true,
      );
      await mount(tester);
      await textTap(tester, '插入片段');
      await textTap(tester, '预览并插入草稿');
      expect(find.text(escapedCommandPreview(content)), findsOneWidget);
      expect(ssh.writes, isEmpty);
      await textTap(tester, '仅插入待发送草稿');
      expect(currentDraft(tester), content);
      expect(ssh.writes, isEmpty);
      await tap(tester, find.byKey(const ValueKey('terminal-disconnect')));
      await tap(tester, find.byKey(const ValueKey('terminal-connect')));
      expect(ssh.connections, 2);
      expect(currentDraft(tester), isEmpty);
      expect(ssh.writes, isEmpty);
    },
  );

  testWidgets('disconnect invalidates a pending exact-send confirmation', (
    tester,
  ) async {
    await mount(tester, draft: 'echo must-not-send\r');
    await tap(tester, find.byKey(const ValueKey('terminal-send')));
    ssh.disconnect();
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('draft-confirm-send')),
          )
          .onPressed,
      isNull,
    );
    await textTap(tester, '取消');
    await tap(tester, find.byKey(const ValueKey('terminal-connect')));
    expect(ssh.writes, isEmpty);
    expect(currentDraft(tester), isEmpty);
  });

  testWidgets('special keys and xterm input work only while connected', (
    tester,
  ) async {
    await mount(tester);
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_left), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.keyboard_arrow_up)).semanticLabel,
      '向上方向键',
    );
    await textTap(tester, 'Ctrl+C');
    await tap(tester, find.byTooltip('向上方向键'));
    final terminal = tester
        .widget<TerminalView>(find.byType(TerminalView))
        .terminal;
    terminal.textInput('pwd');
    expect(ssh.writes, ['\x03', '\x1b[A', 'pwd']);
    await tap(tester, find.byKey(const ValueKey('terminal-disconnect')));
    expect(
      tester.widget<TerminalView>(find.byType(TerminalView)).readOnly,
      isTrue,
    );
    terminal.textInput('never');
    expect(ssh.writes, ['\x03', '\x1b[A', 'pwd']);
  });

  testWidgets(
    'first-use identity shows exact key and refusing prevents authentication',
    (tester) async {
      final identity = hostKey(host: target.host, port: target.port);
      ssh.request = HostVerificationRequest(
        identity: identity,
        status: HostTrustStatus.firstUse,
      );
      await mount(tester);
      expect(find.text(identity.fingerprint), findsOneWidget);
      expect(
        find.text('${identity.algorithm} ${identity.publicKey}'),
        findsOneWidget,
      );
      expect(find.textContaining('端口：${target.port}'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('host-verified-confirm')),
            )
            .onPressed,
        isNull,
      );
      expect(ssh.authentications, 0);
      await textTap(tester, '拒绝连接');
      expect(ssh.authentications, 0);
      expect(ssh.writes, isEmpty);
    },
  );

  testWidgets(
    'explicit independent first-use verification permits authentication only afterwards',
    (tester) async {
      ssh.request = HostVerificationRequest(
        identity: hostKey(host: target.host, port: target.port),
        status: HostTrustStatus.firstUse,
      );
      await mount(tester);
      await tap(tester, find.byKey(const ValueKey('host-verified-check')));
      expect(ssh.authentications, 0);
      await tap(tester, find.byKey(const ValueKey('host-verified-confirm')));
      expect(ssh.authentications, 1);
      expect(ssh.writes, isEmpty);
    },
  );

  testWidgets(
    'changed key requires a distinct reverify step, not an ignore button',
    (tester) async {
      final old = hostKey(seed: 1, host: target.host, port: target.port);
      final changed = hostKey(seed: 2, host: target.host, port: target.port);
      ssh.request = HostVerificationRequest(
        identity: changed,
        status: HostTrustStatus.changed,
        previous: HostTrustRecord(
          host: old.host,
          port: old.port,
          algorithm: old.algorithm,
          publicKey: old.publicKey,
          fingerprint: old.fingerprint,
          verifiedAt: DateTime.utc(2026),
        ),
      );
      await mount(tester);
      expect(find.text('主机密钥变化 · 已阻断认证'), findsOneWidget);
      expect(find.text(old.fingerprint), findsOneWidget);
      expect(find.byKey(const ValueKey('host-verified-confirm')), findsNothing);
      await textTap(tester, '开始独立重新核实');
      expect(
        find.text('${changed.algorithm} ${changed.publicKey}'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('host-verified-confirm')),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, find.byKey(const ValueKey('host-verified-check')));
      expect(ssh.authentications, 0);
      await textTap(tester, '确认更新此主机信任');
      expect(ssh.authentications, 1);
    },
  );

  testWidgets('cancel connecting and background cleanup never send draft', (
    tester,
  ) async {
    ssh.holdConnecting = true;
    await mount(tester, draft: 'unsent\r');
    expect(find.text('取消连接'), findsOneWidget);
    await textTap(tester, '取消连接');
    expect(ssh.authentications, 0);
    ssh.holdConnecting = false;
    await tap(tester, find.byKey(const ValueKey('terminal-connect')));
    await draft(tester, 'still unsent\n');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(ssh.connected, isFalse);
    expect(ssh.writes, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(ssh.connections, 2);
  });

  testWidgets(
    'power is spy-only, two-stage typed-target confirmation sends once',
    (tester) async {
      await mount(tester);
      await tap(tester, find.byTooltip('单机电源'));
      await textTap(tester, 'SSH 重启');
      expect(find.text('重启影响确认（1/2）'), findsOneWidget);
      expect(ssh.powers, isEmpty);
      await textTap(tester, '了解影响，继续核对');
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('power-confirm-submit')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('power-confirm-target')),
        target.label,
      );
      await tester.pump();
      expect(ssh.powers, isEmpty);
      await tap(tester, find.byKey(const ValueKey('power-confirm-submit')));
      expect(ssh.powers, [SshPowerAction.reboot]);
      expect(ssh.writes, isEmpty);
      expect(find.textContaining('结果未知'), findsOneWidget);
    },
  );

  testWidgets(
    'power cancellation and loss of connection invalidate confirmation',
    (tester) async {
      await mount(tester);
      await tap(tester, find.byTooltip('单机电源'));
      await textTap(tester, 'SSH 关机');
      await textTap(tester, '取消');
      expect(ssh.powers, isEmpty);
      await tap(tester, find.byTooltip('单机电源'));
      await textTap(tester, 'SSH 关机');
      await textTap(tester, '了解影响，继续核对');
      await tester.enterText(
        find.byKey(const ValueKey('power-confirm-target')),
        target.label,
      );
      ssh.disconnect();
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('power-confirm-submit')),
            )
            .onPressed,
        isNull,
      );
      await textTap(tester, '取消');
      expect(ssh.powers, isEmpty);
    },
  );

  testWidgets(
    'quick connection reads metadata only and blocks saved demo target',
    (tester) async {
      final now = DateTime.utc(2026, 10, 6);
      final server = ServerRecord(
        id: 'demo',
        name: 'Demo fixture',
        vendor: 'fixture',
        host: '192.0.2.1',
        isDemo: true,
        createdAt: now,
        updatedAt: now,
      );
      await store.saveServer(server, isNew: true);
      await ledger.refresh();
      var creations = 0;
      await mount(
        tester,
        child: SshConnectPage(
          ledger: ledger,
          initialServerId: server.id,
          serviceFactory: (_) {
            creations++;
            return ssh;
          },
        ),
      );
      expect(creations, 0);
      expect(ssh.connections, 0);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('connect-start')))
            .onPressed,
        isNull,
      );
      expect(find.textContaining('演示服务器使用保留地址'), findsOneWidget);
    },
  );

  testWidgets(
    '390px and 2x text keep terminal, draft and first-use dialogs scrollable',
    (tester) async {
      await mount(tester, scale: 2, draft: 'echo large');
      expect(tester.takeException(), isNull);
      await tap(tester, find.byKey(const ValueKey('terminal-send')));
      expect(tester.takeException(), isNull);
      await textTap(tester, '取消');
      await tap(tester, find.byKey(const ValueKey('terminal-disconnect')));
      ssh.request = HostVerificationRequest(
        identity: hostKey(host: target.host, port: target.port),
        status: HostTrustStatus.firstUse,
      );
      await tap(tester, find.byKey(const ValueKey('terminal-connect')));
      expect(tester.takeException(), isNull);
      await tap(tester, find.byKey(const ValueKey('host-verified-check')));
      await textTap(tester, '拒绝连接');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing target invalidates pending Send and never replays a draft',
    (tester) async {
      final targets = ValueNotifier(target);
      addTearDown(targets.dispose);
      await mount(
        tester,
        child: ValueListenableBuilder<SshTarget>(
          valueListenable: targets,
          builder: (_, value, _) => TerminalPage(
            ledger: ledger,
            target: value,
            connectOnOpen: true,
            initialDraft: 'echo old-target\r',
            serviceFactory: (_) => ssh,
          ),
        ),
      );
      await tap(tester, find.byKey(const ValueKey('terminal-send')));
      const next = SshTarget(
        name: 'Next synthetic target',
        host: '::1',
        username: 'other',
        port: 22023,
        credentialId: 'other-fixture',
      );
      targets.value = next;
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('draft-confirm-send')),
            )
            .onPressed,
        isNull,
      );
      await textTap(tester, '取消');
      expect(ssh.connected, isFalse);
      expect(currentDraft(tester), isEmpty);
      expect(ssh.connections, 1);
      await tap(tester, find.byKey(const ValueKey('terminal-connect')));
      expect(ssh.target?.label, next.label);
      expect(ssh.writes, isEmpty);
    },
  );

  testWidgets(
    'stale verification after timeout cannot release authentication',
    (tester) async {
      ssh.request = HostVerificationRequest(
        identity: hostKey(host: target.host, port: target.port),
        status: HostTrustStatus.firstUse,
      );
      await mount(tester);
      await tap(tester, find.byKey(const ValueKey('host-verified-check')));
      ssh.generation++;
      ssh.status = SshStatus.failed;
      ssh.error = 'Synthetic timeout';
      ssh.notifyListeners();
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('host-verified-confirm')),
            )
            .onPressed,
        isNull,
      );
      await textTap(tester, '拒绝连接');
      expect(ssh.authentications, 0);
      expect(ssh.writes, isEmpty);
    },
  );

  testWidgets('arrow shortcuts honor xterm application cursor mode', (
    tester,
  ) async {
    await mount(tester);
    final terminal = tester
        .widget<TerminalView>(find.byType(TerminalView))
        .terminal;
    terminal.write('\x1b[?1h');
    await tap(tester, find.byTooltip('向上方向键'));
    await tap(tester, find.byTooltip('向左方向键'));
    expect(ssh.writes, ['\x1bOA', '\x1bOD']);
    terminal.write('\x1b[?1l');
    await tap(tester, find.byTooltip('向上方向键'));
    expect(ssh.writes.last, '\x1b[A');
  });

  testWidgets(
    'quick saved target keeps explicit user and temporary edits do not overwrite saved config',
    (tester) async {
      final now = DateTime.utc(2026, 10, 6);
      final server = ServerRecord(
        id: 'saved-target',
        name: 'Saved synthetic target',
        vendor: 'fixture',
        host: '127.0.0.1',
        createdAt: now,
        updatedAt: now,
      );
      await store.saveServer(server, isNew: true);
      await ledger.refresh();
      expect(
        await ledger.security.saveCredential(
          name: 'Fixture password',
          kind: CredentialKind.password,
          defaultUsername: 'root',
          secret: 'SYNTHETIC-NOT-A-REAL-PASSWORD',
        ),
        isTrue,
      );
      final credential = ledger.security.credentials.single;
      expect(
        await ledger.security.saveSshConfiguration(
          SshConfiguration(
            serverId: server.id,
            host: '127.0.0.1',
            username: 'deploy',
            port: 22022,
            credentialId: credential.id,
          ),
        ),
        isTrue,
      );
      await mount(
        tester,
        child: SshConnectPage(
          ledger: ledger,
          initialServerId: server.id,
          serviceFactory: (_) => ssh,
        ),
      );
      expect(ssh.connections, 0);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('connect-user')))
            .controller!
            .text,
        'deploy',
      );
      await textTap(tester, '显式采用默认用户名：root');
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('connect-user')))
            .controller!
            .text,
        'root',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('connect-host')));
      await tester.enterText(
        find.byKey(const ValueKey('connect-host')),
        'localhost',
      );
      await tap(tester, find.byKey(const ValueKey('connect-start')));
      expect(ssh.connections, 1);
      expect(ssh.target?.host, 'localhost');
      expect(ssh.target?.username, 'root');
      expect(ssh.target?.credentialId, credential.id);
      expect(ledger.security.configFor(server.id)?.host, '127.0.0.1');
      expect(ledger.security.configFor(server.id)?.username, 'deploy');
      expect(ssh.writes, isEmpty);
    },
  );

  testWidgets(
    'private-key passphrase is obscured, transient, and requested on each connect',
    (tester) async {
      ssh.needsPassphrase = true;
      await mount(tester);
      final fieldFinder = find.byKey(const ValueKey('ssh-key-passphrase'));
      final field = tester.widget<TextField>(fieldFinder);
      final transientController = field.controller!;
      expect(field.obscureText, isTrue);
      expect(field.enableIMEPersonalizedLearning, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(ssh.authentications, 0);
      await tester.enterText(fieldFinder, 'SYNTHETIC-KEY-UNLOCK');
      await tester.pump();
      await tap(
        tester,
        find.byKey(const ValueKey('ssh-key-passphrase-submit')),
      );
      expect(transientController.text, isEmpty);
      expect(ssh.passphrases, ['SYNTHETIC-KEY-UNLOCK']);
      expect(ssh.authentications, 1);
      expect(ssh.writes, isEmpty);
      expect(ledger.security.credentials, isEmpty);
      await tap(tester, find.byKey(const ValueKey('terminal-disconnect')));
      await tap(tester, find.byKey(const ValueKey('terminal-connect')));
      expect(fieldFinder, findsOneWidget);
      await tester.enterText(fieldFinder, 'CANCELLED-SYNTHETIC');
      final cancelledController = tester
          .widget<TextField>(fieldFinder)
          .controller!;
      await textTap(tester, '取消连接');
      expect(cancelledController.text, isEmpty);
      expect(ssh.authentications, 1);
      expect(ssh.passphrases, ['SYNTHETIC-KEY-UNLOCK']);
    },
  );

  testWidgets(
    'private-key passphrase clears on background and cannot authenticate afterwards',
    (tester) async {
      ssh.needsPassphrase = true;
      await mount(tester);
      final finder = find.byKey(const ValueKey('ssh-key-passphrase'));
      await tester.enterText(finder, 'NEVER-PERSIST-SYNTHETIC');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(tester.widget<TextField>(finder).controller!.text, isEmpty);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('ssh-key-passphrase-submit')),
            )
            .onPressed,
        isNull,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await textTap(tester, '取消连接');
      expect(ssh.authentications, 0);
      expect(ssh.passphrases, isEmpty);
    },
  );

  testWidgets(
    'private-key passphrase is cleared when target changes or system Back cancels',
    (tester) async {
      ssh.needsPassphrase = true;
      final targets = ValueNotifier(target);
      addTearDown(targets.dispose);
      await mount(
        tester,
        child: ValueListenableBuilder<SshTarget>(
          valueListenable: targets,
          builder: (_, value, _) => TerminalPage(
            ledger: ledger,
            target: value,
            connectOnOpen: true,
            serviceFactory: (_) => ssh,
          ),
        ),
      );
      final finder = find.byKey(const ValueKey('ssh-key-passphrase'));
      await tester.enterText(finder, 'SYNTHETIC-OLD-TARGET');
      final controller = tester.widget<TextField>(finder).controller!;
      targets.value = const SshTarget(
        name: 'Changed',
        host: '::1',
        username: 'other',
        credentialId: 'other',
      );
      await tester.pumpAndSettle();
      expect(controller.text, isEmpty);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('ssh-key-passphrase-submit')),
            )
            .onPressed,
        isNull,
      );
      await textTap(tester, '取消连接');
      expect(ssh.authentications, 0);
      expect(ssh.passphrases, isEmpty);
      await tap(tester, find.byKey(const ValueKey('terminal-connect')));
      await tester.enterText(finder, 'SYNTHETIC-CANCELLED-BACK');
      final backController = tester.widget<TextField>(finder).controller!;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(backController.text, isEmpty);
      expect(ssh.authentications, 0);
      expect(ssh.passphrases, isEmpty);
    },
  );

  testWidgets(
    'manual draft remains bounded for complete review without writing SSH',
    (tester) async {
      await mount(tester);
      await draft(tester, 'small draft');
      await draft(tester, 'x' * (CommandSnippet.maxContentLength + 1));
      expect(
        currentDraft(tester).length,
        lessThanOrEqualTo(CommandSnippet.maxContentLength),
      );
      expect(ssh.writes, isEmpty);
    },
  );

  testWidgets(
    'quick-connect double activation before a frame opens exactly one session and latch resets on return',
    (tester) async {
      final now = DateTime.utc(2026, 10, 6);
      final server = ServerRecord(
        id: 'double-connect',
        name: 'Synthetic double activation',
        vendor: 'fixture',
        host: '127.0.0.1',
        createdAt: now,
        updatedAt: now,
      );
      await store.saveServer(server, isNew: true);
      await ledger.refresh();
      expect(
        await ledger.security.saveCredential(
          name: 'Double-activation fixture',
          kind: CredentialKind.password,
          defaultUsername: 'fixture',
          secret: 'SYNTHETIC-DOUBLE-ACTIVATION',
        ),
        isTrue,
      );
      final credential = ledger.security.credentials.single;
      expect(
        await ledger.security.saveSshConfiguration(
          SshConfiguration(
            serverId: server.id,
            host: '127.0.0.1',
            username: 'fixture',
            credentialId: credential.id,
          ),
        ),
        isTrue,
      );
      final sessions = <SpySshService>[];
      await mount(
        tester,
        child: SshConnectPage(
          ledger: ledger,
          initialServerId: server.id,
          serviceFactory: (_) {
            final session = SpySshService();
            sessions.add(session);
            return session;
          },
        ),
      );
      final activate = tester
          .widget<FilledButton>(find.byKey(const ValueKey('connect-start')))
          .onPressed!;
      // Same pre-frame callback, before the disabled state can be rebuilt.
      activate();
      activate();
      await tester.pumpAndSettle();
      expect(sessions, hasLength(1));
      expect(sessions.single.connections, 1);
      expect(find.byType(TerminalPage, skipOffstage: false), findsOneWidget);
      await tester.tap(find.byTooltip('退出终端'));
      await tester.pumpAndSettle();
      expect(sessions.single.disposed, isTrue);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('connect-start')))
            .onPressed,
        isNotNull,
      );
      await tap(tester, find.byKey(const ValueKey('connect-start')));
      expect(sessions, hasLength(2));
      expect(sessions.last.connections, 1);
    },
  );
}
