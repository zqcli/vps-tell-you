import 'dart:ui' show SemanticsValidationResult;

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/form_feedback.dart';
import '../core/value_types.dart';
import 'ledger_controller.dart';
import 'server_record.dart';
import 'server_resource_fields.dart';

class ServerForm extends StatefulWidget {
  const ServerForm({
    super.key,
    required this.controller,
    this.record,
    this.focusHardware = false,
  });
  final LedgerController controller;
  final ServerRecord? record;
  final bool focusHardware;
  @override
  State<ServerForm> createState() => _ServerFormState();
}

class _ServerFormState extends State<ServerForm> {
  final _form = GlobalKey<FormState>();
  final _resources = GlobalKey<ServerResourceFieldsState>();
  late final Map<String, TextEditingController> fields;
  late BillingKind billing;
  late String currency;
  late int cycle;
  String? groupId;
  bool saving = false;
  bool get termsLocked =>
      widget.record != null &&
      widget.controller.hasPaymentPeriods(widget.record!.id);
  @override
  void initState() {
    super.initState();
    final s = widget.record;
    fields = {
      'name': TextEditingController(text: s?.name),
      'vendor': TextEditingController(text: s?.vendor),
      'host': TextEditingController(text: s?.host),
      'region': TextEditingController(text: s?.region),
      'purpose': TextEditingController(text: s?.purpose),
      'os': TextEditingController(text: s?.os),
      'spec': TextEditingController(text: s?.spec),
      'notes': TextEditingController(text: s?.notes),
      'amount': TextEditingController(text: s?.money?.decimal),
      'start': TextEditingController(text: s?.startDate?.toString()),
      'due': TextEditingController(text: s?.dueDate?.toString()),
    };
    billing = s?.billing ?? BillingKind.unknown;
    currency = s?.currency ?? 'USD';
    cycle = s?.cycleMonths ?? 12;
    groupId = s?.groupId;
    if (widget.focusHardware) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final hardwareContext = _resources.currentContext;
        if (hardwareContext != null) {
          Scrollable.ensureVisible(hardwareContext);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  String? _validateField(
    String id,
    String label,
    String? value, {
    bool required = false,
  }) {
    final text = value?.trim() ?? '';
    if (required && text.isEmpty) return '请填写$label';
    if (id == 'amount' &&
        billing != BillingKind.unknown &&
        Money.parseMinor(text) == null) {
      return '请输入有效金额，最多两位小数';
    }
    if ((id == 'start' || id == 'due') &&
        text.isNotEmpty &&
        LedgerDate.tryParse(text) == null) {
      return '请使用有效日期，例如 2026-10-06';
    }
    if (id == 'due' && billing == BillingKind.prepaid) {
      final start = LedgerDate.tryParse(fields['start']!.text.trim());
      final due = LedgerDate.tryParse(text);
      if (start != null && due != null && start.compareTo(due) >= 0) {
        return '到期日必须晚于开始日';
      }
    }
    if (id == 'host' && !ServerRecord.validHost(text)) {
      return '请输入纯 IP 或域名，不含协议、端口或路径';
    }
    return null;
  }

  Widget field(
    String id,
    String label, {
    String? hint,
    bool required = false,
    int max = 80,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      key: ValueKey('field-$id'),
      controller: fields[id],
      enabled: !saving && !(termsLocked && (id == 'start' || id == 'due')),
      maxLines: lines,
      maxLength: max,
      keyboardType: lines > 1 ? TextInputType.multiline : TextInputType.text,
      textInputAction: lines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      autocorrect: id != 'host',
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        errorMaxLines: 4,
      ),
      validator: (value) =>
          _validateField(id, label, value, required: required),
    ),
  );

  Widget select<T>(
    String label,
    T value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?> changed, {
    String? id,
    Map<T, String>? selectedLabels,
    bool compact = false,
    String? shortLabel,
  }) {
    final enabled =
        !saving && !(termsLocked && (label == '计费方式' || label == '付款周期'));
    final dropdown = Semantics(
      label: compact ? label : null,
      child: DropdownButtonFormField<T>(
        key: id == null ? null : ValueKey('field-$id'),
        initialValue: value,
        isExpanded: true,
        iconSize: compact ? 16 : 24,
        isDense: id == null,
        itemHeight: null,
        style: id == null ? null : Theme.of(context).textTheme.bodyMedium,
        selectedItemBuilder: id == null
            ? null
            : (context) => [
                for (final item in items)
                  item.value == value
                      ? selectedLabels == null
                            ? item.child
                            : Semantics(
                                label: compact && item.child is Text
                                    ? (item.child as Text).data
                                    : null,
                                excludeSemantics: compact,
                                child: Text(selectedLabels[value]!),
                              )
                      : const SizedBox.shrink(),
              ],
        decoration: compact
            ? InputDecoration(
                labelText: shortLabel ?? label,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 14,
                ),
                constraints: const BoxConstraints(minHeight: 48),
              )
            : InputDecoration(labelText: label),
        items: items,
        onChanged: enabled ? changed : null,
      ),
    );
    return Padding(
      key: id == null ? null : ValueKey('row-$id'),
      padding: EdgeInsets.only(bottom: compact ? 0 : 18),
      child: dropdown,
    );
  }

