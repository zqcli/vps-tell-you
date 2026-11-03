import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/connections/terminal_font.dart';

import 'widget_test_assets.dart';

Future<void> loadTerminalTestFonts(
  WidgetTester tester, {
  String? fallbackPath,
  bool loadFallback = true,
  bool requireFallback = false,
}) async {
  await loadTestFont(tester, terminalFontFamily, const [
    'assets/fonts/DejaVuSansMono.ttf',
    'assets/fonts/DejaVuSansMono-Bold.ttf',
  ]);
  if (!loadFallback) return;
  await tester.runAsync(() async {
    final cjk = File(
      fallbackPath ??
          Platform.environment['VPS_TERMINAL_CJK_FONT'] ??
          '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    );
    if (await cjk.exists()) {
      final bytes = ByteData.sublistView(await cjk.readAsBytes());
      for (final family in [
        'Roboto',
        'Noto Sans CJK SC',
        'Noto Sans Mono CJK SC',
      ]) {
        final loader = FontLoader(family)..addFont(Future.value(bytes));
        await loader.load();
      }
    } else if (requireFallback) {
      fail('Visual evidence requires the configured real CJK font.');
    }
  });
  final root = Platform.environment['FLUTTER_BOOTSTRAP_ROOT'];
  if (root != null) {
    await loadTestFont(tester, 'MaterialIcons', [
      '$root/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
  } else if (requireFallback) {
    fail('Visual evidence requires the real MaterialIcons font.');
  }
}

/// Seed through the real command panel without requesting the terminal IME.
Future<void> seedTerminalDraft(WidgetTester tester, String text) async {
  if (text.isEmpty) return;
  await tester.tap(find.byKey(const ValueKey('terminal-commands')));
  await tester.pumpAndSettle();
  tester
          .widget<TextField>(find.byKey(const ValueKey('terminal-draft')))
          .controller!
          .text =
      text;
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('terminal-commands-close')));
  await tester.pumpAndSettle();
}
