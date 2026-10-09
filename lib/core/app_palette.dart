import 'package:flutter/material.dart';

/// Semantic colour roles of the redesigned UI (light + dark).
///
/// The values mirror the CSS variables of the approved demo
/// (`docs/ui-redesign/style.css`). Pages must read colours from here
/// (`context.palette`) instead of hardcoding hex values, so dark mode and
/// future tweaks work everywhere.
///
/// Soft tints (`primarySoft`, `greenSoft`, …) are opaque colours that are
/// already blended over [surface], so they are safe to use as pill / banner
/// backgrounds on cards and grouped rows.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.onPrimarySoft,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.fill,
    required this.fill2,
    required this.text,
    required this.text2,
    required this.text3,
    required this.separator,
    required this.green,
    required this.greenSoft,
    required this.amber,
    required this.amberSoft,
    required this.amberSolid,
    required this.red,
    required this.redSoft,
    required this.barBg,
    required this.segmentThumb,
    required this.toast,
  });

  /// Brightness this palette was built for.
  final Brightness brightness;

  /// Brand colour: links, selected tab, primary buttons, nav bar actions.
  final Color primary;

  /// Content drawn on top of [primary].
  final Color onPrimary;

  /// Tinted background for tonal buttons / blue pills.
  final Color primarySoft;

  /// Text on [primarySoft].
  final Color onPrimarySoft;

  /// Page background behind grouped lists (`--bg`).
  final Color bg;

  /// Card / grouped-row background (`--surface`).
  final Color surface;

  /// Slightly different surface for pressed rows and alert backgrounds.
  final Color surface2;

  /// Translucent grey fill for search fields, segmented tracks, ✕ buttons.
  final Color fill;

  /// Lighter [fill] used for pressed rows and neutral pills.
  final Color fill2;

  /// Primary text.
  final Color text;

  /// Secondary text (subtitles, section headers, values).
  final Color text2;

  /// Tertiary text (placeholders, chevrons, disabled).
  final Color text3;

  /// Hairline separator colour (use with 0.5 logical px thickness).
  final Color separator;

  /// Success / verified.
  final Color green;

  /// Background for green pills.
  final Color greenSoft;

  /// Warning text colour (≤30 days, missing data).
  final Color amber;

  /// Background for amber pills and banners.
  final Color amberSoft;

  /// Saturated amber for dots, progress bars and the favourite star.
  final Color amberSolid;

  /// Danger / overdue.
  final Color red;

  /// Background for red pills.
  final Color redSoft;

  /// Translucent colour of the navigation bar and tab bar (blurred behind).
  final Color barBg;

  /// Thumb colour of the sliding segmented control and selected mini tabs.
  final Color segmentThumb;

  /// Background of toasts / snack bars.
  final Color toast;

  /// Whether this is the dark variant.
  bool get isDark => brightness == Brightness.dark;

  /// The iOS green used by switches in both themes.
  static const switchGreen = Color(0xFF34C759);

  static final light = AppPalette(
    brightness: Brightness.light,
    primary: const Color(0xFF2F5BEA),
    onPrimary: Colors.white,
    primarySoft: const Color(0xFFE9EFFF),
    onPrimarySoft: const Color(0xFF2347C4),
    bg: const Color(0xFFF2F3F7),
    surface: Colors.white,
    surface2: const Color(0xFFF6F7FA),
    fill: const Color(0x1F767680),
    fill2: const Color(0x14767680),
    text: const Color(0xFF0F1726),
    // Slightly darker than the demo (#687083) so secondary text keeps 4.5:1
    // on the grey page background.
    text2: const Color(0xFF636B7E),
    text3: const Color(0xFFA0A6B2),
    separator: const Color(0x213C3C43),
    // Green / amber / red text colours are tuned to reach 4.5:1 on their soft
    // backgrounds; the hue stays the demo's.
    green: const Color(0xFF167A45),
    greenSoft: const Color(0xFFE3F5EA),
    amber: const Color(0xFFA65A07),
    amberSoft: const Color(0xFFFFF1DC),
    amberSolid: const Color(0xFFF59E0B),
    red: const Color(0xFFC62F38),
    redSoft: const Color(0xFFFDE9EA),
    barBg: const Color(0xD1F9F9FB),
    segmentThumb: Colors.white,
    toast: const Color(0xEB1E2026),
  );

  static final dark = _buildDark();

  static AppPalette _buildDark() {
    const surface = Color(0xFF171A21);
    Color soft(Color c, double a) =>
        Color.alphaBlend(c.withValues(alpha: a), surface);
    return AppPalette(
      brightness: Brightness.dark,
      primary: const Color(0xFF6F95FF),
      onPrimary: const Color(0xFF071233),
      primarySoft: soft(const Color(0xFF6F95FF), .16),
      onPrimarySoft: const Color(0xFFA9C0FF),
      bg: const Color(0xFF0A0C10),
      surface: surface,
      surface2: const Color(0xFF1E222B),
      fill: const Color(0x38788096),
      fill2: const Color(0x24788096),
      text: const Color(0xFFF1F3F8),
      text2: const Color(0xFF98A1B3),
      text3: const Color(0xFF5E6677),
      separator: const Color(0x14FFFFFF),
      green: const Color(0xFF3DD08A),
      greenSoft: soft(const Color(0xFF3DD08A), .14),
      amber: const Color(0xFFFFB547),
      amberSoft: soft(const Color(0xFFFFB547), .14),
      amberSolid: const Color(0xFFFFB547),
      red: const Color(0xFFFF6B72),
      redSoft: soft(const Color(0xFFFF6B72), .15),
      barBg: const Color(0xD112141A),
      segmentThumb: const Color(0xFF3A3F4B),
      toast: const Color(0xEB1E2026),
    );
  }

  /// Palette for [brightness].
  static AppPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Foreground / background pair for a [AppTone].
  (Color fg, Color bg) tone(AppTone tone) => switch (tone) {
    AppTone.neutral => (text2, fill2),
    AppTone.amber => (amber, amberSoft),
    AppTone.red => (red, redSoft),
    AppTone.green => (green, greenSoft),
    AppTone.blue => (onPrimarySoft, primarySoft),
  };

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? primary,
    Color? onPrimary,
    Color? primarySoft,
    Color? onPrimarySoft,
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? fill,
    Color? fill2,
    Color? text,
    Color? text2,
    Color? text3,
    Color? separator,
    Color? green,
    Color? greenSoft,
    Color? amber,
    Color? amberSoft,
    Color? amberSolid,
    Color? red,
    Color? redSoft,
    Color? barBg,
    Color? segmentThumb,
    Color? toast,
  }) => AppPalette(
    brightness: brightness ?? this.brightness,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    primarySoft: primarySoft ?? this.primarySoft,
    onPrimarySoft: onPrimarySoft ?? this.onPrimarySoft,
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surface2: surface2 ?? this.surface2,
    fill: fill ?? this.fill,
    fill2: fill2 ?? this.fill2,
    text: text ?? this.text,
    text2: text2 ?? this.text2,
    text3: text3 ?? this.text3,
    separator: separator ?? this.separator,
    green: green ?? this.green,
    greenSoft: greenSoft ?? this.greenSoft,
    amber: amber ?? this.amber,
    amberSoft: amberSoft ?? this.amberSoft,
    amberSolid: amberSolid ?? this.amberSolid,
    red: red ?? this.red,
    redSoft: redSoft ?? this.redSoft,
    barBg: barBg ?? this.barBg,
    segmentThumb: segmentThumb ?? this.segmentThumb,
    toast: toast ?? this.toast,
  );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < .5 ? brightness : other.brightness,
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primarySoft: l(primarySoft, other.primarySoft),
      onPrimarySoft: l(onPrimarySoft, other.onPrimarySoft),
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      fill: l(fill, other.fill),
      fill2: l(fill2, other.fill2),
      text: l(text, other.text),
      text2: l(text2, other.text2),
      text3: l(text3, other.text3),
      separator: l(separator, other.separator),
      green: l(green, other.green),
      greenSoft: l(greenSoft, other.greenSoft),
      amber: l(amber, other.amber),
      amberSoft: l(amberSoft, other.amberSoft),
      amberSolid: l(amberSolid, other.amberSolid),
      red: l(red, other.red),
      redSoft: l(redSoft, other.redSoft),
      barBg: l(barBg, other.barBg),
      segmentThumb: l(segmentThumb, other.segmentThumb),
      toast: l(toast, other.toast),
    );
  }
}

