import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

const terminalFontFamily = 'TerminalDejaVu';
const terminalFontFallback = <String>[
  'Noto Sans Mono CJK SC',
  'Noto Sans CJK SC',
  'PingFang SC',
  'monospace',
];

/// Rendering-only customization. No font substitutions change terminal bytes
/// or ANSI parsing, and coding ligatures never merge adjacent shell symbols.
class CodingTerminalStyle extends TerminalStyle {
  const CodingTerminalStyle({super.fontSize = 14, super.height = 1.3})
    : super(
        fontFamily: terminalFontFamily,
        fontFamilyFallback: terminalFontFallback,
      );

  @override
  TextStyle toTextStyle({
    Color? color,
    Color? backgroundColor,
    bool bold = false,
    bool italic = false,
    bool underline = false,
  }) => super
      .toTextStyle(
        color: color,
        backgroundColor: backgroundColor,
        bold: bold,
        italic: italic,
        underline: underline,
      )
      .copyWith(
        fontFeatures: const [
          FontFeature.disable('liga'),
          FontFeature.disable('clig'),
          FontFeature.disable('dlig'),
          FontFeature.disable('kern'),
        ],
      );
}

bool _licenseRegistered = false;
void registerTerminalFontLicense() {
  if (_licenseRegistered) return;
  _licenseRegistered = true;
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/LICENSE-DejaVu.txt');
    yield LicenseEntryWithLineBreaks(['DejaVu Sans Mono'], text);
  });
}
