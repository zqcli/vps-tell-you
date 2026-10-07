import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/cloud/cloud_pages.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_detail.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/settings/settings_page.dart';

import 'security_store_test.dart' show FakeSecretStore, FakeDeviceAuth;
import 'cloud_store_test.dart' show completedResources;

class _Adapter implements CloudAdapter {
  _Adapter(this.action);
  final Future<CloudSnapshot> Function(CloudCancellation) action;
  @override
  Future<CloudSnapshot> read({required CloudCancellation cancellation}) =>
      action(cancellation);
}

CloudSnapshot _snapshot(
  CloudProvider provider, {
  int account = 7,
  List<int> ids = const [101, 102],
  CloudPower power = CloudPower.running,
  String? name,
  DateTime? at,
}) {
  final time = at ?? DateTime.utc(2026, 10, 6, 5);
  return CloudSnapshot(
    provider: provider,
    completedAt: time,
    remoteAccountId: provider == CloudProvider.solusVm1 ? null : account,
    instances: provider == CloudProvider.solusVm1
        ? [CloudInstance(observedAt: time, power: power)]
        : [
            for (final id in ids)
              CloudInstance(
                observedAt: time,
                power: power,
                projectId: 11,
                serverId: id,
                name: name ?? 'Fixture VPS $id',
                ipv4: '192.0.2.10',
              ),
          ],
  );
}

