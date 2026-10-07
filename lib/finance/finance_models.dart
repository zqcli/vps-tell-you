import '../l10n/locale_preference.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/value_types.dart';
import '../servers/server_record.dart';

/// Exact fractions of minor units. Intermediate arithmetic never uses doubles.
class Rational implements Comparable<Rational> {
  factory Rational(BigInt numerator, [BigInt? denominator]) {
    var d = denominator ?? BigInt.one;
    if (d == BigInt.zero) throw ArgumentError('Denominator cannot be zero');
    var n = numerator;
    if (d.isNegative) {
      n = -n;
      d = -d;
    }
    final gcd = n.gcd(d);
    return Rational._(n ~/ gcd, d ~/ gcd);
  }
  factory Rational.of(int numerator, [int denominator = 1]) =>
      Rational(BigInt.from(numerator), BigInt.from(denominator));
  const Rational._(this.numerator, this.denominator);
  final BigInt numerator, denominator;
  static final zero = Rational.of(0);
  Rational operator +(Rational other) => Rational(
    numerator * other.denominator + other.numerator * denominator,
    denominator * other.denominator,
  );
  Rational operator -(Rational other) => Rational(
    numerator * other.denominator - other.numerator * denominator,
    denominator * other.denominator,
  );
  Rational operator *(Rational other) =>
      Rational(numerator * other.numerator, denominator * other.denominator);
  Rational operator /(Rational other) =>
      Rational(numerator * other.denominator, denominator * other.numerator);

  /// Round half away from zero, only at the final display/settlement boundary.
  BigInt round() {
    final a = numerator.abs();
    final rounded =
        (a * BigInt.two + denominator) ~/ (denominator * BigInt.two);
    return numerator.isNegative ? -rounded : rounded;
  }

  double toDouble() => numerator.toDouble() / denominator.toDouble();
  bool get isZero => numerator == BigInt.zero;
  @override
  int compareTo(Rational other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);
  @override
  bool operator ==(Object other) =>
      other is Rational &&
      numerator == other.numerator &&
      denominator == other.denominator;
  @override
  int get hashCode => Object.hash(numerator, denominator);
  @override
  String toString() => '$numerator/$denominator';
}

String formatMinor(BigInt minor, {String? currency}) {
  final sign = minor.isNegative ? '-' : '';
  final a = minor.abs();
  final decimal =
      '$sign${a ~/ BigInt.from(100)}.${(a % BigInt.from(100)).toString().padLeft(2, '0')}';
  return currency == null ? decimal : '${currencySymbol(currency)}$decimal';
}

String currencySymbol(String currency) =>
    const {'USD': '\$', 'CNY': '¥', 'EUR': '€'}[currency] ?? currency;

/// Format a rational minor-unit value as a major-unit decimal.
String formatRational(Rational minor, {int digits = 2}) {
  if (digits < 0 || digits > 12) throw ArgumentError('Invalid precision');
  final scale = BigInt.from(10).pow(digits);
  final rounded = (minor * Rational(scale, BigInt.from(100))).round();
  final sign = rounded.isNegative ? '-' : '';
  final a = rounded.abs();
  if (digits == 0) return '$sign$a';
  return '$sign${a ~/ scale}.${(a % scale).toString().padLeft(digits, '0')}';
}

enum AmountStatus { known, unknown, notApplicable }

class FinanceAmount {
  const FinanceAmount(
    this.currency,
    this.minor, {
    this.status = AmountStatus.known,
  });
  factory FinanceAmount.money(Money money) =>
      FinanceAmount(money.currency, Rational.of(money.minor));
  const FinanceAmount.unknown(String currency)
    : this(currency, null, status: AmountStatus.unknown);
  const FinanceAmount.notApplicable(String currency)
    : this(currency, null, status: AmountStatus.notApplicable);
  final String currency;
  final Rational? minor;
  final AmountStatus status;
  bool get known => status == AmountStatus.known && minor != null;
  String get decimal => known ? formatRational(minor!) : '—';
  String get formatted => known ? '${currencySymbol(currency)}$decimal' : '—';
}

