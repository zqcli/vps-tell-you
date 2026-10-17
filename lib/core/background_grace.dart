import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// MethodChannel implemented by ios/Runner/BackgroundTimeChannel.swift.
const backgroundChannelName = 'vps_tell_you/background';

/// How long a session is kept after the app leaves the foreground where the
/// system gives no measurable budget (Android, desktop, or an iOS refusal).
/// Android has no foreground service here, so this is best effort: once the
/// process is cached or frozen nothing can keep a TCP session alive.
const fixedBackgroundGrace = Duration(seconds: 30);

/// Sessions are closed this long before the budget the system reported, so the
/// disconnect is not racing the expiration handler.
const backgroundCloseMargin = Duration(seconds: 3);

/// A remaining time above this means "not measurable" (iOS reports a huge
/// number while the app is still in the foreground).
const _plausibleRemaining = Duration(minutes: 10);

/// An SSH session (terminal or SFTP) that [BackgroundGrace] may keep alive for
/// a short while after the app leaves the foreground.
abstract interface class BackgroundSession {
  /// Connected and worth keeping. Sessions that are not live when the app
  /// leaves the foreground (still connecting, already ended) are ended at once.
  bool get isLive;

  /// Closes the session cleanly: disconnect only, no input is replayed or
  /// reconnected later. [graceExpired] is false for the immediate close of a
  /// session that was never established, true when the time ran out.
  void endInBackground({required bool graceExpired});
}

/// Keeps live SSH sessions alive for the short, system-granted time after the
/// app moves to the background, then closes them.
///
/// * iOS: one `UIApplication.beginBackgroundTask` shared by all sessions. The
///   system decides the duration (typically about 30 s); sessions are closed a
///   few seconds before the reported remaining time, or when the native
///   expiration handler sends `expiring`.
/// * Everything else: a fixed [grace] window, no foreground service.
///
/// Returning to the foreground before the end ends the task and leaves the
/// sessions untouched, so the terminal simply continues.
class BackgroundGrace with WidgetsBindingObserver {
  BackgroundGrace({
    MethodChannel? channel,
    this.native,
    this.grace = fixedBackgroundGrace,
    Duration Function()? clock,
  }) : _channel = channel ?? const MethodChannel(backgroundChannelName),
       _clock = clock ?? _monotonic;

  /// Shared instance used by the pages. Tests replace it.
  static BackgroundGrace instance = BackgroundGrace();

  static final Stopwatch _watch = Stopwatch()..start();
  static Duration _monotonic() => _watch.elapsed;

  /// Forces (true) or disables (false) the iOS task; null follows the platform.
  final bool? native;
  final Duration grace;
  final MethodChannel _channel;
  final Duration Function() _clock;

  final _sessions = <BackgroundSession>[];
  bool _attached = false, _background = false, _expired = false;
  int _epoch = 0;
  int? _token;
  Timer? _timer;
  Duration? _deadline;

  bool get _useNative =>
      native ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  /// The app is in the background and sessions are being kept.
  bool get inBackground => _background;

  /// A system background task is currently held.
  bool get holdsTask => _token != null;

  /// A close timer is armed.
  bool get timerArmed => _timer != null;

  void register(BackgroundSession session) {
    if (_sessions.contains(session)) return;
    _sessions.add(session);
    if (!_attached) {
      _attached = true;
      WidgetsBinding.instance.addObserver(this);
      _channel.setMethodCallHandler(_onNativeCall);
    }
  }

  void unregister(BackgroundSession session) {
    _sessions.remove(session);
    if (_sessions.isEmpty && _attached) {
      _attached = false;
      WidgetsBinding.instance.removeObserver(this);
      _channel.setMethodCallHandler(null);
      _reset();
    } else {
      refresh();
    }
  }

  /// A session changed state. When nothing live is left in the background the
  /// task is given back early.
  void refresh() {
    if (_background && !_expired && !_sessions.any((s) => s.isLive)) {
      _timer?.cancel();
      _timer = null;
      _deadline = null;
      _releaseTask();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _enterBackground();
      case AppLifecycleState.resumed:
        _returnToForeground();
      case AppLifecycleState.inactive:
        // Control Center, app switcher, system dialogs: still the foreground.
        break;
    }
  }

