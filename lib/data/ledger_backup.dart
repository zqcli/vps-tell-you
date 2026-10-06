part of 'ledger_store.dart';

/// Version 1 is deliberately a ledger-only, plaintext interchange format.
/// It cannot reconnect SSH/cloud accounts and never reads the SecretStore.
class LedgerBackupSnapshot {
  LedgerBackupSnapshot._({
    required this.exportedAt,
    required this.groups,
    required this.servers,
    required this.payments,
    required this.servicePeriods,
    required this.fx,
  });

  static const format = 'vps-tell-you-ledger';
  static const version = 1;
  static const maxBytes = 10 * 1024 * 1024;
  static const maxRows = 20000;
  static const exclusions = [
    '密码、私钥、口令、Token、凭据元数据及秘密引用',
    'SSH 配置、主机信任、云账户、云关联与 API 观测',
    '命令片段、服务器备注和付款备注',
    '提醒规则、通知排程及应用偏好（格式 v1）',
  ];
  final String exportedAt;
  final List<Map<String, Object?>> groups, servers, payments, servicePeriods;
  final Map<String, Object?> fx;

  Map<String, int> get counts => Map.unmodifiable({
    'groups': groups.length,
    'servers': servers.length,
    'payments': payments.length,
    'service_periods': servicePeriods.length,
  });

  String encode() => jsonEncode({
    'format': format,
    'version': version,
    'exported_at': exportedAt,
    'groups': groups,
    'servers': servers,
    'payments': payments,
    'service_periods': servicePeriods,
    'fx': fx,
  });

