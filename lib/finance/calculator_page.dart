import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../core/value_types.dart';
import '../servers/ledger_controller.dart';
import '../servers/server_record.dart';
import 'calculation_share.dart';
import 'finance_math.dart';
import 'finance_models.dart';
import 'finance_widgets.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key, required this.controller, this.server});
  final LedgerController controller;
  final ServerRecord? server;
  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final form = GlobalKey<FormState>();
  late final TextEditingController price, asOf, due;
  late String currency;
  late int cycle;
  List<ServicePeriod>? referencedPeriods;
  String? sourceName;
  bool rebuilt = false;
  @override
  void initState() {
    super.initState();
    price = TextEditingController();
    asOf = TextEditingController(text: widget.controller.today.toString());
    due = TextEditingController(
      text: widget.controller.today.addMonths(12).toString(),
    );
    currency = 'USD';
    cycle = 12;
    if (widget.server != null) reference(widget.server!);
  }

  void reference(ServerRecord s) {
    price.text = s.money?.decimal ?? '';
    due.text = s.dueDate?.toString() ?? '';
    currency = s.currency;
    cycle = s.cycleMonths;
    referencedPeriods = List.unmodifiable(widget.controller.periodsFor(s.id));
    sourceName = s.name;
    rebuilt = false;
  }

  @override
  void dispose() {
    price.dispose();
    asOf.dispose();
    due.dispose();
    super.dispose();
  }

  Future<void> chooseReference() async {
    final s = await showModalBottomSheet<ServerRecord>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                '引用服务器资料',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const InfoNote('只复制此刻的续费资料和已知期间。不会修改原服务器。'),
              ...widget.controller.active
                  .where((s) => s.billing == BillingKind.prepaid)
                  .map(
                    (s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.name),
                      subtitle: Text(
                        '${s.billingLabel} · 至 ${s.dueDate ?? '未知'}',
                      ),
                      onTap: () => Navigator.pop(context, s),
                    ),
                  ),
              if (!widget.controller.active.any(
                (s) => s.billing == BillingKind.prepaid,
              ))
                const InfoNote('暂无预付费服务器，可使用独立试算。'),
            ],
          ),
        ),
      ),
    );
    if (s != null && mounted) setState(() => reference(s));
  }

  void changePeriod() {
    if (referencedPeriods != null) {
      setState(() {
        referencedPeriods = null;
        rebuilt = true;
      });
    }
  }

  void calculate() {
    if (!form.currentState!.validate()) return;
    final estimateDate = LedgerDate.tryParse(asOf.text.trim())!;
    final end = LedgerDate.tryParse(due.text.trim())!;
    if (estimateDate.daysUntil(end).abs() > 36600) {
      showFailure(context, ArgumentError('请核对日期，试算范围限制为 100 年'));
      return;
    }
    try {
      final periods =
          referencedPeriods ?? calculatorPeriods(estimateDate, end, cycle);
      final money = Money(currency, Money.parseMinor(price.text)!);
      final value = valueOfPeriods(
        renewal: money,
        periods: periods,
        asOf: estimateDate,
      );
      if (value == null) {
        showFailure(
          context,
          ArgumentError('引用资料缺少有效服务期。请补充服务器日期，或改到期日切换为独立假设。'),
        );
        return;
      }
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CalculationResultPage(
            renewal: money,
            cycleMonths: cycle,
            asOf: estimateDate,
            due: end,
            value: value,
            fx: widget.controller.fx,
            usesKnownPeriods: referencedPeriods != null,
          ),
        ),
      );
    } catch (error) {
      showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('剩余价值计算器')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              const LedgerBadge('试算 · 不入账'),
              TextButton(
                onPressed: chooseReference,
                child: const Text('引用服务器'),
              ),
            ],
          ),
          InfoNote(
            referencedPeriods != null
                ? '引用 $sourceName 的已知期间。修改估值日、金额或币种仍保留期间；不回写资料。'
                : rebuilt
                ? '已切换为独立假设：修改了到期日或周期，按新到期日重建期间。假设到期日前服务连续有效。'
                : '独立试算，无需添加服务器。假设到期日前服务连续有效。',
          ),
          TextFormField(
            key: const ValueKey('calc-price'),
            controller: price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '每周期续费金额'),
            validator: (v) =>
                Money.parseMinor(v!) == null ? '请填写有效金额，明确免费可填 0' : null,
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            key: ValueKey('calc-currency-$currency'),
            initialValue: currency,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '原币种'),
            items: Money.currencies
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => currency = v!),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<int>(
            key: ValueKey('calc-cycle-$cycle'),
            initialValue: cycle,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '续费周期'),
            items: [1, 3, 6, 12, 24, 36]
                .map((c) => DropdownMenuItem(value: c, child: Text('每 $c 个月')))
                .toList(),
            onChanged: (v) {
              if (v != cycle) {
                changePeriod();
                setState(() => cycle = v!);
              }
            },
          ),
          const SizedBox(height: 18),
          TextFormField(
            key: const ValueKey('calc-asof'),
            controller: asOf,
            decoration: const InputDecoration(
              labelText: '估值日期',
              hintText: 'YYYY-MM-DD',
            ),
            validator: (v) =>
                LedgerDate.tryParse(v!.trim()) == null ? '请输入有效估值日' : null,
          ),
          const SizedBox(height: 18),
          TextFormField(
            key: const ValueKey('calc-due'),
            controller: due,
            onChanged: (_) => changePeriod(),
            decoration: const InputDecoration(
              labelText: '服务到期日',
              hintText: 'YYYY-MM-DD',
            ),
            validator: (v) =>
                LedgerDate.tryParse(v!.trim()) == null ? '请输入有效到期日' : null,
          ),
          const SizedBox(height: 16),
          const ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('周期与算法说明'),
            children: [
              InfoNote(
                '剩余价值 = Σ（每周期续费金额 × 该周期未用天数比例）。\n日历周期按真实天数计算，不固定每月 30 天；月底由原到期日锚点倒推，年度处理闰年。估值早于已知开始日不会超过该期整价。\n独立模式向前倒推至覆盖估值日，限制 100 年。到期当天为 0，不检查服务能否转让或退款。',
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('calculate-value'),
            onPressed: calculate,
            child: const Text('计算剩余价值'),
          ),
          const InfoNote('试算与记账分离，修改输入不会更改任何服务器或付款。'),
        ],
      ),
    ),
  );
}

