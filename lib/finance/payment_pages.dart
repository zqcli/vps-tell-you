import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/value_types.dart';
import '../servers/ledger_controller.dart';
import '../servers/refresh_failure_notice.dart';
import '../servers/server_record.dart';
import 'finance_math.dart';
import 'finance_models.dart';
import 'finance_widgets.dart';

class PaymentForm extends StatefulWidget {
  const PaymentForm({super.key, required this.controller, this.server});
  final LedgerController controller;

  /// null records an independent account bill, never copied to instances.
  final ServerRecord? server;
  @override
  State<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<PaymentForm> {
  final form = GlobalKey<FormState>();
  final requestId = newLocalId();
  late final Map<String, TextEditingController> fields;
  late String currency;
  int count = 1;
  bool confirmed = false, saving = false;
  String? confirmationError;
  bool get account => widget.server == null;
  @override
  void initState() {
    super.initState();
    final s = widget.server;
    currency = s?.currency ?? widget.controller.fx.displayCurrency;
    fields = {
      'amount': TextEditingController(text: s?.money?.decimal),
      'date': TextEditingController(text: widget.controller.today.toString()),
      'until': TextEditingController(
        text: s == null || !canRenew(s) ? '' : renewalDate(s, 1).toString(),
      ),
      'from': TextEditingController(),
      'account': TextEditingController(),
      'note': TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(
    String id,
    String label, {
    String? hint,
    int lines = 1,
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      key: ValueKey('pay-$id'),
      controller: fields[id],
      enabled: !saving,
      maxLines: lines,
      maxLength: id == 'note'
          ? 1000
          : id == 'account'
          ? 80
          : null,
      keyboardType: id == 'amount'
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
      ),
      validator: (raw) {
        final value = raw!.trim();
        if (id == 'note') return null;
        if (optional && value.isEmpty) return null;
        if (id == 'account') return value.isEmpty ? '请填写账户显示名称' : null;
        if (id == 'amount') {
          return Money.parseMinor(value) == null ? '请输入有效实付金额，0 表示免费' : null;
        }
        final date = LedgerDate.tryParse(value);
        if (date == null) return '请输入有效日期，例如 2026-10-06';
        if (id == 'date' && date.compareTo(widget.controller.today) > 0) {
          return '付款日期不能晚于今天';
        }
        if (id == 'until' &&
            !account &&
            date.toString() != renewalDate(widget.server!, count).toString()) {
          return '所选周期应至 ${renewalDate(widget.server!, count)}';
        }
        return null;
      },
    ),
  );
  Future<void> save() async {
    if (saving) return;
    final valid = form.currentState!.validate();
    setState(() => confirmationError = confirmed ? null : '请确认已完成厂商付款并核对资料');
    if (!valid || !confirmed) return;
    final from = LedgerDate.tryParse(fields['from']!.text.trim());
    final until = LedgerDate.tryParse(fields['until']!.text.trim());
    if (account &&
        ((from == null) != (until == null) ||
            (from != null && from.compareTo(until!) >= 0))) {
      showFailure(context, ArgumentError('账期起止需同时填写，且结束日应晚于开始日'));
      return;
    }
    setState(() => saving = true);
    try {
      final amount = Money(currency, Money.parseMinor(fields['amount']!.text)!);
      final paidDate = LedgerDate.tryParse(fields['date']!.text.trim())!;
      await widget.controller.mutate(
        () => account
            ? widget.controller.store.recordAccountPayment(
                id: requestId,
                accountLabel: fields['account']!.text.trim(),
                amount: amount,
                paidDate: paidDate,
                from: from,
                until: until,
                note: fields['note']!.text.trim(),
              )
            : widget.controller.store.recordPayment(
                id: requestId,
                server: widget.server!,
                amount: amount,
                paidDate: paidDate,
                cycleCount: count,
                until: until!,
                confirmed: confirmed,
                note: fields['note']!.text.trim(),
              ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.refreshFailed
                ? '付款已保存，显示暂未更新，请重新读取。'
                : account
                ? '账户账单已记录一次，实例期限未改变'
                : '付款已记录，服务期与统计已更新',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        showFailure(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.server != null && !canRenew(widget.server!)
      ? Scaffold(
          appBar: AppBar(title: const Text('记录已付款')),
          body: const Padding(
            padding: EdgeInsets.all(20),
            child: InfoNote('当前记录没有可用的续期日期。请核对预付类型、到期日与支持的日期范围。'),
          ),
        )
      : ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => PopScope(
            canPop: !saving,
            child: Scaffold(
              appBar: AppBar(
                title: Text(account ? '记录账户账单' : '记录已付款'),
                actions: [
                  TextButton(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ],
              ),
              body: Form(
                key: form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (widget.controller.refreshFailed)
                      RefreshFailureNotice(controller: widget.controller),
                    if (!account)
                      LedgerCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.server!.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(widget.server!.vendor),
                            const InfoNote('仅本地记账，不向厂商发起支付。'),
                          ],
                        ),
                      ),
                    if (account)
                      const InfoNote(
                        '独立记录整份账户账单，仅计一次。不要求连接云账户，不分摊到实例，也不产生服务期或剩余价值。',
                      ),
                    const SizedBox(height: 18),
                    if (account)
                      field('account', '账户显示名称', hint: '例如：厂商 · 个人账户'),
                    field('amount', '本次实际支付'),
                    DropdownButtonFormField<String>(
                      initialValue: currency,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '实付币种'),
                      items: Money.currencies
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (c) => setState(() => currency = c!),
                    ),
                    const SizedBox(height: 18),
                    field('date', '实际付款日期', hint: 'YYYY-MM-DD'),
                    if (!account) ...[
                      DropdownButtonFormField<int>(
                        initialValue: count,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '本次续费周期数'),
                        items: [1, 2, 3]
                            .where((n) => canRenew(widget.server!, cycles: n))
                            .map(
                              (n) => DropdownMenuItem(
                                value: n,
                                child: Text(
                                  '$n 个周期 · 每周期 ${widget.server!.cycleMonths} 个月',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (n) => setState(() {
                                count = n!;
                                fields['until']!.text = renewalDate(
                                  widget.server!,
                                  count,
                                ).toString();
                                confirmed = false;
                              }),
                      ),
                      InfoNote(
                        '从原到期日 ${widget.server!.dueDate} 延长，保留当前未用时长。日期按原锚点推算。',
                      ),
                      field('until', '新的服务到期日', hint: '按厂商结果核对'),
                      LedgerCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '下次续费价：${widget.server!.billingLabel} ${widget.server!.currency}',
                            ),
                            const InfoNote(
                              '本次实付独立保存，不覆盖续费金额。特殊赠送期请先核对，不以虚构周期记账。',
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      field(
                        'from',
                        '账期开始日（选填）',
                        hint: 'YYYY-MM-DD',
                        optional: true,
                      ),
                      field(
                        'until',
                        '账期结束日（选填）',
                        hint: 'YYYY-MM-DD',
                        optional: true,
                      ),
                    ],
                    const SizedBox(height: 18),
                    field('note', '备注（选填）', lines: 3, optional: true),
                    CheckboxListTile(
                      key: const ValueKey('pay-confirm'),
                      contentPadding: EdgeInsets.zero,
                      value: confirmed,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: saving
                          ? null
                          : (v) => setState(() {
                              confirmed = v!;
                              confirmationError = null;
                            }),
                      title: Text(
                        account
                            ? '我已在厂商完成付款，并核对账单金额与日期。'
                            : '我已在厂商完成付款，并核对实付金额与新的服务到期日。',
                      ),
                    ),
                    if (confirmationError != null)
                      Text(
                        confirmationError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const SizedBox(height: 18),
                    FilledButton(
                      key: const ValueKey('save-payment'),
                      onPressed: saving || !widget.controller.canMutate
                          ? null
                          : save,
                      child: Text(saving ? '正在保存…' : '保存付款记录'),
                    ),
                    const InfoNote('这不是厂商支付回执，不改变自动续费设置。'),
                  ],
                ),
              ),
            ),
          ),
        );
}

class PaymentListPage extends StatefulWidget {
  const PaymentListPage({
    super.key,
    required this.controller,
    this.serverId,
    this.groupId,
    this.recent = false,
  });
  final LedgerController controller;
  final String? serverId, groupId;
  final bool recent;
  @override
  State<PaymentListPage> createState() => _PaymentListPageState();
}

class _PaymentListPageState extends State<PaymentListPage> {
  late bool recent = widget.recent;
  bool showVoided = false;
  late String? serverId = widget.serverId;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final rows = c.payments.where((p) {
        if (!showVoided && p.voided) return false;
        if (serverId != null && p.serverId != serverId) return false;
        if (widget.groupId != null &&
            (p.serverId == null ||
                (c.byId(p.serverId!)?.groupId ?? '') != widget.groupId)) {
          return false;
        }
        final age = p.paidDate.daysUntil(c.today);
        return !recent || (age >= 0 && age < 30);
      }).toList()..sort((a, b) => b.paidDate.compareTo(a.paidDate));
      final counted = rows.where((p) => !p.voided).toList();
      final total = aggregateAmounts(
        counted.map((p) => FinanceAmount.money(p.amount)),
        c.fx,
      );
      return Scaffold(
        appBar: AppBar(title: const Text('付款记录')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (c.refreshFailed) RefreshFailureNotice(controller: c),
            DropdownButtonFormField<String>(
              initialValue: serverId ?? '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: '付款对象'),
              items: [
                const DropdownMenuItem(value: '', child: Text('全部付款记录')),
                ...c.records.map(
                  (s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      '${s.name}${s.archived ? ' · 已归档' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => serverId = v == '' ? null : v),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: [
                FilterChip(
                  label: const Text('近 30 天'),
                  selected: recent,
                  onSelected: (v) => setState(() => recent = v),
                ),
                FilterChip(
                  label: const Text('显示已撤销'),
                  selected: showVoided,
                  onSelected: (v) => setState(() => showVoided = v),
                ),
              ],
            ),
            const SectionTitle('已记录实付 · 原币合计'),
            LedgerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (counted.isEmpty)
                    const Text('— 尚无付款记录')
                  else
                    FinanceTotalView(total: total),
                  InfoNote('${counted.length} 笔有效记录，不代表完整历史账单。已撤销记录不计入。'),
                ],
              ),
            ),
            if (widget.groupId != null)
              InfoNote(
                '当前分组：${c.groupName(widget.groupId)}。不分摊账户账单；历史记录保留归档付款。',
              ),
            const SectionTitle('付款明细'),
            for (final p in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LedgerCard(
                  child: InkWell(
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PaymentDetailPage(controller: c, id: p.id),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p.targetName}${p.voided ? ' · 已撤销' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${p.amount.formatted} ${p.amount.currency}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${p.paidDate} · ${p.serverId == null ? '历史账户账单，只计一次' : '服务至 ${p.until}'}',
                        ),
                        if (p.serverId != null &&
                            c.byId(p.serverId!)?.archived == true)
                          const LedgerBadge('服务器已归档 · 历史实付保留'),
                      ],
                    ),
                  ),
                ),
              ),
            if (rows.isEmpty) const InfoNote('此范围暂无付款记录。请从服务器详情记录续费付款。'),
          ],
        ),
      );
    },
  );
}

