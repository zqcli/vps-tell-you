import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/connections/tcp_test.dart';
import 'package:vps_tell_you/connections/tcp_test_page.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/security/proxy_models.dart';
import 'package:vps_tell_you/security/proxy_pages.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/security/ssh_configuration_page.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_detail.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'security_store_test.dart' show FakeDeviceAuth, FakeSecretStore;
import 'support/fake_proxy.dart';

void main() {
  final en = AppLocalizationsEn();
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late SecurityController security;
  late FakeSecretStore secrets;
  late FakeDeviceAuth auth;
  late ServerRecord server;

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('proxy-widget-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.db',
    );
    secrets = FakeSecretStore();
    auth = FakeDeviceAuth();
    security = SecurityController(
      store: store,
      secrets: secrets,
      authenticator: auth,
    );
    ledger = LedgerController(store, security: security);
    final now = DateTime.utc(2026, 10, 6);
    server = ServerRecord(
      id: 's1',
      name: 'Tokyo box',
      vendor: 'fixture',
      host: '192.0.2.1',
      createdAt: now,
      updatedAt: now,
    );
    await store.saveServer(server, isNew: true);
    await ledger.refresh();
    await security.initialize();
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => page),
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

  /// Rows below the fold are not built yet by the lazy page list.
  Future<void> show(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String key, String text) async {
    final field = find.byKey(ValueKey(key));
    await show(tester, field);
    await tester.enterText(field, text);
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await show(tester, target);
    if (key == 'proxy-reveal') {
      // Keep it clear of the floating bottom bar.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
      await tester.pumpAndSettle();
    }
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text).last;
    await show(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<String> addProxy({
    String name = 'Office',
    ProxyKind kind = ProxyKind.socks5,
    String? user,
    String? pass,
  }) async {
    final id = await security.saveProxy(
      name: name,
      kind: kind,
      host: 'proxy.example.com',
      port: kind.defaultPort,
      username: user,
      password: pass,
    );
    return id!;
  }

  group('Proxies list and form', () {
    testWidgets('empty list explains scope and offers Add', (tester) async {
      await mount(tester, ProxyListPage(ledger: ledger));
      expect(find.text(en.r13ProxyEmpty), findsOneWidget);
      expect(find.text(en.r13ProxyListFooter), findsOneWidget);
      expect(find.byKey(const ValueKey('proxy-add')), findsOneWidget);
    });

    testWidgets('adding a proxy: type switches the default port, saves', (
      tester,
    ) async {
      await mount(tester, ProxyListPage(ledger: ledger));
      await tapKey(tester, 'proxy-add');
      expect(find.text(en.r13ProxyAdd), findsWidgets);
      await tapText(tester, 'HTTPS');
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const ValueKey('proxy-port')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        '443',
      );
      await tapText(tester, 'HTTP');
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const ValueKey('proxy-port')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        '8080',
      );
      await tapText(tester, 'SOCKS5');
      await fill(tester, 'proxy-name', 'Office');
      await fill(tester, 'proxy-host', 'proxy.example.com');
      await fill(tester, 'proxy-username', 'alice');
      await fill(tester, 'proxy-password', 'hunter2');
      await tapKey(tester, 'proxy-save');
      expect(security.proxies.single.name, 'Office');
      expect(security.proxies.single.kind, ProxyKind.socks5);
      expect(security.proxies.single.port, 1080);
      expect(security.proxies.single.username, 'alice');
      expect(
        secrets.values.values.where((v) => v.contains('hunter2')),
        hasLength(1),
      );
      expect(find.text('Office'), findsOneWidget);
      expect(find.textContaining('hunter2'), findsNothing);
    });

    testWidgets('validation messages appear and nothing is saved', (
      tester,
    ) async {
      await mount(tester, ProxyListPage(ledger: ledger));
      await tapKey(tester, 'proxy-add');
      await fill(tester, 'proxy-port', '0');
      await fill(tester, 'proxy-username', 'alice');
      await tapKey(tester, 'proxy-save');
      expect(find.text(en.r13ProxyNameRequired), findsOneWidget);
      expect(find.text(en.connectionValidHost), findsOneWidget);
      expect(find.text(en.securityPortRequired), findsOneWidget);
      expect(find.text(en.securityLoginPasswordRequired), findsOneWidget);
      expect(security.proxies, isEmpty);
    });

    testWidgets('a long, bracketed IPv6 host is accepted', (tester) async {
      await mount(tester, ProxyForm(ledger: ledger));
      await fill(tester, 'proxy-name', 'v6');
      await fill(tester, 'proxy-host', '[2001:db8::1]');
      await tapKey(tester, 'proxy-save');
      expect(security.proxies.single.host, '2001:db8::1');
    });

    testWidgets('reveal needs device authentication', (tester) async {
      final id = await addProxy(user: 'alice', pass: 'visible-secret');
      await security.reload();
      await mount(
        tester,
        ProxyForm(ledger: ledger, existing: security.proxyById(id)),
      );
      final shown = find.byKey(const ValueKey('revealed-proxy-password'));
      Future<String> text() async {
        await show(tester, shown);
        return tester.widget<Text>(shown).data!;
      }

      expect(await text(), isNot(contains('visible-secret')));
      auth.allowed = false;
      await tapKey(tester, 'proxy-reveal');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(await text(), isNot(contains('visible-secret')));
      expect(auth.calls, 1);
      auth.allowed = true;
      await tapKey(tester, 'proxy-reveal');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(await text(), 'visible-secret');
      await tapKey(tester, 'proxy-reveal');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle(); // Hide
      expect(await text(), isNot(contains('visible-secret')));
    });

    testWidgets('delete is blocked while SSH settings use the proxy', (
      tester,
    ) async {
      final id = await addProxy();
      await store.saveSshConfiguration(
        SshConfiguration(
          serverId: 's1',
          host: 'h.example.com',
          username: 'root',
          proxyId: id,
        ),
      );
      await security.reload();
      await mount(
        tester,
        ProxyForm(ledger: ledger, existing: security.proxyById(id)),
      );
      expect(find.text(en.r13ProxyDeleteBlocked(1)), findsOneWidget);
      await tapKey(tester, 'proxy-delete');
      expect(find.text(en.r13ProxyDeleteTitle), findsNothing);
      expect(security.proxies, hasLength(1));
    });

    testWidgets('delete asks first, then removes proxy and secret', (
      tester,
    ) async {
      final id = await addProxy(user: 'alice', pass: 'secret');
      await security.reload();
      await mount(
        tester,
        ProxyForm(ledger: ledger, existing: security.proxyById(id)),
      );
      await tapKey(tester, 'proxy-delete');
      expect(find.text(en.r13ProxyDeleteTitle), findsOneWidget);
      await tapText(tester, en.r13ProxyDelete);
      expect(security.proxies, isEmpty);
      expect(
        secrets.values.keys.where((k) => k.startsWith('vps_proxy_')),
        isEmpty,
      );
    });
  });

  group('SSH settings', () {
    testWidgets('picker: Direct, saved proxies, New Proxy…', (tester) async {
      final id = await addProxy(name: 'Office');
      await security.reload();
      await mount(tester, SshConfigurationPage(ledger: ledger, serverId: 's1'));
      await fill(tester, 'ssh-username', 'root');
      await show(tester, find.byKey(const ValueKey('ssh-proxy-row')));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('ssh-proxy-row')),
          matching: find.text(en.r13ProxyDirect),
        ),
        findsOneWidget,
      );
      await tapKey(tester, 'ssh-proxy-row');
      expect(find.byKey(const ValueKey('proxy-option-direct')), findsOneWidget);
      expect(find.byKey(ValueKey('proxy-option-$id')), findsOneWidget);
      expect(find.byKey(const ValueKey('proxy-option-new')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('proxy-option-$id')));
      await tester.pumpAndSettle();
      expect(find.text('Office'), findsOneWidget);
      await tester.tap(find.text(en.securitySaveSshConfiguration));
      await tester.pumpAndSettle();
      expect(security.configFor('s1')!.proxyId, id);
    });

    testWidgets('New Proxy… creates and selects it; Direct clears it', (
      tester,
    ) async {
      await mount(tester, SshConfigurationPage(ledger: ledger, serverId: 's1'));
      await fill(tester, 'ssh-username', 'root');
      await tapKey(tester, 'ssh-proxy-row');
      await tester.tap(find.byKey(const ValueKey('proxy-option-new')));
      await tester.pumpAndSettle();
      await fill(tester, 'proxy-name', 'Fresh');
      await fill(tester, 'proxy-host', 'fresh.example.com');
      await tapKey(tester, 'proxy-save');
      expect(security.proxies.single.name, 'Fresh');
      await show(tester, find.byKey(const ValueKey('ssh-proxy-row')));
      expect(find.text('Fresh'), findsOneWidget);
      await tester.tap(find.text(en.securitySaveSshConfiguration));
      await tester.pumpAndSettle();
      expect(security.configFor('s1')!.proxyId, security.proxies.single.id);

      // Reopen: shows the proxy; choosing Direct and saving clears it.
      await mount(tester, SshConfigurationPage(ledger: ledger, serverId: 's1'));
      await show(tester, find.byKey(const ValueKey('ssh-proxy-row')));
      expect(find.text('Fresh'), findsOneWidget);
      await tapKey(tester, 'ssh-proxy-row');
      await tester.tap(find.byKey(const ValueKey('proxy-option-direct')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.securitySaveSshConfiguration));
      await tester.pumpAndSettle();
      expect(security.configFor('s1')!.proxyId, isNull);
    });

    testWidgets('server detail says "via <proxy>" on the SSH row', (
      tester,
    ) async {
      final id = await addProxy(name: 'Office');
      await store.saveSshConfiguration(
        SshConfiguration(
          serverId: 's1',
          host: 'h.example.com',
          username: 'root',
          proxyId: id,
        ),
      );
      await security.reload();
      await mount(tester, ServerDetail(controller: ledger, id: 's1'));
      final row = find.byKey(const ValueKey('server-ssh-settings'));
      await show(tester, row);
      expect(
        find.descendant(
          of: row,
          matching: find.textContaining(en.r13ProxyVia('Office')),
        ),
        findsOneWidget,
      );
    });
  });

  group('TCP test page', () {
    late ServerSocket echo;
    FakeProxy? proxy;
    setUp(() async {
      echo = await ServerSocket.bind('127.0.0.1', 0);
      echo.listen((c) => c.listen((_) {}, onError: (Object _) {}));
    });
    tearDown(() async {
      await echo.close();
      await proxy?.close();
      proxy = null;
    });

    Future<void> pumpReal(WidgetTester tester) async {
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('default is Direct; the row is there', (tester) async {
      await mount(tester, TcpTestPage(ledger: ledger));
      final row = find.byKey(const ValueKey('tcp-proxy-row'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text(en.r13ProxyDirect)),
        findsOneWidget,
      );
    });

    testWidgets(
      'Enter Proxy… is temporary: result says via proxy and what it proves',
      (tester) async {
        await tester.runAsync(() async {
          proxy = await FakeProxy.start(ProxyKind.socks5);
        });
        final controller = TcpTestController();
        addTearDown(controller.dispose);
        await mount(
          tester,
          TcpTestPage(
            ledger: ledger,
            controller: controller,
            initialHost: '127.0.0.1',
            initialPort: echo.port,
          ),
        );
        await tapKey(tester, 'tcp-proxy-row');
        await tester.tap(find.byKey(const ValueKey('proxy-option-temporary')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('proxy-name')), findsNothing);
        await fill(tester, 'proxy-host', '127.0.0.1');
        await fill(tester, 'proxy-port', '${proxy!.port}');
        await fill(tester, 'proxy-username', 'u');
        await fill(tester, 'proxy-password', 'temp-pass');
        await tapKey(tester, 'proxy-save');
        expect(find.text(en.r13TcpProxyFooter), findsOneWidget);
        // Nothing is persisted for a temporary proxy.
        expect(security.proxies, isEmpty);
        expect(secrets.values, isEmpty);

        await tester.tap(find.text(en.tcpStart));
        await pumpReal(tester);
        expect(controller.result?.outcome, TcpOutcome.connected);
        expect(controller.result!.viaProxy, isTrue);
        expect(find.byKey(const ValueKey('tcp-proxied-note')), findsOneWidget);
        expect(
          find.textContaining('SOCKS5 127.0.0.1:${proxy!.port}'),
          findsWidgets,
        );
        expect(find.text(en.r13TcpProxyAddress), findsOneWidget);
        expect(secrets.values, isEmpty);
      },
    );

    testWidgets(
      'a saved proxy is used with its stored password; failures show the reason',
      (tester) async {
        await tester.runAsync(() async {
          proxy = await FakeProxy.start(
            ProxyKind.socks5,
            options: const FakeProxyOptions(username: 'u', password: 'right'),
          );
        });
        late String id;
        await tester.runAsync(() async {
          id = (await security.saveProxy(
            name: 'Office',
            kind: ProxyKind.socks5,
            host: '127.0.0.1',
            port: proxy!.port,
            username: 'u',
            password: 'wrong',
          ))!;
        });
        final controller = TcpTestController();
        addTearDown(controller.dispose);
        await mount(
          tester,
          TcpTestPage(
            ledger: ledger,
            controller: controller,
            initialHost: '127.0.0.1',
            initialPort: echo.port,
          ),
        );
        await tapKey(tester, 'tcp-proxy-row');
        await tester.tap(find.byKey(ValueKey('proxy-option-$id')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(en.tcpStart));
        await pumpReal(tester);
        expect(controller.result?.outcome, TcpOutcome.failed);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('tcp-proxy-reason')),
            matching: find.text(en.r13ProxyAuthRejected),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('tcp-proxied-note')), findsNothing);
      },
    );

    testWidgets('changing the proxy clears the previous result', (
      tester,
    ) async {
      final id = await addProxy(name: 'Office');
      await security.reload();
      final controller = TcpTestController();
      addTearDown(controller.dispose);
      await mount(
        tester,
        TcpTestPage(
          ledger: ledger,
          controller: controller,
          initialHost: '127.0.0.1',
          initialPort: echo.port,
        ),
      );
      await tester.tap(find.text(en.tcpStart));
      await pumpReal(tester);
      expect(controller.result, isNotNull);
      await tapKey(tester, 'tcp-proxy-row');
      await tester.tap(find.byKey(ValueKey('proxy-option-$id')));
      await tester.pumpAndSettle();
      expect(controller.result, isNull);
    });
  });
}