  void _enterBackground() {
    if (_background) return;
    _background = true;
    _expired = false;
    final epoch = ++_epoch;
    for (final session in List.of(_sessions)) {
      if (!session.isLive) _end(session, graceExpired: false);
    }
    if (!_sessions.any((s) => s.isLive)) return;
    if (_useNative) {
      unawaited(_beginNative(epoch));
    } else {
      _arm(grace, epoch);
    }
  }

  Future<void> _beginNative(int epoch) async {
    Map<String, Object?>? reply;
    try {
      reply = await _channel.invokeMapMethod<String, Object?>('begin', {
        'name': 'ssh-session',
      });
    } on PlatformException {
      reply = null;
    } on MissingPluginException {
      reply = null;
    }
    final token = reply?['token'] as int?;
    if (epoch != _epoch) {
      // Back in the foreground (or closed) while the call was in flight.
      if (token != null) unawaited(_endNative(token));
      return;
    }
    _token = token;
    final seconds = (reply?['remainingSeconds'] as num?)?.toDouble();
    final measured =
        seconds != null &&
        seconds.isFinite &&
        seconds < _plausibleRemaining.inSeconds;
    // Without a task (refused) nothing protects the app: use the fixed window.
    // With a task but no usable number, assume the typical budget.
    final delay = token == null
        ? grace
        : _closeDelay(
            measured
                ? Duration(milliseconds: (seconds.clamp(0, 600) * 1000).round())
                : grace,
          );
    if (kDebugMode) {
      debugPrint(
        '[background] begin token=$token '
        'remaining=${seconds?.toStringAsFixed(1) ?? 'n/a'}s '
        'closeIn=${delay.inMilliseconds}ms',
      );
    }
    _arm(delay, epoch);
  }

  Duration _closeDelay(Duration window) => window > backgroundCloseMargin * 2
      ? window - backgroundCloseMargin
      : window ~/ 2;

  void _arm(Duration delay, int epoch) {
    _deadline = _clock() + delay;
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (epoch != _epoch) return;
      _timer = null;
      _closeAll();
      _releaseTask();
    });
  }

  /// Native expiration handler: the system is about to suspend the app.
  Future<Object?> _onNativeCall(MethodCall call) async {
    if (call.method != 'expiring') return null;
    final token = (call.arguments as Map?)?['token'];
    if (token == _token) {
      // The native side ends the task as soon as this call returns.
      _token = null;
    }
    if (_background && !_expired) {
      _closeAll();
    }
    return null;
  }

  void _closeAll() {
    _expired = true;
    _timer?.cancel();
    _timer = null;
    for (final session in List.of(_sessions)) {
      if (session.isLive) _end(session, graceExpired: true);
    }
  }

  void _end(BackgroundSession session, {required bool graceExpired}) {
    try {
      session.endInBackground(graceExpired: graceExpired);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'background grace',
        ),
      );
    }
  }

  void _returnToForeground() {
    if (!_background) return;
    // The process may have been frozen past the deadline without the timer or
    // the native callback running; the connection cannot be trusted then.
    final late = !_expired && _deadline != null && _clock() >= _deadline!;
    _reset();
    if (late) {
      for (final session in List.of(_sessions)) {
        if (session.isLive) _end(session, graceExpired: true);
      }
    }
  }

  void _reset() {
    _epoch++;
    _background = false;
    _expired = false;
    _timer?.cancel();
    _timer = null;
    _deadline = null;
    _releaseTask();
  }

  void _releaseTask() {
    final token = _token;
    _token = null;
    if (token != null) unawaited(_endNative(token));
  }

  Future<void> _endNative(int token) async {
    try {
      await _channel.invokeMethod<void>('end', {'token': token});
    } on PlatformException {
      // The task is gone already.
    } on MissingPluginException {
      // No native side (tests, other platforms).
    }
  }
}
