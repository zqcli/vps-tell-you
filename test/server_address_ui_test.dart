import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/connections/tcp_test_page.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/ssh_configuration_page.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_detail.dart';
import 'package:vps_tell_you/servers/server_list.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

import 'security_store_test.dart' show FakeDeviceAuth, FakeSecretStore;

/// Where the server's address shows up now that there is no host field:
/// `ServerRecord.primaryAddress` (IPv4, IPv6, hostname, legacy host).
void main() {
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  final now = DateTime.utc(2026, 10, 6);

  Future<void> seed(
    String id, {
    String host = '',
    ServerResources? resources,
  }) => store.saveServer(
    ServerRecord(
      id: id,
      name: 'srv-$id',
      vendor: '',
      host: host,
      resources: resources,
      createdAt: now,
      updatedAt: now,
    ),
    isNew: true,
  );

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('server-address-ui-');
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
    // a: legacy host equal to the IPv4 (what the old mirroring stored).
    await seed(
      'a',
      host: '192.0.2.10',
      resources: ServerResources(ip: '192.0.2.10', hostname: 'a.example'),
    );
    // b: only an old host value, never edited.
    await seed('b', host: 'legacy.example');
    // c: IPv6 only.
    await seed('c', resources: ServerResources(ipv6: '2001:db8::c'));
    // d: legacy host that differs from the IPv4 (kept, shown, not preferred).
    await seed(
      'd',
      host: 'old.example',
      resources: ServerResources(ip: '198.51.100.7'),
    );
    // e: nothing at all.
    await seed('e');
    await ledger.refresh();
    await ledger.security.initialize();
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: home,
      ),
    );
    await tester.pumpAndSettle();
  }

  String? copied;
  void mockClipboard(WidgetTester tester) {
    copied = null;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
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
  }

  test('primaryAddress of the seeded records', () {
    expect(ledger.byId('a')!.primaryAddress, '192.0.2.10');
    expect(ledger.byId('b')!.primaryAddress, 'legacy.example');
    expect(ledger.byId('c')!.primaryAddress, '2001:db8::c');
    expect(ledger.byId('d')!.primaryAddress, '198.51.100.7');
    expect(ledger.byId('e')!.primaryAddress, isEmpty);
  });

  group('detail page', () {
    testWidgets('no separate address row when the hardware tiles show it', (
      tester,
    ) async {
      await mount(tester, ServerDetail(controller: ledger, id: 'a'));
      expect(find.byKey(const ValueKey('server-saved-address')), findsNothing);
      expect(find.byKey(const ValueKey('server-copy-host')), findsNothing);
      expect(find.text('Host address'), findsNothing);
      expect(find.text('192.0.2.10'), findsOneWidget, reason: 'IPv4 tile');
    });

    testWidgets('an old host that fits no field is still shown, and copies', (
      tester,
    ) async {
      mockClipboard(tester);
      await mount(tester, ServerDetail(controller: ledger, id: 'b'));
      final card = find.byKey(const ValueKey('server-saved-address'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Saved address')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('legacy.example')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('server-saved-address-copy')));
      await tester.pumpAndSettle();
      expect(copied, 'legacy.example');
    });

    testWidgets('a differing old host is shown next to the hardware IPv4', (
      tester,
    ) async {
      await mount(tester, ServerDetail(controller: ledger, id: 'd'));
      expect(
        find.byKey(const ValueKey('server-saved-address')),
        findsOneWidget,
      );
      expect(find.text('198.51.100.7'), findsOneWidget);
    });

    for (final (id, expected) in [
      ('a', '192.0.2.10'),
      ('b', 'legacy.example'),
      ('c', '2001:db8::c'),
      ('d', '198.51.100.7'),
    ]) {
      testWidgets('Copy Address copies $expected for $id', (tester) async {
        mockClipboard(tester);
        await mount(tester, ServerDetail(controller: ledger, id: id));
        await tester.tap(find.byTooltip('More Actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Copy Address'));
        await tester.pumpAndSettle();
        expect(copied, expected);
        expect(find.text('Address copied'), findsOneWidget);
      });
    }

    testWidgets('no address: no copy action', (tester) async {
      await mount(tester, ServerDetail(controller: ledger, id: 'e'));
      await tester.tap(find.byTooltip('More Actions'));
      await tester.pumpAndSettle();
      expect(find.text('Copy Address'), findsNothing);
    });

    testWidgets('TCP test opens with the primary address', (tester) async {
      await mount(tester, ServerDetail(controller: ledger, id: 'c'));
      final row = find.byKey(const ValueKey('server-quick-tcp'));
      await tester.scrollUntilVisible(
        row,
        300,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axis == Axis.vertical,
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(TcpTestPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TcpTestPage),
          matching: find.widgetWithText(TextField, '2001:db8::c'),
        ),
        findsOneWidget,
      );
    });
  });

  group('list', () {
    testWidgets('long press menu names and copies the primary address', (
      tester,
    ) async {
      mockClipboard(tester);
      await mount(tester, Scaffold(body: ServerList(controller: ledger)));
      await tester.longPress(find.byKey(const ValueKey('server-d')));
      await tester.pumpAndSettle();
      expect(find.text('srv-d · 198.51.100.7'), findsOneWidget);
      await tester.tap(find.text('Copy Address'));
      await tester.pumpAndSettle();
      expect(copied, '198.51.100.7');
    });

    testWidgets('a server without an address has no copy action', (
      tester,
    ) async {
      await mount(tester, Scaffold(body: ServerList(controller: ledger)));
      await tester.longPress(find.byKey(const ValueKey('server-e')));
      await tester.pumpAndSettle();
      expect(find.text('srv-e'), findsWidgets);
      expect(find.text('Copy Address'), findsNothing);
    });

    test('search finds IPv4, IPv6, hostname and an old host', () {
      List<String> find(String q) {
        ledger.search = q;
        return ledger.visible.map((s) => s.id).toList()..sort();
      }

      expect(find('192.0.2.10'), ['a']);
      expect(find('a.example'), ['a'], reason: 'hardware hostname');
      expect(find('2001:db8::c'), ['c']);
      expect(find('legacy.example'), ['b'], reason: 'old host');
      expect(find('old.example'), ['d']);
    });
  });

  group('SSH configuration', () {
    testWidgets('the host defaults to the primary address, not the old host', (
      tester,
    ) async {
      await mount(tester, SshConfigurationPage(ledger: ledger, serverId: 'd'));
      expect(
        tester
            .widget<AppTextField>(find.byKey(const ValueKey('ssh-host')))
            .controller!
            .text,
        '198.51.100.7',
      );
    });

    testWidgets('an own SSH host is required and stays separate', (
      tester,
    ) async {
      await mount(tester, SshConfigurationPage(ledger: ledger, serverId: 'e'));
      expect(
        tester
            .widget<AppTextField>(find.byKey(const ValueKey('ssh-host')))
            .controller!
            .text,
        isEmpty,
      );
    });
  });
}
