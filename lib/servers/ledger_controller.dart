import '../l10n/localized_message.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/net_address.dart';
import '../core/value_types.dart';
import '../data/ledger_store.dart';
import '../l10n/locale_preference.dart';
import '../l10n/generated/app_localizations.dart';
import '../finance/finance_math.dart';
import '../finance/finance_models.dart';
import '../providers/provider_directory.dart';
import '../providers/provider_record.dart';
import '../security/security_controller.dart';
import '../settings/reminder_rule.dart';
import '../settings/reminder_scheduler.dart';
import 'server_record.dart';

enum ServerFilter { all, favorites, pending }

enum DueFilter { all, overdue, next30, unknown }

enum ServerSort { favorites, due, name, updated }

class LedgerController extends ChangeNotifier {
  LedgerController(
    this.store, {
    DateTime Function()? clock,
    SecurityController? security,
    ReminderPlatform? reminderPlatform,
    ProviderDirectory? directory,
  }) : clock = clock ?? DateTime.now,
       directory = directory ?? ProviderDirectory.memory(),
       security = security ?? SecurityController(store: store) {
    reminders = ReminderScheduler(
      store,
      platform: reminderPlatform,
      clock: this.clock,
    );
    reminders.addListener(notifyListeners);
    this.directory.addListener(notifyListeners);
  }
  final SecurityController security;

  /// The public provider directory (names, logos, descriptions). It is
  /// independent of the ledger: a slow or failed download never affects it.
  final ProviderDirectory directory;

  /// Whether the directory refreshes itself on launch (persisted setting).
  bool directoryAuto = true;
  bool _directoryStarted = false;

  /// Reads the cached directory, then — if the setting allows and the cache is
  /// older than 12 hours — refreshes it in the background. Never throws.
  Future<void> startDirectory() async {
    if (_directoryStarted) return;
    _directoryStarted = true;
    await directory.load();
    await directory.autoRefresh(enabled: directoryAuto);
  }

  /// Persists the "Update on Launch" switch. A preference-only write like
  /// [setLanguage]: it does not reload the ledger.
  Future<void> setDirectoryAuto(bool enabled) async {
    if (_disposed || enabled == directoryAuto) return;
    await store.saveProviderDirectoryAuto(enabled);
    if (_disposed) return;
    directoryAuto = enabled;
    notifyListeners();
  }

  late final ReminderScheduler reminders;
  List<ReminderRule> reminderRules = const [];
  String themeMode = 'system';
  LocalePreference languagePreference = LocalePreference.chinese;
  bool savingLanguage = false;
  int _languageRevision = 0;
  bool _disposed = false;

  /// A language change is a preference-only write. Do not call mutate/refresh:
  /// those reload domain controllers and would disturb in-flight local drafts.
  Future<void> setLanguage(LocalePreference preference) async {
    if (_disposed || savingLanguage || preference == languagePreference) {
      return;
    }
    _languageRevision++;
    savingLanguage = true;
    notifyListeners();
    try {
      await store.saveLanguagePreference(preference);
      if (_disposed) return;
      languagePreference = preference;
      reminders.languagePreference = preference;
      // Resubmit existing reminder content in the saved language. This does
      // not reload ledger/SSH state, and native failures stay separate.
      unawaited(reminders.reconcile());
    } finally {
      savingLanguage = false;
      if (!_disposed) notifyListeners();
    }
  }

  ReminderRule? reminderFor(String id) =>
      reminderRules.where((r) => r.serverId == id).firstOrNull;

  @override
  void dispose() {
    _disposed = true;
    reminders.removeListener(notifyListeners);
    directory.removeListener(notifyListeners);
    reminders.dispose();
    security.dispose();
    super.dispose();
  }

  final LedgerStore store;
  final DateTime Function() clock;
  List<ServerRecord> records = [];
  List<ServerGroup> groups = [];
  List<ServicePeriod> periods = [];
  List<PaymentRecord> payments = [];
  List<ProviderRecord> providers = const [];
  FxSettings fx = const FxSettings();
  List<ServicePeriod> periodsFor(String serverId) =>
      periods.where((p) => p.serverId == serverId).toList(growable: false);
  bool hasPaymentPeriods(String serverId) =>
      periods.any((p) => p.serverId == serverId && p.paymentId != null);

