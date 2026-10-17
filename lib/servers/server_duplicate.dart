import '../l10n/generated/app_localizations.dart';
import 'server_record.dart';

/// The prefill for "Duplicate": what describes the *kind* of server that was
/// bought (provider, group, region, purpose, OS, hardware, price), but nothing
/// that identifies a machine or belongs to a purchase.
///
/// Not copied: IPv4/IPv6/hostname, legacy host, start/due/anchor dates,
/// favourite, archive state, notes, demo flag. Payments, service periods, SSH
/// configuration, credentials and reminders live outside the record, so they
/// cannot leak into the copy. The result is never saved by itself; it only
/// seeds `ServerForm(template:)`.
ServerRecord duplicateServerTemplate(
  ServerRecord source,
  AppLocalizations l10n,
) {
  final resources = source.resources;
  return ServerRecord(
    id: '',
    name: duplicateServerName(source.name, l10n),
    vendor: source.vendor,
    providerId: source.providerId,
    region: source.region,
    purpose: source.purpose,
    os: source.os,
    groupId: source.groupId,
    resources: resources?.withAddress(ip: '', ipv6: '', hostname: ''),
    billing: source.billing,
    currency: source.currency,
    amountMinor: source.amountMinor,
    cycleMonths: source.cycleMonths,
    createdAt: source.createdAt,
    updatedAt: source.updatedAt,
  );
}

/// `<name> copy` / `<name> 副本`, with the original name shortened (never in
/// the middle of a character) so the result stays within the 80-unit limit.
String duplicateServerName(String name, AppLocalizations l10n) {
  const max = 80;
  final full = l10n.r14ServerCopyName(name);
  if (full.length <= max) return full;
  final overhead = l10n.r14ServerCopyName('').length;
  final kept = StringBuffer();
  for (final rune in name.runes) {
    final next = String.fromCharCode(rune);
    if (kept.length + next.length + overhead > max) break;
    kept.write(next);
  }
  return l10n.r14ServerCopyName(kept.toString());
}