  Widget _compactInput(
    String id,
    String label,
    String semanticLabel,
    String? error, {
    bool date = false,
  }) => Semantics(
    label: semanticLabel,
    hint: error,
    validationResult: error == null
        ? SemanticsValidationResult.valid
        : SemanticsValidationResult.invalid,
    child: TextFormField(
      key: ValueKey('field-$id'),
      controller: fields[id],
      enabled: !saving && !(termsLocked && date),
      maxLength: date ? 10 : 13,
      minLines: date ? 1 : null,
      // Soft wrapping preserves the complete date at enlarged text sizes. It
      // never inserts a newline into the stored ISO date or changes parsing.
      maxLines: date ? null : 1,
      style: Theme.of(context).textTheme.bodyMedium,
      keyboardType: date
          ? TextInputType.datetime
          : const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        hintText: date ? 'YYYY-MM-DD' : null,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        counterText: '',
        error: error == null ? null : const SizedBox.shrink(),
      ),
    ),
  );

  Widget _rowError(String error, {String? label}) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null)
            Text(
              '$label：',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          Text(
            error,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ),
    ),
  );

  Widget _feeRow() {
    final amountLabel = billing == BillingKind.metered ? '月费用估算' : '续费金额';
    var currencyWidth = 64.0;
    for (final currency in Money.currencies) {
      final painter = TextPainter(
        text: TextSpan(
          text: currency,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout();
      if (painter.width + 44 > currencyWidth) {
        currencyWidth = painter.width + 44;
      }
      painter.dispose();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: FormField<void>(
        validator: (_) => _validateField(
          'amount',
          amountLabel,
          fields['amount']!.text,
          required: true,
        ),
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              key: const ValueKey('row-fees'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: _compactInput(
                    'amount',
                    '金额',
                    amountLabel,
                    field.errorText,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: currencyWidth,
                  child: select<String>(
                    '原币种',
                    currency,
                    Money.currencies
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    (v) => setState(() => currency = v!),
                    id: 'currency',
                    compact: true,
                    shortLabel: '币种',
                  ),
                ),
                if (billing == BillingKind.prepaid) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 1,
                    child: select<int>(
                      '付款周期',
                      cycle,
                      [1, 3, 6, 12, 24, 36]
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(m == 12 ? '每年' : '每 $m 个月'),
                            ),
                          )
                          .toList(),
                      (v) => setState(() => cycle = v!),
                      id: 'cycle',
                      compact: true,
                      shortLabel: '周期',
                      selectedLabels: const {
                        1: '月',
                        3: '季',
                        6: '半年',
                        12: '年',
                        24: '2年',
                        36: '3年',
                      },
                    ),
                  ),
                ],
              ],
            ),
            if (field.errorText case final error?) _rowError(error),
            const SizedBox(height: 6),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: fields['amount']!,
              builder: (context, value, _) {
                final minor = Money.parseMinor(value.text);
                final amount = minor == null
                    ? ''
                    : '${Money(currency, minor).decimal} $currency · ';
                final period = billing == BillingKind.metered
                    ? '每月费用估算'
                    : '${cycle == 12 ? '每年' : '每 $cycle 个月'}续费金额，实付另记';
                // Keep the complete amount readable even while a narrow
                // single-line editor scrolls its digits at larger text sizes.
                return Text(
                  '$amount$period',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Map<String, String> _dateErrors() {
    final errors = <String, String>{};
    for (final id in ['start', 'due']) {
      final error = _validateField(
        id,
        id == 'start' ? '开始日期' : '结束日期',
        fields[id]!.text,
      );
      if (error != null) {
        errors[id] = error;
      }
    }
    return errors;
  }

  Widget _dateRow() => FormField<void>(
    validator: (_) => _dateErrors().values.firstOrNull,
    builder: (field) {
      final errors = field.hasError ? _dateErrors() : const <String, String>{};
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            key: const ValueKey('row-dates'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _compactInput(
                  'start',
                  '开始日期',
                  '服务开始日（选填）',
                  errors['start'],
                  date: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _compactInput(
                  'due',
                  '结束日期',
                  '服务到期日（选填）',
                  errors['due'],
                  date: true,
                ),
              ),
            ],
          ),
          for (final error in errors.entries)
            _rowError(
              error.value,
              label: error.key == 'start' ? '开始日期' : '结束日期',
            ),
        ],
      );
    },
  );

  Future<void> save() async {
    if (saving) return;
    final invalid = _form.currentState!.validateGranularly();
    final resources = _resources.currentState?.validateAndRead(
      invalidFields: invalid,
    );
    if (invalid.isNotEmpty) {
      revealFirstInvalidField(invalid);
      return;
    }
    if (resources == null) return;
    final old = widget.record;
    final now = widget.controller.clock();
    String text(String key) => fields[key]!.text.trim();
    final s = ServerRecord(
      id: old?.id ?? newLocalId(),
      name: text('name'),
      vendor: text('vendor'),
      host: old == null && text('host').isEmpty
          ? (resources.ip.isNotEmpty ? resources.ip : resources.hostname)
          : text('host'),
      region: text('region'),
      purpose: text('purpose'),
      os: text('os'),
      spec: text('spec') == old?.resources?.specSummary
          ? resources.specSummary
          : text('spec'),
      notes: text('notes'),
      resources: resources,
      groupId: groupId,
      favorite: old?.favorite ?? false,
      billing: billing,
      currency: currency,
      amountMinor: billing == BillingKind.unknown
          ? null
          : Money.parseMinor(text('amount')),
      cycleMonths: cycle,
      startDate: billing == BillingKind.prepaid
          ? LedgerDate.tryParse(text('start'))
          : null,
      dueDate: billing == BillingKind.prepaid
          ? LedgerDate.tryParse(text('due'))
          : null,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
      revision: old?.revision ?? 0,
      isDemo: old?.isDemo ?? false,
      renewalAnchorDate: old?.renewalAnchorDate,
    );
    final error = s.validate();
    if (error != null) {
      showFailure(context, ArgumentError(error));
      return;
    }
    setState(() => saving = true);
    try {
      await widget.controller.mutate(
        () => widget.controller.store.saveServer(s, isNew: old == null),
      );
      if (mounted) Navigator.pop(context, s.id);
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        showFailure(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.record == null ? '手动添加' : '编辑服务器'),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
      body: Form(
        key: _form,
        // This bounded form owns nested resource state. Keep every field
        // mounted so scrolling cannot discard edits or prevent validation.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const InfoNote('名称和厂商必填；硬件和费用可稍后补充。仅保存本地台账，不修改远端。'),
              const SectionTitle('基本资料'),
              field('name', '服务器名称', required: true),
              field('vendor', '厂商', required: true, hint: '例如：搬瓦工 / 自定义厂商'),
              field('host', '主机地址（选填）', hint: '独立保存的 IPv4、IPv6 或域名', max: 253),
              InfoNote(
                widget.record == null
                    ? '留空时采用硬件 IP 或 Hostname；SSH 连接地址另行设置。'
                    : '此地址独立保存，修改硬件不会更改它；SSH 连接地址另行设置。',
              ),
              select<String>('用途分组', groupId ?? '', [
                const DropdownMenuItem(value: '', child: Text('未分组')),
                ...widget.controller.groups.map(
                  (g) => DropdownMenuItem(value: g.id, child: Text(g.name)),
                ),
              ], (v) => setState(() => groupId = v == '' ? null : v)),
              field('purpose', '用途（选填）'),
              field('region', '地区（选填）'),
              field('os', '操作系统（选填）'),
              field('spec', '规格补充（选填）', hint: '例如：CPU 型号、网络带宽', max: 200),
              ServerResourceFields(
                key: _resources,
                initial: widget.record?.resources,
                enabled: !saving,
                importing: false,
                defaultTrafficPeriodMonths: widget.record == null ? 1 : null,
              ),
              const SectionTitle('费用资料'),
              if (termsLocked)
                const InfoNote(
                  '已记录追加服务期，计费方式、周期和日期已锁定。更正请先安全撤销付款；调整续费价或币种不会改写历史实付。',
                ),
              select<BillingKind>(
                '计费方式',
                billing,
                const [
                  DropdownMenuItem(
                    value: BillingKind.unknown,
                    child: Text('费用未知 · 稍后补充'),
                  ),
                  DropdownMenuItem(
                    value: BillingKind.prepaid,
                    child: Text('预付费 · 有服务到期日'),
                  ),
                  DropdownMenuItem(
                    value: BillingKind.metered,
                    child: Text('按量付费 · 月估算'),
                  ),
                ],
                (v) => setState(() => billing = v!),
                id: 'billing',
                selectedLabels: const {
                  BillingKind.unknown: '费用未知',
                  BillingKind.prepaid: '预付费',
                  BillingKind.metered: '按量付费',
                },
              ),
              if (billing != BillingKind.unknown) ...[
                _feeRow(),
                if (billing == BillingKind.prepaid) ...[
                  _dateRow(),
                  const InfoNote('日期选填。结束日期当天不计入服务期；只填结束日期会推算一个付款周期，不填则保留未知。'),
                ],
                const InfoNote(
                  '0 元表示明确免费。费用未知请选“费用未知”。保存原币金额；参考汇率仅用于折算。修改续费价不代表已经付款。',
                ),
              ],
              field('notes', '备注（选填）', max: 4000, lines: 4),
              const InfoNote('不要在备注中保存密码、私钥或令牌；登录凭据请在“密钥与安全”管理。'),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? '正在保存…' : '保存服务器'),
          ),
        ),
      ),
    ),
  );
}
