import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../core/ui/ui.dart';
import '../l10n/locale_preference.dart';
import 'terminal_font.dart';

/// A terminal colour scheme: the xterm palette plus the colours of the native
/// chrome around it (top bar, key bar, command drawer), so both read as one
/// surface. Purely visual; selecting one never touches the SSH session.
///
/// Palettes follow the upstream Tokyo Night, Catppuccin Mocha, Dracula and
/// GitHub Light terminal ports. `brightBlack` is lifted where the upstream
/// value is below 3:1 against the background because shells draw
/// autosuggestions and comments with it. `test/terminal_scheme_test.dart`
/// pins the contrast numbers.
class TerminalScheme {
  const TerminalScheme({
    required this.id,
    required this.name,
    required this.brightness,
    required this.theme,
    required this.chrome,
    required this.hairline,
    required this.key,
    required this.keyArmed,
    required this.accent,
    required this.onAccent,
    required this.muted,
    required this.link,
  });

  /// Stable identifier (also used in widget keys).
  final String id;

  /// Proper name of the scheme; not translated.
  final String name;
  final Brightness brightness;
  final TerminalTheme theme;

  /// Top bar, key bar and drawer background.
  final Color chrome, hairline;

  /// Key caps, chips and the popup menu; [keyArmed] is the armed Ctrl key.
  final Color key, keyArmed;

  /// Primary action fill and its label colour.
  final Color accent, onAccent;

  /// Secondary text/icons and tappable text on [chrome].
  final Color muted, link;

  bool get isDark => brightness == Brightness.dark;

  static const defaultScheme = tokyoNight;
  static const all = <TerminalScheme>[
    tokyoNight,
    catppuccinMocha,
    dracula,
    githubLight,
  ];

  /// The scheme of the nearest [TerminalSchemeScope], else the default.
  static TerminalScheme of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<TerminalSchemeScope>()
          ?.scheme ??
      defaultScheme;

  static TerminalScheme byId(String id) =>
      all.firstWhere((scheme) => scheme.id == id, orElse: () => defaultScheme);
}

/// Session-wide choice. `ledger_settings.dart` has no generic key/value
/// mechanism (`app_settings` is a fixed-column row), and persisting would need
/// a schema change, so the choice lives for the app session only.
final ValueNotifier<TerminalScheme> terminalSchemeChoice =
    ValueNotifier<TerminalScheme>(TerminalScheme.defaultScheme);

/// Smart highlighting of uncoloured output (see `terminal_highlighter.dart`).
/// Session-wide like [terminalSchemeChoice]; on by default.
final ValueNotifier<bool> terminalSmartHighlight = ValueNotifier<bool>(true);

/// Exposes the active scheme to the key bar and command drawer, which are
/// built in a separate route and therefore need to be re-wrapped there.
class TerminalSchemeScope extends InheritedWidget {
  const TerminalSchemeScope({
    super.key,
    required this.scheme,
    required super.child,
  });
  final TerminalScheme scheme;

  @override
  bool updateShouldNotify(TerminalSchemeScope old) => old.scheme != scheme;
}

const tokyoNight = TerminalScheme(
  id: 'tokyo-night',
  name: 'Tokyo Night',
  brightness: Brightness.dark,
  theme: TerminalTheme(
    cursor: Color(0xFFC0CAF5),
    selection: Color(0x667AA2F7),
    foreground: Color(0xFFC0CAF5),
    background: Color(0xFF1A1B26),
    black: Color(0xFF15161E),
    red: Color(0xFFF7768E),
    green: Color(0xFF9ECE6A),
    yellow: Color(0xFFE0AF68),
    blue: Color(0xFF7AA2F7),
    magenta: Color(0xFFBB9AF7),
    cyan: Color(0xFF7DCFFF),
    white: Color(0xFFA9B1D6),
    brightBlack: Color(0xFF636DA6),
    brightRed: Color(0xFFFF899D),
    brightGreen: Color(0xFF9FE044),
    brightYellow: Color(0xFFFABA4A),
    brightBlue: Color(0xFF8DB0FF),
    brightMagenta: Color(0xFFC7A9FF),
    brightCyan: Color(0xFFA4DAFF),
    brightWhite: Color(0xFFC0CAF5),
    searchHitBackground: Color(0xFFE0AF68),
    searchHitBackgroundCurrent: Color(0xFF9ECE6A),
    searchHitForeground: Color(0xFF16161E),
  ),
  chrome: Color(0xFF16161E),
  hairline: Color(0xFF292E42),
  key: Color(0xFF292E42),
  keyArmed: Color(0xFF34498A),
  accent: Color(0xFF7AA2F7),
  onAccent: Color(0xFF16161E),
  muted: Color(0xFF8089B3),
  link: Color(0xFF7AA2F7),
);

