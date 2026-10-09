import '../l10n/localized_message.dart';

import 'package:flutter/material.dart';

import '../cloud/provider_pages.dart';
import '../core/app_theme.dart';
import '../core/ui/ui.dart';
import '../data/ledger_store.dart';
import '../finance/fx_page.dart';
import '../l10n/locale_preference.dart';
import '../security/security_pages.dart';
import '../servers/ledger_controller.dart';
import '../servers/refresh_failure_notice.dart';
import '../servers/server_record.dart';
import 'backup_page.dart';
import 'reminder_page.dart';
import 'reminder_scheduler.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});
  final LedgerController controller;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  LedgerController get controller => widget.controller;

  Future<void> language(BuildContext context) async {
    final preference = await showAppSheet<LocalePreference>(
      context,
      title: context.l10n.language,
      builder: (sheetContext) => AppSection(
        topSpacing: 4,
        footer:
            '${sheetContext.l10n.languageDescription}\n${sheetContext.l10n.languageSystemDescription}',
        children: [
          for (final preference in LocalePreference.values)
            Semantics(
              checked: controller.languagePreference == preference,
              inMutuallyExclusiveGroup: true,
              child: AppRow(
                key: ValueKey('language-${preference.storageValue}'),
                title: languageName(sheetContext, preference),
                trailing: controller.languagePreference == preference
                    ? Icon(
                        Icons.check_rounded,
                        size: 22,
                        color: sheetContext.palette.primary,
                      )
                    : null,
                onTap: () => Navigator.pop(sheetContext, preference),
              ),
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

  String themeName(BuildContext context, String mode) => switch (mode) {
    'light' => context.l10n.lightTheme,
    'dark' => context.l10n.darkTheme,
    _ => context.l10n.followSystem,
  };

  Future<void> appearance(BuildContext context) async {
    final mode = await showAppPicker<String>(
      context,
      title: context.l10n.appearance,
      selected: controller.themeMode,
      options: [
        for (final mode in const ['system', 'light', 'dark'])
          AppPickerOption(
            value: mode,
            title: themeName(context, mode),
            key: ValueKey('appearance-$mode'),
          ),
      ],
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
        MaterialPageRoute(builder: (_) => ProvidersPage(ledger: controller)),
      );
    } finally {
      openingCloud = false;
    }
  }

  void push(WidgetBuilder builder) =>
      Navigator.push<void>(context, MaterialPageRoute(builder: builder));

  String notificationValue(BuildContext context) =>
      switch (controller.reminders.state) {
        ReminderSyncState.ready => context.l10n.uiTabsNotifyAllowed,
        ReminderSyncState.denied => context.l10n.uiTabsNotifyDenied,
        ReminderSyncState.unsupported => context.l10n.uiTabsNotifyUnsupported,
        ReminderSyncState.idle => context.l10n.uiTabsNotifyUnchecked,
        ReminderSyncState.syncing => context.l10n.uiTabsNotifyChecking,
        ReminderSyncState.failed => context.l10n.uiTabsNotifyFailed,
      };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, controller.reminders]),
    builder: (context, _) {
      final l10n = context.l10n;
      return AppScaffold(
        title: l10n.settings,
        children: [
          if (controller.refreshFailed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: RefreshFailureNotice(controller: controller),
            ),
          _AppInfoCard(
            name: 'vps tell you',
            description: l10n.appDescription,
            version: l10n.developmentVersion,
          ),
          AppSection(
            header: l10n.uiTabsLedgerSection,
            children: [
              AppRow(
                icon: Icons.folder_outlined,
                iconColor: AppTints.orange,
                title: l10n.manageGroups,
                value: controller.groups.length.toString(),
                chevron: true,
                onTap: () => push((_) => GroupsPage(controller: controller)),
              ),
              AppRow(
                icon: Icons.inventory_2_outlined,
                iconColor: AppTints.purple,
                title: l10n.archivedRecords,
                value: controller.archived.length.toString(),
                chevron: true,
                onTap: () => push((_) => ArchivePage(controller: controller)),
              ),
              AppRow(
                key: const ValueKey('settings-providers'),
                icon: Icons.apartment_outlined,
                iconColor: AppTints.blue,
                title: l10n.providerUiTitle,
                value: controller.cloud.accounts.length.toString(),
                chevron: true,
                onTap: openCloud,
              ),
            ],
          ),
          AppSection(
            header: l10n.uiTabsSecuritySection,
            children: [
              AppRow(
                icon: Icons.shield_outlined,
                iconColor: AppTints.green,
                title: l10n.keysSecurity,
                subtitle: l10n.keysSecurityDescription,
                chevron: true,
                onTap: () => push((_) => SecurityPage(ledger: controller)),
              ),
            ],
          ),
          AppSection(
            header: l10n.uiTabsPreferencesSection,
            children: [
              AppRow(
                icon: Icons.currency_exchange,
                iconColor: AppTints.teal,
                title: l10n.currenciesReferenceRates,
                value: controller.fx.displayCurrency.toString(),
                chevron: true,
                onTap: () => push((_) => FxPage(controller: controller)),
              ),
              AppRow(
                icon: Icons.notifications_none,
                iconColor: AppTints.red,
                title: l10n.notificationAccess,
                value: notificationValue(context),
                chevron: true,
                onTap: () =>
                    push((_) => NotificationPage(controller: controller)),
              ),
              AppRow(
                icon: Icons.brightness_6_outlined,
                iconColor: AppTints.indigo,
                title: l10n.appearance,
                value: themeName(context, controller.themeMode),
                chevron: true,
                enabled: controller.canMutate,
                onTap: () => appearance(context),
              ),
              AppRow(
                key: const ValueKey('language-setting'),
                icon: Icons.language,
                iconColor: AppTints.sky,
                title: l10n.language,
                value: languageName(context, controller.languagePreference),
                chevron: true,
                enabled: controller.canMutate && !controller.savingLanguage,
                onTap: () => language(context),
              ),
            ],
          ),
          AppSection(
            header: l10n.uiTabsDataSection,
            footer: l10n.appLocalDataHelp,
            children: [
              AppRow(
                icon: Icons.save_alt,
                iconColor: AppTints.slate,
                title: l10n.ledgerBackupRestore,
                subtitle: l10n.backupExclusionsSummary,
                chevron: true,
                onTap: () => push((_) => BackupPage(controller: controller)),
              ),
            ],
          ),
        ],
      );
    },
  );
}

