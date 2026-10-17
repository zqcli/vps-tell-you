import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/app.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/data/ledger_store.dart';

import 'support/reminder_platform.dart';

Widget _host(
  Widget child, {
  AppGlassStyle? style,
  bool highContrast = false,
  Brightness brightness = Brightness.light,
}) {
  Widget app = MaterialApp(
    theme: appTheme(brightness: brightness),
    home: MediaQuery(
      data: MediaQueryData(highContrast: highContrast),
      child: Scaffold(body: Center(child: child)),
    ),
  );
  if (style != null) app = AppGlassScope(style: style, child: app);
  return app;
}

void main() {
  tearDown(AppGlassConfig.resetForTest);

  group('version parsing', () {
    test('iOS version strings', () {
      expect(
        AppGlassConfig.parseIosMajorVersion('Version 26.0 (Build 23A340)'),
        26,
      );
      expect(
        AppGlassConfig.parseIosMajorVersion('Version 26.2 (Build 23C54)'),
        26,
      );
      expect(
        AppGlassConfig.parseIosMajorVersion('Version 27.0 (Build 24A1)'),
        27,
      );
      expect(
        AppGlassConfig.parseIosMajorVersion('Version 18.7.7 (Build 22H333)'),
        18,
      );
      expect(AppGlassConfig.parseIosMajorVersion('26'), 26);
    });

    test('malformed strings are null', () {
      expect(AppGlassConfig.parseIosMajorVersion(null), isNull);
      expect(AppGlassConfig.parseIosMajorVersion(''), isNull);
      expect(AppGlassConfig.parseIosMajorVersion('Version unknown'), isNull);
    });

    test('styleFor: liquid only on iOS >= 26', () {
      AppGlassStyle f(TargetPlatform p, String? v) =>
          AppGlassConfig.styleFor(p, v);
      expect(f(TargetPlatform.iOS, 'Version 26.0 (Build 1)'), isLiquid);
      expect(f(TargetPlatform.iOS, 'Version 27.0 (Build 1)'), isLiquid);
      expect(f(TargetPlatform.iOS, 'Version 26.2 (Build 1)'), isLiquid);
      expect(f(TargetPlatform.iOS, 'Version 18.7.7 (Build 1)'), isFrosted);
      expect(f(TargetPlatform.iOS, 'Version 25.9 (Build 1)'), isFrosted);
      expect(f(TargetPlatform.iOS, 'garbage'), isFrosted);
      expect(f(TargetPlatform.iOS, null), isFrosted);
      expect(f(TargetPlatform.android, 'Version 26.2 (Build 1)'), isFrosted);
      expect(f(TargetPlatform.macOS, 'Version 26.2 (Build 1)'), isFrosted);
    });
  });

  group('style resolution', () {
    testWidgets('default test platform is frosted', (tester) async {
      late AppGlassStyle seen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = context.glassStyle;
            return const SizedBox();
          },
        ),
      );
      expect(seen, AppGlassStyle.frosted);
    });

    testWidgets('injected OS version drives detection on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      AppGlassConfig.osVersionReader = () => 'Version 26.2 (Build 23C54)';
      late AppGlassStyle seen;
      Widget probe() => Builder(
        builder: (context) {
          seen = context.glassStyle;
          return const SizedBox();
        },
      );
      await tester.pumpWidget(probe());
      expect(seen, AppGlassStyle.liquid);

      AppGlassConfig.resetForTest();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      AppGlassConfig.osVersionReader = () => 'Version 18.7.7 (Build 22H333)';
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(probe());
      expect(seen, AppGlassStyle.frosted);

      AppGlassConfig.resetForTest();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      AppGlassConfig.osVersionReader = () => throw const FileSystemException();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(probe());
      expect(seen, AppGlassStyle.frosted, reason: 'reader failure is safe');
      // Must be unset before the test ends (the invariant check runs first).
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('scope beats debug override', (tester) async {
      AppGlassConfig.debugOverride = AppGlassStyle.liquid;
      late AppGlassStyle seen;
      await tester.pumpWidget(
        AppGlassScope(
          style: AppGlassStyle.frosted,
          child: Builder(
            builder: (context) {
              seen = context.glassStyle;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, AppGlassStyle.frosted);
    });
  });

  group('AppGlass structure', () {
    Finder blur() => find.descendant(
      of: find.byType(AppGlass),
      matching: find.byType(BackdropFilter),
    );

    for (final style in AppGlassStyle.values) {
      testWidgets('${style.name}: blurs the backdrop and keeps its size', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            const AppGlass(
              borderRadius: AppGlass.capsule,
              child: SizedBox(width: 120, height: 48),
            ),
            style: style,
          ),
        );
        expect(blur(), findsOneWidget);
        expect(tester.getSize(find.byType(AppGlass)), const Size(120, 48));
      });

      testWidgets('${style.name}: high contrast is opaque, no blur', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            const AppGlass(
              kind: AppGlassKind.floating,
              borderRadius: AppGlass.capsule,
              child: SizedBox(width: 120, height: 48),
            ),
            style: style,
            highContrast: true,
          ),
        );
        expect(blur(), findsNothing);
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(AppGlass),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = box.decoration as BoxDecoration;
        expect(decoration.color!.a, 1, reason: 'opaque surface');
        expect(decoration.border, isNotNull, reason: 'visible outline');
      });
    }

    testWidgets('liquid paints a rim; frosted does not', (tester) async {
      Finder rim() => find.descendant(
        of: find.byType(AppGlass),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.foregroundPainter != null,
        ),
      );
      const glass = AppGlass(
        borderRadius: AppGlass.capsule,
        child: SizedBox(width: 120, height: 48),
      );
      await tester.pumpWidget(_host(glass, style: AppGlassStyle.liquid));
      expect(rim(), findsOneWidget);
      await tester.pumpWidget(_host(glass, style: AppGlassStyle.frosted));
      expect(rim(), findsNothing);
    });

    testWidgets('frosted control without fill paints nothing', (tester) async {
      await tester.pumpWidget(
        _host(
          const AppGlass(
            kind: AppGlassKind.control,
            child: SizedBox(width: 40, height: 40),
          ),
          style: AppGlassStyle.frosted,
        ),
      );
      expect(blur(), findsNothing);
    });

    testWidgets('liquid and frosted both work in dark', (tester) async {
      for (final style in AppGlassStyle.values) {
        await tester.pumpWidget(
          _host(
            const AppGlass(
              kind: AppGlassKind.floating,
              borderRadius: AppGlass.capsule,
              child: SizedBox(width: 120, height: 48),
            ),
            style: style,
            brightness: Brightness.dark,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(blur(), findsOneWidget);
      }
    });
  });

  group('floating tab bar', () {
    late Directory directory;
    setUp(() async {
      sqfliteFfiInit();
      directory = await Directory.systemTemp.createTemp('vps-glass-');
    });
    tearDown(() => directory.delete(recursive: true));

    for (final style in AppGlassStyle.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${style.name} at 320 px, text x$scale: tabs reachable, '
            'content not hidden', (tester) async {
          tester.view.physicalSize = const Size(640, 1280);
          tester.view.devicePixelRatio = 2;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          late LedgerStore store;
          await tester.runAsync(() async {
            store = await LedgerStore.open(
              factory: databaseFactoryFfiNoIsolate,
              path: '${directory.path}/ledger-$style-$scale.sqlite3',
            );
            await store.loadDemo();
          });
          await tester.pumpWidget(
            AppGlassScope(
              style: style,
              child: LedgerApp(
                openStore: () async => store,
                reminderPlatform: FakeReminderPlatform(),
              ),
            ),
          );
          for (
            var i = 0;
            i < 20 && find.byType(HomeShell).evaluate().isEmpty;
            i++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
          }
          await tester.pumpAndSettle();

          // The bar has the same four tabs inside the screen width.
          for (var i = 0; i < 4; i++) {
            final rect = tester.getRect(find.byKey(ValueKey('tab-$i')));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(320));
            expect(rect.bottom, lessThanOrEqualTo(640));
          }
          // Only liquid floats inset from the edges.
          final first = tester.getRect(find.byKey(const ValueKey('tab-0')));
          final last = tester.getRect(find.byKey(const ValueKey('tab-3')));
          expect(
            first.left > 8 && last.right < 312,
            style == AppGlassStyle.liquid,
          );

          // Settings tab: scroll to the end; the last section must end
          // above the bar.
          await tester.tap(find.byKey(const ValueKey('tab-3')));
          await tester.pumpAndSettle();
          final page = find.byKey(const ValueKey('tab-page-3'));
          final scrollable = find
              .descendant(of: page, matching: find.byType(Scrollable))
              .first;
          await tester.drag(scrollable, const Offset(0, -6000));
          await tester.pumpAndSettle();
          final sections = find.descendant(
            of: page,
            matching: find.byType(AppSection),
          );
          expect(
            tester.getRect(sections.last).bottom,
            lessThanOrEqualTo(
              tester.getRect(find.byKey(const ValueKey('tab-3'))).top,
            ),
          );
        });
      }
    }
  });
}

final isLiquid = equals(AppGlassStyle.liquid);
final isFrosted = equals(AppGlassStyle.frosted);
