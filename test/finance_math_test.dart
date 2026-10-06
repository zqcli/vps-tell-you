import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/finance/finance_math.dart';
import 'package:vps_tell_you/finance/finance_models.dart';
import 'package:vps_tell_you/servers/server_record.dart';

LedgerDate d(String date) => LedgerDate.tryParse(date)!;
ServerRecord server({
  String id = 's',
  int? minor = 3650,
  String currency = 'USD',
  BillingKind billing = BillingKind.prepaid,
  int cycle = 12,
  String? due = '2027-01-01',
  String? anchor,
  String? group,
  bool archived = false,
}) => ServerRecord(
  id: id,
  name: id,
  vendor: 'vendor',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  amountMinor: minor,
  currency: currency,
  billing: billing,
  cycleMonths: cycle,
  dueDate: due == null ? null : d(due),
  renewalAnchorDate: anchor == null ? null : d(anchor),
  groupId: group,
  archivedAt: archived ? DateTime.utc(2026, 12, 1) : null,
);
ServicePeriod period(String start, String end, {String id = 'p'}) =>
    ServicePeriod(id: id, serverId: 's', start: d(start), end: d(end));
PaymentRecord payment(
  String id,
  int amount,
  String date, {
  String? serverId = 's',
  bool voided = false,
}) => PaymentRecord(
  id: id,
  targetName: id,
  serverId: serverId,
  accountLabel: serverId == null ? 'account' : null,
  amount: Money('USD', amount),
  paidDate: d(date),
  createdAt: DateTime.utc(2026),
  voidedAt: voided ? DateTime.utc(2026) : null,
);

