import 'package:flutter/material.dart';

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

/// Surface and content roles follow the selected platform/app brightness.
/// The export renderer intentionally keeps using the fixed light [AppColors].
ThemeData appTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final colors =
      ColorScheme.fromSeed(
        seedColor: AppColors.blue,
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFFACC5FF) : AppColors.blue,
        onPrimary: dark ? const Color(0xFF102C64) : Colors.white,
        primaryContainer: dark ? const Color(0xFF213D70) : AppColors.soft,
        onPrimaryContainer: dark ? const Color(0xFFD9E5FF) : AppColors.blue,
        surface: dark ? const Color(0xFF151D2C) : Colors.white,
        onSurface: dark ? const Color(0xFFE5ECF7) : AppColors.ink,
        onSurfaceVariant: dark ? const Color(0xFFBAC5D6) : AppColors.muted,
        outline: dark ? const Color(0xFF8997AD) : const Color(0xFF758298),
        outlineVariant: dark ? const Color(0xFF35435B) : AppColors.line,
        tertiary: dark ? const Color(0xFFFFD89B) : AppColors.amber,
        onTertiary: dark ? const Color(0xFF442B07) : Colors.white,
        tertiaryContainer: dark
            ? const Color(0xFF49330F)
            : AppColors.amberBackground,
        onTertiaryContainer: dark ? const Color(0xFFFFE1AC) : AppColors.amber,
        error: dark ? const Color(0xFFFFB3BA) : AppColors.red,
        onError: dark ? const Color(0xFF650C1D) : Colors.white,
        errorContainer: dark
            ? const Color(0xFF57262E)
            : const Color(0xFFFFF0F0),
        onErrorContainer: dark ? const Color(0xFFFFD9DD) : AppColors.red,
      );
  final canvas = dark ? const Color(0xFF0D1420) : AppColors.canvas;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colors,
    scaffoldBackgroundColor: canvas,
    fontFamilyFallback: const [
      'Noto Sans CJK SC',
      'PingFang SC',
      'Microsoft YaHei',
    ],
    textTheme: TextTheme(
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: colors.onSurface),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.5,
        color: colors.onSurfaceVariant,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: colors.onSurface,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: colors.onSurface,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.outline),
      ),
      hintStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: BorderSide(color: colors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

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
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        ?action,
      ],
    ),
  );
}

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
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: danger
          ? Theme.of(context).colorScheme.errorContainer
          : warning
          ? Theme.of(context).colorScheme.tertiaryContainer
          : Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        height: 1.4,
        color: danger
            ? Theme.of(context).colorScheme.onErrorContainer
            : warning
            ? Theme.of(context).colorScheme.onTertiaryContainer
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class InfoNote extends StatelessWidget {
  const InfoNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool dangerous = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: dangerous
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

void showFailure(
  BuildContext context,
  Object error, {
  String fallbackMessage = '操作未完成，请重试。已保存的资料仍保留。',
}) {
  // Never render driver errors: they can include SQL or private record values.
  final message = error is ArgumentError
      ? error.message.toString()
      : error.toString().contains('记录已发生变化')
      ? '记录已发生变化，请返回后重试'
      : fallbackMessage;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void showStage(BuildContext context, String title, String detail) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(title),
      content: Text(detail),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

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
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, size: 23, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    ),
  );
}
