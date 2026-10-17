import 'package:flutter/material.dart';

import '../l10n/locale_preference.dart';
import '../core/app_theme.dart' show showFailure;
import '../core/ui/ui.dart';
import '../core/value_types.dart';
import '../servers/ledger_controller.dart';
import '../servers/refresh_failure_notice.dart';
import 'finance_models.dart';
import 'finance_widgets.dart';

class PaymentDetailPage extends StatelessWidget {
  const PaymentDetailPage({
    super.key,
    required this.controller,
    required this.id,
  });
  final LedgerController controller;
  final String id;

  /// Delete = a voided tombstone (totals exclude it, the idempotency key stays
  /// used). A server renewal can also be rolled back (the default choice) while
  /// it is the tail of the server's term; unrelated server edits do not matter.
  /// Otherwise only the record goes and the service periods / due date stay.
  Future<void> delete(BuildContext context, PaymentRecord payment) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    // The revision on display; the store refuses when the server moved on.
    final revision = payment.isAccount
        ? null
        : controller.byId(payment.serverId!)?.revision;
    bool? rollback;
    if (!payment.isAccount && controller.canUndoPayment(payment)) {
      await showAppActionMenu<void>(
        context,
        title: l10n.r2FinanceDeleteTitle,
        message: l10n.r4PayDeleteChoiceMsg(payment.until.toString()),
        actions: [
          AppMenuAction(
            key: const ValueKey('payment-delete-rollback'),
            label: l10n.r4PayDeleteRollbackTo(payment.previousDue.toString()),
            destructive: true,
            isDefault: true,
            onPressed: () => rollback = true,
          ),
          AppMenuAction(
            key: const ValueKey('payment-delete-keep'),
            label: l10n.r2FinanceDeleteKeep,
            destructive: true,
            onPressed: () => rollback = false,
          ),
        ],
      );
    } else {
      final later = payment.isAccount
          ? const <PaymentRecord>[]
          : controller.laterRenewals(payment);
      if (await showAppConfirm(
        context,
        title: l10n.r2FinanceDeleteTitle,
        message: payment.isAccount
            ? l10n.r2FinanceDeleteAccountMsg
            : later.isEmpty
            ? l10n.r2FinanceDeleteKeepMsg
            : l10n.r4PayDeleteLaterMsg(
                later.map((p) => p.until.toString()).join(' · '),
              ),
        action: l10n.r2FinanceDelete,
        dangerous: true,
      )) {
        rollback = false;
      }
    }
    if (rollback == null || !context.mounted) return;
    try {
      await controller.deletePayment(
        payment,
        rollbackRenewal: rollback!,
        expectedServerRevision: revision,
      );
      if (navigator.mounted) navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.r2FinanceDeleted)));
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> edit(BuildContext context, PaymentRecord payment) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final saved = await showAppModal<bool>(
      context,
      builder: (_) => PaymentEditForm(controller: controller, payment: payment),
    );
    if (saved == true) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.r2FinanceUpdated)));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final p = controller.payments.where((p) => p.id == id).firstOrNull;
      final l10n = context.l10n;
      final palette = context.palette;
      return AppScaffold(
        largeTitle: false,
        title: l10n.financePaymentDetail,
        actions: [
          if (p != null && !p.voided)
            AppNavButton.text(
              l10n.r2FinanceEdit,
              key: const ValueKey('payment-edit'),
              onPressed: controller.canMutate ? () => edit(context, p) : null,
            ),
        ],
        children: [
          if (controller.refreshFailed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: RefreshFailureNotice(controller: controller),
            ),
          if (p == null)
            FinanceNote(
              l10n.financePaymentUnavailable,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            )
          else ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.targetName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${p.amount.formatted} ${p.amount.currency}',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (p.voided)
                        StatusPill(
                          l10n.uiFinanceVoidedPill,
                          tone: AppTone.red,
                          dot: true,
                        )
                      else
                        StatusPill(
                          l10n.financeRecordedStatus,
                          tone: AppTone.green,
                          dot: true,
                        ),
                      if (p.serverId == null)
                        StatusPill(l10n.uiFinanceAccountPill),
                    ],
                  ),
                ],
              ),
            ),
            AppSection(
              footer: l10n.financePaymentHistoryNote,
              children: [
                AppKeyValueRow(
                  label: l10n.financePaymentDateLabel,
                  value: '${p.paidDate}',
                ),
                AppKeyValueRow(
                  label: l10n.financeType,
                  value: p.serverId == null
                      ? l10n.financeAccountBill
                      : l10n.financePrepaidRenewalType(p.cycleCount),
                ),
                AppKeyValueRow(
                  label: l10n.financeBillServicePeriod,
                  value: p.from == null
                      ? l10n.financeNotEntered
                      : l10n.financePaymentPeriodRange(
                          p.from.toString(),
                          p.until.toString(),
                        ),
                ),
                AppKeyValueRow(
                  label: l10n.financeNote,
                  value: p.note.isEmpty ? l10n.financeNotEntered : p.note,
                ),
                AppKeyValueRow(
                  label: l10n.financeStatus,
                  value: p.voided
                      ? l10n.financeVoidedStatus
                      : l10n.financeRecordedStatus,
                ),
              ],
            ),
            if (!p.voided)
              AppSection(
                children: [
                  AppRow(
                    key: const ValueKey('payment-delete'),
                    title: l10n.r2FinanceDelete,
                    center: true,
                    destructive: true,
                    enabled: controller.canMutate,
                    onTap: () => delete(context, p),
                  ),
                ],
              ),
          ],
        ],
      );
    },
  );
}

