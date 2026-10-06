import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/value_types.dart';
import 'ledger_controller.dart';
import 'server_record.dart';

class ServerForm extends StatefulWidget {
  const ServerForm({super.key, required this.controller, this.record});
  final LedgerController controller;
  final ServerRecord? record;
  @override
  State<ServerForm> createState() => _ServerFormState();
}

class _ServerFormState extends State<ServerForm> {
  final _form = GlobalKey<FormState>();
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
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
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
      keyboardType: id == 'amount'
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
      ),
      validator: (value) {
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
        if (id == 'host' && !ServerRecord.validHost(text)) {
          return '请输入纯 IP 或域名，不含协议、端口或路径';
        }
        return null;
      },
    ),
  );
  Widget select<T>(
    String label,
    T value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: saving || (termsLocked && (label == '计费方式' || label == '付款周期'))
          ? null
          : changed,
    ),
  );

  Future<void> save() async {
    if (saving || !_form.currentState!.validate()) return;
    final old = widget.record;
    final now = widget.controller.clock();
    String text(String key) => fields[key]!.text.trim();
    final s = ServerRecord(
      id: old?.id ?? newLocalId(),
      name: text('name'),
      vendor: text('vendor'),
      host: text('host'),
      region: text('region'),
      purpose: text('purpose'),
      os: text('os'),
      spec: text('spec'),
      notes: text('notes'),
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
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const InfoNote('只保存本地台账，不修改云端实例，也不需要密码或 API Key。'),
            field('name', '服务器名称', required: true),
            field('vendor', '厂商', required: true, hint: '例如：搬瓦工 / 自定义厂商'),
            field('host', 'IP 或域名（选填）', hint: 'IPv4、IPv6 或域名', max: 253),
            select<String>('用途分组', groupId ?? '', [
              const DropdownMenuItem(value: '', child: Text('未分组')),
              ...widget.controller.groups.map(
                (g) => DropdownMenuItem(value: g.id, child: Text(g.name)),
              ),
            ], (v) => setState(() => groupId = v == '' ? null : v)),
            field('purpose', '用途（选填）'),
            field('region', '地区（选填）'),
            field('os', '操作系统（选填）'),
            field('spec', '规格（选填）', max: 200),
            const SectionTitle('费用资料'),
            if (termsLocked)
              const InfoNote(
                '已记录追加服务期，计费方式、周期和日期已锁定。更正请先安全撤销付款；调整续费价或币种不会改写历史实付。',
              ),
            select<BillingKind>('计费方式', billing, const [
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
            ], (v) => setState(() => billing = v!)),
            if (billing != BillingKind.unknown) ...[
              field(
                'amount',
                billing == BillingKind.metered ? '月费用估算' : '续费金额',
                required: true,
                max: 13,
              ),
              select<String>(
                '原币种',
                currency,
                Money.currencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                (v) => setState(() => currency = v!),
              ),
              if (billing == BillingKind.prepaid) ...[
                select<int>(
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
                ),
                field('start', '服务开始日（选填）', hint: 'YYYY-MM-DD', max: 10),
                field('due', '服务到期日（选填）', hint: 'YYYY-MM-DD', max: 10),
                const InfoNote(
                  '到期日是服务截止边界 [开始日, 到期日)。仅有到期日时反推一个日历周期并标注推算；缺少到期日保持未知。',
                ),
              ],
              const InfoNote(
                '0 元表示明确免费。费用未知请选“费用未知”。保存原币金额；参考汇率仅用于折算。修改续费价不代表已经付款。',
              ),
            ],
            field('notes', '备注（选填）', max: 4000, lines: 4),
            const InfoNote('不要在备注中保存密码、私钥或令牌。凭据库将在后续阶段提供。'),
          ],
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
