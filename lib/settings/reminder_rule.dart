/// Local intent only; none of these values change the provider's billing.
enum UsagePlan { continueUsing, undecided, stopAtExpiry }

/// Immutable per-server rule. Persist [id] once and retain it across edits;
/// reusing deleted IDs could let an old notification target a different rule.
class ReminderRule {
  ReminderRule({
    required this.id,
    required this.serverId,
    this.enabled = true,
    Iterable<int> leadDays = const [7, 3, 1],
    this.minuteOfDay = 9 * 60,
    this.usagePlan = UsagePlan.continueUsing,
    this.revision = 0,
  }) : leadDays = List.unmodifiable(
         leadDays.toSet().toList()..sort((a, b) => b.compareTo(a)),
       ) {
    if (id < 1 || id > maxId) throw ArgumentError('Invalid reminder ID');
    if (serverId.isEmpty) throw ArgumentError('Missing server ID');
    if (revision < 0) throw ArgumentError('Invalid reminder revision');
    if (minuteOfDay < 0 || minuteOfDay >= 24 * 60) {
      throw ArgumentError('Invalid reminder time');
    }
    if (this.leadDays.any((days) => !allowedLeadDays.contains(days))) {
      throw ArgumentError('Invalid reminder lead days');
    }
  }

  static const allowedLeadDays = [30, 14, 7, 3, 1, 0];
  static const maxId = 0x7fffffff ~/ 8;
  final int id;
  final String serverId;
  final bool enabled;
  final List<int> leadDays;
  final int minuteOfDay;
  final UsagePlan usagePlan;
  final int revision;

  ReminderRule copyWith({
    bool? enabled,
    Iterable<int>? leadDays,
    int? minuteOfDay,
    UsagePlan? usagePlan,
    int? revision,
  }) => ReminderRule(
    id: id,
    serverId: serverId,
    enabled: enabled ?? this.enabled,
    leadDays: leadDays ?? this.leadDays,
    minuteOfDay: minuteOfDay ?? this.minuteOfDay,
    usagePlan: usagePlan ?? this.usagePlan,
    revision: revision ?? this.revision,
  );

  /// Six fixed slots, independent of due date, timezone or selected lead days.
  /// IDs remain positive signed 32-bit integers accepted by mobile plugins.
  int notificationIdFor(int leadDay) {
    final slot = allowedLeadDays.indexOf(leadDay);
    if (slot < 0) throw ArgumentError('Invalid reminder lead day');
    return id * 8 + slot;
  }

  List<int> get notificationIds => [
    for (final day in allowedLeadDays) notificationIdFor(day),
  ];
}