class PaymentDetailPage extends StatelessWidget {
  const PaymentDetailPage({
    super.key,
    required this.controller,
    required this.id,
  });
  final LedgerController controller;
  final String id;
  Future<void> undo(BuildContext context, PaymentRecord payment) async {
    final confirmed = await confirmAction(
      context,
      title: '撤销此次本地记录？',
      message: payment.serverId == null
          ? '将此账单标记为已撤销，不向厂商申请退款。'
          : '仅还原本次增加的服务期间与到期日，并将实付标记为已撤销。不会向厂商退款或取消服务。',
      action: '撤销记录',
      dangerous: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await controller.mutate(() => controller.store.undoPayment(id));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('本次本地付款记录已撤销')));
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final p = controller.payments.where((p) => p.id == id).firstOrNull;
      return Scaffold(
        appBar: AppBar(title: const Text('付款详情')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (controller.refreshFailed)
              RefreshFailureNotice(controller: controller),
            if (p == null)
              const InfoNote('记录暂不可用，请返回重新读取')
            else ...[
              LedgerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.targetName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${p.amount.formatted} ${p.amount.currency}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    FinanceLine('付款日', '${p.paidDate}'),
                    FinanceLine(
                      '类型',
                      p.serverId == null
                          ? '账户账单'
                          : '预付续期 · ${p.cycleCount} 个周期',
                    ),
                    FinanceLine(
                      '对应账期 / 服务期',
                      p.from == null ? '未填写' : '${p.from} 至 ${p.until}',
                    ),
                    FinanceLine('备注', p.note.isEmpty ? '未填写' : p.note),
                    FinanceLine('状态', p.voided ? '已撤销，不计入实付统计' : '已记录'),
                  ],
                ),
              ),
              const InfoNote('这是原币历史实付，不随续费价或参考汇率重写。更正需先安全撤销，再重新录入。'),
              if (!p.voided) ...[
                OutlinedButton(
                  onPressed:
                      controller.canMutate && controller.canUndoPayment(p)
                      ? () => undo(context, p)
                      : null,
                  child: const Text('撤销此次记录'),
                ),
                if (!controller.canUndoPayment(p))
                  const InfoNote('资料已改变，请核对。后续编辑、付款或归档后不能用旧记录覆盖现有资料。'),
              ],
            ],
          ],
        ),
      );
    },
  );
}
