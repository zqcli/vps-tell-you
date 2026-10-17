import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_palette.dart';

/// Which family of translucent chrome the app draws.
///
/// * [frosted] – the classic iOS blur bar (today's look): blurred backdrop,
///   palette tint and a hairline. Used on iOS < 26, Android and everywhere
///   else.
/// * [liquid] – an *emulation* of iOS 26 "Liquid Glass": blur + saturation
///   boost, a lighter tint, a thin specular rim (brighter at the top-left) and a
///   very soft inner highlight. No refraction, no motion.
///
/// Flutter has no Liquid Glass widget, so this is plain Dart painting.
enum AppGlassStyle {
  frosted,
  liquid;

  bool get isLiquid => this == liquid;
}

/// Decides which [AppGlassStyle] is used.
///
/// Order: [AppGlassScope] above the widget → [debugOverride] → the
/// `--dart-define=APP_GLASS=liquid|frosted` build flag → platform detection
/// ([styleFor]): `liquid` on iOS ≥ 26, `frosted` otherwise.
abstract final class AppGlassConfig {
  /// First iOS major version that gets [AppGlassStyle.liquid].
  static const liquidMinIosMajor = 26;

  /// Forces a style app-wide (debug builds / manual checks); `null` = detect.
  static AppGlassStyle? debugOverride;

  /// Reads the OS version string (`Platform.operatingSystemVersion`).
  /// Replace in tests.
  @visibleForTesting
  static String Function() osVersionReader = _readOsVersion;

  static String _readOsVersion() => Platform.operatingSystemVersion;

  static const _flag = String.fromEnvironment('APP_GLASS');

  /// Major version of an iOS `operatingSystemVersion` string such as
  /// `Version 26.2 (Build 23C54)` or `Version 18.7.7 (Build 22H333)`;
  /// `null` when it cannot be parsed.
  static int? parseIosMajorVersion(String? version) {
    if (version == null) return null;
    final match = RegExp(r'(\d{1,3})(?:\.\d+)*').firstMatch(version);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// Style for [platform] running OS [osVersion]. Unknown / unparsable
  /// versions fall back to [AppGlassStyle.frosted].
  static AppGlassStyle styleFor(TargetPlatform platform, String? osVersion) {
    if (platform != TargetPlatform.iOS) return AppGlassStyle.frosted;
    final major = parseIosMajorVersion(osVersion);
    return major != null && major >= liquidMinIosMajor
        ? AppGlassStyle.liquid
        : AppGlassStyle.frosted;
  }

  static AppGlassStyle? _detected;

  /// Style of this device, ignoring any override.
  static AppGlassStyle detect() {
    final cached = _detected;
    if (cached != null && !kDebugMode) return cached;
    String? version;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        version = osVersionReader();
      } on Object {
        version = null;
      }
    }
    return _detected = styleFor(defaultTargetPlatform, version);
  }

  /// Style to use below [context].
  static AppGlassStyle of(BuildContext context) {
    final scoped = context
        .dependOnInheritedWidgetOfExactType<AppGlassScope>()
        ?.style;
    if (scoped != null) return scoped;
    if (debugOverride != null) return debugOverride!;
    return switch (_flag) {
      'liquid' => AppGlassStyle.liquid,
      'frosted' => AppGlassStyle.frosted,
      _ => detect(),
    };
  }

  @visibleForTesting
  static void resetForTest() {
    debugOverride = null;
    osVersionReader = _readOsVersion;
    _detected = null;
  }
}

/// Fixes the [AppGlassStyle] for a subtree (tests, previews).
class AppGlassScope extends InheritedWidget {
  const AppGlassScope({super.key, required this.style, required super.child});

  final AppGlassStyle style;

  @override
  bool updateShouldNotify(AppGlassScope old) => style != old.style;
}

extension AppGlassContext on BuildContext {
  /// The glass style in effect here (see [AppGlassConfig.of]).
  AppGlassStyle get glassStyle => AppGlassConfig.of(this);
}

