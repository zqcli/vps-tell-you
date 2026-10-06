import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/connections/ssh_socket_io.dart';

/// A deterministic native Socket contract, without a real network endpoint.
/// Like dart:io's IOSink, close() returns the same future as done, carrying
/// a prior asynchronous write failure to every listener.
class _SocketFixture implements Socket {
  final incoming = StreamController<Uint8List>();
  final completion = Completer<void>();
  final writes = <List<int>>[];
  Object? closeFailure, writeFailure, flushFailure;
  int closeCalls = 0, destroys = 0;

  @override
  Future<void> get done => completion.future;

  @override
  Future<void> close() {
    closeCalls++;
    if (!completion.isCompleted) {
      final problem = closeFailure;
      if (problem == null) {
        completion.complete();
      } else {
        completion.completeError(problem, StackTrace.current);
      }
    }
    return done;
  }

  @override
  void destroy() {
    destroys++;
    unawaited(incoming.close());
  }

  @override
  void add(List<int> bytes) {
    final problem = writeFailure;
    if (problem != null) throw problem;
    writes.add(List.of(bytes));
  }

  @override
  Future<void> flush() async {
    final problem = flushFailure;
    if (problem != null) throw problem;
  }

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

void main() {
  const brokenPipe = SocketException(
    'Synthetic write failure',
    osError: OSError('Synthetic broken pipe', 32),
  );

  test(
    'close handles teardown EPIPE while done preserves original failure',
    () async {
      final raw = _SocketFixture()..closeFailure = brokenPipe;
      final adapter = NativeSshSocket(raw);
      final originalFailure = expectLater(
        adapter.done,
        throwsA(same(brokenPipe)),
      );

      await adapter.close();
      await originalFailure;
      expect(raw.closeCalls, 1);
      expect(raw.destroys, 1);
      expect(adapter.sink, same(raw));
      expect(adapter.stream, same(raw));
    },
  );

  test('close success does not destroy a healthy socket', () async {
    final raw = _SocketFixture();
    final adapter = NativeSshSocket(raw);
    await adapter.close();
    await adapter.done;
    expect(raw.closeCalls, 1);
    expect(raw.destroys, 0);
  });

  test('write and flush failures remain observable to callers', () async {
    final raw = _SocketFixture()
      ..writeFailure = brokenPipe
      ..flushFailure = brokenPipe;
    final adapter = NativeSshSocket(raw);
    expect(() => adapter.sink.add([1, 2, 3]), throwsA(same(brokenPipe)));
    await expectLater(adapter.flush(), throwsA(same(brokenPipe)));
    expect(raw.writes, isEmpty);
    expect(raw.destroys, 0);
    await adapter.close();
  });

  test(
    'unexpected close programming errors are not silently swallowed',
    () async {
      final problem = StateError('Synthetic invalid sink state');
      final raw = _SocketFixture()..closeFailure = problem;
      final adapter = NativeSshSocket(raw);
      final originalFailure = expectLater(adapter.done, throwsA(same(problem)));
      await expectLater(adapter.close(), throwsA(same(problem)));
      await originalFailure;
    },
  );

  test(
    'SSHClient remote EOF consumes duplicate close-time writer failure',
    () async {
      final raw = _SocketFixture()..closeFailure = brokenPipe;
      final client = SSHClient(
        NativeSshSocket(raw),
        username: 'synthetic-user',
        handshakeTimeout: const Duration(seconds: 1),
      );
      final authFailure = expectLater(
        client.authenticated,
        throwsA(isA<SSHAuthAbortError>()),
      );
      // The library marks transport.done complete and invokes adapter.close()
      // from an unawaited remote-EOF callback. A second propagation of the
      // close/done error would be caught as an unhandled error by flutter_test.
      await raw.incoming.close();
      await client.done;
      await authFailure;
      await Future<void>.delayed(Duration.zero);
      expect(raw.closeCalls, 1);
      expect(raw.destroys, 1);
    },
  );
}
