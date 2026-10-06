import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/value_types.dart';
import '../servers/ledger_controller.dart';
import '../servers/refresh_failure_notice.dart';
import '../servers/server_detail.dart';
import '../servers/server_record.dart';
import 'finance_math.dart';
import 'finance_models.dart';
import 'finance_widgets.dart';
import 'fx_page.dart';
import 'payment_pages.dart';

List<ServerRecord> financeScope(
  LedgerController c,
  String? groupId, {
  String? vendor,
}) => c.active
    .where(
      (s) =>
          (groupId == null || (s.groupId ?? '') == groupId) &&
          (vendor == null || s.vendor == vendor),
    )
    .toList();
FinanceAmount remainingAmount(LedgerController c, ServerRecord s) =>
    s.billing == BillingKind.metered
    ? FinanceAmount.notApplicable(s.currency)
    : serverValuation(s, c.periodsFor(s.id), c.today)?.amount ??
          FinanceAmount.unknown(s.currency);
bool incompleteFinance(LedgerController c, ServerRecord s) =>
    s.billing == BillingKind.unknown ||
    s.amountMinor == null ||
    (s.billing == BillingKind.prepaid &&
        (s.dueDate == null ||
            s.dueDate!.compareTo(c.today) <= 0 ||
            c.periodsFor(s.id).isEmpty));

void showFinanceRules(BuildContext context) => showStage(
  context,
  '这些数字如何计算',
  '合计月参考 = 有效预付续费价 ÷ 周期月数 + 按量月估算。预付到期日 ≤ 今天或未知时不计入月参考。\n\n剩余价值按已知服务期间 [开始日, 到期日) 逐期折算当前续费价。未来整期计整价，过期为真实 0；按量不适用，资料缺失为未知。历史实付独立保存。\n\n未来 30 天包含今天，不含第 30 天；已过期项目不补推。六个月为本月起六个自然月，预测从今天开始，不包含按量账单。\n\n近 30 天实付包含今天及前 29 天。全部范围保留归档付款，账户账单只计一次；分组不分摊账户账单。\n\n缺汇率只展示可转换部分，不补 0。原币小计保留。先精确求和，再四舍五入到分，中点远离 0。参考折算不是银行卡扣款额。',
);

