import 'dart:io';

import 'package:flutter/cupertino.dart'
    show CupertinoAlertDialog, CupertinoDialogAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/cloud/cloud_pages.dart';
import 'package:vps_tell_you/cloud/provider_pages.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_detail.dart';
import 'package:vps_tell_you/servers/server_form.dart';
import 'package:vps_tell_you/servers/server_list.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

import 'security_store_test.dart' show FakeSecretStore, FakeDeviceAuth;
import 'support/reminder_platform.dart';

class _Ledger extends LedgerController {
  _Ledger(super.store, {required super.cloud, required super.security})
    : super(reminderPlatform: FakeReminderPlatform()..supported = false);
  bool failReload = false;
  @override
  Future<void> refresh() async {
    if (failReload) throw StateError('synthetic reload failure');
    await super.refresh();
  }
}

void main() {
  final time = DateTime.utc(2026, 10, 8);
  final north = ProviderRecord(
    id: 'north',
    name: 'North Provider',
    createdAt: time,
  );
  final south = ProviderRecord(
    id: 'south',
    name: 'South Provider',
    createdAt: time,
  );
  late Directory directory;
  late LedgerStore store;
  late _Ledger ledger;
  late FakeSecretStore secrets;
  late ValueNotifier<Locale> locale;

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('provider-ui-synthetic-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite',
      clock: () => time,
    );
    secrets = FakeSecretStore();
    ledger = _Ledger(
      store,
      cloud: CloudController(
        store: store,
        secrets: secrets,
        adapterFactory: (_, _, _) =>
            throw StateError('No network in UI fixtures'),
      ),
      security: SecurityController(
        store: store,
        secrets: secrets,
        authenticator: FakeDeviceAuth(),
      ),
    );
    await store.saveProvider(north, isNew: true);
    await store.saveProvider(south, isNew: true);
    await ledger.refresh();
    locale = ValueNotifier(const Locale('en'));
  });
  tearDown(() async {
    locale.dispose();
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester,
    Widget page, {
    double scale = 1,
    double width = 390,
  }) async {
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

  /// "Change provider" lives in the detail page's more-actions menu.
  Future<void> changeProviderFromMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('server-change-provider')));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        240,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  Future<CloudAccount> account(
    String id,
    ProviderRecord provider, {
    bool v1 = false,
    bool imported = false,
  }) async {
    final snapshot = CloudSnapshot(
      provider: v1 ? CloudProvider.solusVm1 : CloudProvider.solusVm2,
      completedAt: time,
      remoteAccountId: v1 ? null : 7,
      instances: [
        CloudInstance(
          observedAt: time,
          power: CloudPower.running,
          projectId: v1 ? null : 2,
          serverId: v1 ? null : 3,
          name: v1 ? null : 'Device $id',
          ipv4: '192.0.2.10',
          hostname: 'fixture.example',
          vcpu: 2,
          ramBytes: 1073741824,
          diskBytes: 21474836480,
          trafficBytes: 1099511627776,
        ),
      ],
    );
    final record = CloudAccount(
      id: id,
      provider: snapshot.provider,
      businessProviderId: provider.id,
      authScope: adapterScope(snapshot.provider),
      alias: 'Adapter $id',
      endpoint: 'https://panel.example',
      secretRef: 'synthetic-$id',
      createdAt: time,
      remoteAccountId: snapshot.remoteAccountId,
    );
    await store.reserveSecret(record.secretRef);
    await store.saveCloudAccount(
      account: record,
      snapshot: snapshot,
      expected: null,
      selectedInstanceKeys: imported
          ? {cloudInstanceKey(snapshot, snapshot.instances.single)}
          : {},
      v1DisplayName: 'Device $id',
      v1Resources: v1
          ? ServerResources(
              ip: '192.0.2.10',
              hostname: 'fixture.example',
              vcpu: 2,
              ramBytes: 1073741824,
              diskBytes: 21474836480,
              trafficBytes: 1099511627776,
              trafficPeriodMonths: 1,
            )
          : null,
    );
    await ledger.refresh();
    return ledger.cloud.accounts.singleWhere((a) => a.id == id);
  }

  testWidgets(
    'unified add starts with provider and unspecified is manual only',
    (tester) async {
      await mount(tester, Scaffold(body: ServerList(controller: ledger)));
      await tap(tester, 'add-server');
      expect(find.byType(AddServerPage), findsOneWidget);
      expect(find.byType(ServerForm), findsNothing);
      await tap(tester, 'choose-provider-unspecified');
      expect(
        tester
            .widget<AppRow>(find.byKey(const ValueKey('add-automatic')))
            .onTap,
        isNull,
      );
      await tap(tester, 'add-manual');
      expect(find.byKey(const ValueKey('field-vendor')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('field-name')),
        'Manual unknown',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final saved = (await store.servers()).single;
      expect(saved.providerId, isNull);
      expect(saved.vendor, isEmpty);
      expect(saved.resources!.vcpu, isNull);
      expect(saved.amountMinor, isNull);
      expect(find.byType(AddServerPage), findsNothing);
      expect(find.byType(ServerDetail), findsOneWidget);
      expect(secrets.reads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('manual back and repeated opening preserve selected provider', (
    tester,
  ) async {
    await mount(tester, AddServerPage(ledger: ledger));
    await tap(tester, 'choose-provider-north');
    final row = tester.widget<AppRow>(find.byKey(const ValueKey('add-manual')));
    row.onTap!();
    row.onTap!();
    await tester.pumpAndSettle();
    expect(find.byType(ServerForm), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('North Provider'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-manual')), findsOneWidget);
    await back(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('choose-provider-north')), findsOneWidget);
    expect((await store.servers()), isEmpty);
  });

  testWidgets(
    'new provider cancellation and duplicate validation keep input across locale change',
    (tester) async {
      await mount(
        tester,
        ProviderPickerPage(ledger: ledger, allowUnspecified: true),
      );
      await tap(tester, 'choose-provider-add');
      await tester.enterText(
        find.byKey(const ValueKey('provider-name')),
        ' North Provider ',
      );
      await tap(tester, 'provider-save');
      expect(
        find.text('This provider already exists. Select it from the list.'),
        findsOneWidget,
      );
      locale.value = const Locale('zh');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('provider-name')))
            .controller!
            .text,
        ' North Provider ',
      );
      expect(
        find.text('This provider already exists. Select it from the list.'),
        findsNothing,
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect((await store.providers()).length, 2);
      expect(secrets.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'provider save followed by reload failure remains committed without duplicate',
    (tester) async {
      await mount(tester, ProviderPickerPage(ledger: ledger));
      await tap(tester, 'choose-provider-add');
      await tester.enterText(
        find.byKey(const ValueKey('provider-name')),
        'New Provider',
      );
      ledger.failReload = true;
      final button = tester.widget<CupertinoDialogAction>(
        find.byKey(const ValueKey('provider-save')),
      );
      button.onPressed!();
      button.onPressed!();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(ledger.refreshFailed, isTrue);
      expect(
        (await store.providers()).where((p) => p.name == 'New Provider').length,
        1,
      );
      expect(
        tester
            .widget<AppRow>(find.byKey(const ValueKey('choose-provider-add')))
            .onTap,
        isNull,
      );
      ledger.failReload = false;
      await ledger.refresh();
      await tester.pumpAndSettle();
      expect(find.text('New Provider'), findsOneWidget);
      expect(ledger.refreshFailed, isFalse);
    },
  );

  testWidgets(
    'automatic picker isolates providers and blocks a pinned singleton after unlink',
    (tester) async {
      await account('north-account', north);
      await account('south-account', south);
      final single = await account(
        'north-single',
        north,
        v1: true,
        imported: true,
      );
      final options = await store.serverCloudBindingOptions(
        single.pinnedServerId!,
      );
      await store.setServerCloudBinding(options, choice: null);
      await ledger.refresh();
      await mount(tester, AddServerPage(ledger: ledger, provider: north));
      await tap(tester, 'add-automatic');
      expect(
        find.byKey(const ValueKey('choose-instance-north-account')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('choose-instance-south-account')),
        findsNothing,
      );
      final pinned = find.byKey(const ValueKey('choose-instance-north-single'));
      await tester.ensureVisible(pinned);
      expect(tester.widget<AppRow>(pinned).onTap, isNull);
      expect(find.textContaining('pinned to'), findsOneWidget);
      expect(secrets.reads, 0);
      await tap(tester, 'pinned-device-north-single');
      expect(find.byType(ServerDetail), findsOneWidget);
      final bindingButton = find.byKey(const ValueKey('server-cloud-binding'));
      await tester.scrollUntilVisible(
        bindingButton,
        240,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
      expect(tester.widget<AppRow>(bindingButton).onTap, isNotNull);
      await back(tester);
      await back(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('add-automatic')), findsOneWidget);
    },
  );

  testWidgets(
    'provider and adapter details use forward and reverse navigation',
    (tester) async {
      final adapter = await account('linked', north, v1: true, imported: true);
      await mount(tester, ProvidersPage(ledger: ledger));
      await tap(tester, 'provider-north');
      expect(find.byType(ProviderDetailsPage), findsOneWidget);
      await tap(tester, 'provider-instance-linked');
      expect(find.byType(CloudAccountDetailsPage), findsOneWidget);
      await back(tester);
      await tester.pumpAndSettle();
      await tap(tester, 'provider-device-${adapter.pinnedServerId}');
      expect(find.byType(ServerDetail), findsOneWidget);
      await tap(tester, 'server-provider-link');
      expect(find.byType(ProviderDetailsPage), findsOneWidget);
      await back(tester);
      await tester.pumpAndSettle();
      await tap(tester, 'server-adapter-link');
      expect(find.byType(CloudAccountDetailsPage), findsOneWidget);
      expect(secrets.reads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing provider discloses unlink and preserves local data and singleton pin',
    (tester) async {
      final adapter = await account('single', north, v1: true, imported: true);
      final before = ledger.byId(adapter.pinnedServerId!)!;
      await mount(tester, ServerDetail(controller: ledger, id: before.id));
      await changeProviderFromMenu(tester);
      await tap(tester, 'choose-provider-south');
      expect(find.textContaining('Adapter single'), findsWidgets);
      expect(find.text('Unlink and Change Provider'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(ledger.byId(before.id)!.providerId, north.id);
      expect(ledger.cloud.bindings, hasLength(1));
      await changeProviderFromMenu(tester);
      await tap(tester, 'choose-provider-south');
      await tester.tap(find.text('Unlink and Change Provider'));
      await tester.pumpAndSettle();
      final after = ledger.byId(before.id)!;
      expect(after.providerId, south.id);
      expect(after.vendor, before.vendor);
      expect(after.resources!.toJson(), before.resources!.toJson());
      expect(after.amountMinor, before.amountMinor);
      expect(after.host, before.host);
      expect(ledger.cloud.bindings, isEmpty);
      expect(ledger.cloud.accounts.single.pinnedServerId, before.id);
      expect(ledger.cloud.accounts.single.secretRef, adapter.secretRef);
      expect(secrets.reads, 0);
    },
  );

  testWidgets(
    'pending ownership cannot be selected and confirmation names affected devices',
    (tester) async {
      final adapter = await account('review', north, v1: true, imported: true);
      final raw = await databaseFactoryFfiNoIsolate.openDatabase(
        '${directory.path}/ledger.sqlite',
      );
      await raw.update(
        'providers',
        {'needs_review': 1},
        where: 'id = ?',
        whereArgs: [north.id],
      );
      await ledger.refresh();
      await mount(tester, ProviderPickerPage(ledger: ledger));
      expect(
        tester
            .widget<AppRow>(find.byKey(const ValueKey('choose-provider-north')))
            .onTap,
        isNull,
      );
      await back(tester);
      await tester.pumpAndSettle();
      await mount(
        tester,
        ProviderDetailsPage(ledger: ledger, providerId: north.id),
      );
      expect(find.byKey(const ValueKey('provider-add-instance')), findsNothing);
      await tap(tester, 'confirm-provider-review');
      await tap(tester, 'choose-provider-south');
      expect(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.textContaining('Device review'),
        ),
        findsOneWidget,
      );
      final confirm = find.widgetWithText(
        CupertinoDialogAction,
        'Confirm Provider',
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(ledger.cloud.accounts.single.businessProviderId, south.id);
      expect(ledger.byId(adapter.pinnedServerId!)!.providerId, south.id);
      expect(
        find.byKey(const ValueKey('provider-instance-review')),
        findsOneWidget,
      );
      expect(
        find.text(
          'This provider changed or is unavailable. Go back and choose again.',
        ),
        findsNothing,
      );
      expect(ledger.cloud.accounts.single.secretRef, adapter.secretRef);
      expect(secrets.reads, 0);
      expect(secrets.writes, 0);
    },
  );

  testWidgets(
    'selected provider persists through manual creation with unknown hardware and finance',
    (tester) async {
      await mount(tester, Scaffold(body: ServerList(controller: ledger)));
      await tap(tester, 'add-server');
      await tap(tester, 'choose-provider-north');
      await tap(tester, 'add-manual');
      await tester.enterText(
        find.byKey(const ValueKey('field-name')),
        'Owned manual device',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final saved = (await store.servers()).single;
      expect(saved.providerId, north.id);
      expect(saved.vendor, north.name);
      expect(saved.amountMinor, isNull);
      expect(saved.billing, BillingKind.unknown);
      expect(saved.resources!.vcpu, isNull);
      expect(find.byType(ServerDetail), findsOneWidget);
    },
  );

  testWidgets(
    'failed automatic read returns to the same provider and instance choices',
    (tester) async {
      await account('north-account', north);
      await account('south-account', south);
      await mount(tester, AddServerPage(ledger: ledger));
      await tap(tester, 'choose-provider-north');
      await tap(tester, 'add-automatic');
      await tap(tester, 'choose-instance-north-account');
      expect(find.byType(CloudReadPage), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect((await store.servers()), isEmpty);
      await back(tester);
      expect(
        find.byKey(const ValueKey('choose-instance-north-account')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('choose-instance-south-account')),
        findsNothing,
      );
      await back(tester);
      expect(find.text('North Provider'), findsOneWidget);
      expect(find.byKey(const ValueKey('add-manual')), findsOneWidget);
    },
  );

  for (final language in ['en', 'zh']) {
    testWidgets(
      '$language narrow large-text selection and details remain scrollable',
      (tester) async {
        final adapter = await account(
          'long-alias-for-narrow-layout',
          north,
          v1: true,
          imported: true,
        );
        locale.value = Locale(language);
        await mount(
          tester,
          AddServerPage(ledger: ledger),
          width: 320,
          scale: 2,
        );
        await tap(tester, 'choose-provider-north');
        await tap(tester, 'add-manual');
        expect(tester.takeException(), isNull);
        await back(tester);
        await tester.pumpAndSettle();
        await back(tester);
        await tester.pumpAndSettle();
        await back(tester);
        await tester.pumpAndSettle();
        await mount(
          tester,
          ProviderDetailsPage(ledger: ledger, providerId: north.id),
          width: 320,
          scale: 2,
        );
        await tap(tester, 'provider-device-${adapter.pinnedServerId}');
        await tap(tester, 'server-provider-link');
        expect(tester.takeException(), isNull);
        expect(find.byType(ProviderDetailsPage), findsOneWidget);
      },
    );
  }
}
