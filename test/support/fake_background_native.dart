import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/core/background_grace.dart';

/// Stands in for ios/Runner/BackgroundTimeChannel.swift.
class FakeBackgroundNative {
  FakeBackgroundNative({this.remaining = 30});

  /// What `backgroundTimeRemaining` reports right after `begin`.
  double remaining;

  /// `begin` fails like a refused `beginBackgroundTask`.
  bool refuse = false;

  /// While set, `begin` waits for it (the app may return meanwhile).
  Completer<void>? holdBegin;

  final calls = <MethodCall>[];
  final live = <int>{};
  int _next = 1;

  static const channel = MethodChannel(backgroundChannelName);

  int get begins => calls.where((c) => c.method == 'begin').length;
  int get ends => calls.where((c) => c.method == 'end').length;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, _handle);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
  }

  Future<Object?> _handle(MethodCall call) async {
    calls.add(call);
    switch (call.method) {
      case 'begin':
        await holdBegin?.future;
        if (refuse) {
          throw PlatformException(code: 'unavailable');
        }
        final token = _next++;
        live.add(token);
        return {'token': token, 'remainingSeconds': remaining};
      case 'end':
        live.remove((call.arguments as Map)['token']);
        return null;
      case 'remaining':
        return remaining;
    }
    return null;
  }

  /// The expiration handler: tells Dart, then (like the Swift code) ends the
  /// task once Dart has answered. Returns whether Dart answered.
  Future<bool> expire(int token) async {
    var answered = false;
    final message = const StandardMethodCodec().encodeMethodCall(
      MethodCall('expiring', {'token': token}),
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          backgroundChannelName,
          message,
          (_) => answered = true,
        );
    if (answered) live.remove(token);
    return answered;
  }
}