/// Status tones shared by [StatusPill], banners and quick actions.
enum AppTone { neutral, amber, red, green, blue }

/// Vivid, theme-independent colours for [AppIconSquare] backgrounds (the
/// white glyph sits on top). Matches the settings / tools screens of the demo.
abstract final class AppTints {
  static const blue = Color(0xFF2F5BEA);
  static const indigo = Color(0xFF6366F1);
  static const purple = Color(0xFF8A6CF0);
  static const orange = Color(0xFFF2A007);
  static const red = Color(0xFFEF4444);
  static const green = Color(0xFF1DB57D);
  static const teal = Color(0xFF14B8A6);
  static const sky = Color(0xFF0EA5E9);
  static const slate = Color(0xFF3C4A63);
  static const grey = Color(0xFF8E96A6);
}

/// Text feature list for money / days / counters (`font-variant-numeric:
/// tabular-nums`). Use as `TextStyle(fontFeatures: kTabularFigures)`.
const kTabularFigures = <FontFeature>[FontFeature.tabularFigures()];

/// Monospace style for addresses, fingerprints and commands.
const kMonoTextStyle = TextStyle(
  fontFamily: 'Menlo',
  fontFamilyFallback: ['Roboto Mono', 'RobotoMono', 'monospace'],
);

/// Convenience accessors for the design tokens.
extension AppPaletteContext on BuildContext {
  /// The [AppPalette] of the current theme. Falls back to the light/dark
  /// palette matching the ambient brightness when the theme has none (for
  /// example a bare `MaterialApp()` in a test).
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ??
      AppPalette.of(Theme.of(this).brightness);

  /// Footnote style: 12.5 px secondary text under groups.
  TextStyle get footnoteStyle =>
      TextStyle(fontSize: 12.5, height: 1.4, color: palette.text2);
}