class FxSettings {
  const FxSettings({
    this.displayCurrency = 'CNY',
    this.usdToCny,
    this.eurToCny,
    this.rateDate,
  });
  final String displayCurrency;
  final String? usdToCny, eurToCny;
  final LedgerDate? rateDate;
  static Rational? parseRate(String? text) {
    if (text == null || !RegExp(r'^\d{1,9}(\.\d{1,8})?$').hasMatch(text)) {
      return null;
    }
    final p = text.split('.');
    final digits = p.length == 1 ? '' : p[1];
    final n = BigInt.parse('${p[0]}$digits');
    return n > BigInt.zero
        ? Rational(n, BigInt.from(10).pow(digits.length))
        : null;
  }

  String? validate({AppLocalizations? l10n}) {
    final messages = l10n ?? defaultLocalizations;
    if (!Money.currencies.contains(displayCurrency)) {
      return messages.financeUnsupportedCurrency;
    }
    if ((usdToCny != null && parseRate(usdToCny) == null) ||
        (eurToCny != null && parseRate(eurToCny) == null)) {
      return messages.financeInvalidRate;
    }
    if ((usdToCny != null || eurToCny != null) &&
        (rateDate == null || !rateDate!.isValid)) {
      return messages.financeMissingRateDate;
    }
    return null;
  }

  Rational? cnyRate(String currency) => switch (currency) {
    'CNY' => Rational.of(1),
    'USD' => parseRate(usdToCny),
    'EUR' => parseRate(eurToCny),
    _ => null,
  };
  Rational? convert(Rational minor, String from, {String? to}) {
    final target = to ?? displayCurrency;
    if (!Money.currencies.contains(from) ||
        !Money.currencies.contains(target)) {
      return null;
    }
    if (from == target) return minor;
    final sourceRate = cnyRate(from), targetRate = cnyRate(target);
    if (sourceRate == null || targetRate == null) return null;
    return minor * sourceRate / targetRate;
  }

  Map<String, Object?> toMap() => {
    'id': 1,
    'display_currency': displayCurrency,
    'usd_to_cny': usdToCny,
    'eur_to_cny': eurToCny,
    'rate_date': rateDate?.toString(),
  };
  factory FxSettings.fromMap(Map<String, Object?> row) => FxSettings(
    displayCurrency: row['display_currency'] as String,
    usdToCny: row['usd_to_cny'] as String?,
    eurToCny: row['eur_to_cny'] as String?,
    rateDate: row['rate_date'] == null
        ? null
        : LedgerDate.tryParse(row['rate_date'] as String),
  );
}

class ServicePeriod {
  const ServicePeriod({
    required this.id,
    required this.serverId,
    required this.start,
    required this.end,
    this.inferred = false,
    this.paymentId,
  });
  final String id, serverId;
  final LedgerDate start, end;
  final bool inferred;
  final String? paymentId;
  int get days => start.daysUntil(end);
  Map<String, Object?> toMap() => {
    'id': id,
    'server_id': serverId,
    'start_date': start.toString(),
    'end_date': end.toString(),
    'inferred': inferred ? 1 : 0,
    'payment_id': paymentId,
  };
  factory ServicePeriod.fromMap(Map<String, Object?> row) => ServicePeriod(
    id: row['id'] as String,
    serverId: row['server_id'] as String,
    start: LedgerDate.tryParse(row['start_date'] as String)!,
    end: LedgerDate.tryParse(row['end_date'] as String)!,
    inferred: row['inferred'] == 1,
    paymentId: row['payment_id'] as String?,
  );
}

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.targetName,
    required this.amount,
    required this.paidDate,
    required this.createdAt,
    this.serverId,
    this.accountLabel,
    this.from,
    this.until,
    this.cycleCount = 0,
    this.note = '',
    this.previousDue,
    this.appliedServerRevision,
    this.voidedAt,
    this.requestFingerprint = '',
  });
  final String id, targetName, note, requestFingerprint;
  final String? serverId, accountLabel;
  final Money amount;
  final LedgerDate paidDate;
  final LedgerDate? from, until, previousDue;
  final int cycleCount;
  final int? appliedServerRevision;
  final DateTime createdAt;
  final DateTime? voidedAt;
  bool get isAccount => serverId == null;
  bool get voided => voidedAt != null;
  Map<String, Object?> toMap() => {
    'id': id,
    'server_id': serverId,
    'target_name': targetName,
    'account_label': accountLabel,
    'amount_minor': amount.minor,
    'currency': amount.currency,
    'paid_date': paidDate.toString(),
    'from_date': from?.toString(),
    'until_date': until?.toString(),
    'cycle_count': cycleCount,
    'note': note,
    'previous_due': previousDue?.toString(),
    'applied_server_revision': appliedServerRevision,
    'created_at': createdAt.toUtc().toIso8601String(),
    'voided_at': voidedAt?.toUtc().toIso8601String(),
    'request_fingerprint': requestFingerprint,
  };
  factory PaymentRecord.fromMap(Map<String, Object?> row) => PaymentRecord(
    id: row['id'] as String,
    serverId: row['server_id'] as String?,
    targetName: row['target_name'] as String,
    accountLabel: row['account_label'] as String?,
    amount: Money(row['currency'] as String, row['amount_minor'] as int),
    paidDate: LedgerDate.tryParse(row['paid_date'] as String)!,
    from: row['from_date'] == null
        ? null
        : LedgerDate.tryParse(row['from_date'] as String),
    until: row['until_date'] == null
        ? null
        : LedgerDate.tryParse(row['until_date'] as String),
    cycleCount: row['cycle_count'] as int,
    note: row['note'] as String,
    previousDue: row['previous_due'] == null
        ? null
        : LedgerDate.tryParse(row['previous_due'] as String),
    appliedServerRevision: row['applied_server_revision'] as int?,
    createdAt: DateTime.parse(row['created_at'] as String),
    voidedAt: row['voided_at'] == null
        ? null
        : DateTime.parse(row['voided_at'] as String),
    requestFingerprint: row['request_fingerprint'] as String,
  );
}

