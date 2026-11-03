import 'package:flutter/material.dart';

import '../core/app_theme.dart' show showFailure;
import '../core/ui/ui.dart';
import '../data/ledger_store.dart' show ArchiveUndo;
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../providers/directory_widgets.dart';
import 'ledger_controller.dart';
import 'refresh_failure_notice.dart';
import 'server_record.dart';

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
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: context.palette.text2),
    ),
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
        await controller.saveGroup(result, id: group?.id);
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
      if (action == 'delete') {
        await controller.deleteGroup(group.id);
      } else {
        await controller.moveGroup(group.id, action == 'up' ? -1 : 1);
      }
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
      final counts = <String?, int>{};
      for (final s in controller.active) {
        counts[s.groupId] = (counts[s.groupId] ?? 0) + 1;
      }
      int count(String? id) => counts[id] ?? 0;
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
        slivers: [
          if (controller.refreshFailed)
            SliverToBoxAdapter(child: _refreshNotice(controller)),
          AppLazySections(
            sections: [
              AppListSection(
                topSpacing: 16,
                footer: l10n.archiveHelp,
                count: controller.archived.isEmpty
                    ? 1
                    : controller.archived.length,
                itemKey: (i) => controller.archived.isEmpty
                    ? const ValueKey('archive-empty')
                    : ValueKey('archive-${controller.archived[i].id}'),
                itemBuilder: (context, i) {
                  if (controller.archived.isEmpty)
                    return _TextRow(l10n.noArchivedRecords);
                  final s = controller.archived[i];
                  return AppRow(
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
                  );
                },
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
