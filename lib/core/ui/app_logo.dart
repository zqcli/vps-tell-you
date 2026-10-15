import 'package:flutter/widgets.dart';

/// The vps tell you mark: a speech bubble listing three servers, each with a
/// status dot — the ledger "telling you" about your VPSs.
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
  static const _dots = [
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 1024;
    canvas.save();
    canvas.scale(unit);
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
      // Adaptive icons show the middle 66 % of a 108 dp layer.
      canvas.translate(512, 512);
      canvas.scale(0.75);
      canvas.translate(-512, -512);
    }

    // Bubble with a tail at the lower left.
    const body = Rect.fromLTRB(196, 228, 828, 724);
    final tail = Path()
      ..moveTo(296, 660)
      ..cubicTo(300, 770, 276, 822, 224, 852)
      ..cubicTo(332, 856, 410, 806, 470, 700)
      ..close();
    final bubble = Path.combine(
      PathOperation.union,
      Path()
        ..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(128))),
      tail,
    );
    canvas.drawShadow(bubble, const Color(0xFF1E1B4B), 24, false);
    canvas.drawPath(bubble, Paint()..color = const Color(0xFFFFFFFF));

    // Three server rows: status dot plus a text line.
    for (var i = 0; i < 3; i++) {
      final top = 300.0 + i * 122;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(268, top, 488, 98),
          const Radius.circular(49),
        ),
        Paint()..color = const Color(0xFFEEF0FF),
      );
      canvas.drawCircle(Offset(317, top + 49), 25, Paint()..color = _dots[i]);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(372, top + 37, i == 1 ? 228 : 300, 24),
          const Radius.circular(12),
        ),
        Paint()..color = const Color(0xFF6366F1).withValues(alpha: 0.55),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(AppLogoPainter oldDelegate) => oldDelegate.shape != shape;
}