  factory LedgerBackupSnapshot.decode(String source) {
    if (source.length > maxBytes || utf8.encode(source).length > maxBytes) {
      throw const FormatException('备份超过 10 MiB 上限');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (_) {
      throw const FormatException('备份不是有效 JSON');
    }
    return LedgerBackupSnapshot._validated(decoded);
  }

  factory LedgerBackupSnapshot._validated(Object? decoded) {
    final root = _backupObject(decoded, const [
      'format',
      'version',
      'exported_at',
      'groups',
      'servers',
      'payments',
      'service_periods',
      'fx',
    ]);
    if (root['format'] != format ||
        root['version'] is! int ||
        root['version'] != version) {
      throw const FormatException('不支持的台账备份格式或版本');
    }
    _backupInstant(root, 'exported_at');
    List<Map<String, Object?>> rows(String key, List<String> columns) {
      final value = root[key];
      if (value is! List || value.length > maxRows) {
        throw const FormatException('备份集合类型或数量无效');
      }
      final ids = <String>{};
      return List.unmodifiable(
        value.map((item) {
          final row = _backupObject(
            item,
            columns,
            optional: key == 'servers' ? const ['resources_json'] : const [],
          );
          _backupText(row, 'id', max: 160, nonempty: true);
          if (!ids.add(row['id'] as String)) {
            throw const FormatException('备份包含重复记录标识');
          }
          return Map<String, Object?>.unmodifiable(row);
        }),
      );
    }

    final groups = rows('groups', _backupGroupColumns);
    final servers = rows('servers', _backupServerColumns);
    final payments = rows('payments', _backupPaymentColumns);
    final periods = rows('service_periods', _backupPeriodColumns);
    final fx = _backupObject(root['fx'], _backupFxColumns);
    final names = <String>{};
    for (final row in groups) {
      _backupText(row, 'name', max: 40, nonempty: true);
      _backupInt(row, 'position', max: 1000000);
      final name = row['name'] as String;
      // SQLite's built-in NOCASE folds ASCII, not arbitrary Unicode.
      final folded = name.replaceAllMapped(
        RegExp('[A-Z]'),
        (m) => m[0]!.toLowerCase(),
      );
      if (name == '未分组' || name != name.trim() || !names.add(folded)) {
        throw const FormatException('备份分组名称冲突');
      }
    }
    final groupIds = groups.map((r) => r['id']).toSet();
    final byServer = <String, ServerRecord>{};
    for (final row in servers) {
      _backupText(row, 'name', max: 80, nonempty: true);
      _backupText(row, 'vendor', max: 80, nonempty: true);
      _backupText(row, 'host', max: 253);
      for (final key in ['region', 'purpose', 'os', 'spec']) {
        // The existing editor/store does not cap these descriptive fields.
        // Preserve them losslessly; the whole-file byte cap remains enforced.
        _backupText(row, key, max: maxBytes);
      }
      _backupText(row, 'group_id', max: 160, nullable: true, nonempty: true);
      _backupEnum(row, 'billing', const ['unknown', 'prepaid', 'metered']);
      _backupEnum(row, 'currency', Money.currencies);
      _backupInt(row, 'amount_minor', max: Money.maxMinor, nullable: true);
      _backupInt(row, 'cycle_months', min: 1, max: 36);
      _backupInt(row, 'revision');
      _backupInt(row, 'favorite', max: 1);
      _backupInt(row, 'is_demo', max: 1);
      for (final key in ['start_date', 'due_date', 'renewal_anchor_date']) {
        _backupDate(row, key, nullable: true);
      }
      _backupInstant(row, 'created_at');
      _backupInstant(row, 'updated_at');
      _backupInstant(row, 'archived_at', nullable: true);
      if (row['group_id'] != null && !groupIds.contains(row['group_id'])) {
        throw const FormatException('服务器引用不存在的分组');
      }
      _backupText(row, 'resources_json', max: 4096, nullable: true);
      // Strict decoding also prevents private/unknown fields from hitchhiking
      // inside an otherwise whitelisted local resources blob.
      final server = ServerRecord.fromMap({...row, 'notes': ''});
      if (server.validate() != null) {
        throw const FormatException('服务器字段校验失败');
      }
      if (server.billing == BillingKind.prepaid && server.dueDate != null) {
        try {
          renewalDate(server, 0);
        } catch (_) {
          throw const FormatException('续费锚点与到期日不一致');
        }
      }
      byServer[server.id] = server;
    }

    final byPayment = <String, Map<String, Object?>>{};
    final activeUntil = <String>{};
    for (final row in payments) {
      _backupText(row, 'id', max: 128, nonempty: true);
      _backupText(row, 'server_id', max: 160, nullable: true, nonempty: true);
      _backupText(row, 'target_name', max: 80, nonempty: true);
      _backupText(
        row,
        'account_label',
        max: 80,
        nullable: true,
        nonempty: true,
      );
      _backupEnum(row, 'currency', Money.currencies);
      _backupInt(row, 'amount_minor', max: Money.maxMinor);
      _backupInt(row, 'cycle_count', max: 3);
      _backupInt(row, 'applied_server_revision', min: 1, nullable: true);
      _backupDate(row, 'paid_date');
      for (final key in ['from_date', 'until_date', 'previous_due']) {
        _backupDate(row, key, nullable: true);
      }
      _backupInstant(row, 'created_at');
      _backupInstant(row, 'voided_at', nullable: true);
      final from = row['from_date'] as String?,
          until = row['until_date'] as String?;
      if ((from == null) != (until == null) ||
          (from != null && from.compareTo(until!) >= 0)) {
        throw const FormatException('付款服务期无效');
      }
      if (row['server_id'] == null) {
        if (row['account_label'] == null ||
            row['account_label'] != row['target_name'] ||
            row['account_label'] != (row['account_label'] as String).trim() ||
            row['cycle_count'] != 0 ||
            row['previous_due'] != null ||
            row['applied_server_revision'] != null) {
          throw const FormatException('独立账户账单字段不一致');
        }
      } else {
        final server = byServer[row['server_id']];
        if (server == null ||
            row['account_label'] != null ||
            from == null ||
            row['previous_due'] != from ||
            row['cycle_count'] == 0 ||
            row['applied_server_revision'] == null ||
            (row['applied_server_revision'] as int) > server.revision) {
          throw const FormatException('服务器付款关联无效');
        }
        if (row['voided_at'] == null &&
            (server.billing != BillingKind.prepaid ||
                server.dueDate == null ||
                until!.compareTo(server.dueDate.toString()) > 0 ||
                !activeUntil.add(jsonEncode([server.id, until])))) {
          throw const FormatException('有效付款与服务器期限冲突');
        }
      }
      byPayment[row['id'] as String] = row;
    }

    final periodsByServer = <String, List<Map<String, Object?>>>{};
    final periodsByPayment = <String, List<Map<String, Object?>>>{};
    final initialServers = <String>{};
    for (final row in periods) {
      _backupText(row, 'server_id', max: 160, nonempty: true);
      _backupText(row, 'payment_id', max: 128, nonempty: true, nullable: true);
      _backupDate(row, 'start_date');
      _backupDate(row, 'end_date');
      _backupInt(row, 'inferred', max: 1);
      final server = byServer[row['server_id']];
      if (server == null ||
          server.billing != BillingKind.prepaid ||
          server.dueDate == null ||
          (row['start_date'] as String).compareTo(row['end_date'] as String) >=
              0 ||
          (row['end_date'] as String).compareTo(server.dueDate.toString()) >
              0) {
        throw const FormatException('服务期与服务器期限不一致');
      }
      (periodsByServer[server.id] ??= []).add(row);
      final paymentId = row['payment_id'];
      if (paymentId == null) {
        if (!initialServers.add(server.id)) {
          throw const FormatException('同一服务器包含重复初始服务期');
        }
      } else {
        final payment = byPayment[paymentId];
        if (payment == null ||
            payment['server_id'] != server.id ||
            payment['voided_at'] != null ||
            row['inferred'] != 0) {
          throw const FormatException('服务期付款关联无效');
        }
        (periodsByPayment[paymentId as String] ??= []).add(row);
      }
    }
    for (final list in periodsByServer.values) {
      list.sort(
        (a, b) =>
            (a['start_date'] as String).compareTo(b['start_date'] as String),
      );
      for (var i = 1; i < list.length; i++) {
        if ((list[i - 1]['end_date'] as String).compareTo(
              list[i]['start_date'] as String,
            ) >
            0) {
          throw const FormatException('同一服务器存在重叠服务期');
        }
      }
    }
    for (final payment in payments) {
      if (payment['server_id'] == null || payment['voided_at'] != null) {
        continue;
      }
      final list = periodsByPayment[payment['id']] ?? [];
      list.sort(
        (a, b) =>
            (a['start_date'] as String).compareTo(b['start_date'] as String),
      );
      if (list.length != payment['cycle_count'] ||
          list.first['start_date'] != payment['from_date'] ||
          list.last['end_date'] != payment['until_date']) {
        throw const FormatException('有效付款缺少完整服务期');
      }
      final server = byServer[payment['server_id']]!;
      final anchor = server.renewalAnchorDate ?? server.dueDate!;
      for (var i = 0; i < list.length; i++) {
        final start = LedgerDate.tryParse(list[i]['start_date'] as String)!;
        final months =
            (start.year - anchor.year) * 12 + start.month - anchor.month;
        if ((i > 0 && list[i - 1]['end_date'] != list[i]['start_date']) ||
            months < 0 ||
            months % server.cycleMonths != 0 ||
            anchor.addMonths(months) != start ||
            anchor.addMonths(months + server.cycleMonths).toString() !=
                list[i]['end_date']) {
          throw const FormatException('付款服务期与续费周期不一致');
        }
      }
    }
    // Initial periods and every active renewal form the same contiguous chain
    // that the ordinary transaction writer would produce. A truncated backup
    // must not silently discard an initial period or introduce unearned gaps.
    for (final server in byServer.values) {
      if (server.billing != BillingKind.prepaid || server.dueDate == null) {
        continue;
      }
      final chain = periodsByServer[server.id] ?? [];
      final paid = chain.where((r) => r['payment_id'] != null).toList();
      final firstDue = paid.isEmpty
          ? server.dueDate!
          : LedgerDate.tryParse(paid.first['start_date'] as String)!;
      final knownStart = server.startDate;
      final hasStart = knownStart != null && knownStart.compareTo(firstDue) < 0;
      final start = hasStart
          ? knownStart
          : firstDue.addMonths(-server.cycleMonths);
      final initial = chain.where((r) => r['payment_id'] == null).toList();
      if (start.isValid && start.compareTo(firstDue) < 0) {
        if (initial.length != 1 ||
            initial.single['start_date'] != start.toString() ||
            initial.single['end_date'] != firstDue.toString() ||
            initial.single['inferred'] != (hasStart ? 0 : 1)) {
          throw const FormatException('初始服务期缺失或与原始期限不一致');
        }
      } else if (initial.isNotEmpty) {
        throw const FormatException('初始服务期超出有效日期范围');
      }
      for (var i = 1; i < chain.length; i++) {
        if (chain[i - 1]['end_date'] != chain[i]['start_date']) {
          throw const FormatException('有效服务期必须连续');
        }
      }
      if (chain.isNotEmpty &&
          chain.last['end_date'] != server.dueDate.toString()) {
        throw const FormatException('有效服务期未覆盖当前到期日');
      }
    }
    _backupEnum(fx, 'display_currency', Money.currencies);
    for (final key in ['usd_to_cny', 'eur_to_cny']) {
      _backupText(fx, key, max: 18, nullable: true);
    }
    _backupDate(fx, 'rate_date', nullable: true);
    if (FxSettings.fromMap(fx).validate() != null) {
      throw const FormatException('参考汇率无效');
    }
    return LedgerBackupSnapshot._(
      exportedAt: root['exported_at'] as String,
      groups: groups,
      servers: servers,
      payments: payments,
      servicePeriods: periods,
      fx: Map.unmodifiable(fx),
    );
  }
}

class LedgerRestorePreview {
  LedgerRestorePreview(this.snapshot, Iterable<String> conflicts)
    : conflicts = List.unmodifiable(conflicts);
  final LedgerBackupSnapshot snapshot;
  final List<String> conflicts;
  Map<String, int> get counts => snapshot.counts;
  List<String> get exclusions => LedgerBackupSnapshot.exclusions;
  bool get canRestore => conflicts.isEmpty;
}

extension LedgerBackupStore on LedgerStore {
  Future<LedgerBackupSnapshot> exportLedgerBackup() => _db.transaction((
    txn,
  ) async {
    Future<List<Map<String, Object?>>> rows(
      String table,
      List<String> columns,
    ) async => (await txn.query(
      table,
      columns: columns,
      orderBy: 'id',
    )).map((r) => Map<String, Object?>.from(r)).toList();
    final snapshot = LedgerBackupSnapshot._validated({
      'format': LedgerBackupSnapshot.format,
      'version': LedgerBackupSnapshot.version,
      'exported_at': clock().toUtc().toIso8601String(),
      'groups': await rows('server_groups', _backupGroupColumns),
      'servers': await rows('servers', _backupServerColumns),
      'payments': await rows('payments', _backupPaymentColumns),
      'service_periods': await rows('service_periods', _backupPeriodColumns),
      'fx': (await txn.query(
        'finance_settings',
        columns: _backupFxColumns,
        where: 'id = 1',
      )).single,
    });
    if (utf8.encode(snapshot.encode()).length > LedgerBackupSnapshot.maxBytes) {
      throw const FormatException('备份超过 10 MiB 上限');
    }
    return snapshot;
  });

