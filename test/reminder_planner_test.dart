import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/settings/reminder_planner.dart';
import 'package:vps_tell_you/settings/reminder_rule.dart';

void main() {
  setUpAll(tz_data.initializeTimeZones);

  ReminderRule rule({
    int id = 1,
    String serverId = 'local-1',
    Iterable<int> days = const [7, 3, 1],
    int minutes = 540,
    bool enabled = true,
    UsagePlan plan = UsagePlan.continueUsing,
  }) => ReminderRule(
    id: id,
    serverId: serverId,
    leadDays: days,
    minuteOfDay: minutes,
    enabled: enabled,
    usagePlan: plan,
  );

  ReminderPlan single(
    ReminderRule rule,
    LedgerDate? due, {
    String zone = 'Etc/UTC',
    DateTime? now,
    int capacity = 64,
  }) => planReminders(
    inputs: [ReminderInput(rule: rule, dueDate: due)],
    now: now ?? DateTime.utc(2026),
    location: tz.getLocation(zone),
    capacity: capacity,
  );

  test('rule defaults are per-server, normalized and immutable', () {
    final offsets = [1, 7, 1, 3];
    final value = rule(days: offsets);
    offsets.clear();
    expect(value.leadDays, [7, 3, 1]);
    expect(value.enabled, isTrue);
    expect(value.minuteOfDay, 540);
    expect(value.usagePlan, UsagePlan.continueUsing);
    expect(() => value.leadDays.add(0), throwsUnsupportedError);
  });

  test('rejects malformed rules without accepting normalized bad values', () {
    for (final id in [0, -1, ReminderRule.maxId + 1]) {
      expect(() => rule(id: id), throwsArgumentError);
    }
    expect(() => rule(serverId: ''), throwsArgumentError);
    for (final minutes in [-1, 1440]) {
      expect(() => rule(minutes: minutes), throwsArgumentError);
    }
    for (final day in [-1, 2, 31]) {
      expect(() => rule(days: [day]), throwsArgumentError);
      expect(() => rule().notificationIdFor(day), throwsArgumentError);
    }
  });

  test('persistent IDs have fixed slots and remain signed 32-bit safe', () {
    final original = rule(days: [7, 1]);
    final edited = rule(days: [30, 1], minutes: 600);
    expect(original.notificationIdFor(1), edited.notificationIdFor(1));
    final all = <int>{};
    for (var id = 1; id < 100; id++) {
      final ids = rule(id: id).notificationIds;
      expect(ids.toSet().length, 6);
      expect(ids.any(all.contains), isFalse);
      all.addAll(ids);
    }
    expect(rule(id: ReminderRule.maxId).notificationIds.last, 2147483645);
  });

  test('unknown, nonprepaid, archived, demo, disabled and empty are inert', () {
    final due = LedgerDate(2026, 4, 20);
    final plan = planReminders(
      inputs: [
        ReminderInput(rule: rule(id: 1, serverId: 'unknown'), dueDate: null),
        ReminderInput(
          rule: rule(id: 2, serverId: 'metered'),
          dueDate: due,
          isPrepaid: false,
        ),
        ReminderInput(
          rule: rule(id: 3, serverId: 'archived'),
          dueDate: due,
          archived: true,
        ),
        ReminderInput(
          rule: rule(id: 4, serverId: 'demo'),
          dueDate: due,
          isDemo: true,
        ),
        ReminderInput(
          rule: rule(id: 5, serverId: 'off', enabled: false),
          dueDate: due,
        ),
        ReminderInput(
          rule: rule(id: 6, serverId: 'empty', days: []),
          dueDate: due,
        ),
      ],
      now: DateTime.utc(2026),
      location: tz.UTC,
      capacity: 64,
    );
    expect(plan.selected, isEmpty);
    expect(plan.uncovered, isEmpty);
  });

  test('stop-at-expiry retains reminders with cancellation-check wording', () {
    for (final usagePlan in UsagePlan.values) {
      final result = single(
        rule(plan: usagePlan),
        const LedgerDate(2026, 4, 20),
      );
      expect(result.selected.length, 3);
      expect(result.selected.first.usagePlan, usagePlan);
      expect(result.selected.first.body, isNot(contains('local-1')));
      expect(result.selected.first.title, 'VPS 到期核对');
      expect(result.selected.first.body, contains('到期日为 2026-04-20'));
      expect(
        result.selected.first.body.contains('取消续费'),
        usagePlan == UsagePlan.stopAtExpiry,
      );
    }
  });

  test(
    'today schedules only strictly future instants and never catches up',
    () {
      final value = rule(days: [7, 1, 0]);
      const due = LedgerDate(2026, 4, 20);
      expect(
        single(
          value,
          due,
          now: DateTime.utc(2026, 4, 20, 8, 59),
        ).selected.single.leadDays,
        0,
      );
      for (final now in [
        DateTime.utc(2026, 4, 20, 9),
        DateTime.utc(2026, 4, 20, 10),
        DateTime.utc(2026, 4, 21),
      ]) {
        expect(single(value, due, now: now).selected, isEmpty);
      }
    },
  );

  test('calendar offsets preserve 09:00 across spring DST (23-hour day)', () {
    final result = single(
      rule(days: [1, 0]),
      const LedgerDate(2026, 3, 8),
      zone: 'America/New_York',
    ).selected;
    expect(result.map((r) => r.at.day), [7, 8]);
    expect(result.map((r) => r.at.hour), [9, 9]);
    expect(
      result.last.at.difference(result.first.at),
      const Duration(hours: 23),
    );
  });

  test('calendar offsets preserve 09:00 across autumn DST (25-hour day)', () {
    final result = single(
      rule(days: [1, 0]),
      const LedgerDate(2026, 11, 1),
      zone: 'America/New_York',
    ).selected;
    expect(result.map((r) => r.at.hour), [9, 9]);
    expect(
      result.last.at.difference(result.first.at),
      const Duration(hours: 25),
    );
  });

  test(
    'nonexistent wall time moves across gap once, including 30-minute DST',
    () {
      final ny = single(
        rule(days: [0], minutes: 150),
        const LedgerDate(2026, 3, 8),
        zone: 'America/New_York',
      ).selected.single;
      expect(ny.at.toUtc(), DateTime.utc(2026, 3, 8, 7, 30));
      expect(ny.at.hour, 3);
      final lordHowe = single(
        rule(days: [0], minutes: 135),
        const LedgerDate(2026, 10, 4),
        zone: 'Australia/Lord_Howe',
      ).selected.single;
      expect(lordHowe.at.hour, 2);
      expect(lordHowe.at.minute, 45);
    },
  );

  test('DST fold uses one canonical occurrence with no second catch-up', () {
    final value = rule(days: [0], minutes: 90);
    const due = LedgerDate(2026, 11, 1);
    final occurrence = single(
      value,
      due,
      zone: 'America/New_York',
    ).selected.single;
    expect(occurrence.at.toUtc(), DateTime.utc(2026, 11, 1, 5, 30));
    expect(
      single(
        value,
        due,
        zone: 'America/New_York',
        now: DateTime.utc(2026, 11, 1, 6),
      ).selected,
      isEmpty,
    );
    // timezone's canonical choice in a positive-offset fold is the later one.
    final berlin = single(
      rule(days: [0], minutes: 150),
      const LedgerDate(2026, 10, 25),
      zone: 'Europe/Berlin',
    ).selected.single;
    expect(berlin.at.toUtc(), DateTime.utc(2026, 10, 25, 1, 30));
  });

  test('entirely skipped date does not become a next-day notification', () {
    expect(
      single(
        rule(days: [0]),
        const LedgerDate(2011, 12, 30),
        zone: 'Pacific/Apia',
        now: DateTime.utc(2011),
      ).selected,
      isEmpty,
    );
  });

  test(
    'timezone/date edits recompute instants while retaining notification IDs',
    () {
      final value = rule(days: [0]);
      final utc = single(value, const LedgerDate(2026, 4, 20)).selected.single;
      final shanghai = single(
        value,
        const LedgerDate(2026, 4, 20),
        zone: 'Asia/Shanghai',
      ).selected.single;
      final edited = single(
        value,
        const LedgerDate(2026, 5, 20),
      ).selected.single;
      expect(shanghai.at.toUtc(), DateTime.utc(2026, 4, 20, 1));
      expect(utc.notificationId, shanghai.notificationId);
      expect(utc.notificationId, edited.notificationId);
    },
  );

  test('leap/month/year boundaries use calendar dates', () {
    final leap = single(
      rule(days: [1]),
      const LedgerDate(2024, 3, 1),
      now: DateTime.utc(2024),
    ).selected.single;
    expect(leap.at.toUtc(), DateTime.utc(2024, 2, 29, 9));
    final year = single(
      rule(days: [1]),
      const LedgerDate(2027, 1, 1),
    ).selected.single;
    expect(year.at.toUtc(), DateTime.utc(2026, 12, 31, 9));
  });

  test(
    'nearest-first capacity is global, deterministic and reports uncovered',
    () {
      final inputs = [
        for (var id = 70; id > 0; id--)
          ReminderInput(
            rule: rule(
              id: id,
              serverId: 'server-${id.toString().padLeft(2, '0')}',
              days: [0],
            ),
            dueDate: const LedgerDate(2026, 4, 20),
          ),
      ];
      ReminderPlan plan(Iterable<ReminderInput> values, int capacity) =>
          planReminders(
            inputs: values,
            now: DateTime.utc(2026),
            location: tz.UTC,
            capacity: capacity,
          );
      final result = plan(inputs, 64);
      expect(result.selected.length, 64);
      expect(result.uncovered.length, 6);
      expect(result.selected.first.serverId, 'server-01');
      expect(result.selected.last.serverId, 'server-64');
      expect(result.uncovered.first.serverId, 'server-65');
      expect(
        result.selected.map((r) => r.notificationId),
        plan(inputs.reversed, 64).selected.map((r) => r.notificationId),
      );
      expect(plan(inputs, 0).uncovered.length, 70);
      expect(plan(inputs, 100).uncovered, isEmpty);
      expect(() => result.selected.clear(), throwsUnsupportedError);
      expect(() => result.uncovered.clear(), throwsUnsupportedError);
      expect(() => plan(inputs, -1), throwsArgumentError);
    },
  );

  test(
    'closer instants beat ID ordering; no overflow is falsely scheduled',
    () {
      final result = planReminders(
        inputs: [
          ReminderInput(
            rule: rule(days: [0]),
            dueDate: const LedgerDate(2026, 5, 1),
          ),
          ReminderInput(
            rule: rule(id: 2, serverId: 'second', days: [0]),
            dueDate: const LedgerDate(2026, 4, 1),
          ),
        ],
        now: DateTime.utc(2026),
        location: tz.UTC,
        capacity: 1,
      );
      expect(result.selected.single.serverId, 'second');
      expect(result.uncovered.single.serverId, 'local-1');
    },
  );

  test(
    'invalid dates and duplicate identities fail before any native work',
    () {
      expect(
        () => single(rule(), const LedgerDate(2026, 2, 30)),
        throwsArgumentError,
      );
      for (final other in [rule(serverId: 'other'), rule(id: 2)]) {
        expect(
          () => planReminders(
            inputs: [
              ReminderInput(
                rule: rule(),
                dueDate: const LedgerDate(2026, 4, 20),
              ),
              ReminderInput(
                rule: other,
                dueDate: const LedgerDate(2026, 4, 20),
              ),
            ],
            now: DateTime.utc(2026),
            location: tz.UTC,
            capacity: 64,
          ),
          throwsArgumentError,
        );
      }
    },
  );
}
