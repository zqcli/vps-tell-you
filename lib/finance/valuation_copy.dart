import '../core/value_types.dart';

/// Describes the displayed period without implying it is active on the
/// valuation date. The amount still includes all known remaining periods.
String valuationPeriodLabel({
  required LedgerDate asOf,
  LedgerDate? start,
  LedgerDate? end,
}) {
  if (start == null || end == null) return '所示周期';
  if (asOf.compareTo(start) < 0) return '尚未开始的周期';
  if (asOf.compareTo(end) >= 0) return '已结束的周期';
  return '当前周期';
}
