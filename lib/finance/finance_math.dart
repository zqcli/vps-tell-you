import '../l10n/localized_message.dart';
import '../core/value_types.dart';
import '../servers/server_record.dart';
import 'finance_models.dart';

bool validCycle(int months) => const [1, 3, 6, 12, 24, 36].contains(months);

FinanceAmount monthlyAmount(ServerRecord server, LedgerDate today) {
  if (server.billing == BillingKind.unknown || server.money == null) {
    return FinanceAmount.unknown(server.currency);
  }
  if (server.billing == BillingKind.metered) {
    return FinanceAmount.money(server.money!);
  }
  if (server.dueDate == null || !validCycle(server.cycleMonths)) {
    return FinanceAmount.unknown(server.currency);
  }
  if (server.dueDate!.compareTo(today) <= 0) {
    return FinanceAmount.notApplicable(server.currency);
  }
  return FinanceAmount(
    server.currency,
    Rational.of(server.amountMinor!, server.cycleMonths),
  );
}

/// Every period is valued using current renewal terms, not historical payment.
Valuation? valueOfPeriods({
  required Money renewal,
  required List<ServicePeriod> periods,
  required LedgerDate asOf,
}) {
  if (periods.isEmpty ||
      !asOf.isValid ||
      renewal.minor < 0 ||
      !Money.currencies.contains(renewal.currency)) {
    return null;
  }
  final sorted = [...periods]..sort((a, b) => a.start.compareTo(b.start));
  for (var i = 0; i < sorted.length; i++) {
    final p = sorted[i];
    if (!p.start.isValid ||
        !p.end.isValid ||
        p.days <= 0 ||
        (i > 0 && sorted[i - 1].end.compareTo(p.start) > 0)) {
      return null;
    }
  }
  var remaining = 0;
  var amount = Rational.zero;
  for (final p in sorted) {
    final unused = asOf.daysUntil(p.end).clamp(0, p.days);
    remaining += unused;
    amount += Rational.of(renewal.minor) * Rational.of(unused, p.days);
  }
  final active =
      sorted
          .where(
            (p) => p.start.compareTo(asOf) <= 0 && p.end.compareTo(asOf) > 0,
          )
          .firstOrNull ??
      sorted.where((p) => p.start.compareTo(asOf) > 0).firstOrNull ??
      sorted.last;
  return Valuation(
    amount: FinanceAmount(renewal.currency, amount),
    activePeriod: active,
    activeRemaining: asOf.daysUntil(active.end).clamp(0, active.days),
    remainingDays: remaining,
    futurePeriods: sorted.where((p) => p.start.compareTo(asOf) > 0).length,
    periodCount: sorted.length,
    inferred: sorted.any((p) => p.inferred),
    dailyMinor: Rational.of(renewal.minor, active.days),
  );
}

Valuation? serverValuation(
  ServerRecord server,
  List<ServicePeriod> periods,
  LedgerDate asOf,
) {
  if (server.billing != BillingKind.prepaid ||
      server.money == null ||
      server.dueDate == null) {
    return null;
  }
  return valueOfPeriods(
    renewal: server.money!,
    periods: periods.where((p) => p.serverId == server.id).toList(),
    asOf: asOf,
  );
}

FinanceTotal aggregateAmounts(Iterable<FinanceAmount> amounts, FxSettings fx) {
  var total = 0, covered = 0, unknown = 0, notApplicable = 0, missingFx = 0;
  var converted = Rational.zero;
  final originals = <String, Rational>{};
  for (final a in amounts) {
    total++;
    if (!a.known) {
      if (a.status == AmountStatus.notApplicable) {
        notApplicable++;
      } else {
        unknown++;
      }
      continue;
    }
    originals[a.currency] = (originals[a.currency] ?? Rational.zero) + a.minor!;
    final value = fx.convert(a.minor!, a.currency);
    if (value == null) {
      missingFx++;
    } else {
      covered++;
      converted += value;
    }
  }
  return FinanceTotal(
    currency: fx.displayCurrency,
    convertedMinor: converted,
    originals: originals,
    covered: covered,
    total: total,
    unknown: unknown,
    notApplicable: notApplicable,
    missingFx: missingFx,
  );
}

