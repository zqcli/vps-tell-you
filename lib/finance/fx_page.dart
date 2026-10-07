import 'package:flutter/material.dart';

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
    if (saving || !form.currentState!.validate()) return;
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
          title: const Text('币种与参考汇率'),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('取消'),
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
              const InfoNote('仅改变参考折算，原币续费价与历史实付保持不变。不会请求实时汇率。留空表示该汇率未知。'),
              DropdownButtonFormField<String>(
                initialValue: currency,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '合计显示币种'),
                items: Money.currencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: saving ? null : (v) => setState(() => currency = v!),
              ),
              const SizedBox(height: 18),
              for (final entry in [
                (usd, '1 USD = 多少 CNY', 'fx-usd'),
                (eur, '1 EUR = 多少 CNY', 'fx-eur'),
              ]) ...[
                TextFormField(
                  key: ValueKey(entry.$3),
                  controller: entry.$1,
                  enabled: !saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: entry.$2,
                    hintText: '留空表示汇率未知',
                  ),
                  validator: (value) {
                    final text = value!.trim();
                    if (text.isEmpty) return null;
                    if (!RegExp(r'^\d{1,9}(\.\d{1,8})?$').hasMatch(text) ||
                        (double.tryParse(text) ?? 0) <= 0) {
                      return '请输入大于 0 的汇率，最多 8 位小数';
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
                decoration: const InputDecoration(
                  labelText: '汇率参考日期',
                  hintText: 'YYYY-MM-DD',
                ),
                validator: (v) {
                  final value = LedgerDate.tryParse(v!.trim());
                  return value == null ||
                          value.compareTo(widget.controller.today) > 0
                      ? '请输入不晚于今天的有效日期'
                      : null;
                },
              ),
              const InfoNote(
                'CNY 为基准，1 CNY = 1 CNY。同币种换算不需要汇率；跨币种缺汇率时只展示可转换部分及覆盖率。',
              ),
              FilledButton(
                onPressed: saving || !widget.controller.canMutate ? null : save,
                child: Text(saving ? '正在保存…' : '保存参考汇率'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
