import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_form.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resource_fields.dart';

import 'support/reminder_platform.dart';

void main() {
  final now = DateTime(2026, 10, 7);
  ServerRecord fixture({int? amount = 3650}) => ServerRecord(
    id: 'locale-terms',
    name: '用户名称 Original',
    vendor: '用户厂商 Provider',
    billing: BillingKind.prepaid,
    currency: 'USD',
    amountMinor: amount,
    cycleMonths: 12,
    startDate: const LedgerDate(2026, 1, 1),
    dueDate: const LedgerDate(2027, 1, 1),
    spec: '用户自填中文规格',
    createdAt: now,
    updatedAt: now,
  );
  test('English unknown and zero amounts retain original currency without converting value', () {
    final en = AppLocalizationsEn();
    expect(fixture(amount: null).billingLabelFor(en), '— USD/year');
    expect(fixture(amount: 0).billingLabelFor(en), '0.00 USD/year');
    expect(fixture().billingLabelFor(en), '36.50 USD/year');
    expect(fixture().money!.minor, 3650);
  });

  group('localized server forms', () {
    late Directory directory;
    late LedgerStore store;
    late LedgerController ledger;
    late ServerRecord record;
    late ValueNotifier<Locale> locale;
    setUp(() async {
      sqfliteFfiInit();
      directory = await Directory.systemTemp.createTemp('server-l10n-');
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${directory.path}/ledger.db',
        clock: () => now,
      );
      await store.saveServer(fixture(), isNew: true);
      record = (await store.servers()).single;
      await store.recordPayment(
        id: 'paid-fixture',
        server: record,
        amount: const Money('USD', 3650),
        paidDate: const LedgerDate(2026, 10, 7),
        cycleCount: 1,
        until: const LedgerDate(2028, 1, 1),
        confirmed: true,
      );
      ledger = LedgerController(
        store,
        clock: () => now,
        reminderPlatform: FakeReminderPlatform()..supported = false,
      );
      await ledger.refresh();
      record = ledger.records.single;
      locale = ValueNotifier(const Locale('en'));
    });
    tearDown(() async {
      locale.dispose();
      ledger.dispose();
      await store.close();
      await directory.delete(recursive: true);
    });
    Future<void> mount(WidgetTester tester, Widget page) async {
      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (_, current, _) => MaterialApp(
            locale: current,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: page,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> reveal(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        250,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 60,
      );
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'payment terms stay locked by field ID in English and Chinese',
      (tester) async {
        await mount(tester, ServerForm(controller: ledger, record: record));
        Future<void> expectLocked(String metered, String lockHelp) async {
          final billing = find.byKey(const ValueKey('field-billing'));
          await reveal(tester, billing);
          expect(
            tester.widget<AppSegmented<BillingKind>>(billing).value,
            BillingKind.prepaid,
          );
          // The segmented control cannot be disabled: it absorbs the tap and
          // explains the lock instead of changing the billing type.
          expect(find.text(lockHelp), findsOneWidget);
          await tester.tap(
            find.descendant(of: billing, matching: find.text(metered)),
            warnIfMissed: false,
          );
          await tester.pump();
          expect(find.text(lockHelp), findsNWidgets(2));
          expect(
            tester.widget<AppSegmented<BillingKind>>(billing).value,
            BillingKind.prepaid,
          );
          for (final id in ['field-cycle', 'field-start', 'field-due']) {
            await reveal(tester, find.byKey(ValueKey(id)));
            await tester.tap(find.byKey(ValueKey(id)));
            await tester.pumpAndSettle();
            expect(find.byType(BottomSheet), findsNothing);
          }
        }

        await expectLocked(
          'Metered',
          AppLocalizationsEn().serverPaymentLockHelp,
        );
        locale.value = const Locale('zh');
        await tester.pumpAndSettle();
        ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
            .clearSnackBars();
        await tester.pumpAndSettle();
        await expectLocked('按量', AppLocalizationsZh().serverPaymentLockHelp);
        expect(ledger.records.single.toMap(), record.toMap());
        expect(record.spec, '用户自填中文规格');
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      'resource validation retranslates without resetting entered IP',
      (tester) async {
        final key = GlobalKey<ServerResourceFieldsState>();
        locale.value = const Locale('zh');
        await mount(
          tester,
          Scaffold(
            body: SingleChildScrollView(child: ServerResourceFields(key: key)),
          ),
        );
        final ip = find.byKey(const ValueKey('resource-ip'));
        await tester.enterText(ip, '192.0.2.10');
        expect(key.currentState!.validateAndRead(), isNull);
        await tester.pumpAndSettle();
        locale.value = const Locale('en');
        await tester.pumpAndSettle();
        expect(find.text('192.0.2.10'), findsOneWidget);
        expect(find.textContaining('Enter a valid hostname'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}
