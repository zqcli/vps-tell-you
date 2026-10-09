import 'package:flutter/cupertino.dart'
    show
        CupertinoActionSheet,
        CupertinoActionSheetAction,
        CupertinoAlertDialog,
        CupertinoDialogAction,
        showCupertinoDialog,
        showCupertinoModalPopup;
import 'package:flutter/material.dart';

import '../../l10n/locale_preference.dart';
import '../../l10n/localized_message.dart';
import '../app_palette.dart';
import 'app_list.dart';

/// Modal bottom sheet in the app style: grabber, centred title, ✕ button,
/// scrollable body, safe-area aware, themed background.
///
/// [builder] returns the body – normally one or more [AppSection]s (they
/// bring their own 16 px margin). Close it from inside with
/// `Navigator.pop(context, value)`; the value completes the future. Keyboard
/// insets are handled.
///
/// ```dart
/// final unit = await showAppSheet<String>(
///   context,
///   title: l10n.filter,
///   builder: (context) => AppSection(children: [
///     AppRow(title: 'GiB', onTap: () => Navigator.pop(context, 'GiB')),
///   ]),
/// );
/// ```
///
/// Set [scrollable] to `false` when the body manages its own scrolling
/// (e.g. contains a `ListView` with a bounded height).
Future<T?> showAppSheet<T>(
  BuildContext context, {
  String? title,
  required WidgetBuilder builder,
  bool showClose = true,
  bool scrollable = true,
  bool isDismissible = true,
  double maxHeightFactor = .88,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: isDismissible,
  enableDrag: isDismissible,
  backgroundColor: context.palette.bg,
  builder: (sheetContext) => _AppSheetFrame(
    title: title,
    showClose: showClose,
    scrollable: scrollable,
    maxHeightFactor: maxHeightFactor,
    child: Builder(builder: builder),
  ),
);

class _AppSheetFrame extends StatelessWidget {
  const _AppSheetFrame({
    required this.title,
    required this.showClose,
    required this.scrollable,
    required this.maxHeightFactor,
    required this.child,
  });

  final String? title;
  final bool showClose, scrollable;
  final double maxHeightFactor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final hasHeader = title != null || showClose;
    final closeLabel = MaterialLocalizations.of(context).closeButtonTooltip;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: (media.size.height - media.padding.top) * maxHeightFactor,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.only(top: 6, bottom: 6),
                decoration: BoxDecoration(
                  color: p.text3.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            if (hasHeader)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 56),
                      child: title == null
                          ? const SizedBox(height: 30)
                          : Semantics(
                              header: true,
                              child: Text(
                                title!,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 17,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                  color: p.text,
                                ),
                              ),
                            ),
                    ),
                    if (showClose)
                      PositionedDirectional(
                        end: 14,
                        top: 0,
                        child: Tooltip(
                          message: closeLabel,
                          child: Semantics(
                            button: true,
                            label: closeLabel,
                            excludeSemantics: true,
                            onTap: () => Navigator.maybePop(context),
                            child: InkResponse(
                              key: const ValueKey('app-sheet-close'),
                              onTap: () => Navigator.maybePop(context),
                              radius: 20,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: p.fill,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: p.text2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Flexible(
              child: scrollable
                  ? SingleChildScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: EdgeInsets.only(
                        bottom: media.padding.bottom + 16,
                      ),
                      child: child,
                    )
                  : child,
            ),
          ],
        ),
      ),
    );
  }
}

/// One entry of [showAppActionMenu].
class AppMenuAction<T> {
  const AppMenuAction({
    required this.label,
    this.value,
    this.onPressed,
    this.destructive = false,
    this.isDefault = false,
  });

  /// Button text.
  final String label;

  /// Returned by [showAppActionMenu] when chosen.
  final T? value;

  /// Called after the menu has closed, when this entry is chosen.
  final VoidCallback? onPressed;

  /// Red text for delete / archive style actions.
  final bool destructive;

  /// Bold text for the preferred action.
  final bool isDefault;
}

