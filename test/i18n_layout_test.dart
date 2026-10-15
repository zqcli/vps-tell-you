import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/app.dart';
import 'package:vps_tell_you/core/ui/app_logo.dart';
import 'package:vps_tell_you/providers/provider_pages.dart';
import 'package:vps_tell_you/connections/connection_pages.dart';
import 'package:vps_tell_you/connections/snippet_pages.dart';
import 'package:vps_tell_you/connections/tcp_test_page.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/finance/calculator_page.dart';
import 'package:vps_tell_you/finance/finance_page.dart';
import 'package:vps_tell_you/finance/fx_page.dart';
import 'package:vps_tell_you/finance/payment_pages.dart';
import 'package:vps_tell_you/security/host_trust_pages.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_pages.dart';
import 'package:vps_tell_you/security/ssh_configuration_page.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_detail.dart';
import 'package:vps_tell_you/servers/server_form.dart';
import 'package:vps_tell_you/servers/server_list.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/settings/backup_page.dart';
import 'package:vps_tell_you/settings/reminder_page.dart';
import 'package:vps_tell_you/settings/settings_page.dart';

import 'support/reminder_platform.dart';

import 'package:vps_tell_you/l10n/generated/app_localizations.dart';

import 'security_store_test.dart' show FakeDeviceAuth, FakeSecretStore;