class FinanceTotal {
  FinanceTotal({
    required this.currency,
    required this.convertedMinor,
    required Map<String, Rational> originals,
    required this.covered,
    required this.total,
    required this.unknown,
    required this.notApplicable,
    required this.missingFx,
  }) : originals = Map.unmodifiable(originals);
  final String currency;
  final Rational convertedMinor;
  final Map<String, Rational> originals;
  final int covered, total, unknown, notApplicable, missingFx;
  String get formatted => covered == 0 && total > 0
      ? '—'
      : formatMinor(convertedMinor.round(), currency: currency);
  String get coverageLabel => '$covered / $total';
  bool get complete => covered == total;
}

class Valuation {
  const Valuation({
    required this.amount,
    required this.activePeriod,
    required this.activeRemaining,
    required this.remainingDays,
    required this.futurePeriods,
    required this.periodCount,
    required this.inferred,
    required this.dailyMinor,
  });
  final FinanceAmount amount;
  final ServicePeriod activePeriod;
  final int activeRemaining, remainingDays, futurePeriods, periodCount;
  final bool inferred;
  final Rational dailyMinor;
  int get days => activePeriod.days;
  Rational get ratio => Rational.of(activeRemaining, days);
}

class RenewalEvent {
  const RenewalEvent({required this.server, required this.date});
  final ServerRecord server;
  final LedgerDate date;
  FinanceAmount get amount => server.money == null
      ? FinanceAmount.unknown(server.currency)
      : FinanceAmount.money(server.money!);
}

class ForecastMonth {
  const ForecastMonth({
    required this.month,
    required this.events,
    required this.total,
  });
  final LedgerDate month;
  final List<RenewalEvent> events;
  final FinanceTotal total;
}

enum FeePayer { buyer, seller, split }

class QuoteResult {
  const QuoteResult({
    required this.currency,
    required this.offerMinor,
    required this.feeMinor,
    required this.buyerFeeMinor,
    required this.sellerFeeMinor,
    required this.buyerTotalMinor,
    required this.sellerNetMinor,
    required this.premiumMinor,
  });
  final String currency;
  final BigInt offerMinor,
      feeMinor,
      buyerFeeMinor,
      sellerFeeMinor,
      buyerTotalMinor,
      sellerNetMinor,
      premiumMinor;
  String get offer => formatMinor(offerMinor, currency: currency);
  String get fee => formatMinor(feeMinor, currency: currency);
  String get buyerFee => formatMinor(buyerFeeMinor, currency: currency);
  String get sellerFee => formatMinor(sellerFeeMinor, currency: currency);
  String get buyerTotal => formatMinor(buyerTotalMinor, currency: currency);
  String get sellerNet => formatMinor(sellerNetMinor, currency: currency);
  String get premium => formatMinor(premiumMinor, currency: currency);
}
