import '../l10n/localized_message.dart';

import 'package:flutter/material.dart';

import '../cloud/cloud_pages.dart';
import '../core/app_theme.dart';
import '../data/ledger_store.dart';
import '../finance/fx_page.dart';
import '../l10n/locale_preference.dart';
import '../security/security_pages.dart';
import '../servers/ledger_controller.dart';
import '../servers/refresh_failure_notice.dart';
import '../servers/server_record.dart';
import 'backup_page.dart';
import 'reminder_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});
  final LedgerController controller;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  LedgerController get controller => widget.controller;

  Future<void> language(BuildContext context) async {
    final preference = await showDialog<LocalePreference>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.language),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(context.l10n.languageDescription),
          ),
          for (final preference in LocalePreference.values)
            Semantics(
              checked: controller.languagePreference == preference,
              inMutuallyExclusiveGroup: true,
              child: SimpleDialogOption(
                key: ValueKey('language-${preference.storageValue}'),
                onPressed: () => Navigator.pop(context, preference),
                child: Row(
                  children: [
                    Icon(
                      controller.languagePreference == preference
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(languageName(context, preference))),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: Text(context.l10n.languageSystemDescription),
          ),
        ],
      ),
    );
    if (preference == null) {
      return;
    }
    try {
      await controller.setLanguage(preference);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) => Text(context.l10n.languageSaveFailed),
            ),
          ),
        );
      }
    }
  }

  String languageName(BuildContext context, LocalePreference preference) =>
      switch (preference) {
        LocalePreference.chinese => context.l10n.languageChinese,
        LocalePreference.english => context.l10n.languageEnglish,
        LocalePreference.system => context.l10n.languageSystem,
      };
  Future<void> appearance(BuildContext context) async {
    final mode = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.appearance),
        children: [
          for (final entry in {
            'system': context.l10n.followSystem,
            'light': context.l10n.lightTheme,
            'dark': context.l10n.darkTheme,
          }.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, entry.key),
              child: Text(
                '${controller.themeMode == entry.key ? '✓ ' : ''}${entry.value}',
              ),
            ),
        ],
      ),
    );
    if (mode == null) {
      return;
    }
    try {
      await controller.mutate(() => controller.store.saveThemeMode(mode));
    } catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }

  bool openingCloud = false;
  Future<void> openCloud() async {
    if (openingCloud) {
      return;
    }
    openingCloud = true;
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CloudAccountsPage(ledger: controller),
        ),
      );
    } finally {
      openingCloud = false;
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        context.l10n.settings,
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 22),
      if (controller.refreshFailed)
        RefreshFailureNotice(controller: controller),
      LedgerCard(
        child: Row(
          children: [
            Icon(
              Icons.dns_outlined,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'vps tell you',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    context.l10n.appDescription,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      SectionTitle(context.l10n.organizationData),
      LedgerCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            SettingRow(
              icon: Icons.folder_outlined,
              title: context.l10n.manageGroups,
              subtitle: context.l10n.groupCountHelp(
                (controller.groups.length).toString(),
              ),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupsPage(controller: controller),
                ),
              ),
            ),
            const Divider(),
            SettingRow(
              icon: Icons.inventory_2_outlined,
              title: context.l10n.archivedRecords,
              subtitle: context.l10n.archiveCountHelp(
                (controller.archived.length).toString(),
              ),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ArchivePage(controller: controller),
                ),
              ),
            ),
          ],
        ),
      ),
      SectionTitle(context.l10n.accountsPreferences),
      LedgerCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            SettingRow(
              icon: Icons.cloud_outlined,
              title: context.l10n.panelAccounts,
              subtitle: context.l10n.panelConnectionCount(
                (controller.cloud.accounts.length).toString(),
              ),
              onTap: openCloud,
            ),
            const Divider(),
            SettingRow(
              icon: Icons.shield_outlined,
              title: context.l10n.keysSecurity,
              subtitle: context.l10n.keysSecurityDescription,
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => SecurityPage(ledger: controller),
                ),
              ),
            ),
            const Divider(),
            SettingRow(
              icon: Icons.currency_exchange,
              title: context.l10n.currenciesReferenceRates,
              subtitle: context.l10n.currencyRateSummary(
                (controller.fx.displayCurrency).toString(),
                (controller.fx.rateDate ?? context.l10n.notSet).toString(),
              ),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => FxPage(controller: controller),
                ),
              ),
            ),
            const Divider(),
            SettingRow(
              icon: Icons.notifications_none,
              title: context.l10n.notificationAccess,
              subtitle: controller.reminders.descriptionFor(context.l10n),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationPage(controller: controller),
                ),
              ),
            ),
            const Divider(),
            SettingRow(
              icon: Icons.brightness_6_outlined,
              title: context.l10n.appearance,
              subtitle:
                  {
                    'system': context.l10n.followSystem,
                    'light': context.l10n.lightTheme,
                    'dark': context.l10n.darkTheme,
                  }[controller.themeMode] ??
                  context.l10n.followSystem,
              onTap: controller.canMutate ? () => appearance(context) : null,
            ),
            const Divider(),
            SettingRow(
              key: const ValueKey('language-setting'),
              icon: Icons.language,
              title: context.l10n.language,
              subtitle: languageName(context, controller.languagePreference),
              onTap: controller.canMutate && !controller.savingLanguage
                  ? () => language(context)
                  : null,
            ),
            const Divider(),
            SettingRow(
              icon: Icons.save_alt,
              title: context.l10n.ledgerBackupRestore,
              subtitle: context.l10n.backupExclusionsSummary,
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => BackupPage(controller: controller),
                ),
              ),
            ),
          ],
        ),
      ),
      SectionTitle(context.l10n.about),
      LedgerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.developmentVersion,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            InfoNote(context.l10n.appLocalDataHelp),
          ],
        ),
      ),
    ],
  );
}

