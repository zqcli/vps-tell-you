import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../cloud/cloud_pages.dart';
import '../cloud/provider_pages.dart';
import '../cloud/cloud_widgets.dart';
import '../cloud/server_cloud_binding_page.dart';
import '../core/app_theme.dart';
import '../connections/connection_pages.dart';
import '../connections/tcp_test_page.dart';
import '../finance/calculator_page.dart';
import '../finance/finance_math.dart';
import '../finance/finance_widgets.dart';
import '../finance/payment_pages.dart';
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
    final confirmed = await confirmAction(
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

  Widget value(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        SelectableText(
          value.isEmpty ? context.l10n.serverMissingDetails : value,
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final s = controller.byId(id);
      if (s == null) {
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.serverDetails)),
          body: Center(child: Text(context.l10n.serverRecordUnavailable)),
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.serverDetails),
          actions: [
            IconButton(
              tooltip: s.favorite
                  ? context.l10n.serverRemoveFavorite
                  : context.l10n.serverSetFavorite,
              onPressed: !controller.canMutate || s.archived
                  ? null
                  : () async {
                      try {
                        await controller.mutate(
                          () => controller.store.setFavorite(s, !s.favorite),
                        );
                      } catch (error) {
                        if (context.mounted) {
                          showFailure(context, error);
                        }
                      }
                    },
              icon: Icon(
                s.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: context.l10n.serverMoreActions,
              enabled: controller.canMutate && !s.archived,
              onSelected: (_) => archive(context, s),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'archive',
                  child: Builder(
                    builder: (context) => Text(
                      context.l10n.serverArchiveLocal,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (controller.refreshFailed)
              RefreshFailureNotice(controller: controller),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    serverProviderMark(controller, s),
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        [
                          s.purpose,
                          serverProviderLabel(context, controller, s),
                          s.region,
                        ].where((e) => e.isNotEmpty).join(' · '),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (s.isDemo)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: LedgerBadge(context.l10n.serverDemoWarning),
              ),
            SectionTitle(
              context.l10n.serverBasicInfo,
              action: TextButton(
                onPressed: !controller.canMutate || s.archived
                    ? null
                    : () => Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ServerForm(controller: controller, record: s),
                        ),
                      ),
                child: Text(context.l10n.serverEdit),
              ),
            ),
            LedgerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: value(
                          context,
                          context.l10n.serverHostAddress,
                          s.host,
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.serverCopyHost,
                        onPressed: s.host.isEmpty
                            ? null
                            : () async {
                                try {
                                  await Clipboard.setData(
                                    ClipboardData(text: s.host),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Builder(
                                          builder: (context) => Text(
                                            context.l10n.serverHostCopied,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                } catch (error) {
                                  if (context.mounted) {
                                    showFailure(
                                      context,
                                      error,
                                      fallbackMessage: LocalizedText(
                                        (l10n) => l10n.serverCopyHostFailed,
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: const Icon(Icons.copy_outlined, size: 20),
                      ),
                    ],
                  ),
                  const Divider(),
                  value(context, context.l10n.serverOperatingSystem, s.os),
                  value(
                    context,
                    context.l10n.serverGroupPurpose,
                    '${controller.groupName(s.groupId, l10n: context.l10n)} · ${s.purpose.isEmpty ? context.l10n.serverMissingDetails : s.purpose}',
                  ),
                  value(context, context.l10n.serverSpecifications, s.spec),
                  InfoNote(context.l10n.serverLocalInfoHelp),
                ],
              ),
            ),
            SectionTitle(
              context.l10n.resourceHardware,
              action: TextButton(
                onPressed: !controller.canMutate || s.archived
                    ? null
                    : () => Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServerForm(
                            controller: controller,
                            record: s,
                            focusHardware: true,
                          ),
                        ),
                      ),
                child: Text(context.l10n.serverEditHardware),
              ),
            ),
            HardwareInformationCard(s.resources),
            SectionTitle(context.l10n.providerUiProviderAndAdapter),
            _ServerProviderCard(controller: controller, server: s),
            SectionTitle(context.l10n.serverCostExpiry),
            LedgerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.billing == BillingKind.metered
                        ? context.l10n.serverMonthlyEstimate
                        : s.billing == BillingKind.prepaid
                        ? context.l10n.serverRenewalAmount
                        : context.l10n.serverCostsMissing,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (s.money != null && s.billing != BillingKind.unknown)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 8,
                      children: [
                        Text(
                          s.money!.formatted,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(s.currency),
                      ],
                    ),
                  if (s.billing == BillingKind.prepaid) ...[
                    value(
                      context,
                      context.l10n.serverRenewalCycle,
                      context.l10n.serverMonths(s.cycleMonths),
                    ),
                    value(
                      context,
                      context.l10n.serverServiceStart,
                      s.startDate?.toString() ?? context.l10n.serverUnknown,
                    ),
                    value(
                      context,
                      context.l10n.serverServiceDue,
                      s.dueDate?.toString() ?? context.l10n.serverUnknown,
                    ),
                  ],
                  InfoNote(
                    s.billing == BillingKind.unknown
                        ? context.l10n.serverUnknownCostHelp
                        : s.billing == BillingKind.metered
                        ? context.l10n.serverMeteredValueHelp
                        : context.l10n.serverRenewalValueHelp,
                  ),
                  if (controller.reminderFor(s.id) case final rule?)
                    SettingRow(
                      icon: Icons.notifications_none,
                      title: context.l10n.serverReminderPlan,
                      subtitle:
                          '${usagePlanLabel(rule.usagePlan, l10n: context.l10n)} · ${rule.enabled ? '${reminderDaysLabel(rule.leadDays, l10n: context.l10n)} · ${reminderTime(rule.minuteOfDay)}' : context.l10n.serverRemindersOff}',
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReminderPage(
                            controller: controller,
                            serverId: s.id,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (s.billing == BillingKind.prepaid) ...[
              SectionTitle(context.l10n.serverRemainingValue),
              Builder(
                builder: (context) {
                  final valuation = serverValuation(
                    s,
                    controller.periodsFor(s.id),
                    controller.today,
                  );
                  if (valuation == null) {
                    return LedgerCard(
                      child: InfoNote(context.l10n.serverUnknownValueHelp),
                    );
                  }
                  return ValuationCard(
                    value: valuation,
                    renewal: s.money!,
                    cycleMonths: s.cycleMonths,
                    due: s.dueDate!,
                    asOf: controller.today,
                    fx: controller.fx,
                  );
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed:
                        !controller.canMutate || s.archived || !canRenew(s)
                        ? null
                        : () => Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentForm(
                                controller: controller,
                                server: s,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.add_card_outlined),
                    label: Text(context.l10n.serverRecordPayment),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.refreshFailed
                        ? null
                        : () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CalculatorPage(
                                controller: controller,
                                server: s,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.calculate_outlined),
                    label: Text(context.l10n.serverUseForCalculation),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PaymentListPage(controller: controller, serverId: s.id),
                ),
              ),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(context.l10n.serverViewPayments),
            ),
            SectionTitle(context.l10n.serverConnectionsControl),
            LedgerCard(
              padding: EdgeInsets.zero,
              child: SettingRow(
                icon: Icons.terminal,
                title: context.l10n.serverSshSettings,
                subtitle: context.l10n.serverSshSettingsDescription,
                onTap: s.archived
                    ? null
                    : () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SshConfigurationPage(
                            ledger: controller,
                            serverId: s.id,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: s.archived || s.isDemo
                      ? null
                      : () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SshConnectPage(
                              ledger: controller,
                              initialServerId: s.id,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.terminal),
                  label: Text(context.l10n.serverConnectSsh),
                ),
                OutlinedButton.icon(
                  onPressed: s.archived || s.isDemo
                      ? null
                      : () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TcpTestPage(
                              initialHost: s.host,
                              initialPort:
                                  controller.security.configFor(s.id)?.port ??
                                  22,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.monitor_heart_outlined),
                  label: Text(context.l10n.serverTcpTest),
                ),
                OutlinedButton.icon(
                  onPressed: s.archived || s.isDemo
                      ? null
                      : () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SshConnectPage(
                              ledger: controller,
                              initialServerId: s.id,
                              powerMode: true,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.power_settings_new),
                  label: Text(context.l10n.serverPower),
                ),
              ],
            ),
            InfoNote(context.l10n.serverConnectionSafety),
            if (s.notes.isNotEmpty) ...[
              SectionTitle(context.l10n.serverNotes),
              LedgerCard(child: SelectableText(s.notes)),
            ],
            InfoNote(
              context.l10n.serverSavedMetadata(
                (s.updatedAt.toLocal().toString().substring(0, 16)).toString(),
                (s.id).toString(),
              ),
            ),
          ],
        ),
      );
    },
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
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingRow(
            key: const ValueKey('server-provider-link'),
            icon: Icons.business_outlined,
            title: provider?.name ?? context.l10n.providerUiUnspecified,
            subtitle: provider?.needsReview == true
                ? context.l10n.providerUiNeedsReview
                : context.l10n.providerUiOpenProvider,
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
          TextButton.icon(
            key: const ValueKey('server-change-provider'),
            onPressed: editable && !server.isDemo
                ? () => open(() async {
                    await changeServerProvider(context, controller, server);
                  })
                : null,
            icon: const Icon(Icons.swap_horiz),
            label: Text(context.l10n.providerUiChange),
          ),
          const Divider(),
          if (account != null)
            SettingRow(
              key: const ValueKey('server-adapter-link'),
              icon: Icons.cloud_outlined,
              title: account.alias,
              subtitle:
                  '${cloudProviderName(account.adapterType)} · '
                  '${context.l10n.providerUiOpenInstance}',
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
            )
          else
            Text(
              context.l10n.serverNoPanelLink,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          InfoNote(context.l10n.serverPanelLinkHelp),
          if (provider?.needsReview == true && account != null)
            OutlinedButton.icon(
              onPressed: editable
                  ? () => open(() async {
                      await confirmAdapterProviderOwnership(
                        context,
                        controller,
                        account,
                      );
                    })
                  : null,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(context.l10n.providerUiConfirmOwnership),
            ),
          OutlinedButton.icon(
            key: const ValueKey('server-cloud-binding'),
            onPressed: editable
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
            icon: const Icon(Icons.link),
            label: Text(
              binding == null
                  ? context.l10n.serverLinkPanel
                  : context.l10n.serverManageLink,
            ),
          ),
          if (controller.cloud.needsReload)
            TextButton(
              onPressed: controller.cloud.busy
                  ? null
                  : () => controller.cloud.reload(),
              child: Text(context.l10n.serverReloadPanelDetails),
            ),
        ],
      ),
    );
  }
}
