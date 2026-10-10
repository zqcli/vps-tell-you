import 'package:flutter/material.dart';

import '../l10n/locale_preference.dart';
import '../core/app_theme.dart' show showFailure;
import '../core/ui/ui.dart';
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
          (vendor == null || c.providerGroupKey(s) == vendor),
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

/// The ⓘ sheet of the Costs pages: how the numbers are calculated.
void showFinanceRules(BuildContext context, {bool groupScoped = false}) =>
    showAppSheet<void>(
      context,
      builder: (context) {
        final l10n = context.l10n;
        final p = context.palette;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                l10n.financeRulesTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                ),
              ),
            ),
            AppCard(
              child: Text(
                l10n.financeRulesBody,
                style: TextStyle(fontSize: 14, height: 1.65, color: p.text),
              ),
            ),
            FinanceNote(l10n.financeMonthlyNotPaid),
            FinanceNote(
              groupScoped
                  ? l10n.financeGroupDistributionNote
                  : l10n.financeDistributionNote,
            ),
            FinanceNote(l10n.financeForecastNote),
            FinanceNote(l10n.financeUnknownZeroNote),
            const SizedBox(height: 16),
          ],
        );
      },
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
  int forecastIndex = 0;

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

  Future<void> openFx() => showAppModal<void>(
    context,
    builder: (_) => FxPage(controller: widget.controller),
  );

  void open(WidgetBuilder builder) =>
      Navigator.push<void>(context, MaterialPageRoute(builder: builder));

  void openServer(String id) =>
      open((_) => ServerDetail(controller: widget.controller, id: id));

  void detail(
    FinanceMetric metric, {
    String? vendor,
    String? sliceGroup,
    String? label,
  }) => open(
    (_) => FinanceDetailPage(
      controller: widget.controller,
      metric: metric,
      groupId: sliceGroup ?? groupId,
      vendor: vendor,
      label: label,
    ),
  );

  Future<void> pickScope() async {
    final c = widget.controller;
    final l10n = context.l10n;
    final picked = await showAppPicker<String>(
      context,
      title: l10n.financeScope,
      selected: groupId ?? '*',
      options: [
        AppPickerOption(
          key: const ValueKey('finance-group-all'),
          value: '*',
          title: l10n.financeAllGroups,
          icon: Icons.folder_outlined,
          iconColor: AppTints.grey,
        ),
        AppPickerOption(
          key: const ValueKey('finance-group-none'),
          value: '',
          title: l10n.financeUngrouped,
          icon: Icons.folder_off_outlined,
          iconColor: AppTints.grey,
        ),
        for (final g in c.groups)
          AppPickerOption(
            key: ValueKey('finance-group-${g.id}'),
            value: g.id,
            title: g.name,
            icon: Icons.folder_outlined,
            iconColor: AppTints.orange,
          ),
      ],
    );
    if (picked != null && mounted) {
      setState(() => groupId = picked == '*' ? null : picked);
    }
  }

  Future<void> pickCurrency() async {
    final c = widget.controller;
    final fx = c.fx;
    final picked = await showAppPicker<String>(
      context,
      title: context.l10n.financeDisplayCurrency,
      selected: fx.displayCurrency,
      footnote: context.l10n.uiFinanceCurrencyNote,
      options: [
        for (final code in Money.currencies)
          AppPickerOption(
            key: ValueKey('finance-currency-$code'),
            value: code,
            title: '${currencySymbol(code)}  $code',
          ),
      ],
    );
    if (picked == null || picked == fx.displayCurrency || !mounted) return;
    try {
      await c.mutate(
        () => c.store.saveFx(
          FxSettings(
            displayCurrency: picked,
            usdToCny: fx.usdToCny,
            eurToCny: fx.eurToCny,
            rateDate: fx.rateDate,
          ),
        ),
      );
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final l10n = context.l10n;
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
      final incomplete = records.where((s) => incompleteFinance(c, s)).length;
      final scopeLabel = groupId == null
          ? l10n.financeAllGroups
          : groupId == ''
          ? l10n.financeUngrouped
          : c.groupName(groupId, l10n: l10n);
      return AppScaffold(
        title: l10n.financeTitle,
        actions: [
          AppNavButton.icon(
            Icons.currency_exchange,
            key: const ValueKey('finance-fx'),
            tooltip: l10n.financeFxTitle,
            onPressed: openFx,
          ),
          AppNavButton.icon(
            Icons.info_outline,
            tooltip: l10n.financeCalculationRules,
            onPressed: () =>
                showFinanceRules(context, groupScoped: groupId != null),
          ),
        ],
        children: [
          if (c.refreshFailed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: RefreshFailureNotice(controller: c),
            ),
          AppChipRow(
            children: [
              AppChip(
                key: const ValueKey('finance-scope'),
                icon: Icons.folder_outlined,
                label: scopeLabel,
                onTap: pickScope,
              ),
              AppChip(
                key: const ValueKey('finance-currency'),
                label: l10n.uiFinanceDisplayChip(c.fx.displayCurrency),
                onTap: pickCurrency,
              ),
            ],
          ),
          _SummaryCard(
            monthly: monthly,
            values: values,
            renewals: renewals,
            fx: c.fx,
            onMonthly: () => detail(FinanceMetric.monthly),
            onValue: () => detail(FinanceMetric.value),
            onRenewals: () =>
                open((_) => RenewalsPage(controller: c, groupId: groupId)),
            onFx: openFx,
          ),
          if (incomplete > 0 || monthly.missingFx > 0)
            AppBanner(
              key: const ValueKey('finance-incomplete'),
              tone: AppTone.amber,
              icon: Icons.warning_amber_rounded,
              text: [
                if (incomplete > 0) l10n.financeIncompleteCount(incomplete),
                if (monthly.missingFx > 0)
                  l10n.uiFinanceBannerMissingFx(monthly.missingFx),
              ].join(' · '),
              onTap: incomplete > 0
                  ? () => detail(FinanceMetric.incomplete)
                  : openFx,
            ),
          _upcoming(context, c, events),
          _distribution(context, c, records, monthly),
          _forecast(context, c, forecast),
          _tools(context, c, payments.length, paid),
          FinanceNote(
            l10n.uiFinanceFootnote,
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
          ),
        ],
      );
    },
  );

  Widget _upcoming(
    BuildContext context,
    LedgerController c,
    List<RenewalEvent> events,
  ) {
    final l10n = context.l10n;
    return AppSection(
      key: const ValueKey('finance-upcoming'),
      header: l10n.financeUpcomingRenewals,
      footer: l10n.financeRenewalEventNote(events.length),
      children: [
        if (events.isEmpty) AppRow(title: l10n.financeNoKnownRenewals),
        for (final e in events)
          _RenewalRow(
            event: e,
            controller: c,
            onTap: () => openServer(e.server.id),
          ),
      ],
    );
  }

  Widget _distribution(
    BuildContext context,
    LedgerController c,
    List<ServerRecord> records,
    FinanceTotal monthly,
  ) {
    final l10n = context.l10n;
    final p = context.palette;
    final slices = <String, List<ServerRecord>>{};
    for (final s in records) {
      slices
          .putIfAbsent(
            byVendor ? c.providerGroupKey(s) : s.groupId ?? '',
            () => [],
          )
          .add(s);
    }
    final entries = [
      for (final slice in slices.entries)
        (
          slice,
          aggregateAmounts(
            slice.value.map((s) => monthlyAmount(s, c.today)),
            c.fx,
          ),
        ),
    ]..sort((a, b) => b.$2.convertedMinor.compareTo(a.$2.convertedMinor));
    double ratioOf(FinanceTotal total) => monthly.convertedMinor.isZero
        ? 0.0
        : (total.convertedMinor / monthly.convertedMinor)
              .toDouble()
              .clamp(0, 1)
              .toDouble();
    return AppSection(
      header: l10n.financeMonthlyDistribution,
      dividers: false,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: AppSegmented<bool>(
            key: const ValueKey('finance-split'),
            margin: EdgeInsets.zero,
            options: {true: l10n.financeByVendor, false: l10n.financeByGroup},
            value: byVendor,
            onChanged: (v) => setState(() => byVendor = v),
          ),
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Text(
              l10n.financeDistributionEmpty,
              style: TextStyle(fontSize: 14, color: p.text2),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _StackBar(
              ratios: [for (final e in entries) ratioOf(e.$2)],
              colors: [for (var i = 0; i < entries.length; i++) _sliceColor(i)],
            ),
          ),
          for (var i = 0; i < entries.length; i++)
            _sliceRow(context, c, i, entries[i].$1, entries[i].$2, ratioOf),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  static Color _sliceColor(int index) => const [
    AppTints.blue,
    AppTints.orange,
    AppTints.green,
    AppTints.purple,
    AppTints.red,
    AppTints.sky,
    AppTints.teal,
    AppTints.indigo,
    AppTints.slate,
    AppTints.grey,
  ][index % 10];

  Widget _sliceRow(
    BuildContext context,
    LedgerController c,
    int index,
    MapEntry<String, List<ServerRecord>> slice,
    FinanceTotal total,
    double Function(FinanceTotal) ratioOf,
  ) {
    final l10n = context.l10n;
    final p = context.palette;
    final label = byVendor
        ? c.providerNameFor(slice.value.first, l10n: l10n)
        : c.groupName(slice.key, l10n: l10n);
    final ratio = ratioOf(total);
    final partial = total.covered < total.total;
    return Column(
      children: [
        if (index > 0)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 42),
            child: SizedBox(height: .5, child: ColoredBox(color: p.separator)),
          ),
        Material(
          type: MaterialType.transparency,
          child: InkWell(
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _sliceColor(index),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.financeSliceLabel(label, slice.value.length),
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.3,
                            color: p.text,
                          ),
                        ),
                        if (partial)
                          Text(
                            l10n.financeCoverage(
                              total.covered,
                              total.total,
                              total.missingFx,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: p.text2,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    total.formatted,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      total.covered == 0 && total.total > 0
                          ? '—'
                          : '${(ratio * 100).round()}%',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 13,
                        color: p.text2,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _forecast(
    BuildContext context,
    LedgerController c,
    List<ForecastMonth> forecast,
  ) {
    final l10n = context.l10n;
    final selected = forecast[forecastIndex.clamp(0, forecast.length - 1)];
    return AppSection(
      header: l10n.financeSixMonthTitle,
      children: [
        _ForecastChart(
          forecast: forecast,
          selected: forecast.indexOf(selected),
          onSelect: (i) => setState(() => forecastIndex = i),
        ),
        AppRow(
          key: const ValueKey('forecast-open'),
          title: l10n.financeRenewalsMonthTitle(
            selected.month.year,
            selected.month.month,
          ),
          chevron: true,
          onTap: () => open(
            (_) => RenewalsPage(
              controller: c,
              groupId: groupId,
              month: selected.month,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tools(
    BuildContext context,
    LedgerController c,
    int paymentCount,
    FinanceTotal paid,
  ) {
    final l10n = context.l10n;
    final paidPartial = paymentCount > 0 && paid.covered < paid.total;
    return AppSection(
      header: l10n.uiFinanceToolsHeader,
      children: [
        AppRow(
          key: const ValueKey('finance-recent-payments'),
          icon: Icons.receipt_long_outlined,
          iconColor: AppTints.green,
          title: l10n.financeRecentPayments,
          subtitle: paymentCount == 0
              ? l10n.financeUnrecordedNotZero
              : paidPartial
              ? l10n.financeCoverage(paid.covered, paid.total, paid.missingFx)
              : null,
          value: paymentCount == 0 ? '—' : paid.formatted,
          chevron: true,
          onTap: () => open(
            (_) =>
                PaymentListPage(controller: c, groupId: groupId, recent: true),
          ),
        ),
        _CalculatorEntry(onTap: openCalculator),
      ],
    );
  }
}

/// The remaining-value calculator row. `finance-calculator-entry` is on the
/// row that performs the action; the wrapper only adds button semantics.
class _CalculatorEntry extends StatelessWidget implements AppSectionItem {
  const _CalculatorEntry({required this.onTap});
  final VoidCallback onTap;
  @override
  double get separatorInset => 58;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: AppRow(
      key: const ValueKey('finance-calculator-entry'),
      icon: Icons.calculate_outlined,
      iconColor: AppTints.blue,
      title: context.l10n.remainingValueCalculator,
      subtitle: context.l10n.calculatorDescription,
      chevron: true,
      onTap: onTap,
    ),
  );
}

/// Gradient summary card: monthly reference, coverage, remaining value and
/// 30-day renewals.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.monthly,
    required this.values,
    required this.renewals,
    required this.fx,
    required this.onMonthly,
    required this.onValue,
    required this.onRenewals,
    required this.onFx,
  });
  final FinanceTotal monthly, values, renewals;
  final FxSettings fx;
  final VoidCallback onMonthly, onValue, onRenewals, onFx;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    // Light: brand blue to violet. Dark: the same hues pulled towards the page
    // background.
    final stops = [
      AppTints.blue,
      Color.lerp(AppTints.blue, AppTints.indigo, .5)!,
      Color.lerp(AppTints.blue, AppTints.purple, .55)!,
    ];
    final colors = p.isDark
        ? [for (final c in stops) Color.lerp(c, p.bg, .5)!]
        : stops;
    const label = TextStyle(color: Colors.white, fontSize: 13);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DecoratedBox(
        key: const ValueKey('finance-summary'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
            stops: const [0, .55, 1],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  key: const ValueKey('metric-monthly'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: onMonthly,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.financeMonthlyReference, style: label),
                        const SizedBox(height: 2),
                        FinanceTotalView(
                          total: monthly,
                          emphasize: true,
                          layout: FinanceTotalLayout.hero,
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  key: const ValueKey('finance-fx-status'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: onFx,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.currency_exchange,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.financeFxOverview(
                              fx.displayCurrency,
                              fx.rateDate?.toString() ?? l10n.financeNotSet,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, box) {
                    final valueTile = _SummaryTile(
                      key: const ValueKey('metric-value'),
                      label: l10n.uiFinanceTileRemaining,
                      total: values,
                      onTap: onValue,
                    );
                    final renewalTile = _SummaryTile(
                      key: const ValueKey('metric-renewals'),
                      label: l10n.uiFinanceTileRenewals,
                      total: renewals,
                      onTap: onRenewals,
                    );
                    // Large text or a narrow screen: stack the tiles.
                    final scale = MediaQuery.textScalerOf(context).scale(1);
                    if ((box.maxWidth - 10) / 2 < 110 * scale) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          valueTile,
                          const SizedBox(height: 10),
                          renewalTile,
                        ],
                      );
                    }
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: valueTile),
                          const SizedBox(width: 10),
                          Expanded(child: renewalTile),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    super.key,
    required this.label,
    required this.total,
    required this.onTap,
  });
  final String label;
  final FinanceTotal total;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .16),
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(height: 2),
            FinanceTotalView(total: total, layout: FinanceTotalLayout.tile),
          ],
        ),
      ),
    ),
  );
}

