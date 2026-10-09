import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart'
    show
        CupertinoButton,
        CupertinoPageScaffoldBackgroundColor,
        CupertinoSliverNavigationBar,
        CupertinoSliverRefreshControl,
        showCupertinoSheet;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../../l10n/locale_preference.dart';
import '../app_palette.dart';

/// Remembers the title of each page so that a pushed page can label its back
/// button with the previous page's title ("‹ Servers"), like iOS.
///
/// Add [AppRouteTitles.createObserver] to `MaterialApp.navigatorObservers` (done in
/// `LedgerApp`). Without the observer (for example a bare test app) the back
/// button simply reads "Back". [AppScaffold] registers its title
/// automatically; nothing to do in pages.
abstract final class AppRouteTitles {
  static final _titles = Expando<String>('AppRouteTitles.title');
  static final _previous = Expando<Route<dynamic>>('AppRouteTitles.previous');

  /// Creates an observer recording the route stack. Use one per `Navigator`
  /// (`MaterialApp.navigatorObservers`).
  static NavigatorObserver createObserver() => _TitleObserver();

  /// Title registered for the page that is below [route], if any.
  static String? previousTitle(Route<dynamic> route) {
    final previous = _previous[route];
    return previous == null ? null : _titles[previous];
  }

  /// Registers [title] as the title of the route that owns [context].
  static void register(BuildContext context, String title) {
    final route = ModalRoute.of(context);
    if (route != null) _titles[route] = title;
  }
}

class _TitleObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppRouteTitles._previous[route] = previousRoute;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null && oldRoute != null) {
      AppRouteTitles._previous[newRoute] = AppRouteTitles._previous[oldRoute];
    }
  }
}

/// Button for the navigation bar: either a 24 px primary-coloured icon or a
/// text label.
///
/// ```dart
/// AppScaffold(title: l10n.servers, actions: [
///   AppNavButton.icon(Icons.add, tooltip: l10n.add, onPressed: addServer),
///   AppNavButton.text(l10n.edit, onPressed: edit),
/// ], …)
/// ```
class AppNavButton extends StatelessWidget {
  /// Icon button (40 × 40 hit area).
  const AppNavButton.icon(
    IconData this.icon, {
    super.key,
    required this.onPressed,
    this.tooltip,
    this.color,
  }) : label = null,
       bold = false;

  /// Text button; [bold] gives the confirming action look ("Save").
  const AppNavButton.text(
    String this.label, {
    super.key,
    required this.onPressed,
    this.bold = false,
    this.color,
  }) : icon = null,
       tooltip = null;

  final IconData? icon;
  final String? label;

  /// `null` renders the disabled (grey) look.
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool bold;

