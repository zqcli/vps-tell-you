import 'dart:math';

import '../core/net_address.dart';
import '../core/value_types.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import 'server_resources.dart';

String newLocalId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

enum BillingKind { unknown, prepaid, metered }

class ServerGroup {
  const ServerGroup({
    required this.id,
    required this.name,
    required this.position,
  });
  final String id;
  final String name;
  final int position;
  factory ServerGroup.fromMap(Map<String, Object?> row) => ServerGroup(
    id: row['id'] as String,
    name: row['name'] as String,
    position: row['position'] as int,
  );
}

/// Editable local ledger fields. Future provider observations must be separate;
/// an API refresh must never replace this object with a provider response.
class ServerRecord {
  const ServerRecord({
    required this.id,
    required this.name,
    required this.vendor,
    required this.createdAt,
    required this.updatedAt,
    this.host = '',
    this.region = '',
    this.purpose = '',
    this.os = '',
    this.spec = '',
    this.resources,
    this.notes = '',
    this.groupId,
    this.providerId,
    this.packageId,
    this.packageSnapshot,
    this.favorite = false,
    this.billing = BillingKind.unknown,
    this.currency = 'USD',
    this.amountMinor,
    this.cycleMonths = 12,
    this.startDate,
    this.dueDate,
    this.renewalAnchorDate,
    this.archivedAt,
    this.revision = 0,
    this.isDemo = false,
  });
  final String id, name, vendor, host, region, purpose, os, spec, notes;
  final String? groupId;
  final String? providerId;

  /// Catalog package chosen for this server and the package JSON at that
  /// moment. Both are set or both are null; the server's own hardware and
  /// billing fields stay the source of truth when the catalog changes.
  final String? packageId, packageSnapshot;
  final ServerResources? resources;
  final bool favorite, isDemo;
  final BillingKind billing;
  final String currency;
  final int? amountMinor;
  final int cycleMonths, revision;
  final LedgerDate? startDate, dueDate, renewalAnchorDate;
  final DateTime createdAt, updatedAt;
  final DateTime? archivedAt;
  bool get archived => archivedAt != null;
  Money? get money =>
      amountMinor == null ? null : Money(currency, amountMinor!);
  String get mark => vendor.isEmpty
      ? 'VPS'
      : vendor.runes.take(2).map(String.fromCharCode).join().toUpperCase();
  String get billingLabel => billingLabelFor(defaultLocalizations);
  String billingLabelFor(AppLocalizations l10n) {
    final amount = money == null
        ? (l10n.localeName.startsWith('zh') ? '—' : '— $currency')
        : l10n.localeName.startsWith('zh')
        ? money!.formatted
        : '${money!.decimal} $currency';
    return switch (billing) {
      BillingKind.unknown => l10n.billingCostUnknown,
      BillingKind.metered => l10n.billingMeteredAmount(amount),
      BillingKind.prepaid =>
        cycleMonths == 12
            ? l10n.billingAnnualAmount(amount)
            : l10n.billingMonthlyAmount(amount, cycleMonths),
    };
  }