class _DateBlock extends StatelessWidget implements AppLeading {
  const _DateBlock({required this.date, required this.color});
  final LedgerDate date;
  final Color color;
  @override
  double get leadingExtent => 46;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 46,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            date.day.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 19,
              height: 1,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: kTabularFigures,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              context.l10n.uiFinanceMonthShort('${date.month}'),
              maxLines: 1,
              style: TextStyle(fontSize: 11, color: p.text2),
            ),
          ),
        ],
      ),
    );
  }
}

class _RenewalRow extends StatelessWidget implements AppSectionItem {
  const _RenewalRow({
    required this.event,
    required this.controller,
    required this.onTap,
  });
  final RenewalEvent event;
  final LedgerController controller;
  final VoidCallback onTap;
  @override
  double get separatorInset => 74;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final fx = controller.fx;
    final days = controller.today.daysUntil(event.date);
    final tone = days == 0 ? p.red : p.amber;
    final amount = event.amount;
    final converted = amount.currency == fx.displayCurrency
        ? null
        : convertedAmount(amount, fx, l10n: l10n);
    return AppRow.custom(
      key: ValueKey('finance-renewal-${event.server.id}'),
      leading: _DateBlock(date: event.date, color: tone),
      chevron: true,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, box) {
          Widget info() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.server.name,
                style: TextStyle(fontSize: 16, height: 1.3, color: p.text),
              ),
              Text(
                days == 0 ? l10n.serverDueToday : l10n.serverDueInDays(days),
                style: TextStyle(fontSize: 13, height: 1.35, color: tone),
              ),
            ],
          );
          Widget amounts(CrossAxisAlignment align, TextAlign textAlign) =>
              Column(
                crossAxisAlignment: align,
                children: [
                  Text(
                    amount.formatted,
                    textAlign: textAlign,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                  if (converted != null)
                    Text(
                      converted,
                      textAlign: textAlign,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: p.text2,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                ],
              );
          // Large text or a narrow screen: amounts go under the name.
          final stacked =
              box.maxWidth < 200 * MediaQuery.textScalerOf(context).scale(1);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      info(),
                      const SizedBox(height: 4),
                      amounts(CrossAxisAlignment.start, TextAlign.start),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: info()),
                      const SizedBox(width: 8),
                      Flexible(
                        child: amounts(CrossAxisAlignment.end, TextAlign.end),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

/// Horizontal stacked share bar.
class _StackBar extends StatelessWidget {
  const _StackBar({required this.ratios, required this.colors});
  final List<double> ratios;
  final List<Color> colors;
  @override
  Widget build(BuildContext context) {
    final shown = [
      for (var i = 0; i < ratios.length; i++)
        if (ratios[i] > 0) i,
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: shown.isEmpty
            ? ColoredBox(color: context.palette.fill)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var k = 0; k < shown.length; k++) ...[
                    if (k > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: (ratios[shown[k]] * 10000).round().clamp(1, 10000),
                      child: ColoredBox(color: colors[shown[k]]),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Six-month prepaid renewal chart: tappable bars, the selected month's
/// amount and renewal count above. Months whose total is partial (missing
/// exchange rate or unknown amount) are drawn in amber with a gap pill.
class _ForecastChart extends StatelessWidget {
  const _ForecastChart({
    required this.forecast,
    required this.selected,
    required this.onSelect,
  });
  final List<ForecastMonth> forecast;
  final int selected;
  final ValueChanged<int> onSelect;

  static bool _gaps(FinanceTotal t) => t.missingFx > 0 || t.unknown > 0;

  /// Whole major units for the bar caption, or '—' without a convertible part.
  static String _caption(FinanceTotal t) => t.covered == 0 && t.total > 0
      ? '—'
      : (t.convertedMinor / Rational.of(100)).round().toString();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final sel = forecast[selected];
    final maxValue = forecast.fold<double>(
      0,
      (m, f) => f.total.convertedMinor.toDouble() > m
          ? f.total.convertedMinor.toDouble()
          : m,
    );
    final gapParts = [
      if (sel.total.missingFx > 0)
        l10n.uiFinanceGapMissingFx(sel.total.missingFx),
      if (sel.total.unknown > 0) l10n.uiFinanceGapUnknown(sel.total.unknown),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.financeForecastMonth(
                        sel.month.year,
                        sel.month.month,
                        sel.events.length,
                      ),
                      style: TextStyle(fontSize: 13, color: p.text2),
                    ),
                    Text(
                      sel.total.formatted,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: StatusPill(
                  gapParts.isEmpty
                      ? l10n.uiFinanceForecastBasis
                      : gapParts.join(' · '),
                  tone: gapParts.isEmpty ? AppTone.neutral : AppTone.amber,
                  icon: gapParts.isEmpty ? null : Icons.warning_amber_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < forecast.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _ForecastBar(
                      month: forecast[i],
                      ratio: maxValue <= 0
                          ? 0
                          : forecast[i].total.convertedMinor.toDouble() /
                                maxValue,
                      selected: i == selected,
                      caption: _caption(forecast[i].total),
                      gaps: _gaps(forecast[i].total),
                      onTap: () => onSelect(i),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastBar extends StatelessWidget {
  const _ForecastBar({
    required this.month,
    required this.ratio,
    required this.selected,
    required this.caption,
    required this.gaps,
    required this.onTap,
  });
  final ForecastMonth month;
  final double ratio;
  final bool selected, gaps;
  final String caption;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final base = gaps ? p.amberSolid : p.primary;
    final monthLabel = l10n.uiFinanceMonthShort('${month.month.month}');
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: '$monthLabel ${month.total.formatted}',
      onTap: onTap,
      child: GestureDetector(
        key: ValueKey('forecast-${month.month}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Opacity(
              opacity: selected ? 1 : 0,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  caption,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: p.text,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: (ratio.clamp(0, 1) * box.maxHeight).clamp(
                      4,
                      box.maxHeight,
                    ),
                    decoration: BoxDecoration(
                      color: base.withValues(alpha: selected ? 1 : .3),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                        bottom: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                monthLabel,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? p.text : p.text2,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum FinanceMetric { monthly, value, incomplete }

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
      final l10n = context.l10n;
      var records = financeScope(c, groupId, vendor: vendor);
      if (metric == FinanceMetric.incomplete) {
        records = records.where((s) => incompleteFinance(c, s)).toList();
      }
      return AppScaffold(
        largeTitle: false,
        title: switch (metric) {
          FinanceMetric.monthly => l10n.financeMonthlyDetail,
          FinanceMetric.value => l10n.financeValueDetail,
          FinanceMetric.incomplete => l10n.financeIncompleteDetail,
        },
        actions: [
          AppNavButton.icon(
            Icons.info_outline,
            tooltip: l10n.financeCalculationRules,
            onPressed: () =>
                showFinanceRules(context, groupScoped: groupId != null),
          ),
        ],
        children: [
          if (c.refreshFailed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: RefreshFailureNotice(controller: c),
            ),
          FinanceNote(
            l10n.financeDetailScope(
              label ??
                  (groupId == null
                      ? l10n.financeAllGroups
                      : c.groupName(groupId, l10n: l10n)),
              records.length,
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          ),
          AppSection(
            children: [
              if (records.isEmpty) AppRow(title: l10n.financeNoServersInRange),
              for (final s in records) _detailRow(context, c, s),
            ],
          ),
          FinanceNote(
            l10n.financeUnknownZeroNote,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          ),
        ],
      );
    },
  );

  Widget _detailRow(BuildContext context, LedgerController c, ServerRecord s) {
    final l10n = context.l10n;
    final p = context.palette;
    final amount = metric == FinanceMetric.value
        ? remainingAmount(c, s)
        : monthlyAmount(s, c.today);
    final secondary = TextStyle(fontSize: 13, height: 1.4, color: p.text2);
    return AppRow.custom(
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ServerDetail(controller: c, id: s.id),
        ),
      ),
      chevron: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.name,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: p.text,
              ),
            ),
            Text(
              '${c.providerNameFor(s, l10n: l10n)} · ${c.groupName(s.groupId, l10n: l10n)}',
              style: secondary,
            ),
            Text(
              l10n.localeName.startsWith('zh') &&
                      s.billing != BillingKind.unknown
                  ? '${s.billingLabelFor(l10n)} ${s.currency}'
                  : s.billingLabelFor(l10n),
              style: secondary,
            ),
            const SizedBox(height: 6),
            Text(
              amount.known
                  ? l10n.financeAmountMetric(
                      amount.formatted,
                      amount.currency,
                      metric == FinanceMetric.value ? 'value' : 'monthly',
                    )
                  : s.billing == BillingKind.metered &&
                        metric == FinanceMetric.value
                  ? l10n.financeMeteredValueNa
                  : amount.status == AmountStatus.notApplicable
                  ? l10n.financeExpiredMonthlyExcluded
                  : l10n.financeUnknownAmount,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: p.text,
                fontFeatures: kTabularFigures,
              ),
            ),
            Text(convertedAmount(amount, c.fx, l10n: l10n), style: secondary),
            if (s.dueDate != null)
              Text(
                l10n.financeDueDateValue(s.dueDate.toString()),
                style: secondary,
              ),
          ],
        ),
      ),
    );
  }
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
      final l10n = context.l10n;
      final p = context.palette;
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
      void openServer(String id) => Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ServerDetail(controller: c, id: id),
        ),
      );
      final secondary = TextStyle(fontSize: 13, height: 1.4, color: p.text2);
      return AppScaffold(
        largeTitle: false,
        title: month == null
            ? l10n.financeRenewals30Title
            : l10n.financeRenewalsMonthTitle(month!.year, month!.month),
        children: [
          if (c.refreshFailed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: RefreshFailureNotice(controller: c),
            ),
          const SizedBox(height: 12),
          AppCard(child: FinanceTotalView(total: total)),
          FinanceNote(
            l10n.financeRenewalsScopeNote(
              events.length,
              groupId == null
                  ? l10n.financeAllGroups
                  : c.groupName(groupId, l10n: l10n),
            ),
          ),
          AppSection(
            children: [
              if (events.isEmpty) AppRow(title: l10n.financeNoKnownRenewals),
              for (final e in events)
                AppRow.custom(
                  onTap: () => openServer(e.server.id),
                  chevron: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.server.name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: p.text,
                          ),
                        ),
                        Text(
                          l10n.financeRenewalEventDate(
                            e.date.toString(),
                            e.server.cycleMonths,
                          ),
                          style: secondary,
                        ),
                        Text(
                          '${e.amount.formatted} ${e.amount.currency}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: p.text,
                            fontFeatures: kTabularFigures,
                          ),
                        ),
                        Text(
                          convertedAmount(e.amount, c.fx, l10n: l10n),
                          style: secondary,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (expired.isNotEmpty)
            AppSection(
              header: l10n.financeExpiredCheck,
              children: [
                for (final s in expired)
                  AppRow(
                    title: s.name,
                    subtitle: l10n.financeExpiredDate(s.dueDate.toString()),
                    chevron: true,
                    onTap: () => openServer(s.id),
                  ),
              ],
            ),
          FinanceNote(
            l10n.financeMeteredRenewalNote,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          ),
        ],
      );
    },
  );
}