/// iOS action sheet (CupertinoActionSheet) with optional title / message,
/// a list of actions and a separate Cancel button.
///
/// Returns the chosen action's [AppMenuAction.value] (`null` when cancelled);
/// each action may also carry an [AppMenuAction.onPressed] that runs after the
/// sheet closed.
///
/// ```dart
/// await showAppActionMenu<void>(context, title: server.name, actions: [
///   AppMenuAction(label: l10n.copyAddress, onPressed: copy),
///   AppMenuAction(label: l10n.archive, destructive: true, onPressed: archive),
/// ]);
/// ```
Future<T?> showAppActionMenu<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<AppMenuAction<T>> actions,
  String? cancelLabel,
}) async {
  AppMenuAction<T>? picked;
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      title: title == null ? null : Text(title),
      message: message == null ? null : Text(message),
      actions: [
        for (final action in actions)
          CupertinoActionSheetAction(
            isDestructiveAction: action.destructive,
            isDefaultAction: action.isDefault,
            onPressed: () {
              picked = action;
              Navigator.pop(sheetContext);
            },
            child: Text(action.label),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheetContext),
        child: Text(cancelLabel ?? context.l10n.cancel),
      ),
    ),
  );
  picked?.onPressed?.call();
  return picked?.value;
}

/// Confirmation prompt returning `true` only when the user confirms.
///
/// Same signature and semantics as the legacy `confirmAction`. A
/// [dangerous] confirmation is shown as an action sheet with a red button,
/// everything else as a centred iOS alert. The full [message] is always shown
/// (it scrolls when long). [title], [message] and [action] accept a `String`
/// or a localisation callback like `confirmAction` does.
///
/// ```dart
/// final ok = await showAppConfirm(
///   context,
///   title: l10n.archiveServerTitle,
///   message: l10n.archiveServerBody,
///   action: l10n.archive,
///   dangerous: true,
/// );
/// ```
Future<bool> showAppConfirm(
  BuildContext context, {
  required Object title,
  required Object message,
  required Object action,
  bool dangerous = false,
}) async {
  final l10n = context.l10n;
  final titleText = localizedText(title, l10n);
  final messageText = localizedText(message, l10n);
  final actionText = localizedText(action, l10n);
  if (dangerous) {
    var confirmed = false;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(titleText),
        message: Text(messageText),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              confirmed = true;
              Navigator.pop(sheetContext);
            },
            child: Text(actionText),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(l10n.cancel),
        ),
      ),
    );
    return confirmed;
  }
  return await showCupertinoDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(titleText),
          content: Text(messageText),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(actionText),
            ),
          ],
        ),
      ) ??
      false;
}

/// One choice of [showAppPicker].
class AppPickerOption<T> {
  const AppPickerOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor = AppTints.blue,
    this.key,
  });

  final T value;
  final String title;
  final String? subtitle;

  /// Optional coloured icon square before the title.
  final IconData? icon;
  final Color iconColor;

  /// Key of the row (for tests).
  final Key? key;
}

/// Single-choice list in a bottom sheet with a check mark on the current
/// value and an optional footnote. Returns the chosen value, or `null` when
/// dismissed (use a sentinel value such as `''` for a "None" option).
///
/// ```dart
/// final cycle = await showAppPicker<int>(
///   context,
///   title: l10n.billingCycle,
///   selected: current,
///   options: [
///     AppPickerOption(value: 1, title: l10n.monthly),
///     AppPickerOption(value: 12, title: l10n.yearly),
///   ],
///   footnote: l10n.cycleHelp,
/// );
/// ```
Future<T?> showAppPicker<T>(
  BuildContext context, {
  String? title,
  required List<AppPickerOption<T>> options,
  T? selected,
  String? footnote,
}) => showAppSheet<T>(
  context,
  title: title,
  builder: (sheetContext) {
    final p = sheetContext.palette;
    return AppSection(
      topSpacing: 4,
      footer: footnote,
      children: [
        for (final option in options)
          AppRow(
            key: option.key,
            icon: option.icon,
            iconColor: option.iconColor,
            title: option.title,
            subtitle: option.subtitle,
            trailing: option.value == selected
                ? Icon(Icons.check_rounded, size: 22, color: p.primary)
                : null,
            onTap: () => Navigator.pop(sheetContext, option.value),
          ),
      ],
    );
  },
);

/// Floating dark toast (SnackBar) with an optional action such as "Undo".
///
/// Replaces any toast currently on screen. Messages with an action stay
/// longer (4.5 s) than plain ones (2.2 s).
///
/// ```dart
/// showAppToast(context, l10n.archived,
///     actionLabel: l10n.undo, onAction: () => controller.restore(id));
/// ```
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showAppToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return null;
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration:
          duration ??
          (actionLabel == null
              ? const Duration(milliseconds: 2200)
              : const Duration(milliseconds: 4500)),
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ),
  );
}
