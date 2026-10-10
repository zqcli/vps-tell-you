import 'support/provider_fixture.dart';

import 'dart:io';

import 'package:vps_tell_you/cloud/cloud_widgets.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/cloud/server_cloud_binding_page.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'cloud_controller_test.dart'
    show CloudTestSecrets, ReloadFailCloudController;
import 'cloud_store_test.dart' show cloudTestTime, snapshot;

void main() {
  late Directory directory;
  late LedgerStore store;
  late CloudTestSecrets secrets;
  late ReloadFailCloudController cloud;
  late LedgerController ledger;
  bool? result;
  var adapterCalls = 0;

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('server-cloud-widget-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
      clock: () => cloudTestTime,
    );
    await addTestProvider(store);
    secrets = CloudTestSecrets();
    adapterCalls = 0;
    result = null;
    cloud = ReloadFailCloudController(
      store: store,
      secrets: secrets,
      adapterFactory: (_, _, _) {
        adapterCalls++;
        throw StateError('No API request is allowed on this page');
      },
    );
    ledger = LedgerController(
      store,
      cloud: cloud,
      security: SecurityController(store: store, secrets: secrets),
    );
    for (final id in ['local', 'other']) {
      await store.saveServer(
        ServerRecord(
          id: id,
          name: 'Local $id',
          vendor: 'Local vendor',
          providerId: testProvider.id,
          host: '192.0.2.99',
          createdAt: cloudTestTime,
          updatedAt: cloudTestTime,
        ),
        isNew: true,
      );
    }
    await ledger.refresh();
  });
  tearDown(() async {
    expect(adapterCalls, 0);
    expect(secrets.reads, 0);
    expect(secrets.writes, 0);
    expect(secrets.deletes, 0);
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> addAccount(
    String id, {
    CloudProvider provider = CloudProvider.solusVm2,
  }) async {
    final data = provider.isSingleInstance
        ? CloudSnapshot(
            provider: provider,
            completedAt: cloudTestTime,
            instances: [
              CloudInstance(
                observedAt: cloudTestTime,
                power: CloudPower.running,
                ipv4: '192.0.2.45',
              ),
            ],
          )
        : snapshot(name: 'Observed $id');
    final account = CloudAccount(
      id: id,
      provider: data.provider,
      businessProviderId: testProvider.id,
      authScope: adapterScope(data.provider),
      alias: 'Panel $id',
      endpoint: 'https://$id.panel.example',
      secretRef: 'opaque-$id',
      remoteAccountId: data.remoteAccountId,
      createdAt: cloudTestTime,
    );
    await store.reserveSecret(account.secretRef);
    await store.saveCloudAccount(
      account: account,
      snapshot: data,
      expected: null,
    );
    await cloud.reload();
  }

  Future<void> bind(String id, String accountId) async {
    final options = await store.serverCloudBindingOptions(id);
    await store.setServerCloudBinding(
      options,
      choice: options.choices.singleWhere((c) => c.accountId == accountId),
    );
    await cloud.reload();
  }

  Future<void> mount(WidgetTester tester, {double scale = 1}) async {
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
            body: Center(
              child: TextButton(
                child: const Text('Open binding'),
                onPressed: () async {
                  result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServerCloudBindingPage(
                        ledger: ledger,
                        serverId: 'local',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open binding'));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      await tester.scrollUntilVisible(
        target,
        250,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await reveal(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('empty saved accounts guide manual setup without network', (
    tester,
  ) async {
    await mount(tester);
    expect(
      find.text(AppLocalizationsZh().cloudNoSavedAccounts),
      findsOneWidget,
    );
    expect(
      find.text(AppLocalizationsZh().cloudLocalBindingInfo),
      findsOneWidget,
    );
    expect(await store.cloudBindings(), isEmpty);
  });

  testWidgets(
    'select saved account and observation binds the existing server',
    (tester) async {
      await addAccount('a');
      await mount(tester);
      await tapKey(tester, 'server-cloud-instance-a-7/2/3');
      await tapKey(tester, 'server-cloud-save');
      expect(result, isTrue);
      expect(find.text('Open binding'), findsOneWidget);
      expect(cloud.bindingFor('local')!.accountId, 'a');
      expect(await store.servers(), hasLength(2));
      expect(
        (await store.servers()).singleWhere((s) => s.id == 'local').host,
        '192.0.2.99',
      );
    },
  );

  testWidgets('occupied instance is labeled and disabled', (tester) async {
    await addAccount('a');
    await bind('other', 'a');
    await mount(tester);
    final target = find.byKey(const ValueKey('server-cloud-instance-a-7/2/3'));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(tester.widget<CloudCheckRow>(target).onChanged, isNull);
    expect(find.textContaining('已关联：Local other · 不可覆盖'), findsOneWidget);
    expect(
      tester
          .widget<AppButton>(find.byKey(const ValueKey('server-cloud-save')))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'RackNerd saved anonymous instance binds locally without credentials or API',
    (tester) async {
      await addAccount('rack', provider: CloudProvider.rackNerd);
      final before = (await store.servers())
          .singleWhere((server) => server.id == 'local')
          .toMap();
      await mount(tester, scale: 2);
      expect(find.textContaining('RackNerd ctrl'), findsOneWidget);
      await tapKey(tester, 'server-cloud-instance-rack-single');
      await tapKey(tester, 'server-cloud-save');
      expect(result, isTrue);
      expect(cloud.bindingFor('local')!.instanceKey, 'single');
      expect(cloud.bindingFor('local')!.observation.serverId, isNull);
      expect(cloud.bindingFor('local')!.observation.projectId, isNull);
      expect(cloud.accounts.single.authScope, AdapterAuthScope.singleDevice);
      expect(cloud.accounts.single.pinnedServerId, 'local');
      expect(
        (await store.servers())
            .singleWhere((server) => server.id == 'local')
            .toMap(),
        before,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'RackNerd single-device pin cannot be reassigned after a local unlink',
    (tester) async {
      await addAccount('rack', provider: CloudProvider.rackNerd);
      await bind('other', 'rack');
      final options = await store.serverCloudBindingOptions('other');
      await store.setServerCloudBinding(options, choice: null);
      await cloud.reload();
      expect(cloud.accounts.single.pinnedServerId, 'other');
      final before = (await store.servers()).map((s) => s.toMap()).toList();
      await mount(tester, scale: 2);
      final account = find.byKey(const ValueKey('server-cloud-account-rack'));
      await reveal(tester, account);
      expect(tester.widget<AppRow>(account).enabled, isFalse);
      expect(tester.widget<AppRow>(account).onTap, isNull);
      expect(
        find.textContaining(AppLocalizationsZh().adapterSingletonPinned),
        findsWidgets,
      );
      final instance = find.byKey(
        const ValueKey('server-cloud-instance-rack-single'),
      );
      await reveal(tester, instance);
      expect(tester.widget<CloudCheckRow>(instance).onChanged, isNull);
      final save = find.byKey(const ValueKey('server-cloud-save'));
      await reveal(tester, save);
      expect(tester.widget<AppButton>(save).onPressed, isNull);
      expect(await store.cloudBindings(), isEmpty);
      expect((await store.servers()).map((s) => s.toMap()).toList(), before);
      expect(cloud.accounts.single.pinnedServerId, 'other');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('leaving a selected draft makes no binding', (tester) async {
    await addAccount('a');
    await mount(tester);
    await tapKey(tester, 'server-cloud-instance-a-7/2/3');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(await store.cloudBindings(), isEmpty);
  });

  testWidgets(
    'replacement requires confirmation and cancellation retains original',
    (tester) async {
      await addAccount('a');
      await addAccount('b');
      await bind('local', 'a');
      await mount(tester);
      await tapKey(tester, 'server-cloud-account-b');
      await tapKey(tester, 'server-cloud-instance-b-7/2/3');
      await tapKey(tester, 'server-cloud-save');
      expect(find.text('更换这台服务器的面板关联？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect((await store.cloudBindings()).single.accountId, 'a');
      await tapKey(tester, 'server-cloud-save');
      await tester.tap(find.text('确认更换关联'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect((await store.cloudBindings()).single.accountId, 'b');
      expect(await store.cloudAccounts(), hasLength(2));
    },
  );

  testWidgets(
    'unlink cancellation and confirmation preserve account and observations',
    (tester) async {
      await addAccount('a');
      await bind('local', 'a');
      await mount(tester);
      await tapKey(tester, 'server-cloud-unbind');
      expect(find.text('解除这台服务器的面板关联？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(await store.cloudBindings(), hasLength(1));
      await tapKey(tester, 'server-cloud-unbind');
      await tester.tap(find.text('仅解除这台关联'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(await store.cloudBindings(), isEmpty);
      expect(await store.cloudAccounts(), hasLength(1));
      expect(
        (await store.serverCloudBindingOptions('local')).choices,
        hasLength(1),
      );
    },
  );

  testWidgets(
    'an outdated page cannot overwrite another binding and must reload',
    (tester) async {
      await addAccount('a');
      await addAccount('b');
      await mount(tester);
      await tapKey(tester, 'server-cloud-instance-a-7/2/3');
      await tester.runAsync(() => bind('local', 'b'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'server-cloud-save');
      expect((await store.cloudBindings()).single.accountId, 'b');
      expect(
        tester
            .widget<AppButton>(find.byKey(const ValueKey('server-cloud-save')))
            .onPressed,
        isNull,
      );
      await tapKey(tester, 'server-cloud-reload');
      expect(find.text('当前关联'), findsWidgets);
      expect(find.text('Observed b'), findsWidgets);
      expect(result, isNull);
    },
  );

  testWidgets(
    'committed reload failure stays saved and blocks duplicate save',
    (tester) async {
      await addAccount('a');
      await mount(tester);
      await tapKey(tester, 'server-cloud-instance-a-7/2/3');
      cloud.failReload = true;
      await tapKey(tester, 'server-cloud-save');
      expect(await store.cloudBindings(), hasLength(1));
      expect(find.byType(ServerCloudBindingPage), findsOneWidget);
      expect(
        tester
            .widget<AppButton>(find.byKey(const ValueKey('server-cloud-save')))
            .onPressed,
        isNull,
      );
      cloud.failReload = false;
      await tapKey(tester, 'server-cloud-reload');
      expect(result, isTrue);
      expect(find.text('Open binding'), findsOneWidget);
      expect(await store.cloudBindings(), hasLength(1));
    },
  );

  testWidgets('390px large text selection and confirmation do not overflow', (
    tester,
  ) async {
    await addAccount('a');
    await addAccount('b');
    await bind('local', 'a');
    await mount(tester, scale: 2);
    await tapKey(tester, 'server-cloud-account-b');
    await tapKey(tester, 'server-cloud-instance-b-7/2/3');
    await tapKey(tester, 'server-cloud-save');
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect((await store.cloudBindings()).single.accountId, 'a');
  });
}
