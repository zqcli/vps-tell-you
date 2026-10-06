import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../servers/server_record.dart';

typedef TcpConnector = Future<ConnectionTask<Socket>> Function(
  String host,
  int port,
);

enum TcpOutcome { connected, refused, timedOut, cancelled, failed }

class TcpTarget {
  const TcpTarget._(this.host, this.port);
  factory TcpTarget({required String host, required int port}) {
    var normalized = host.trim();
    if (normalized.startsWith('[') && normalized.endsWith(']')) {
      normalized = normalized.substring(1, normalized.length - 1);
      if (InternetAddress.tryParse(normalized)?.type !=
          InternetAddressType.IPv6) {
        throw ArgumentError('请输入有效的 IPv6 地址');
      }
    }
    if (normalized.isEmpty || !ServerRecord.validHost(normalized)) {
      throw ArgumentError('请输入 IP 或域名，不含协议、端口或路径');
    }
    if (port < 1 || port > 65535) throw ArgumentError('端口需为 1–65535');
    final address = InternetAddress.tryParse(normalized);
    return TcpTarget._(address?.address ?? normalized.toLowerCase(), port);
  }
  final String host;
  final int port;
  String get label => host.contains(':') ? '[$host]:$port' : '$host:$port';
}

class TcpTestResult {
  const TcpTestResult({
    required this.target,
    required this.outcome,
    required this.finishedAt,
    required this.elapsed,
    this.remoteAddress,
  });
  final TcpTarget target;
  final TcpOutcome outcome;
  final DateTime finishedAt;
  final Duration elapsed;
  final String? remoteAddress;
  String get source => '本机 TCP 连接测试';
  String get label => switch (outcome) {
    TcpOutcome.connected => 'TCP 连接成功',
    TcpOutcome.refused => '连接被拒绝',
    TcpOutcome.timedOut => '连接超时',
    TcpOutcome.cancelled => '测试已取消',
    TcpOutcome.failed => '连接失败（网络或地址不可用）',
  };
}

class _TcpAttempt {
  _TcpAttempt(this.target);
  final TcpTarget target;
  final watch = Stopwatch()..start();
  final done = Completer<void>();
  ConnectionTask<Socket>? task;
  Timer? timer;
  bool ended = false;
}

/// A single target and bounded attempt. Even a DNS/startConnect future that
/// arrives after cancellation is consumed and cancelled; late sockets are
/// destroyed, and can never publish a result for a replacement target.
class TcpTestController extends ChangeNotifier {
  TcpTestController({
    TcpConnector? connector,
    this.timeout = const Duration(seconds: 10),
    DateTime Function()? clock,
  }) : _connector =
           connector ?? ((host, port) => Socket.startConnect(host, port)),
       _clock = clock ?? DateTime.now {
    if (timeout <= Duration.zero) throw ArgumentError('超时必须大于 0');
  }
  final TcpConnector _connector;
  final DateTime Function() _clock;
  final Duration timeout;
  _TcpAttempt? _attempt;
  bool _disposed = false;
  TcpTarget? target;
  TcpTestResult? result;
  bool get running => _attempt != null && !_attempt!.ended;

  Future<void> test(TcpTarget next) {
    if (_disposed) throw StateError('TCP controller disposed');
    _stopCurrent(publish: false);
    final attempt = _TcpAttempt(next);
    _attempt = attempt;
    target = next;
    result = null;
    attempt.timer = Timer(timeout, () => _finish(attempt, TcpOutcome.timedOut));
    notifyListeners();
    unawaited(_connect(attempt));
    return attempt.done.future;
  }

  Future<void> _connect(_TcpAttempt attempt) async {
    try {
      final task = await _connector(attempt.target.host, attempt.target.port);
      attempt.task = task;
      // Attach success/error handlers before cancel, including late task setup.
      final socketResult = task.socket.then<void>(
        (socket) {
          try {
            if (!attempt.ended) {
              _finish(
                attempt,
                TcpOutcome.connected,
                remoteAddress: socket.remoteAddress.address,
              );
            }
          } finally {
            socket.destroy();
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!attempt.ended) _finish(attempt, _failureOutcome(error));
        },
      );
      if (attempt.ended) task.cancel();
      await socketResult;
    } catch (error) {
      if (!attempt.ended) _finish(attempt, _failureOutcome(error));
    }
  }

  TcpOutcome _failureOutcome(Object error) {
    if (error is SocketException &&
        const {61, 111, 10061}.contains(error.osError?.errorCode)) {
      return TcpOutcome.refused;
    }
    return TcpOutcome.failed;
  }

  void _finish(
    _TcpAttempt attempt,
    TcpOutcome outcome, {
    String? remoteAddress,
    bool publish = true,
  }) {
    if (attempt.ended) return;
    attempt.ended = true;
    attempt.timer?.cancel();
    attempt.watch.stop();
    if (outcome != TcpOutcome.connected) attempt.task?.cancel();
    if (!_disposed && identical(attempt, _attempt) && publish) {
      result = TcpTestResult(
        target: attempt.target,
        outcome: outcome,
        finishedAt: _clock().toUtc(),
        elapsed: attempt.watch.elapsed,
        remoteAddress: remoteAddress,
      );
      notifyListeners();
    }
    attempt.done.complete();
  }

  void _stopCurrent({bool publish = true}) {
    final attempt = _attempt;
    if (attempt != null) {
      _finish(attempt, TcpOutcome.cancelled, publish: publish);
    }
  }

  void cancel() => _stopCurrent();

  /// Target edits invalidate both an in-flight attempt and its previous result.
  void clearTarget() {
    _stopCurrent(publish: false);
    _attempt = null;
    target = null;
    result = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopCurrent(publish: false);
    super.dispose();
  }
}
