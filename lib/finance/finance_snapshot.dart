import '../core/value_types.dart';
import '../servers/ledger_controller.dart';
import '../servers/server_record.dart';
import 'finance_math.dart';
import 'finance_models.dart';

/// One slice of the monthly distribution (a provider or a group).
class FinanceSlice {
  const FinanceSlice(this.key, this.servers, this.total);
  final String key;
  final List<ServerRecord> servers;
  final FinanceTotal total;
}

/// Every figure the Costs pages show for one scope, computed lazily and at
/// most once per ledger revision. The controller also notifies for search
/// text, reminders, the busy flag and the provider directory; none of those
/// change a figure, so the pages rebuild from this cache instead of
/// re-aggregating thousands of periods and payments.
class FinanceScope {
  FinanceScope._(this._data, this.groupId);

  /// The cached scope of [groupId] (null = all groups, '' = ungrouped).
  static FinanceScope of(LedgerController c, String? groupId) {
    final cached = _caches[c];
    final today = c.today;
    final data =
        cached != null &&
            identical(cached.records, c.records) &&
            identical(cached.periods, c.periods) &&
            identical(cached.payments, c.payments) &&
            identical(cached.fx, c.fx) &&
            cached.today == today
        ? cached
        : _caches[c] = _LedgerData(c, today);
    return data.scopes[groupId] ??= FinanceScope._(data, groupId);
  }

  static final _caches = Expando<_LedgerData>('FinanceScope');

  final _LedgerData _data;
  final String? groupId;
  FxSettings get _fx => _data.fx;
  LedgerDate get _today => _data.today;

  /// Active servers of the scope.
  late final List<ServerRecord> records = [
    for (final s in _data.records)
      if (!s.archived && (groupId == null || (s.groupId ?? '') == groupId)) s,
  ];

  /// [records] of one provider group key, or all of them.
  List<ServerRecord> servers({String? vendor}) => vendor == null
      ? records
      : [
          for (final s in records)
            if (_data.providerKey(s) == vendor) s,
        ];

  /// What is left of [s]'s paid terms (not applicable for metered billing).
  FinanceAmount remaining(ServerRecord s) =>
      _remaining[s.id] ??= s.billing == BillingKind.metered
      ? FinanceAmount.notApplicable(s.currency)
      : serverValuation(s, _data.periodsOf(s.id), _today)?.amount ??
            FinanceAmount.unknown(s.currency);
  late final _remaining = <String, FinanceAmount>{};

  bool isIncomplete(ServerRecord s) =>
      s.billing == BillingKind.unknown ||
      s.amountMinor == null ||
      (s.billing == BillingKind.prepaid &&
          (s.dueDate == null ||
              s.dueDate!.compareTo(_today) <= 0 ||
              _data.periodsOf(s.id).isEmpty));

  late final List<ServerRecord> incomplete = records
      .where(isIncomplete)
      .toList(growable: false);

  late final FinanceTotal monthly = _monthlyOf(records);

  late final FinanceTotal value = aggregateAmounts(records.map(remaining), _fx);

  /// Renewals due within the next 30 days.
  late final List<RenewalEvent> events = renewalEvents(
    records,
    _today,
    _today.addDays(30),
  );
  late final FinanceTotal renewals = aggregateAmounts(
    events.map((e) => e.amount),
    _fx,
  );

  late final List<PaymentRecord> payments = recentPayments(
    _data.payments,
    _today,
    records: _data.records,
    groupId: groupId,
  );
  late final FinanceTotal paid = aggregateAmounts(
    payments.map((p) => FinanceAmount.money(p.amount)),
    _fx,
  );

  late final List<ForecastMonth> forecast = sixMonthForecast(
    records,
    _today,
    _fx,
  );

  /// Monthly distribution, largest first.
  List<FinanceSlice> slices({required bool byVendor}) =>
      byVendor ? _byVendor : _byGroup;
  late final _byVendor = _slicesBy(_data.providerKey);
  late final _byGroup = _slicesBy((s) => s.groupId ?? '');

  List<FinanceSlice> _slicesBy(String Function(ServerRecord) keyOf) {
    final groups = <String, List<ServerRecord>>{};
    for (final s in records) {
      (groups[keyOf(s)] ??= []).add(s);
    }
    return [
      for (final e in groups.entries)
        FinanceSlice(e.key, e.value, _monthlyOf(e.value)),
    ]..sort((a, b) => b.total.convertedMinor.compareTo(a.total.convertedMinor));
  }

  FinanceTotal _monthlyOf(Iterable<ServerRecord> servers) =>
      aggregateAmounts(servers.map((s) => monthlyAmount(s, _today)), _fx);
}

/// The ledger inputs one cache generation was computed from.
class _LedgerData {
  _LedgerData(LedgerController c, this.today)
    : records = c.records,
      periods = c.periods,
      payments = c.payments,
      fx = c.fx,
      providerKey = c.providerGroupKey;

  final List<ServerRecord> records;
  final List<ServicePeriod> periods;
  final List<PaymentRecord> payments;
  final FxSettings fx;
  final LedgerDate today;
  final String Function(ServerRecord) providerKey;
  final scopes = <String?, FinanceScope>{};

  late final Map<String, List<ServicePeriod>> _periodsByServer = () {
    final map = <String, List<ServicePeriod>>{};
    for (final p in periods) {
      (map[p.serverId] ??= []).add(p);
    }
    return map;
  }();

  List<ServicePeriod> periodsOf(String serverId) =>
      _periodsByServer[serverId] ?? const [];
}