/// Role of an [AppGlass] surface; picks tint and shadow.
enum AppGlassKind {
  /// Full-width chrome docked to an edge (footer bar, collapsed nav bar).
  bar,

  /// Detached bar that floats above content (iOS 26 tab bar). Gets a faint
  /// ambient shadow in [AppGlassStyle.liquid].
  floating,

  /// Small control: nav buttons, search field, close button.
  control,
}

/// Edge of a [AppGlassKind.bar] that carries the hairline in
/// [AppGlassStyle.frosted].
enum AppGlassEdge { none, top, bottom }

/// Translucent chrome surface: blurred backdrop + palette tint.
///
/// One code path, two looks (see [AppGlassStyle]). Sizes never depend on the
/// style – the surface only paints behind / around [child].
///
/// With `MediaQuery.highContrast` (iOS "Increase Contrast") the surface turns
/// opaque with a visible outline and nothing is blurred.
///
/// Use it for chrome that floats over content (bars, controls, search) – never
/// for rows, cards or content.
class AppGlass extends StatelessWidget {
  const AppGlass({
    super.key,
    required this.child,
    this.kind = AppGlassKind.bar,
    this.borderRadius = BorderRadius.zero,
    this.edge = AppGlassEdge.none,
    this.blur = true,
    this.tint,
    this.frostedFill,
    this.style,
  });

  /// Capsule (stadium) radius for any height.
  static const capsule = BorderRadius.all(Radius.circular(999));

  final Widget child;
  final AppGlassKind kind;
  final BorderRadius borderRadius;

  /// Hairline side for flat bars in the frosted style (liquid has none).
  final AppGlassEdge edge;

  /// Blur the backdrop. Pass `false` for controls that sit on an
  /// already-blurred bar or a flat background.
  final bool blur;

  /// Overrides the palette-derived tint.
  final Color? tint;

  /// Background of a [AppGlassKind.control] in the frosted style (e.g. the
  /// grey search field); `null` paints nothing there.
  final Color? frostedFill;

  /// Forces a style (otherwise [AppGlassConfig.of]).
  final AppGlassStyle? style;

  /// Tint of a flat liquid bar; also used for the system navigation bar.
  static Color liquidBarTint(AppPalette p) =>
      p.barBg.withValues(alpha: p.isDark ? .72 : .70);

  /// iOS 26 "Liquid Glass" tint over the palette: light & airy in light mode.
  Color _liquidTint(AppPalette p) {
    if (tint != null) return tint!;
    return switch (kind) {
      AppGlassKind.bar => liquidBarTint(p),
      AppGlassKind.floating =>
        p.isDark
            ? const Color(0xFF1B1E26).withValues(alpha: .58)
            : Colors.white.withValues(alpha: .56),
      AppGlassKind.control =>
        p.isDark
            ? Colors.white.withValues(alpha: .10)
            : Colors.white.withValues(alpha: .72),
    };
  }

  // Shared instead of one native filter object per build.
  static final _liquidFilter = ImageFilter.compose(
    outer: const ColorFilter.matrix(_saturation),
    inner: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
  );
  static final _frostedFilter = ImageFilter.blur(sigmaX: 20, sigmaY: 20);

  // Luminance-preserving saturation (Rec. 709 weights), factor 1.2: glass
  // picks up some colour of what is behind it without shifting greys.
  static const _sat = 1.2;
  static const _saturation = <double>[
    .2126 + .7874 * _sat, .7152 - .7152 * _sat, .0722 - .0722 * _sat, 0, 0, //
    .2126 - .2126 * _sat, .7152 + .2848 * _sat, .0722 - .0722 * _sat, 0, 0, //
    .2126 - .2126 * _sat, .7152 - .7152 * _sat, .0722 + .9278 * _sat, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final effective = style ?? context.glassStyle;
    final highContrast = MediaQuery.highContrastOf(context);
    final liquid = effective.isLiquid;

    if (highContrast) return _opaque(p);
    return liquid ? _liquid(p) : _frosted(p);
  }

