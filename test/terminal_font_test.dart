import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/connections/terminal_font.dart';
import 'package:xterm/xterm.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('offline font assets and complete copyright are pinned', () {
    const expected = {
      'DejaVuSansMono.ttf':
          '54bf827eb99404e8f430c330ad30f063334f637eba0109b6a18d4f566a8e9dd8',
      'DejaVuSansMono-Bold.ttf':
          '0d3c03d1b667192f91223660a3163325cf83132662fe4d9f7d6e596bf7a995c2',
    };
    var bytes = 0;
    for (final entry in expected.entries) {
      final data = File('assets/fonts/${entry.key}').readAsBytesSync();
      bytes += data.length;
      expect(sha256.convert(data).toString(), entry.value);
    }
    expect(bytes, 677408);
    final license = File('assets/fonts/LICENSE-DejaVu.txt').readAsStringSync();
    expect(license, contains('Copyright (c) 2003 by Bitstream'));
    expect(license, contains('DejaVu changes are in public domain'));
    expect(license, contains('Permission is hereby granted'));
    expect(license, contains('without prior written authorization'));
  });

  test('terminal rendering disables ligatures and preserves ANSI styles', () {
    const style = CodingTerminalStyle();
    final text = style.toTextStyle(bold: true, italic: true, underline: true);
    expect(text.fontFamily, terminalFontFamily);
    expect(text.fontWeight, FontWeight.bold);
    expect(text.fontStyle, FontStyle.italic);
    expect(text.decoration, TextDecoration.underline);
    expect(text.fontFeatures, const [
      FontFeature.disable('liga'),
      FontFeature.disable('clig'),
      FontFeature.disable('dlig'),
      FontFeature.disable('kern'),
    ]);
    expect(text.fontFamilyFallback, contains('Noto Sans CJK SC'));
  });

  testWidgets(
    'bundled normal and bold glyphs keep ASCII and box cells aligned',
    (tester) async {
      await tester.runAsync(() async {
        final font = FontLoader(terminalFontFamily);
        for (final file in ['DejaVuSansMono.ttf', 'DejaVuSansMono-Bold.ttf']) {
          font.addFont(
            File('assets/fonts/$file').readAsBytes().then(ByteData.sublistView),
          );
        }
        await font.load();
      });
      double measure(String text, {bool bold = false}) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: const CodingTerminalStyle().toTextStyle(bold: bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      }

      final cell = measure('m');
      expect(cell, closeTo(14 * 1233 / 2048, .02));
      for (final bold in [false, true]) {
        for (final text in [
          '0O1lI',
          '!= == => -> >= <=',
          '┌──┬──┐│└──┴──┘',
          '{}[]()/\\|_',
        ]) {
          expect(
            measure(text, bold: bold),
            closeTo(cell * text.length, .1),
            reason: '$text bold=$bold',
          );
        }
      }
      final terminal = Terminal();
      terminal.resize(40, 10);
      terminal.write('AB中文CD');
      expect(terminal.buffer.cursorX, 8);
      terminal.write('\r\n\x1b[1m0O1lI\x1b[0m');
      expect(terminal.buffer.cursorX, 5);
    },
  );
}
