import '../l10n/locale_preference.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/value_types.dart';

/// Describes the displayed period without implying it is active on the
/// valuation date. The amount still includes all known remaining periods.
String valuationPeriodLabel({
  required LedgerDate asOf,
  LedgerDate? start,
  LedgerDate? end,
  AppLocalizations? l10n,
}) {
  final messages = l10n ?? defaultLocalizations;
  if (start == null || end == null) return messages.financeShownPeriod;
  if (asOf.compareTo(start) < 0) return messages.financeFuturePeriod;
  if (asOf.compareTo(end) >= 0) return messages.financeEndedPeriod;
  return messages.financeCurrentPeriod;
}