  Widget _clip(Widget child) => borderRadius == BorderRadius.zero
      ? ClipRect(child: child)
      : ClipRRect(borderRadius: borderRadius, child: child);

  /// Opaque surface + outline for "Increase Contrast".
  Widget _opaque(AppPalette p) {
    final base = kind == AppGlassKind.bar
        ? Color.alphaBlend(p.barBg, p.bg)
        : kind == AppGlassKind.floating
        ? p.surface
        : (frostedFill == null ? p.surface : Color.alphaBlend(p.fill, p.bg));
    final flat = borderRadius == BorderRadius.zero;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(base, p.bg),
        borderRadius: flat ? null : borderRadius,
        border: flat
            ? _hairline(p.text3, 1)
            : Border.all(color: p.text3, width: 1),
      ),
      child: child,
    );
  }

  Border? _hairline(Color color, double width) => switch (edge) {
    AppGlassEdge.none => null,
    AppGlassEdge.top => Border(
      top: BorderSide(color: color, width: width),
    ),
    AppGlassEdge.bottom => Border(
      bottom: BorderSide(color: color, width: width),
    ),
  };

  /// Today's look: blur 20, palette bar colour, hairline.
  Widget _frosted(AppPalette p) {
    if (kind == AppGlassKind.control) {
      if (frostedFill == null) return child;
      return _clip(ColoredBox(color: frostedFill!, child: child));
    }
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: tint ?? p.barBg,
        border: _hairline(p.separator, .5),
      ),
      child: child,
    );
    return _clip(
      blur
          ? BackdropFilter(filter: _frostedFilter, child: decorated)
          : decorated,
    );
  }

  Widget _liquid(AppPalette p) {
    final flat = borderRadius == BorderRadius.zero;
    final dark = p.isDark;
    // Two layers: a gradient replaces `color` inside one BoxDecoration.
    Widget surface = ColoredBox(
      color: _liquidTint(p),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Very soft inner highlight: light spilling in from the top.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: dark ? .07 : .22),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0, .55],
          ),
        ),
        child: child,
      ),
    );
    if (blur) {
      surface = BackdropFilter(filter: _liquidFilter, child: surface);
    }
    surface = _clip(surface);
    if (!flat) {
      surface = CustomPaint(
        foregroundPainter: _RimPainter(borderRadius: borderRadius, dark: dark),
        child: surface,
      );
    }
    if (kind == AppGlassKind.floating) {
      surface = CustomPaint(
        painter: _AmbientShadowPainter(borderRadius: borderRadius, dark: dark),
        child: surface,
      );
    }
    return surface;
  }
}

/// 1 px specular rim: bright at the top-left, a faint shade at the bottom-right.
class _RimPainter extends CustomPainter {
  const _RimPainter({required this.borderRadius, required this.dark});

  final BorderRadius borderRadius;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect).deflate(.5);
    final colors = dark
        ? [
            Colors.white.withValues(alpha: .34),
            Colors.white.withValues(alpha: .05),
            Colors.white.withValues(alpha: .13),
          ]
        : [
            Colors.white.withValues(alpha: .95),
            const Color(0xFF8A90A0).withValues(alpha: .08),
            const Color(0xFF8A90A0).withValues(alpha: .20),
          ];
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
        stops: const [0, .5, 1],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.borderRadius != borderRadius || old.dark != dark;
}

/// Faint shadow around (not under) a floating bar, so the translucent glass
/// is not darkened from behind.
class _AmbientShadowPainter extends CustomPainter {
  const _AmbientShadowPainter({required this.borderRadius, required this.dark});

  final BorderRadius borderRadius;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = borderRadius.toRRect(Offset.zero & size);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & size).inflate(40)),
      Path()..addRRect(rrect),
    );
    canvas
      ..save()
      ..clipPath(outside)
      ..drawRRect(
        rrect.shift(const Offset(0, 4)),
        Paint()
          ..color = Colors.black.withValues(alpha: dark ? .30 : .09)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_AmbientShadowPainter old) =>
      old.borderRadius != borderRadius || old.dark != dark;
}
