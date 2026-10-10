import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_detail.dart';
import 'package:vps_tell_you/servers/server_form.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resources.dart';

import 'support/form_test_helpers.dart';

/// Regression: hardware that came from a panel adapter (API markers set,
/// address copied from the API IP, specification generated from it) must show
/// the user's manual edits everywhere after saving.
void main() {
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  late ServerRecord imported;

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('hw-refresh-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
    );
    ledger = LedgerController(store);
    final resources = ServerResources(
      ip: '192.0.2.40',
      hostname: 'api-host.example',
      vcpu: 2,
      ramBytes: 2 * 1073741824,
      diskBytes: 30 * 1073741824,
      trafficBytes: 1099511627776,
      trafficPeriodMonths: 1,
      apiFields: ServerResources.fieldKeys,
    );
    // Exactly what a panel import stores: host = API IP, spec = summary.
    await store.saveServer(
      ServerRecord(
        id: 'imported',
        name: 'Adapter VPS',
        vendor: 'Panel',
        host: resources.ip,
        spec: resources.specSummary,
        resources: resources,
        createdAt: DateTime.utc(2026, 10, 6),
        updatedAt: DateTime.utc(2026, 10, 6),
      ),
      isNew: true,
    );
    await ledger.refresh();
    imported = ledger.byId('imported')!;
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  testWidgets(
    'manual edits of imported hardware replace API values on screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ServerDetail(controller: ledger, id: imported.id),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('192.0.2.40'), findsWidgets);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      Future<void> type(String key, String text) async {
        final f = find.byKey(ValueKey(key));
        await tester.ensureVisible(f);
        await tester.enterText(f, text);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }

      await type('resource-ramBytes', '4');
      await type('resource-diskBytes', '80');
      await type('resource-trafficBytes', '2');
      await chooseUnit(tester, 'trafficBytes', 'TiB');
      // The IP is the address (one concept): the hardware IP row is hidden.
      expect(find.byKey(const ValueKey('resource-ip')), findsNothing);
      await type('field-host', '192.0.2.99');
      await type('resource-hostname', 'manual-host.example');
      await tapSave(tester);

      final saved = (await store.servers()).single;
      expect(saved.resources!.ramBytes, 4 * 1073741824);
      expect(saved.resources!.diskBytes, 80 * 1073741824);
      expect(saved.resources!.trafficBytes, 2 * 1099511627776);
      expect(saved.host, '192.0.2.99');
      expect(saved.resources!.ip, '192.0.2.99');
      expect(saved.resources!.hostname, 'manual-host.example');
      expect(saved.resources!.apiFields, {'vcpu'});
      // Derived text follows the edit instead of keeping the API summary.
      expect(saved.spec, '2 vCPU · 4 GiB · 80 GiB');
      expect(saved.spec, isNot(contains('2 GiB')));

      expect(find.text('Adapter VPS'), findsWidgets);
      expect(find.text('192.0.2.99'), findsWidgets);
      expect(find.text('192.0.2.40'), findsNothing);
      expect(find.text('manual-host.example'), findsWidgets);
      expect(find.text('4 GiB'), findsWidgets);
      expect(find.text('80 GiB'), findsWidgets);
      expect(find.textContaining('2 TiB'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy spec text stays when there is no hardware to generate from',
    (tester) async {
      await store.saveServer(
        ServerRecord(
          id: 'legacy-spec',
          name: 'Legacy',
          vendor: 'V',
          spec: 'Custom 4C/8G note',
          createdAt: DateTime.utc(2026, 10, 6),
          updatedAt: DateTime.utc(2026, 10, 6),
        ),
        isNew: true,
      );
      await ledger.refresh();
      final legacy = ledger.byId('legacy-spec')!;
      expect(
        serverSpecSummary(legacy, AppLocalizationsZh()),
        'Custom 4C/8G note',
      );
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ServerForm(controller: ledger, record: legacy),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('field-spec')), findsNothing);
      await tapSave(tester);
      var saved = (await store.servers()).singleWhere(
        (s) => s.id == 'legacy-spec',
      );
      expect(saved.spec, 'Custom 4C/8G note');
      expect(saved.notes, isEmpty);
      // Once hardware is known the generated text wins and the old text moves
      // to the notes instead of being lost.
      await tester.pumpWidget(const SizedBox());
      await ledger.refresh();
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ServerForm(
            controller: ledger,
            record: ledger.byId('legacy-spec')!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await setVcpu(tester, 4);
      await tapSave(tester);
      saved = (await store.servers()).singleWhere((s) => s.id == 'legacy-spec');
      expect(saved.spec, '4 vCPU');
      expect(saved.notes, contains('Custom 4C/8G note'));
      expect(serverSpecSummary(saved, AppLocalizationsEn()), '4 vCPU');
    },
  );
}