/// Add from the durable first due-date anchor, including across reopen/retries.
LedgerDate renewalDate(ServerRecord server, int cycles) {
  final due = server.dueDate;
  if (due == null ||
      !due.isValid ||
      !validCycle(server.cycleMonths) ||
      cycles < 0) {
    throw LocalizedArgumentError((l10n) => l10n.financeRenewalDateError);
  }
  final anchor = server.renewalAnchorDate ?? due;
  final elapsed = (due.year - anchor.year) * 12 + due.month - anchor.month;
  if (!anchor.isValid ||
      elapsed < 0 ||
      anchor.addMonths(elapsed) != due ||
      elapsed % server.cycleMonths != 0) {
    throw LocalizedStateError((l10n) => l10n.financeAnchorMismatch);
  }
  final result = anchor.addMonths(elapsed + cycles * server.cycleMonths);
  if (!result.isValid) {
    throw LocalizedArgumentError((l10n) => l10n.financeDueRangeError);
  }
  return result;
}

bool canRenew(ServerRecord server, {int cycles = 1}) {
  if (server.archived ||
      server.billing != BillingKind.prepaid ||
      !const [1, 2, 3].contains(cycles)) {
    return false;
  }
  try {
    renewalDate(server, cycles);
    return true;
  } on ArgumentError {
    return false;
  } on StateError {
    return false;
  }
}

List<RenewalEvent> renewalEvents(
  Iterable<ServerRecord> records,
  LedgerDate today,
  LedgerDate until,
) {
  final events = <RenewalEvent>[];
  for (final server in records) {
    final due = server.dueDate;
    if (server.archived ||
        server.billing != BillingKind.prepaid ||
        due == null ||
        due.compareTo(today) < 0 ||
        !validCycle(server.cycleMonths)) {
      continue;
    }
    for (var i = 0; i < 1200; i++) {
      LedgerDate date;
      try {
        date = renewalDate(server, i);
      } on ArgumentError {
        // No supported date remains beyond year 9999.
        break;
      }
      if (date.compareTo(until) >= 0) break;
      events.add(RenewalEvent(server: server, date: date));
    }
  }
  events.sort((a, b) {
    final date = a.date.compareTo(b.date);
    return date == 0 ? a.server.id.compareTo(b.server.id) : date;
  });
  return events;
}

List<ForecastMonth> sixMonthForecast(
  Iterable<ServerRecord> records,
  LedgerDate today,
  FxSettings fx,
) {
  final first = LedgerDate(today.year, today.month, 1);
  final events = renewalEvents(records, today, first.addMonths(6));
  return List.generate(6, (i) {
    final month = first.addMonths(i), end = first.addMonths(i + 1);
    final items = events
        .where((e) => e.date.compareTo(month) >= 0 && e.date.compareTo(end) < 0)
        .toList(growable: false);
    return ForecastMonth(
      month: month,
      events: List.unmodifiable(items),
      total: aggregateAmounts(items.map((e) => e.amount), fx),
    );
  }, growable: false);
}

/// All-scope history includes archived servers and each account bill once.
/// A group never allocates or copies account-level payments onto instances.
List<PaymentRecord> recentPayments(
  Iterable<PaymentRecord> payments,
  LedgerDate today, {
  Iterable<ServerRecord> records = const [],
  String? groupId,
}) {
  final ids = records
      .where((s) => (s.groupId ?? '') == groupId)
      .map((s) => s.id)
      .toSet();
  final result = payments
      .where(
        (p) =>
            !p.voided &&
            p.paidDate.compareTo(today.addDays(-29)) >= 0 &&
            p.paidDate.compareTo(today) <= 0 &&
            (groupId == null ||
                (p.serverId != null && ids.contains(p.serverId))),
      )
      .toList();
  result.sort((a, b) => b.paidDate.compareTo(a.paidDate));
  return result;
}

