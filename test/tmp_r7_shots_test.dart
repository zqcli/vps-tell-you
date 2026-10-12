import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/providers/provider_record.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_list.dart';

import 'support/catalog_fixture.dart';

void main() {
  late Directory directory;
  late LedgerStore store;
  late LedgerController ledger;
  var fontsLoaded = false;
  final now = DateTime.utc(2026, 10, 6);
  const out = '/tmp/vps-ui-dev/r7';

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('vps-r7-shot-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
      clock: () => now,
    );
    ledger = LedgerController(
      store,
      clock: () => now,
      catalog: MemoryCatalog(),
    );
    await store.saveProvider(
      ProviderRecord(id: 'mine', name: 'A provider with a rather long name for narrow phones', createdAt: now),
      isNew: true,
    );
    await ledger.refresh();
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('r7-shot')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(out).create(recursive: true);
      await File('$out/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final (lang, width, scale) in [
    ('zh', 390.0, 1.0),
    ('en', 390.0, 1.0),
    ('en', 320.0, 1.0),
    ('zh', 320.0, 2.0),
    ('en', 320.0, 2.0),
  ]) {
    testWidgets('shots $lang $width ${scale}x', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      if (!fontsLoaded) {
        await tester.runAsync(() async {
          final loader = FontLoader('R7 Font');
          loader.addFont(
            File(
              Platform.environment['VPS_R7_FONT'] ??
                  '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          );
          await loader.load();
          final icons = FontLoader('MaterialIcons');
          icons.addFont(
            File(
              '${Platform.environment['FLUTTER_BOOTSTRAP_ROOT']}/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes().then(ByteData.sublistView),
          );
          await icons.load();
        });
        fontsLoaded = true;
      }
      final base = appTheme();
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: base.copyWith(
            textTheme: base.textTheme.apply(fontFamily: 'R7 Font'),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(
              key: const ValueKey('r7-shot'),
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontFamily: 'R7 Font'),
                child: child!,
              ),
            ),
          ),
          home: Scaffold(body: ServerList(controller: ledger)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-server')));
      await tester.pumpAndSettle();
      final tag = '$lang-${width.toInt()}${scale == 1 ? '' : '-2x'}';
      await shot(tester, 'form-top-$tag');
      await tester.tap(find.byKey(const ValueKey('form-provider')));
      await tester.pumpAndSettle();
      await shot(tester, 'dropdown-provider-$tag');
      await tester.tap(
        find.byKey(const ValueKey('form-provider-catalog-fixture-cloud')),
      );
      await tester.pumpAndSettle();
      await shot(tester, 'form-catalog-chosen-$tag');
      await tester.tap(find.byKey(const ValueKey('form-package')));
      await tester.pumpAndSettle();
      await shot(tester, 'dropdown-package-$tag');
    });
  }
}
