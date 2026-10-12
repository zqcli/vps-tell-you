import 'package:flutter/material.dart';

import '../core/search_match.dart';
import '../core/ui/ui.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import '../servers/ledger_controller.dart';
import '../servers/server_resources.dart';
import 'provider_catalog.dart';

/// `2 vCPU · 4 GiB · 60 GiB` (empty when the package lists no hardware).
String packageHardwareLine(AppLocalizations l10n, CatalogPackage package) =>
    package.resources.specSummaryFor(l10n);

String packageCycleText(AppLocalizations l10n, int months) =>
    months == 12 ? l10n.serverEveryYear : l10n.serverEveryMonths(months);

/// `12.00 USD · Every month`.
String packagePriceText(AppLocalizations l10n, CatalogPrice price) =>
    l10n.r6CatPriceValue(
      price.money.decimal,
      price.currency,
      packageCycleText(l10n, price.cycleMonths),
    );

/// One-line summary for lists: price, then hardware.
String packageSummaryLine(AppLocalizations l10n, CatalogPackage package) => [
  if (package.price != null) packagePriceText(l10n, package.price!),
  packageHardwareLine(l10n, package),
].where((part) => part.isNotEmpty).join(' · ');

/// 核 ("core"), written as an escape: a search alias, not interface text.
const _coreCjk = '\u6838';

const _mib = 1024 * 1024, _gib = 1024 * _mib, _tib = 1024 * _gib;

/// Compact spellings of a capacity people type: `2g 2gb 2gib` for 2 GiB.
Iterable<String> _capacityWords(int? bytes) {
  if (bytes == null || bytes <= 0) return const [];
  final (n, units) = bytes % _tib == 0
      ? (bytes ~/ _tib, ['t', 'tb', 'tib'])
      : bytes % _gib == 0
      ? (bytes ~/ _gib, ['g', 'gb', 'gib'])
      : (bytes ~/ _mib, ['m', 'mb', 'mib']);
  return [for (final u in units) '$n$u'];
}

/// Everything a user may search a package by: name, region, the localized
/// summary, price, and compact spec spellings (`2c`, `2gb`, `40g`, `2核`).
String packageSearchText(AppLocalizations l10n, CatalogPackage package) =>
    searchHaystack([
      package.name,
      package.region,
      packageSummaryLine(l10n, package),
      if (package.vcpu != null)
        for (final u in ['c', 'core', 'cores', 'vcpu', 'cpu', _coreCjk])
          '${package.vcpu}$u',
      ..._capacityWords(package.ramBytes),
      ..._capacityWords(package.diskBytes),
      ..._capacityWords(package.trafficBytes),
      if (package.trafficUnlimited) 'unlimited',
    ]);

/// Pill describing how a saved package relates to the current catalog.
StatusPill? packageStatePill(
  AppLocalizations l10n,
  PackageCatalogState state,
) => switch (state) {
  PackageCatalogState.changed => StatusPill(
    l10n.r6CatChangedPill,
    tone: AppTone.amber,
  ),
  PackageCatalogState.removed => StatusPill(
    l10n.r6CatRemovedPill,
    tone: AppTone.neutral,
  ),
  _ => null,
};

/// Read-only specification rows of [package]. Unknown values read "—".
List<Widget> packageSpecRows(BuildContext context, CatalogPackage package) {
  final l10n = context.l10n;
  String? bytes(int? value) =>
      value == null ? null : ServerResources.formatBytes(value);
  return [
    AppKeyValueRow(
      label: l10n.resourceVcpuCount,
      value: package.vcpu?.toString(),
    ),
    AppKeyValueRow(label: l10n.uiFormMemory, value: bytes(package.ramBytes)),
    AppKeyValueRow(label: l10n.uiFormDisk, value: bytes(package.diskBytes)),
    AppKeyValueRow(
      label: l10n.uiFormTraffic,
      value: package.trafficUnlimited || package.trafficBytes != null
          ? package.resources.trafficSummaryFor(l10n)
          : null,
    ),
    AppKeyValueRow(
      label: l10n.r6CatPrice,
      value: package.price == null
          ? null
          : packagePriceText(l10n, package.price!),
    ),
    if (package.region.isNotEmpty)
      AppKeyValueRow(label: l10n.uiFormRegion, value: package.region),
    if (package.notes.isNotEmpty)
      AppKeyValueRow(label: l10n.serverNotes, value: package.notes),
  ];
}

/// Shown on pages which depend on the catalog when it could not be loaded.
class CatalogFailureBanner extends StatelessWidget {
  const CatalogFailureBanner({super.key, required this.ledger});
  final LedgerController ledger;
  @override
  Widget build(BuildContext context) {
    if (!ledger.catalogFailed || ledger.catalogLoaded) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBanner(
          text: context.l10n.r6CatCatalogFailed,
          tone: AppTone.amber,
          icon: Icons.error_outline_rounded,
        ),
        AppSection(
          topSpacing: 10,
          children: [
            AppRow(
              key: const ValueKey('catalog-retry'),
              center: true,
              title: context.l10n.r6CatRetry,
              onTap: () => ledger.loadCatalog(),
            ),
          ],
        ),
      ],
    );
  }
}
