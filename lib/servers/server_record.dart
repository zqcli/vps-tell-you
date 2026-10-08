import 'dart:math';
import 'dart:io';

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

  static bool validHost(String host) =>
      host.isEmpty ||
      InternetAddress.tryParse(host) != null ||
      (host.length <= 253 &&
          RegExp(
            r'^(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.?$',
          ).hasMatch(host));
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
