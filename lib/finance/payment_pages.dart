import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../core/app_theme.dart' show showFailure;
import '../core/ui/ui.dart';
import '../core/value_types.dart';
import '../servers/ledger_controller.dart';
import '../servers/refresh_failure_notice.dart';
import '../servers/server_record.dart';
import 'finance_math.dart';
import 'finance_models.dart';
import 'finance_widgets.dart';
import 'payment_detail_page.dart';

class PaymentForm extends StatefulWidget {
  const PaymentForm({super.key, required this.controller, this.server});
  final LedgerController controller;

  /// null records an independent account bill, never copied to instances.
  final ServerRecord? server;
  @override
  State<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<PaymentForm>
    with LocaleRevalidatingForm<PaymentForm> {
  final requestId = newLocalId();
  late final Map<String, TextEditingController> fields;
  late String currency;
  int count = 1;
  bool confirmed = false, saving = false;
  LocalizedText? confirmationError;
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
  }) => FinanceFieldRow(
    key: ValueKey('pay-$id'),
    controller: fields[id]!,
    label: label,
    hint: hint,
    enabled: !saving,
    stacked: id == 'note',
    maxLines: lines,
    maxLength: id == 'note'
        ? 1000
        : id == 'account'
        ? 80
        : null,
    keyboardType: id == 'amount'
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    check: (raw) {
      final value = raw.trim();
      if (id == 'note') return null;
      if (optional && value.isEmpty) return null;
      if (id == 'account') {
        return value.isEmpty ? context.l10n.financeAccountNameError : null;
      }
      if (id == 'amount') {
        return Money.parseMinor(value) == null
            ? context.l10n.financePaidAmountError
            : null;
      }
      final date = LedgerDate.tryParse(value);
      if (date == null) return context.l10n.financeDateError;
      if (id == 'date' && date.compareTo(widget.controller.today) > 0) {
        return context.l10n.financePaymentFutureError;
      }
      if (id == 'until' &&
          !account &&
          date.toString() != renewalDate(widget.server!, count).toString()) {
        return context.l10n.financeCycleEndError(
          renewalDate(widget.server!, count).toString(),
        );
      }
      return null;
    },
  );

  Future<void> chooseCount() async {
    final server = widget.server!;
    final n = await showAppPicker<int>(
      context,
      title: context.l10n.financeRenewalCount,
      selected: count,
      options: [
        for (final n in [1, 2, 3].where((n) => canRenew(server, cycles: n)))
          AppPickerOption(
            key: ValueKey('pay-count-$n'),
            value: n,
            title: context.l10n.financeCycleCountOption(n, server.cycleMonths),
          ),
      ],
    );
    if (n == null || n == count || !mounted) return;
    setState(() {
      count = n;
      fields['until']!.text = renewalDate(server, count).toString();
      confirmed = false;
    });
  }

  Future<void> save() async {
    if (saving) return;
    final valid = validateForm();
    setState(
      () => confirmationError = confirmed
          ? null
          : LocalizedText((l10n) => l10n.financePaymentConfirmError),
    );
    if (!valid || !confirmed) return;
    final from = LedgerDate.tryParse(fields['from']!.text.trim());
    final until = LedgerDate.tryParse(fields['until']!.text.trim());
    if (account &&
        ((from == null) != (until == null) ||
            (from != null && from.compareTo(until!) >= 0))) {
      showFailure(
        context,
        LocalizedArgumentError((l10n) => l10n.financeBillPeriodError),
      );
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
          content: Builder(
            builder: (context) => Text(
              widget.controller.refreshFailed
                  ? context.l10n.financePaymentSavedRefresh
                  : account
                  ? context.l10n.financeAccountPaymentSaved
                  : context.l10n.financePaymentSaved,
            ),
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final server = widget.server;
    if (server != null && !canRenew(server)) {
      return FinanceModalFrame(
        child: AppScaffold.modal(
          title: l10n.financeRecordPayment,
          actionLabel: l10n.gotIt,
          onAction: () => Navigator.maybePop(context),
          children: [FinanceNote(l10n.financeNoRenewalDate)],
        ),
      );
    }
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final l10n = context.l10n;
        final canSave = !saving && widget.controller.canMutate;
        return PopScope(
          canPop: !saving,
          child: FinanceModalFrame(
            child: Form(
              key: formKey,
              child: AppScaffold.modal(
                title: account
                    ? l10n.financeRecordAccountBill
                    : l10n.financeRecordPayment,
                cancelLabel: l10n.financeCancel,
                actionLabel: l10n.save,
                actionBusy: saving,
                onAction: canSave ? save : null,
                children: [
                  if (widget.controller.refreshFailed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: RefreshFailureNotice(
                        controller: widget.controller,
                      ),
                    ),
                  if (server != null)
                    AppSection(
                      footer: l10n.financeLocalPaymentOnly,
                      children: [
                        AppRow(
                          title: server.name,
                          subtitle: widget.controller.providerNameFor(
                            server,
                            l10n: l10n,
                          ),
                        ),
                      ],
                    )
                  else
                    FinanceNote(
                      l10n.financeAccountBillNote,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    ),
                  AppSection(
                    children: [
                      if (account)
                        field(
                          'account',
                          l10n.financeAccountName,
                          hint: l10n.financeAccountNameHint,
                        ),
                      field('amount', l10n.financePaidAmount),
                      AppFormRow(
                        label: l10n.financePaidCurrency,
                        child: AppSegmented<String>(
                          key: const ValueKey('pay-currency'),
                          compact: true,
                          options: {for (final c in Money.currencies) c: c},
                          value: currency,
                          onChanged: (c) {
                            if (!saving) setState(() => currency = c);
                          },
                        ),
                      ),
                      field('date', l10n.financePaidDate, hint: 'YYYY-MM-DD'),
                    ],
                  ),
                  if (server != null) ...[
                    AppSection(
                      footer: l10n.financeExtendFromDue(
                        server.dueDate.toString(),
                      ),
                      children: [
                        AppFormRow.pick(
                          key: const ValueKey('pay-count'),
                          label: l10n.financeRenewalCount,
                          value: l10n.financeCycleCountOption(
                            count,
                            server.cycleMonths,
                          ),
                          onTap: saving ? null : chooseCount,
                        ),
                        field(
                          'until',
                          l10n.financeNewDue,
                          hint: l10n.financeNewDueHint,
                        ),
                      ],
                    ),
                    AppSection(
                      footer: l10n.financePaymentRenewalNote,
                      children: [
                        AppRow(
                          title: l10n.financeNextRenewalPrice(
                            server.billingLabelFor(l10n),
                            server.currency,
                          ),
                        ),
                      ],
                    ),
                  ] else
                    AppSection(
                      children: [
                        field(
                          'from',
                          l10n.financeBillStart,
                          hint: 'YYYY-MM-DD',
                          optional: true,
                        ),
                        field(
                          'until',
                          l10n.financeBillEnd,
                          hint: 'YYYY-MM-DD',
                          optional: true,
                        ),
                      ],
                    ),
                  AppSection(
                    children: [
                      field(
                        'note',
                        l10n.financeOptionalNote,
                        lines: 3,
                        optional: true,
                      ),
                    ],
                  ),
                  AppSection(
                    footerWidget: confirmationError == null
                        ? null
                        : Text(
                            confirmationError!.messageFor(l10n),
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: context.palette.red,
                            ),
                          ),
                    children: [
                      AppSwitchRow(
                        key: const ValueKey('pay-confirm'),
                        title: account
                            ? l10n.financeConfirmAccountPaid
                            : l10n.financeConfirmServerPaid,
                        value: confirmed,
                        onChanged: saving
                            ? null
                            : (v) => setState(() {
                                confirmed = v;
                                confirmationError = null;
                              }),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: AppButton(
                      key: const ValueKey('save-payment'),
                      label: saving
                          ? l10n.financeSaving
                          : l10n.financeSavePayment,
                      expand: true,
                      onPressed: canSave ? save : null,
                    ),
                  ),
                  FinanceNote(l10n.financeNotReceipt),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Look-back window of the payment list, counted in days including today
/// (a "month" is the same 30-day window as the Costs entry).
enum PaymentPeriod {
  week(7),
  month(30),
  quarter(90),
  halfYear(180),
  year(365),
  all(null);

  const PaymentPeriod(this.days);
  final int? days;

  String label(AppLocalizations l10n) => switch (this) {
    week => l10n.r3FinancePeriodWeek,
    month => l10n.r3FinancePeriodMonth,
    quarter => l10n.r3FinancePeriodQuarter,
    halfYear => l10n.r3FinancePeriodHalfYear,
    year => l10n.r3FinancePeriodYear,
    all => l10n.r3FinancePeriodAll,
  };
}

class PaymentListPage extends StatefulWidget {
  /// [period] is the window the user came from (the Costs entry passes
  /// [PaymentPeriod.month]); the default shows everything.
  const PaymentListPage({
    super.key,
    required this.controller,
    this.serverId,
    this.groupId,
    this.period,
  });
  final LedgerController controller;
  final String? serverId, groupId;
  final PaymentPeriod? period;
  @override
  State<PaymentListPage> createState() => _PaymentListPageState();
}

class _PaymentListPageState extends State<PaymentListPage> {
  late PaymentPeriod period = widget.period ?? PaymentPeriod.all;
  bool showVoided = false;
  late String? serverId = widget.serverId;

  Future<void> chooseTarget() async {
    final c = widget.controller;
    final picked = await showAppPicker<String>(
      context,
      title: context.l10n.financePaymentTarget,
      selected: serverId ?? '',
      options: [
        AppPickerOption(
          key: const ValueKey('payment-target-all'),
          value: '',
          title: context.l10n.financeAllPayments,
        ),
        for (final s in c.records)
          AppPickerOption(
            key: ValueKey('payment-target-${s.id}'),
            value: s.id,
            title: context.l10n.financeArchivedName(
              s.name,
              s.archived ? 'yes' : 'no',
            ),
          ),
      ],
    );
    if (picked != null && mounted) {
      setState(() => serverId = picked == '' ? null : picked);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final l10n = context.l10n;
      final p = context.palette;
      final groupOf = widget.groupId == null
          ? null
          : {for (final s in c.records) s.id: s.groupId ?? ''};
      final rows = c.payments.where((p) {
        if (!showVoided && p.voided) return false;
        if (serverId != null && p.serverId != serverId) return false;
        if (groupOf != null &&
            (p.serverId == null ||
                (groupOf[p.serverId!] ?? '') != widget.groupId)) {
          return false;
        }
        final days = period.days;
        if (days == null) return true;
        final age = p.paidDate.daysUntil(c.today);
        return age >= 0 && age < days;
      }).toList()..sort((a, b) => b.paidDate.compareTo(a.paidDate));
      final counted = rows.where((p) => !p.voided).toList();
      final archivedIds = {
        for (final s in c.records)
          if (s.archived) s.id,
      };
      final total = aggregateAmounts(
        counted.map((p) => FinanceAmount.money(p.amount)),
        c.fx,
      );
      final target = serverId == null ? null : c.byId(serverId!);
      final secondary = TextStyle(fontSize: 13, height: 1.4, color: p.text2);
      return AppScaffold(
        largeTitle: false,
        title: l10n.financePayments,
        children: [
          if (c.refreshFailed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: RefreshFailureNotice(controller: c),
            ),
          AppSection(
            children: [
              AppFormRow.pick(
                key: const ValueKey('payment-target'),
                label: l10n.financePaymentTarget,
                value: target == null
                    ? l10n.financeAllPayments
                    : l10n.financeArchivedName(
                        target.name,
                        target.archived ? 'yes' : 'no',
                      ),
                onTap: chooseTarget,
              ),
            ],
          ),
          if (target != null) OrphanTermBanner(controller: c, server: target),
          AppChipRow(
            children: [
              for (final option in PaymentPeriod.values)
                AppChip(
                  key: ValueKey('payment-period-${option.name}'),
                  label: option.label(l10n),
                  selected: period == option,
                  onTap: () => setState(() => period = option),
                ),
            ],
          ),
          AppChipRow(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            children: [
              AppChip(
                key: const ValueKey('payment-voided'),
                label: l10n.financeShowVoided,
                selected: showVoided,
                onTap: () => setState(() => showVoided = !showVoided),
              ),
            ],
          ),
          AppSection(
            header: l10n.financeRecordedPaidTotal,
            footer: [
              if (period.days != null)
                l10n.financePaymentPeriodRange(
                  c.today.addDays(1 - period.days!).toString(),
                  c.today.toString(),
                ),
              l10n.financeValidPaymentsNote(counted.length),
              if (widget.groupId != null)
                l10n.financePaymentGroupNote(
                  c.groupName(widget.groupId, l10n: l10n),
                ),
            ].join('\n'),
            children: [
              AppRow.custom(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: counted.isEmpty
                      ? Text(
                          l10n.financeNoPayments,
                          style: TextStyle(fontSize: 15, color: p.text2),
                        )
                      : FinanceTotalView(total: total),
                ),
              ),
            ],
          ),
          AppSection(
            header: l10n.financePaymentDetails,
            children: [
              if (rows.isEmpty) AppRow(title: l10n.financeNoPaymentsInRange),
              for (final pay in rows)
                AppRow.custom(
                  key: ValueKey('payment-${pay.id}'),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PaymentDetailPage(controller: c, id: pay.id),
                    ),
                  ),
                  chevron: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                pay.targetName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: p.text,
                                ),
                              ),
                            ),
                            if (pay.voided) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: StatusPill(
                                  l10n.uiFinanceVoidedPill,
                                  tone: AppTone.red,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${pay.amount.formatted} ${pay.amount.currency}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: p.text,
                            fontFeatures: kTabularFigures,
                          ),
                        ),
                        Text(
                          l10n.financePaymentSummary(
                            pay.paidDate.toString(),
                            pay.serverId == null ? 'yes' : 'no',
                            pay.until?.toString() ?? l10n.financeUnknown,
                          ),
                          style: secondary,
                        ),
                        if (archivedIds.contains(pay.serverId)) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: StatusPill(
                                l10n.uiFinanceArchivedPill,
                                tone: AppTone.neutral,
                              ),
                            ),
                          ),
                          Text(l10n.financeArchivedPayment, style: secondary),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );
}

/// Amber notice for a server whose latest service periods belong to a deleted
/// payment (the old "delete record, keep periods" choice, or data from before
/// rollbacks followed the term). Tapping offers to roll the due date back to the
/// start of that span; repeatable when several deleted payments are stacked.
class OrphanTermBanner extends StatelessWidget {
  const OrphanTermBanner({
    super.key,
    required this.controller,
    required this.server,
  });
  final LedgerController controller;
  final ServerRecord server;

  Future<void> _repair(BuildContext context, TermTail tail) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final from = tail.start.toString(), until = tail.end.toString();
    if (!await showAppConfirm(
      context,
      title: l10n.r4PayOrphanTitle,
      message: l10n.r4PayOrphanMsg(from, until),
      action: l10n.r4PayOrphanAction,
    )) {
      return;
    }
    try {
      final restored = await controller.rollbackOrphanTerm(server);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.r4PayOrphanDone(restored.toString()))),
      );
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tail = controller.orphanTermFor(server);
    if (tail == null || controller.refreshFailed) {
      return const SizedBox.shrink();
    }
    return AppBanner(
      key: const ValueKey('orphan-term-banner'),
      tone: AppTone.amber,
      icon: Icons.history_rounded,
      text: context.l10n.r4PayOrphanBanner(
        tail.start.toString(),
        tail.end.toString(),
      ),
      onTap: () => _repair(context, tail),
    );
  }
}