/// Independent trial: service was continuously available before the given end.
/// Every boundary is computed from the original end, never a clamped predecessor.
List<ServicePeriod> calculatorPeriods(
  LedgerDate asOf,
  LedgerDate end,
  int cycleMonths,
) {
  if (!asOf.isValid ||
      !end.isValid ||
      !validCycle(cycleMonths) ||
      asOf.daysUntil(end).abs() > 36600) {
    throw LocalizedArgumentError((l10n) => l10n.financeTrialInputError);
  }
  final result = <ServicePeriod>[];
  for (var i = 0; i < 1200; i++) {
    final start = end.addMonths(-(i + 1) * cycleMonths);
    if (!start.isValid) {
      throw LocalizedArgumentError((l10n) => l10n.financePeriodRangeError);
    }
    result.add(
      ServicePeriod(
        id: 'trial-$i',
        serverId: 'trial',
        start: start,
        end: end.addMonths(-i * cycleMonths),
        inferred: true,
      ),
    );
    if (start.compareTo(asOf) <= 0) {
      return result.reversed.toList(growable: false);
    }
  }
  throw LocalizedArgumentError((l10n) => l10n.financeTrialRangeError);
}

/// Parses a premium percentage such as `12.5` (0 – 1000, up to two decimals).
/// The sign is chosen separately (premium or discount).
Rational? parseQuotePercent(String text) {
  final value = text.trim();
  if (!RegExp(r'^\d{1,4}(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final decimals = parts.length == 2 ? parts[1] : '';
  final numerator = BigInt.parse('${parts[0]}$decimals');
  final result = Rational(numerator, BigInt.from(10).pow(decimals.length));
  return result.compareTo(Rational.of(1000)) > 0 ? null : result;
}

/// Transfer-trial settlement in the display currency.
///
/// Exactly one price input is given:
/// * [offer] – the seller's price; premium = offer − remaining value.
/// * [premiumMinor] – signed premium amount; price = remaining value + premium.
/// * [premiumPercent] – signed percent of the (rounded) remaining value, e.g.
///   `Rational.of(-5)` is a 5 % discount; the premium is rounded half away
///   from zero.
///
/// The remaining value is converted and rounded once (half away from zero) so
/// the displayed `remaining value + premium = price` always adds up. A
/// negative premium is a discount. Returns null when a rate is missing or the
/// price would be negative or above [Money.maxMinor]. Fees: the total is
/// converted and rounded; "split" gives the odd minor unit to the buyer.
QuoteResult? calculateQuote({
  Money? offer,
  BigInt? premiumMinor,
  Rational? premiumPercent,
  required Money fee,
  required FeePayer payer,
  required FinanceAmount reference,
  required FxSettings fx,
}) {
  final inputs = [offer, premiumMinor, premiumPercent].nonNulls.length;
  if (inputs != 1) {
    throw ArgumentError('Exactly one of offer, premium or percent is needed');
  }
  if (fee.minor < 0 ||
      fee.minor > Money.maxMinor ||
      (offer != null &&
          (offer.minor < 0 ||
              offer.minor > Money.maxMinor ||
              offer.currency != fx.displayCurrency)) ||
      !reference.known) {
    return null;
  }
  final referenceExact = fx.convert(reference.minor!, reference.currency);
  final convertedFee = fx.convert(Rational.of(fee.minor), fee.currency);
  if (referenceExact == null || convertedFee == null) return null;
  final referenceMinor = referenceExact.round();
  final BigInt premium;
  if (offer != null) {
    premium = BigInt.from(offer.minor) - referenceMinor;
  } else if (premiumMinor != null) {
    premium = premiumMinor;
  } else {
    premium = (Rational(referenceMinor) * premiumPercent! / Rational.of(100))
        .round();
  }
  final offerMinor = referenceMinor + premium;
  final max = BigInt.from(Money.maxMinor);
  if (offerMinor.isNegative || offerMinor > max) return null;
  final totalFee = convertedFee.round();
  final buyerFee = switch (payer) {
    FeePayer.buyer => totalFee,
    FeePayer.seller => BigInt.zero,
    FeePayer.split => (totalFee + BigInt.one) ~/ BigInt.two,
  };
  final sellerFee = totalFee - buyerFee;
  return QuoteResult(
    currency: fx.displayCurrency,
    referenceMinor: referenceMinor,
    offerMinor: offerMinor,
    feeMinor: totalFee,
    buyerFeeMinor: buyerFee,
    sellerFeeMinor: sellerFee,
    buyerTotalMinor: offerMinor + buyerFee,
    sellerNetMinor: offerMinor - sellerFee,
    premiumMinor: premium,
  );
}
