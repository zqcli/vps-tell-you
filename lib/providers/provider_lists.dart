import 'package:flutter/material.dart';

import '../core/search_match.dart';
import '../core/ui/ui.dart';
import '../l10n/locale_preference.dart';
import '../servers/ledger_controller.dart';
import 'package_widgets.dart';
import 'provider_catalog.dart';
import 'provider_pages.dart';

/// "3 servers · 2 packages in use" for a provider that has servers.
String providerUsageLine(BuildContext context, ProviderUsage usage) {
  final l10n = context.l10n;
  return [
    l10n.r6CatProviderSummary(usage.servers.length),
    if (usage.packageIds.isNotEmpty)
      l10n.r8PackagesInUseCount(usage.packageIds.length),
  ].join(' · ');
}

int _byName(String a, String b) => compareNames(a, b);

/// Catalog providers that have no local provider yet.
List<CatalogProvider> notAddedCatalogProviders(LedgerController ledger) {
  final added = {for (final p in ledger.providers) ?p.catalogId};
  return [
    for (final c in ledger.catalog.providers)
      if (!added.contains(c.id)) c,
  ];
}

/// Settings → Providers: only providers that have servers, plus the way in to
/// every other provider. Stays small however large the catalog is.
class ProvidersPage extends StatefulWidget {
  const ProvidersPage({super.key, required this.ledger});
  final LedgerController ledger;
  @override
  State<ProvidersPage> createState() => _ProvidersPageState();
}

class _ProvidersPageState extends State<ProvidersPage> {
  bool opening = false;
  @override
  void initState() {
    super.initState();
    widget.ledger.loadCatalog();
  }

  Future<void> open(Future<void> Function() action) async {
    if (opening) return;
    setState(() => opening = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> push(Widget page) => open(() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  });

  Future<void> add() => open(() async {
    final provider = await editProvider(context, widget.ledger);
    if (provider != null && mounted && widget.ledger.canMutate) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderDetailsPage(
            ledger: widget.ledger,
            providerId: provider.id,
          ),
        ),
      );
    }
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger,
    builder: (context, _) {
      final ledger = widget.ledger;
      final l10n = context.l10n;
      final usage = ledger.providerUsage;
      final used = [
        for (final p in ledger.providers)
          if (usage.containsKey(p.id)) p,
      ]..sort((a, b) => _byName(a.name, b.name));
      final total =
          ledger.providers.length + notAddedCatalogProviders(ledger).length;
      final canAdd = !opening && ledger.canMutate;
      final unspecified = ledger.records
          .where((s) => s.providerId == null)
          .length;
      return AppScaffold(
        title: l10n.uiCloudProvidersTitle,
        actions: [
          AppNavButton.icon(
            Icons.add,
            key: const ValueKey('provider-add'),
            tooltip: l10n.providerUiAdd,
            onPressed: canAdd ? add : null,
          ),
        ],
        children: [
          ProviderNotices(ledger),
          if (used.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 4),
              child: Text(
                l10n.r8NoProvidersInUse,
                key: const ValueKey('providers-empty'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: context.palette.text2,
                ),
              ),
            )
          else
            AppSection(
              header: l10n.r8ProvidersInUse,
              topSpacing: 8,
              children: [
                for (final provider in used)
                  AppRow(
                    key: ValueKey('provider-${provider.id}'),
                    leading: ProviderAvatar(name: provider.name),
                    title: provider.name,
                    subtitle: providerUsageLine(context, usage[provider.id]!),
                    chevron: true,
                    onTap: opening
                        ? null
                        : () => push(
                            ProviderDetailsPage(
                              ledger: ledger,
                              providerId: provider.id,
                            ),
                          ),
                  ),
              ],
            ),
          AppSection(
            footer: l10n.providerUiHierarchyHelp,
            children: [
              AppRow(
                key: const ValueKey('providers-all'),
                icon: Icons.business_outlined,
                iconColor: AppTints.slate,
                title: l10n.r8AllProviders,
                value: '$total',
                chevron: true,
                onTap: opening
                    ? null
                    : () => push(AllProvidersPage(ledger: ledger)),
              ),
            ],
          ),
          if (unspecified > 0)
            AppSection(
              children: [
                AppRow(
                  leading: const ProviderAvatar(name: null),
                  title: l10n.providerUiUnspecified,
                  subtitle: l10n.providerUiUnspecifiedCount(unspecified),
                ),
              ],
            ),
        ],
      );
    },
  );
}

