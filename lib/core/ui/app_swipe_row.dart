import 'package:flutter/material.dart';

import '../app_palette.dart';
import 'app_list.dart';

/// One button revealed by swiping an [AppSwipeRow].
class AppSwipeAction {
  const AppSwipeAction({
    this.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  /// Placed on the button's [InkWell].
  final Key? key;
  final Color color;
  final IconData icon;
  final String label;

  /// `null` dims the button and makes it inert.
  final VoidCallback? onTap;
}

/// Row with swipe-to-reveal buttons. Swiping towards the leading edge reveals
/// [trailing], towards the trailing edge [leading] (both mirror in RTL). Only
/// one row stays open; the buttons are only built while the row is swiped or
/// settling, so their colours never bleed through the antialiased corners of
/// a rounded group. While open the content ignores taps and a tap on it
/// closes the row.
class AppSwipeRow extends StatefulWidget implements AppSectionItem {
  const AppSwipeRow({
    super.key,
    this.leading = const [],
    this.trailing = const [],
    this.leadingKey,
    this.trailingKey,
    this.separatorInset = 0,
    required this.child,
  });
  final List<AppSwipeAction> leading, trailing;

  /// Keys of the revealed button groups.
  final Key? leadingKey, trailingKey;
  final Widget child;

  @override
  final double separatorInset;

  @override
  State<AppSwipeRow> createState() => _AppSwipeRowState();
}

class _AppSwipeRowState extends State<AppSwipeRow> {
  static const _buttonWidth = 76.0;
  static _AppSwipeRowState? _open;

  /// Signed distance the content is pushed: positive towards the leading edge
  /// (revealing the trailing buttons), negative towards the trailing edge.
  double _extent = 0;

  /// Which side's buttons are built while the row settles back to zero.
  bool _trailingSide = true;
  bool _dragging = false, _visible = false;

  double get _trailingWidth => widget.trailing.length * _buttonWidth;
  double get _leadingWidth => widget.leading.length * _buttonWidth;

  void _setExtent(double value, {bool drag = false}) {
    if (!mounted) return;
    setState(() {
      if (value != 0) _trailingSide = value > 0;
      if (value != 0 || drag) {
        _visible = true;
      } else if (_extent == 0) {
        _visible = false;
      }
      _extent = value;
      _dragging = drag;
    });
    if (value != 0) {
      if (_open != this) {
        final previous = _open;
        _open = this;
        previous?._setExtent(0);
      }
    } else if (_open == this) {
      _open = null;
    }
  }

  void _close() => _setExtent(0);

  /// Where a released drag settles: fully open on that side, or closed.
  double get _settled => _extent > _trailingWidth * .45
      ? _trailingWidth
      : _extent < -_leadingWidth * .45
      ? -_leadingWidth
      : 0;

  @override
  void dispose() {
    if (_open == this) _open = null;
    super.dispose();
  }

  Widget _button(AppSwipeAction action) => SizedBox(
    width: _buttonWidth,
    child: Opacity(
      opacity: action.onTap == null ? .45 : 1,
      child: Material(
        color: action.color,
        child: InkWell(
          key: action.key,
          onTap: action.onTap == null
              ? null
              : () {
                  _close();
                  action.onTap!();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.icon, size: 22, color: Colors.white),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    action.label,
                    maxLines: 1,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _actionsLayer({
    required AlignmentGeometry alignment,
    required bool side,
    required Key? key,
    required List<AppSwipeAction> actions,
  }) => Positioned.fill(
    child: Align(
      alignment: alignment,
      child: !_visible || _trailingSide != side
          ? const SizedBox.shrink()
          : ExcludeSemantics(
              excluding: _extent == 0,
              child: IgnorePointer(
                ignoring: _extent == 0,
                child: SizedBox(
                  key: key,
                  width: actions.length * _buttonWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (final action in actions) _button(action)],
                  ),
                ),
              ),
            ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Positive logical extent moves the content towards the leading edge.
    final sign = Directionality.of(context) == TextDirection.rtl ? 1.0 : -1.0;
    final lower = widget.leading.isEmpty ? 0.0 : -_leadingWidth - 30;
    final upper = widget.trailing.isEmpty ? 0.0 : _trailingWidth + 30;
    return ClipRect(
      child: Stack(
        children: [
          _actionsLayer(
            alignment: AlignmentDirectional.centerEnd,
            side: true,
            key: widget.trailingKey,
            actions: widget.trailing,
          ),
          _actionsLayer(
            alignment: AlignmentDirectional.centerStart,
            side: false,
            key: widget.leadingKey,
            actions: widget.leading,
          ),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _setExtent(_extent, drag: true),
            onHorizontalDragUpdate: (details) => _setExtent(
              (_extent + details.delta.dx * sign).clamp(lower, upper),
              drag: true,
            ),
            onHorizontalDragEnd: (_) => _setExtent(_settled),
            onHorizontalDragCancel: () => _setExtent(_settled),
            child: AnimatedContainer(
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              onEnd: () {
                if (_extent == 0 && _visible && mounted) {
                  setState(() => _visible = false);
                }
              },
              transform: Matrix4.translationValues(_extent * sign, 0, 0),
              child: Material(
                color: context.palette.surface,
                child: IgnorePointer(
                  ignoring: _extent != 0,
                  child: widget.child,
                ),
              ),
            ),
          ),
          if (_extent != 0)
            PositionedDirectional(
              top: 0,
              bottom: 0,
              start: _extent < 0 ? _leadingWidth : 0,
              end: _extent > 0 ? _trailingWidth : 0,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
              ),
            ),
        ],
      ),
    );
  }
}
