import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/security/host_trust_pages.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/security/security_pages.dart';
import 'package:vps_tell_you/security/ssh_configuration_page.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'security_store_test.dart' show FakeDeviceAuth, FakeSecretStore, hostKey;

void main() {
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late SecurityController security;
  late FakeSecretStore secrets;
  late FakeDeviceAuth auth;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('vps-security-widget-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
    );
    secrets = FakeSecretStore();
    auth = FakeDeviceAuth();
    security = SecurityController(
      store: store,
      secrets: secrets,
      authenticator: auth,
    );
    ledger = LedgerController(store, security: security);
    await ledger.refresh();
    await security.initialize();
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<CredentialMetadata> credential({
    String name = 'Synthetic password',
    String user = 'root',
  }) async {
    expect(
      await security.saveCredential(
        name: name,
        kind: CredentialKind.password,
        defaultUsername: user,
        secret: 'SYNTHETIC_SECRET_VALUE',
      ),
      isTrue,
    );
    return security.credentials.firstWhere((c) => c.name == name);
  }

  Future<String> server({String name = 'Synthetic server'}) async {
    final now = DateTime.utc(2026, 10, 6);
    final record = ServerRecord(
      id: name,
      name: name,
      vendor: 'fixture',
      host: '192.0.2.1',
      createdAt: now,
      updatedAt: now,
    );
    await store.saveServer(record, isNew: true);
    await ledger.refresh();
    return record.id;
  }

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        navigatorObservers: [securityRouteObserver],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => child),
                ),
                child: const Text('Open fixture'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open fixture'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String key, String text) async {
    final field = find.byKey(ValueKey(key));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  for (final remember in [false, true]) {
    testWidgets('encrypted import passphrase storage is explicit: $remember', (
      tester,
    ) async {
      final key = File('test/fixtures/security/ed25519_encrypted.fixture')
          .readAsStringSync();
      await mount(
        tester,
        CredentialForm(
          ledger: ledger,
          kind: CredentialKind.privateKey,
          pickKey: () async => key,
        ),
      );
      await fill(tester, 'credential-name', 'Encrypted fixture');
      if (remember) {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async =>
              call.method == 'Clipboard.getData' ? {'text': key} : null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await tap(tester, '粘贴完整私钥');
      } else {
        await tap(tester, '选择私钥文件');
      }
      await fill(tester, 'credential-passphrase', 'fixture-passphrase-only');
      final option = find.byKey(const ValueKey('credential-save-passphrase'));
      await tester.ensureVisible(option);
      expect(tester.widget<CheckboxListTile>(option).value, isFalse);
      if (remember) {
        await tester.tap(option);
        await tester.pump();
      }
      await tester.ensureVisible(find.text('保存凭据'));
      await tester.runAsync(() async {
        await tester.tap(find.text('保存凭据'));
        // Key parsing is intentionally performed in an isolate. Poll metadata
        // without pretending that fake widget time advances native work.
        final deadline = DateTime.now().add(const Duration(seconds: 15));
        while (security.credentials.isEmpty &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      await tester.pumpAndSettle();
      expect(security.credentials, hasLength(1), reason: security.error);
      final encoded = await secrets.read(security.credentials.single.secretRef);
      final envelope = jsonDecode(encoded!) as Map<String, dynamic>;
      expect(envelope['secret'], key);
      expect(
        envelope['passphrase'],
        remember ? 'fixture-passphrase-only' : isNull,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('password save uses native contract; search is metadata only', (
    tester,
  ) async {
    await mount(
      tester,
      CredentialForm(ledger: ledger, kind: CredentialKind.password),
    );
    await fill(tester, 'credential-name', 'fixture name');
    await fill(tester, 'credential-username', 'ubuntu');
    await fill(tester, 'credential-secret', 'SYNTHETIC_NEW_PASSWORD');
    await tap(tester, '保存凭据');
    expect(security.credentials.single.defaultUsername, 'ubuntu');
    expect(secrets.writes, 1);
    await mount(tester, SecurityPage(ledger: ledger));
    await fill(tester, 'credential-search', 'ubuntu');
    expect(find.text('fixture name'), findsOneWidget);
    await fill(tester, 'credential-search', 'SYNTHETIC_NEW_PASSWORD');
    expect(find.text('fixture name'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dirty edit cancellation preserves secret and metadata; leaving background clears input',
    (tester) async {
      final c = await credential();
      await mount(
        tester,
        CredentialForm(ledger: ledger, kind: c.kind, existing: c),
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('credential-secret')),
            )
            .controller!
            .text,
        isEmpty,
      );
      await fill(tester, 'credential-name', 'Uncommitted');
      await fill(tester, 'credential-secret', 'SYNTHETIC_DRAFT');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('credential-secret')),
            )
            .controller!
            .text,
        isEmpty,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.byTooltip('取消编辑凭据'));
      await tester.pumpAndSettle();
      await tap(tester, '取消');
      expect(find.text('编辑凭据'), findsOneWidget);
      await tester.tap(find.byTooltip('取消编辑凭据'));
      await tester.pumpAndSettle();
      await tap(tester, '放弃修改');
      expect(security.credentials.single.name, c.name);
      expect(secrets.writes, 1);
    },
  );

  testWidgets(
    'failed native save stays editable and error never echoes secret',
    (tester) async {
      secrets.failWrite = true;
      await mount(
        tester,
        CredentialForm(ledger: ledger, kind: CredentialKind.password),
      );
      await fill(tester, 'credential-name', 'fixture');
      await fill(tester, 'credential-username', 'root');
      await fill(tester, 'credential-secret', 'DO_NOT_ECHO_THIS');
      await tap(tester, '保存凭据');
      expect(security.credentials, isEmpty);
      expect(find.textContaining('DO-NOT-LEAK'), findsNothing);
      expect(security.error, isNot(contains('DO_NOT_ECHO_THIS')));
      expect(find.text('保存凭据'), findsOneWidget);
      expect(security.cleanupPending, isTrue);
    },
  );

  testWidgets(
    'file chooser cancel keeps draft and late result after departure is ignored',
    (tester) async {
      var picks = 0;
      await mount(
        tester,
        CredentialForm(
          ledger: ledger,
          kind: CredentialKind.privateKey,
          pickKey: () async => picks++ == 0 ? 'SYNTHETIC_KEY_DRAFT' : null,
        ),
      );
      await tap(tester, '选择私钥文件');
      await tap(tester, '选择私钥文件');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('credential-secret')),
            )
            .controller!
            .text,
        'SYNTHETIC_KEY_DRAFT',
      );
      final pending = Completer<String?>();
      await mount(
        tester,
        CredentialForm(
          ledger: ledger,
          kind: CredentialKind.privateKey,
          pickKey: () => pending.future,
        ),
      );
      await tap(tester, '选择私钥文件');
      await tester.tap(find.byTooltip('取消编辑凭据'));
      await tester.pump();
      pending.complete('LATE_SYNTHETIC_KEY');
      await tester.pumpAndSettle();
      expect(find.text('新增凭据'), findsNothing);
      expect(security.credentials, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reveal requires auth, timeout hides, background invalidates pending auth',
    (tester) async {
      final c = await credential();
      await mount(
        tester,
        CredentialDetailPage(ledger: ledger, credentialId: c.id),
      );
      expect(find.text('SYNTHETIC_SECRET_VALUE'), findsNothing);
      auth.allowed = false;
      await tap(tester, '设备验证后查看密码');
      expect(find.text('SYNTHETIC_SECRET_VALUE'), findsNothing);
      auth.allowed = true;
      await tap(tester, '设备验证后查看密码');
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 3));
        while (security.authenticating && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.pumpAndSettle();
      expect(
        security.revealedSecret,
        'SYNTHETIC_SECRET_VALUE',
        reason: security.error,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('revealed-secret')));
      expect(find.text('SYNTHETIC_SECRET_VALUE'), findsOneWidget);
      await tester.pump(const Duration(seconds: 21));
      expect(find.text('SYNTHETIC_SECRET_VALUE'), findsNothing);
      auth.pending = Completer<bool>();
      await tap(tester, '设备验证后查看密码');
      final reads = secrets.reads;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      auth.pending!.complete(true);
      await tester.pumpAndSettle();
      expect(secrets.reads, reads);
      expect(find.text('SYNTHETIC_SECRET_VALUE'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    },
  );

  testWidgets(
    'SSH credential change explicitly adopts or keeps username and persists independently',
    (tester) async {
      final first = await credential(name: 'First', user: 'root');
      final second = await credential(name: 'Second', user: 'ubuntu');
      final id = await server();
      expect(
        await security.saveSshConfiguration(
          SshConfiguration(
            serverId: id,
            host: '192.0.2.1',
            username: 'root',
            credentialId: first.id,
          ),
        ),
        isTrue,
      );
      await mount(tester, SshConfigurationPage(ledger: ledger, serverId: id));
      await tap(tester, 'First');
      await tap(tester, 'Second');
      expect(find.text('使用凭据的默认用户名？'), findsOneWidget);
      await tap(tester, '取消');
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('ssh-username')))
            .controller!
            .text,
        'root',
      );
      await tap(tester, '保存 SSH 配置');
      expect(security.configFor(id)!.username, 'root');
      expect(security.configFor(id)!.credentialId, second.id);
      await mount(tester, SshConfigurationPage(ledger: ledger, serverId: id));
      await tap(tester, 'Second');
      await tap(tester, 'Second');
      await tap(tester, '采用默认用户名');
      await tap(tester, '保存 SSH 配置');
      expect(security.configFor(id)!.username, 'ubuntu');
      expect(ledger.byId(id)!.host, '192.0.2.1');
    },
  );

  testWidgets(
    'delete impact defaults unchecked and detach retains server and username',
    (tester) async {
      final c = await credential();
      final id = await server();
      await security.saveSshConfiguration(
        SshConfiguration(
          serverId: id,
          host: '192.0.2.1',
          username: 'explicit',
          credentialId: c.id,
        ),
      );
      await mount(tester, CredentialDeletePage(ledger: ledger, credential: c));
      await tester.ensureVisible(find.text('确认删除'));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '确认删除'))
            .onPressed,
        isNull,
      );
      await tap(tester, '我已确认关联影响，删除本地凭据');
      await tap(tester, '确认删除');
      expect(security.credentials, isEmpty);
      expect(security.configFor(id)!.credentialId, isNull);
      expect(security.configFor(id)!.username, 'explicit');
      expect(ledger.byId(id), isNotNull);
    },
  );

  testWidgets(
    'first use and changed host trust require checkbox and separate reverify',
    (tester) async {
      final initial = hostKey();
      await mount(
        tester,
        HostVerificationPage(ledger: ledger, identity: initial),
      );
      await tester.ensureVisible(find.text('保存已核验的主机信任'));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '保存已核验的主机信任'),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, '拒绝并返回');
      expect(security.hostTrusts, isEmpty);
      await security.verifyHost(initial);
      final changed = hostKey(seed: 2);
      await mount(
        tester,
        HostVerificationPage(
          ledger: ledger,
          identity: changed,
          previous: security.hostTrusts.single,
        ),
      );
      expect(find.text('重新核实并替换信任'), findsNothing);
      await tap(tester, '开始独立重新核实');
      await tester.ensureVisible(find.text('重新核实并替换信任'));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '重新核实并替换信任'),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, '我已通过独立渠道核对主机、端口和完整指纹');
      await tap(tester, '重新核实并替换信任');
      expect(security.hostTrusts.single.publicKey, changed.publicKey);
      expect(auth.calls, 0);
    },
  );

  testWidgets('security pages support 390px and double text without overflow', (
    tester,
  ) async {
    final c = await credential(name: '长名称用于窄屏与大文字布局检查' * 3);
    final id = await server();
    await security.verifyHost(hostKey());
    for (final page in <Widget>[
      SecurityPage(ledger: ledger),
      CredentialForm(ledger: ledger, kind: CredentialKind.privateKey),
      CredentialDetailPage(ledger: ledger, credentialId: c.id),
      CredentialReferencesPage(ledger: ledger, credential: c),
      CredentialDeletePage(ledger: ledger, credential: c),
      SshConfigurationPage(ledger: ledger, serverId: id),
      HostTrustPage(ledger: ledger),
      HostTrustForm(ledger: ledger),
      HostVerificationPage(
        ledger: ledger,
        identity: hostKey(seed: 2),
        previous: security.hostTrusts.single,
      ),
    ]) {
      await mount(tester, page, scale: 2);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -650));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: page.runtimeType.toString(),
      );
    }
  });
}
