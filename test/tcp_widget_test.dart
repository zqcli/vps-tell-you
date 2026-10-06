import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/connections/tcp_test.dart';
import 'package:vps_tell_you/connections/tcp_test_page.dart';
import 'package:vps_tell_you/core/app_theme.dart';

class _SocketSpy implements Socket {
  bool destroyed = false;
  @override
  InternetAddress get remoteAddress => InternetAddress.loopbackIPv4;
  @override
  void destroy() => destroyed = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    TcpTestController controller, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => TcpTestPage(
                    initialHost: '127.0.0.1',
                    controller: controller,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pump();
  }

  testWidgets(
    'port validation, cancelled attempt, changed target cannot show late result',
    (tester) async {
      final pending = <Completer<Socket>>[];
      var cancelled = 0;
      final controller = TcpTestController(
        connector: (_, _) async {
          final c = Completer<Socket>();
          pending.add(c);
          return ConnectionTask.fromSocket(c.future, () => cancelled++);
        },
      );
      addTearDown(controller.dispose);
      await mount(tester, controller);
      await tester.enterText(find.byKey(const Key('tcp-port')), '65536');
      await tap(tester, '开始测试');
      expect(find.text('端口需为 1–65535'), findsOneWidget);
      expect(pending, isEmpty);
      await tester.enterText(find.byKey(const Key('tcp-port')), '22');
      await tap(tester, '开始测试');
      expect(controller.running, isTrue);
      await tap(tester, '取消测试');
      expect(controller.result!.outcome, TcpOutcome.cancelled);
      expect(cancelled, 1);
      await tester.enterText(find.byKey(const Key('tcp-host')), '::1');
      await tester.pump();
      expect(controller.result, isNull);
      final late = _SocketSpy();
      pending.single.complete(late);
      await tester.pump();
      expect(late.destroyed, isTrue);
      expect(find.text('TCP 连接成功'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'leaving and background cancel without later success or overflow',
    (tester) async {
      final pending = <Completer<Socket>>[];
      var cancelled = 0;
      final controller = TcpTestController(
        connector: (_, _) async {
          final c = Completer<Socket>();
          pending.add(c);
          return ConnectionTask.fromSocket(c.future, () => cancelled++);
        },
      );
      addTearDown(controller.dispose);
      await mount(tester, controller, scale: 2);
      await tap(tester, '开始测试');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(controller.result!.outcome, TcpOutcome.cancelled);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tap(tester, '开始测试');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(controller.running, isFalse);
      expect(cancelled, 2);
      for (final c in pending) {
        c.complete(_SocketSpy());
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'successful observation shows source and finished time at double text',
    (tester) async {
      final controller = TcpTestController(
        connector: (_, _) async =>
            ConnectionTask.fromSocket(Future.value(_SocketSpy()), () {}),
        clock: () => DateTime.utc(2026, 10, 6),
      );
      addTearDown(controller.dispose);
      await mount(tester, controller, scale: 2);
      await tap(tester, '开始测试');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('来源：本机 TCP 连接测试'));
      await tester.pumpAndSettle();
      expect(find.text('TCP 连接成功'), findsOneWidget);
      expect(find.textContaining('结束时间：2026-10-06'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