void main() {
  late Directory directory;
  late LedgerStore store;
  late FakeSecretStore secrets;
  late CloudController cloud;
  late LedgerController ledger;
  late Future<CloudSnapshot> Function(CloudProvider, CloudCancellation)
  behavior;
  final cancellations = <CloudCancellation>[];
  final endpoints = <String>[];
  var calls = 0;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('vps-cloud-widget-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
    );
    secrets = FakeSecretStore();
    behavior = (provider, _) async => _snapshot(provider);
    cancellations.clear();
    endpoints.clear();
    calls = 0;
    cloud = CloudController(
      store: store,
      secrets: secrets,
      adapterFactory: (provider, endpoint, credentials) =>
          _Adapter((cancellation) {
            calls++;
            endpoints.add(endpoint.toString());
            cancellations.add(cancellation);
            return behavior(provider, cancellation);
          }),
    );
    ledger = LedgerController(
      store,
      cloud: cloud,
      security: SecurityController(
        store: store,
        secrets: secrets,
        authenticator: FakeDeviceAuth(),
      ),
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
    Widget child, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
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
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => child),
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

  Future<void> reveal(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      await tester.scrollUntilVisible(
        target,
        350,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(target);
    await tester.pump();
  }

  Future<void> fill(WidgetTester tester, String key, String value) async {
    final field = find.byKey(ValueKey(key));
    await reveal(tester, field);
    await tester.enterText(field, value);
    await tester.pump();
  }

  Future<void> tapKey(
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

  Future<void> tapText(
    WidgetTester tester,
    String text, {
    bool settle = true,
  }) async {
    final target = find.text(text).last;
    await reveal(tester, target);
    await tester.tap(target);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> fillResources(WidgetTester tester) async {
    await fill(tester, 'resource-ip', '2001:db8::20');
    await fill(tester, 'resource-hostname', 'Fixture-VM');
    await fill(tester, 'resource-diskBytes', '20');
    await fill(tester, 'resource-trafficBytes', '1536');
    await fill(tester, 'resource-ramBytes', '2048');
    await fill(tester, 'resource-vcpu', '2');
  }

  Future<void> authorize(
    WidgetTester tester, {
    CloudProvider provider = CloudProvider.solusVm2,
  }) async {
    await fill(
      tester,
      'cloud-endpoint',
      provider == CloudProvider.solusVm1
          ? 'https://panel.example:5656/home.php'
          : 'https://panel.example',
    );
    if (provider == CloudProvider.solusVm1) {
      await fill(tester, 'cloud-key', 'SYNTHETIC_KEY');
      await fill(tester, 'cloud-hash', 'SYNTHETIC_HASH');
    } else {
      await fill(tester, 'cloud-token', 'SYNTHETIC_TOKEN');
    }
    await tapKey(tester, 'verify-cloud');
  }

  Future<CloudAccount> account({
    CloudProvider provider = CloudProvider.solusVm2,
    bool import = true,
  }) async {
    final verification = (await cloud.verifyConnection(
      provider: provider,
      endpoint: 'https://panel.example',
      credentials: provider == CloudProvider.solusVm1
          ? SolusVm1Credentials(key: 'SYNTHETIC_KEY', hash: 'SYNTHETIC_HASH')
          : SolusVm2Credentials('SYNTHETIC_TOKEN'),
    ))!;
    expect(
      await cloud.saveAccount(
        verification,
        alias: 'Fixture account',
        v1Resources: provider == CloudProvider.solusVm1
            ? completedResources()
            : null,
        selectedInstanceKeys: import
            ? {verification.keyFor(verification.snapshot.instances.first)}
            : {},
      ),
      isTrue,
    );
    await ledger.refresh();
    return cloud.accounts.last;
  }

  testWidgets(
    'template repeated taps do not stack forms; V1 origin review and explicit anonymous import at 390px large text',
    (tester) async {
      await mount(tester, CloudTemplatesPage(ledger: ledger), scale: 2.0);
      final v1 = find.text('SolusVM 1');
      await tester.tap(v1);
      await tester.tap(v1, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        find.byType(CloudAuthorizationPage, skipOffstage: false),
        findsOneWidget,
      );
      await fill(
        tester,
        'cloud-endpoint',
        'https://panel.example:5656/home.php',
      );
      expect(
        find.text('已移除 /home.php。\n验证将连接：https://panel.example:5656'),
        findsOneWidget,
      );
      expect(calls, 0);
      await fill(tester, 'cloud-key', 'SYNTHETIC_KEY');
      await fill(tester, 'cloud-hash', 'SYNTHETIC_HASH');
      for (final key in ['cloud-key', 'cloud-hash']) {
        await reveal(tester, find.byKey(ValueKey(key)));
        expect(
          tester
              .widget<TextFormField>(find.byKey(ValueKey(key)))
              .controller!
              .text,
          isNotEmpty,
        );
        final editable = find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(EditableText),
        );
        expect(tester.widget<EditableText>(editable).obscureText, isTrue);
      }
      await tapKey(tester, 'verify-cloud');
      expect(calls, 1);
      expect(endpoints.single, 'https://panel.example:5656');
      expect(find.text('无稳定实例 ID · 按此独立连接识别'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('cloud-import-submit')));
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('cloud-import-submit')),
            )
            .onPressed,
        isNull,
      );
      await tapKey(tester, 'cloud-select-single');
      await fill(tester, 'cloud-v1-name', '我的独立 VPS');
      await fillResources(tester);
      await tapKey(tester, 'cloud-import-submit');
      expect(cloud.accounts, hasLength(1));
      expect(ledger.active.single.name, '我的独立 VPS');
      expect(ledger.active.single.host, '2001:db8::20');
      expect(ledger.active.single.resources!.hostname, 'Fixture-VM');
      expect(ledger.active.single.resources!.ramBytes, 2 * 1024 * 1024 * 1024);
      expect(ledger.active.single.resources!.apiFields, isEmpty);
      expect(ledger.active.single.billing, BillingKind.unknown);
      expect(cloud.bindings.single.observation.name, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'complete V1 API resources survive a direct bottom jump and import',
    (tester) async {
      final resources = completedResources();
      behavior = (_, _) async => CloudSnapshot(
        provider: CloudProvider.solusVm1,
        completedAt: DateTime.utc(2026, 10, 6),
        instances: [
          CloudInstance(
            observedAt: DateTime.utc(2026, 10, 6),
            power: CloudPower.running,
            ipv4: resources.ip,
            hostname: resources.hostname,
            diskBytes: resources.diskBytes,
            trafficBytes: resources.trafficBytes,
            ramBytes: resources.ramBytes,
            vcpu: resources.vcpu,
          ),
        ],
      );
      await mount(
        tester,
        CloudAuthorizationPage(
          ledger: ledger,
          provider: CloudProvider.solusVm1,
        ),
        scale: 2,
      );
      await authorize(tester, provider: CloudProvider.solusVm1);
      await tapKey(tester, 'cloud-select-single');
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cloud-import-submit')));
      await tester.pumpAndSettle();
      expect(ledger.active, hasLength(1));
      final saved = ledger.active.single.resources!;
      expect(saved.apiFields, {
        'ip',
        'hostname',
        'diskBytes',
        'trafficBytes',
        'ramBytes',
        'vcpu',
      });
      expect(saved.vcpu, resources.vcpu);
      expect(saved.ramBytes, resources.ramBytes);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('background expiry fences a completed V1 resource form', (
    tester,
  ) async {
    await mount(
      tester,
      CloudAuthorizationPage(ledger: ledger, provider: CloudProvider.solusVm1),
    );
    await authorize(tester, provider: CloudProvider.solusVm1);
    await tapKey(tester, 'cloud-select-single');
    await fillResources(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    final submit = find.byKey(const ValueKey('cloud-import-submit'));
    await reveal(tester, submit);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(cloud.accounts, isEmpty);
    expect(await store.servers(), isEmpty);
    expect(secrets.values, isEmpty);
    expect(cancellations.single.isCancelled, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'partial V1 import shows required completion, never stores zeros, and repeated submit imports once',
    (tester) async {
      behavior = (_, _) async => CloudSnapshot(
        provider: CloudProvider.solusVm1,
        completedAt: DateTime.utc(2026, 10, 6),
        instances: [
          CloudInstance(
            observedAt: DateTime.utc(2026, 10, 6),
            power: CloudPower.running,
            ipv4: '192.0.2.60',
            hostname: 'Provider-VM',
            diskBytes: 21474836480,
            trafficBytes: 1649267441664,
            trafficUsedBytes: 0,
          ),
        ],
      );
      await mount(
        tester,
        CloudAuthorizationPage(
          ledger: ledger,
          provider: CloudProvider.solusVm1,
        ),
      );
      await authorize(tester, provider: CloudProvider.solusVm1);
      await tapKey(tester, 'cloud-select-single');
      await tapKey(tester, 'cloud-import-submit');
      expect(cloud.accounts, isEmpty);
      expect(secrets.values, isEmpty);
      expect(await store.servers(), isEmpty);
      await fill(tester, 'resource-ramBytes', '2048');
      await fill(tester, 'resource-vcpu', '2');
      final submit = find.byKey(const ValueKey('cloud-import-submit'));
      await reveal(tester, submit);
      await tester.tap(submit);
      await tester.tap(submit, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(ledger.active, hasLength(1));
      final resources = ledger.active.single.resources!;
      expect(resources.apiFields, {
        'ip',
        'hostname',
        'diskBytes',
        'trafficBytes',
      });
      expect(resources.ramBytes, 2147483648);
      expect(resources.vcpu, 2);
      expect(cloud.bindings.single.observation.trafficUsedBytes, 0);
      expect(ledger.active.single.billing, BillingKind.unknown);
      expect(await store.sshConfigurations(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancel verification and Back fence ignored late responses; repeated verify starts one read',
    (tester) async {
      var pending = Completer<CloudSnapshot>();
      behavior = (_, _) => pending.future; // Deliberately ignores cancellation.
      await mount(
        tester,
        CloudAuthorizationPage(
          ledger: ledger,
          provider: CloudProvider.solusVm2,
        ),
      );
      await fill(tester, 'cloud-endpoint', 'https://panel.example');
      await fill(tester, 'cloud-token', 'SYNTHETIC_TOKEN');
      final verify = find.byKey(const ValueKey('verify-cloud'));
      await tester.ensureVisible(verify);
      await tester.tap(verify);
      await tester.tap(verify, warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);
      await tapKey(tester, 'cancel-cloud-verify');
      expect(cancellations.single.isCancelled, isTrue);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('cloud-token')))
            .controller!
            .text,
        isEmpty,
      );
      pending.complete(_snapshot(CloudProvider.solusVm2));
      await tester.pumpAndSettle();
      expect(find.byType(CloudImportPage), findsNothing);
      expect(cloud.accounts, isEmpty);
      pending = Completer<CloudSnapshot>();
      await fill(tester, 'cloud-token', 'SYNTHETIC_NEW_TOKEN');
      await tapKey(tester, 'verify-cloud', settle: false);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(cancellations.last.isCancelled, isTrue);
      pending.complete(_snapshot(CloudProvider.solusVm2));
      await tester.pumpAndSettle();
      expect(find.text('Open fixture'), findsOneWidget);
      expect(find.byType(CloudImportPage), findsNothing);
      expect(secrets.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'save-only, continue import and dedup selection are distinct; repeated save commits once',
    (tester) async {
      await mount(
        tester,
        CloudAuthorizationPage(
          ledger: ledger,
          provider: CloudProvider.solusVm2,
        ),
      );
      await authorize(tester);
      await tapKey(tester, 'cloud-save-only');
      expect(cloud.accounts, hasLength(1));
      expect(ledger.active, isEmpty);
      await mount(tester, CloudAccountsPage(ledger: ledger));
      await tapKey(tester, 'cloud-account-${cloud.accounts.single.id}');
      await tapText(tester, '继续导入实例');
      expect(find.byType(CloudImportPage), findsOneWidget);
      await tapKey(tester, 'cloud-select-7/11/101');
      final submit = find.byKey(const ValueKey('cloud-import-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.tap(submit, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(ledger.active, hasLength(1));
      expect(secrets.writes, 1);
      await tapKey(tester, 'cloud-account-${cloud.accounts.single.id}');
      await tapText(tester, '继续导入实例');
      final linked = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('cloud-select-7/11/101')),
      );
      expect(linked.value, isTrue);
      expect(linked.onChanged, isNull);
      await tapKey(tester, 'cloud-select-7/11/102');
      await tapKey(tester, 'cloud-import-submit');
      expect(ledger.active, hasLength(2));
      expect(cloud.bindings, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'verification errors stay on form and clear input without fake success',
    (tester) async {
      behavior = (_, _) async =>
          throw const CloudFailure(CloudFailureKind.unauthorized);
      await mount(
        tester,
        CloudAuthorizationPage(
          ledger: ledger,
          provider: CloudProvider.solusVm2,
        ),
      );
      await authorize(tester);
      expect(find.text('API 凭据未通过验证，请检查凭据或重新授权'), findsOneWidget);
      expect(cloud.accounts, isEmpty);
      expect(find.byType(CloudImportPage), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('cloud-token')))
            .controller!
            .text,
        isEmpty,
      );
      behavior = (_, _) async =>
          throw const CloudFailure(CloudFailureKind.timeout);
      await fill(tester, 'cloud-token', 'SYNTHETIC_TOKEN');
      await tapKey(tester, 'verify-cloud');
      expect(find.text('读取超时，保留上次读取的信息；请稍后重试'), findsOneWidget);
      expect(secrets.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'background clears pending verification on selection and saved-account read cancellation',
    (tester) async {
      await mount(
        tester,
        CloudAuthorizationPage(
          ledger: ledger,
          provider: CloudProvider.solusVm2,
        ),
      );
      await authorize(tester);
      await tapKey(tester, 'cloud-select-7/11/101');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('cloud-import-submit')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('cloud-save-only')),
            )
            .onPressed,
        isNull,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tapText(tester, '返回重新验证');
      expect(cloud.accounts, isEmpty);
      expect(secrets.writes, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final saved = await account(import: false);
      final pending = Completer<CloudSnapshot>();
      behavior = (_, _) => pending.future;
      // Do not settle while the progress indicator is active.
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: CloudReadPage(
            ledger: ledger,
            account: saved,
            importAfterRead: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(cancellations.last.isCancelled, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      pending.complete(_snapshot(CloudProvider.solusVm2));
      await tester.pumpAndSettle();
      expect(find.byType(CloudImportPage), findsNothing);
      expect(cloud.bindings, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account menu details rename and unbind preserve local fields, finance and SSH',
    (tester) async {
      final saved = await account();
      final original = ledger.active.single;
      await store.saveServer(
        ServerRecord(
          id: original.id,
          name: '手动名称',
          vendor: '自填服务商',
          host: 'manual.example',
          notes: '本地备注',
          billing: BillingKind.metered,
          amountMinor: 1234,
          createdAt: original.createdAt,
          updatedAt: original.updatedAt,
          revision: original.revision,
        ),
        isNew: false,
      );
      await store.saveSshConfiguration(
        SshConfiguration(
          serverId: original.id,
          host: 'ssh.example',
          port: 2222,
          username: 'myuser',
          revision: -1,
        ),
      );
      await store.recordAccountPayment(
        id: 'independent-bill',
        accountLabel: 'Fixture account',
        amount: Money('USD', 1234),
        paidDate: const LedgerDate(2026, 10, 6),
      );
      await ledger.refresh();
      final before = ledger.active.single.toMap();
      final ssh = (await store.sshConfigurations()).single.toMap();
      await mount(tester, CloudAccountsPage(ledger: ledger), scale: 2.0);
      await tapKey(tester, 'cloud-account-${saved.id}');
      await tapText(tester, '查看账户详情');
      expect(find.text('面板账户详情'), findsOneWidget);
      expect(find.text('已验证用户账户 7 · 项目与实例'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapKey(tester, 'cloud-account-${saved.id}');
      await tapText(tester, '编辑账户名称');
      await fill(tester, 'cloud-rename', '重命名的面板');
      await tapText(tester, '保存名称');
      expect(cloud.accounts.single.alias, '重命名的面板');
      await tapKey(tester, 'cloud-account-${saved.id}');
      await tapText(tester, '解除账户关联');
      await tapText(tester, '解除本地关联');
      expect(cloud.accounts, isEmpty);
      expect(cloud.bindings, isEmpty);
      expect((await store.servers()).single.toMap(), before);
      expect((await store.sshConfigurations()).single.toMap(), ssh);
      expect((await store.payments()).single.id, 'independent-bill');
      expect(secrets.values, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'V1 reauthorization requires detach confirmation, preserves old record, and imports separately',
    (tester) async {
      final saved = await account(provider: CloudProvider.solusVm1);
      final oldServerId = ledger.active.single.id;
      await mount(
        tester,
        CloudAuthorizationPage(
          ledger: ledger,
          provider: CloudProvider.solusVm1,
          existing: saved,
        ),
        scale: 2.0,
      );
      await fill(tester, 'cloud-key', 'REPLACEMENT_SYNTHETIC_KEY');
      await fill(tester, 'cloud-hash', 'REPLACEMENT_SYNTHETIC_HASH');
      await tapKey(tester, 'verify-cloud');
      await tapKey(tester, 'cloud-select-single');
      await reveal(tester, find.byKey(const ValueKey('cloud-import-submit')));
      expect(find.text('更新授权并解除旧关联'), findsOneWidget);
      expect(find.text('仅更新授权'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('cloud-import-submit')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('cloud-save-only')),
            )
            .onPressed,
        isNull,
      );
      await tapKey(tester, 'cloud-confirm-rebind');
      await fillResources(tester);
      await tapKey(tester, 'cloud-import-submit');
      expect(ledger.active, hasLength(2));
      expect(ledger.byId(oldServerId), isNotNull);
      expect(cloud.bindingFor(oldServerId), isNull);
      expect(cloud.bindings.single.serverId, isNot(oldServerId));
      expect(cloud.accounts.single.id, saved.id);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'V2 changed identity reauthorization cannot replace old secret or binding',
    (tester) async {
      final saved = await account();
      final previousSecret = secrets.values[saved.secretRef];
      final serverId = ledger.active.single.id;
      behavior = (provider, _) async => _snapshot(provider, account: 99);
      await mount(
        tester,
        CloudAuthorizationPage(
          ledger: ledger,
          provider: CloudProvider.solusVm2,
          existing: saved,
        ),
      );
      await fill(tester, 'cloud-token', 'OTHER_SYNTHETIC_TOKEN');
      await tapKey(tester, 'verify-cloud');
      expect(find.text(CloudAccountFailure.identity.message), findsOneWidget);
      expect(find.byType(CloudImportPage), findsNothing);
      expect(secrets.values[saved.secretRef], previousSecret);
      expect(cloud.bindingFor(serverId), isNotNull);
      expect(cloud.accounts.single.remoteAccountId, 7);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'detail hides provider observation fields and retains local values on refresh failure',
    (tester) async {
      final saved = await account();
      behavior = (provider, _) async => _snapshot(
        provider,
        power: CloudPower.unknown,
        name: '远端变化的名称',
        at: DateTime.utc(2026, 10, 6, 6),
      );
      expect(await cloud.refreshAccount(saved), isNotNull);
      behavior = (_, _) async =>
          throw const CloudFailure(CloudFailureKind.unavailable);
      expect(await cloud.refreshAccount(cloud.accounts.single), isNull);
      final binding = cloud.bindings.single;
      expect(binding.stale, isTrue);
      expect(ledger.active.single.name, 'Fixture VPS 101');
      await mount(
        tester,
        ServerDetail(controller: ledger, id: ledger.active.single.id),
        scale: 2.0,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('server-cloud-binding')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('API 返回信息'), findsNothing);
      expect(find.text('远端变化的名称'), findsNothing);
      expect(find.text('未知（API 未提供）'), findsNothing);
      expect(find.text('管理关联'), findsOneWidget);
      expect(ledger.active.single.name, 'Fixture VPS 101');
      expect(cloud.bindings.single.observation.name, '远端变化的名称');
      expect(cloud.bindings.single.stale, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Back cancels account read before pop animation can open late import',
    (tester) async {
      await account(import: false);
      await mount(tester, CloudAccountsPage(ledger: ledger));
      final pending = Completer<CloudSnapshot>();
      behavior = (_, _) => pending.future;
      await tapKey(tester, 'cloud-account-${cloud.accounts.single.id}');
      await tapText(tester, '继续导入实例', settle: false);
      await tester.pump(const Duration(milliseconds: 350));
      final request = cancellations.last;
      expect(request.isCancelled, isFalse);
      final readContext = tester.element(find.byType(CloudReadPage));
      Navigator.of(readContext).pop();
      // Complete before disposal: the route is still mounted during animation.
      expect(request.isCancelled, isTrue);
      pending.complete(_snapshot(CloudProvider.solusVm2));
      await tester.pumpAndSettle();
      expect(find.byType(CloudReadPage), findsNothing);
      expect(find.byType(CloudImportPage), findsNothing);
      expect(find.byType(CloudAccountsPage), findsOneWidget);
      expect(cloud.bindings, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saving twice waits for one secure-store operation; failed storage cannot claim success',
    (tester) async {
      await mount(
        tester,
        CloudAuthorizationPage(
          ledger: ledger,
          provider: CloudProvider.solusVm2,
        ),
      );
      await authorize(tester);
      await tapKey(tester, 'cloud-select-7/11/101');
      secrets.failWrite = true;
      await tapKey(tester, 'cloud-import-submit');
      expect(find.text(CloudAccountFailure.secret.message), findsOneWidget);
      expect(cloud.accounts, isEmpty);
      expect(ledger.active, isEmpty);
      expect(find.byType(CloudImportPage), findsOneWidget);
      secrets.failWrite = false;
      secrets.blockRead = Completer<void>();
      final oldWrites = secrets.writes;
      final submit = find.byKey(const ValueKey('cloud-import-submit'));
      await reveal(tester, submit);
      await tester.tap(submit);
      await tester.tap(submit, warnIfMissed: false);
      await tester.pump();
      expect(secrets.writes, oldWrites + 1);
      expect(cloud.accounts, isEmpty);
      secrets.blockRead!.complete();
      secrets.blockRead = null;
      await tester.pumpAndSettle();
      expect(cloud.accounts, hasLength(1));
      expect(ledger.active, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings repeated cloud entry taps open one account route', (
    tester,
  ) async {
    await mount(tester, Scaffold(body: SettingsPage(controller: ledger)));
    final entry = find.text('面板账户');
    await reveal(tester, entry);
    await tester.tap(entry);
    await tester.tap(entry, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(CloudAccountsPage, skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'V1 unselected import explains the blocker and returns to selection without granting it',
    (tester) async {
      await mount(
        tester,
        CloudAuthorizationPage(
          ledger: ledger,
          provider: CloudProvider.solusVm1,
        ),
        scale: 2,
      );
      await authorize(tester, provider: CloudProvider.solusVm1);
      await fillResources(tester);
      await tapKey(tester, 'cloud-return-to-instance');
      final selection = find.byWidgetPredicate(
        (widget) =>
            widget is CheckboxListTile &&
            widget.key is ValueKey<String> &&
            (widget.key as ValueKey<String>).value.startsWith('cloud-select-'),
      );
      expect(selection.hitTestable(), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(selection).value, isFalse);
      expect(cloud.accounts, isEmpty);
      expect(calls, 1);
      await tester.tap(selection);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('cloud-return-to-instance')),
        findsNothing,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('resource-vcpu')))
            .controller!
            .text,
        '2',
      );
      await tapKey(tester, 'cloud-import-submit');
      expect(cloud.accounts, hasLength(1));
      expect(ledger.active, hasLength(1));
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('V1 invalid completion reveals its first error from the bottom', (
    tester,
  ) async {
    await mount(
      tester,
      CloudAuthorizationPage(ledger: ledger, provider: CloudProvider.solusVm1),
      scale: 2,
    );
    await authorize(tester, provider: CloudProvider.solusVm1);
    final selection = find.byWidgetPredicate(
      (widget) =>
          widget is CheckboxListTile &&
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith('cloud-select-'),
    );
    await reveal(tester, selection);
    await tester.tap(selection);
    await tester.pumpAndSettle();
    await fill(tester, 'resource-vcpu', '2');
    await tapKey(tester, 'cloud-import-submit');
    expect(
      find.byKey(const ValueKey('resource-ip')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.text('请填写有效 IPv4 或 IPv6，不能为全零地址').hitTestable(),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('resource-vcpu')))
          .controller!
          .text,
      '2',
    );
    expect(cloud.accounts, isEmpty);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
}
