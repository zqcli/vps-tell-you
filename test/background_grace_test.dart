import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/core/background_grace.dart';

import 'support/fake_background_native.dart';

class _Session implements BackgroundSession {
  _Session({this.live = true});
  bool live;
  final ends = <bool>[];
  @override
  bool get isLive => live;
  @override
  void endInBackground({required bool graceExpired}) {
    ends.add(graceExpired);
    live = false;
  }
}

void main() {
  late FakeBackgroundNative native;
  late Duration now;

  BackgroundGrace make({bool? ios = true}) =>
      BackgroundGrace(native: ios, clock: () => now);

  void lifecycle(Iterable<AppLifecycleState> states) {
    for (final state in states) {
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(state);
    }
  }

  void background() => lifecycle(const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]);
  void foreground() => lifecycle(const [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]);

  setUp(() {
    native = FakeBackgroundNative()..install();
    now = Duration.zero;
  });

  group('iOS background task', () {
    testWidgets('begins one named task and ends it when the app returns', (
      tester,
    ) async {
      final grace = make();
      final session = _Session();
      grace.register(session);
      addTearDown(() => grace.unregister(session));
      background();
      await tester.pump();
      expect(native.begins, 1);
      expect(native.calls.first.arguments, {'name': 'ssh-session'});
      expect(grace.holdsTask, isTrue);
      expect(grace.timerArmed, isTrue);
      await tester.pump(const Duration(seconds: 10));
      foreground();
      await tester.pump();
      // Seamless: nothing closed, nothing reconnected, the task is returned.
      expect(session.ends, isEmpty);
      expect(session.live, isTrue);
      expect(native.ends, 1);
      expect(native.live, isEmpty);
      expect(grace.holdsTask, isFalse);
      expect(grace.timerArmed, isFalse);
      // A second trip begins a fresh task.
      background();
      await tester.pump();
      expect(native.begins, 2);
      foreground();
      await tester.pump();
    });

    testWidgets('inactive alone (Control Center, app switcher) does nothing', (
      tester,
    ) async {
      final grace = make();
      final session = _Session();
      grace.register(session);
      addTearDown(() => grace.unregister(session));
      lifecycle(const [AppLifecycleState.inactive]);
      await tester.pump();
      expect(native.begins, 0);
      lifecycle(const [AppLifecycleState.resumed]);
    });

    testWidgets('the native expiring call closes sessions and is answered', (
      tester,
    ) async {
      final grace = make();
      final a = _Session(), b = _Session();
      grace
        ..register(a)
        ..register(b);
      addTearDown(() {
        grace
          ..unregister(a)
          ..unregister(b);
      });
      background();
      await tester.pump();
      expect(native.begins, 1, reason: 'two sessions share one task');
      final token = native.live.single;
      expect(await native.expire(token), isTrue);
      expect(a.ends, [true]);
      expect(b.ends, [true]);
      // The native side ends the task itself after the answer.
      expect(native.live, isEmpty);
      expect(native.ends, 0);
      expect(grace.timerArmed, isFalse);
      expect(grace.holdsTask, isFalse);
      foreground();
      await tester.pump();
      expect(a.ends, [true], reason: 'closed once only');
      expect(native.ends, 0);
    });

    testWidgets('the safety timer closes a few seconds before the budget', (
      tester,
    ) async {
      native.remaining = 30;
      final grace = make();
      final session = _Session();
      grace.register(session);
      addTearDown(() => grace.unregister(session));
      background();
      await tester.pump();
      await tester.pump(const Duration(seconds: 26));
      expect(session.ends, isEmpty);
      await tester.pump(const Duration(seconds: 2));
      expect(session.ends, [true]);
      // Dart closed first, so it gives the task back itself.
      expect(native.ends, 1);
      expect(native.live, isEmpty);
    });

    testWidgets('a short budget is respected', (tester) async {
      native.remaining = 4;
      final grace = make();
      final session = _Session();
      grace.register(session);
      addTearDown(() => grace.unregister(session));
      background();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(session.ends, isEmpty);
      await tester.pump(const Duration(seconds: 1, milliseconds: 100));
      expect(session.ends, [true]);
    });

    testWidgets('sessions that are not live are ended immediately', (
      tester,
    ) async {
      final grace = make();
      final connecting = _Session(live: false);
      final live = _Session();
      grace
        ..register(connecting)
        ..register(live);
      addTearDown(() {
        grace
          ..unregister(connecting)
          ..unregister(live);
      });
      background();
      await tester.pump();
      expect(connecting.ends, [false]);
      expect(live.ends, isEmpty);
      foreground();
      await tester.pump();
    });

    testWidgets('no live session: no task is requested', (tester) async {
      final grace = make();
      final session = _Session(live: false);
      grace.register(session);
      addTearDown(() => grace.unregister(session));
      background();
      await tester.pump();
      expect(native.begins, 0);
      foreground();
    });

    testWidgets('returning while begin is in flight ends the task at once', (
      tester,
    ) async {
      native.holdBegin = Completer<void>();
      final grace = make();
      final session = _Session();
      grace.register(session);
      addTearDown(() => grace.unregister(session));
      background();
      await tester.pump();
      foreground();
      native.holdBegin!.complete();
      await tester.pump();
      await tester.pump();
      expect(native.live, isEmpty);
      expect(native.ends, 1);
      expect(grace.timerArmed, isFalse);
      expect(session.ends, isEmpty);
    });

    testWidgets('a refused task falls back to the fixed window', (
      tester,
    ) async {
      native.refuse = true;
      final grace = make();
      final session = _Session();
      grace.register(session);
      addTearDown(() => grace.unregister(session));
      background();
      await tester.pump();
      expect(grace.holdsTask, isFalse);
      await tester.pump(fixedBackgroundGrace - const Duration(seconds: 1));
      expect(session.ends, isEmpty);
      await tester.pump(const Duration(seconds: 2));
      expect(session.ends, [true]);
      expect(native.ends, 0);
    });

    testWidgets('a huge remaining time (still foreground) is not trusted', (
      tester,
    ) async {
      native.remaining = double.maxFinite;
      final grace = make();
      final session = _Session();
      grace.register(session);
      addTearDown(() => grace.unregister(session));
      background();
      await tester.pump();
      await tester.pump(const Duration(seconds: 28));
      expect(session.ends, [true]);
    });

    testWidgets('the task is given back early when the last session ends', (
      tester,
    ) async {
      final grace = make();
      final session = _Session();
      grace.register(session);
      background();
      await tester.pump();
      expect(grace.holdsTask, isTrue);
      session.live = false; // remote closed the shell
      grace.refresh();
      await tester.pump();
      expect(native.ends, 1);
      expect(grace.timerArmed, isFalse);
      grace.unregister(session);
      foreground();
    });

    testWidgets('unregistering the last session cancels everything', (
      tester,
    ) async {
      final grace = make();
      final session = _Session();
      grace.register(session);
      background();
      await tester.pump();
      grace.unregister(session);
      await tester.pump();
      expect(native.live, isEmpty);
      expect(grace.timerArmed, isFalse);
      expect(grace.inBackground, isFalse);
    });
  });

  group('other platforms', () {
    testWidgets('keep the session for the fixed window, no native calls', (
      tester,
    ) async {
      expect(fixedBackgroundGrace, const Duration(seconds: 30));
      final grace = make(ios: false);
      final session = _Session();
      grace.register(session);
      addTearDown(() => grace.unregister(session));
      background();
      await tester.pump();
      expect(grace.holdsTask, isFalse);
      await tester.pump(fixedBackgroundGrace - const Duration(seconds: 1));
      expect(session.ends, isEmpty);
      await tester.pump(const Duration(seconds: 2));
      expect(session.ends, [true]);
      expect(native.calls, isEmpty);
      foreground();
      await tester.pump();
      expect(session.ends, [true]);
    });

    testWidgets('returning inside the window keeps the session', (
      tester,
    ) async {
      final grace = make(ios: false);
      final session = _Session();
      grace.register(session);
      addTearDown(() => grace.unregister(session));
      background();
      await tester.pump(const Duration(seconds: 20));
      foreground();
      await tester.pump(const Duration(seconds: 60));
      expect(session.ends, isEmpty);
      expect(session.live, isTrue);
      expect(grace.timerArmed, isFalse);
    });

    testWidgets(
      'a process frozen past the window closes the session on return',
      (tester) async {
        final grace = make(ios: false);
        final session = _Session();
        grace.register(session);
        addTearDown(() => grace.unregister(session));
        background();
        // The timer never fires (process frozen) but the clock moved on.
        now += const Duration(minutes: 5);
        foreground();
        await tester.pump();
        expect(session.ends, [true]);
      },
    );

    testWidgets('the fixed window follows a fake clock on a normal return', (
      tester,
    ) async {
      final grace = make(ios: false);
      final session = _Session();
      grace.register(session);
      addTearDown(() => grace.unregister(session));
      background();
      now += const Duration(seconds: 10);
      foreground();
      await tester.pump();
      expect(session.ends, isEmpty);
    });

    testWidgets('the platform decides when native is not forced', (
      tester,
    ) async {
      final grace = BackgroundGrace(clock: () => now);
      final session = _Session();
      grace.register(session);
      addTearDown(() => grace.unregister(session));
      background();
      await tester.pump();
      expect(native.begins, 1);
      foreground();
      await tester.pump();
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Android never touches the channel', (tester) async {
      final grace = BackgroundGrace(clock: () => now);
      final session = _Session();
      grace.register(session);
      addTearDown(() => grace.unregister(session));
      background();
      await tester.pump(fixedBackgroundGrace);
      expect(native.calls, isEmpty);
      expect(session.ends, [true]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  test('the channel name is the documented one', () {
    expect(backgroundChannelName, 'vps_tell_you/background');
    expect(
      const MethodChannel(backgroundChannelName).name,
      FakeBackgroundNative.channel.name,
    );
  });
}