  Future<LedgerRestorePreview> previewLedgerRestore(
    LedgerBackupSnapshot snapshot,
  ) async => LedgerRestorePreview(snapshot, await _backupConflicts(_db));

  Future<void> restoreLedgerBackup(
    LedgerBackupSnapshot snapshot, {
    Future<void> Function(int inserted)? afterInsert,
  }) async {
    // Re-validate before starting a write transaction. Immutable snapshots prevent
    // callers from changing the checked data while the transaction is awaited.
    final checked = LedgerBackupSnapshot.decode(snapshot.encode());
    await _db.transaction((txn) async {
      if ((await _backupConflicts(txn)).isNotEmpty) {
        throw StateError('仅支持恢复到空台账；现有数据未改动');
      }
      var inserted = 0;
      Future<void> insert(String table, Map<String, Object?> row) async {
        await txn.insert(
          table,
          row,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        await afterInsert?.call(++inserted);
      }

      for (final row in checked.groups) {
        await insert('server_groups', row);
      }
      for (final row in checked.servers) {
        await insert('servers', {...row, 'notes': ''});
        // Schema 6 creates the ordinary reminder default on every server insert.
        // Imported records must remain silent until explicitly enabled again.
        await txn.update(
          'reminder_rules',
          {'enabled': 0},
          where: 'server_id = ?',
          whereArgs: [row['id']],
        );
      }
      for (final row in checked.payments) {
        await insert('payments', {
          ...row,
          'note': '',
          'request_fingerprint': _backupPaymentFingerprint(row),
        });
      }
      for (final row in checked.servicePeriods) {
        await insert('service_periods', row);
      }
      // FX is one documented singleton; destination app/notification preferences
      // and any unrelated security records are intentionally left alone.
      final updated = await txn.update(
        'finance_settings',
        checked.fx,
        where: 'id = 1',
      );
      if (updated != 1) throw StateError('参考汇率设置缺失；恢复已回滚');
    });
  }
}

Future<List<String>> _backupConflicts(DatabaseExecutor db) async {
  final conflicts = <String>[];
  for (final entry in const {
    'server_groups': '分组',
    'servers': '服务器（含归档）',
    'payments': '付款（含撤销）',
    'service_periods': '服务期',
  }.entries) {
    if ((await db.query(entry.key, columns: ['id'], limit: 1)).isNotEmpty) {
      conflicts.add('目标台账已有${entry.value}');
    }
  }
  return conflicts;
}

String _backupPaymentFingerprint(Map<String, Object?> row) => jsonEncode(
  row['server_id'] == null
      ? [
          'account',
          row['account_label'],
          row['currency'],
          row['amount_minor'],
          row['paid_date'],
          row['from_date'],
          row['until_date'],
          '',
        ]
      : [
          'server',
          row['server_id'],
          row['currency'],
          row['amount_minor'],
          row['paid_date'],
          row['cycle_count'],
          row['until_date'],
          '',
        ],
);

const _backupGroupColumns = ['id', 'name', 'position'];
const _backupServerColumns = [
  'id',
  'name',
  'vendor',
  'host',
  'region',
  'purpose',
  'os',
  'spec',
  'resources_json',
  'group_id',
  'favorite',
  'billing',
  'currency',
  'amount_minor',
  'cycle_months',
  'start_date',
  'due_date',
  'renewal_anchor_date',
  'archived_at',
  'created_at',
  'updated_at',
  'revision',
  'is_demo',
];
const _backupPaymentColumns = [
  'id',
  'server_id',
  'target_name',
  'account_label',
  'amount_minor',
  'currency',
  'paid_date',
  'from_date',
  'until_date',
  'cycle_count',
  'previous_due',
  'applied_server_revision',
  'created_at',
  'voided_at',
];
const _backupPeriodColumns = [
  'id',
  'server_id',
  'start_date',
  'end_date',
  'inferred',
  'payment_id',
];
const _backupFxColumns = [
  'display_currency',
  'usd_to_cny',
  'eur_to_cny',
  'rate_date',
];

Map<String, Object?> _backupObject(
  Object? value,
  List<String> keys, {
  List<String> optional = const [],
}) {
  if (value is! Map ||
      value.keys.any((k) => k is! String || !keys.contains(k)) ||
      !keys.where((key) => !optional.contains(key)).every(value.containsKey)) {
    throw const FormatException('备份字段缺失、未知或类型错误');
  }
  return Map<String, Object?>.from(value);
}

void _backupText(
  Map<String, Object?> row,
  String key, {
  required int max,
  bool nullable = false,
  bool nonempty = false,
}) {
  final value = row[key];
  if (value == null && nullable) return;
  if (value is! String ||
      value.length > max ||
      (nonempty && value.trim().isEmpty) ||
      value.contains('\u0000')) {
    throw const FormatException('备份文字字段无效');
  }
}

void _backupInt(
  Map<String, Object?> row,
  String key, {
  int min = 0,
  int max = 2147483647,
  bool nullable = false,
}) {
  final value = row[key];
  if (value == null && nullable) return;
  if (value is! int || value < min || value > max) {
    throw const FormatException('备份整数或金额超出范围');
  }
}

void _backupEnum(Map<String, Object?> row, String key, List<String> values) {
  if (row[key] is! String || !values.contains(row[key])) {
    throw const FormatException('备份枚举字段无效');
  }
}

void _backupDate(
  Map<String, Object?> row,
  String key, {
  bool nullable = false,
}) {
  final value = row[key];
  if (value == null && nullable) return;
  if (value is! String || LedgerDate.tryParse(value) == null) {
    throw const FormatException('备份日期无效');
  }
}

void _backupInstant(
  Map<String, Object?> row,
  String key, {
  bool nullable = false,
}) {
  final value = row[key];
  if (value == null && nullable) return;
  if (value is! String ||
      value.length > 32 ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}(\d{3})?Z$')
          .hasMatch(value)) {
    throw const FormatException('备份时间需为规范 UTC 时间');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || parsed.year < 1 || parsed.toIso8601String() != value) {
    throw const FormatException('备份时间无效');
  }
}