void main() {
  final evidence = Platform.environment['VPS_I18N_EVIDENCE_DIR'];
  // CI also uses a real bundled font for Latin metrics; the configured QA
  // run supplies the verified CJK subset for both languages.
  final fontPath =
      Platform.environment['VPS_I18N_FONT'] ??
      'assets/fonts/DejaVuSansMono.ttf';
  var fontsLoaded = false;
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late ServerRecord server;
  final now = DateTime(2026, 10, 7, 12);

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('i18n-layout-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.db',
      clock: () => now,
    );
    ledger = LedgerController(
      store,
      clock: () => now,
      reminderPlatform: FakeReminderPlatform()..supported = false,
      security: SecurityController(
        store: store,
        secrets: FakeSecretStore(),
        authenticator: FakeDeviceAuth(),
      ),
    );
    server = ServerRecord(
      id: 'copy-review-fixture',
      name: '文案审查演示服务器',
      vendor: '合成厂商',
      host: '192.0.2.10',
      purpose: '合成演示',
      billing: BillingKind.prepaid,
      currency: 'EUR',
      amountMinor: 2400,
      cycleMonths: 12,
      startDate: const LedgerDate(2026, 1, 1),
      dueDate: const LedgerDate(2027, 1, 1),
      createdAt: now,
      updatedAt: now,
      isDemo: true,
    );
    await store.saveServer(server, isNew: true);
    await ledger.refresh();
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester,
    Widget page, {
    double scale = 2,
    String locale = 'zh',
    Size size = const Size(320, 844),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    if (!fontsLoaded) {
      await tester.runAsync(() async {
        final loader = FontLoader('Copy Review CJK');
        loader.addFont(File(fontPath).readAsBytes().then(ByteData.sublistView));
        await loader.load();
        if (Platform.environment['FLUTTER_BOOTSTRAP_ROOT'] case final sdk?) {
          final icons = FontLoader('MaterialIcons');
          icons.addFont(
            File(
              '$sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes().then(ByteData.sublistView),
          );
          await icons.load();
        }
        fontsLoaded = true;
      });
    }
    final base = appTheme();
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: 'Copy Review CJK'),
          appBarTheme: base.appBarTheme.copyWith(
            titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
              fontFamily: 'Copy Review CJK',
            ),
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: const ValueKey('copy-evidence'),
            child: child,
          ),
        ),
        home: page,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (evidence == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('copy-evidence')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('$evidence/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> inspectPage(
    WidgetTester tester,
    String name,
    Widget page, {
    String locale = 'zh',
    Size size = const Size(320, 844),
  }) async {
    await mount(tester, page, locale: locale, size: size);
    await capture(tester, '$name-top-320x2');
    // Visit every vertical section, including lazily built rows, without
    // activating a network, system clipboard, picker, notification or keyring.
    for (var i = 0; i < 45; i++) {
      final scrollables = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .where(
            (state) =>
                state.axisDirection == AxisDirection.down &&
                state.position.hasContentDimensions,
          );
      if (scrollables.isEmpty) break;
      final state = scrollables.first;
      if (state.position.extentAfter <= 1) break;
      final target = (state.position.pixels + 430).clamp(
        0.0,
        state.position.maxScrollExtent,
      );
      state.position.jumpTo(target);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$name section $i');
      if (i == 3) await capture(tester, '$name-middle-320x2');
    }
    await capture(tester, '$name-bottom-320x2');
  }

  final pages = <String, Widget Function()>{
    'server-list': () => Scaffold(body: ServerList(controller: ledger)),
    'server-form': () => ServerForm(controller: ledger, record: server),
    'server-detail': () => ServerDetail(controller: ledger, id: server.id),
    'finance': () => Scaffold(body: FinancePage(controller: ledger)),
    'calculator': () => CalculatorPage(controller: ledger, server: server),
    'payment': () => PaymentForm(controller: ledger, server: server),
    'exchange-rates': () => FxPage(controller: ledger),
    'tools': () => Scaffold(body: ToolsPage(controller: ledger)),
    'settings': () => Scaffold(body: SettingsPage(controller: ledger)),
    'backup': () => BackupPage(controller: ledger),
    'reminder': () => ReminderPage(controller: ledger, serverId: server.id),
    'notification': () => NotificationPage(controller: ledger),
    'providers': () => ProvidersPage(ledger: ledger),
    'security': () => SecurityPage(ledger: ledger),
    'ssh-config': () =>
        SshConfigurationPage(ledger: ledger, serverId: server.id),
    'ssh-connect': () => SshConnectPage(ledger: ledger),
    'host-trust': () => HostTrustPage(ledger: ledger),
    'snippets': () => SnippetListPage(store: store),
    'tcp': () => const TcpTestPage(),
  };
  for (final locale in ['zh', 'en']) {
    for (final entry in pages.entries) {
      testWidgets('$locale ${entry.key} at 320px and 2x text', (tester) async {
        await inspectPage(
          tester,
          '$locale-${entry.key}',
          entry.value(),
          locale: locale,
        );
      });
    }
    for (final name in [
      'server-form',
      'settings',
      'calculator',
      'ssh-config',
    ]) {
      testWidgets('$locale $name landscape at 2x text', (tester) async {
        await inspectPage(
          tester,
          '$locale-$name-landscape',
          pages[name]!(),
          locale: locale,
          size: const Size(844, 320),
        );
      });
    }
    testWidgets('$locale settings banner shows the logo and slogan', (
      tester,
    ) async {
      await mount(
        tester,
        Scaffold(body: SettingsPage(controller: ledger)),
        locale: locale,
      );
      expect(find.byType(AppLogo), findsOneWidget);
      expect(
        find.text(
          locale == 'zh' ? '每台 VPS，心里有数' : 'Know every VPS at a glance',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('$locale language choice dialog at 320px and 2x text', (
      tester,
    ) async {
      await mount(
        tester,
        Scaffold(body: SettingsPage(controller: ledger)),
        locale: locale,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('language-setting')),
        300,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
      // The settings card is eagerly built inside a lazy outer list. Settle
      // updated extents before positioning its actual tap target.
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('language-setting')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('language-setting')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('language-setting')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('language-zh')), findsOneWidget);
      expect(find.byKey(const ValueKey('language-en')), findsOneWidget);
      expect(find.byKey(const ValueKey('language-system')), findsOneWidget);
      await capture(tester, '$locale-language-dialog-320x2');
    });
  }
}