/// Header group of the settings page: gradient app icon, name and version.
class _AppInfoCard extends StatelessWidget {
  const _AppInfoCard({
    required this.name,
    required this.description,
    required this.version,
  });
  final String name, description, version;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTints.blue, AppTints.indigo],
              ),
            ),
            child: const Icon(
              Icons.dns_outlined,
              size: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, height: 1.35, color: p.text2),
                ),
                Text(
                  version,
                  style: TextStyle(fontSize: 13, height: 1.35, color: p.text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _refreshNotice(LedgerController controller) => Padding(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
  child: RefreshFailureNotice(controller: controller),
);

/// Free-form text row inside a grouped section.
class _TextRow extends StatelessWidget {
  const _TextRow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Text(text, style: TextStyle(color: context.palette.text2)),
  );
}

class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key, required this.controller});
  final LedgerController controller;
  Future<void> edit(BuildContext context, [ServerGroup? group]) async {
    final result = await showAppModal<String>(
      context,
      builder: (_) => _GroupNameSheet(name: group?.name),
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
      final ok = await showAppConfirm(
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

  void openMenu(BuildContext context, ServerGroup group) {
    final l10n = context.l10n;
    final index = controller.groups.indexOf(group);
    showAppActionMenu<void>(
      context,
      title: group.name,
      actions: [
        AppMenuAction(
          label: l10n.rename,
          onPressed: () => menu(context, group, 'rename'),
        ),
        if (index != 0)
          AppMenuAction(
            label: l10n.moveUp,
            onPressed: () => menu(context, group, 'up'),
          ),
        if (index != controller.groups.length - 1)
          AppMenuAction(
            label: l10n.moveDown,
            onPressed: () => menu(context, group, 'down'),
          ),
        AppMenuAction(
          label: l10n.deleteGroup,
          destructive: true,
          onPressed: () => menu(context, group, 'delete'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l10n = context.l10n;
      int count(String? id) =>
          controller.active.where((s) => s.groupId == id).length;
      return AppScaffold(
        title: l10n.manageGroups,
        largeTitle: false,
        actions: [
          AppNavButton.icon(
            Icons.add,
            tooltip: l10n.addGroup,
            onPressed: controller.canMutate ? () => edit(context) : null,
          ),
        ],
        children: [
          if (controller.refreshFailed) _refreshNotice(controller),
          AppSection(
            footer: l10n.groupsHelp,
            children: [
              if (controller.groups.isEmpty) _TextRow(l10n.noGroupsHelp),
              for (final g in controller.groups)
                AppRow(
                  icon: Icons.folder_outlined,
                  iconColor: AppTints.orange,
                  title: g.name,
                  subtitle: l10n.unarchivedServerCount(count(g.id).toString()),
                  enabled: controller.canMutate,
                  onTap: () => openMenu(context, g),
                  trailing: IconButton(
                    tooltip: l10n.actionsForGroup(g.name),
                    visualDensity: VisualDensity.compact,
                    onPressed: controller.canMutate
                        ? () => openMenu(context, g)
                        : null,
                    icon: Icon(Icons.more_horiz, color: context.palette.text3),
                  ),
                ),
            ],
          ),
          AppSection(
            children: [
              AppRow(
                icon: Icons.folder_off_outlined,
                iconColor: AppTints.grey,
                title: l10n.ungrouped,
                subtitle: l10n.ungroupedCountHelp(count(null).toString()),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key, required this.controller});
  final LedgerController controller;

  Future<void> restore(BuildContext context, ServerRecord s) async {
    try {
      await controller.mutate(
        () => controller.store.undoArchive(ArchiveUndo(s.id, s.revision)),
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
    builder: (context, _) {
      final l10n = context.l10n;
      return AppScaffold(
        title: l10n.archivedRecords,
        largeTitle: false,
        children: [
          if (controller.refreshFailed) _refreshNotice(controller),
          AppSection(
            footer: l10n.archiveHelp,
            children: [
              if (controller.archived.isEmpty) _TextRow(l10n.noArchivedRecords),
              for (final s in controller.archived)
                AppRow(
                  icon: Icons.inventory_2_outlined,
                  iconColor: AppTints.purple,
                  title: s.name,
                  subtitle:
                      '${serverProviderLabel(context, controller, s)} · ${controller.groupName(s.groupId)}',
                  trailing: AppLinkButton(
                    label: l10n.restoreRecord,
                    onPressed: controller.canMutate
                        ? () => restore(context, s)
                        : null,
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );
}

class _GroupNameSheet extends StatefulWidget {
  const _GroupNameSheet({this.name});
  final String? name;
  @override
  State<_GroupNameSheet> createState() => _GroupNameSheetState();
}

class _GroupNameSheetState extends State<_GroupNameSheet> {
  late final TextEditingController field = TextEditingController(
    text: widget.name,
  );
  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScaffold.modal(
    title: widget.name == null
        ? context.l10n.addGroup
        : context.l10n.renameGroup,
    actionLabel: context.l10n.save,
    onAction: () => Navigator.pop(context, field.text),
    children: [
      AppSection(
        children: [
          AppFormRow(
            label: context.l10n.groupName,
            child: AppTextField(
              key: const ValueKey('group-name'),
              controller: field,
              autofocus: true,
              maxLength: 40,
              label: context.l10n.groupName,
            ),
          ),
        ],
      ),
    ],
  );
}
