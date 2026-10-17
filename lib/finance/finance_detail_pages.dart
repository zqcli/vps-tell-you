import 'package:flutter/material.dart';

import '../core/ui/ui.dart';
import '../l10n/locale_preference.dart';
import '../core/value_types.dart';
import '../servers/ledger_controller.dart';
import '../servers/refresh_failure_notice.dart';
import '../servers/server_detail.dart';
import '../servers/server_record.dart';
import 'finance_math.dart';
import 'finance_models.dart';
import 'finance_page.dart' show showFinanceRules;
import 'finance_snapshot.dart';
import 'finance_widgets.dart';

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
      final scope = FinanceScope.of(c, groupId);
      final records = metric == FinanceMetric.incomplete
          ? scope.incomplete
                .where((s) => vendor == null || c.providerGroupKey(s) == vendor)
                .toList()
          : scope.servers(vendor: vendor);
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
              for (final s in records) _detailRow(context, c, scope, s),
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

  Widget _detailRow(
    BuildContext context,
    LedgerController c,
    FinanceScope scope,
    ServerRecord s,
  ) {
    final l10n = context.l10n;
    final amount = metric == FinanceMetric.value
        ? scope.remaining(s)
        : monthlyAmount(s, c.today);
    return _financeRow(
      context,
      name: s.name,
      captions: [
        '${c.providerNameFor(s, l10n: l10n)} · ${c.groupName(s.groupId, l10n: l10n)}',
        l10n.localeName.startsWith('zh') && s.billing != BillingKind.unknown
            ? '${s.billingLabelFor(l10n)} ${s.currency}'
            : s.billingLabelFor(l10n),
      ],
      gap: 6,
      figure: amount.known
          ? l10n.financeAmountMetric(
              amount.formatted,
              amount.currency,
              metric == FinanceMetric.value ? 'value' : 'monthly',
            )
          : s.billing == BillingKind.metered && metric == FinanceMetric.value
          ? l10n.financeMeteredValueNa
          : amount.status == AmountStatus.notApplicable
          ? l10n.financeExpiredMonthlyExcluded
          : l10n.financeUnknownAmount,
      converted: convertedAmount(amount, c.fx, l10n: l10n),
      trailing: s.dueDate == null
          ? null
          : l10n.financeDueDateValue(s.dueDate.toString()),
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ServerDetail(controller: c, id: s.id),
        ),
      ),
    );
  }
}

/// A tappable server row of the Costs detail pages: bold name, then caption
/// lines; [figure] and [converted] are the bold amount and its conversion.
/// [gap] (between the captions and the figure) is only used by the detail row.
Widget _financeRow(
  BuildContext context, {
  required String name,
  required List<String> captions,
  required String figure,
  required String converted,
  String? trailing,
  double gap = 0,
  required VoidCallback onTap,
}) {
  final p = context.palette;
  final secondary = TextStyle(fontSize: 13, height: 1.4, color: p.text2);
  return AppRow.custom(
    onTap: onTap,
    chevron: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: p.text,
            ),
          ),
          for (final caption in captions) Text(caption, style: secondary),
          if (gap > 0) SizedBox(height: gap),
          Text(
            figure,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: p.text,
              fontFeatures: kTabularFigures,
            ),
          ),
          Text(converted, style: secondary),
          if (trailing != null) Text(trailing, style: secondary),
        ],
      ),
    ),
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
      final l10n = context.l10n;
      final scope = FinanceScope.of(c, groupId);
      final events = month == null
          ? scope.events
          : scope.forecast.where((f) => f.month == month).firstOrNull?.events ??
                <RenewalEvent>[];
      final total = aggregateAmounts(events.map((e) => e.amount), c.fx);
      final expired = month == null
          ? scope.records.where(
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
                _financeRow(
                  context,
                  name: e.server.name,
                  captions: [
                    l10n.financeRenewalEventDate(
                      e.date.toString(),
                      e.server.cycleMonths,
                    ),
                  ],
                  figure: '${e.amount.formatted} ${e.amount.currency}',
                  converted: convertedAmount(e.amount, c.fx, l10n: l10n),
                  onTap: () => openServer(e.server.id),
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
