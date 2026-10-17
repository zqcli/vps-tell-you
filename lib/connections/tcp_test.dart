import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';
import '../l10n/generated/app_localizations.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/net_address.dart';
import '../security/proxy_models.dart';
import 'error_details.dart';
import 'proxy_connector.dart';

typedef TcpConnector = Future<ConnectionTask<Socket>> Function(
  String host,
  int port,
);

enum TcpOutcome { connected, refused, timedOut, cancelled, failed }

final _digits = RegExp(r'^[0-9]+$');

class TcpTarget {
  const TcpTarget._(this.host, this.port, this.kind);

  /// [host] is an IPv4, IPv6 (optionally bracketed; link-local may carry a
  /// zone) or DNS name. Only the bare canonical form is kept, which is what
  /// `Socket.connect` takes; brackets are for display ([label]).
  factory TcpTarget({required String host, required int port}) {
    final input = host.trim();
    final address = NetAddress.tryParse(input);
    if (address == null) {
      // A bracketed non-IPv6 is a different mistake than a bad host name.
      throw LocalizedArgumentError(
        (l10n) => input.startsWith('[') && input.endsWith(']')
            ? l10n.tcpValidIpv6
            : l10n.tcpValidHost,
      );
    }
    if (port < 1 || port > 65535) {
      throw LocalizedArgumentError((l10n) => l10n.tcpValidPort);
    }
    return TcpTarget._(address.host, port, address.kind);
  }

  /// One-field input: `host`, `host:port`, `[v6]` or `[v6]:port`. A bare IPv6
  /// is always an address. [defaultPort] is used when no port is given.
  factory TcpTarget.parse(String input, {required int defaultPort}) {
    final split = splitHostPort(input.trim());
    if (split == null) {
      throw LocalizedArgumentError((l10n) => l10n.tcpValidHost);
    }
    final text = split.port;
    if (text != null && !_digits.hasMatch(text)) {
      // `https://host`, `host:` ... are not a host with a port.
      throw LocalizedArgumentError((l10n) => l10n.tcpValidHost);
    }
    final port = text == null ? defaultPort : (int.tryParse(text) ?? 0);
    return TcpTarget(host: split.host, port: port);
  }

  final String host;
  final int port;
  final NetHostKind kind;
  String get label => formatHostPort(host, port);
}

class TcpTestResult {
  const TcpTestResult({
    required this.target,
    required this.outcome,
    required this.finishedAt,
    required this.elapsed,
    this.remoteAddress,
    this.remoteFamily,
    this.proxy,
    this.proxyName,
    this.proxyFailure,
    this.errorDetails,
  });
  final TcpTarget target;

  /// The original (redacted) error of a refused / timed-out / failed test;
  /// null when it connected or was cancelled. In memory only.
  final ErrorDetails? errorDetails;

  /// Set when the test went through a proxy (never carries credentials in
  /// anything shown). Then [remoteAddress] is the proxy's, not the target's.
  final ProxyEndpoint? proxy;

  /// Name of the saved proxy, null for a temporary one.
  final String? proxyName;
  final ProxyException? proxyFailure;
  bool get viaProxy => proxy != null;
  final TcpOutcome outcome;
  final DateTime finishedAt;
  final Duration elapsed;
  final String? remoteAddress;

  /// Family the connection actually used (a name can resolve to either).
  final NetHostKind? remoteFamily;
  String get source => sourceFor(defaultLocalizations);
  String sourceFor(AppLocalizations l10n) => l10n.tcpSource;
  String get label => labelFor(defaultLocalizations);
  String labelFor(AppLocalizations l10n) => switch (outcome) {
    TcpOutcome.connected => l10n.tcpConnected,
    TcpOutcome.refused => l10n.tcpRefused,
    TcpOutcome.timedOut => l10n.tcpTimedOut,
    TcpOutcome.cancelled => l10n.tcpCancelled,
    TcpOutcome.failed => l10n.tcpFailed,
  };
}

