import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_widgets.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/cloud/cloud_pages.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';
import 'package:vps_tell_you/l10n/localized_message.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

import 'cloud_controller_test.dart' show CallbackCloudAdapter, CloudTestSecrets;
import 'support/provider_fixture.dart';
import 'support/reminder_platform.dart';

class _ImportUiCloud extends CloudController {
  _ImportUiCloud({
    required super.store,
    required super.secrets,
    required super.adapterFactory,
  });
  bool failReload = false,
      gateAfterFirst = false,
      wasCancelled = false,
      gateMetadata = false;
  final metadataStarted = Completer<void>();
  late Completer<void> metadataRelease;
  int saveCalls = 0;
  final batches = <List<String>>[];
  final batchStarted = Completer<void>();
  late Completer<void> batchRelease;
  String? gatedAccount;

  @override
  Future<void> readMetadata() async {
    if (failReload) throw StateError('synthetic local metadata failure');
    if (gateMetadata) {
      gateMetadata = false;
      metadataRelease = Completer<void>();
      metadataStarted.complete();
      await metadataRelease.future;
    }
    await super.readMetadata();
  }

  @override
  Future<bool> saveAccount(
    CloudVerification verification, {
    required String alias,
    Set<String> selectedInstanceKeys = const {},
    String? v1DisplayName,
    ServerResources? v1Resources,
    bool confirmV1Rebind = false,
  }) {
    saveCalls++;
    expect(
      selectedInstanceKeys,
      isEmpty,
      reason: 'Instance persistence is independent from device import.',
    );
    return super.saveAccount(
      verification,
      alias: alias,
      selectedInstanceKeys: selectedInstanceKeys,
      v1DisplayName: v1DisplayName,
      v1Resources: v1Resources,
      confirmV1Rebind: confirmV1Rebind,
    );
  }

  @override
  Future<CloudImportBatchResult?> importBatch(
    CloudInventory inventory,
    List<CloudImportDraft> drafts,
  ) async {
    batches.add(drafts.map((draft) => draft.instanceKey).toList());
    if (!gateAfterFirst) return super.importBatch(inventory, drafts);
    gateAfterFirst = false;
    batchRelease = Completer<void>();
    final first = (await super.importBatch(inventory, [drafts.first]))!;
    gatedAccount = inventory.account.id;
    batchStarted.complete();
    await batchRelease.future;
    return CloudImportBatchResult(
      items: first.items,
      failures: first.failures,
      unprocessed: drafts.skip(1).map((draft) => draft.instanceKey).toSet(),
      interruption: LocalizedText((l10n) => l10n.cloudImportCancelled),
    );
  }

  @override
  void cancelAccount(String accountId, {bool notify = true}) {
    if (accountId == gatedAccount) wasCancelled = true;
    super.cancelAccount(accountId, notify: notify);
  }
}

CloudSnapshot _inventory({
  List<int> ids = const [1, 2, 3],
  bool missing = false,
  bool v1 = false,
  String? uuid,
}) {
  final time = DateTime.utc(2026, 10, 8);
  return CloudSnapshot(
    provider: v1 ? CloudProvider.solusVm1 : CloudProvider.solusVm2,
    remoteAccountId: v1 ? null : 7,
    completedAt: time,
    instances: [
      for (final id in (v1 ? [1] : ids))
        CloudInstance(
          observedAt: time,
          power: CloudPower.running,
          projectId: v1 ? null : 2,
          serverId: v1 ? null : id,
          name: 'Device $id',
          uuid: uuid,
          ipv4: '192.0.2.$id',
          hostname: missing ? null : 'device-$id.example',
          vcpu: missing ? 0 : 2,
          ramBytes: 2147483648,
          diskBytes: 32212254720,
          trafficBytes: missing ? 0 : 1099511627776,
        ),
    ],
  );
}