class CalculationResultPage extends StatefulWidget {
  const CalculationResultPage({
    super.key,
    required this.renewal,
    required this.cycleMonths,
    required this.asOf,
    required this.due,
    required this.value,
    required this.fx,
    required this.usesKnownPeriods,
  });
  final Money renewal;
  final int cycleMonths;
  final LedgerDate asOf, due;
  final Valuation value;
  final FxSettings fx;
  final bool usesKnownPeriods;
  @override
  State<CalculationResultPage> createState() => _CalculationResultPageState();
}

class _CalculationResultPageState extends State<CalculationResultPage> {
  final quoteForm = GlobalKey<FormState>();
  final offer = TextEditingController();
  final fee = TextEditingController(text: '0');
  late String feeCurrency = widget.fx.displayCurrency;
  FeePayer payer = FeePayer.buyer;
  QuoteResult? quote;
  String? quoteError;
  @override
  void dispose() {
    offer.dispose();
    fee.dispose();
    super.dispose();
  }

  CalculationShareData get shareData {
    final v = widget.value, fx = widget.fx;
    final rate = fx.convert(Rational.of(100), widget.renewal.currency);
    return CalculationShareData(
      amount: v.amount.formatted,
      currency: widget.renewal.currency,
      converted: convertedAmount(v.amount, fx),
      asOf: widget.asOf,
      start: v.activePeriod.start,
      end: v.activePeriod.end,
      due: widget.due,
      ratio: v.ratio.toDouble(),
      activeRemaining: v.activeRemaining,
      days: v.days,
      remaining: v.remainingDays,
      renewal:
          '${widget.renewal.formatted} ${widget.renewal.currency} / ${widget.cycleMonths} 个月',
      daily:
          '${formatRational(v.dailyMinor, digits: 4)} ${widget.renewal.currency}',
      futurePeriods: v.futurePeriods,
      fx: rate == null
          ? '参考汇率缺失'
          : '1 ${widget.renewal.currency} = ${formatRational(rate, digits: 8)} ${fx.displayCurrency}',
      fxSource: '手动汇率 · ${fx.rateDate ?? '未设置日期'} · 非实时报价',
      periodBasis: widget.usesKnownPeriods
          ? '引用时复制的已知服务期${v.inferred ? '；部分起点为推算' : ''}，未回写台账。'
          : '独立假设：到期日前服务连续有效，期间按到期日倒推。',
    );
  }

