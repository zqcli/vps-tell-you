import 'package:flutter/material.dart';

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
              onTap: ledger.loadCatalog,
            ),
          ],
        ),
      ],
    );
  }
}
