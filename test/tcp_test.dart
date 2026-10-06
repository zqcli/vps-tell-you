import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/connections/tcp_test.dart';

class _SocketSpy implements Socket {
  bool destroyed = false;
  int writes = 0;
  @override
  InternetAddress get remoteAddress => InternetAddress.loopbackIPv4;
  @override
  void destroy() => destroyed = true;
  @override
  void add(List<int> data) => writes++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('TCP targets validate ports and normalize IPv4, IPv6, domain', () {
    expect(TcpTarget(host: ' 127.0.0.1 ', port: 1).label, '127.0.0.1:1');
    expect(TcpTarget(host: '[::1]', port: 65535).label, '[::1]:65535');
    expect(TcpTarget(host: 'EXAMPLE.test', port: 22).host, 'example.test');
    for (final host in [
      '',
      'https://example.test',
      'host:22',
      '[example.test]',
      'host/path',
      'user@host',
    ]) {
      expect(() => TcpTarget(host: host, port: 22), throwsArgumentError);
    }
    for (final port in [-1, 0, 65536]) {
      expect(
        () => TcpTarget(host: '127.0.0.1', port: port),
        throwsArgumentError,
      );
    }
  });

  for (final address in [
    InternetAddress.loopbackIPv4,
    InternetAddress.loopbackIPv6,
  ]) {
    test(
      'native TCP connects on ${address.address} without application bytes',
      () async {
        final server = await ServerSocket.bind(address, 0);
        final bytes = <int>[];
        final closed = Completer<void>();
        final subscription = server.listen((socket) {
          socket.listen(
            bytes.addAll,
            onDone: () {
              socket.destroy();
              closed.complete();
            },
          );
        });
        final now = DateTime.utc(2026, 10, 6);
        final controller = TcpTestController(clock: () => now);
        try {
          await controller.test(
            TcpTarget(host: address.address, port: server.port),
          );
          await closed.future.timeout(const Duration(seconds: 2));
          expect(controller.result!.outcome, TcpOutcome.connected);
          expect(controller.result!.remoteAddress, address.address);
          expect(controller.result!.source, '本机 TCP 连接测试');
          expect(controller.result!.finishedAt, now);
          expect(controller.running, isFalse);
          expect(bytes, isEmpty);
        } finally {
          controller.dispose();
          await subscription.cancel();
          await server.close();
        }
      },
    );
  }

  test(
    'native loopback refused connection is reported without raw OS errors',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close();
      final controller = TcpTestController();
      addTearDown(controller.dispose);
      await controller.test(TcpTarget(host: '127.0.0.1', port: port));
      expect(controller.result!.outcome, TcpOutcome.refused);
      expect(controller.result!.label, '连接被拒绝');
    },
  );

  test(
    'bounded timeout cancels pending task and destroys a late socket',
    () async {
      final pending = Completer<Socket>();
      var cancellations = 0;
      final controller = TcpTestController(
        timeout: const Duration(milliseconds: 10),
        connector: (_, _) async =>
            ConnectionTask.fromSocket(pending.future, () => cancellations++),
      );
      addTearDown(controller.dispose);
      await controller.test(TcpTarget(host: '127.0.0.1', port: 22));
      expect(controller.result!.outcome, TcpOutcome.timedOut);
      expect(cancellations, 1);
      final late = _SocketSpy();
      pending.complete(late);
      await Future<void>.delayed(Duration.zero);
      expect(late.destroyed, isTrue);
      expect(late.writes, 0);
      expect(controller.result!.outcome, TcpOutcome.timedOut);
    },
  );

  test('cancel before connector setup cancels the late task and consumes its error', () async {
    final setup = Completer<ConnectionTask<Socket>>();
    final pending = Completer<Socket>();
    var cancellations = 0;
    final controller = TcpTestController(connector: (_, _) => setup.future);
    addTearDown(controller.dispose);
    final done = controller.test(TcpTarget(host: '127.0.0.1', port: 22));
    controller.cancel();
    await done;
    expect(controller.result!.outcome, TcpOutcome.cancelled);
    setup.complete(
      ConnectionTask.fromSocket(pending.future, () {
        cancellations++;
        pending.completeError(const SocketException('synthetic cancellation'));
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(cancellations, 1);
    expect(controller.result!.outcome, TcpOutcome.cancelled);
  });

  test(
    'replacement target result cannot be overwritten by old completion',
    () async {
      final first = Completer<Socket>(), second = Completer<Socket>();
      final controller = TcpTestController(
        connector: (_, port) async => ConnectionTask.fromSocket(
          port == 1 ? first.future : second.future,
          () {},
        ),
      );
      addTearDown(controller.dispose);
      final old = controller.test(TcpTarget(host: '127.0.0.1', port: 1));
      final current = controller.test(TcpTarget(host: '127.0.0.1', port: 2));
      final secondSocket = _SocketSpy();
      second.complete(secondSocket);
      await current;
      final result = controller.result;
      final firstSocket = _SocketSpy();
      first.complete(firstSocket);
      await old;
      await Future<void>.delayed(Duration.zero);
      expect(controller.result, same(result));
      expect(controller.result!.target.port, 2);
      expect(firstSocket.destroyed, isTrue);
      expect(secondSocket.destroyed, isTrue);
    },
  );

  test(
    'target edit clears old result and late setup after disposal is closed',
    () async {
      final setup = Completer<ConnectionTask<Socket>>();
      final socket = _SocketSpy();
      var cancellations = 0;
      final controller = TcpTestController(connector: (_, _) => setup.future);
      var notifications = 0;
      controller.addListener(() => notifications++);
      final done = controller.test(TcpTarget(host: '127.0.0.1', port: 22));
      controller.clearTarget();
      expect(controller.result, isNull);
      expect(controller.target, isNull);
      final beforeDispose = notifications;
      controller.dispose();
      setup.complete(
        ConnectionTask.fromSocket(Future.value(socket), () => cancellations++),
      );
      await done;
      await Future<void>.delayed(Duration.zero);
      expect(socket.destroyed, isTrue);
      expect(cancellations, 1);
      expect(notifications, beforeDispose);
    },
  );

  test('connector errors are sanitized and a later test can succeed', () async {
    var calls = 0;
    final controller = TcpTestController(
      connector: (_, _) async {
        if (calls++ == 0) {
          throw const SocketException('SYNTHETIC_PRIVATE_RAW_ERROR');
        }
        return ConnectionTask.fromSocket(Future.value(_SocketSpy()), () {});
      },
    );
    addTearDown(controller.dispose);
    await controller.test(TcpTarget(host: '127.0.0.1', port: 22));
    expect(controller.result!.outcome, TcpOutcome.failed);
    expect(controller.result!.label, isNot(contains('SYNTHETIC')));
    await controller.test(TcpTarget(host: '127.0.0.1', port: 22));
    expect(controller.result!.outcome, TcpOutcome.connected);
  });
}
