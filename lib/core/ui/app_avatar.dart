import 'package:flutter/material.dart';

import '../app_palette.dart';
import 'app_list.dart';

/// Rounded-square provider avatar with a stable colour derived from the
/// name, initials (or an explicit [mark]) and an optional favourite star. With
/// a [logo] it shows the picture instead, on a white tile with a hairline
/// border in both themes (logos are drawn for light backgrounds).
///
/// ```dart
/// ProviderAvatar(name: 'DigitalOcean', starred: server.favorite)
/// ProviderAvatar(name: 'BandwagonHost', mark: 'BWG', size: 60)
/// ProviderAvatar(name: null) // grey "?" for an unspecified provider
/// ProviderAvatar(name: 'Aliyun', logo: FileImage(file)) // directory logo
/// ```
///
/// Prefer `ProviderLogo` (lib/providers) in screens: it finds the cached
/// directory logo of a provider, so every screen shows the same picture.
/// The semantics label is the provider [name]. When used as `AppRow.leading`
/// the separator inset follows [size].
class ProviderAvatar extends StatelessWidget implements AppLeading {
  const ProviderAvatar({
    super.key,
    required this.name,
    this.mark,
    this.size = 42,
    this.starred = false,
    this.color,
    this.logo,
  });

  /// Provider name; `null` / empty gives a grey "?".
  final String? name;

  /// Square picture (the app uses 256 px PNGs with ~12 % margin). It is decoded
  /// at the pixel size it is shown at; if it cannot be decoded the initials
  /// are shown instead.
  final ImageProvider? logo;

  /// Explicit 1–3 character mark; derived from [name] when null.
  final String? mark;

  /// Edge length: 42 in lists, 60 in the detail header.
  final double size;

  /// Draws the amber favourite badge at the bottom-right corner.
  final bool starred;

  /// Overrides the hashed colour.
  final Color? color;

  static const _colors = <Color>[
    Color(0xFFF07A2A),
    Color(0xFF1F7AE0),
    Color(0xFF22A06B),
    Color(0xFF6D5AE6),
    Color(0xFFD6334A),
    Color(0xFF0E9F9A),
    Color(0xFFC2410C),
    Color(0xFF8B5CF6),
    Color(0xFF0F766E),
    Color(0xFFDB2777),
  ];

  /// Stable colour for [name] (FNV-1a hash, independent of the Dart VM).
  static Color colorFor(String? name) {
    final text = name?.trim() ?? '';
    if (text.isEmpty) return AppTints.grey;
    var hash = 0x811c9dc5;
    for (final unit in text.toLowerCase().codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return _colors[hash % _colors.length];
  }

  /// Initials for [name]: CJK → first character; "RackNerd" → "RN";
  /// "Hetzner" → "He"; empty → "?".
  static String initialsFor(String? name) {
    final text = name?.trim() ?? '';
    if (text.isEmpty) return '?';
    final first = text.runes.first;
    if (first >= 0x2E80) return String.fromCharCode(first);
    final words = text
        .split(RegExp(r'[\s_\-.]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length >= 2) {
      return (words[0][0] + words[1][0]).toUpperCase();
    }
    final capitals = RegExp('[A-Z]').allMatches(words.first).toList();
    if (capitals.length >= 2) {
      return capitals.take(2).map((m) => m.group(0)!).join();
    }
    final word = words.first;
    if (word.length <= 3 && word == word.toUpperCase()) return word;
    return word.length == 1
        ? word.toUpperCase()
        : word[0].toUpperCase() + word[1].toLowerCase();
  }

  @override
  double get leadingExtent => size;

  Widget _initials(String label) => DecoratedBox(
    decoration: BoxDecoration(
      color: color ?? colorFor(name),
      borderRadius: BorderRadius.circular(size * .26),
    ),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * .31,
              fontWeight: FontWeight.w700,
              letterSpacing: .2,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _logoTile(BuildContext context, String label) {
    final p = context.palette;
    final radius = BorderRadius.circular(size * .26);
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: p.separator, width: .5),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image(
          image: ResizeImage.resizeIfNeeded(pixels, null, logo!),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => _initials(label),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final label = (mark != null && mark!.isNotEmpty)
        ? mark!
        : initialsFor(name);
    final badge = size * 17 / 42;
    final trimmed = name?.trim() ?? '';
    return Semantics(
      label: trimmed.isEmpty ? null : trimmed,
      image: true,
      excludeSemantics: trimmed.isNotEmpty,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: logo == null
                  ? _initials(label)
                  : _logoTile(context, label),
            ),
            if (starred)
              Positioned(
                right: -size * 4 / 42,
                bottom: -size * 4 / 42,
                child: Container(
                  width: badge,
                  height: badge,
                  decoration: BoxDecoration(
                    color: p.surface,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.star_rounded,
                    size: badge * .75,
                    color: p.amberSolid,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