class _TcpAttempt {
  _TcpAttempt(this.target, {this.proxy, this.proxyName});
  final TcpTarget target;
  final ProxyEndpoint? proxy;
  final String? proxyName;
  ProxyDial? dial;
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
    this.proxyTlsContext,
  }) : _connector =
           connector ?? ((host, port) => Socket.startConnect(host, port)),
       _clock = clock ?? DateTime.now {
    if (timeout <= Duration.zero) {
      throw LocalizedArgumentError((l10n) => l10n.tcpTimeoutPositive);
    }
  }
  final TcpConnector _connector;
  final DateTime Function() _clock;

  /// Replaces the TLS trust roots for an HTTPS proxy (tests only).
  final SecurityContext? proxyTlsContext;
  final Duration timeout;
  _TcpAttempt? _attempt;
  bool _disposed = false;
  TcpTarget? target;
  TcpTestResult? result;
  bool get running => _attempt != null && !_attempt!.ended;

  /// With [proxy] the target is dialled through it (SOCKS5/HTTP CONNECT); the
  /// result then only says whether the proxy could reach the target. [proxy]
  /// is used for this attempt only and never stored.
  Future<void> test(TcpTarget next, {ProxyEndpoint? proxy, String? proxyName}) {
    if (_disposed) {
      throw StateError('TCP controller disposed');
    }
    _stopCurrent(publish: false);
    final attempt = _TcpAttempt(next, proxy: proxy, proxyName: proxyName);
    _attempt = attempt;
    target = next;
    result = null;
    attempt.timer = Timer(
      timeout,
      () => _finish(
        attempt,
        TcpOutcome.timedOut,
        cause: TimeoutException('No connection was established', timeout),
      ),
    );
    notifyListeners();
    unawaited(_connect(attempt));
    return attempt.done.future;
  }

  void _connectViaProxy(_TcpAttempt attempt) {
    final dial = attempt.dial = ProxyDial(
      proxy: attempt.proxy!,
      host: attempt.target.host,
      port: attempt.target.port,
      tlsContext: proxyTlsContext,
    );
    dial.tunnel.then<void>(
      (tunnel) {
        try {
          _reached(attempt, tunnel.proxyAddress);
        } finally {
          tunnel.destroy();
        }
      },
      onError: (Object error, StackTrace stack) {
        if (attempt.ended) return;
        final problem = error is ProxyException
            ? error
            : const ProxyException(ProxyFailure.closed);
        _finish(
          attempt,
          problem.failure == ProxyFailure.timeout
              ? TcpOutcome.timedOut
              : problem.targetRefused
              ? TcpOutcome.refused
              : TcpOutcome.failed,
          proxyFailure: problem,
          cause: problem,
        );
      },
    );
  }

  Future<void> _connect(_TcpAttempt attempt) async {
    if (attempt.proxy != null) {
      _connectViaProxy(attempt);
      return;
    }
    try {
      final task = await _connector(attempt.target.host, attempt.target.port);
      attempt.task = task;
      // Attach success/error handlers before cancel, including late task setup.
      final socketResult = task.socket.then<void>(
        (socket) {
          try {
            _reached(attempt, socket.remoteAddress);
          } finally {
            socket.destroy();
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!attempt.ended) {
            _finish(attempt, _failureOutcome(error), cause: error);
          }
        },
      );
      if (attempt.ended) {
        task.cancel();
      }
      await socketResult;
    } catch (error) {
      if (!attempt.ended) {
        _finish(attempt, _failureOutcome(error), cause: error);
      }
    }
  }

  void _reached(_TcpAttempt attempt, InternetAddress address) {
    if (attempt.ended) return;
    _finish(
      attempt,
      TcpOutcome.connected,
      remoteAddress: address.address,
      remoteFamily: switch (address.type) {
        InternetAddressType.IPv6 => NetHostKind.ipv6,
        InternetAddressType.IPv4 => NetHostKind.ipv4,
        _ => null,
      },
    );
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
    NetHostKind? remoteFamily,
    ProxyException? proxyFailure,
    Object? cause,
    bool publish = true,
  }) {
    if (attempt.ended) {
      return;
    }
    attempt.ended = true;
    attempt.timer?.cancel();
    attempt.watch.stop();
    if (outcome != TcpOutcome.connected) {
      attempt.task?.cancel();
      attempt.dial?.cancel();
    }
    if (!_disposed && identical(attempt, _attempt) && publish) {
      final proxy = attempt.proxy;
      final failed =
          outcome == TcpOutcome.refused ||
          outcome == TcpOutcome.timedOut ||
          outcome == TcpOutcome.failed;
      result = TcpTestResult(
        errorDetails: !failed || cause == null
            ? null
            : ErrorDetails(
                stage: proxy == null
                    ? ErrorStage.connect
                    : (proxyFailure?.stage ?? ErrorStage.proxy),
                technical: cause is ProxyException
                    ? cause.detail
                    : describeError(cause),
                target: attempt.target.label,
                proxy: proxy == null
                    ? null
                    : [?attempt.proxyName, proxy.label].join(' · '),
                time: _clock(),
                secrets: [?proxy?.password],
              ),
        target: attempt.target,
        outcome: outcome,
        finishedAt: _clock().toUtc(),
        elapsed: attempt.watch.elapsed,
        remoteAddress: remoteAddress,
        remoteFamily: remoteFamily,
        proxy: attempt.proxy,
        proxyName: attempt.proxyName,
        proxyFailure: proxyFailure,
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
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopCurrent(publish: false);
    super.dispose();
  }
}
