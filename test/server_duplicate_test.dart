import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_duplicate.dart';
import 'package:vps_tell_you/servers/server_list.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

import 'support/provider_fixture.dart';

void main() {
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late ServerRecord source;
  DateTime clock() => DateTime(2026, 10, 6, 8);

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('vps-duplicate-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
      clock: clock,
    );
    await addTestProvider(store);
    await store.saveGroup('Prod');
    final groupId = (await store.groups()).single.id;
    source = ServerRecord(
      id: 'src',
      name: 'Tokyo-1',
      vendor: 'Local vendor',
      providerId: testProvider.id,
      region: 'Tokyo',
      purpose: 'Proxy',
      os: 'Debian 12',
      notes: 'private notes',
      groupId: groupId,
      favorite: true,
      resources: ServerResources(
        ip: '203.0.113.10',
        ipv6: '2001:db8::10',
        hostname: 'tokyo.example.com',
        vcpu: 2,
        ramBytes: 2 * 1073741824,
        diskBytes: 40 * 1073741824,
        trafficBytes: 1024 * 1073741824,
        trafficPeriodMonths: 1,
      ),
      billing: BillingKind.prepaid,
      currency: 'EUR',
      amountMinor: 1250,
      cycleMonths: 3,
      startDate: const LedgerDate(2026, 1, 1),
      dueDate: const LedgerDate(2026, 4, 1),
      createdAt: clock(),
      updatedAt: clock(),
    );
    await store.saveServer(source, isNew: true);
    await store.recordPayment(
      id: 'pay1',
      server: source,
      amount: const Money('EUR', 1250),
      paidDate: const LedgerDate(2026, 1, 1),
      cycleCount: 1,
      until: const LedgerDate(2026, 7, 1),
      confirmed: true,
    );
    await store.saveSshConfiguration(
      const SshConfiguration(
        serverId: 'src',
        host: '203.0.113.10',
        username: 'root',
      ),
    );
    ledger = LedgerController(store, clock: clock);
    await ledger.refresh();
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester, {
    String locale = 'zh',
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width * 2, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: ServerList(controller: ledger),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row() => find.byKey(const ValueKey('server-src'));
  Finder leading() => find.byKey(const ValueKey('server-swipe-leading'));
  Finder trailing() => find.byKey(const ValueKey('server-swipe-trailing'));
  String fieldText(WidgetTester tester, String key) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  /// The date rows show "Unknown" while empty, the ISO date otherwise.
  String dateText(WidgetTester tester, String key) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data ?? t.textSpan!.toPlainText())
      .last;

  Future<void> swipe(WidgetTester tester, double dx) async {
    // Start inside the content but away from the screen's back-swipe edge.
    final rect = tester.getRect(row());
    await tester.dragFrom(
      Offset(rect.right - 30, rect.center.dy),
      Offset(dx, 0),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('right swipe shows only Duplicate, left swipe SSH + favourite', (
    tester,
  ) async {
    await mount(tester);
    expect(leading(), findsNothing);
    expect(trailing(), findsNothing);
    await swipe(tester, 200);
    expect(leading(), findsOneWidget);
    expect(trailing(), findsNothing);
    expect(
      find.descendant(of: leading(), matching: find.text('复制')),
      findsOneWidget,
    );
    await tester.tapAt(tester.getCenter(row()));
    await tester.pumpAndSettle();
    expect(leading(), findsNothing);
    await swipe(tester, -200);
    expect(trailing(), findsOneWidget);
    expect(leading(), findsNothing);
    expect(
      find.descendant(of: trailing(), matching: find.text('SSH')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: trailing(), matching: find.text('取消常用')),
      findsOneWidget,
    );
    expect(find.text('归档'), findsNothing);
    // Tapping the row closes it instead of opening the detail page.
    await tester.tapAt(tester.getCenter(row()));
    await tester.pumpAndSettle();
    expect(trailing(), findsNothing);
  });

  testWidgets('only one row stays open and the swipe mirrors in RTL', (
    tester,
  ) async {
    await store.saveServer(
      ServerRecord(
        id: 'other',
        name: 'Other',
        vendor: '',
        createdAt: clock(),
        updatedAt: clock(),
      ),
      isNew: true,
    );
    await ledger.refresh();
    await mount(tester);
    await swipe(tester, 200);
    expect(leading(), findsOneWidget);
    await tester.dragFrom(
      tester.getCenter(find.byKey(const ValueKey('server-other'))),
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();
    expect(leading(), findsNothing);
    expect(trailing(), findsOneWidget);
  });

  testWidgets('right-to-left: dragging left reveals the leading Duplicate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: ServerList(controller: ledger),
      ),
    );
    await tester.pumpAndSettle();
    await swipe(tester, -200);
    expect(leading(), findsOneWidget);
    expect(trailing(), findsNothing);
    expect(
      tester.getCenter(leading()).dx,
      greaterThan(195),
      reason: 'leading = right in RTL',
    );
  });

  testWidgets('long press menu has Duplicate and Archive', (tester) async {
    await mount(tester);
    await tester.longPress(row());
    await tester.pumpAndSettle();
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('归档'), findsOneWidget);
  });

  testWidgets('duplicate opens a prefilled form; save creates a clean copy', (
    tester,
  ) async {
    await mount(tester);
    await swipe(tester, 200);
    await tester.tap(find.descendant(of: leading(), matching: find.text('复制')));
    await tester.pumpAndSettle();
    expect(find.text('添加服务器'), findsOneWidget);
    expect(fieldText(tester, 'field-name'), 'Tokyo-1 副本');
    expect(fieldText(tester, 'field-region'), 'Tokyo');
    expect(fieldText(tester, 'field-purpose'), 'Proxy');
    expect(fieldText(tester, 'field-os'), 'Debian 12');
    expect(fieldText(tester, 'field-notes'), isEmpty);
    expect(fieldText(tester, 'field-amount'), '12.50');
    expect(dateText(tester, 'field-start'), '未知');
    expect(dateText(tester, 'field-due'), '未知');
    expect(fieldText(tester, 'resource-ip'), isEmpty);
    expect(fieldText(tester, 'resource-ipv6'), isEmpty);
    expect(fieldText(tester, 'resource-hostname'), isEmpty);
    // Nothing is written before Save.
    expect((await store.servers()), hasLength(1));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final all = await store.servers();
    expect(all, hasLength(2));
    final copy = all.firstWhere((s) => s.id != 'src');
    expect(copy.name, 'Tokyo-1 副本');
    expect(copy.providerId, testProvider.id);
    expect(copy.groupId, source.groupId);
    expect(copy.region, 'Tokyo');
    expect(copy.purpose, 'Proxy');
    expect(copy.os, 'Debian 12');
    expect(copy.billing, BillingKind.prepaid);
    expect(copy.currency, 'EUR');
    expect(copy.amountMinor, 1250);
    expect(copy.cycleMonths, 3);
    expect(copy.startDate, isNull);
    expect(copy.dueDate, isNull);
    expect(copy.favorite, isFalse);
    expect(copy.archived, isFalse);
    expect(copy.notes, isEmpty);
    expect(copy.host, isEmpty);
    final r = copy.resources!;
    expect([r.ip, r.ipv6, r.hostname], ['', '', '']);
    expect(r.vcpu, 2);
    expect(r.ramBytes, 2 * 1073741824);
    expect(r.diskBytes, 40 * 1073741824);
    expect(r.trafficBytes, 1024 * 1073741824);
    expect(r.trafficPeriodMonths, 1);
    expect(
      (await store.payments()).where((p) => p.serverId == copy.id),
      isEmpty,
    );
    expect(
      (await store.sshConfigurations()).where((c) => c.serverId == copy.id),
      isEmpty,
    );
    // The source is untouched.
    final original = all.firstWhere((s) => s.id == 'src');
    expect(original.favorite, isTrue);
    expect(original.resources!.ip, '203.0.113.10');
    expect(await store.payments(), hasLength(1));
    expect(await store.sshConfigurations(), hasLength(1));
  });

  testWidgets('cancel leaves no trace', (tester) async {
    await mount(tester);
    await tester.longPress(row());
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    expect(find.text('添加服务器'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('添加服务器'), findsNothing);
    expect(await store.servers(), hasLength(1));
    expect(await store.groups(), hasLength(1));
  });

  testWidgets('picking a start date derives the due date as for a new server', (
    tester,
  ) async {
    await mount(tester);
    await tester.longPress(row());
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('field-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('field-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('date-sheet-done')));
    await tester.pumpAndSettle();
    expect(dateText(tester, 'field-start'), matches(r'^\d{4}-\d\d-\d\d$'));
    expect(dateText(tester, 'field-due'), matches(r'^\d{4}-\d\d-\d\d$'));
  });

  testWidgets('demo and read-only rows cannot be duplicated', (tester) async {
    await store.saveServer(
      ServerRecord(
        id: 'demo1',
        name: 'Demo box',
        vendor: '',
        isDemo: true,
        createdAt: clock(),
        updatedAt: clock(),
      ),
      isNew: true,
    );
    await ledger.refresh();
    await mount(tester);
    final demo = ledger.byId('demo1')!;
    await tester.longPress(find.byKey(ValueKey('server-${demo.id}')));
    await tester.pumpAndSettle();
    expect(find.text('复制'), findsNothing);
    expect(find.text('归档'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.dragFrom(
      tester.getCenter(find.byKey(ValueKey('server-${demo.id}'))),
      const Offset(200, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: leading(), matching: find.text('复制')));
    await tester.pumpAndSettle();
    expect(find.text('添加服务器'), findsNothing);
  });

  for (final locale in ['zh', 'en']) {
    testWidgets('320px / 2x text layout of both swipe sides ($locale)', (
      tester,
    ) async {
      await mount(tester, locale: locale, width: 320, scale: 2);
      await swipe(tester, -200);
      expect(trailing(), findsOneWidget);
      expect(tester.getRect(trailing()).right, lessThanOrEqualTo(320.5));
      for (final label in [
        'SSH',
        locale == 'zh' ? '取消常用' : 'Remove from Favorites',
      ]) {
        expect(
          tester.getRect(find.text(label)).width,
          lessThanOrEqualTo(76),
          reason: label,
        );
      }
      await swipe(tester, 400); // across to the other side
      expect(leading(), findsOneWidget);
      expect(tester.getRect(leading()).left, greaterThanOrEqualTo(-.5));
      expect(
        tester.getRect(find.text(locale == 'zh' ? '复制' : 'Duplicate')).width,
        lessThanOrEqualTo(76),
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('duplicate name is localized and never exceeds 80 units', () {
    expect(duplicateServerName('HK-01', AppLocalizationsZh()), 'HK-01 副本');
    expect(duplicateServerName('HK-01', AppLocalizationsEn()), 'HK-01 copy');
    final long = '😀' * 40; // 80 UTF-16 units
    for (final l10n in [AppLocalizationsZh(), AppLocalizationsEn()]) {
      final name = duplicateServerName(long, l10n);
      expect(name.length, lessThanOrEqualTo(80));
      expect(name, endsWith(l10n.r14ServerCopyName('').trim()));
      expect(name.runes.every((r) => r != 0xFFFD), isTrue);
    }
  });

  test('template drops identifying and purchase-specific data', () {
    final t = duplicateServerTemplate(source, AppLocalizationsEn());
    expect(t.resources!.ip, isEmpty);
    expect(t.startDate, isNull);
    expect(t.notes, isEmpty);
    expect(t.favorite, isFalse);
    expect(t.host, isEmpty);
    expect(t.name, 'Tokyo-1 copy');
  });
}
