import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/cloud/cloud_pages.dart';
import 'package:vps_tell_you/cloud/cloud_widgets.dart';
import 'package:vps_tell_you/cloud/server_cloud_binding_page.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';
import 'package:vps_tell_you/l10n/locale_preference.dart';
import 'package:vps_tell_you/l10n/localized_message.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'cloud_controller_test.dart' show CallbackCloudAdapter, CloudTestSecrets;
import 'cloud_store_test.dart' show cloudTestTime, snapshot;
import 'support/reminder_platform.dart';

void main() {
  final english = AppLocalizationsEn();
  final chinese = AppLocalizationsZh();
  late Directory directory;
  late LedgerStore store;
  late CloudTestSecrets secrets;
  late CloudController cloud;
  late LedgerController ledger;
  late Future<CloudSnapshot> Function(CloudProvider) read;
  var calls = 0;
  final cancellations = <CloudCancellation>[];

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('cloud-localization-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite',
      clock: () => cloudTestTime,
    );
    secrets = CloudTestSecrets();
    calls = 0;
    cancellations.clear();
    read = (provider) async => snapshot(v1: provider == CloudProvider.solusVm1);
    cloud = CloudController(
      store: store,
      secrets: secrets,
      adapterFactory: (provider, _, _) => CallbackCloudAdapter((cancellation) {
        cancellations.add(cancellation);
        calls++;
        return read(provider);
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

  Future<void> mount(
    WidgetTester tester,
    Widget page, {
    bool narrow = false,
    bool settle = true,
  }) async {
    tester.view.physicalSize = Size(narrow ? 320 : 390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: ledger,
        builder: (context, _) => MaterialApp(
          theme: appTheme(),
          locale: ledger.languagePreference.resolve(const [Locale('en')]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(narrow ? 2 : 1)),
            child: child!,
          ),
          home: page,
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> language(WidgetTester tester, LocalePreference value) async {
    await ledger.setLanguage(value);
    await tester.pumpAndSettle();
    expect(await store.languagePreference(), value);
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    final scrollable = find.byType(Scrollable).first;
    if (target.evaluate().isEmpty) {
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pump();
      await tester.scrollUntilVisible(target, 300, scrollable: scrollable);
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String key, String value) async {
    final target = find.byKey(ValueKey(key));
    await reveal(tester, target);
    await tester.enterText(target, value);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await reveal(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<CloudVerification> verify({bool v1 = false}) async =>
      (await cloud.verifyConnection(
        provider: v1 ? CloudProvider.solusVm1 : CloudProvider.solusVm2,
        endpoint: 'https://panel.example:8443',
        credentials: v1
            ? SolusVm1Credentials(key: 'fixture-key', hash: 'fixture-hash')
            : SolusVm2Credentials('fixture-token'),
      ))!;

  Future<CloudAccount> account({String? alias}) async {
    final verification = await verify();
    expect(
      await cloud.saveAccount(
        verification,
        alias: alias ?? '用户维护名称 User-owned panel',
      ),
      isTrue,
    );
    return cloud.accounts.single;
  }

  Future<void> scanPage(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isEmpty) return;
    final state = tester.state<ScrollableState>(scrollables.first);
    var offset = 0.0;
    while (offset < state.position.maxScrollExtent) {
      offset = (offset + 320).clamp(0, state.position.maxScrollExtent);
      state.position.jumpTo(offset);
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  }

  test('closed failure vocabulary resolves without changing stable codes', () {
    for (final kind in CloudFailureKind.values) {
      final failure = CloudFailure(kind);
      expect(failure.message, failure.messageFor(chinese));
      expect(failure.messageFor(english), isNot(failure.message));
      expect(failure.kind, kind);
      expect(failure.messageFor(english), isNot(contains('fixture-token')));
    }
    for (final failure in [
      CloudAccountFailure.identity,
      CloudAccountFailure.v1Rebind,
      CloudAccountFailure.selection,
      CloudAccountFailure.alias,
      CloudAccountFailure.secret,
      CloudAccountFailure.secretRead,
      CloudAccountFailure.bindingTaken,
      CloudAccountFailure.bindingUnavailable,
    ]) {
      expect(failure.message, failure.messageFor(chinese));
      expect(failure.messageFor(english), isNot(failure.message));
    }
    final safe = CloudAccountFailure(
      LocalizedText((l10n) => l10n.cloudOperationFailed),
    );
    expect(safe.messageFor(english), english.cloudOperationFailed);
    expect(cloudPowerLabel(CloudPower.running), chinese.cloudPowerRunning);
    expect(
      cloudPowerLabel(CloudPower.running, l10n: english),
      english.cloudPowerRunning,
    );
  });

  testWidgets(
    'authorization draft and validation survive persisted language change',
    (tester) async {
      await mount(
        tester,
        CloudAuthorizationPage(
          ledger: ledger,
          provider: CloudProvider.solusVm2,
        ),
      );
      const alias = '自定义 Draft alias';
      await fill(tester, 'cloud-alias', alias);
      await fill(tester, 'cloud-endpoint', 'https://panel.example:8443');
      await fill(tester, 'cloud-token', 'fixture-draft-token');
      await language(tester, LocalePreference.english);
      for (final item in {
        'cloud-alias': alias,
        'cloud-endpoint': 'https://panel.example:8443',
        'cloud-token': 'fixture-draft-token',
      }.entries) {
        final target = find.byKey(ValueKey(item.key));
        await reveal(tester, target);
        expect(
          tester.widget<TextFormField>(target).controller!.text,
          item.value,
        );
      }
      expect(calls, 0);
      expect(secrets.reads + secrets.writes + secrets.deletes, 0);
      await fill(tester, 'cloud-endpoint', 'invalid');
      await tapKey(tester, 'verify-cloud');
      await reveal(tester, find.byKey(const ValueKey('cloud-endpoint')));
      expect(find.text(english.cloudEndpointValidation), findsOneWidget);
      await language(tester, LocalePreference.chinese);
      expect(find.text(chinese.cloudEndpointValidation), findsOneWidget);
      expect(calls, 0);
      expect(await store.cloudAccounts(), isEmpty);
    },
  );

  testWidgets(
    'stored verification error translates without retry or raw error leak',
    (tester) async {
      read = (_) async =>
          throw StateError('DO-NOT-LEAK fixture-token https://private');
      await mount(
        tester,
        CloudAuthorizationPage(
          ledger: ledger,
          provider: CloudProvider.solusVm2,
        ),
      );
      await fill(tester, 'cloud-endpoint', 'https://panel.example:8443');
      await fill(tester, 'cloud-token', 'fixture-token');
      await tapKey(tester, 'verify-cloud');
      expect(calls, 1);
      await reveal(tester, find.text(chinese.cloudOperationFailed));
      final message = cloud.localizedError;
      await language(tester, LocalePreference.english);
      await reveal(tester, find.text(english.cloudOperationFailed));
      expect(find.text(english.cloudOperationFailed), findsOneWidget);
      expect(find.textContaining('DO-NOT-LEAK'), findsNothing);
      expect(identical(cloud.localizedError, message), isTrue);
      expect(calls, 1);
      expect(cloud.error, chinese.cloudOperationFailed);
      expect(secrets.reads + secrets.writes + secrets.deletes, 0);
    },
  );

  testWidgets(
    'saved failed read and account status translate without API or secret access',
    (tester) async {
      final saved = await account();
      read = (_) async => throw const CloudFailure(CloudFailureKind.timeout);
      await mount(
        tester,
        CloudReadPage(ledger: ledger, account: saved, importAfterRead: false),
      );
      expect(calls, 2);
      expect(find.text(chinese.cloudFailureTimeout), findsOneWidget);
      final records = (await store.cloudAccounts())
          .map((a) => a.toMap())
          .toList();
      final reads = secrets.reads;
      final writes = secrets.writes;
      final deletes = secrets.deletes;
      await language(tester, LocalePreference.english);
      expect(find.text(english.cloudFailureTimeout), findsOneWidget);
      expect(calls, 2);
      expect(secrets.reads, reads);
      expect(secrets.writes, writes);
      expect(secrets.deletes, deletes);
      expect(
        (await store.cloudAccounts()).map((a) => a.toMap()).toList(),
        records,
      );
      expect(cloud.accounts.single.lastFailure, CloudFailureKind.timeout);
      expect(cloud.accounts.single.alias, saved.alias);
      expect(
        cloudAccountStatus(cloud.accounts.single, l10n: english),
        english.cloudFailedKept,
      );
    },
  );

  testWidgets(
    'in-flight read keeps its request and completes in the new language',
    (tester) async {
      final saved = await account();
      final pending = Completer<CloudSnapshot>();
      read = (_) => pending.future;
      await mount(
        tester,
        CloudReadPage(ledger: ledger, account: saved, importAfterRead: false),
        settle: false,
      );
      await tester.pump();
      expect(calls, 2);
      final cancellation = cancellations.last;
      final secretReads = secrets.reads;
      await ledger.setLanguage(LocalePreference.english);
      await tester.pump();
      expect(cloud.busy, isTrue);
      expect(cancellation.isCancelled, isFalse);
      expect(calls, 2);
      expect(secrets.reads, secretReads);
      expect(find.text(english.cloudReadingInfo), findsOneWidget);
      pending.complete(snapshot());
      await tester.pumpAndSettle();
      expect(find.text(english.cloudReadCompleteInfo), findsOneWidget);
      expect(cloud.busy, isFalse);
      expect(calls, 2);
      expect(cloud.accounts.single.alias, saved.alias);
    },
  );

  testWidgets(
    'open account menu, rename error and unlink dialog change language safely',
    (tester) async {
      final saved = await account();
      final before = saved.toMap();
      final writes = secrets.writes;
      final reads = secrets.reads;
      await mount(tester, CloudAccountsPage(ledger: ledger), narrow: true);
      await tapKey(tester, 'cloud-account-${saved.id}');
      await language(tester, LocalePreference.english);
      await reveal(tester, find.text(english.cloudRenameAccount));
      await tester.tap(find.text(english.cloudRenameAccount));
      await tester.pumpAndSettle();
      await fill(tester, 'cloud-rename', '');
      await tester.tap(find.text(english.cloudSaveName));
      await tester.pumpAndSettle();
      expect(find.text(english.cloudAliasRange), findsOneWidget);
      await language(tester, LocalePreference.chinese);
      expect(find.text(chinese.cloudAliasRange), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('cloud-rename')))
            .controller!
            .text,
        '',
      );
      await tester.tap(find.text(chinese.cloudCancel).last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'cloud-account-${saved.id}');
      final unlink = find.text(chinese.cloudUnlinkAccount);
      await reveal(tester, unlink);
      await tester.tap(unlink);
      await tester.pumpAndSettle();
      await language(tester, LocalePreference.english);
      expect(find.text(english.cloudUnlinkAccountTitle), findsOneWidget);
      expect(find.textContaining(english.cloudRevokeV2), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(english.cancel).last);
      await tester.pumpAndSettle();
      expect(cloud.accounts.single.toMap(), before);
      expect(calls, 1);
      expect(secrets.reads, reads);
      expect(secrets.writes, writes);
      expect(secrets.deletes, 0);
    },
  );

  testWidgets(
    'V1 selection and incomplete hardware draft survive language change',
    (tester) async {
      final verified = await verify(v1: true);
      await mount(
        tester,
        CloudImportPage(
          ledger: ledger,
          verification: verified,
          alias: 'User alias',
        ),
      );
      await tapKey(tester, 'cloud-select-single');
      await fill(tester, 'cloud-v1-name', '用户本地名称 Local draft');
      await fill(tester, 'resource-ip', '192.0.2.77');
      await fill(tester, 'resource-hostname', 'User-Hostname.example');
      await tapKey(tester, 'cloud-import-submit');
      expect(calls, 1);
      await language(tester, LocalePreference.english);
      for (final item in {
        'cloud-v1-name': '用户本地名称 Local draft',
        'resource-ip': '192.0.2.77',
        'resource-hostname': 'User-Hostname.example',
      }.entries) {
        final target = find.byKey(ValueKey(item.key));
        await reveal(tester, target);
        final widget = tester.widget(target);
        final controller = widget is TextField
            ? widget.controller
            : (widget as TextFormField).controller;
        expect(controller!.text, item.value);
      }
      await reveal(tester, find.byKey(const ValueKey('cloud-select-single')));
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('cloud-select-single')),
            )
            .value,
        isTrue,
      );
      expect(find.text(english.resourceFieldValidVcpu), findsOneWidget);
      expect(find.text(english.resourceFieldValidBytes), findsWidgets);
      expect(find.text(chinese.resourceFieldValidVcpu), findsNothing);
      await reveal(tester, find.text(english.cloudResourcesIncomplete));
      expect(find.text(english.cloudResourcesIncomplete), findsOneWidget);
      expect(calls, 1);
      expect(secrets.reads + secrets.writes + secrets.deletes, 0);
      expect(await store.cloudAccounts(), isEmpty);
    },
  );

  testWidgets(
    'local binding selection uses no API and keeps IDs across language change',
    (tester) async {
      final saved = await account();
      await store.saveServer(
        ServerRecord(
          id: 'local',
          name: '用户维护服务器',
          vendor: 'Vendor literal',
          host: '192.0.2.12',
          createdAt: cloudTestTime,
          updatedAt: cloudTestTime,
        ),
        isNew: true,
      );
      await ledger.refresh();
      final reads = secrets.reads;
      await mount(
        tester,
        ServerCloudBindingPage(ledger: ledger, serverId: 'local'),
      );
      final key = 'server-cloud-instance-${saved.id}-7/2/3';
      await tapKey(tester, key);
      await language(tester, LocalePreference.english);
      await reveal(tester, find.byKey(ValueKey(key)));
      expect(
        tester.widget<CheckboxListTile>(find.byKey(ValueKey(key))).value,
        isTrue,
      );
      expect(calls, 1);
      expect(secrets.reads, reads);
      expect(await store.cloudBindings(), isEmpty);
      expect((await store.servers()).single.name, '用户维护服务器');
    },
  );

  testWidgets('English cloud pages fit 320 pixels at 2x with long user content', (
    tester,
  ) async {
    const longName =
        '用户内容 Very long user-maintained panel account and instance description';
    read = (_) async => snapshot(name: longName);
    final saved = await account(alias: longName);
    await store.saveServer(
      ServerRecord(
        id: 'local',
        name: longName,
        vendor: 'Vendor literal',
        host: '192.0.2.12',
        createdAt: cloudTestTime,
        updatedAt: cloudTestTime,
      ),
      isNew: true,
    );
    await ledger.refresh();
    await ledger.setLanguage(LocalePreference.english);
    final inventory = CloudInventory(
      account: saved,
      snapshot: snapshot(name: longName),
    );
    final v1 = CloudInventory(
      account: CloudAccount(
        id: 'v1',
        provider: CloudProvider.solusVm1,
        alias: longName,
        endpoint: 'https://panel.example:8443',
        secretRef: 'synthetic-only',
        createdAt: cloudTestTime,
      ),
      snapshot: snapshot(v1: true),
    );
    for (final page in <Widget>[
      CloudAccountsPage(ledger: ledger),
      CloudTemplatesPage(ledger: ledger),
      CloudAuthorizationPage(ledger: ledger, provider: CloudProvider.solusVm1),
      CloudAuthorizationPage(ledger: ledger, provider: CloudProvider.solusVm2),
      CloudImportPage(ledger: ledger, inventory: inventory),
      CloudImportPage(ledger: ledger, inventory: v1),
      CloudAccountDetailsPage(ledger: ledger, accountId: saved.id),
      ServerCloudBindingPage(ledger: ledger, serverId: 'local'),
    ]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await mount(tester, page, narrow: true);
      await scanPage(tester);
      expect(calls, 1);
    }
  });
}
