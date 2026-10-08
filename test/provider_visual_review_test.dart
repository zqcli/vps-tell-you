import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/cloud/cloud_pages.dart';
import 'package:vps_tell_you/cloud/provider_pages.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';

import 'cloud_controller_test.dart' show CloudTestSecrets;
import 'cloud_store_test.dart' show snapshot, cloudTestTime;
import 'support/provider_fixture.dart';
import 'support/reminder_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  var fontsLoaded = false;
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late CloudInventory inventory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('provider-visual-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.db',
    );
    await addTestProvider(store);
    final provider2 = ProviderRecord(
      id: 'second',
      name: 'Second Provider',
      createdAt: cloudTestTime,
    );
    await store.saveProvider(provider2, isNew: true);
    final data = CloudSnapshot(
      provider: CloudProvider.solusVm2,
      remoteAccountId: 7,
      completedAt: cloudTestTime,
      instances: [
        snapshot(server: 1).instances.single,
        CloudInstance(
          observedAt: cloudTestTime,
          power: CloudPower.running,
          projectId: 2,
          serverId: 2,
          name: 'Build server',
          ipv4: '192.0.2.20',
          hostname: 'build.example',
          vcpu: 2,
          ramBytes: 0,
          diskBytes: 0,
          trafficBytes: 0,
        ),
        snapshot(server: 3, name: 'Ready server').instances.single,
      ],
    );
    final account = CloudAccount(
      id: 'account',
      provider: CloudProvider.solusVm2,
      businessProviderId: testProvider.id,
      authScope: AdapterAuthScope.account,
      alias: 'Amsterdam · Account API',
      endpoint: 'https://panel.example',
      secretRef: 'opaque-synthetic-only',
      remoteAccountId: 7,
      createdAt: cloudTestTime,
    );
    await store.reserveSecret(account.secretRef);
    await store.saveCloudAccount(
      account: account,
      snapshot: data,
      expected: null,
      selectedInstanceKeys: {'7/2/1'},
    );
    final secrets = CloudTestSecrets();
    ledger = LedgerController(
      store,
      cloud: CloudController(
        store: store,
        secrets: secrets,
        adapterFactory: (_, _, _) =>
            throw StateError('Visual fixtures never contact a panel'),
      ),
      security: SecurityController(store: store, secrets: secrets),
      reminderPlatform: FakeReminderPlatform(),
    );
    await ledger.refresh();
    inventory = CloudInventory(
      account: ledger.cloud.accounts.single,
      snapshot: data,
    );
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester,
    Widget page, {
    required String locale,
    required double width,
    required double scale,
    required Brightness brightness,
  }) async {
    final fontPath = Platform.environment['VPS_PROVIDER_REVIEW_FONT'];
    if (fontPath != null && !fontsLoaded) {
      await tester.runAsync(() async {
        final loader = FontLoader('Provider review font');
        loader.addFont(
          Future.value(
            ByteData.sublistView(await File(fontPath).readAsBytes()),
          ),
        );
        await loader.load();
        final root = Platform.environment['FLUTTER_BOOTSTRAP_ROOT'];
        if (root != null) {
          final icons = FontLoader('MaterialIcons');
          icons.addFont(
            Future.value(
              ByteData.sublistView(
                await File(
                  '$root/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
                ).readAsBytes(),
              ),
            ),
          );
          await icons.load();
        }
      });
      fontsLoaded = true;
    }
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final base = appTheme(brightness: brightness);
    final theme = fontPath == null
        ? base
        : base.copyWith(
            appBarTheme: base.appBarTheme.copyWith(
              titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
                fontFamily: 'Provider review font',
              ),
              toolbarTextStyle: base.appBarTheme.toolbarTextStyle?.copyWith(
                fontFamily: 'Provider review font',
              ),
            ),
            textTheme: base.textTheme.apply(fontFamily: 'Provider review font'),
            primaryTextTheme: base.primaryTextTheme.apply(
              fontFamily: 'Provider review font',
            ),
          );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: const ValueKey('provider-visual'),
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => page),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 30,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    expect(tester.takeException(), isNull);
    final destination = Platform.environment['VPS_PROVIDER_VISUAL_DIR'];
    if (destination == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('provider-visual')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$destination/$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  for (final locale in ['zh', 'en']) {
    for (final scene in [
      'providers',
      'provider-detail',
      'adapter-detail',
      'add-method',
      'import-preview',
      'completion',
      'adapter-menu',
    ]) {
      testWidgets(
        '$locale $scene uses the existing theme with readable narrow layout',
        (tester) async {
          final narrow = scene == 'completion' || scene == 'provider-detail';
          final dark = narrow || scene == 'add-method';
          final Widget page = switch (scene) {
            'providers' => ProvidersPage(ledger: ledger),
            'provider-detail' => ProviderDetailsPage(
              ledger: ledger,
              providerId: testProvider.id,
            ),
            'adapter-detail' || 'adapter-menu' => CloudAccountDetailsPage(
              ledger: ledger,
              accountId: inventory.account.id,
            ),
            'add-method' => AddServerPage(
              ledger: ledger,
              provider: testProvider,
            ),
            _ => CloudImportPage(ledger: ledger, inventory: inventory),
          };
          await mount(
            tester,
            page,
            locale: locale,
            width: narrow ? 320 : 390,
            scale: narrow ? 2 : 1,
            brightness: dark ? Brightness.dark : Brightness.light,
          );
          if (scene == 'completion') {
            final target = find.byKey(const ValueKey('cloud-complete-7/2/2'));
            await reveal(tester, target);
            await tester.tap(target);
            await tester.pumpAndSettle();
          }
          if (scene == 'adapter-menu') {
            final target = find.byKey(const ValueKey('cloud-instance-menu'));
            await reveal(tester, target);
            await tester.tap(target);
            await tester.pumpAndSettle();
          }
          await capture(
            tester,
            '$locale-$scene-${narrow ? '320x2' : '390x1'}-${dark ? 'dark' : 'light'}',
          );
          if (scene == 'import-preview' || scene == 'completion') {
            final target = find.byKey(
              ValueKey(
                scene == 'completion'
                    ? 'cloud-resource-done'
                    : 'cloud-import-submit',
              ),
            );
            await reveal(tester, target);
            await capture(
              tester,
              '$locale-$scene-bottom-${narrow ? '320x2' : '390x1'}',
            );
          }
        },
      );
    }
  }
}
