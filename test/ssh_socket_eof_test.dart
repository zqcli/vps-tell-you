import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/connections/ssh_socket_io.dart';

/// Only a stream/sink contract: no socket endpoint, shell, or authentication.
class _SocketFixture extends Stream<Uint8List> implements Socket {
  final incoming = StreamController<Uint8List>();
  final completion = Completer<void>();
  final writes = <List<int>>[];
  int closeCalls = 0;

  @override
  Future<void> get done => completion.future;

  @override
  Future<void> close() async {
    closeCalls++;
    if (!completion.isCompleted) completion.complete();
  }

  @override
  void destroy() {
    unawaited(incoming.close());
    if (!completion.isCompleted) completion.complete();
  }

  @override
  void add(List<int> bytes) => writes.add(List.of(bytes));

  @override
  Future<void> flush() async {}

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => incoming.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<int> _word(int value) => [
  (value >> 24) & 255,
  (value >> 16) & 255,
  (value >> 8) & 255,
  value & 255,
];

List<int> _string(String text) {
  final bytes = utf8.encode(text);
  return [..._word(bytes.length), ...bytes];
}

/// An RFC 4253 cleartext SSH_MSG_DEBUG frame, before key negotiation.
/// These messages do not authorize a session or bypass host verification.
List<int> _debugFrame(String text) {
  final payload = [4, 0, ..._string(text), ..._string('')];
  var padding = 8 - ((5 + payload.length) % 8);
  if (padding < 4) padding += 8;
  return [
    ..._word(1 + payload.length + padding),
    padding,
    ...payload,
    ...List.filled(padding, 0),
  ];
}

void main() {
  test(
    'SSHTransport handles every coalesced frame before native EOF',
    () async {
      final raw = _SocketFixture();
      final parsed = <String>[];
      var hostChecks = 0;
      final transport = SSHTransport(
        NativeSshSocket(raw),
        printDebug: (text) {
          if (text != null && text.startsWith('Remote: ')) parsed.add(text);
        },
        onVerifyHostKey: (_, _) {
          hostChecks++;
          return false;
        },
      );
      final messages = List.generate(32, (i) => 'synthetic-frame-$i');
      // A single read gives dartssh2 a packet queue. Its asynchronous handlers
      // yield between frames, while the raw stream immediately queues EOF.
      raw.incoming.add(
        Uint8List.fromList([
          ...utf8.encode('SSH-2.0-synthetic-fixture\r\n'),
          for (final message in messages) ..._debugFrame(message),
        ]),
      );
      unawaited(raw.incoming.close());

      await transport.done;
      expect(parsed, messages.map((message) => 'Remote: $message').toList());
      expect(hostChecks, 0);
      expect(raw.closeCalls, 1);
    },
  );

  test(
    'stream errors retain identity and stack without waiting for EOF',
    () async {
      final raw = _SocketFixture();
      final adapter = NativeSshSocket(raw);
      final problem = StateError('synthetic read error');
      final stack = StackTrace.current;
      final observedError = Completer<void>();
      final observedDone = Completer<void>();
      final received = <int>[];
      final subscription = adapter.stream.listen(
        received.addAll,
        onError: (Object error, StackTrace trace) {
          expect(error, same(problem));
          expect(trace, same(stack));
          observedError.complete();
        },
        onDone: observedDone.complete,
      );

      raw.incoming.add(Uint8List.fromList([1, 2]));
      raw.incoming.addError(problem, stack);
      await observedError.future;
      expect(received, [1, 2]);
      expect(observedDone.isCompleted, isFalse);
      raw.incoming.add(Uint8List.fromList([3, 4]));
      await raw.incoming.close();
      await observedDone.future;
      expect(received, [1, 2, 3, 4]);
      await subscription.cancel();
    },
  );

  test(
    'cancellation suppresses an already scheduled EOF notification',
    () async {
      final raw = _SocketFixture();
      final adapter = NativeSshSocket(raw);
      var doneCalls = 0;
      final received = <int>[];
      final subscription = adapter.stream.listen(
        received.addAll,
        onDone: () => doneCalls++,
      );
      raw.incoming.add(Uint8List.fromList([1, 2, 3]));
      // The raw source has delivered EOF, but the adapter's event-turn callback
      // has not run. Explicit cancellation must still take effect immediately.
      await raw.incoming.close();
      expect(doneCalls, 0);
      await subscription.cancel();
      await Future<void>(() {});
      expect(doneCalls, 0);
      expect(received, [1, 2, 3]);
    },
  );

  test(
    'explicit cancellation discards queued bytes and cancels its source',
    () async {
      final raw = _SocketFixture();
      var sourceCancellations = 0;
      raw.incoming.onCancel = () => sourceCancellations++;
      final adapter = NativeSshSocket(raw);
      final received = <int>[];
      var doneCalls = 0;
      final subscription = adapter.stream.listen(
        received.addAll,
        onDone: () => doneCalls++,
      );
      raw.incoming.add(Uint8List.fromList([1, 2, 3]));
      await subscription.cancel();
      expect(sourceCancellations, 1);
      await raw.incoming.close();
      await Future<void>(() {});
      expect(received, isEmpty);
      expect(doneCalls, 0);
    },
  );
}
