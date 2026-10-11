import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_widgets.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/cloud/server_cloud_binding_page.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'cloud_controller_test.dart' show CloudTestSecrets;
import 'cloud_store_test.dart' show cloudTestTime, snapshot;
import 'support/reminder_platform.dart';

void main() {
  final north = ProviderRecord(
    id: 'north',
    name: 'North Provider',
    createdAt: cloudTestTime,
  );
  final south = ProviderRecord(
    id: 'south',
    name: 'South Provider',
    createdAt: cloudTestTime,
  );
  late Directory directory;
  late LedgerStore store;
  late CloudController cloud;
  late CloudTestSecrets secrets;
  late LedgerController ledger;
  late ValueNotifier<Locale> locale;
  var adapterCalls = 0;
  bool? result;

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('binding-provider-ui-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite',
      clock: () => cloudTestTime,
    );
    await store.saveProvider(north, isNew: true);
    await store.saveProvider(south, isNew: true);
    secrets = CloudTestSecrets();
    adapterCalls = 0;
    result = null;
    cloud = CloudController(
      store: store,
      secrets: secrets,
      adapterFactory: (_, _, _) {
        adapterCalls++;
        throw StateError('Local binding must not construct an API adapter');
      },
    );
    ledger = LedgerController(
      store,
      cloud: cloud,
      security: SecurityController(store: store, secrets: secrets),
      reminderPlatform: FakeReminderPlatform()..supported = false,
    );
    locale = ValueNotifier(const Locale('en'));
  });

  tearDown(() async {
    expect(adapterCalls, 0);
    expect(secrets.reads, 0);
    expect(secrets.writes, 0);
    expect(secrets.deletes, 0);
    locale.dispose();
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<Database> raw() => databaseFactoryFfiNoIsolate.openDatabase(
    '${directory.path}/ledger.sqlite',
  );

  Future<void> server(String id, {ProviderRecord? provider}) =>
      store.saveServer(
        ServerRecord(
          id: id,
          name: 'Local $id',
          vendor: provider?.name ?? '',
          providerId: provider?.id,
          host: '192.0.2.99',
          notes: 'Manual details',
          createdAt: cloudTestTime,
          updatedAt: cloudTestTime,
        ),
        isNew: true,
      );

  Future<void> account(
    String id,
    ProviderRecord provider, {
    bool v1 = false,
  }) async {
    final data = snapshot(name: 'Observed $id', v1: v1);
    final account = CloudAccount(
      id: id,
      provider: data.provider,
      businessProviderId: provider.id,
      authScope: adapterScope(data.provider),
      alias: 'Adapter $id',
      endpoint: 'https://$id.panel.example',
      secretRef: 'synthetic-only-$id',
      remoteAccountId: data.remoteAccountId,
      createdAt: cloudTestTime,
    );
    await store.reserveSecret(account.secretRef);
    await store.saveCloudAccount(
      account: account,
      snapshot: data,
      expected: null,
    );
  }

  Future<void> bind(String serverId, String accountId) async {
    final options = await store.serverCloudBindingOptions(serverId);
    await store.setServerCloudBinding(
      options,
      choice: options.choices.singleWhere((c) => c.accountId == accountId),
    );
  }

  Future<void> mount(
    WidgetTester tester, {
    String serverId = 'local',
    double width = 390,
    double scale = 1,
    bool refresh = true,
  }) async {
    if (refresh) await ledger.refresh();
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (_, current, _) => MaterialApp(
          theme: appTheme(),
          locale: current,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServerCloudBindingPage(
                        ledger: ledger,
                        serverId: serverId,
                      ),
                    ),
                  );
                },
                child: const Text('Open binding fixture'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open binding fixture'));
    await tester.pumpAndSettle();
  }

  Future<Finder> reveal(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    if (target.evaluate().isEmpty) {
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      await tester.scrollUntilVisible(
        target,
        240,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 50,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    return target;
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(await reveal(tester, key));
    await tester.pumpAndSettle();
  }

  Future<void> saveDisabled(WidgetTester tester) async {
    final target = await reveal(tester, 'server-cloud-save');
    expect(tester.widget<AppButton>(target).onPressed, isNull);
  }

  testWidgets(
    'unassigned manual server must choose ownership before any adapter',
    (tester) async {
      await server('local');
      await account('north', north);
      await account('south', south);
      await mount(tester);
      expect(
        find.text(
          'Assign a provider in server details before choosing a panel connection to link.',
        ),
        findsOneWidget,
      );
      expect(find.byType(CloudCheckRow), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key as ValueKey<String>).value.startsWith(
                'server-cloud-account-',
              ),
        ),
        findsNothing,
      );
      await saveDisabled(tester);
      await tap(tester, 'server-cloud-reload');
      await saveDisabled(tester);
      final record = (await store.servers()).single;
      expect(record.providerId, isNull);
      expect(record.vendor, isEmpty);
      expect(record.host, '192.0.2.99');
      expect(record.notes, 'Manual details');
      expect(await store.cloudBindings(), isEmpty);
    },
  );

  testWidgets(
    'only confirmed same-provider saved accounts can link an existing server',
    (tester) async {
      await server('local', provider: north);
      await account('north', north);
      await account('south', south);
      await mount(tester);
      await reveal(tester, 'server-cloud-account-north');
      expect(
        find.byKey(const ValueKey('server-cloud-account-south')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('server-cloud-instance-south-7/2/3')),
        findsNothing,
      );
      await tap(tester, 'server-cloud-instance-north-7/2/3');
      await tap(tester, 'server-cloud-save');
      expect(result, isTrue);
      final record = (await store.servers()).single;
      expect(record.providerId, north.id);
      expect(record.host, '192.0.2.99');
      expect(record.notes, 'Manual details');
      expect((await store.cloudBindings()).single.accountId, 'north');
    },
  );

  testWidgets(
    'pending ownership is reread locally and keeps existing unlink available',
    (tester) async {
      await server('local', provider: north);
      await account('north', north);
      await account('south', south);
      await bind('local', 'north');
      await ledger.refresh();
      final db = await raw();
      await db.update(
        'providers',
        {'needs_review': 1},
        where: 'id = ?',
        whereArgs: [north.id],
      );
      // Do not refresh the controller: opening the page must reread the local
      // confirmation state rather than trust its previous provider metadata.
      await mount(tester, refresh: false);
      expect(
        find.textContaining('Confirm this panel connection’s provider'),
        findsOneWidget,
      );
      expect(find.text('Observed north'), findsOneWidget);
      expect(find.byType(CloudCheckRow), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key as ValueKey<String>).value.startsWith(
                'server-cloud-account-',
              ),
        ),
        findsNothing,
      );
      await saveDisabled(tester);
      await tap(tester, 'server-cloud-reload');
      final unlink = await reveal(tester, 'server-cloud-unbind');
      expect(tester.widget<AppRow>(unlink).onTap, isNotNull);
      await tester.tap(unlink);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await store.cloudBindings(), hasLength(1));
      await tap(tester, 'server-cloud-unbind');
      await tester.tap(find.text('Unlink Only This Server'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(await store.cloudBindings(), isEmpty);
      expect(await store.cloudAccounts(), hasLength(2));
      expect(
        (await store.serverCloudBindingOptions('local')).choices,
        hasLength(2),
      );
      expect((await store.servers()).single.providerId, north.id);
    },
  );

  testWidgets('unknown authorization scope is visible but disabled', (
    tester,
  ) async {
    await server('local', provider: north);
    await account('north', north);
    final db = await raw();
    await db.update(
      'cloud_accounts',
      {'auth_scope': 'unknown'},
      where: 'id = ?',
      whereArgs: ['north'],
    );
    await mount(tester);
    final row = await reveal(tester, 'server-cloud-account-north');
    expect(tester.widget<AppRow>(row).onTap, isNull);
    expect(
      find.textContaining('authorization scope is unverified'),
      findsWidgets,
    );
    final item = await reveal(tester, 'server-cloud-instance-north-7/2/3');
    expect(tester.widget<CloudCheckRow>(item).onChanged, isNull);
    await saveDisabled(tester);
    expect(await store.cloudBindings(), isEmpty);
  });

  testWidgets(
    'unknown scope retains current observation and permits local unlink',
    (tester) async {
      await server('local', provider: north);
      await account('north', north);
      await bind('local', 'north');
      final db = await raw();
      await db.update(
        'cloud_accounts',
        {'auth_scope': 'unknown'},
        where: 'id = ?',
        whereArgs: ['north'],
      );
      await mount(tester);
      expect(find.text('Observed north'), findsWidgets);
      await saveDisabled(tester);
      await tap(tester, 'server-cloud-unbind');
      await tester.tap(find.text('Unlink Only This Server'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(await store.cloudBindings(), isEmpty);
      expect(
        (await store.cloudAccounts()).single.authScope,
        AdapterAuthScope.unknown,
      );
    },
  );

  testWidgets(
    'unlinked singleton remains disabled for another server with a pin reason',
    (tester) async {
      await server('local', provider: north);
      await server('original', provider: north);
      await account('single', north, v1: true);
      await bind('original', 'single');
      await store.setServerCloudBinding(
        await store.serverCloudBindingOptions('original'),
      );
      await mount(tester);
      final row = await reveal(tester, 'server-cloud-account-single');
      expect(tester.widget<AppRow>(row).onTap, isNull);
      expect(
        find.textContaining('pinned to another local server'),
        findsWidgets,
      );
      final item = await reveal(tester, 'server-cloud-instance-single-single');
      expect(tester.widget<CloudCheckRow>(item).onChanged, isNull);
      await saveDisabled(tester);
      expect(await store.cloudBindings(), isEmpty);
      expect((await store.cloudAccounts()).single.pinnedServerId, 'original');
    },
  );

  testWidgets('an unlinked singleton may return to its original server', (
    tester,
  ) async {
    await server('local', provider: north);
    await account('single', north, v1: true);
    await bind('local', 'single');
    await store.setServerCloudBinding(
      await store.serverCloudBindingOptions('local'),
    );
    await mount(tester);
    await tap(tester, 'server-cloud-instance-single-single');
    await tap(tester, 'server-cloud-save');
    expect(result, isTrue);
    expect((await store.cloudBindings()).single.serverId, 'local');
    expect((await store.cloudAccounts()).single.pinnedServerId, 'local');
  });

  for (final state in ['stale', 'missing', 'failure']) {
    testWidgets('$state saved observations remain disabled with a reason', (
      tester,
    ) async {
      await server('local', provider: north);
      await account('north', north);
      final db = await raw();
      if (state == 'failure') {
        await db.update(
          'cloud_accounts',
          {'last_failure': 'unavailable'},
          where: 'id = ?',
          whereArgs: ['north'],
        );
      } else {
        await db.update('cloud_observations', {state: 1});
      }
      await mount(tester);
      final item = await reveal(tester, 'server-cloud-instance-north-7/2/3');
      expect(tester.widget<CloudCheckRow>(item).onChanged, isNull);
      final strings = AppLocalizations.of(tester.element(item));
      expect(
        find.textContaining(
          state == 'missing'
              ? strings.cloudMissingRefresh
              : strings.cloudFailedRefresh,
        ),
        findsWidgets,
      );
      await saveDisabled(tester);
      expect(await store.cloudBindings(), isEmpty);
    });
  }

  testWidgets('local reload clears a draft after provider ownership changes', (
    tester,
  ) async {
    await server('local', provider: north);
    await account('north', north);
    await account('south', south);
    await mount(tester);
    await tap(tester, 'server-cloud-instance-north-7/2/3');
    await tester.runAsync(() async {
      await store.setServerProvider(
        await store.serverCloudBindingOptions('local'),
        south.id,
      );
    });
    await tap(tester, 'server-cloud-reload');
    final item = await reveal(tester, 'server-cloud-instance-south-7/2/3');
    expect(tester.widget<CloudCheckRow>(item).value, isFalse);
    expect(
      find.byKey(const ValueKey('server-cloud-account-north')),
      findsNothing,
    );
    await saveDisabled(tester);
    await tap(tester, 'server-cloud-instance-south-7/2/3');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(await store.cloudBindings(), isEmpty);
    expect((await store.servers()).single.providerId, south.id);
  });

  testWidgets('narrow bilingual binding draft preserves selection and fits', (
    tester,
  ) async {
    await server('local', provider: north);
    await account('north', north);
    await mount(tester, width: 320, scale: 2);
    await tap(tester, 'server-cloud-instance-north-7/2/3');
    expect(tester.takeException(), isNull);
    locale.value = const Locale('zh');
    await tester.pumpAndSettle();
    final item = await reveal(tester, 'server-cloud-instance-north-7/2/3');
    expect(tester.widget<CloudCheckRow>(item).value, isTrue);
    await reveal(tester, 'server-cloud-save');
    expect(tester.takeException(), isNull);
    expect(await store.cloudBindings(), isEmpty);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