class FinancePage extends StatefulWidget {
  const FinancePage({super.key, required this.controller});
  final LedgerController controller;
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  String? groupId;
  bool byVendor = true;
  void detail(
    FinanceMetric metric, {
    String? vendor,
    String? sliceGroup,
    String? label,
  }) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => FinanceDetailPage(
        controller: widget.controller,
        metric: metric,
        groupId: sliceGroup ?? groupId,
        vendor: vendor,
        label: label,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      if (groupId != null &&
          groupId != '' &&
          !c.groups.any((g) => g.id == groupId)) {
        groupId = null;
      }
      final records = financeScope(c, groupId);
      final monthly = aggregateAmounts(
        records.map((s) => monthlyAmount(s, c.today)),
        c.fx,
      );
      final values = aggregateAmounts(
        records.map((s) => remainingAmount(c, s)),
        c.fx,
      );
      final events = renewalEvents(records, c.today, c.today.addDays(30));
      final renewals = aggregateAmounts(events.map((e) => e.amount), c.fx);
      final payments = recentPayments(
        c.payments,
        c.today,
        records: c.records,
        groupId: groupId,
      );
      final paid = aggregateAmounts(
        payments.map((p) => FinanceAmount.money(p.amount)),
        c.fx,
      );
      final forecast = sixMonthForecast(records, c.today, c.fx);
      final maxForecast = forecast.fold<double>(
        0,
        (m, f) => f.total.convertedMinor.toDouble() > m
            ? f.total.convertedMinor.toDouble()
            : m,
      );
      final slices = <String, List<ServerRecord>>{};
      for (final s in records) {
        slices
            .putIfAbsent(byVendor ? s.vendor : s.groupId ?? '', () => [])
            .add(s);
      }
      final ordered = slices.entries.toList()
        ..sort(
          (a, b) =>
              aggregateAmounts(
                b.value.map((s) => monthlyAmount(s, c.today)),
                c.fx,
              ).convertedMinor.compareTo(
                aggregateAmounts(
                  a.value.map((s) => monthlyAmount(s, c.today)),
                  c.fx,
                ).convertedMinor,
              ),
        );
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '费用',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: '付款记录',
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PaymentListPage(controller: c, groupId: groupId),
                  ),
                ),
                icon: const Icon(Icons.receipt_long_outlined),
              ),
              IconButton(
                tooltip: '统计口径',
                onPressed: () => showFinanceRules(context),
                icon: const Icon(Icons.info_outline),
              ),
            ],
          ),
          const InfoNote('每月花多少，还剩多少。'),
          if (c.refreshFailed) RefreshFailureNotice(controller: c),
          DropdownButtonFormField<String>(
            key: ValueKey('finance-group-${groupId ?? 'all'}'),
            initialValue: groupId ?? '*',
            isExpanded: true,
            decoration: const InputDecoration(labelText: '统计范围'),
            items: [
              const DropdownMenuItem(value: '*', child: Text('全部分组')),
              const DropdownMenuItem(value: '', child: Text('未分组')),
              ...c.groups.map(
                (g) => DropdownMenuItem(value: g.id, child: Text(g.name)),
              ),
            ],
            onChanged: (v) => setState(() => groupId = v == '*' ? null : v),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => FxPage(controller: c)),
              ),
              icon: const Icon(Icons.currency_exchange, size: 18),
              label: Text(
                '${c.fx.displayCurrency} 参考 · 手动汇率 ${c.fx.rateDate ?? '未设置'}',
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF1E355B),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '合计费用 · 折合每月',
                  style: TextStyle(color: Color(0xFFCAD5E7), fontSize: 12),
                ),
                const SizedBox(height: 12),
                InkWell(
                  key: const ValueKey('metric-monthly'),
                  onTap: () => detail(FinanceMetric.monthly),
                  child: FinanceTotalView(total: monthly, dark: true),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => detail(FinanceMetric.inventory),
                  child: Text(
                    '在管服务器：${records.length} 台  ›',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const Divider(color: Color(0xFF476087)),
                const SizedBox(height: 16),
                InkWell(
                  key: const ValueKey('metric-value'),
                  onTap: () => detail(FinanceMetric.value),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '总体剩余价值  ›',
                        style: TextStyle(color: Color(0xFFCAD5E7)),
                      ),
                      FinanceTotalView(
                        total: values,
                        dark: true,
                        compact: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '预付摊月 + 按量估算 · 非实际本月账单',
                  style: TextStyle(fontSize: 12, color: Color(0xFFCAD5E7)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _MetricCard(
            title: '未来 30 天预计续费',
            total: renewals,
            note: '${events.length} 笔预付续费 · [今天, 今天 + 30 天)',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => RenewalsPage(controller: c, groupId: groupId),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MetricCard(
            title: '近 30 天已记录实付',
            total: paid,
            note: payments.isEmpty
                ? '尚无已录付款，非完整历史账单'
                : '${payments.length} 笔 · 今天及前 29 天',
            empty: payments.isEmpty,
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentListPage(
                  controller: c,
                  groupId: groupId,
                  recent: true,
                ),
              ),
            ),
          ),
          if (records.any((s) => incompleteFinance(c, s)))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: () => detail(FinanceMetric.incomplete),
                icon: const Icon(Icons.info_outline),
                label: Text(
                  '${records.where((s) => incompleteFinance(c, s)).length} 台费用资料待完善 / 已到期',
                ),
              ),
            ),
          SectionTitle(
            '月费用分布',
            action: Wrap(
              spacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('按厂商'),
                  selected: byVendor,
                  onSelected: (_) => setState(() => byVendor = true),
                ),
                ChoiceChip(
                  label: const Text('按分组'),
                  selected: !byVendor,
                  onSelected: (_) => setState(() => byVendor = false),
                ),
              ],
            ),
          ),
          LedgerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (ordered.isEmpty) const InfoNote('添加费用资料后显示分布。'),
                for (final slice in ordered)
                  Builder(
                    builder: (context) {
                      final total = aggregateAmounts(
                        slice.value.map((s) => monthlyAmount(s, c.today)),
                        c.fx,
                      );
                      final ratio = monthly.convertedMinor.isZero
                          ? 0.0
                          : (total.convertedMinor / monthly.convertedMinor)
                                .toDouble()
                                .clamp(0, 1)
                                .toDouble();
                      final label = byVendor
                          ? slice.key
                          : c.groupName(slice.key);
                      return InkWell(
                        key: ValueKey(
                          'finance-slice-${byVendor ? 'vendor' : 'group'}-${slice.key}',
                        ),
                        onTap: () => detail(
                          FinanceMetric.monthly,
                          vendor: byVendor ? slice.key : null,
                          sliceGroup: byVendor ? null : slice.key,
                          label: label,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$label · ${slice.value.length} 台',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              FinanceTotalView(total: total, compact: true),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: ratio,
                                minHeight: 5,
                                borderRadius: BorderRadius.circular(4),
                                backgroundColor: AppColors.line,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          InfoNote(
            groupId == null
                ? '点击分布查看同一口径的服务器明细。账户账单独立记录，不复制到实例。'
                : '当前分组不分摊账户级实付。点击分布查看明细。',
          ),
          const SectionTitle('本月起六个月 · 预付续费'),
          LedgerCard(
            child: Column(
              children: [
                for (final f in forecast)
                  InkWell(
                    key: ValueKey('forecast-${f.month}'),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RenewalsPage(
                          controller: c,
                          groupId: groupId,
                          month: f.month,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${f.month.year} 年 ${f.month.month} 月 · ${f.events.length} 笔',
                          ),
                          Text(
                            '${f.total.formatted} ${c.fx.displayCurrency}${f.total.missingFx > 0 ? ' · 缺汇率 ${f.total.missingFx} 项' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 7),
                          LinearProgressIndicator(
                            value: maxForecast <= 0
                                ? 0
                                : (f.total.convertedMinor.toDouble() /
                                          maxForecast)
                                      .clamp(0, 1),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                            backgroundColor: AppColors.line,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const InfoNote(
            '从今天起按当前续费价与原锚点推演，到第七个月月初截止。图表与月度下钻使用同一批事件；不包含按量账单或已过期项目。',
          ),
          OutlinedButton.icon(
            onPressed: c.canMutate
                ? () => Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentForm(controller: c),
                    ),
                  )
                : null,
            icon: const Icon(Icons.add),
            label: const Text('记录账户账单'),
          ),
        ],
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.total,
    required this.note,
    required this.onTap,
    this.empty = false,
  });
  final String title, note;
  final FinanceTotal total;
  final VoidCallback onTap;
  final bool empty;
  @override
  Widget build(BuildContext context) => LedgerCard(
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title  ›',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (empty)
            const Text('—', style: TextStyle(fontSize: 28))
          else
            FinanceTotalView(total: total, compact: true),
          InfoNote(note),
        ],
      ),
    ),
  );
}

enum FinanceMetric { monthly, value, inventory, incomplete }

class FinanceDetailPage extends StatelessWidget {
  const FinanceDetailPage({
    super.key,
    required this.controller,
    required this.metric,
    this.groupId,
    this.vendor,
    this.label,
  });
  final LedgerController controller;
  final FinanceMetric metric;
  final String? groupId, vendor, label;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller;
      var records = financeScope(c, groupId, vendor: vendor);
      if (metric == FinanceMetric.incomplete) {
        records = records.where((s) => incompleteFinance(c, s)).toList();
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(switch (metric) {
            FinanceMetric.monthly => '月费用明细',
            FinanceMetric.value => '剩余价值明细',
            FinanceMetric.inventory => '服务器构成',
            FinanceMetric.incomplete => '费用资料待完善',
          }),
          actions: [
            IconButton(
              tooltip: '统计口径',
              onPressed: () => showFinanceRules(context),
              icon: const Icon(Icons.info_outline),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (c.refreshFailed) RefreshFailureNotice(controller: c),
            InfoNote(
              '${label ?? (groupId == null ? '全部分组' : c.groupName(groupId))} · ${records.length} 台活动服务器',
            ),
            for (final s in records)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LedgerCard(
                  child: InkWell(
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ServerDetail(controller: c, id: s.id),
                      ),
                    ),
                    child: Builder(
                      builder: (context) {
                        final amount = metric == FinanceMetric.value
                            ? remainingAmount(c, s)
                            : monthlyAmount(s, c.today);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text('${s.vendor} · ${c.groupName(s.groupId)}'),
                            const SizedBox(height: 10),
                            Text(
                              '${s.billingLabel} ${s.billing == BillingKind.unknown ? '' : s.currency}',
                            ),
                            Text(
                              amount.known
                                  ? '${amount.formatted} ${amount.currency}${metric == FinanceMetric.value ? ' 剩余价值' : ' / 月参考'}'
                                  : s.billing == BillingKind.metered &&
                                        metric == FinanceMetric.value
                                  ? '按量计费 · 剩余价值不适用'
                                  : '日期 / 费用未知或已到期，未纳入',
                            ),
                            Text(
                              convertedAmount(amount, c.fx),
                              style: const TextStyle(color: AppColors.muted),
                            ),
                            if (s.dueDate != null) Text('服务至 ${s.dueDate}'),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            if (records.isEmpty) const InfoNote('此范围没有服务器。'),
            const InfoNote('“—”是未知或不适用，不代表免费。已知 0 元会明确显示 0.00。'),
          ],
        ),
      );
    },
  );
}

class RenewalsPage extends StatelessWidget {
  const RenewalsPage({
    super.key,
    required this.controller,
    this.groupId,
    this.month,
  });
  final LedgerController controller;
  final String? groupId;
  final LedgerDate? month;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller;
      final records = financeScope(c, groupId);
      final forecast = sixMonthForecast(records, c.today, c.fx);
      final events = month == null
          ? renewalEvents(records, c.today, c.today.addDays(30))
          : forecast.where((f) => f.month == month).firstOrNull?.events ??
                <RenewalEvent>[];
      final total = aggregateAmounts(events.map((e) => e.amount), c.fx);
      final expired = month == null
          ? records.where(
              (s) =>
                  s.billing == BillingKind.prepaid &&
                  s.dueDate != null &&
                  s.dueDate!.compareTo(c.today) < 0,
            )
          : <ServerRecord>[];
      return Scaffold(
        appBar: AppBar(
          title: Text(
            month == null
                ? '未来 30 天续费安排'
                : '${month!.year} 年 ${month!.month} 月续费',
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (c.refreshFailed) RefreshFailureNotice(controller: c),
            LedgerCard(child: FinanceTotalView(total: total)),
            InfoNote(
              '${events.length} 笔 · ${groupId == null ? '全部分组' : c.groupName(groupId)} · 按当前续费价预测，不代表已付款。',
            ),
            for (final e in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LedgerCard(
                  child: InkWell(
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ServerDetail(controller: c, id: e.server.id),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.server.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        Text('${e.date} · ${e.server.cycleMonths} 个月周期'),
                        Text('${e.amount.formatted} ${e.amount.currency}'),
                        Text(convertedAmount(e.amount, c.fx)),
                      ],
                    ),
                  ),
                ),
              ),
            if (events.isEmpty) const InfoNote('此范围没有已知的预付续费。'),
            if (expired.isNotEmpty) ...[
              const SectionTitle('已过期 · 先核实'),
              ...expired.map(
                (s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.name),
                  subtitle: Text('${s.dueDate} 已过期，不推断停机'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServerDetail(controller: c, id: s.id),
                    ),
                  ),
                ),
              ),
            ],
            const InfoNote('按量账单单独核对，不产生预付续费事件。'),
            OutlinedButton(
              onPressed: c.canMutate
                  ? () => Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentForm(controller: c),
                      ),
                    )
                  : null,
              child: const Text('记录账户账单'),
            ),
          ],
        ),
      );
    },
  );
}