/// Page-sheet form editing the bookkeeping of a payment. It never changes
/// service periods, the due date or the cycle count; saving is guarded by the
/// row the form was opened with ([LedgerStore.editPayment]).
class PaymentEditForm extends StatefulWidget {
  const PaymentEditForm({
    super.key,
    required this.controller,
    required this.payment,
  });
  final LedgerController controller;
  final PaymentRecord payment;
  @override
  State<PaymentEditForm> createState() => _PaymentEditFormState();
}

class _PaymentEditFormState extends State<PaymentEditForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController amount, date, note, account;
  late String currency;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.payment;
    amount = TextEditingController(text: p.amount.decimal);
    date = TextEditingController(text: p.paidDate.toString());
    note = TextEditingController(text: p.note);
    account = TextEditingController(text: p.accountLabel ?? '');
    currency = p.amount.currency;
  }

  @override
  void dispose() {
    amount.dispose();
    date.dispose();
    note.dispose();
    account.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    final c = widget.controller;
    try {
      await c.mutate(
        () => c.store.editPayment(
          original: widget.payment,
          amount: Money(currency, Money.parseMinor(amount.text)!),
          paidDate: LedgerDate.tryParse(date.text.trim())!,
          note: note.text.trim(),
          accountLabel: widget.payment.isAccount ? account.text : null,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        showFailure(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l10n = context.l10n;
      final canSave = !saving && widget.controller.canMutate;
      final isAccount = widget.payment.isAccount;
      return PopScope(
        canPop: !saving,
        child: FinanceModalFrame(
          child: Form(
            key: form,
            child: AppScaffold.modal(
              title: l10n.r2FinanceEditTitle,
              cancelLabel: l10n.financeCancel,
              actionLabel: l10n.save,
              actionBusy: saving,
              onAction: canSave ? save : null,
              children: [
                AppSection(
                  footer: l10n.r2FinanceEditHint,
                  children: [
                    if (isAccount)
                      FinanceFieldRow(
                        key: const ValueKey('edit-account'),
                        controller: account,
                        label: l10n.financeAccountName,
                        hint: l10n.financeAccountNameHint,
                        enabled: !saving,
                        maxLength: 80,
                        check: (v) => v.trim().isEmpty
                            ? l10n.financeAccountNameError
                            : null,
                      )
                    else
                      AppRow(
                        title: widget.payment.targetName,
                        subtitle: l10n.financePrepaidRenewalType(
                          widget.payment.cycleCount,
                        ),
                      ),
                    FinanceFieldRow(
                      key: const ValueKey('edit-amount'),
                      controller: amount,
                      label: l10n.financePaidAmount,
                      enabled: !saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      check: (v) => Money.parseMinor(v.trim()) == null
                          ? l10n.financePaidAmountError
                          : null,
                    ),
                    AppFormRow(
                      label: l10n.financePaidCurrency,
                      child: AppSegmented<String>(
                        key: const ValueKey('edit-currency'),
                        compact: true,
                        options: {for (final c in Money.currencies) c: c},
                        value: currency,
                        onChanged: (c) {
                          if (!saving) setState(() => currency = c);
                        },
                      ),
                    ),
                    FinanceFieldRow(
                      key: const ValueKey('edit-date'),
                      controller: date,
                      label: l10n.financePaidDate,
                      hint: 'YYYY-MM-DD',
                      enabled: !saving,
                      check: (v) {
                        final value = LedgerDate.tryParse(v.trim());
                        if (value == null) return l10n.financeDateError;
                        return value.compareTo(widget.controller.today) > 0
                            ? l10n.financePaymentFutureError
                            : null;
                      },
                    ),
                  ],
                ),
                AppSection(
                  children: [
                    FinanceFieldRow(
                      key: const ValueKey('edit-note'),
                      controller: note,
                      label: l10n.financeOptionalNote,
                      enabled: !saving,
                      stacked: true,
                      maxLines: 3,
                      maxLength: 1000,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