const catppuccinMocha = TerminalScheme(
  id: 'catppuccin-mocha',
  name: 'Catppuccin Mocha',
  brightness: Brightness.dark,
  theme: TerminalTheme(
    cursor: Color(0xFFF5E0DC),
    selection: Color(0x6689B4FA),
    foreground: Color(0xFFCDD6F4),
    background: Color(0xFF1E1E2E),
    black: Color(0xFF45475A),
    red: Color(0xFFF38BA8),
    green: Color(0xFFA6E3A1),
    yellow: Color(0xFFF9E2AF),
    blue: Color(0xFF89B4FA),
    magenta: Color(0xFFF5C2E7),
    cyan: Color(0xFF94E2D5),
    white: Color(0xFFBAC2DE),
    brightBlack: Color(0xFF6C7086),
    brightRed: Color(0xFFF38BA8),
    brightGreen: Color(0xFFA6E3A1),
    brightYellow: Color(0xFFF9E2AF),
    brightBlue: Color(0xFF89B4FA),
    brightMagenta: Color(0xFFF5C2E7),
    brightCyan: Color(0xFF94E2D5),
    brightWhite: Color(0xFFA6ADC8),
    searchHitBackground: Color(0xFFF9E2AF),
    searchHitBackgroundCurrent: Color(0xFFA6E3A1),
    searchHitForeground: Color(0xFF11111B),
  ),
  chrome: Color(0xFF181825),
  hairline: Color(0xFF313244),
  key: Color(0xFF313244),
  keyArmed: Color(0xFF45567F),
  accent: Color(0xFF89B4FA),
  onAccent: Color(0xFF11111B),
  muted: Color(0xFF9399B2),
  link: Color(0xFF89B4FA),
);

const dracula = TerminalScheme(
  id: 'dracula',
  name: 'Dracula',
  brightness: Brightness.dark,
  theme: TerminalTheme(
    cursor: Color(0xFFF8F8F2),
    selection: Color(0x66BD93F9),
    foreground: Color(0xFFF8F8F2),
    background: Color(0xFF282A36),
    black: Color(0xFF21222C),
    red: Color(0xFFFF5555),
    green: Color(0xFF50FA7B),
    yellow: Color(0xFFF1FA8C),
    blue: Color(0xFFBD93F9),
    magenta: Color(0xFFFF79C6),
    cyan: Color(0xFF8BE9FD),
    white: Color(0xFFF8F8F2),
    brightBlack: Color(0xFF6C78AB),
    brightRed: Color(0xFFFF6E6E),
    brightGreen: Color(0xFF69FF94),
    brightYellow: Color(0xFFFFFFA5),
    brightBlue: Color(0xFFD6ACFF),
    brightMagenta: Color(0xFFFF92DF),
    brightCyan: Color(0xFFA4FFFF),
    brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0xFFF1FA8C),
    searchHitBackgroundCurrent: Color(0xFF50FA7B),
    searchHitForeground: Color(0xFF21222C),
  ),
  chrome: Color(0xFF21222C),
  hairline: Color(0xFF343746),
  key: Color(0xFF343746),
  keyArmed: Color(0xFF5A4A8A),
  accent: Color(0xFFBD93F9),
  onAccent: Color(0xFF21222C),
  muted: Color(0xFFA0A8CD),
  link: Color(0xFF8BE9FD),
);

