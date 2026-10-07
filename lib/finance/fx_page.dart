import 'package:flutter/material.dart';

import '../l10n/locale_preference.dart';
import '../core/app_theme.dart';
import '../core/value_types.dart';
import '../servers/ledger_controller.dart';
import '../servers/refresh_failure_notice.dart';
import 'finance_models.dart';

class FxPage extends StatefulWidget {
  const FxPage({super.key, required this.controller});
  final LedgerController controller;
  @override
  State<FxPage> createState() => _FxPageState();
}

class _FxPageState extends State<FxPage> {
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
    validationAttempted = true;
    if (!form.currentState!.validate()) return;
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
    builder: (context, _) => PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.financeFxTitle),
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
              InfoNote(context.l10n.financeFxScope),
              DropdownButtonFormField<String>(
                initialValue: currency,
                isExpanded: true,
                itemHeight: null,
                decoration: InputDecoration(
                  errorMaxLines: 5,
                  labelText: context.l10n.financeDisplayCurrency,
                ),
                items: Money.currencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: saving ? null : (v) => setState(() => currency = v!),
              ),
              const SizedBox(height: 18),
              for (final entry in [
                (usd, context.l10n.financeUsdRate, 'fx-usd'),
                (eur, context.l10n.financeEurRate, 'fx-eur'),
              ]) ...[
                TextFormField(
                  key: ValueKey(entry.$3),
                  controller: entry.$1,
                  enabled: !saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    errorMaxLines: 5,
                    labelText: entry.$2,
                    hintText: context.l10n.financeUnknownRateHint,
                  ),
                  validator: (value) {
                    final text = value!.trim();
                    if (text.isEmpty) return null;
                    if (!RegExp(r'^\d{1,9}(\.\d{1,8})?$').hasMatch(text) ||
                        (double.tryParse(text) ?? 0) <= 0) {
                      return context.l10n.financeRateError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
              ],
              TextFormField(
                key: const ValueKey('fx-date'),
                controller: date,
                enabled: !saving,
                decoration: InputDecoration(
                  errorMaxLines: 5,
                  labelText: context.l10n.financeRateDate,
                  hintText: 'YYYY-MM-DD',
                ),
                validator: (v) {
                  final value = LedgerDate.tryParse(v!.trim());
                  return value == null ||
                          value.compareTo(widget.controller.today) > 0
                      ? context.l10n.financePastDateError
                      : null;
                },
              ),
              InfoNote(context.l10n.financeFxBasis),
              FilledButton(
                onPressed: saving || !widget.controller.canMutate ? null : save,
                child: Text(
                  saving
                      ? context.l10n.financeSaving
                      : context.l10n.financeSaveFx,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
