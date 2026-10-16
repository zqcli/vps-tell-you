import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The VPS Tell You mark: a server stack inside a renewal countdown ring. The
/// bright arc is the time left in the term; its amber head and the amber
/// status dot are the app telling you one server is coming due.
///
/// Drawn in a 1024-unit grid so the in-app logo and the exported launcher
/// icons (`tool/app_icon_test.dart`) come from the same geometry.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 60, this.semanticLabel});

  final double size;

  /// Read by screen readers; `null` (the default) marks the logo decorative,
  /// for places where the app name is already written next to it.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final logo = SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: AppLogoPainter()),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: logo)
        : Semantics(label: semanticLabel, image: true, child: logo);
  }
}

enum AppLogoShape {
  /// Rounded tile for use inside the app and Android legacy icons.
  rounded,

  /// Full-bleed square: iOS masks the corners itself.
  square,

  /// Bubble only on a transparent canvas, scaled into the Android adaptive
  /// icon safe zone; the gradient is the separate background layer.
  foreground,
}

class AppLogoPainter extends CustomPainter {
  const AppLogoPainter({this.shape = AppLogoShape.rounded});

  final AppLogoShape shape;

  static const gradientStart = Color(0xFF3B82F6);
  static const gradientEnd = Color(0xFF4F46E5);
  static const _white = Color(0xFFFFFFFF);
  static const _line = Color(0xFFC7D2FE);
  static const _green = Color(0xFF22C55E);
  static const _amber = Color(0xFFF59E0B);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / 1024);
    const tile = Rect.fromLTWH(0, 0, 1024, 1024);
    if (shape != AppLogoShape.foreground) {
      final background = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientStart, gradientEnd],
        ).createShader(tile);
      if (shape == AppLogoShape.rounded) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(tile, const Radius.circular(232)),
          background,
        );
      } else {
        canvas.drawRect(tile, background);
      }
    } else {
      // Adaptive icons show roughly the middle two thirds of the layer.
      canvas.translate(512, 512);
      canvas.scale(0.74);
      canvas.translate(-512, -512);
    }

    // Countdown ring: faint full track, bright 270° from 12 o'clock
    // clockwise, amber head at 9 o'clock.
    const center = Offset(512, 512);
    const radius = 392.0;
    const stroke = 60.0;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = _white.withValues(alpha: 0.24),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..color = _white,
    );
    canvas.drawCircle(
      const Offset(512 - radius, 512),
      54,
      Paint()..color = _amber,
    );

    // Three server units: status dot and a label line.
    const width = 470.0, height = 120.0, gap = 30.0;
    const top = 512 - (3 * height + 2 * gap) / 2;
    for (var i = 0; i < 3; i++) {
      final unit = Rect.fromLTWH(
        512 - width / 2,
        top + i * (height + gap),
        width,
        height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(unit, const Radius.circular(36)),
        Paint()..color = _white,
      );
      canvas.drawCircle(
        Offset(unit.left + 60, unit.center.dy),
        24,
        Paint()..color = i == 2 ? _amber : _green,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            unit.left + 112,
            unit.center.dy - 12,
            i == 1 ? 170 : 230,
            24,
          ),
          const Radius.circular(12),
        ),
        Paint()..color = _line,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(AppLogoPainter oldDelegate) => oldDelegate.shape != shape;
}
