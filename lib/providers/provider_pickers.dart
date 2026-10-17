import 'package:flutter/material.dart';

import '../core/search_match.dart';
import '../core/ui/ui.dart';
import '../l10n/locale_preference.dart';
import '../servers/ledger_controller.dart';
import '../servers/server_record.dart';
import 'directory_widgets.dart';
import 'provider_lists.dart';
import 'provider_pages.dart';
import 'provider_record.dart';

/// What the server form's provider picker returns. A null route result means
/// cancelled; [none] is the explicit "no provider".
class ProviderChoice {
  const ProviderChoice.none() : local = null, catalog = null, draft = null;
  const ProviderChoice.local(ProviderRecord this.local)
    : catalog = null,
      draft = null;
  const ProviderChoice.catalog(CatalogProviderRef this.catalog)
    : local = null,
      draft = null;
  const ProviderChoice.draft(ProviderRecord this.draft)
    : local = null,
      catalog = null;

  /// An existing local provider.
  final ProviderRecord? local;

  /// A directory provider that gets its local provider when the server is saved.
  final CatalogProviderRef? catalog;

  /// A new user provider that is created when the server is saved.
  final ProviderRecord? draft;
}

/// Full-height provider picker for the server form: search on top, then None,
/// providers in use, the user's others, the directory and "New Provider…".
/// Nothing is written: new and catalog providers are created on save.
Future<ProviderChoice?> pickProvider(
  BuildContext context, {
  required LedgerController ledger,
  ProviderRecord? selected,
  CatalogProviderRef? pendingCatalog,
  ProviderRecord? pendingNew,
}) => showAppModal<ProviderChoice>(
  context,
  builder: (_) => ProviderPickerPage(
    ledger: ledger,
    selected: selected,
    pendingCatalog: pendingCatalog,
    pendingNew: pendingNew,
  ),
);

class ProviderPickerPage extends StatefulWidget {
  const ProviderPickerPage({
    super.key,
    required this.ledger,
    this.selected,
    this.pendingCatalog,
    this.pendingNew,
  });
  final LedgerController ledger;
  final ProviderRecord? selected, pendingNew;
  final CatalogProviderRef? pendingCatalog;
  @override
  State<ProviderPickerPage> createState() => _ProviderPickerPageState();
}

class _ProviderPickerPageState extends State<ProviderPickerPage> {
  final query = TextEditingController();
  final _folded = <String, String>{};
  bool busy = false;

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  String _fold(String name) =>
      _folded.putIfAbsent(name, () => foldSearch(name));

  void _pick(ProviderChoice choice) {
    if (busy) return;
    busy = true;
    Navigator.pop(context, choice);
  }

  Future<void> _newProvider() async {
    if (busy || !widget.ledger.canMutate) return;
    busy = true;
    final draft = await draftProvider(context, widget.ledger);
    busy = false;
    if (draft != null && mounted) _pick(ProviderChoice.draft(draft));
  }