  /// Whether deleting [payment] may also roll back its renewal: an account
  /// bill always can (nothing to roll back); a server renewal only while its
  /// periods are the tail of the server's term. Unrelated server edits do not
  /// matter (see [canRollbackPayment]).
  bool canUndoPayment(PaymentRecord payment) {
    if (payment.voided) {
      return false;
    }
    if (payment.isAccount) {
      return true;
    }
    return canRollbackPayment(byId(payment.serverId!), periods, payment);
  }

  /// The tail of [server]'s term when its payment was deleted (offered for
  /// repair), else null.
  TermTail? orphanTermFor(ServerRecord server) =>
      orphanTail(server, periods, payments);

  /// Live renewals of [payment]'s server that end after it, oldest first.
  List<PaymentRecord> laterRenewals(PaymentRecord payment) =>
      payments
          .where(
            (p) =>
                !p.voided &&
                !p.isAccount &&
                p.serverId == payment.serverId &&
                p.until!.compareTo(payment.until!) > 0,
          )
          .toList()
        ..sort((a, b) => a.until!.compareTo(b.until!));

  /// Deletes [payment]. With [rollbackRenewal] the renewal is rolled back too;
  /// [expectedServerRevision] is the server revision the user was looking at.
  Future<void> deletePayment(
    PaymentRecord payment, {
    bool rollbackRenewal = false,
    int? expectedServerRevision,
  }) => mutate(
    () => store.deletePayment(
      original: payment,
      rollbackRenewal: rollbackRenewal,
      expectedServerRevision: expectedServerRevision,
    ),
  );

  /// Repairs the term left behind by a deleted payment (see
  /// [LedgerStore.rollbackOrphanTerm]); returns the restored due date.
  Future<LedgerDate> rollbackOrphanTerm(ServerRecord server) => mutate(
    () => store.rollbackOrphanTerm(
      serverId: server.id,
      expectedRevision: server.revision,
    ),
  );

  String search = '';
  ServerFilter filter = ServerFilter.all;
  DueFilter dueFilter = DueFilter.all;
  ServerSort sort = ServerSort.favorites;
  // null = all groups; empty string = ungrouped.
  String? groupFilter;
  bool busy = false;
  bool refreshFailed = false;
  bool get canMutate => !busy && !refreshFailed;
  List<ServerRecord> get active => _index.active;
  List<ServerRecord> get archived => _index.archived;
  LedgerDate get today => LedgerDate.today(clock());
  int? dueIn(ServerRecord s) => _dueIn(s, today);
  static int? _dueIn(ServerRecord s, LedgerDate today) =>
      s.billing == BillingKind.prepaid && s.dueDate != null
      ? today.daysUntil(s.dueDate!)
      : null;
  bool isPending(ServerRecord s) => (dueIn(s) ?? 30) < 30;
  String groupName(String? id, {AppLocalizations? l10n}) =>
      groups.where((g) => g.id == id).firstOrNull?.name ??
      (l10n ?? defaultLocalizations).ungrouped;

  _LedgerIndex? _indexCache;

  /// Lookup tables over [records] and [providers], rebuilt only when either
  /// list is replaced (every refresh), never per access.
  _LedgerIndex get _index {
    final cached = _indexCache;
    if (cached != null &&
        identical(cached.records, records) &&
        identical(cached.providers, providers)) {
      return cached;
    }
    return _indexCache = _LedgerIndex(records, providers);
  }

  /// Servers (active and archived) per local provider id.
  /// Providers without servers are absent. Rebuilt only when [records] change,
  /// so lists of hundreds of providers stay cheap.
  Map<String, ProviderUsage> get providerUsage => _index.usage;

  ProviderRecord? providerFor(ServerRecord server) =>
      _index.providerById[server.providerId];

  ProviderRecord? localProviderForCatalog(String catalogId) =>
      providers.where((p) => p.catalogId == catalogId).firstOrNull;

  DirectoryProvider? directoryProviderFor(ProviderRecord provider) =>
      provider.catalogId == null
      ? null
      : directory.provider(provider.catalogId!);