void main() {
  test('calendar anchors, actual year lengths and bounded period value', () {
    expect(d('2024-02-29').addMonths(12), d('2025-02-28'));
    expect(d('2024-01-31').addMonths(1), d('2024-02-29'));
    expect(d('2024-01-31').addMonths(2), d('2024-03-31'));
    for (final year in [2023, 2024]) {
      final p = period('$year-01-01', '${year + 1}-01-01');
      expect(p.days, year == 2024 ? 366 : 365);
      final end = valueOfPeriods(
        renewal: const Money('USD', 100),
        periods: [p],
        asOf: p.end,
      )!;
      expect(end.amount.minor, Rational.zero);
      expect(end.activeRemaining, 0);
      final before = valueOfPeriods(
        renewal: const Money('USD', 100),
        periods: [p],
        asOf: p.start.addDays(-2),
      )!;
      expect(before.amount.minor, Rational.of(100));
      expect(before.ratio, Rational.of(1));
    }
    expect(
      valueOfPeriods(
        renewal: const Money('USD', 100),
        periods: [],
        asOf: d('2026-01-01'),
      ),
      isNull,
    );
    expect(
      valueOfPeriods(
        renewal: const Money('USD', 100),
        periods: [
          period('2026-01-01', '2027-01-01'),
          period('2026-12-01', '2027-02-01'),
        ],
        asOf: d('2026-01-01'),
      ),
      isNull,
    );
  });

  test(
    'renewal-price value preserves the current and complete future periods',
    () {
      final current = period('2026-01-01', '2027-01-01');
      final asOf = d('2026-09-23');
      final first = valueOfPeriods(
        renewal: const Money('USD', 3650),
        periods: [current],
        asOf: asOf,
      )!;
      expect(first.remainingDays, 100);
      expect(first.amount.minor, Rational.of(1000));
      expect(formatRational(first.dailyMinor, digits: 4), '0.1000');
      final multiple = valueOfPeriods(
        renewal: const Money('USD', 3650),
        periods: [
          current,
          period('2027-01-01', '2028-01-01', id: 'future'),
        ],
        asOf: asOf,
      )!;
      expect(multiple.amount.minor, Rational.of(4650));
      expect(multiple.futurePeriods, 1);
      expect(multiple.periodCount, 2);
      expect(multiple.activePeriod, current);
      // Historical payments are deliberately not inputs into service valuation.
      final changed = valueOfPeriods(
        renewal: const Money('USD', 7300),
        periods: [current],
        asOf: asOf,
      )!;
      expect(changed.amount.minor, Rational.of(2000));
    },
  );

  test(
    'exact aggregation rounds once, preserving original currency and coverage',
    () {
      const fx = FxSettings(displayCurrency: 'USD');
      final today = d('2026-09-23');
      final tiny = monthlyAmount(server(minor: 1), today);
      final two = aggregateAmounts([tiny, tiny], fx);
      expect(two.originals['USD'], Rational.of(1, 6));
      expect(two.convertedMinor, Rational.of(1, 6));
      expect(two.formatted, '\$0.00');
      expect(aggregateAmounts(List.filled(12, tiny), fx).formatted, '\$0.01');
      expect(
        aggregateAmounts([
          FinanceAmount.money(const Money('USD', 10)),
          FinanceAmount.money(const Money('USD', 20)),
        ], fx).formatted,
        '\$0.30',
      );
      final mixed = aggregateAmounts([
        monthlyAmount(server(minor: 0), today),
        monthlyAmount(server(billing: BillingKind.unknown, minor: null), today),
        monthlyAmount(server(billing: BillingKind.metered, minor: 1200), today),
        monthlyAmount(server(currency: 'EUR'), today),
        monthlyAmount(server(due: '2026-09-23'), today),
        monthlyAmount(server(due: null), today),
      ], fx);
      expect(mixed.covered, 2);
      expect(mixed.total, 6);
      expect(mixed.unknown, 2);
      expect(mixed.notApplicable, 1);
      expect(mixed.missingFx, 1);
      expect(mixed.originals.keys, containsAll(['USD', 'EUR']));
      expect(mixed.formatted, '\$12.00');
      expect(
        serverValuation(server(billing: BillingKind.metered), [], today),
        isNull,
      );
    },
  );

  test('FX is exact, same currency needs no rate, and large products never overflow', () {
    final fx = FxSettings(
      displayCurrency: 'CNY',
      usdToCny: '7.12345678',
      eurToCny: '7.8',
      rateDate: d('2026-09-23'),
    );
    expect(fx.validate(), isNull);
    expect(
      fx.convert(Rational.of(100), 'USD'),
      Rational(BigInt.from(712345678), BigInt.from(1000000)),
    );
    expect(
      const FxSettings(displayCurrency: 'USD').convert(Rational.of(10), 'USD'),
      Rational.of(10),
    );
    expect(
      const FxSettings(displayCurrency: 'USD').convert(Rational.of(10), 'CNY'),
      isNull,
    );
    final huge = FxSettings(
      displayCurrency: 'CNY',
      usdToCny: '999999999.99999999',
      rateDate: d('2026-09-23'),
    );
    final product = huge.convert(Rational.of(Money.maxMinor), 'USD')!;
    expect(product.numerator, greaterThan(BigInt.from(9223372036854775807)));
    expect(formatRational(product), '9999999999989999900.00');
    expect(const FxSettings(usdToCny: '0').validate(), isNotNull);
    expect(const FxSettings(usdToCny: '7').validate(), isNotNull);
    expect(FxSettings.parseRate('1e2'), isNull);
    expect(Rational.of(1, 2).round(), BigInt.one);
    expect(Rational.of(-1, 2).round(), -BigInt.one);
    expect(Money('USD', -4).decimal, '-0.04');
    expect(formatMinor(BigInt.from(-4), currency: 'USD'), '\$-0.04');
  });

  test('30-day windows and six calendar buckets share exact inclusive/exclusive boundaries', () {
    final today = d('2026-12-15');
    final records = [
      server(id: 'today', due: '2026-12-15'),
      server(id: 'last', due: '2027-01-13'),
      server(id: 'excluded', due: '2027-01-14'),
      server(id: 'old', due: '2026-12-14'),
      server(id: 'sixEnd', due: '2027-06-01'),
      server(id: 'monthly', cycle: 1, due: '2027-01-31', anchor: '2027-01-31'),
    ];
    final soon = renewalEvents(records, today, today.addDays(30));
    expect(soon.map((e) => e.server.id), ['today', 'last']);
    final months = sixMonthForecast(
      records,
      today,
      const FxSettings(displayCurrency: 'USD'),
    );
    expect(months.map((m) => m.month.toString()), [
      '2026-12-01',
      '2027-01-01',
      '2027-02-01',
      '2027-03-01',
      '2027-04-01',
      '2027-05-01',
    ]);
    final flattened = months.expand((m) => m.events).toList();
    expect(
      flattened.any((e) => e.server.id == 'sixEnd' || e.server.id == 'old'),
      isFalse,
    );
    expect(
      flattened
          .where((e) => e.server.id == 'monthly')
          .map((e) => e.date.toString()),
      ['2027-01-31', '2027-02-28', '2027-03-31', '2027-04-30', '2027-05-31'],
    );
    for (final month in months) {
      expect(
        month.total.convertedMinor,
        aggregateAmounts(
          month.events.map((e) => e.amount),
          const FxSettings(displayCurrency: 'USD'),
        ).convertedMinor,
      );
    }
    final payments = [
      payment('old', 1, '2026-11-15'),
      payment('first', 10, '2026-11-16'),
      payment('today', 20, '2026-12-15'),
      payment('future', 1, '2026-12-16'),
      payment('account', 30, '2026-12-15', serverId: null),
      payment('void', 100, '2026-12-15', voided: true),
    ];
    expect(recentPayments(payments, today).map((p) => p.id).toSet(), {
      'first',
      'today',
      'account',
    });
    expect(
      aggregateAmounts(
        recentPayments(
          payments,
          today,
        ).map((p) => FinanceAmount.money(p.amount)),
        const FxSettings(displayCurrency: 'USD'),
      ).formatted,
      '\$0.60',
    );
    expect(
      recentPayments(
        payments,
        today,
        records: [server(group: 'g', archived: true)],
        groupId: 'g',
      ).map((p) => p.id).toSet(),
      {'first', 'today'},
    );
  });

  test('independent and referenced periods stay anchored when valuation terms change', () {
    final ps = calculatorPeriods(d('2024-01-31'), d('2024-03-31'), 1);
    expect(ps.map((p) => p.start.toString()), ['2024-01-31', '2024-02-29']);
    expect(ps.map((p) => p.end.toString()), ['2024-02-29', '2024-03-31']);
    expect(
      valueOfPeriods(
        renewal: const Money('USD', 100),
        periods: ps,
        asOf: d('2024-01-31'),
      )!.amount.minor,
      Rational.of(200),
    );
    expect(
      valueOfPeriods(
        renewal: const Money('EUR', 200),
        periods: ps,
        asOf: d('2024-02-29'),
      )!.amount.minor,
      Rational.of(200),
    );
    expect(ps.length, 2);
    final expired = calculatorPeriods(d('2024-04-01'), d('2024-03-31'), 1);
    expect(
      valueOfPeriods(
        renewal: const Money('USD', 100),
        periods: expired,
        asOf: d('2024-04-01'),
      )!.amount.minor,
      Rational.zero,
    );
    expect(
      () => calculatorPeriods(d('1900-01-01'), d('2024-03-31'), 1),
      throwsArgumentError,
    );
    final leap = server(cycle: 1, due: '2024-02-29', anchor: '2024-01-31');
    expect(renewalDate(leap, 1), d('2024-03-31'));
    final endOfRange = server(due: '9999-12-31');
    expect(canRenew(endOfRange), isFalse);
    expect(
      renewalEvents(
        [endOfRange],
        d('9999-12-01'),
        const LedgerDate(10000, 1, 1),
      ).length,
      1,
    );
  });

  test('fee rounding/split conserves every cent and negative settlement is retained', () {
    for (final payer in FeePayer.values) {
      final quote = calculateQuote(
        offer: const Money('USD', 1),
        fee: const Money('USD', 5),
        payer: payer,
        reference: FinanceAmount.money(const Money('USD', 2)),
        fx: const FxSettings(displayCurrency: 'USD'),
      )!;
      final expected = switch (payer) {
        FeePayer.buyer => (5, 0),
        FeePayer.seller => (0, 5),
        FeePayer.split => (3, 2),
      };
      expect(quote.buyerFeeMinor, BigInt.from(expected.$1));
      expect(quote.sellerFeeMinor, BigInt.from(expected.$2));
      expect(quote.buyerTotalMinor - quote.sellerNetMinor, BigInt.from(5));
      expect(quote.premiumMinor, BigInt.from(-1));
      if (payer == FeePayer.seller) expect(quote.sellerNet, '\$-0.04');
    }
    expect(
      calculateQuote(
        offer: const Money('USD', 1),
        fee: const Money('EUR', 5),
        payer: FeePayer.split,
        reference: FinanceAmount.money(const Money('USD', 2)),
        fx: const FxSettings(displayCurrency: 'USD'),
      ),
      isNull,
    );
  });
}
