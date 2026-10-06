import 'package:flutter/foundation.dart';

import '../cloud/cloud_controller.dart';
import '../core/value_types.dart';
import '../data/ledger_store.dart';
import '../finance/finance_models.dart';
import '../security/security_controller.dart';
import 'server_record.dart';

enum ServerFilter { all, favorites, pending }

enum DueFilter { all, overdue, next30, unknown }

enum ServerSort { favorites, due, name, updated }

class LedgerController extends ChangeNotifier {
  LedgerController(
    this.store, {
    DateTime Function()? clock,
    SecurityController? security,
    CloudController? cloud,
  }) : clock = clock ?? DateTime.now,
       security = security ?? SecurityController(store: store) {
    this.cloud =
        cloud ?? CloudController(store: store, secrets: this.security.secrets);
    this.cloud.addListener(_cloudChanged);
  }
  final SecurityController security;
  late final CloudController cloud;

  void _cloudChanged() => notifyListeners();

  @override
  void dispose() {
    cloud.removeListener(_cloudChanged);
    cloud.dispose();
    security.dispose();
    super.dispose();
  }

  final LedgerStore store;
  final DateTime Function() clock;
  List<ServerRecord> records = [];
  List<ServerGroup> groups = [];
  List<ServicePeriod> periods = [];
  List<PaymentRecord> payments = [];
  FxSettings fx = const FxSettings();
  List<ServicePeriod> periodsFor(String serverId) =>
      periods.where((p) => p.serverId == serverId).toList(growable: false);
  List<PaymentRecord> paymentsFor(String serverId) => payments
      .where((p) => p.serverId == serverId && !p.voided)
      .toList(growable: false);
  bool hasPaymentPeriods(String serverId) =>
      periods.any((p) => p.serverId == serverId && p.paymentId != null);
  bool canUndoPayment(PaymentRecord payment) {
    if (payment.voided) return false;
    if (payment.isAccount) return true;
    final server = byId(payment.serverId!);
    return server != null &&
        !server.archived &&
        server.revision == payment.appliedServerRevision &&
        server.dueDate == payment.until;
  }

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
  String groupName(String? id) =>
      groups.where((g) => g.id == id).firstOrNull?.name ?? '未分组';
  ServerRecord? byId(String id) => records.where((s) => s.id == id).firstOrNull;
  List<ServerRecord> get visible {
    final query = search.trim().toLowerCase();
    final result = active.where((s) {
      final days = dueIn(s);
      return (query.isEmpty ||
              '${s.name} ${s.host} ${s.vendor} ${s.purpose} ${s.region}'
                  .toLowerCase()
                  .contains(query)) &&
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
    // Publish the complete loaded ledger only after every read succeeds.
    final loadedRecords = await store.servers();
    final loadedGroups = await store.groups();
    final loadedPeriods = await store.servicePeriods();
    final loadedPayments = await store.payments();
    final loadedFx = await store.fxSettings();
    await cloud.reload();
    refreshFailed = false;
    periods = List.unmodifiable(loadedPeriods);
    payments = List.unmodifiable(loadedPayments);
    fx = loadedFx;
    records = loadedRecords;
    groups = loadedGroups;
    if (groupFilter != null &&
        groupFilter != '' &&
        !groups.any((g) => g.id == groupFilter)) {
      groupFilter = null;
    }
    notifyListeners();
  }

  /// A cloud write is already committed. Surface a reload failure without
  /// inviting duplicate imports or losing the successful write result.
  Future<void> refreshAfterCloudCommit() async {
    try {
      await refresh();
    } catch (_) {
      refreshFailed = true;
      notifyListeners();
    }
  }

  Future<T> mutate<T>(Future<T> Function() action) async {
    if (busy) throw StateError('请等待当前操作完成');
    if (refreshFailed) throw StateError('请先重新读取已保存的台账');
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
    if (query != null) search = query;
    if (category != null) filter = category;
    if (due != null) dueFilter = due;
    if (order != null) sort = order;
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
