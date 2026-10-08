import 'package:flutter/material.dart';

import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
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
  bool validationAttempted = false;
  String? validationLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = context.l10n.localeName;
    if (validationLocale != null &&
        validationLocale != locale &&
        validationAttempted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) form.currentState?.validate();
      });
    }
    validationLocale = locale;
  }

  final form = GlobalKey<FormState>();
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
        errorMaxLines: 4,
      ),
      validator: (raw) {
        final value = raw!.trim();
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
    ),
  );
  Future<void> save() async {
    if (saving) return;
    validationAttempted = true;
    final valid = form.currentState!.validate();
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
  Widget build(BuildContext context) =>
      widget.server != null && !canRenew(widget.server!)
      ? Scaffold(
          appBar: AppBar(title: Text(context.l10n.financeRecordPayment)),
          body: Padding(
            padding: EdgeInsets.all(20),
            child: InfoNote(context.l10n.financeNoRenewalDate),
          ),
        )
      : ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => PopScope(
            canPop: !saving,
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  account
                      ? context.l10n.financeRecordAccountBill
                      : context.l10n.financeRecordPayment,
                ),
                actions: [
                  TextButton(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    child: Text(context.l10n.financeCancel),
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
                            Text(
                              widget.controller.providerNameFor(
                                widget.server!,
                                l10n: context.l10n,
                              ),
                            ),
                            InfoNote(context.l10n.financeLocalPaymentOnly),
                          ],
                        ),
                      ),
                    if (account) InfoNote(context.l10n.financeAccountBillNote),
                    const SizedBox(height: 18),
                    if (account)
                      field(
                        'account',
                        context.l10n.financeAccountName,
                        hint: context.l10n.financeAccountNameHint,
                      ),
                    field('amount', context.l10n.financePaidAmount),
                    DropdownButtonFormField<String>(
                      initialValue: currency,
                      isExpanded: true,
                      itemHeight: null,
                      decoration: InputDecoration(
                        labelText: context.l10n.financePaidCurrency,
                      ),
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
                    field(
                      'date',
                      context.l10n.financePaidDate,
                      hint: 'YYYY-MM-DD',
                    ),
                    if (!account) ...[
                      DropdownButtonFormField<int>(
                        initialValue: count,
                        isExpanded: true,
                        itemHeight: null,
                        decoration: InputDecoration(
                          labelText: context.l10n.financeRenewalCount,
                        ),
                        items: [1, 2, 3]
                            .where((n) => canRenew(widget.server!, cycles: n))
                            .map(
                              (n) => DropdownMenuItem(
                                value: n,
                                child: Builder(
                                  builder: (context) => Text(
                                    context.l10n.financeCycleCountOption(
                                      n,
                                      widget.server!.cycleMonths,
                                    ),
                                  ),
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
                        context.l10n.financeExtendFromDue(
                          widget.server!.dueDate.toString(),
                        ),
                      ),
                      field(
                        'until',
                        context.l10n.financeNewDue,
                        hint: context.l10n.financeNewDueHint,
                      ),
                      LedgerCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.financeNextRenewalPrice(
                                widget.server!.billingLabelFor(context.l10n),
                                widget.server!.currency,
                              ),
                            ),
                            InfoNote(context.l10n.financePaymentRenewalNote),
                          ],
                        ),
                      ),
                    ] else ...[
                      field(
                        'from',
                        context.l10n.financeBillStart,
                        hint: 'YYYY-MM-DD',
                        optional: true,
                      ),
                      field(
                        'until',
                        context.l10n.financeBillEnd,
                        hint: 'YYYY-MM-DD',
                        optional: true,
                      ),
                    ],
                    const SizedBox(height: 18),
                    field(
                      'note',
                      context.l10n.financeOptionalNote,
                      lines: 3,
                      optional: true,
                    ),
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
                            ? context.l10n.financeConfirmAccountPaid
                            : context.l10n.financeConfirmServerPaid,
                      ),
                    ),
                    if (confirmationError != null)
                      Text(
                        confirmationError!.messageFor(context.l10n),
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
                      child: Text(
                        saving
                            ? context.l10n.financeSaving
                            : context.l10n.financeSavePayment,
                      ),
                    ),
                    InfoNote(context.l10n.financeNotReceipt),
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
        appBar: AppBar(title: Text(context.l10n.financePayments)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (c.refreshFailed) RefreshFailureNotice(controller: c),
            DropdownButtonFormField<String>(
              initialValue: serverId ?? '',
              isExpanded: true,
              itemHeight: null,
              decoration: InputDecoration(
                labelText: context.l10n.financePaymentTarget,
              ),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Builder(
                    builder: (context) => Text(context.l10n.financeAllPayments),
                  ),
                ),
                ...c.records.map(
                  (s) => DropdownMenuItem(
                    value: s.id,
                    child: Builder(
                      builder: (context) => Text(
                        context.l10n.financeArchivedName(
                          s.name,
                          s.archived ? 'yes' : 'no',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
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
                  label: Text(context.l10n.financeRecent30),
                  selected: recent,
                  onSelected: (v) => setState(() => recent = v),
                ),
                FilterChip(
                  label: Text(context.l10n.financeShowVoided),
                  selected: showVoided,
                  onSelected: (v) => setState(() => showVoided = v),
                ),
              ],
            ),
            SectionTitle(context.l10n.financeRecordedPaidTotal),
            LedgerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (counted.isEmpty)
                    Text(context.l10n.financeNoPayments)
                  else
                    FinanceTotalView(total: total),
                  InfoNote(
                    context.l10n.financeValidPaymentsNote(counted.length),
                  ),
                ],
              ),
            ),
            if (widget.groupId != null)
              InfoNote(
                context.l10n.financePaymentGroupNote(
                  c.groupName(widget.groupId, l10n: context.l10n),
                ),
              ),
            SectionTitle(context.l10n.financePaymentDetails),
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
                          context.l10n.financeVoidedName(
                            p.targetName,
                            p.voided ? 'yes' : 'no',
                          ),
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
                          context.l10n.financePaymentSummary(
                            p.paidDate.toString(),
                            p.serverId == null ? 'yes' : 'no',
                            p.until?.toString() ?? context.l10n.financeUnknown,
                          ),
                        ),
                        if (p.serverId != null &&
                            c.byId(p.serverId!)?.archived == true)
                          LedgerBadge(context.l10n.financeArchivedPayment),
                      ],
                    ),
                  ),
                ),
              ),
            if (rows.isEmpty) InfoNote(context.l10n.financeNoPaymentsInRange),
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
      title: LocalizedText((l10n) => l10n.financeVoidTitle),
      message: payment.serverId == null
          ? LocalizedText((l10n) => l10n.financeVoidAccountNote)
          : LocalizedText((l10n) => l10n.financeVoidServerNote),
      action: LocalizedText((l10n) => l10n.financeVoidRecord),
      dangerous: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await controller.mutate(() => controller.store.undoPayment(id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) => Text(context.l10n.financePaymentVoided),
            ),
          ),
        );
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
        appBar: AppBar(title: Text(context.l10n.financePaymentDetail)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (controller.refreshFailed)
              RefreshFailureNotice(controller: controller),
            if (p == null)
              InfoNote(context.l10n.financePaymentUnavailable)
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
                    FinanceLine(
                      context.l10n.financePaymentDateLabel,
                      '${p.paidDate}',
                    ),
                    FinanceLine(
                      context.l10n.financeType,
                      p.serverId == null
                          ? context.l10n.financeAccountBill
                          : context.l10n.financePrepaidRenewalType(
                              p.cycleCount,
                            ),
                    ),
                    FinanceLine(
                      context.l10n.financeBillServicePeriod,
                      p.from == null
                          ? context.l10n.financeNotEntered
                          : context.l10n.financePaymentPeriodRange(
                              p.from.toString(),
                              p.until.toString(),
                            ),
                    ),
                    FinanceLine(
                      context.l10n.financeNote,
                      p.note.isEmpty ? context.l10n.financeNotEntered : p.note,
                    ),
                    FinanceLine(
                      context.l10n.financeStatus,
                      p.voided
                          ? context.l10n.financeVoidedStatus
                          : context.l10n.financeRecordedStatus,
                    ),
                  ],
                ),
              ),
              InfoNote(context.l10n.financePaymentHistoryNote),
              if (!p.voided) ...[
                OutlinedButton(
                  onPressed:
                      controller.canMutate && controller.canUndoPayment(p)
                      ? () => undo(context, p)
                      : null,
                  child: Text(context.l10n.financeVoidThisRecord),
                ),
                if (!controller.canUndoPayment(p))
                  InfoNote(context.l10n.financeVoidBlocked),
              ],
            ],
          ],
        ),
      );
    },
  );
}
