import 'package:flutter/material.dart';

const sshTerminalRouteName = '/ssh-terminal';

/// Ordinary ledger pages keep their reading width. A live terminal and its
/// dialogs use the complete display, including wide phone landscape layouts.
class AppViewportObserver extends NavigatorObserver {
  final fullWidth = ValueNotifier(false);
  final _routes = <Route<dynamic>>[];
  bool _scheduled = false, _disposed = false;

  void _changed() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_disposed) {
        fullWidth.value = _routes.any(
          (route) => route.settings.name == sshTerminalRouteName,
        );
      }
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _routes.remove(oldRoute);
    if (newRoute != null) _routes.add(newRoute);
    _changed();
  }

  void dispose() {
    _disposed = true;
    fullWidth.dispose();
  }
}
