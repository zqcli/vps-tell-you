import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/value_types.dart';
import 'finance_models.dart';

class FinanceLine extends StatelessWidget {
  const FinanceLine(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 3),
        SelectableText(value),
      ],
    ),
  );
}

class FinanceTotalView extends StatelessWidget {
  const FinanceTotalView({
    super.key,
    required this.total,
    this.dark = false,
    this.compact = false,
  });
  final FinanceTotal total;
  final bool dark, compact;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${total.covered > 0 ? '约 ' : ''}${total.formatted} ${total.currency}',
        style: TextStyle(
          fontSize: compact ? 21 : 30,
          fontWeight: FontWeight.w700,
          color: dark ? Colors.white : AppColors.ink,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        '折算覆盖 ${total.coverageLabel}${total.missingFx > 0 ? ' · ${total.missingFx} 项缺汇率' : ''}',
        style: TextStyle(
          fontSize: 12,
          color: dark ? const Color(0xFFCAD5E7) : AppColors.muted,
        ),
      ),
      if (total.unknown + total.notApplicable > 0)
        Text(
          '${total.unknown} 项未知 · ${total.notApplicable} 项不适用 / 未纳入',
          style: TextStyle(
            fontSize: 12,
            color: dark ? const Color(0xFFCAD5E7) : AppColors.muted,
          ),
        ),
      if (total.missingFx > 0)
        Text(
          '仅为可转换部分，缺失部分未补 0',
          style: TextStyle(
            fontSize: 12,
            color: dark ? const Color(0xFFFFD89B) : AppColors.amber,
          ),
        ),
      if (total.originals.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '原币小计：${total.originals.entries.map((e) => '${e.key} ${formatRational(e.value)}').join(' · ')}',
            style: TextStyle(
              fontSize: 12,
              color: dark ? const Color(0xFFCAD5E7) : AppColors.muted,
            ),
          ),
        ),
    ],
  );
}

String convertedAmount(FinanceAmount amount, FxSettings fx) {
  if (!amount.known) {
    return amount.status == AmountStatus.notApplicable ? '不适用 / 未纳入' : '资料未知';
  }
  final converted = fx.convert(amount.minor!, amount.currency);
  return converted == null
      ? '缺少汇率 · 原币仍保留'
      : '约 ${formatMinor(converted.round(), currency: fx.displayCurrency)} ${fx.displayCurrency}';
}

class ValuationCard extends StatelessWidget {
  const ValuationCard({
    super.key,
    required this.value,
    required this.renewal,
    required this.cycleMonths,
    required this.due,
    required this.asOf,
    required this.fx,
  });
  final Valuation value;
  final Money renewal;
  final int cycleMonths;
  final LedgerDate due, asOf;
  final FxSettings fx;
  @override
  Widget build(BuildContext context) => LedgerCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '剩余价值 · 续费价口径',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Text(
          '${value.amount.formatted} ${value.amount.currency}',
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
        ),
        Text(
          convertedAmount(value.amount, fx),
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 22),
        Text(
          '本周期剩余 ${(value.ratio.toDouble() * 100).toStringAsFixed(1)}% · ${value.activeRemaining} / ${value.days} 天',
        ),
        const SizedBox(height: 9),
        LinearProgressIndicator(
          value: value.ratio.toDouble().clamp(0, 1),
          borderRadius: BorderRadius.circular(5),
          minHeight: 7,
          backgroundColor: AppColors.line,
        ),
        const SizedBox(height: 8),
        Text(
          '${value.activePeriod.start} 至 ${value.activePeriod.end}',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        FinanceLine('估值日 / 服务到期日', '$asOf / $due'),
        FinanceLine('剩余有效期', '${value.remainingDays} 天'),
        FinanceLine(
          '续费 / 周期',
          '${renewal.formatted} ${renewal.currency} / $cycleMonths 个月',
        ),
        FinanceLine(
          '本周期日均',
          '${formatRational(value.dailyMinor, digits: 4)} ${renewal.currency}',
        ),
        if (value.futurePeriods > 0)
          InfoNote('含 ${value.futurePeriods} 个未来周期，进度条只表示当前周期。'),
        if (value.inferred) const InfoNote('部分服务起点由到期日与日历周期反推；不代表历史付款证明。'),
        const InfoNote('仅表示服务时长的价格折算，不是退款承诺或成交价。'),
      ],
    ),
  );
}