class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key, required this.controller});
  final LedgerController controller;
  Future<void> edit(BuildContext context, [ServerGroup? group]) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _GroupNameDialog(name: group?.name),
    );
    if (result != null) {
      try {
        await controller.mutate(
          () => controller.store.saveGroup(result, id: group?.id),
        );
      } catch (error) {
        if (context.mounted) {
          showFailure(
            context,
            error,
            fallbackMessage: LocalizedText((l10n) => l10n.groupSaveFailed),
          );
        }
      }
    }
  }

  Future<void> menu(
    BuildContext context,
    ServerGroup group,
    String action,
  ) async {
    if (action == 'rename') {
      return edit(context, group);
    }
    if (action == 'delete') {
      final ok = await confirmAction(
        context,
        title: LocalizedText(
          (l10n) => l10n.deleteGroupQuestion((group.name).toString()),
        ),
        message: LocalizedText((l10n) => l10n.deleteGroupHelp),
        action: LocalizedText((l10n) => l10n.deleteGroup),
        dangerous: true,
      );
      if (!ok) {
        return;
      }
    }
    try {
      await controller.mutate(
        () => action == 'delete'
            ? controller.store.deleteGroup(group.id)
            : controller.store.moveGroup(group.id, action == 'up' ? -1 : 1),
      );
    } catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.manageGroups),
        actions: [
          IconButton(
            tooltip: context.l10n.addGroup,
            onPressed: controller.canMutate ? () => edit(context) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (controller.refreshFailed)
            RefreshFailureNotice(controller: controller),
          InfoNote(context.l10n.groupsHelp),
          if (controller.groups.isEmpty)
            LedgerCard(child: Text(context.l10n.noGroupsHelp)),
          for (final g in controller.groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LedgerCard(
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            context.l10n.unarchivedServerCount(
                              (controller.active
                                      .where((s) => s.groupId == g.id)
                                      .length)
                                  .toString(),
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: context.l10n.actionsForGroup(
                        (g.name).toString(),
                      ),
                      enabled: controller.canMutate,
                      onSelected: (a) => menu(context, g, a),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: Builder(
                            builder: (context) => Text(context.l10n.rename),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'up',
                          child: Builder(
                            builder: (context) => Text(context.l10n.moveUp),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'down',
                          child: Builder(
                            builder: (context) => Text(context.l10n.moveDown),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Builder(
                            builder: (context) =>
                                Text(context.l10n.deleteGroup),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          LedgerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.ungrouped,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                InfoNote(
                  context.l10n.ungroupedCountHelp(
                    (controller.active.where((s) => s.groupId == null).length)
                        .toString(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key, required this.controller});
  final LedgerController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(context.l10n.archivedRecords)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (controller.refreshFailed)
            RefreshFailureNotice(controller: controller),
          InfoNote(context.l10n.archiveHelp),
          if (controller.archived.isEmpty)
            LedgerCard(child: Text(context.l10n.noArchivedRecords)),
          for (final s in controller.archived)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LedgerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      '${s.vendor} · ${controller.groupName(s.groupId)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: !controller.canMutate
                          ? null
                          : () async {
                              try {
                                await controller.mutate(
                                  () => controller.store.undoArchive(
                                    ArchiveUndo(s.id, s.revision),
                                  ),
                                );
                              } catch (error) {
                                if (context.mounted) {
                                  showFailure(context, error);
                                }
                              }
                            },
                      icon: const Icon(Icons.restore, size: 18),
                      label: Text(context.l10n.restoreRecord),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _GroupNameDialog extends StatefulWidget {
  const _GroupNameDialog({this.name});
  final String? name;
  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  late final TextEditingController field = TextEditingController(
    text: widget.name,
  );
  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(
      widget.name == null ? context.l10n.addGroup : context.l10n.renameGroup,
    ),
    content: TextField(
      key: const ValueKey('group-name'),
      controller: field,
      autofocus: true,
      maxLength: 40,
      decoration: InputDecoration(labelText: context.l10n.groupName),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, field.text),
        child: Text(context.l10n.save),
      ),
    ],
  );
}
