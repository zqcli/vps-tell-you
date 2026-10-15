// Renders the launcher icon masters from `AppLogoPainter`:
//   flutter test tool/app_icon_test.dart
// then run `python3 tool/app_icons.py` to resize them into the iOS and
// Android icon sets. Kept out of test/ so the normal suite never writes files.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/core/ui/app_logo.dart';

void main() {
  test('render icon masters', () async {
    final out = Directory('build/app_icon')..createSync(recursive: true);
    for (final shape in AppLogoShape.values) {
      final recorder = ui.PictureRecorder();
      AppLogoPainter(shape: shape)
          .paint(Canvas(recorder), const Size.square(1024));
      final image = await recorder.endRecording().toImage(1024, 1024);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/${shape.name}.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    }
  });
}