  void clearQuote() => setState(() {
    quote = null;
    quoteError = null;
  });
  void settle() {
    if (!quoteForm.currentState!.validate()) return;
    final result = calculateQuote(
      offer: Money(widget.fx.displayCurrency, Money.parseMinor(offer.text)!),
      fee: Money(feeCurrency, Money.parseMinor(fee.text)!),
      payer: payer,
      reference: widget.value.amount,
      fx: widget.fx,
    );
    setState(() {
      quote = result;
      quoteError = result == null ? '缺少对应汇率，不能计算参考价值与结算金额。' : null;
    });
  }

  Future<void> copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: shareData.plainText));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('计算结果已复制，仅包含计算信息')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('未能写入剪贴板，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('计算结果')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const LedgerBadge('试算 · 不入账'),
        const SizedBox(height: 16),
        ValuationCard(
          value: widget.value,
          renewal: widget.renewal,
          cycleMonths: widget.cycleMonths,
          due: widget.due,
          asOf: widget.asOf,
          fx: widget.fx,
        ),
        InfoNote(shareData.periodBasis),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('修改条件'),
            ),
            OutlinedButton.icon(
              onPressed: copy,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('复制结果'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('preview-png'),
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => CalculationPreview(data: shareData),
            ),
          ),
          icon: const Icon(Icons.image_outlined),
          label: const Text('预览 / 保存 PNG'),
        ),
        const SizedBox(height: 20),
        LedgerCard(
          child: ExpansionTile(
            key: const ValueKey('quote-panel'),
            maintainState: true,
            tilePadding: EdgeInsets.zero,
            title: const Text('转让结算 · 可选'),
            children: [
              Form(
                key: quoteForm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const InfoNote(
                      '仅比较报价，不判断服务是否可转让。不包含中介、税费或支付手续费；请自行确认转移条款。',
                    ),
                    TextFormField(
                      key: const ValueKey('quote-offer'),
                      controller: offer,
                      onChanged: (_) => clearQuote(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: '卖家报价 · ${widget.fx.displayCurrency}',
                      ),
                      validator: (v) =>
                          Money.parseMinor(v!) == null ? '请输入 0 或正数报价' : null,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      key: const ValueKey('quote-fee'),
                      controller: fee,
                      onChanged: (_) => clearQuote(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Push / 转移手续费',
                      ),
                      validator: (v) =>
                          Money.parseMinor(v!) == null ? '请输入 0 或正数手续费' : null,
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: feeCurrency,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '手续费币种'),
                      items: Money.currencies
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) {
                        clearQuote();
                        setState(() => feeCurrency = v!);
                      },
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<FeePayer>(
                      initialValue: payer,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '手续费承担'),
                      items: const [
                        DropdownMenuItem(
                          value: FeePayer.buyer,
                          child: Text('买家承担'),
                        ),
                        DropdownMenuItem(
                          value: FeePayer.seller,
                          child: Text('卖家承担'),
                        ),
                        DropdownMenuItem(
                          value: FeePayer.split,
                          child: Text('各承担一半'),
                        ),
                      ],
                      onChanged: (v) {
                        clearQuote();
                        setState(() => payer = v!);
                      },
                    ),
                    const InfoNote('手续费先折算到显示币种的分，再分摊；奇数分余数归买方。双方手续费之和等于总手续费。'),
                    OutlinedButton(
                      onPressed: settle,
                      child: const Text('计算转让结算'),
                    ),
                    if (quoteError != null) InfoNote(quoteError!),
                    if (quote != null) ...[
                      FinanceLine('报价与参考价值差额（溢价 / 折价）', quote!.premium),
                      FinanceLine(
                        '买方 / 卖方手续费',
                        '${quote!.buyerFee} / ${quote!.sellerFee}',
                      ),
                      FinanceLine('买方最终总支出', quote!.buyerTotal),
                      FinanceLine('卖方净收款', quote!.sellerNet),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        InfoNote('${shareData.fx}\n${shareData.fxSource}。先求和后四舍五入到分，中点远离 0。'),
      ],
    ),
  );
}
