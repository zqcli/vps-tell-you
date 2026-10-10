import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../cloud/cloud_pages.dart';
import '../cloud/provider_pages.dart';
import '../cloud/cloud_widgets.dart';
import '../cloud/server_cloud_binding_page.dart';
import '../core/app_theme.dart';
import '../core/ui/ui.dart';
import '../core/value_types.dart';
import '../connections/connection_pages.dart';
import '../connections/tcp_test_page.dart';
import '../finance/calculator_page.dart';
import '../finance/finance_math.dart';
import '../finance/finance_models.dart';
import '../finance/payment_pages.dart';
import '../security/host_trust_pages.dart';
import '../security/ssh_configuration_page.dart';
import '../settings/reminder_page.dart';
import 'hardware_information_card.dart';
import 'ledger_controller.dart';
import 'refresh_failure_notice.dart';
import 'server_form.dart';
import 'server_record.dart';

class ServerDetail extends StatelessWidget {
  const ServerDetail({super.key, required this.controller, required this.id});
  final LedgerController controller;
  final String id;

  Future<void> archive(BuildContext context, ServerRecord record) async {
    final confirmed = await showAppConfirm(
      context,
      title: LocalizedText((l10n) => l10n.serverArchiveQuestion),
      message: LocalizedText((l10n) => l10n.serverArchiveHelp(record.name)),
      action: LocalizedText((l10n) => l10n.serverArchiveLocal),
      dangerous: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      final token = await controller.mutate(
        () => controller.store.archive(record),
      );
      if (!context.mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      final canUndo = !controller.refreshFailed;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          // The standard action remains persistent and once-only even though
          // it lives in localized content so an open/queued label can rebuild.
          persist: canUndo,
          content: Builder(
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.l10n.serverArchived),
                if (canUndo)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: SnackBarAction(
                      label: context.l10n.serverUndo,
                      onPressed: () async {
                        try {
                          await controller.mutate(
                            () => controller.store.undoArchive(token),
                          );
                        } catch (_) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Builder(
                                builder: (context) =>
                                    Text(context.l10n.serverUndoArchiveFailed),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }

  Future<void> _toggleFavorite(BuildContext context, ServerRecord s) async {
    try {
      await controller.mutate(
        () => controller.store.setFavorite(s, !s.favorite),
      );
    } catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }

  Future<void> _copyHost(BuildContext context, ServerRecord s) async {
    try {
      await Clipboard.setData(ClipboardData(text: s.host));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) => Text(context.l10n.serverHostCopied),
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        showFailure(
          context,
          error,
          fallbackMessage: LocalizedText((l10n) => l10n.serverCopyHostFailed),
        );
      }
    }
  }

  Future<void> _openForm(
    BuildContext context,
    ServerRecord s, {
    bool focusHardware = false,
  }) => showAppModal<String>(
    context,
    builder: (_) => ServerForm(
      controller: controller,
      record: s,
      focusHardware: focusHardware,
    ),
  );

  void _push(BuildContext context, Widget page) =>
      Navigator.push<void>(context, MaterialPageRoute(builder: (_) => page));

  void _openCalculator(BuildContext context, ServerRecord s) =>
      _push(context, CalculatorPage(controller: controller, server: s));

  void _openSshConfiguration(BuildContext context, ServerRecord s) =>
      _push(context, SshConfigurationPage(ledger: controller, serverId: s.id));

  Future<void> _offerSshSetup(BuildContext context, ServerRecord s) async {
    final configure = await showAppConfirm(
      context,
      title: LocalizedText((l10n) => l10n.uiDetailNeedSshTitle),
      message: LocalizedText((l10n) => l10n.uiDetailNeedSshMessage(s.name)),
      action: LocalizedText((l10n) => l10n.uiDetailGoConfigure),
    );
    if (configure && context.mounted) {
      _openSshConfiguration(context, s);
    }
  }

  void _showMoreMenu(BuildContext context, ServerRecord s) {
    final canChangeProvider =
        controller.canMutate &&
        !s.archived &&
        !s.isDemo &&
        !controller.cloud.busy &&
        !controller.cloud.needsReload;
    showAppActionMenu<void>(
      context,
      title: s.name,
      actions: [
        if (s.host.isNotEmpty)
          AppMenuAction(
            label: context.l10n.serverCopyHost,
            onPressed: () => _copyHost(context, s),
          ),
        if (s.billing == BillingKind.prepaid)
          AppMenuAction(
            label: context.l10n.uiDetailMenuValuation,
            onPressed: () => _openCalculator(context, s),
          ),
        if (canChangeProvider)
          AppMenuAction(
            label: context.l10n.providerUiChange,
            onPressed: () => changeServerProvider(context, controller, s),
          ),
        AppMenuAction(
          label: context.l10n.serverArchiveLocal,
          destructive: true,
          onPressed: () => archive(context, s),
        ),
      ],
    );
  }

  /// Share of the current service term that has elapsed, or null when the
  /// term cannot be determined (unknown stays unknown).
  double? _elapsedShare(LedgerDate? start, LedgerDate? due) {
    if (start == null || due == null) return null;
    final total = start.daysUntil(due);
    if (total <= 0) return null;
    return (start.daysUntil(controller.today) / total).clamp(0.0, 1.0);
  }

  String _dueText(BuildContext context, int? days) => days == null
      ? context.l10n.serverDueUnknown
      : days < 0
      ? context.l10n.serverExpiredDays(-days)
      : days == 0
      ? context.l10n.serverDueToday
      : context.l10n.serverDueInDays(days);

  /// Side-by-side layouts need ~300 px of text-scale-normalised width.
  bool _isNarrow(BuildContext context, BoxConstraints box) =>
      box.maxWidth / MediaQuery.textScalerOf(context).scale(1) < 300;

  Widget _statLabel(String text, AppPalette p) =>
      Text(text, style: TextStyle(fontSize: 12.5, color: p.text2));

  Widget _statValue(String text, AppPalette p) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: p.text,
      fontFeatures: kTabularFigures,
    ),
  );

  Widget _quickActions(BuildContext context, ServerRecord s) {
    final l10n = context.l10n;
    final blocked = s.archived || s.isDemo;
    final security = controller.security;
    final config = security.configFor(s.id);
    // While the security store is reloading, let the target page decide.
    final noSsh = config == null && !security.needsReload;
    String? paymentBlock;
    if (s.archived) {
      paymentBlock = l10n.uiDetailArchivedUnavailable;
    } else if (s.billing != BillingKind.prepaid) {
      paymentBlock = l10n.uiDetailNotPrepaid;
    } else if (!controller.canMutate) {
      paymentBlock = l10n.uiDetailReadOnly;
    } else if (!canRenew(s)) {
      paymentBlock = l10n.uiDetailCannotRenew;
    }

    void blockedNotice() => showAppToast(
      context,
      s.archived ? l10n.uiDetailArchivedUnavailable : l10n.serverDemoWarning,
    );
    void connect({required bool power}) {
      if (blocked) return blockedNotice();
      if (noSsh) {
        _offerSshSetup(context, s);
        return;
      }
      _push(
        context,
        SshConnectPage(
          ledger: controller,
          initialServerId: s.id,
          powerMode: power,
        ),
      );
    }

    return AppQuickActionRow(
      children: [
        AppQuickAction(
          key: const ValueKey('server-quick-ssh'),
          icon: Icons.terminal_rounded,
          label: l10n.uiDetailQuickSsh,
          dimmed: blocked || noSsh,
          onTap: () => connect(power: false),
        ),
        AppQuickAction(
          key: const ValueKey('server-quick-tcp'),
          icon: Icons.monitor_heart_outlined,
          label: l10n.serverTcpTest,
          dimmed: blocked,
          onTap: () {
            if (blocked) return blockedNotice();
            _push(
              context,
              TcpTestPage(initialHost: s.host, initialPort: config?.port ?? 22),
            );
          },
        ),
        AppQuickAction(
          key: const ValueKey('server-quick-payment'),
          icon: Icons.credit_card_rounded,
          label: l10n.uiDetailQuickPayment,
          dimmed: paymentBlock != null,
          onTap: () {
            if (paymentBlock != null) {
              showAppToast(context, paymentBlock);
              return;
            }
            showAppModal<bool>(
              context,
              builder: (_) => PaymentForm(controller: controller, server: s),
            );
          },
        ),
        AppQuickAction(
          key: const ValueKey('server-quick-power'),
          icon: Icons.power_settings_new_rounded,
          label: l10n.uiDetailQuickPower,
          tone: AppTone.red,
          dimmed: blocked || noSsh,
          onTap: () => connect(power: true),
        ),
      ],
    );
  }

  Widget _costSection(BuildContext context, ServerRecord s) {
    final l10n = context.l10n;
    final p = context.palette;
    final editable = controller.canMutate && !s.archived;
    final money = s.money;
    final TextStyle amountStyle = TextStyle(
      fontSize: 32,
      height: 1.15,
      fontWeight: FontWeight.w700,
      color: p.text,
      fontFeatures: kTabularFigures,
    );
    final unknownAmount = Text(
      l10n.serverUnknown,
      style: amountStyle.copyWith(fontSize: 26, color: p.text3),
    );
    Widget amountBlock(String label) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: p.text2)),
        const SizedBox(height: 4),
        money == null
            ? unknownAmount
            : FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(money.formatted, style: amountStyle),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        s.currency,
                        style: TextStyle(fontSize: 14, color: p.text2),
                      ),
                    ),
                  ],
                ),
              ),
      ],
    );

    final footnotes = <String>[];
    final Widget card;
    switch (s.billing) {
      case BillingKind.unknown:
        final fillIn = AppButton(
          key: const ValueKey('server-fill-costs'),
          label: l10n.uiDetailFillIn,
          kind: AppButtonKind.tonal,
          compact: true,
          onPressed: editable ? () => _openForm(context, s) : null,
        );
        final message = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.serverCostsMissing,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.serverUnknownCostHelp,
              style: TextStyle(fontSize: 13, height: 1.35, color: p.text2),
            ),
          ],
        );
        const icon = AppIconSquare(
          icon: Icons.warning_amber_rounded,
          color: AppTints.orange,
          size: 38,
        );
        card = AppCard(
          child: LayoutBuilder(
            builder: (context, box) => _isNarrow(context, box)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          icon,
                          const SizedBox(width: 12),
                          Expanded(child: message),
                        ],
                      ),
                      const SizedBox(height: 12),
                      fillIn,
                    ],
                  )
                : Row(
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Expanded(child: message),
                      const SizedBox(width: 10),
                      fillIn,
                    ],
                  ),
          ),
        );
      case BillingKind.metered:
        footnotes.add(l10n.serverMeteredValueHelp);
        card = AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: amountBlock(l10n.serverMonthlyEstimate)),
              const SizedBox(width: 8),
              Flexible(child: StatusPill(l10n.serverMeteredBilling)),
            ],
          ),
        );
      case BillingKind.prepaid:
        final valuation = serverValuation(
          s,
          controller.periodsFor(s.id),
          controller.today,
        );
        final days = controller.dueIn(s);
        final tone = days == null
            ? AppTone.neutral
            : days < 0
            ? AppTone.red
            : days < 30
            ? AppTone.amber
            : AppTone.neutral;
        final start = s.startDate ?? valuation?.activePeriod.start;
        final elapsed = _elapsedShare(start, s.dueDate);
        final fx = controller.fx;
        final stats = <(String, String)>[];
        if (valuation == null) {
          footnotes.add(l10n.serverUnknownValueHelp);
        } else {
          final amount = valuation.amount;
          final converted =
              amount.known && amount.currency != fx.displayCurrency
              ? fx.convert(amount.minor!, amount.currency)
              : null;
          final missingFx =
              amount.known &&
              amount.currency != fx.displayCurrency &&
              converted == null;
          stats.addAll([
            (l10n.serverRemainingValue, amount.formatted),
            converted != null
                ? (
                    l10n.uiDetailConverted(fx.displayCurrency),
                    formatMinor(
                      converted.round(),
                      currency: fx.displayCurrency,
                    ),
                  )
                : (
                    l10n.uiDetailRemainingDays,
                    l10n.financeDaysValue(valuation.remainingDays),
                  ),
            (
              l10n.uiDetailDaily,
              '${currencySymbol(amount.currency)}'
                  '${formatRational(valuation.dailyMinor, digits: 4)}',
            ),
          ]);
          if (missingFx) footnotes.add(l10n.financeMissingFxPreserved);
          if (valuation.futurePeriods > 0) {
            footnotes.add(
              l10n.financeFuturePeriodsNote(valuation.futurePeriods),
            );
          }
          if (valuation.inferred) footnotes.add(l10n.financeInferredPeriods);
          footnotes.add(l10n.financeValueDisclaimer);
        }
        footnotes.insert(0, l10n.serverRenewalValueHelp);
        final dateStyle = TextStyle(
          fontSize: 13,
          color: p.text2,
          fontFeatures: kTabularFigures,
        );
        final amount = amountBlock(
          '${l10n.serverRenewalAmount} · ${l10n.serverMonths(s.cycleMonths)}',
        );
        final duePill = StatusPill(
          _dueText(context, days),
          tone: tone,
          dot: tone != AppTone.neutral,
        );
        final dueLabel = Text(
          l10n.uiDetailDueOn(s.dueDate?.toString() ?? l10n.serverUnknown),
          style: dateStyle,
        );
        final startLabel = Text(
          start?.toString() ?? l10n.serverUnknown,
          style: dateStyle,
        );
        final payments = AppButton(
          key: const ValueKey('server-payments'),
          label: l10n.uiDetailPayments,
          icon: Icons.receipt_long_outlined,
          kind: AppButtonKind.tonal,
          compact: true,
          expand: true,
          onPressed: () => _push(
            context,
            PaymentListPage(controller: controller, serverId: s.id),
          ),
        );
        final estimate = AppButton(
          key: const ValueKey('server-valuation'),
          label: l10n.uiDetailValuation,
          icon: Icons.calculate_outlined,
          kind: AppButtonKind.tonal,
          compact: true,
          expand: true,
          onPressed: controller.refreshFailed
              ? null
              : () => _openCalculator(context, s),
        );
        card = AppCard(
          child: LayoutBuilder(
            builder: (context, box) {
              final narrow = _isNarrow(context, box);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (narrow) ...[
                    amount,
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: duePill,
                    ),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: amount),
                        const SizedBox(width: 8),
                        Flexible(child: duePill),
                      ],
                    ),
                  const SizedBox(height: 14),
                  if (elapsed != null) ...[
                    AppProgressBar(
                      value: elapsed,
                      tone: tone == AppTone.neutral ? AppTone.blue : tone,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (narrow)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        startLabel,
                        const SizedBox(height: 2),
                        dueLabel,
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: startLabel),
                        const SizedBox(width: 8),
                        dueLabel,
                      ],
                    ),
                  if (stats.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Divider(height: 1, thickness: .5, color: p.separator),
                    const SizedBox(height: 12),
                    if (narrow)
                      for (final (label, value) in stats)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Expanded(child: _statLabel(label, p)),
                              const SizedBox(width: 8),
                              _statValue(value, p),
                            ],
                          ),
                        )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < stats.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _statLabel(stats[i].$1, p),
                                  const SizedBox(height: 2),
                                  _statValue(stats[i].$2, p),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                  const SizedBox(height: 14),
                  if (narrow) ...[
                    payments,
                    const SizedBox(height: 8),
                    estimate,
                  ] else
                    Row(
                      children: [
                        Expanded(child: payments),
                        const SizedBox(width: 8),
                        Expanded(child: estimate),
                      ],
                    ),
                ],
              );
            },
          ),
        );
    }

    final rule = controller.reminderFor(s.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(l10n.serverCostExpiry),
        card,
        if (footnotes.isNotEmpty)
          _Footnote(footnotes.join('\n'), top: 7, padding: 32),
        if (rule != null)
          AppSection(
            topSpacing: 12,
            children: [
              AppRow(
                key: const ValueKey('server-reminder'),
                icon: Icons.notifications_none_rounded,
                iconColor: AppTints.red,
                title: l10n.serverReminderPlan,
                subtitle:
                    '${usagePlanLabel(rule.usagePlan, l10n: l10n)} · ${rule.enabled ? '${reminderDaysLabel(rule.leadDays, l10n: l10n)} · ${reminderTime(rule.minuteOfDay)}' : l10n.serverRemindersOff}',
                chevron: true,
                onTap: () => _push(
                  context,
                  ReminderPage(controller: controller, serverId: s.id),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _connectionSection(BuildContext context, ServerRecord s) {
    final l10n = context.l10n;
    final config = controller.security.configFor(s.id);
    final trusted =
        config != null &&
        controller.security.hostTrusts.any(
          (t) =>
              t.port == config.port &&
              t.host.toLowerCase() == config.host.toLowerCase(),
        );
    return AppSection(
      header: l10n.serverConnectionsControl,
      footer: l10n.serverConnectionSafety,
      children: [
        AppRow(
          key: const ValueKey('server-ssh-settings'),
          icon: Icons.terminal_rounded,
          iconColor: AppTints.slate,
          title: l10n.serverSshSettings,
          subtitle: config == null
              ? l10n.serverSshSettingsDescription
              : '${config.username}@${config.host}:${config.port}',
          value: config == null ? l10n.uiDetailNotConfigured : null,
          chevron: true,
          onTap: s.archived ? null : () => _openSshConfiguration(context, s),
        ),
        AppRow(
          key: const ValueKey('server-host-key'),
          icon: Icons.shield_outlined,
          iconColor: AppTints.sky,
          title: l10n.uiDetailHostKey,
          value: trusted
              ? l10n.uiDetailHostKeyTrusted
              : l10n.uiDetailHostKeyFirstUse,
          valueMaxLines: 2,
          chevron: true,
          onTap: () => _push(context, HostTrustPage(ledger: controller)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, controller.security]),
    builder: (context, _) {
      final l10n = context.l10n;
      final s = controller.byId(id);
      if (s == null) {
        return AppScaffold(
          title: l10n.serverDetails,
          largeTitle: false,
          children: [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text(l10n.serverRecordUnavailable)),
            ),
          ],
        );
      }
      final p = context.palette;
      final editable = controller.canMutate && !s.archived;
      final provider = controller.cloud.providers
          .where((x) => x.id == s.providerId)
          .firstOrNull;
      final groupName = controller.groupName(s.groupId, l10n: l10n);
      final subtitle = [
        s.purpose,
        serverProviderLabel(context, controller, s),
        s.region,
      ].where((e) => e.isNotEmpty).join(' · ');
      return AppScaffold(
        title: s.name,
        largeTitle: false,
        revealTitleOnScroll: true,
        actions: [
          AppNavButton.icon(
            s.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
            tooltip: s.favorite
                ? l10n.serverRemoveFavorite
                : l10n.serverSetFavorite,
            color: s.favorite ? p.amberSolid : null,
            onPressed: editable ? () => _toggleFavorite(context, s) : null,
          ),
          AppNavButton.text(
            l10n.serverEdit,
            onPressed: editable ? () => _openForm(context, s) : null,
          ),
          AppNavButton.icon(
            Icons.more_horiz_rounded,
            tooltip: l10n.serverMoreActions,
            onPressed: editable ? () => _showMoreMenu(context, s) : null,
          ),
        ],
        children: [
          if (controller.refreshFailed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: RefreshFailureNotice(controller: controller),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ProviderAvatar(
                  name: provider?.name,
                  mark: provider == null
                      ? null
                      : serverProviderMark(controller, s),
                  size: 60,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 26,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          color: p.text,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.3,
                            color: p.text2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (s.isDemo)
            AppBanner(
              tone: AppTone.amber,
              icon: Icons.info_outline_rounded,
              text: l10n.serverDemoWarning,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            ),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: LayoutBuilder(
              builder: (context, box) {
                final label = Text(
                  l10n.serverHostAddress,
                  style: TextStyle(fontSize: 13, color: p.text2),
                );
                final host = Text(
                  s.host.isEmpty ? l10n.serverNotEntered : s.host,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: kMonoTextStyle.copyWith(
                    fontSize: 15,
                    color: s.host.isEmpty ? p.text3 : p.text,
                  ),
                );
                final copy = Tooltip(
                  message: l10n.serverCopyHost,
                  child: AppButton(
                    key: const ValueKey('server-copy-host'),
                    label: l10n.uiDetailCopy,
                    icon: Icons.copy_outlined,
                    kind: AppButtonKind.tonal,
                    compact: true,
                    onPressed: s.host.isEmpty
                        ? null
                        : () => _copyHost(context, s),
                  ),
                );
                if (_isNarrow(context, box)) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: label),
                          const SizedBox(width: 8),
                          copy,
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, right: 8),
                        child: host,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    label,
                    const SizedBox(width: 10),
                    Expanded(child: host),
                    const SizedBox(width: 8),
                    copy,
                  ],
                );
              },
            ),
          ),
          _quickActions(context, s),
          _costSection(context, s),
          _SectionHeader(
            l10n.resourceHardware,
            action: AppLinkButton(
              label: l10n.serverEditHardware,
              onPressed: editable
                  ? () => _openForm(context, s, focusHardware: true)
                  : null,
            ),
          ),
          HardwareInformationCard(s.resources),
          AppSection(
            header: l10n.serverBasicInfo,
            footer: l10n.serverLocalInfoHelp,
            children: [
              AppKeyValueRow(
                label: l10n.serverOperatingSystem,
                value: s.os,
                placeholder: l10n.serverNotEntered,
              ),
              AppKeyValueRow(label: l10n.serverGroup, value: groupName),
              AppKeyValueRow(
                label: l10n.uiDetailPurpose,
                value: s.purpose,
                placeholder: l10n.serverNotEntered,
              ),
              AppKeyValueRow(
                label: l10n.uiDetailRegion,
                value: s.region,
                placeholder: l10n.serverNotEntered,
              ),
              AppKeyValueRow(
                label: l10n.serverSpecifications,
                value: s.spec,
                placeholder: l10n.serverNotEntered,
              ),
            ],
          ),
          _ServerProviderCard(controller: controller, server: s),
          _connectionSection(context, s),
          if (s.notes.isNotEmpty) ...[
            _SectionHeader(l10n.serverNotes),
            AppCard(
              child: SelectableText(
                s.notes,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
            child: Text(
              l10n.serverSavedMetadata(
                (s.updatedAt.toLocal().toString().substring(0, 16)).toString(),
                (s.id).toString(),
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.5, color: p.text3),
            ),
          ),
        ],
      );
    },
  );
}

/// Small grey caption above a free-form card (same metrics as the
/// [AppSection] header).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 22, 32, 7),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 13, color: context.palette.text2),
        ),
        ?action,
      ],
    ),
  );
}