  /// The address shown and copied for this server, and the default host of
  /// its SSH/TCP tools: IPv4, else IPv6, else hostname (all hardware fields),
  /// else the legacy `host` column of older records. Empty when none is set.
  String get primaryAddress {
    for (final value in [
      resources?.ip,
      resources?.ipv6,
      resources?.hostname,
      host,
    ]) {
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  /// Legacy `host` column: bare IPv4, IPv6 (zone only on link-local) or a DNS
  /// name. It is no longer edited (the form moves it into the address fields
  /// on save, see [LegacyHost]); it stays valid for older records.
  /// Numeric-looking names stay readable; every connection path re-checks
  /// them strictly.
  static bool validHost(String host) =>
      host.isEmpty ||
      NetAddress.tryParse(host, allowBrackets: false, lenientNames: true) !=
          null;
  String? validate({AppLocalizations? l10n}) {
    l10n ??= defaultLocalizations;
    if (name.trim().isEmpty || name.length > 80) {
      return l10n.serverNameRange;
    }
    if (vendor.length > 80) {
      return l10n.serverVendorRange;
    }
    if (!validHost(host)) {
      return l10n.serverHostFormat;
    }
    final resourceError = resources?.validate(l10n: l10n);
    if (resourceError != null) {
      return resourceError;
    }
    if (notes.length > 4000) {
      return l10n.notesTooLong;
    }
    if (!Money.currencies.contains(currency)) {
      return l10n.serverUnsupportedCurrency;
    }
    if (billing != BillingKind.unknown &&
        (amountMinor == null ||
            amountMinor! < 0 ||
            amountMinor! > Money.maxMinor)) {
      return l10n.serverValidAmount;
    }
    if (![1, 3, 6, 12, 24, 36].contains(cycleMonths)) {
      return l10n.serverValidCycle;
    }
    if ([
      startDate,
      dueDate,
      renewalAnchorDate,
    ].any((d) => d != null && !d.isValid)) {
      return l10n.serverInvalidDate;
    }
    if (startDate != null &&
        dueDate != null &&
        startDate!.compareTo(dueDate!) >= 0) {
      return l10n.serverDueAfterStart;
    }
    return null;
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'vendor': vendor,
    'provider_id': providerId,
    'package_id': packageId,
    'package_snapshot': packageSnapshot,
    'host': host,
    'region': region,
    'purpose': purpose,
    'os': os,
    'spec': spec,
    'resources_json': resources?.encode(),
    'notes': notes,
    'group_id': groupId,
    'favorite': favorite ? 1 : 0,
    'billing': billing.name,
    'currency': currency,
    'amount_minor': amountMinor,
    'cycle_months': cycleMonths,
    'start_date': startDate?.toString(),
    'due_date': dueDate?.toString(),
    'renewal_anchor_date': renewalAnchorDate?.toString(),
    'archived_at': archivedAt?.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
    'is_demo': isDemo ? 1 : 0,
  };
  factory ServerRecord.fromMap(Map<String, Object?> row) => ServerRecord(
    id: row['id'] as String,
    name: row['name'] as String,
    vendor: row['vendor'] as String,
    providerId: row['provider_id'] as String?,
    packageId: row['package_id'] as String?,
    packageSnapshot: row['package_snapshot'] as String?,
    host: row['host'] as String,
    region: row['region'] as String,
    purpose: row['purpose'] as String,
    os: row['os'] as String,
    spec: row['spec'] as String,
    resources: row['resources_json'] == null
        ? null
        : ServerResources.decode(row['resources_json'] as String),
    notes: row['notes'] as String,
    groupId: row['group_id'] as String?,
    favorite: row['favorite'] == 1,
    billing: BillingKind.values.byName(row['billing'] as String),
    currency: row['currency'] as String,
    amountMinor: row['amount_minor'] as int?,
    cycleMonths: row['cycle_months'] as int,
    startDate: row['start_date'] == null
        ? null
        : LedgerDate.tryParse(row['start_date'] as String),
    dueDate: row['due_date'] == null
        ? null
        : LedgerDate.tryParse(row['due_date'] as String),
    renewalAnchorDate: row['renewal_anchor_date'] == null
        ? null
        : LedgerDate.tryParse(row['renewal_anchor_date'] as String),
    archivedAt: row['archived_at'] == null
        ? null
        : DateTime.parse(row['archived_at'] as String),
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    revision: row['revision'] as int? ?? 0,
    isDemo: row['is_demo'] == 1,
  );
}

enum LegacyHostField { ipv4, ipv6, hostname }

/// The legacy `servers.host` value of an older record and the address field
/// it belongs to. The form prefills that field when it is empty and clears
/// `host` on save only once the value is safely stored there; a value that
/// fits no field (zoned IPv6, odd names) simply stays in `host`.
class LegacyHost {
  const LegacyHost._(this.field, this.value);
  final LegacyHostField field;

  /// Canonical spelling (RFC 5952 for IPv6).
  final String value;

  static LegacyHost? of(String host) {
    final text = host.trim();
    if (text.isEmpty) return null;
    final address = NetAddress.tryParse(text, allowBrackets: false);
    if (address != null && address.isIp) {
      if (ServerResources.validIpv4(text)) {
        return LegacyHost._(LegacyHostField.ipv4, address.address);
      }
      if (ServerResources.validIpv6(text)) {
        return LegacyHost._(LegacyHostField.ipv6, address.address);
      }
      return null;
    }
    return ServerResources.validHostname(text)
        ? LegacyHost._(LegacyHostField.hostname, text)
        : null;
  }

  String fieldValue(ServerResources? resources) => switch (field) {
    LegacyHostField.ipv4 => resources?.ip ?? '',
    LegacyHostField.ipv6 => resources?.ipv6 ?? '',
    LegacyHostField.hostname => resources?.hostname ?? '',
  };

  /// Whether [resources] holds this value in its field.
  bool isStoredIn(ServerResources? resources) => fieldValue(resources) == value;

  /// [resources] with the value filled into its (empty) field; unchanged when
  /// the field is already used, even by a different value.
  ServerResources? prefill(ServerResources? resources) =>
      fieldValue(resources).isNotEmpty
      ? resources
      : (resources ?? ServerResources()).withAddress(
          ip: field == LegacyHostField.ipv4 ? value : null,
          ipv6: field == LegacyHostField.ipv6 ? value : null,
          hostname: field == LegacyHostField.hostname ? value : null,
        );
}

/// Specification text for display, search and export: generated from the
/// hardware (`2 vCPU · 2 GiB · 40 GiB`) whenever any of vCPU / memory / disk
/// is known, otherwise the legacy free-text [ServerRecord.spec] of older
/// records. The form stores the same value into `spec` on save.
String serverSpecSummary(ServerRecord server, AppLocalizations l10n) {
  final generated = server.resources?.specSummaryFor(l10n) ?? '';
  return generated.isNotEmpty ? generated : server.spec;
}