  String providerNameFor(ServerRecord server, {AppLocalizations? l10n}) {
    return _providerName(providerFor(server), server, l10n);
  }

  // Separate actual provider identity from legacy labels and the unassigned
  // group. A rename must not merge providers or change a drill-down's scope.
  String providerGroupKey(ServerRecord server) => server.providerId == null
      ? 'legacy:${server.vendor.trim().isEmpty || server.vendor.trim() == legacyUnknownVendor ? '' : server.vendor}'
      : 'provider:${server.providerId}';

  ServerRecord? byId(String id) => _index.byId[id];

  (Object, String, ServerFilter, DueFilter, ServerSort, String?, LedgerDate)?
  _visibleKey;
  List<ServerRecord> _visible = const [];

  /// Active servers matching the search, filters and group, in the chosen
  /// order. Cached until the ledger, a filter or the date changes, so the many
  /// reads of one frame (and filter-sheet previews) filter and sort once.
  List<ServerRecord> get visible {
    final key = (_index, search, filter, dueFilter, sort, groupFilter, today);
    if (key != _visibleKey) {
      _visible = _filtered(
        filter: filter,
        dueFilter: dueFilter,
        groupFilter: groupFilter,
      );
      _visibleKey = key;
    }
    return _visible;
  }

  /// How many servers would be listed with another group / due selection
  /// (the filter sheet's "Show N"), without touching the live filters.
  int countMatching({required String? group, required DueFilter due}) =>
      _filtered(
        filter: ServerFilter.all,
        dueFilter: due,
        groupFilter: group,
      ).length;

  List<ServerRecord> _filtered({
    required ServerFilter filter,
    required DueFilter dueFilter,
    required String? groupFilter,
  }) {
    final query = search.trim().toLowerCase();
    // A pasted IPv6 in any spelling also finds its canonical stored form.
    final canonicalQuery = NetAddress.tryParse(query)?.isIpv6 == true
        ? NetAddress.tryParse(query)!.host
        : null;
    final today = this.today;
    final index = _index;
    final result = <ServerRecord>[];
    for (var i = 0; i < index.active.length; i++) {
      final s = index.active[i];
      final days = _dueIn(s, today);
      if ((query.isEmpty ||
              index.searchText[i].contains(query) ||
              (canonicalQuery != null &&
                  index.searchText[i].contains(canonicalQuery))) &&
          (filter != ServerFilter.favorites || s.favorite) &&
          (filter != ServerFilter.pending || (days ?? 30) < 30) &&
          (groupFilter == null || (s.groupId ?? '') == groupFilter) &&
          switch (dueFilter) {
            DueFilter.all => true,
            DueFilter.overdue => days != null && days < 0,
            DueFilter.next30 => days != null && days >= 0 && days < 30,
            DueFilter.unknown =>
              s.billing == BillingKind.unknown ||
                  (s.billing == BillingKind.prepaid && s.dueDate == null),
          }) {
        result.add(s);
      }
    }
    result.sort((a, b) {
      final result = switch (sort) {
        ServerSort.favorites => (b.favorite ? 1 : 0).compareTo(
          a.favorite ? 1 : 0,
        ),
        ServerSort.due => (_dueIn(a, today) ?? 1 << 30).compareTo(
          _dueIn(b, today) ?? 1 << 30,
        ),
        ServerSort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        ServerSort.updated => b.updatedAt.compareTo(a.updatedAt),
      };
      return result != 0 ? result : a.name.compareTo(b.name);
    });
    return result;
  }

