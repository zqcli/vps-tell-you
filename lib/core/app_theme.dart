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

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.blue,
    primary: AppColors.blue,
    surface: Colors.white,
    onSurface: AppColors.ink,
  ),
  scaffoldBackgroundColor: AppColors.canvas,
  fontFamilyFallback: const [
    'Noto Sans CJK SC',
    'PingFang SC',
    'Microsoft YaHei',
  ],
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: AppColors.ink),
    bodySmall: TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.canvas,
    surfaceTintColor: Colors.transparent,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.all(14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
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
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: AppColors.line,
    thickness: 1,
    space: 1,
  ),
  snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
);

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
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.line),
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
          ? const Color(0xFFFFF0F0)
          : warning
          ? AppColors.amberBackground
          : AppColors.canvas,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        height: 1.4,
        color: danger
            ? AppColors.red
            : warning
            ? AppColors.amber
            : AppColors.muted,
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
                ? FilledButton.styleFrom(backgroundColor: AppColors.red)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

void showFailure(BuildContext context, Object error) {
  // Never render driver errors: they can include SQL or private record values.
  final message = error is ArgumentError
      ? error.message.toString()
      : error.toString().contains('记录已发生变化')
      ? '记录已发生变化，请返回后重试'
      : '操作未完成，已保存的记录仍保留。请检查输入后重试（分组名称不能重复）。';
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