void main() {
  late Directory directory;
  late LedgerStore store;
  late CloudTestSecrets secrets;
  late _ImportUiCloud cloud;
  late LedgerController ledger;
  late CloudSnapshot snapshot;
  late String path;
  int reads = 0;
  Object? routeResult;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp(
      'provider-import-preview-',
    );
    path = '${directory.path}/ledger.sqlite';
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
    );
    await addTestProvider(store);
    snapshot = _inventory();
    reads = 0;
    routeResult = 'not returned';
    secrets = CloudTestSecrets();
    cloud = _ImportUiCloud(
      store: store,
      secrets: secrets,
      adapterFactory: (_, _, _) => CallbackCloudAdapter((_) async {
        reads++;
        return snapshot;
      }),
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

  Future<CloudVerification> verification({bool v1 = false}) async =>
      (await cloud.verifyConnection(
        businessProvider: testProvider,
        provider: v1 ? CloudProvider.solusVm1 : CloudProvider.solusVm2,
        endpoint: 'https://panel.example',
        credentials: v1
            ? SolusVm1Credentials(key: 'fixture', hash: 'fixture')
            : SolusVm2Credentials('fixture'),
      ))!;

  Future<void> mount(
    WidgetTester tester,
    Widget page, {
    String locale = 'en',
    bool narrow = false,
    bool nested = false,
  }) async {
    tester.view.physicalSize = Size(narrow ? 320 : 390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(narrow ? 2 : 1)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('fixture-open'),
              onPressed: () async {
                if (nested) {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (middleContext) => Scaffold(
                        body: TextButton(
                          key: const ValueKey('fixture-middle'),
                          onPressed: () async {
                            routeResult = await Navigator.push<bool>(
                              middleContext,
                              MaterialPageRoute(builder: (_) => page),
                            );
                          },
                          child: const Text('Open preview'),
                        ),
                      ),
                    ),
                  );
                } else {
                  routeResult = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => page),
                  );
                }
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('fixture-open')));
    await tester.pumpAndSettle();
    if (nested) {
      await tester.tap(find.byKey(const ValueKey('fixture-middle')));
      await tester.pumpAndSettle();
    }
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    final scrolling = find.byType(Scrollable).first;
    if (target.evaluate().isEmpty) {
      tester.state<ScrollableState>(scrolling).position.jumpTo(0);
      await tester.pump();
      await tester.scrollUntilVisible(
        target,
        350,
        scrollable: scrolling,
        maxScrolls: 150,
      );
    }
    await tester.ensureVisible(target);
    await tester.pump();
  }

  Future<void> tap(
    WidgetTester tester,
    String key, {
    bool settle = true,
  }) async {
    final target = find.byKey(ValueKey(key));
    await reveal(tester, target);
    await tester.tap(target);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> fill(WidgetTester tester, String key, String value) async {
    final target = find.byKey(ValueKey(key));
    await reveal(tester, target);
    await tester.enterText(target, value);
    await tester.pump();
  }

  Future<void> selectAll(
    WidgetTester tester, {
    List<int> ids = const [1, 2, 3],
  }) async {
    for (final id in ids) {
      await tap(tester, 'cloud-select-7/2/$id');
    }
  }

  Future<void> trigger(String condition) async {
    final db = await databaseFactoryFfiNoIsolate.openDatabase(path);
    await db.execute(
      "CREATE TRIGGER fail_ui_import BEFORE INSERT ON servers WHEN $condition BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
    );
  }

  Future<void> clearTrigger() async {
    final db = await databaseFactoryFfiNoIsolate.openDatabase(path);
    await db.execute('DROP TRIGGER fail_ui_import');
  }

  Future<void> expectSummary(WidgetTester tester, String summary) async {
    await reveal(tester, find.byKey(const ValueKey('cloud-import-results')));
    expect(find.text(summary), findsOneWidget);
  }

  for (final locale in ['en', 'zh']) {
    testWidgets(
      'V2 missing resources complete on separate eager form at 320px 2x ($locale)',
      (tester) async {
        snapshot = _inventory(
          ids: List.generate(30, (index) => index + 1),
          missing: true,
        );
        final verified = await verification();
        await mount(
          tester,
          CloudImportPage(
            ledger: ledger,
            verification: verified,
            alias: 'Local adapter',
          ),
          locale: locale,
          narrow: true,
        );
        final select = find.byKey(const ValueKey('cloud-select-7/2/1'));
        await reveal(tester, select);
        expect(tester.widget<CloudCheckRow>(select).onChanged, isNull);
        // A row that cannot be selected yet stays fully legible.
        final palette = tester.element(select).palette;
        final title = find.descendant(
          of: select,
          matching: find.text('Device 1'),
        );
        expect(tester.widget<Text>(title.first).style!.color, palette.text);
        final address = find.descendant(
          of: select,
          matching: find.text('192.0.2.1'),
        );
        expect(tester.widget<Text>(address).style!.color, palette.text2);
        await tap(tester, 'cloud-complete-7/2/1');
        await tap(tester, 'cloud-resource-done');
        expect(cloud.saveCalls, 0);
        await fill(tester, 'resource-hostname', 'completed.example');
        await fill(tester, 'resource-vcpu', '2');
        await fill(tester, 'resource-trafficBytes', '1024');
        await fill(tester, 'resource-ip', '192.0.2.200');
        await tap(tester, 'cloud-resource-done');
        await reveal(tester, select);
        expect(tester.widget<CloudCheckRow>(select).value, isTrue);
        await tap(tester, 'cloud-complete-7/2/30');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tap(tester, 'cloud-complete-7/2/1');
        await reveal(tester, find.byKey(const ValueKey('resource-hostname')));
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('resource-hostname')),
              )
              .controller!
              .text,
          'completed.example',
        );
        await tap(tester, 'cloud-resource-done');
        await tap(tester, 'cloud-import-submit');
        expect(cloud.saveCalls, 1);
        expect(secrets.writes, 1);
        expect(reads, 1);
        expect(ledger.active, hasLength(1));
        final resources = ledger.active.single.resources!;
        expect(resources.apiFields, {'ramBytes', 'diskBytes'});
        expect(resources.trafficUnlimited, isFalse);
        expect(cloud.bindings.single.observation.hostname, isNull);
        expect(cloud.bindings.single.observation.trafficBytes, 0);
        expect(await store.payments(), isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'saved adapter survives all failed imports and Back reports its commit',
    (tester) async {
      final verified = await verification();
      await trigger('1 = 1');
      await mount(
        tester,
        CloudImportPage(
          ledger: ledger,
          verification: verified,
          alias: 'Kept adapter',
        ),
      );
      await selectAll(tester);
      await tap(tester, 'cloud-import-submit');
      await expectSummary(
        tester,
        AppLocalizationsEn().cloudImportSummary(0, 0, 1, 2),
      );
      expect(verified.isCommitted, isTrue);
      expect(cloud.accounts, hasLength(1));
      expect(await store.servers(), isEmpty);
      expect(secrets.writes, 1);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(routeResult, isTrue);
      expect(find.byKey(const ValueKey('fixture-open')), findsOneWidget);
      expect(cloud.saveCalls, 1);
    },
  );

  testWidgets(
    'partial retry preserves successes and never repeats credential persistence',
    (tester) async {
      final verified = await verification();
      await trigger("NEW.name = 'Device 2'");
      await mount(
        tester,
        CloudImportPage(
          ledger: ledger,
          verification: verified,
          alias: 'Kept adapter',
        ),
      );
      await selectAll(tester);
      await tap(tester, 'cloud-import-submit');
      await expectSummary(
        tester,
        AppLocalizationsEn().cloudImportSummary(1, 0, 1, 1),
      );
      final firstId = ledger.active.single.id;
      await clearTrigger();
      final retry = find.byKey(const ValueKey('cloud-import-retry'));
      await reveal(tester, retry);
      await tester.tap(retry);
      await tester.tap(retry, warnIfMissed: false);
      await tester.pumpAndSettle();
      await expectSummary(
        tester,
        AppLocalizationsEn().cloudImportSummary(3, 0, 0, 0),
      );
      expect(cloud.batches, [
        ['7/2/1', '7/2/2', '7/2/3'],
        ['7/2/2', '7/2/3'],
      ]);
      expect(ledger.active.map((server) => server.id), contains(firstId));
      expect(ledger.active, hasLength(3));
      expect(cloud.saveCalls, 1);
      expect(secrets.writes, 1);
      expect(reads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'committed metadata reread failure requires explicit local reload before the batch',
    (tester) async {
      final verified = await verification();
      await mount(
        tester,
        CloudImportPage(
          ledger: ledger,
          verification: verified,
          alias: 'Committed adapter',
        ),
      );
      await selectAll(tester);
      cloud.failReload = true;
      await tap(tester, 'cloud-import-submit');
      expect(verified.isCommitted, isTrue);
      expect((await store.cloudAccounts()).length, 1);
      expect(await store.servers(), isEmpty);
      expect(cloud.batches, isEmpty);
      expect(secrets.writes, 1);
      await expectSummary(
        tester,
        AppLocalizationsEn().cloudImportSummary(0, 0, 0, 3),
      );
      await reveal(tester, find.byKey(const ValueKey('cloud-import-retry')));
      expect(
        tester
            .widget<AppButton>(find.byKey(const ValueKey('cloud-import-retry')))
            .onPressed,
        isNull,
      );
      cloud.failReload = false;
      await tap(tester, 'cloud-import-reload');
      expect(
        cloud.batches,
        isEmpty,
        reason: 'Local reload must not silently import old selections.',
      );
      await tap(tester, 'cloud-import-retry');
      expect(ledger.active, hasLength(3));
      expect(cloud.saveCalls, 1);
      expect(secrets.writes, 1);
      expect(reads, 1);
    },
  );

  testWidgets(
    'stop and Back while importing keep committed results without duplicate submission',
    (tester) async {
      final verified = await verification();
      cloud.gateAfterFirst = true;
      await mount(
        tester,
        CloudImportPage(
          ledger: ledger,
          verification: verified,
          alias: 'Cancelable adapter',
        ),
      );
      await selectAll(tester);
      final submit = find.byKey(const ValueKey('cloud-import-submit'));
      await reveal(tester, submit);
      await tester.tap(submit);
      await tester.tap(submit, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(cloud.batchStarted.isCompleted, isTrue);
      expect(cloud.batches, hasLength(1));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CloudImportPage), findsOneWidget);
      await tap(tester, 'cloud-import-cancel');
      expect(cloud.wasCancelled, isTrue);
      cloud.batchRelease.complete();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await expectSummary(
        tester,
        AppLocalizationsEn().cloudImportSummary(1, 0, 0, 2),
      );
      expect(ledger.active, hasLength(1));
      expect(cloud.saveCalls, 1);
      expect(secrets.writes, 1);
      await tap(tester, 'cloud-import-retry');
      expect(ledger.active, hasLength(3));
      expect(cloud.batches.last, ['7/2/2', '7/2/3']);
    },
  );

  testWidgets(
    'Back from an unsaved preview consumes no secret and invalidates its verification',
    (tester) async {
      final verified = await verification();
      await mount(
        tester,
        CloudImportPage(
          ledger: ledger,
          verification: verified,
          alias: 'Discarded adapter',
        ),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(verified.cancellation.isCancelled, isTrue);
      expect(verified.isCommitted, isFalse);
      expect(secrets.writes, 0);
      expect(await store.cloudAccounts(), isEmpty);
      expect(
        await cloud.saveAccount(verified, alias: 'Must not save'),
        isFalse,
      );
    },
  );

  for (final locale in ['en', 'zh']) {
    testWidgets(
      'empty V2 read can save an adapter without device or finance creation ($locale)',
      (tester) async {
        snapshot = _inventory(ids: const []);
        final verified = await verification();
        await mount(
          tester,
          CloudImportPage(
            ledger: ledger,
            verification: verified,
            alias: 'Empty adapter',
          ),
          locale: locale,
          narrow: true,
        );
        final strings = locale == 'en'
            ? AppLocalizationsEn()
            : AppLocalizationsZh();
        await reveal(tester, find.text(strings.cloudEmptyVerification));
        expect(find.text(strings.cloudEmptyVerification), findsOneWidget);
        await tap(tester, 'cloud-save-only');
        expect(routeResult, isTrue);
        expect(verified.isCommitted, isTrue);
        expect(cloud.accounts, hasLength(1));
        expect(await store.servers(), isEmpty);
        expect(await store.payments(), isEmpty);
        expect(secrets.writes, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'completion repeated callback and Back cannot pop the import preview',
    (tester) async {
      snapshot = _inventory(ids: const [1]);
      final verified = await verification();
      await mount(
        tester,
        CloudImportPage(
          ledger: ledger,
          verification: verified,
          alias: 'Draft adapter',
        ),
      );
      await tap(tester, 'cloud-complete-7/2/1');
      final done = find.byKey(const ValueKey('cloud-resource-done'));
      await reveal(tester, done);
      final finish = tester.widget<AppButton>(done).onPressed!;
      finish();
      finish();
      await tester.pumpAndSettle();
      expect(find.byType(CloudImportPage), findsOneWidget);
      expect(routeResult, 'not returned');
      expect(tester.takeException(), isNull);
      await tap(tester, 'cloud-complete-7/2/1');
      await reveal(tester, done);
      final staleFinish = tester.widget<AppButton>(done).onPressed!;
      Navigator.of(tester.element(done)).pop();
      staleFinish();
      await tester.pumpAndSettle();
      expect(find.byType(CloudImportPage), findsOneWidget);
      expect(secrets.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'route closing during committed metadata reload never starts a late batch',
    (tester) async {
      final verified = await verification();
      await mount(
        tester,
        CloudImportPage(
          ledger: ledger,
          verification: verified,
          alias: 'Committed adapter',
        ),
      );
      await selectAll(tester);
      cloud.gateMetadata = true;
      await tap(tester, 'cloud-import-submit');
      expect(cloud.metadataStarted.isCompleted, isTrue);
      expect(verified.isCommitted, isTrue);
      final context = tester.element(find.byType(CloudImportPage));
      Navigator.of(context).pop();
      cloud.metadataRelease.complete();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(cloud.batches, isEmpty);
      expect(await store.cloudAccounts(), hasLength(1));
      expect(await store.servers(), isEmpty);
      expect(secrets.writes, 1);
      expect(find.byKey(const ValueKey('fixture-open')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('retry respects deselected unfinished devices', (tester) async {
    final verified = await verification();
    await trigger("NEW.name = 'Device 2'");
    await mount(
      tester,
      CloudImportPage(
        ledger: ledger,
        verification: verified,
        alias: 'Selective retry',
      ),
    );
    await selectAll(tester);
    await tap(tester, 'cloud-import-submit');
    await clearTrigger();
    await tap(tester, 'cloud-select-7/2/3');
    await tap(tester, 'cloud-import-retry');
    await expectSummary(
      tester,
      AppLocalizationsEn().cloudImportSummary(2, 0, 0, 1),
    );
    expect(cloud.batches.last, ['7/2/2']);
    expect(ledger.active, hasLength(2));
    await reveal(tester, find.byKey(const ValueKey('cloud-import-retry')));
    expect(
      tester
          .widget<AppButton>(find.byKey(const ValueKey('cloud-import-retry')))
          .onPressed,
      isNull,
    );
    await tap(tester, 'cloud-select-7/2/3');
    await tap(tester, 'cloud-import-retry');
    expect(ledger.active, hasLength(3));
    expect(cloud.batches.last, ['7/2/3']);
    expect(cloud.saveCalls, 1);
    expect(secrets.writes, 1);
  });

  testWidgets(
    'new V2 adapter preview recognizes archived stable identity without merging addresses',
    (tester) async {
      snapshot = _inventory(ids: const [1]);
      final first = await verification();
      expect(
        await cloud.saveAccount(first, alias: 'First authorization'),
        isTrue,
      );
      final inventory = cloud.lastSavedInventory!;
      expect(
        (await cloud.importBatch(inventory, [
          CloudImportDraft(
            instanceKey: '7/2/1',
            resources: resourcesFromCloud(snapshot.instances.single),
          ),
        ]))!.importedCount,
        1,
      );
      await ledger.refresh();
      await store.archive(ledger.active.single);
      await ledger.refresh();
      final next = await verification();
      await mount(
        tester,
        CloudImportPage(
          ledger: ledger,
          verification: next,
          alias: 'Separate authorization',
        ),
      );
      final checkbox = find.byKey(const ValueKey('cloud-select-7/2/1'));
      await reveal(tester, checkbox);
      expect(tester.widget<CloudCheckRow>(checkbox).value, isTrue);
      expect(tester.widget<CloudCheckRow>(checkbox).onChanged, isNull);
      final existing = AppLocalizationsEn().cloudRecordWithState(
        'Device 1',
        AppLocalizationsEn().cloudArchivedSuffix,
      );
      await reveal(tester, find.text(existing));
      expect(find.text(existing), findsOneWidget);
      expect(await store.servers(), hasLength(1));
      expect(secrets.writes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final backFirst in [false, true]) {
    testWidgets('Done is one-shot even after Back ($backFirst)', (
      tester,
    ) async {
      snapshot = _inventory(ids: const []);
      final verified = await verification();
      expect(
        await cloud.saveAccount(verified, alias: 'Saved empty adapter'),
        isTrue,
      );
      await mount(
        tester,
        CloudImportPage(ledger: ledger, inventory: cloud.lastSavedInventory!),
        nested: true,
      );
      final done = find.byKey(const ValueKey('cloud-import-done'));
      await reveal(tester, done);
      final finish = tester.widget<AppButton>(done).onPressed!;
      if (backFirst) {
        await tester.binding.handlePopRoute();
      } else {
        finish();
      }
      finish();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('fixture-middle')), findsOneWidget);
      expect(find.byKey(const ValueKey('fixture-open')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('expired preview return callback cannot pop its parent twice', (
    tester,
  ) async {
    final verified = await verification();
    await mount(
      tester,
      CloudImportPage(
        ledger: ledger,
        verification: verified,
        alias: 'Expired adapter',
      ),
      nested: true,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    final back = find.byKey(const ValueKey('cloud-import-return-verify'));
    await reveal(tester, back);
    final finish = tester.widget<AppButton>(back).onPressed!;
    finish();
    finish();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fixture-middle')), findsOneWidget);
    expect(find.byKey(const ValueKey('fixture-open')), findsNothing);
    expect(verified.cancellation.isCancelled, isTrue);
    expect(secrets.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved read Done callback cannot pop its parent twice', (
    tester,
  ) async {
    snapshot = _inventory(ids: const []);
    final verified = await verification();
    expect(await cloud.saveAccount(verified, alias: 'Read adapter'), isTrue);
    await mount(
      tester,
      CloudReadPage(
        ledger: ledger,
        account: cloud.accounts.single,
        importAfterRead: false,
      ),
      nested: true,
    );
    final done = find.byKey(const ValueKey('cloud-read-done'));
    await reveal(tester, done);
    final finish = tester.widget<AppButton>(done).onPressed!;
    finish();
    finish();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fixture-middle')), findsOneWidget);
    expect(find.byKey(const ValueKey('fixture-open')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final missingOnRefresh in [false, true]) {
    testWidgets(
      'V2 preview blocks locked UUID conflict after omitted observation ($missingOnRefresh)',
      (tester) async {
        snapshot = _inventory(ids: const [1], uuid: 'original-remote-uuid');
        final first = await verification();
        expect(
          await cloud.saveAccount(first, alias: 'First authorization'),
          isTrue,
        );
        final inventory = cloud.lastSavedInventory!;
        expect(
          (await cloud.importBatch(inventory, [
            CloudImportDraft(
              instanceKey: '7/2/1',
              resources: resourcesFromCloud(snapshot.instances.single),
            ),
          ]))!.importedCount,
          1,
        );
        await ledger.refresh();
        final serverId = ledger.active.single.id;
        if (missingOnRefresh) {
          snapshot = _inventory(ids: const [1]);
          expect(await cloud.refreshAccount(cloud.accounts.single), isNotNull);
          expect(cloud.bindings.single.observation.uuid, isNull);
        }
        snapshot = _inventory(ids: const [1], uuid: 'different-remote-uuid');
        final conflicting = await verification();
        await mount(
          tester,
          CloudImportPage(
            ledger: ledger,
            verification: conflicting,
            alias: 'Conflicting authorization',
          ),
        );
        final checkbox = find.byKey(const ValueKey('cloud-select-7/2/1'));
        await reveal(tester, checkbox);
        expect(tester.widget<CloudCheckRow>(checkbox).value, isFalse);
        expect(tester.widget<CloudCheckRow>(checkbox).onChanged, isNull);
        expect(
          find.text(AppLocalizationsEn().cloudImportExisting),
          findsNothing,
        );
        await reveal(
          tester,
          find.text(AppLocalizationsEn().cloudAccountFailureIdentity),
        );
        expect(
          find.text(AppLocalizationsEn().cloudAccountFailureIdentity),
          findsOneWidget,
        );
        await reveal(tester, find.widgetWithText(AppRow, 'Device 1'));
        expect(find.widgetWithText(AppRow, 'Device 1'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('cloud-complete-7/2/1')),
          findsNothing,
        );
        await reveal(tester, find.byKey(const ValueKey('cloud-import-submit')));
        expect(
          tester
              .widget<AppButton>(
                find.byKey(const ValueKey('cloud-import-submit')),
              )
              .onPressed,
          isNull,
        );
        expect((await store.servers()).single.id, serverId);
        expect(cloud.batches, hasLength(1));
        expect(secrets.writes, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'reauthorization UUID conflict blocks an unbound source before selecting any device',
    (tester) async {
      snapshot = _inventory(ids: const [1], uuid: 'locked-source-uuid');
      final first = await verification();
      expect(await cloud.saveAccount(first, alias: 'Unbound source'), isTrue);
      final source = cloud.accounts.single;
      snapshot = _inventory(ids: const [1], uuid: 'changed-source-uuid');
      final verified = (await cloud.verifyConnection(
        provider: CloudProvider.solusVm2,
        businessProvider: testProvider,
        endpoint: source.endpoint,
        credentials: SolusVm2Credentials('renewed-fixture'),
        existing: source,
      ))!;
      await mount(
        tester,
        CloudImportPage(
          ledger: ledger,
          verification: verified,
          alias: 'Reauthorized source',
        ),
      );
      final checkbox = find.byKey(const ValueKey('cloud-select-7/2/1'));
      await reveal(tester, checkbox);
      expect(tester.widget<CloudCheckRow>(checkbox).value, isFalse);
      expect(tester.widget<CloudCheckRow>(checkbox).onChanged, isNull);
      expect(find.text(AppLocalizationsEn().cloudImportExisting), findsNothing);
      await reveal(
        tester,
        find.text(AppLocalizationsEn().cloudAccountFailureIdentity),
      );
      expect(
        find.text(AppLocalizationsEn().cloudAccountFailureIdentity),
        findsOneWidget,
      );
      await reveal(tester, find.byKey(const ValueKey('cloud-import-submit')));
      expect(
        tester
            .widget<AppButton>(
              find.byKey(const ValueKey('cloud-import-submit')),
            )
            .onPressed,
        isNull,
      );
      expect(cloud.batches, isEmpty);
      expect(cloud.bindings, isEmpty);
      expect(await store.servers(), isEmpty);
      expect(secrets.writes, 1);
    },
  );

  testWidgets('V1 pin after unlink disables importing another device', (
    tester,
  ) async {
    snapshot = _inventory(v1: true);
    final verified = await verification(v1: true);
    expect(await cloud.saveAccount(verified, alias: 'Pinned adapter'), isTrue);
    final inventory = cloud.lastSavedInventory!;
    expect(
      (await cloud.importBatch(inventory, [
        CloudImportDraft(
          instanceKey: 'single',
          resources: resourcesFromCloud(snapshot.instances.single),
        ),
      ]))!.importedCount,
      1,
    );
    await ledger.refresh();
    final original = ledger.active.single;
    final options = (await cloud.serverBindingOptions(original.id))!;
    expect(await cloud.setServerBinding(options), isTrue);
    await ledger.refresh();
    final saved = cloud.accounts.single;
    await mount(
      tester,
      CloudImportPage(
        ledger: ledger,
        inventory: CloudInventory(account: saved, snapshot: snapshot),
      ),
    );
    final checkbox = find.byKey(const ValueKey('cloud-select-single'));
    await reveal(tester, checkbox);
    expect(tester.widget<CloudCheckRow>(checkbox).onChanged, isNull);
    await reveal(
      tester,
      find.text(AppLocalizationsEn().providerUiPinnedHelp(original.name)),
    );
    expect(
      find.text(AppLocalizationsEn().providerUiPinnedHelp(original.name)),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('resource-vcpu')), findsNothing);
    expect(await store.servers(), hasLength(1));
    expect(secrets.writes, 1);
  });
}