  Future<void> refresh() async {
    final languageRevision = _languageRevision;
    // Publish the complete loaded ledger only after every read succeeds.
    final (
      loadedRecords,
      loadedGroups,
      loadedPeriods,
      loadedPayments,
      loadedFx,
      loadedRules,
      (loadedTheme, loadedDirectoryAuto),
      loadedLanguage,
      loadedProviders,
    ) = await (
      store.servers(),
      store.groups(),
      store.servicePeriods(),
      store.payments(),
      store.fxSettings(),
      store.reminderRules(),
      (store.themeMode(), store.providerDirectoryAuto()).wait,
      store.languagePreference(),
      store.providers(),
    ).wait;
    refreshFailed = false;
    providers = List.unmodifiable(loadedProviders);
    directoryAuto = loadedDirectoryAuto;
    periods = List.unmodifiable(loadedPeriods);
    payments = List.unmodifiable(loadedPayments);
    fx = loadedFx;
    reminderRules = List.unmodifiable(loadedRules);
    themeMode = loadedTheme;
    // A slower pre-existing reload must not overwrite a newer preference-only
    // write or publish a pre-commit read while that write is pending.
    if (languageRevision == _languageRevision && !savingLanguage) {
      languagePreference = loadedLanguage;
      reminders.languagePreference = loadedLanguage;
    }
    records = loadedRecords;
    groups = loadedGroups;
    if (groupFilter != null &&
        groupFilter != '' &&
        !groups.any((g) => g.id == groupFilter)) {
      groupFilter = null;
    }
    notifyListeners();
    // Native permission/scheduling errors must never turn a committed ledger
    // mutation into a failed save or block access to local data.
    unawaited(reminders.reconcile());
  }

  Future<T> mutate<T>(Future<T> Function() action) async {
    if (busy) {
      throw LocalizedStateError((l10n) => l10n.serverWaitForOperation);
    }
    if (refreshFailed) {
      throw LocalizedStateError((l10n) => l10n.serverReloadSavedFirst);
    }
    busy = true;
    notifyListeners();
    try {
      final result = await action();
      try {
        await refresh();
      } catch (_) {
        // The write has committed. Return its result, never invite a duplicate
        // submission; the UI exposes a retry notice instead.
        refreshFailed = true;
      }
      return result;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void updateFilters({
    String? query,
    ServerFilter? category,
    DueFilter? due,
    ServerSort? order,
  }) {
    if (query != null) {
      search = query;
    }
    if (category != null) {
      filter = category;
    }
    if (due != null) {
      dueFilter = due;
    }
    if (order != null) {
      sort = order;
    }
    notifyListeners();
  }

  void setGroup(String? id) {
    groupFilter = id;
    notifyListeners();
  }

  void resetFilters() {
    search = '';
    filter = ServerFilter.all;
    dueFilter = DueFilter.all;
    groupFilter = null;
    notifyListeners();
  }
}

/// Lookup tables over one snapshot of the records and providers.
class _LedgerIndex {
  _LedgerIndex(this.records, this.providers)
    : active = List.unmodifiable(records.where((s) => !s.archived)),
      archived = List.unmodifiable(records.where((s) => s.archived)),
      byId = {for (final s in records) s.id: s},
      providerById = {for (final p in providers) p.id: p} {
    final servers = <String, List<ServerRecord>>{};
    for (final s in records) {
      if (s.providerId != null) (servers[s.providerId!] ??= []).add(s);
    }
    usage = {for (final e in servers.entries) e.key: ProviderUsage(e.value)};
  }
  final List<ServerRecord> records;
  final List<ProviderRecord> providers;
  final List<ServerRecord> active;
  final List<ServerRecord> archived;
  final Map<String, ServerRecord> byId;
  final Map<String, ProviderRecord> providerById;
  late final Map<String, ProviderUsage> usage;

  /// Lower-cased search haystack per active server, parallel to [active].
  late final List<String> searchText = [
    for (final s in active)
      '${s.name} ${s.host} ${s.resources?.ip ?? ''} '
              '${s.resources?.ipv6 ?? ''} ${s.resources?.hostname ?? ''} '
              '${s.vendor} ${_providerName(providerById[s.providerId], s, null)} '
              '${s.purpose} ${s.region}'
          .toLowerCase(),
  ];
}

String _providerName(
  ProviderRecord? provider,
  ServerRecord server,
  AppLocalizations? l10n,
) {
  if (provider != null) return provider.name;
  final vendor = server.vendor.trim();
  return vendor.isNotEmpty && vendor != legacyUnknownVendor
      ? server.vendor
      : (l10n ?? defaultLocalizations).providerUiUnspecified;
}

/// What a provider is used for: its servers (active and archived).
class ProviderUsage {
  const ProviderUsage(this.servers);
  final List<ServerRecord> servers;
}
