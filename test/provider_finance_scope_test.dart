import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/cloud/provider_record.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/finance/finance_page.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'support/reminder_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('provider finance scope uses stable ownership and preserves legacy labels as data', () async {
    final dir = await Directory.systemTemp.createTemp('provider-finance-');
    final store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${dir.path}/ledger.db',
    );
    final ledger = LedgerController(
      store,
      reminderPlatform: FakeReminderPlatform(),
    );
    try {
      final now = DateTime.utc(2026, 10, 8);
      for (final id in ['one', 'two']) {
        await store.saveProvider(
          ProviderRecord(id: id, name: 'Provider $id', createdAt: now),
          isNew: true,
        );
      }
      for (final item in [
        ('a', 'one'),
        ('b', 'one'),
        ('c', 'two'),
        ('legacy', ''),
        ('unassigned', ''),
      ]) {
        await store.saveServer(
          ServerRecord(
            id: item.$1,
            name: 'Server ${item.$1}',
            vendor: item.$1 == 'unassigned' ? '' : 'Historical vendor',
            providerId: item.$2.isEmpty ? null : item.$2,
            billing: BillingKind.prepaid,
            amountMinor: 1200,
            cycleMonths: 1,
            startDate: const LedgerDate(2026, 10, 1),
            dueDate: const LedgerDate(2026, 11, 1),
            createdAt: now,
            updatedAt: now,
          ),
          isNew: true,
        );
      }
      await ledger.refresh();
      final one = ledger.byId('a')!;
      final key = ledger.providerGroupKey(one);
      expect(financeScope(ledger, null, vendor: key).map((s) => s.id).toSet(), {
        'a',
        'b',
      });
      expect(
        ledger.providerNameFor(one, l10n: AppLocalizationsEn()),
        'Provider one',
      );
      expect(
        ledger.providerNameFor(
          ledger.byId('legacy')!,
          l10n: AppLocalizationsEn(),
        ),
        'Historical vendor',
      );
      expect(
        ledger.providerNameFor(
          ledger.byId('unassigned')!,
          l10n: AppLocalizationsEn(),
        ),
        'Unspecified provider',
      );
      expect(ledger.active.map(ledger.providerGroupKey).toSet(), hasLength(4));
      final before = ledger.records.map((s) => s.toMap()).toList();
      final periods = (await store.servicePeriods())
          .map((p) => p.toMap())
          .toList();
      await store.saveProvider(
        ProviderRecord(id: 'one', name: 'Renamed provider', createdAt: now),
        isNew: false,
      );
      await ledger.refresh();
      expect(ledger.providerGroupKey(ledger.byId('a')!), key);
      expect(financeScope(ledger, null, vendor: key).map((s) => s.id).toSet(), {
        'a',
        'b',
      });
      expect(
        ledger.providerNameFor(ledger.byId('a')!, l10n: AppLocalizationsEn()),
        'Renamed provider',
      );
      expect(ledger.records.map((s) => s.toMap()).toList(), before);
      expect(
        (await store.servicePeriods()).map((p) => p.toMap()).toList(),
        periods,
      );
      ledger.search = 'renamed provider';
      expect(ledger.visible.map((s) => s.id).toSet(), {'a', 'b'});
    } finally {
      ledger.dispose();
      await store.close();
      await dir.delete(recursive: true);
    }
  });
}
