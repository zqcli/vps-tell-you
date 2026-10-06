import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/finance/png_share.dart';
import 'package:vps_tell_you/settings/reminder_planner.dart';
import 'package:vps_tell_you/settings/reminder_rule.dart';

class _TemporaryPaths extends PathProviderPlatform {
  _TemporaryPaths(this.root);
  final String root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tz_data.initializeTimeZones);

  ReminderPlan plan({
    required LedgerDate due,
    String zone = 'Etc/UTC',
    int minutes = 540,
    List<int> leadDays = const [0],
    DateTime? now,
  }) => planReminders(
    inputs: [
      ReminderInput(
        rule: ReminderRule(
          id: ReminderRule.maxId,
          serverId: 'independent-review',
          leadDays: leadDays,
          minuteOfDay: minutes,
        ),
        dueDate: due,
      ),
    ],
    now: now ?? DateTime.utc(due.year, 1, 1).subtract(const Duration(days: 1)),
    location: tz.getLocation(zone),
    capacity: 64,
  );

  test('review: boundary ledger dates cannot leak year-zero notifications', () {
    final earliest = plan(
      due: const LedgerDate(1, 1, 1),
      leadDays: ReminderRule.allowedLeadDays,
    ).selected;
    expect(earliest, hasLength(1));
    expect(earliest.single.at.toUtc(), DateTime.utc(1, 1, 1, 9));
    final latest = plan(due: const LedgerDate(9999, 12, 31)).selected.single;
    expect(latest.at.toUtc(), DateTime.utc(9999, 12, 31, 9));
    expect(latest.notificationId, inInclusiveRange(1, 0x7fffffff));
  });

  test('review: now is an instant independent of its presentation zone', () {
    final utcNow = DateTime.utc(2026, 4, 19, 20);
    final nyNow = tz.TZDateTime.from(
      utcNow,
      tz.getLocation('America/New_York'),
    );
    final utc = plan(
      due: const LedgerDate(2026, 4, 20),
      zone: 'Asia/Kathmandu',
      now: utcNow,
    ).selected.single;
    final ny = plan(
      due: const LedgerDate(2026, 4, 20),
      zone: 'Asia/Kathmandu',
      now: nyNow,
    ).selected.single;
    expect(utc.at, ny.at);
    expect(utc.at.toUtc(), DateTime.utc(2026, 4, 20, 3, 15));
  });

  test(
    'review: midnight gap remains on its civil day, and folds stay single',
    () {
      final gap = plan(
        due: const LedgerDate(2026, 9, 6),
        zone: 'America/Santiago',
        minutes: 30,
      ).selected.single;
      expect(gap.at.hour, 1);
      expect(gap.at.minute, 30);
      expect(gap.at.day, 6);
      final fold = plan(
        due: const LedgerDate(2026, 4, 5),
        zone: 'Australia/Lord_Howe',
        minutes: 105,
      ).selected.single;
      expect(fold.at.hour, 1);
      expect(fold.at.minute, 45);
      expect(
        plan(
          due: const LedgerDate(2026, 4, 5),
          zone: 'Australia/Lord_Howe',
          minutes: 105,
          now: fold.at.add(const Duration(microseconds: 1)),
        ).selected,
        isEmpty,
      );
    },
  );

  test(
    'review: a short cross-midnight gap advances once with truthful due date',
    () {
      final zone = tz.getLocation('America/Nuuk');
      final normalized = tz.TZDateTime(zone, 2026, 3, 28, 23, 30);
      expect(normalized.toUtc(), DateTime.utc(2026, 3, 29, 1, 30));
      expect(tz.TZDateTime(zone, 2026, 3, 28, 12).day, 28);
      final result = plan(
        due: const LedgerDate(2026, 3, 28),
        zone: 'America/Nuuk',
        minutes: 23 * 60 + 30,
      ).selected.single;
      expect(result.at, normalized);
      expect(result.body, contains('2026-03-28'));
      expect(result.body, isNot(contains('今天到期')));
      expect(
        plan(
          due: const LedgerDate(2026, 3, 28),
          zone: 'America/Nuuk',
          minutes: 23 * 60 + 30,
          now: normalized,
        ).selected,
        isEmpty,
      );
    },
  );

  test('review: all minutes of a skipped date stay absent', () {
    for (var minute = 0; minute < 1440; minute++) {
      expect(
        plan(
          due: const LedgerDate(1993, 8, 21),
          zone: 'Pacific/Kwajalein',
          minutes: minute,
        ).selected,
        isEmpty,
        reason: 'minute $minute',
      );
    }
  });

  test('review: queue partition and ordering survive reversed mixed input', () {
    final inputs = [
      for (var id = 1; id <= 120; id++)
        ReminderInput(
          rule: ReminderRule(
            id: id,
            serverId: 'server-$id',
            minuteOfDay: id % 2 == 0 ? 1439 : 1,
            leadDays: ReminderRule.allowedLeadDays,
            usagePlan: UsagePlan.values[id % UsagePlan.values.length],
          ),
          dueDate: LedgerDate(2027, 1, 1).addDays(id % 12),
        ),
    ];
    ReminderPlan run(Iterable<ReminderInput> rows, int capacity) =>
        planReminders(
          inputs: rows,
          now: DateTime.utc(2026),
          location: tz.getLocation('Pacific/Auckland'),
          capacity: capacity,
        );
    final all = run(inputs, 1000).selected;
    final limited = run(inputs.reversed, 64);
    expect(all, hasLength(720));
    final partition = [...limited.selected, ...limited.uncovered];
    expect(
      partition.map((r) => r.notificationId),
      all.map((r) => r.notificationId),
    );
    expect(partition.map((r) => r.notificationId).toSet(), hasLength(720));
    for (var i = 1; i < partition.length; i++) {
      expect(partition[i].at.isBefore(partition[i - 1].at), isFalse);
    }
  });

  group('review: share plugin boundary', () {
    const asOf = LedgerDate(2026, 4, 20);
    Uint8List png() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
    );
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test(
      'synchronous failure releases guard; unavailable allows another call',
      () async {
        var calls = 0;
        final share = MobilePngShare(
          invoke: (_) {
            if (++calls == 1) throw StateError('/fixture/private/path');
            return Future.value(
              const ShareResult('ignored', ShareResultStatus.unavailable),
            );
          },
        );
        expect(await share.share(png(), asOf), PngShareOutcome.failed);
        expect(await share.share(png(), asOf), PngShareOutcome.unknown);
        expect(await share.share(png(), asOf), PngShareOutcome.unknown);
        expect(calls, 3);
      },
    );

    test('same-instance reentrancy cannot open a second sheet', () async {
      late MobilePngShare share;
      late Future<PngShareOutcome> nested;
      var calls = 0;
      share = MobilePngShare(
        invoke: (_) {
          calls++;
          nested = share.share(png(), asOf);
          return Future.value(
            const ShareResult('', ShareResultStatus.dismissed),
          );
        },
      );
      expect(await share.share(png(), asOf), PngShareOutcome.dismissed);
      expect(await nested, PngShareOutcome.busy);
      expect(calls, 1);
    });

    test(
      'real Dart plugin mapping writes exact PNG and sends no ancillary data',
      () async {
        const channel = MethodChannel('dev.fluttercommunity.plus/share');
        final root = await Directory.systemTemp.createTemp(
          'stage6-review-share-',
        );
        final originalPaths = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _TemporaryPaths(root.path);
        Map<dynamic, dynamic>? nativeMap;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'share');
          nativeMap = call.arguments as Map<dynamic, dynamic>;
          return 'dev.fluttercommunity.plus/share/unavailable';
        });
        try {
          final share = MobilePngShare();
          expect(await share.share(png(), asOf), PngShareOutcome.unknown);
          expect(nativeMap!.keys.toSet(), {'paths', 'mimeTypes'});
          expect(nativeMap!['mimeTypes'], ['image/png']);
          final file = File((nativeMap!['paths'] as List).single as String);
          expect(
            file.uri.pathSegments.last,
            'vps-tell-you-value-2026-04-20.png',
          );
          expect(file.path.startsWith('${root.path}/'), isTrue);
          expect(await file.readAsBytes(), png());
        } finally {
          messenger.setMockMethodCallHandler(channel, null);
          PathProviderPlatform.instance = originalPaths;
          await root.delete(recursive: true);
        }
      },
    );
  });
}