/// Every provider: the user's own (incl. those linked to the catalog) and the
/// catalog providers not added yet. Searchable and lazily built, so hundreds
/// of providers cost nothing until they scroll into view.
class AllProvidersPage extends StatefulWidget {
  const AllProvidersPage({super.key, required this.ledger});
  final LedgerController ledger;
  @override
  State<AllProvidersPage> createState() => _AllProvidersPageState();
}

class _AllProvidersPageState extends State<AllProvidersPage> {
  final query = TextEditingController();
  final _folded = <String, String>{};
  bool opening = false;

  @override
  void initState() {
    super.initState();
    widget.ledger.loadCatalog();
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  bool _matches(String name, List<String> tokens) =>
      tokens.isEmpty ||
      matchesTokens(_folded.putIfAbsent(name, () => foldSearch(name)), tokens);

  Future<void> push(Widget page) async {
    if (opening) return;
    setState(() => opening = true);
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> add() async {
    if (opening || !widget.ledger.canMutate) return;
    setState(() => opening = true);
    try {
      final provider = await editProvider(context, widget.ledger);
      if (provider != null && mounted && widget.ledger.canMutate) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => ProviderDetailsPage(
              ledger: widget.ledger,
              providerId: provider.id,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger,
    builder: (context, _) {
      final ledger = widget.ledger;
      final l10n = context.l10n;
      final tokens = searchTokens(query.text);
      final usage = ledger.providerUsage;
      final mine = [
        for (final p in ledger.providers)
          if (_matches(p.name, tokens)) p,
      ]..sort((a, b) => _byName(a.name, b.name));
      final catalog = [
        for (final c in notAddedCatalogProviders(ledger))
          if (_matches(c.name, tokens)) c,
      ]..sort((a, b) => _byName(a.name, b.name));
      final nothing = mine.isEmpty && catalog.isEmpty;
      return AppScaffold(
        title: l10n.r8AllProviders,
        actions: [
          AppNavButton.icon(
            Icons.add,
            key: const ValueKey('provider-add'),
            tooltip: l10n.providerUiAdd,
            onPressed: !opening && ledger.canMutate ? add : null,
          ),
        ],
        slivers: [
          SliverToBoxAdapter(child: ProviderNotices(ledger)),
          AppPinnedSearch(
            controller: query,
            placeholder: l10n.r8SearchProviders,
            onChanged: (_) => setState(() {}),
          ),
          if (nothing)
            AppListMessage(
              tokens.isEmpty ? l10n.providerUiEmpty : l10n.r8NoMatches,
              key: const ValueKey('providers-no-match'),
            )
          else
            AppLazySections(
              sections: [
                AppListSection(
                  header: l10n.r6CatMineSection,
                  count: mine.length,
                  itemBuilder: (context, i) {
                    final provider = mine[i];
                    final used = usage[provider.id];
                    final packages = ledger
                        .catalogProviderFor(provider)
                        ?.packages
                        .length;
                    return AppRow(
                      key: ValueKey('provider-${provider.id}'),
                      leading: ProviderAvatar(name: provider.name),
                      title: provider.name,
                      subtitle: [
                        if (used != null)
                          l10n.r6CatProviderSummary(used.servers.length),
                        if (packages != null && packages > 0)
                          l10n.r6CatPackageCount(packages),
                      ].join(' · '),
                      chevron: true,
                      onTap: opening
                          ? null
                          : () => push(
                              ProviderDetailsPage(
                                ledger: ledger,
                                providerId: provider.id,
                              ),
                            ),
                    );
                  },
                ),
                AppListSection(
                  header: l10n.r6CatCatalogSection,
                  footer: tokens.isEmpty ? l10n.r6CatCatalogFooter : null,
                  count: catalog.length,
                  itemBuilder: (context, i) {
                    final provider = catalog[i];
                    return AppRow(
                      key: ValueKey('catalog-provider-${provider.id}'),
                      leading: ProviderAvatar(name: provider.name),
                      title: provider.name,
                      subtitle: provider.packages.isEmpty
                          ? null
                          : l10n.r6CatPackageCount(provider.packages.length),
                      chevron: true,
                      onTap: opening
                          ? null
                          : () => push(
                              ProviderDetailsPage(
                                ledger: ledger,
                                catalogId: provider.id,
                              ),
                            ),
                    );
                  },
                ),
              ],
            ),
        ],
      );
    },
  );
}

enum _PackageSort { listed, price, name }

/// Every package of one catalog provider, searchable by name, region and
/// specification text (`2 GB`, `2C`, `40G`).
class PackageListPage extends StatefulWidget {
  const PackageListPage({
    super.key,
    required this.ledger,
    required this.catalogId,
  });
  final LedgerController ledger;
  final String catalogId;
  @override
  State<PackageListPage> createState() => _PackageListPageState();
}

class _PackageListPageState extends State<PackageListPage> {
  final query = TextEditingController();
  final _text = <String, String>{};
  _PackageSort sort = _PackageSort.listed;
  bool opening = false;

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> openPackage(CatalogPackage package) async {
    if (opening) return;
    setState(() => opening = true);
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PackageDetailsPage(ledger: widget.ledger, packageId: package.id),
        ),
      );
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  /// Monthly price for ordering; packages without a price go last.
  static (int, String, double) _priceKey(CatalogPackage p) {
    final price = p.price;
    return price == null
        ? (1, '', 0)
        : (0, price.currency, price.amountMinor / price.cycleMonths);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger,
    builder: (context, _) {
      final ledger = widget.ledger;
      final l10n = context.l10n;
      final provider = ledger.catalog.provider(widget.catalogId);
      final tokens = searchTokens(query.text);
      final packages = [
        for (final p in provider?.packages ?? const <CatalogPackage>[])
          if (tokens.isEmpty ||
              matchesTokens(
                _text.putIfAbsent(
                  '${l10n.localeName}/${p.id}',
                  () => packageSearchText(l10n, p),
                ),
                tokens,
              ))
            p,
      ];
      switch (sort) {
        case _PackageSort.listed:
          break;
        case _PackageSort.name:
          packages.sort((a, b) => _byName(a.name, b.name));
        case _PackageSort.price:
          packages.sort((a, b) {
            final x = _priceKey(a), y = _priceKey(b);
            final c = x.$1 != y.$1
                ? x.$1.compareTo(y.$1)
                : x.$2 != y.$2
                ? x.$2.compareTo(y.$2)
                : x.$3.compareTo(y.$3);
            return c != 0 ? c : _byName(a.name, b.name);
          });
      }
      return AppScaffold(
        title: l10n.r8AllPackages,
        subtitle: provider?.name,
        slivers: [
          SliverToBoxAdapter(child: ProviderNotices(ledger)),
          AppPinnedSearch(
            controller: query,
            placeholder: l10n.r8SearchPackages,
            onChanged: (_) => setState(() {}),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: AppSegmented<_PackageSort>(
                key: const ValueKey('package-sort'),
                options: {
                  _PackageSort.listed: l10n.r8SortListed,
                  _PackageSort.price: l10n.r8SortPrice,
                  _PackageSort.name: l10n.r8SortName,
                },
                value: sort,
                onChanged: (value) => setState(() => sort = value),
              ),
            ),
          ),
          if (packages.isEmpty)
            AppListMessage(
              provider == null || provider.packages.isEmpty
                  ? l10n.r6CatNoPackagesYet
                  : l10n.r8NoMatches,
              key: const ValueKey('packages-no-match'),
            )
          else
            AppLazySections(
              sections: [
                AppListSection(
                  count: packages.length,
                  itemBuilder: (context, i) {
                    final package = packages[i];
                    return packageRow(
                      context,
                      key: ValueKey('package-list-${package.id}'),
                      package: package,
                      useCount: ledger.packageUseCount(package.id),
                      chevron: true,
                      onTap: opening ? null : () => openPackage(package),
                    );
                  },
                ),
              ],
            ),
        ],
      );
    },
  );
}