  void _newNamed(String name) => _pick(
    ProviderChoice.draft(
      ProviderRecord(
        id: newLocalId(),
        name: name,
        createdAt: widget.ledger.clock(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ledger,
    builder: (context, _) {
      final ledger = widget.ledger;
      final l10n = context.l10n;
      final p = context.palette;
      final typed = query.text.trim();
      final tokens = searchTokens(typed);
      bool matches(String name) =>
          tokens.isEmpty || matchesTokens(_fold(name), tokens);
      final usage = ledger.providerUsage;
      final local = [
        for (final provider in ledger.providers)
          if (matches(provider.name)) provider,
      ]..sort((a, b) => compareNames(a.name, b.name));
      final inUse = [
        for (final provider in local)
          if (usage.containsKey(provider.id)) provider,
      ];
      final mine = [
        for (final provider in local)
          if (!usage.containsKey(provider.id)) provider,
      ];
      final catalog = [
        for (final provider in notAddedDirectoryProviders(ledger))
          if (tokens.isEmpty ||
              matchesTokens(_fold(provider.searchNames.join('\u0001')), tokens))
            provider,
      ]..sort((a, b) => compareNames(a.displayName(l10n), b.displayName(l10n)));
      final draft = widget.pendingNew;
      final showDraft = draft != null && matches(draft.name);
      final searching = tokens.isNotEmpty;
      // Offer the typed text as a new provider unless that name exists.
      final typedFold = foldSearch(typed);
      final exact =
          searching &&
          (ledger.providers.any((x) => _fold(x.name) == typedFold) ||
              ledger.directory.providers.any(
                (x) => x.searchNames.any((n) => foldSearch(n) == typedFold),
              ) ||
              (draft != null && _fold(draft.name) == typedFold));
      final canOfferTyped =
          searching && !exact && typed.length <= 80 && ledger.canMutate;
      Widget? check(bool on) =>
          on ? Icon(Icons.check_rounded, size: 22, color: p.primary) : null;
      final none =
          widget.selected == null &&
          widget.pendingCatalog == null &&
          widget.pendingNew == null;

      AppListSection providerSection(
        String? header,
        List<ProviderRecord> items,
      ) => AppListSection(
        header: header,
        count: items.length,
        itemBuilder: (context, i) {
          final provider = items[i];
          final used = usage[provider.id];
          return AppRow(
            key: ValueKey('picker-provider-${provider.id}'),
            leading: ProviderLogo(ledger: ledger, provider: provider),
            title: provider.name,
            subtitle: used == null
                ? null
                : l10n.r6CatProviderSummary(used.servers.length),
            trailing: check(widget.selected?.id == provider.id),
            onTap: () => _pick(ProviderChoice.local(provider)),
          );
        },
      );

      final empty =
          searching &&
          !canOfferTyped &&
          inUse.isEmpty &&
          mine.isEmpty &&
          catalog.isEmpty &&
          !showDraft;
      return AppScaffold.modal(
        title: l10n.r8PickProvider,
        slivers: [
          SliverToBoxAdapter(child: ProviderNotices(ledger)),
          AppPinnedSearch(
            controller: query,
            placeholder: l10n.r8SearchProviders,
            onChanged: (_) => setState(() {}),
          ),
          if (empty)
            AppListMessage(
              l10n.r8NoMatches,
              key: const ValueKey('picker-no-match'),
            )
          else
            AppLazySections(
              sections: [
                if (canOfferTyped)
                  AppListSection(
                    count: 1,
                    itemBuilder: (context, _) => AppRow(
                      key: const ValueKey('picker-provider-new-named'),
                      icon: Icons.add_rounded,
                      iconColor: AppTints.green,
                      title: l10n.r8NewProviderNamed(typed),
                      onTap: () => _newNamed(typed),
                    ),
                  ),
                if (!searching)
                  AppListSection(
                    count: 1,
                    itemBuilder: (context, _) => AppRow(
                      key: const ValueKey('picker-provider-none'),
                      leading: const ProviderAvatar(name: null),
                      title: l10n.r7FormProviderNone,
                      trailing: check(none),
                      onTap: () => _pick(const ProviderChoice.none()),
                    ),
                  ),
                // Kept near the top: the catalog can run to hundreds of rows.
                if (!searching && ledger.canMutate)
                  AppListSection(
                    count: 1,
                    itemBuilder: (context, _) => AppRow(
                      key: const ValueKey('picker-provider-new'),
                      icon: Icons.add_rounded,
                      iconColor: AppTints.green,
                      title: l10n.r7FormProviderNew,
                      onTap: _newProvider,
                    ),
                  ),
                if (showDraft)
                  AppListSection(
                    count: 1,
                    itemBuilder: (context, _) => AppRow(
                      key: const ValueKey('picker-provider-draft'),
                      leading: ProviderAvatar(name: draft.name),
                      title: draft.name,
                      trailing: check(true),
                      onTap: () => _pick(ProviderChoice.draft(draft)),
                    ),
                  ),
                providerSection(l10n.r8SectionInUse, inUse),
                providerSection(l10n.r6CatMineSection, mine),
                AppListSection(
                  header: l10n.r6CatCatalogSection,
                  count: catalog.length,
                  itemBuilder: (context, i) {
                    final provider = catalog[i];
                    final name = provider.displayName(l10n);
                    return AppRow(
                      key: ValueKey('picker-catalog-${provider.id}'),
                      leading: ProviderLogo(
                        ledger: ledger,
                        directoryId: provider.id,
                        name: name,
                      ),
                      title: name,
                      trailing: check(
                        widget.pendingCatalog?.catalogId == provider.id,
                      ),
                      onTap: () =>
                          _pick(ProviderChoice.catalog(provider.refIn(l10n))),
                    );
                  },
                ),
              ],
            ),
          if (!searching && directoryIsEmpty(ledger.directory))
            const SliverToBoxAdapter(child: DirectoryEmptyHint()),
        ],
      );
    },
  );
}