const githubLight = TerminalScheme(
  id: 'github-light',
  name: 'GitHub Light',
  brightness: Brightness.light,
  theme: TerminalTheme(
    cursor: Color(0xFF0969DA),
    selection: Color(0x500969DA),
    foreground: Color(0xFF24292F),
    background: Color(0xFFFFFFFF),
    black: Color(0xFF24292F),
    red: Color(0xFFCF222E),
    green: Color(0xFF116329),
    yellow: Color(0xFF4D2D00),
    blue: Color(0xFF0969DA),
    magenta: Color(0xFF8250DF),
    cyan: Color(0xFF1B7C83),
    white: Color(0xFF6E7781),
    brightBlack: Color(0xFF57606A),
    brightRed: Color(0xFFA40E26),
    brightGreen: Color(0xFF1A7F37),
    brightYellow: Color(0xFF633C01),
    brightBlue: Color(0xFF218BFF),
    brightMagenta: Color(0xFFA475F9),
    brightCyan: Color(0xFF3192AA),
    brightWhite: Color(0xFF8C959F),
    searchHitBackground: Color(0xFFFFDF5D),
    searchHitBackgroundCurrent: Color(0xFF4AC26B),
    searchHitForeground: Color(0xFF24292F),
  ),
  chrome: Color(0xFFF6F8FA),
  hairline: Color(0xFFD0D7DE),
  key: Color(0xFFE6EAEF),
  keyArmed: Color(0xFFB6D6FF),
  accent: Color(0xFF0969DA),
  onAccent: Color(0xFFFFFFFF),
  muted: Color(0xFF57606A),
  link: Color(0xFF0969DA),
);

/// Colour chips for the picker: background, "Aa" in the foreground colour and
/// the six normal ANSI hues.
class TerminalSchemePreview extends StatelessWidget {
  const TerminalSchemePreview(this.scheme, {super.key});
  final TerminalScheme scheme;

  @override
  Widget build(BuildContext context) {
    final t = scheme.theme;
    return ExcludeSemantics(
      child: Container(
        width: 64,
        height: 44,
        padding: const EdgeInsets.fromLTRB(7, 4, 7, 5),
        decoration: BoxDecoration(
          color: t.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Aa',
              style: TextStyle(
                fontFamily: terminalFontFamily,
                fontSize: 13,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: t.foreground,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final c in [
                  t.red,
                  t.green,
                  t.yellow,
                  t.blue,
                  t.magenta,
                  t.cyan,
                ])
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Picker sheet. Returns the chosen scheme (also written to
/// [terminalSchemeChoice] so the page repaints at once), or `null`.
Future<TerminalScheme?> showTerminalSchemePicker(BuildContext context) async {
  final picked = await showAppSheet<TerminalScheme>(
    context,
    title: context.l10n.r3TermColorScheme,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      final p = sheetContext.palette;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSection(
            topSpacing: 4,
            footer: l10n.r3TermSchemeFootnote,
            children: [
              for (final scheme in TerminalScheme.all)
                AppRow(
                  key: ValueKey('terminal-scheme-${scheme.id}'),
                  leading: TerminalSchemePreview(scheme),
                  title: scheme.name,
                  subtitle: scheme.isDark
                      ? l10n.r3TermSchemeDark
                      : l10n.r3TermSchemeLight,
                  trailing: scheme == terminalSchemeChoice.value
                      ? Icon(Icons.check_rounded, size: 22, color: p.primary)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, scheme),
                ),
            ],
          ),
          ValueListenableBuilder<bool>(
            valueListenable: terminalSmartHighlight,
            builder: (context, on, _) => AppSection(
              footer: l10n.r4HlSmartNote,
              children: [
                AppSwitchRow(
                  key: const ValueKey('terminal-smart-highlight'),
                  title: l10n.r4HlSmart,
                  value: on,
                  onChanged: (value) => terminalSmartHighlight.value = value,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
  if (picked != null) {
    terminalSchemeChoice.value = picked;
  }
  return picked;
}
