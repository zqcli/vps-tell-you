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
import 'finance_cards.dart';
import 'finance_detail_pages.dart';
import 'finance_models.dart';
import 'finance_snapshot.dart';
import 'finance_widgets.dart';
import 'fx_page.dart';
import 'payment_pages.dart';

List<ServerRecord> financeScope(
  LedgerController c,
  String? groupId, {
  String? vendor,
}) => FinanceScope.of(c, groupId).servers(vendor: vendor);

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
      final scope = FinanceScope.of(c, groupId);
      final monthly = scope.monthly;
      final incomplete = scope.incomplete.length;
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
          FinanceSummaryCard(
            monthly: monthly,
            values: scope.value,
            renewals: scope.renewals,
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
          _upcoming(context, c, scope.events),
          _distribution(context, c, scope),
          _forecast(context, c, scope.forecast),
          _tools(context, c, scope.payments.length, scope.paid),
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
          FinanceRenewalRow(
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
    FinanceScope scope,
  ) {
    final l10n = context.l10n;
    final p = context.palette;
    final monthly = scope.monthly;
    final entries = scope.slices(byVendor: byVendor);
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
            child: FinanceStackBar(
              ratios: [for (final e in entries) ratioOf(e.total)],
              colors: [for (var i = 0; i < entries.length; i++) _sliceColor(i)],
            ),
          ),
          for (var i = 0; i < entries.length; i++)
            _sliceRow(context, c, i, entries[i], ratioOf),
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
    FinanceSlice slice,
    double Function(FinanceTotal) ratioOf,
  ) {
    final total = slice.total;
    final l10n = context.l10n;
    final p = context.palette;
    final label = byVendor
        ? c.providerNameFor(slice.servers.first, l10n: l10n)
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
                          l10n.financeSliceLabel(label, slice.servers.length),
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
        FinanceForecastChart(
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
              : [
                  l10n.r3FinanceRecentSub(paymentCount),
                  if (paidPartial)
                    l10n.financeCoverage(
                      paid.covered,
                      paid.total,
                      paid.missingFx,
                    ),
                ].join('\n'),
          value: paymentCount == 0 ? '—' : paid.formatted,
          chevron: true,
          onTap: () => open(
            (_) => PaymentListPage(
              controller: c,
              groupId: groupId,
              period: PaymentPeriod.month,
            ),
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