  /// Overrides the primary colour (e.g. red for a destructive action).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = onPressed == null ? p.text3 : (color ?? p.primary);
    final Widget child = icon != null
        ? Icon(icon, size: 24, color: fg)
        : Text(
            label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              color: fg,
            ),
          );
    final button = CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(40, 40),
      onPressed: onPressed,
      child: child,
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tooltip = MaterialLocalizations.of(context).backButtonTooltip;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: label,
        button: true,
        excludeSemantics: true,
        onTap: () => Navigator.maybePop(context),
        child: CupertinoButton(
          key: const ValueKey('app-nav-back'),
          padding: const EdgeInsetsDirectional.only(end: 8),
          minimumSize: const Size(44, 44),
          onPressed: () => Navigator.maybePop(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: p.primary,
                textDirection: Directionality.of(context),
              ),
              const SizedBox(width: 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, color: p.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page skeleton of the redesigned UI: a [CustomScrollView] under an iOS
/// navigation bar.
///
/// * **Large title** (default): big left-aligned title that collapses into a
///   centred small title with a translucent blurred bar when scrolled.
/// * `largeTitle: false`: always-small centred title (detail pages, sheets).
/// * Pushed pages automatically get a back button labelled with the previous
///   page's title (see [AppRouteTitles]); override with [backLabel].
/// * [AppScaffold.modal] is the page-sheet variant for forms: "Cancel" on
///   the left, a bold [actionLabel] on the right (disabled while [onAction] is
///   null). Open it with [showAppModal].
/// * Pass [onRefresh] for iOS pull-to-refresh.
///
/// It is a Material [Scaffold] underneath, so SnackBars, `SnackBar`s and
/// dialogs behave as before, and widgets such as `RefreshFailureNotice` can be
/// used as ordinary children.
///
/// Provide either [children] (simple pages) or [slivers] (long lists:
/// `SliverList.builder`). Children are laid out edge to edge – the grouped
/// building blocks ([AppSection], [AppCard], …) already include the 16 px
/// page margin. Bottom padding for the tab bar / home indicator is added
/// automatically.
///
/// ```dart
/// AppScaffold(
///   title: l10n.settings,
///   subtitle: 'v0.1.0',
///   onRefresh: controller.refresh,
///   actions: [AppNavButton.icon(Icons.add, onPressed: add)],
///   children: [
///     AppSection(header: l10n.ledger, children: [AppRow(title: 'Groups', chevron: true, onTap: open)]),
///   ],
/// )
/// ```
class AppScaffold extends StatefulWidget {
  const AppScaffold({
    super.key,
    required this.title,
    this.largeTitle = true,
    this.subtitle,
    this.backLabel,
    this.leading,
    this.actions = const [],
    this.children = const [],
    this.slivers,
    this.onRefresh,
    this.controller,
    this.bottomBar,
    this.revealTitleOnScroll = false,
    this.resizeToAvoidBottomInset = true,
  }) : modal = false,
       cancelLabel = null,
       onCancel = null,
       actionLabel = null,
       onAction = null,
       actionBusy = false;

  /// Page-sheet variant for add / edit forms.
  const AppScaffold.modal({
    super.key,
    required this.title,
    this.cancelLabel,
    this.onCancel,
    this.actionLabel,
    this.onAction,
    this.actionBusy = false,
    this.children = const [],
    this.slivers,
    this.controller,
    this.bottomBar,
    this.resizeToAvoidBottomInset = true,
  }) : modal = true,
       largeTitle = false,
       subtitle = null,
       backLabel = null,
       leading = null,
       actions = const [],
       onRefresh = null,
       revealTitleOnScroll = false;

  /// Title shown large and, collapsed, in the centre of the bar.
  final String title;

  /// `false` for a permanently small centred title.
  final bool largeTitle;

  /// Grey caption below the large title; scrolls away with the content.
  final String? subtitle;

  /// Text of the back button. Defaults to the previous page's title.
  final String? backLabel;

  /// Replaces the automatic back button.
  final Widget? leading;

  /// Trailing bar buttons, usually [AppNavButton]s.
  final List<Widget> actions;

  /// Body widgets (ignored when [slivers] is given).
  final List<Widget> children;

  /// Body slivers for long lists.
  final List<Widget>? slivers;

  /// Enables pull-to-refresh; the returned future ends the spinner.
  final Future<void> Function()? onRefresh;

  /// Scroll controller; defaults to the [PrimaryScrollController].
  final ScrollController? controller;

  /// Fixed widget under the content, e.g. a primary [AppButton]. It is
  /// wrapped in a blurred bar with a hairline and the bottom safe area.
  final Widget? bottomBar;

  /// With `largeTitle: false`: keep the title transparent until content
  /// scrolls under the bar (hero headers on the detail page).
  final bool revealTitleOnScroll;

  final bool resizeToAvoidBottomInset;

  /// Whether this is the page-sheet form variant.
  final bool modal;

  /// Modal: left button text (default "Cancel").
  final String? cancelLabel;

  /// Modal: left button action (default: `Navigator.maybePop`). Use it to ask
  /// for discard confirmation.
  final VoidCallback? onCancel;

  /// Modal: right bold button text (default "Save").
  final String? actionLabel;

  /// Modal: right button action; `null` disables it.
  final VoidCallback? onAction;

  /// Modal: shows a spinner instead of the action label and ignores taps.
  final bool actionBusy;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerTitle();
  }

  @override
  void didUpdateWidget(AppScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) _registerTitle();
  }

  void _registerTitle() {
    // Hidden tabs keep their state but must not claim the route's title.
    if (TickerMode.valuesOf(context).enabled) {
      AppRouteTitles.register(context, widget.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final canPop = Navigator.of(context).canPop();
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    Widget? leading = widget.leading;
    if (widget.modal) {
      leading = AppNavButton.text(
        widget.cancelLabel ?? l10n.cancel,
        onPressed: widget.onCancel ?? () => Navigator.maybePop(context),
      );
    } else if (leading == null && canPop) {
      final route = ModalRoute.of(context);
      leading = _BackButton(
        label:
            widget.backLabel ??
            (route == null ? null : AppRouteTitles.previousTitle(route)) ??
            MaterialLocalizations.of(context).backButtonTooltip,
      );
    }

    final actions = widget.modal
        ? <Widget>[
            widget.actionBusy
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : AppNavButton.text(
                    widget.actionLabel ?? l10n.save,
                    bold: true,
                    onPressed: widget.onAction,
                  ),
          ]
        : widget.actions;
    final trailing = actions.isEmpty
        ? null
        : Row(mainAxisSize: MainAxisSize.min, children: actions);

    final bar = widget.largeTitle
        ? CupertinoSliverNavigationBar(
            largeTitle: Text(widget.title),
            middle: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            alwaysShowMiddle: false,
            leading: leading,
            trailing: trailing,
            automaticallyImplyLeading: false,
            automaticallyImplyTitle: false,
            transitionBetweenRoutes: false,
            backgroundColor: p.barBg,
            padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
            border: Border(bottom: BorderSide(color: p.separator, width: .5)),
          )
        : SliverPersistentHeader(
            pinned: true,
            delegate: _SmallBarDelegate(
              topInset: MediaQuery.paddingOf(context).top,
              title: widget.title,
              leading: leading,
              trailing: trailing,
              palette: p,
              revealTitleOnScroll: widget.revealTitleOnScroll,
              modal: widget.modal,
            ),
          );

    final scroll = CustomScrollView(
      controller: widget.controller,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        bar,
        if (widget.onRefresh != null)
          CupertinoSliverRefreshControl(onRefresh: widget.onRefresh),
        if (widget.subtitle != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                widget.subtitle!,
                style: TextStyle(fontSize: 13, height: 1.4, color: p.text2),
              ),
            ),
          ),
        if (widget.slivers != null)
          ...widget.slivers!
        else
          SliverList(delegate: SliverChildListDelegate(widget.children)),
        SliverToBoxAdapter(child: SizedBox(height: bottomInset + 28)),
      ],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (p.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: p.bg,
          ),
      child: CupertinoPageScaffoldBackgroundColor(
        color: p.bg,
        child: Scaffold(
          backgroundColor: p.bg,
          resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
          body: scroll,
          bottomNavigationBar: widget.bottomBar == null
              ? null
              : _BottomBar(child: widget.bottomBar!),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.barBg,
            border: Border(top: BorderSide(color: p.separator, width: .5)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pinned small centred navigation bar. Transparent over the page background
/// until content scrolls under it, then translucent + blurred with a hairline.
class _SmallBarDelegate extends SliverPersistentHeaderDelegate {
  _SmallBarDelegate({
    required this.topInset,
    required this.title,
    required this.leading,
    required this.trailing,
    required this.palette,
    required this.revealTitleOnScroll,
    required this.modal,
  });

  final double topInset;
  final String title;
  final Widget? leading, trailing;
  final AppPalette palette;
  final bool revealTitleOnScroll, modal;

  // A page sheet starts below the status bar, so it needs no top inset.
  double get _top => modal ? 0 : topInset;

  @override
  double get minExtent => _top + 44;

  @override
  double get maxExtent => _top + 44;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final bar = Padding(
      padding: EdgeInsets.only(top: _top),
      child: SizedBox(
        height: 44,
        child: NavigationToolbar(
          leading: leading,
          middle: Opacity(
            opacity: revealTitleOnScroll && !overlapsContent ? 0 : 1,
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
            ),
          ),
          trailing: trailing,
          centerMiddle: true,
          middleSpacing: 8,
        ),
      ),
    );
    if (!overlapsContent) {
      return ColoredBox(color: palette.bg, child: bar);
    }
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.barBg,
            border: Border(
              bottom: BorderSide(color: palette.separator, width: .5),
            ),
          ),
          child: bar,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SmallBarDelegate old) =>
      topInset != old.topInset ||
      title != old.title ||
      leading != old.leading ||
      trailing != old.trailing ||
      palette != old.palette ||
      revealTitleOnScroll != old.revealTitleOnScroll ||
      modal != old.modal;
}

/// Opens [builder] (usually returning an [AppScaffold.modal]) as an iOS page
/// sheet that slides up below the status bar, can be dragged down to dismiss
/// and scales the page behind it.
///
/// Pop it with `Navigator.pop(context, result)`; the result completes the
/// returned future.
///
/// ```dart
/// final saved = await showAppModal<bool>(
///   context,
///   builder: (_) => ServerFormPage(controller: controller),
/// );
/// ```
Future<T?> showAppModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  RouteSettings? settings,
}) => showCupertinoSheet<T>(
  context: context,
  settings: settings,
  scrollableBuilder: (sheetContext, controller) => PrimaryScrollController(
    controller: controller,
    child: Builder(builder: builder),
  ),
);
