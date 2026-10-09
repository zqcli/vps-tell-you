import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import 'ui/ui.dart';

export 'app_palette.dart';

/// Fixed light colours. The PNG export renderer (finance share) paints with
/// these regardless of the app theme, so do not change their values; UI code
/// should use `context.palette` instead.
abstract final class AppColors {
  static const blue = Color(0xFF2859DC);
  static const ink = Color(0xFF18263D);
  static const muted = Color(0xFF657084);
  static const line = Color(0xFFE4E8F0);
  static const canvas = Color(0xFFF5F7FB);
  static const soft = Color(0xFFEDF2FF);
  static const amber = Color(0xFF985C09);
  static const amberBackground = Color(0xFFFFF4DE);
  static const red = Color(0xFFB9363F);
}

/// Bouncing (iOS-style) scrolling on every platform. Installed on the
/// `MaterialApp`; [AppScaffold] also sets the same physics explicitly.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}

/// Builds the app theme (iOS look on every platform).
///
/// Colours come from [AppPalette] (available through `context.palette`);
/// the Material [ColorScheme] is derived from it so unmigrated widgets stay
/// consistent. The export renderer keeps using the fixed light [AppColors].
ThemeData appTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final p = AppPalette.of(brightness);
  final colors =
      ColorScheme.fromSeed(
        seedColor: AppColors.blue,
        brightness: brightness,
      ).copyWith(
        primary: p.primary,
        onPrimary: p.onPrimary,
        primaryContainer: p.primarySoft,
        onPrimaryContainer: p.onPrimarySoft,
        surface: p.surface,
        onSurface: p.text,
        onSurfaceVariant: p.text2,
        outline: dark ? const Color(0xFF8997AD) : const Color(0xFF7C8496),
        outlineVariant: dark
            ? const Color(0xFF262A33)
            : const Color(0xFFE3E5EB),
        surfaceContainerLowest: p.surface,
        surfaceContainerLow: p.surface2,
        surfaceContainer: dark
            ? const Color(0xFF1E222B)
            : const Color(0xFFEEF0F4),
        surfaceContainerHigh: dark
            ? const Color(0xFF262B35)
            : const Color(0xFFE8EAF0),
        surfaceContainerHighest: dark
            ? const Color(0xFF2D323D)
            : const Color(0xFFE2E5EC),
        tertiary: p.amber,
        onTertiary: dark ? const Color(0xFF442B07) : Colors.white,
        tertiaryContainer: p.amberSoft,
        onTertiaryContainer: p.amber,
        error: p.red,
        onError: dark ? const Color(0xFF4A0D12) : Colors.white,
        errorContainer: p.redSoft,
        onErrorContainer: p.red,
      );
  final canvas = p.bg;
  const noBorder = InputBorder.none;
  final switchOff = dark ? const Color(0xFF39393D) : const Color(0xFFE5E5EA);
  const fallback = ['Noto Sans CJK SC', 'PingFang SC', 'Microsoft YaHei'];
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colors,
    scaffoldBackgroundColor: canvas,
    canvasColor: canvas,
    extensions: [p],
    splashFactory: NoSplash.splashFactory,
    highlightColor: p.fill2,
    fontFamilyFallback: fallback,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const CupertinoPageTransitionsBuilder(),
      },
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: p.text),
      bodySmall: TextStyle(fontSize: 12, height: 1.5, color: p.text2),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: p.text,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: p.text,
      ),
    ),
    // Inline, borderless fields for grouped forms. Pages put them in an
    // [AppFormRow]; there is no outline and no fill.
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      border: noBorder,
      enabledBorder: noBorder,
      focusedBorder: noBorder,
      disabledBorder: noBorder,
      errorBorder: noBorder,
      focusedErrorBorder: noBorder,
      hintStyle: TextStyle(color: p.text3, fontSize: 16),
      labelStyle: TextStyle(color: p.text2, fontSize: 16),
      errorStyle: TextStyle(color: p.red, fontSize: 12.5, height: 1.3),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.primary,
      selectionColor: p.primary.withValues(alpha: .25),
      selectionHandleColor: p.primary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    // Outlined buttons render as soft tonal buttons: the design has no
    // outlined controls.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        foregroundColor: p.onPrimarySoft,
        backgroundColor: p.primarySoft,
        side: BorderSide.none,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppPalette.switchGreen
            : switchOff,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      // A (blank) thumb icon keeps the unselected thumb full size like iOS.
      thumbIcon: const WidgetStatePropertyAll(Icon(null)),
    ),
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant,
      thickness: .5,
      space: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: p.text,
      ),
      contentTextStyle: TextStyle(fontSize: 13.5, height: 1.45, color: p.text),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: canvas,
      modalBackgroundColor: canvas,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.toast,
      contentTextStyle: const TextStyle(
        fontSize: 14,
        height: 1.35,
        color: Colors.white,
      ),
      actionTextColor: const Color(0xFF8FB0FF),
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
  );
  // Cupertino widgets (navigation bar, action sheet, search field) read their
  // text styles from here; reuse the Material font so both families agree.
  final family = base.textTheme.bodyMedium?.fontFamily;
  TextStyle cupertinoText(double size, Color color, [FontWeight? weight]) =>
      TextStyle(
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: size,
        fontWeight: weight,
        color: color,
      );
  return base.copyWith(
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: p.primary,
      primaryContrastingColor: p.onPrimary,
      scaffoldBackgroundColor: canvas,
      barBackgroundColor: p.barBg,
      textTheme: CupertinoTextThemeData(
        primaryColor: p.primary,
        textStyle: cupertinoText(16, p.text),
        navTitleTextStyle: cupertinoText(17, p.text, FontWeight.w600),
        navLargeTitleTextStyle: cupertinoText(
          32,
          p.text,
          FontWeight.w700,
        ).copyWith(letterSpacing: .2),
        navActionTextStyle: cupertinoText(17, p.primary),
      ),
    ),
  );
}

