/// A calendar date without a timezone or time-of-day.
/// UTC is used only as an ordinal representation, never as local midnight.
class LedgerDate implements Comparable<LedgerDate> {
  const LedgerDate(this.year, this.month, this.day);
  final int year;
  final int month;
  final int day;

  static LedgerDate? tryParse(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    final parts = value.split('-').map(int.parse).toList();
    final normalized = DateTime.utc(parts[0], parts[1], parts[2]);
    if (normalized.year != parts[0] ||
        normalized.month != parts[1] ||
        normalized.day != parts[2] ||
        parts[0] < 1) {
      return null;
    }
    return LedgerDate(parts[0], parts[1], parts[2]);
  }

  factory LedgerDate.today(DateTime now) =>
      LedgerDate(now.year, now.month, now.day);
  bool get isValid =>
      year >= 1 &&
      year <= 9999 &&
      ordinal.year == year &&
      ordinal.month == month &&
      ordinal.day == day;
  @override
  bool operator ==(Object other) =>
      other is LedgerDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;
  @override
  int get hashCode => Object.hash(year, month, day);
  DateTime get ordinal => DateTime.utc(year, month, day);
  int daysUntil(LedgerDate other) => other.ordinal.difference(ordinal).inDays;
  LedgerDate addDays(int days) {
    final result = ordinal.add(Duration(days: days));
    return LedgerDate(result.year, result.month, result.day);
  }

  /// Always add from the original anchor, not the previous clamped result.
  LedgerDate addMonths(int months) {
    final target = DateTime.utc(year, month + months);
    final lastDay = DateTime.utc(target.year, target.month + 1, 0).day;
    return LedgerDate(target.year, target.month, day > lastDay ? lastDay : day);
  }

  @override
  int compareTo(LedgerDate other) => ordinal.compareTo(other.ordinal);
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

/// USD/CNY/EUR use integer minor units. A null amount is unknown, not zero.
class Money {
  const Money(this.currency, this.minor);
  final String currency;
  final int minor;
  static const currencies = ['USD', 'CNY', 'EUR'];
  static const maxMinor = 999999999999;
  static int? parseMinor(String value) {
    if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(value.trim())) return null;
    final parts = value.trim().split('.');
    final minor =
        int.parse(parts[0]) * 100 +
        (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
    return minor <= maxMinor ? minor : null;
  }

  String get decimal =>
      "${minor < 0 ? '-' : ''}${minor.abs() ~/ 100}.${(minor.abs() % 100).toString().padLeft(2, '0')}";
  String get formatted =>
      '${{'USD': '\$', 'CNY': '¥', 'EUR': '€'}[currency] ?? currency}$decimal';
}
