import 'package:flutter/material.dart';

import '../l10n/locale_preference.dart';
import '../core/app_theme.dart' show showFailure;
import '../core/ui/ui.dart';
import '../core/value_types.dart';
import '../servers/ledger_controller.dart';
import '../servers/refresh_failure_notice.dart';
import 'finance_models.dart';
import 'finance_widgets.dart';

class FxPage extends StatefulWidget {
  const FxPage({super.key, required this.controller});
  final LedgerController controller;
  @override
  State<FxPage> createState() => _FxPageState();
}

class _FxPageState extends State<FxPage> with LocaleRevalidatingForm<FxPage> {
  late final TextEditingController usd, eur, date;
  late String currency;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final fx = widget.controller.fx;
    usd = TextEditingController(text: fx.usdToCny);
    eur = TextEditingController(text: fx.eurToCny);
    date = TextEditingController(
      text: (fx.rateDate ?? widget.controller.today).toString(),
    );
    currency = fx.displayCurrency;
  }

  @override
  void dispose() {
    usd.dispose();
    eur.dispose();
    date.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    if (!validateForm()) return;
    final fx = FxSettings(
      displayCurrency: currency,
      usdToCny: usd.text.trim().isEmpty ? null : usd.text.trim(),
      eurToCny: eur.text.trim().isEmpty ? null : eur.text.trim(),
      rateDate: LedgerDate.tryParse(date.text.trim()),
    );
    setState(() => saving = true);
    try {
      await widget.controller.mutate(() => widget.controller.store.saveFx(fx));
      if (mounted) Navigator.pop(context);
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
      return PopScope(
        canPop: !saving,
        child: FinanceModalFrame(
          child: Form(
            key: formKey,
            child: AppScaffold.modal(
              title: l10n.financeFxTitle,
              cancelLabel: l10n.financeCancel,
              actionLabel: l10n.save,
              actionBusy: saving,
              onAction: canSave ? save : null,
              children: [
                if (widget.controller.refreshFailed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: RefreshFailureNotice(controller: widget.controller),
                  ),
                AppSection(
                  footer: l10n.financeFxScope,
                  children: [
                    AppFormRow(
                      label: l10n.financeDisplayCurrency,
                      child: AppSegmented<String>(
                        key: const ValueKey('fx-currency'),
                        compact: true,
                        options: {for (final c in Money.currencies) c: c},
                        value: currency,
                        onChanged: (v) {
                          if (!saving) setState(() => currency = v);
                        },
                      ),
                    ),
                  ],
                ),
                AppSection(
                  header: l10n.financeFxTitle,
                  footer: l10n.financeFxBasis,
                  children: [
                    for (final entry in [
                      (usd, l10n.financeUsdRate, 'fx-usd'),
                      (eur, l10n.financeEurRate, 'fx-eur'),
                    ])
                      FinanceFieldRow(
                        key: ValueKey(entry.$3),
                        controller: entry.$1,
                        label: entry.$2,
                        hint: l10n.financeUnknownRateHint,
                        enabled: !saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        check: (value) {
                          final text = value.trim();
                          if (text.isEmpty) return null;
                          if (!RegExp(r'^\d{1,9}(\.\d{1,8})?$')
                                  .hasMatch(text) ||
                              (double.tryParse(text) ?? 0) <= 0) {
                            return l10n.financeRateError;
                          }
                          return null;
                        },
                      ),
                    FinanceFieldRow(
                      key: const ValueKey('fx-date'),
                      controller: date,
                      label: l10n.financeRateDate,
                      hint: 'YYYY-MM-DD',
                      enabled: !saving,
                      check: (v) {
                        final value = LedgerDate.tryParse(v.trim());
                        return value == null ||
                                value.compareTo(widget.controller.today) > 0
                            ? l10n.financePastDateError
                            : null;
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: AppButton(
                    key: const ValueKey('save-fx'),
                    label: saving ? l10n.financeSaving : l10n.financeSaveFx,
                    expand: true,
                    onPressed: canSave ? save : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