/// Legacy card. Prefer [AppSection] (grouped rows) or [AppCard].
///
/// Restyled to the new design: surface fill, radius 14, no border.
class LedgerCard extends StatelessWidget {
  const LedgerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

/// Legacy section heading. Prefer `AppSection(header: …)`.
///
/// Renders as the small grey group header of the demo; [action] stays on the
/// right.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 7),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 13, color: context.palette.text2),
        ),
        ?action,
      ],
    ),
  );
}

/// Legacy badge. Prefer [StatusPill]. Renders as a pill.
class LedgerBadge extends StatelessWidget {
  const LedgerBadge(
    this.text, {
    super.key,
    this.warning = false,
    this.danger = false,
  });
  final String text;
  final bool warning, danger;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: danger
          ? Theme.of(context).colorScheme.errorContainer
          : warning
          ? Theme.of(context).colorScheme.tertiaryContainer
          : Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        height: 1.5,
        fontWeight: FontWeight.w600,
        color: danger
            ? Theme.of(context).colorScheme.onErrorContainer
            : warning
            ? Theme.of(context).colorScheme.onTertiaryContainer
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// Legacy explanatory note. Prefer `AppSection(footer: …)`.
///
/// Renders in footnote style (12.5 px, secondary colour).
class InfoNote extends StatelessWidget {
  const InfoNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Text(text, style: context.footnoteStyle),
  );
}

/// iOS-alert looking buttons for the Material [AlertDialog] used by the
/// legacy helpers: a hairline above a row of flat buttons.
List<Widget> _alertActions(BuildContext context, List<Widget> buttons) {
  final p = context.palette;
  return [
    SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.separator, width: .5)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0)
                  VerticalDivider(color: p.separator, width: .5, thickness: .5),
                Expanded(child: buttons[i]),
              ],
            ],
          ),
        ),
      ),
    ),
  ];
}

final _alertButtonShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.zero,
);

/// Legacy confirmation dialog (Material [AlertDialog] with an iOS-like look).
/// Prefer [showAppConfirm]. Returns `true` only when the action is confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required Object title,
  required Object message,
  required Object action,
  bool dangerous = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        actionsPadding: EdgeInsets.zero,
        buttonPadding: EdgeInsets.zero,
        title: Text(
          localizedText(title, context.l10n),
          textAlign: TextAlign.center,
        ),
        content: Text(
          localizedText(message, context.l10n),
          textAlign: TextAlign.center,
        ),
        actions: _alertActions(context, [
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 46),
              shape: _alertButtonShape,
              textStyle: const TextStyle(fontSize: 17),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 46),
              backgroundColor: Colors.transparent,
              foregroundColor: dangerous
                  ? context.palette.red
                  : context.palette.primary,
              shape: _alertButtonShape,
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              localizedText(action, context.l10n),
              textAlign: TextAlign.center,
            ),
          ),
        ]),
      ),
    ) ??
    false;

void showFailure(
  BuildContext context,
  Object error, {
  Object? fallbackMessage,
}) {
  // Never render driver errors: they can include SQL or private record values.
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Builder(
        builder: (context) {
          final message = error is LocalizedMessage
              ? error.messageFor(context.l10n)
              : error is ArgumentError
              ? localizedText(error.message ?? '', context.l10n)
              : fallbackMessage == null
              ? context.l10n.operationFailed
              : localizedText(fallbackMessage, context.l10n);
          return Text(message);
        },
      ),
    ),
  );
}

/// Legacy informational alert with a single "Got it" button.
void showStage(BuildContext context, Object title, Object detail) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      actionsPadding: EdgeInsets.zero,
      buttonPadding: EdgeInsets.zero,
      title: Text(
        localizedText(title, context.l10n),
        textAlign: TextAlign.center,
      ),
      content: Text(
        localizedText(detail, context.l10n),
        textAlign: TextAlign.center,
      ),
      actions: _alertActions(context, [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 46),
            shape: _alertButtonShape,
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.gotIt),
        ),
      ]),
    ),
  );
}

/// Legacy navigation row. Prefer [AppRow].
///
/// Renders as an iOS row: coloured icon square, title, subtitle and chevron.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => AppRow(
    icon: icon,
    iconColor: AppTints.blue,
    title: title,
    subtitle: subtitle,
    chevron: true,
    onTap: onTap,
  );
}