class _Footnote extends StatelessWidget {
  const _Footnote(this.text, {this.top = 7, this.padding = 16});
  final String text;
  final double top, padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(padding, top, padding, 0),
    child: Text(text, style: context.footnoteStyle),
  );
}

class _ServerProviderCard extends StatefulWidget {
  const _ServerProviderCard({required this.controller, required this.server});
  final LedgerController controller;
  final ServerRecord server;
  @override
  State<_ServerProviderCard> createState() => _ServerProviderCardState();
}

class _ServerProviderCardState extends State<_ServerProviderCard> {
  bool opening = false;
  Future<void> open(Future<void> Function() action) async {
    if (opening) return;
    setState(() => opening = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final server = widget.server;
    final l10n = context.l10n;
    final provider = controller.cloud.providers
        .where((p) => p.id == server.providerId)
        .firstOrNull;
    final binding = controller.cloud.bindingFor(server.id);
    final account = controller.cloud.accounts
        .where((a) => a.id == binding?.accountId)
        .firstOrNull;
    final editable =
        !opening &&
        controller.canMutate &&
        !server.archived &&
        !controller.cloud.busy &&
        !controller.cloud.needsReload;
    final canChange = editable && !server.isDemo;
    return AppSection(
      header: l10n.providerUiProviderAndAdapter,
      footer: l10n.serverPanelLinkHelp,
      children: [
        AppRow(
          key: const ValueKey('server-provider-link'),
          leading: ProviderAvatar(
            name: provider?.name,
            mark: provider == null
                ? null
                : serverProviderMark(controller, server),
            size: 30,
          ),
          title: provider?.name ?? l10n.providerUiUnspecified,
          subtitle: provider?.needsReview == true
              ? l10n.providerUiNeedsReview
              : l10n.providerUiOpenProvider,
          chevron: true,
          onTap: provider == null || opening
              ? null
              : () => open(() async {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProviderDetailsPage(
                        ledger: controller,
                        providerId: provider.id,
                      ),
                    ),
                  );
                }),
        ),
        AppRow(
          key: const ValueKey('server-change-provider'),
          icon: Icons.swap_horiz_rounded,
          iconColor: AppTints.grey,
          title: l10n.providerUiChange,
          enabled: canChange,
          chevron: true,
          onTap: canChange
              ? () => open(() async {
                  await changeServerProvider(context, controller, server);
                })
              : null,
        ),
        if (account != null)
          AppRow(
            key: const ValueKey('server-adapter-link'),
            icon: Icons.cloud_outlined,
            iconColor: AppTints.purple,
            title: account.alias,
            subtitle:
                '${cloudProviderName(account.adapterType)} · '
                '${l10n.providerUiOpenInstance}',
            chevron: true,
            onTap: opening
                ? null
                : () => open(() async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CloudAccountDetailsPage(
                          ledger: controller,
                          accountId: account.id,
                        ),
                      ),
                    );
                  }),
          ),
        AppRow(
          key: const ValueKey('server-cloud-binding'),
          icon: Icons.link_rounded,
          iconColor: AppTints.purple,
          title: binding == null ? l10n.serverLinkPanel : l10n.serverManageLink,
          subtitle: account == null ? l10n.serverNoPanelLink : null,
          enabled: editable,
          chevron: true,
          onTap: editable
              ? () => open(() async {
                  await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServerCloudBindingPage(
                        ledger: controller,
                        serverId: server.id,
                      ),
                    ),
                  );
                })
              : null,
        ),
        if (provider?.needsReview == true && account != null)
          AppRow(
            key: const ValueKey('server-confirm-ownership'),
            icon: Icons.fact_check_outlined,
            iconColor: AppTints.green,
            title: l10n.providerUiConfirmOwnership,
            enabled: editable,
            chevron: true,
            onTap: editable
                ? () => open(() async {
                    await confirmAdapterProviderOwnership(
                      context,
                      controller,
                      account,
                    );
                  })
                : null,
          ),
        if (controller.cloud.needsReload)
          AppRow(
            key: const ValueKey('server-reload-panel'),
            title: l10n.serverReloadPanelDetails,
            center: true,
            enabled: !controller.cloud.busy,
            onTap: controller.cloud.busy
                ? null
                : () => controller.cloud.reload(),
          ),
      ],
    );
  }
}
