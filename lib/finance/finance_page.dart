import 'package:flutter/material.dart';

import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../core/app_theme.dart';
import '../core/value_types.dart';
import '../servers/ledger_controller.dart';
import '../servers/refresh_failure_notice.dart';
import '../servers/server_detail.dart';
import '../servers/server_record.dart';
import 'calculator_page.dart';
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
  LocalizedText((l10n) => l10n.financeRulesTitle),
  LocalizedText((l10n) => l10n.financeRulesBody),
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
  bool calculatorOpen = false;

  Future<void> openCalculator() async {
    if (calculatorOpen) return;
    calculatorOpen = true;
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CalculatorPage(controller: widget.controller),
        ),
      );
    } finally {
      calculatorOpen = false;
    }
  }

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
      final colors = Theme.of(context).colorScheme;
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
              Expanded(
                child: Text(
                  context.l10n.financeTitle,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: context.l10n.financePayments,
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
                tooltip: context.l10n.financeCalculationRules,
                onPressed: () => showFinanceRules(context),
                icon: const Icon(Icons.info_outline),
              ),
            ],
          ),
          InfoNote(context.l10n.financeOverview),
          if (c.refreshFailed) RefreshFailureNotice(controller: c),
          DropdownButtonFormField<String>(
            key: ValueKey('finance-group-${groupId ?? 'all'}'),
            initialValue: groupId ?? '*',
            isExpanded: true,
            itemHeight: null,
            decoration: InputDecoration(labelText: context.l10n.financeScope),
            items: [
              DropdownMenuItem(
                value: '*',
                child: Builder(
                  builder: (context) => Text(context.l10n.financeAllGroups),
                ),
              ),
              DropdownMenuItem(
                value: '',
                child: Builder(
                  builder: (context) => Text(context.l10n.financeUngrouped),
                ),
              ),
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
                context.l10n.financeFxOverview(
                  c.fx.displayCurrency,
                  c.fx.rateDate?.toString() ?? context.l10n.financeNotSet,
                ),
              ),
            ),
          ),
          LedgerCard(
            key: const ValueKey('finance-summary'),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.financeMonthlyReference,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                InkWell(
                  key: const ValueKey('metric-monthly'),
                  // Keep metadata legible when focus, hover and ripple overlap.
                  highlightColor: Colors.transparent,
                  splashColor: colors.primary.withValues(alpha: .02),
                  focusColor: colors.primary.withValues(alpha: .03),
                  hoverColor: colors.primary.withValues(alpha: .01),
                  onTap: () => detail(FinanceMetric.monthly),
                  child: FinanceTotalView(total: monthly, emphasize: true),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => detail(FinanceMetric.inventory),
                  child: Text(context.l10n.financeManagedCount(records.length)),
                ),
                const Divider(),
                const SizedBox(height: 16),
                InkWell(
                  key: const ValueKey('metric-value'),
                  highlightColor: Colors.transparent,
                  splashColor: colors.primary.withValues(alpha: .02),
                  focusColor: colors.primary.withValues(alpha: .03),
                  hoverColor: colors.primary.withValues(alpha: .01),
                  onTap: () => detail(FinanceMetric.value),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.financeTotalRemaining,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      FinanceTotalView(total: values, compact: true),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  context.l10n.financeMonthlyNotPaid,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LedgerCard(
            key: const ValueKey('finance-calculator-entry'),
            padding: EdgeInsets.zero,
            child: Semantics(
              button: true,
              child: SettingRow(
                icon: Icons.calculate_outlined,
                title: context.l10n.remainingValueCalculator,
                subtitle: context.l10n.calculatorDescription,
                onTap: openCalculator,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MetricCard(
            title: context.l10n.financeUpcomingRenewals,
            total: renewals,
            note: context.l10n.financeRenewalEventNote(events.length),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => RenewalsPage(controller: c, groupId: groupId),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MetricCard(
            title: context.l10n.financeRecentPayments,
            total: paid,
            note: payments.isEmpty
                ? context.l10n.financeUnrecordedNotZero
                : context.l10n.financeRecentPaymentNote(payments.length),
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
                  context.l10n.financeIncompleteCount(
                    records.where((s) => incompleteFinance(c, s)).length,
                  ),
                ),
              ),
            ),
          SectionTitle(
            context.l10n.financeMonthlyDistribution,
            action: Wrap(
              spacing: 6,
              children: [
                ChoiceChip(
                  label: Text(context.l10n.financeByVendor),
                  selected: byVendor,
                  onSelected: (_) => setState(() => byVendor = true),
                ),
                ChoiceChip(
                  label: Text(context.l10n.financeByGroup),
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
                if (ordered.isEmpty)
                  InfoNote(context.l10n.financeDistributionEmpty),
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
                          : c.groupName(slice.key, l10n: context.l10n);
                      return InkWell(
                        key: ValueKey(
                          'finance-slice-${byVendor ? 'vendor' : 'group'}-${slice.key}',
                        ),
                        onTap: () => detail(
                          FinanceMetric.monthly,
                          vendor: byVendor ? slice.key : null,
                          sliceGroup: byVendor ? null : slice.key,
                          label: byVendor ? label : null,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.financeSliceLabel(
                                  label,
                                  slice.value.length,
                                ),
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
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
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
                ? context.l10n.financeDistributionNote
                : context.l10n.financeGroupDistributionNote,
          ),
          SectionTitle(context.l10n.financeSixMonthTitle),
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
                            context.l10n.financeForecastMonth(
                              f.month.year,
                              f.month.month,
                              f.events.length,
                            ),
                          ),
                          Text(
                            context.l10n.financeForecastTotal(
                              f.total.formatted,
                              c.fx.displayCurrency,
                              f.total.missingFx,
                              f.total.unknown,
                            ),
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
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .outlineVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          InfoNote(context.l10n.financeForecastNote),
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
            FinanceMetric.monthly => context.l10n.financeMonthlyDetail,
            FinanceMetric.value => context.l10n.financeValueDetail,
            FinanceMetric.inventory => context.l10n.financeInventoryDetail,
            FinanceMetric.incomplete => context.l10n.financeIncompleteDetail,
          }),
          actions: [
            IconButton(
              tooltip: context.l10n.financeCalculationRules,
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
              context.l10n.financeDetailScope(
                label ??
                    (groupId == null
                        ? context.l10n.financeAllGroups
                        : c.groupName(groupId, l10n: context.l10n)),
                records.length,
              ),
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
                            Text(
                              '${s.vendor} · ${c.groupName(s.groupId, l10n: context.l10n)}',
                            ),
                            const SizedBox(height: 10),
                            Text(
                              context.l10n.localeName.startsWith('zh') &&
                                      s.billing != BillingKind.unknown
                                  ? '${s.billingLabelFor(context.l10n)} ${s.currency}'
                                  : s.billingLabelFor(context.l10n),
                            ),
                            Text(
                              amount.known
                                  ? context.l10n.financeAmountMetric(
                                      amount.formatted,
                                      amount.currency,
                                      metric == FinanceMetric.value
                                          ? 'value'
                                          : 'monthly',
                                    )
                                  : s.billing == BillingKind.metered &&
                                        metric == FinanceMetric.value
                                  ? context.l10n.financeMeteredValueNa
                                  : amount.status == AmountStatus.notApplicable
                                  ? context.l10n.financeExpiredMonthlyExcluded
                                  : context.l10n.financeUnknownAmount,
                            ),
                            Text(
                              convertedAmount(amount, c.fx, l10n: context.l10n),
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            if (s.dueDate != null)
                              Text(
                                context.l10n.financeDueDateValue(
                                  s.dueDate.toString(),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            if (records.isEmpty) InfoNote(context.l10n.financeNoServersInRange),
            InfoNote(context.l10n.financeUnknownZeroNote),
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
                ? context.l10n.financeRenewals30Title
                : context.l10n.financeRenewalsMonthTitle(
                    month!.year,
                    month!.month,
                  ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (c.refreshFailed) RefreshFailureNotice(controller: c),
            LedgerCard(child: FinanceTotalView(total: total)),
            InfoNote(
              context.l10n.financeRenewalsScopeNote(
                events.length,
                groupId == null
                    ? context.l10n.financeAllGroups
                    : c.groupName(groupId, l10n: context.l10n),
              ),
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
                        Text(
                          context.l10n.financeRenewalEventDate(
                            e.date.toString(),
                            e.server.cycleMonths,
                          ),
                        ),
                        Text('${e.amount.formatted} ${e.amount.currency}'),
                        Text(
                          convertedAmount(e.amount, c.fx, l10n: context.l10n),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (events.isEmpty) InfoNote(context.l10n.financeNoKnownRenewals),
            if (expired.isNotEmpty) ...[
              SectionTitle(context.l10n.financeExpiredCheck),
              ...expired.map(
                (s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.name),
                  subtitle: Text(
                    context.l10n.financeExpiredDate(s.dueDate.toString()),
                  ),
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
            InfoNote(context.l10n.financeMeteredRenewalNote),
          ],
        ),
      );
    },
  );
}
