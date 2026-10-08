import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/cloud/cloud_pages.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';

import 'cloud_controller_test.dart' show CallbackCloudAdapter, CloudTestSecrets;
import 'cloud_store_test.dart' show cloudTestTime, snapshot;
import 'support/provider_fixture.dart';
import 'support/reminder_platform.dart';

void main() {
  late Directory directory;
  late LedgerStore store;
  late CloudController cloud;
  late LedgerController ledger;
  late CloudSnapshot data;
  Completer<CloudSnapshot>? readGate;

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('provider-final-review-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite',
      clock: () => cloudTestTime,
    );
    await addTestProvider(store);
    data = snapshot();
    readGate = null;
    final secrets = CloudTestSecrets();
    cloud = CloudController(
      store: store,
      secrets: secrets,
      adapterFactory: (_, _, _) =>
          CallbackCloudAdapter((_) async => readGate?.future ?? data),
    );
    ledger = LedgerController(
      store,
      cloud: cloud,
      security: SecurityController(store: store, secrets: secrets),
      reminderPlatform: FakeReminderPlatform(),
    );
    await ledger.refresh();
  });

  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<CloudVerification> verify() async => (await cloud.verifyConnection(
    provider: CloudProvider.solusVm2,
    businessProvider: testProvider,
    endpoint: 'https://panel.example',
    credentials: SolusVm2Credentials('synthetic-token'),
  ))!;

  Future<CloudInventory> save() async {
    final verified = await verify();
    expect(await cloud.saveAccount(verified, alias: 'Review adapter'), isTrue);
    return cloud.lastSavedInventory!;
  }

  Future<void> mount(
    WidgetTester tester,
    Widget page, {
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (rootContext) => Scaffold(
            body: TextButton(
              key: const ValueKey('review-root'),
              child: const Text('Open middle'),
              onPressed: () => Navigator.push<void>(
                rootContext,
                MaterialPageRoute(
                  builder: (middleContext) => Scaffold(
                    body: TextButton(
                      key: const ValueKey('review-middle'),
                      child: const Text('Open preview'),
                      onPressed: () => Navigator.push<bool>(
                        middleContext,
                        MaterialPageRoute(builder: (_) => page),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('review-root')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-middle')));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        400,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 30,
      );
    }
    await tester.ensureVisible(target);
    await tester.pump();
  }

  test(
    'oversized integer diskGiB cannot wrap into an apparently valid capacity',
    () {
      final resource = resourcesFromCloud(
        CloudInstance(
          observedAt: cloudTestTime,
          power: CloudPower.unknown,
          // Within the protocol DTO bound, but native byte multiplication
          // overflows a signed 64-bit int unless checked before scaling.
          diskGiB: 17179869185,
        ),
      );
      expect(resource.diskBytes, isNull);
      expect(resource.apiFields, isNot(contains('diskBytes')));
    },
  );

  testWidgets('repeated Done only closes the import preview once', (
    tester,
  ) async {
    data = snapshot(empty: true);
    final inventory = await save();
    await mount(tester, CloudImportPage(ledger: ledger, inventory: inventory));
    final done = find.byKey(const ValueKey('cloud-import-done'));
    await reveal(tester, done);
    final press = tester.widget<OutlinedButton>(done).onPressed!;
    press();
    press();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('review-middle')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-root')), findsNothing);
  });

  testWidgets(
    'a late inventory read does not open preview above a newer route',
    (tester) async {
      final inventory = await save();
      readGate = Completer<CloudSnapshot>();
      await mount(
        tester,
        CloudReadPage(
          ledger: ledger,
          account: inventory.account,
          importAfterRead: true,
        ),
        settle: false,
      );
      final context = tester.element(find.byType(CloudReadPage));
      unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Newer screen')),
          ),
        ),
      );
      await tester.pump();
      readGate!.complete(data);
      await tester.pumpAndSettle();
      expect(find.text('Newer screen'), findsOneWidget);
      expect(find.byType(CloudImportPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preview exposes cross-instance UUID conflict instead of declaring an existing match',
    (tester) async {
      final first = await save();
      final instance = first.snapshot.instances.single;
      final result = await cloud.importBatch(first, [
        CloudImportDraft(
          instanceKey: first.keyFor(instance),
          resources: resourcesFromCloud(instance),
        ),
      ]);
      expect(result!.importedCount, 1);
      await ledger.refresh();
      data = snapshot(uuid: 'different-remote-uuid');
      final verified = await verify();
      await mount(
        tester,
        CloudImportPage(
          ledger: ledger,
          verification: verified,
          alias: 'Conflicting adapter',
        ),
      );
      await reveal(tester, find.byKey(const ValueKey('cloud-select-7/2/3')));
      expect(find.text(AppLocalizationsEn().cloudImportExisting), findsNothing);
      expect(
        find.text(AppLocalizationsEn().cloudAccountFailureIdentity),
        findsOneWidget,
      );
      expect(await store.servers(), hasLength(1));
    },
  );

  testWidgets(
    'omitting UUID on refresh does not erase the source instances locked identity in preview',
    (tester) async {
      data = snapshot(uuid: 'old-source-uuid');
      final older = await save();
      data = snapshot(uuid: 'new-device-uuid');
      final newer = await save();
      final item = newer.snapshot.instances.single;
      final imported = await cloud.importBatch(newer, [
        CloudImportDraft(
          instanceKey: newer.keyFor(item),
          resources: resourcesFromCloud(item),
        ),
      ]);
      expect(imported!.importedCount, 1);
      data = snapshot(uuid: null);
      final refreshed = await cloud.refreshAccount(older.account);
      expect(refreshed, isNotNull);
      await ledger.refresh();
      // The DB still knows old-source-uuid, so it correctly rejects this
      // duplicate identity; omission in the newest DTO is not a reset.
      final attempted = await cloud.importBatch(refreshed!, [
        CloudImportDraft(
          instanceKey: refreshed.keyFor(refreshed.snapshot.instances.single),
          resources: resourcesFromCloud(refreshed.snapshot.instances.single),
        ),
      ]);
      expect(attempted!.existingCount, 0);
      expect(attempted.interruption, isNotNull);
      await mount(
        tester,
        CloudImportPage(ledger: ledger, inventory: refreshed),
      );
      await reveal(tester, find.byKey(const ValueKey('cloud-select-7/2/3')));
      expect(find.text(AppLocalizationsEn().cloudImportExisting), findsNothing);
      expect(
        find.text(AppLocalizationsEn().cloudAccountFailureIdentity),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'reauthorization preview detects changed source UUID even without a bound device',
    (tester) async {
      data = snapshot(uuid: 'locked-source-uuid');
      final original = await save();
      expect(await store.cloudBindings(), isEmpty);
      data = snapshot(uuid: 'changed-source-uuid');
      final verified = await cloud.verifyConnection(
        provider: CloudProvider.solusVm2,
        businessProvider: testProvider,
        endpoint: original.account.endpoint,
        credentials: SolusVm2Credentials('synthetic-replacement'),
        existing: original.account,
      );
      expect(verified, isNotNull);
      await mount(
        tester,
        CloudImportPage(
          ledger: ledger,
          verification: verified,
          alias: 'Changed source',
        ),
      );
      final select = find.byKey(const ValueKey('cloud-select-7/2/3'));
      await reveal(tester, select);
      expect(tester.widget<CheckboxListTile>(select).onChanged, isNull);
      expect(
        find.text(AppLocalizationsEn().cloudAccountFailureIdentity),
        findsOneWidget,
      );
    },
  );
}
