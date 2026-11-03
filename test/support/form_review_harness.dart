import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/core/app_theme.dart';

import 'widget_test_assets.dart';

/// Shared presentation setup; individual tests still own their form fixtures,
/// routes, geometry checks and interactions.
class FormReviewHarness {
  FormReviewHarness({
    required this.boundaryKey,
    required this.fontFamily,
    this.evidenceDirectory,
    this.fontPath,
  });

  final Key boundaryKey;
  final String fontFamily;
  final String? evidenceDirectory, fontPath;
  bool _fontsLoaded = false;

  Future<void> mount(
    WidgetTester tester, {
    required WidgetBuilder page,
    Size size = const Size(320, 844),
    double scale = 2,
    ValueListenable<double>? textScale,
    Brightness brightness = Brightness.light,
    String? routeLabel,
    bool captureRoutes = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (evidenceDirectory != null && !_fontsLoaded) {
      await loadTestFont(tester, fontFamily, [
        fontPath ??
            Platform.environment['VPS_FORM_EVIDENCE_FONT_PATH'] ??
            '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
      ]);
      await loadTestFont(tester, 'MaterialIcons', [
        '${Platform.environment['FLUTTER_BOOTSTRAP_ROOT']}/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ]);
      _fontsLoaded = true;
    }
    final theme = appTheme(brightness: brightness);
    Widget boundary(Widget? child) =>
        RepaintBoundary(key: boundaryKey, child: child);
    Widget scaled(BuildContext context, double factor, Widget? child) =>
        MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(factor)),
          child: child!,
        );
    final home = Builder(
      builder: routeLabel == null
          ? page
          : (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: page),
                  ),
                  child: Text(routeLabel),
                ),
              ),
            ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: evidenceDirectory == null
            ? theme
            : theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: fontFamily),
                appBarTheme: theme.appBarTheme.copyWith(
                  titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
                    fontFamily: fontFamily,
                  ),
                ),
              ),
        builder: (context, child) {
          final content = captureRoutes ? boundary(child) : child;
          return textScale == null
              ? scaled(context, scale, content)
              : ValueListenableBuilder<double>(
                  valueListenable: textScale,
                  child: content,
                  builder: scaled,
                );
        },
        home: captureRoutes ? home : boundary(home),
      ),
    );
    if (routeLabel != null) await tester.tap(find.text(routeLabel));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (evidenceDirectory == null) return;
    await tester.pumpAndSettle();
    await captureTestWidget(
      tester,
      find.byKey(boundaryKey),
      evidenceDirectory,
      name,
    );
  }
}
