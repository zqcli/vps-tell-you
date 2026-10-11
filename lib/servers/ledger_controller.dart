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
  }) : clock = clock ?? DateTime.now,
       security = security ?? SecurityController(store: store) {
    reminders = ReminderScheduler(
      store,
      platform: reminderPlatform,
      clock: this.clock,
    );
    reminders.addListener(notifyListeners);
  }
  final SecurityController security;
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
  List<PaymentRecord> paymentsFor(String serverId) => payments
      .where((p) => p.serverId == serverId && !p.voided)
      .toList(growable: false);
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
  List<ServerRecord> get active => records.where((s) => !s.archived).toList();
  List<ServerRecord> get archived => records.where((s) => s.archived).toList();
  LedgerDate get today => LedgerDate.today(clock());
  int? dueIn(ServerRecord s) =>
      s.billing == BillingKind.prepaid && s.dueDate != null
      ? today.daysUntil(s.dueDate!)
      : null;
  bool isPending(ServerRecord s) => dueIn(s) != null && dueIn(s)! < 30;
  String groupName(String? id, {AppLocalizations? l10n}) =>
      groups.where((g) => g.id == id).firstOrNull?.name ??
      (l10n ?? defaultLocalizations).ungrouped;
  ProviderRecord? providerFor(ServerRecord server) =>
      providers.where((p) => p.id == server.providerId).firstOrNull;

  String providerNameFor(ServerRecord server, {AppLocalizations? l10n}) {
    final strings = l10n ?? defaultLocalizations;
    final provider = providerFor(server);
    if (provider != null) return provider.name;
    return server.vendor.trim().isNotEmpty &&
            server.vendor.trim() != legacyUnknownVendor
        ? server.vendor
        : strings.providerUiUnspecified;
  }

  // Separate actual provider identity from legacy labels and the unassigned
  // group. A rename must not merge providers or change a drill-down's scope.
  String providerGroupKey(ServerRecord server) => server.providerId == null
      ? 'legacy:${server.vendor.trim().isEmpty || server.vendor.trim() == legacyUnknownVendor ? '' : server.vendor}'
      : 'provider:${server.providerId}';

  ServerRecord? byId(String id) => records.where((s) => s.id == id).firstOrNull;
  List<ServerRecord> get visible {
    final query = search.trim().toLowerCase();
    // A pasted IPv6 in any spelling also finds its canonical stored form.
    final canonicalQuery = NetAddress.tryParse(query)?.isIpv6 == true
        ? NetAddress.tryParse(query)!.host
        : null;
    final result = active.where((s) {
      final days = dueIn(s);
      final text =
          '${s.name} ${s.host} ${s.resources?.ip ?? ''} ${s.resources?.ipv6 ?? ''} '
                  '${s.vendor} ${providerNameFor(s)} ${s.purpose} ${s.region}'
              .toLowerCase();
      return (query.isEmpty ||
              text.contains(query) ||
              (canonicalQuery != null && text.contains(canonicalQuery))) &&
          (filter != ServerFilter.favorites || s.favorite) &&
          (filter != ServerFilter.pending || isPending(s)) &&
          (groupFilter == null || (s.groupId ?? '') == groupFilter) &&
          switch (dueFilter) {
            DueFilter.all => true,
            DueFilter.overdue => days != null && days < 0,
            DueFilter.next30 => days != null && days >= 0 && days < 30,
            DueFilter.unknown =>
              s.billing == BillingKind.unknown ||
                  (s.billing == BillingKind.prepaid && s.dueDate == null),
          };
    }).toList();
    result.sort((a, b) {
      final result = switch (sort) {
        ServerSort.favorites => (b.favorite ? 1 : 0).compareTo(
          a.favorite ? 1 : 0,
        ),
        ServerSort.due => (dueIn(a) ?? 1 << 30).compareTo(dueIn(b) ?? 1 << 30),
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
    final loadedRecords = await store.servers();
    final loadedGroups = await store.groups();
    final loadedPeriods = await store.servicePeriods();
    final loadedPayments = await store.payments();
    final loadedFx = await store.fxSettings();
    final loadedRules = await store.reminderRules();
    final loadedTheme = await store.themeMode();
    final loadedLanguage = await store.languagePreference();
    final loadedProviders = await store.providers();
    refreshFailed = false;
    providers = List.unmodifiable(loadedProviders);
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
