import 'package:flutter/material.dart';

import '../core/app_theme.dart' show showFailure;
import '../core/ui/ui.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import '../servers/ledger_controller.dart';
import 'provider_directory.dart';
import 'provider_record.dart';

extension DirectoryProviderL10n on DirectoryProvider {
  /// Name in the interface language (Chinese, otherwise English).
  String displayName(AppLocalizations l10n) => nameFor(l10n.localeName);

  /// Description in the interface language; empty when there is none.
  String displayDescription(AppLocalizations l10n) =>
      descriptionFor(l10n.localeName);

  /// What the local provider is created with when the user picks this entry.
  CatalogProviderRef refIn(AppLocalizations l10n) =>
      CatalogProviderRef(catalogId: id, name: displayName(l10n));
}

/// "just now", "5 minutes ago", "3 hours ago", "2 days ago".
String relativeTime(AppLocalizations l10n, DateTime then, DateTime now) {
  final age = now.difference(then);
  if (age.inMinutes < 1) return l10n.r9TimeJustNow;
  if (age.inHours < 1) return l10n.r9TimeMinutesAgo(age.inMinutes);
  if (age.inDays < 1) return l10n.r9TimeHoursAgo(age.inHours);
  return l10n.r9TimeDaysAgo(age.inDays);
}

/// The hint shown in place of the directory list while there is no directory
/// (never downloaded, or no cache and offline). "None" and custom providers
/// keep working.
class DirectoryEmptyHint extends StatelessWidget {
  const DirectoryEmptyHint({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 18, 32, 8),
    child: Text(
      context.l10n.r9DirEmptyHint,
      key: const ValueKey('directory-empty-hint'),
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13, height: 1.4, color: context.palette.text2),
    ),
  );
}

/// True when the directory should be replaced by [DirectoryEmptyHint]: it has
/// been read (so there is no flash at start-up) and holds nothing.
bool directoryIsEmpty(ProviderDirectory directory) =>
    directory.loaded && directory.providers.isEmpty;

/// Settings → Providers: status of the directory, "Check for Updates" and the
/// "Update on Launch" switch.
class DirectorySettingsSection extends StatelessWidget {
  const DirectorySettingsSection({super.key, required this.ledger});
  final LedgerController ledger;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final directory = ledger.directory;
    final snapshot = directory.snapshot;
    final outcome = directory.lastOutcome;
    final checked = directory.checkedAt;
    final status = switch (outcome) {
      DirectoryOutcome.upToDate => l10n.r9DirUpToDate,
      DirectoryOutcome.updated => l10n.r9DirUpdated,
      DirectoryOutcome.failed => l10n.r9DirUnreachable,
      null => null,
    };
    final when = checked == null
        ? l10n.r9DirNeverChecked
        : l10n.r9DirChecked(relativeTime(l10n, checked, ledger.clock()));
    return AppSection(
      header: l10n.r9DirSection,
      footer: l10n.r9DirAutoFooter,
      children: [
        AppRow(
          key: const ValueKey('directory-status'),
          icon: Icons.cloud_download_outlined,
          iconColor: AppTints.slate,
          title: snapshot == null
              ? l10n.r9DirNone
              : l10n.r9DirSummary(
                  snapshot.catalogVersion,
                  snapshot.providers.length,
                ),
          subtitle: [?status, when].join(' · '),
          subtitleMaxLines: 3,
        ),
        AppRow.custom(
          child: Center(
            child: AppButton(
              key: const ValueKey('directory-check'),
              label: l10n.r9DirCheck,
              icon: Icons.refresh_rounded,
              kind: AppButtonKind.plain,
              compact: true,
              busy: directory.checking,
              onPressed: () => directory.refresh(),
            ),
          ),
        ),
        AppSwitchRow(
          key: const ValueKey('directory-auto'),
          title: l10n.r9DirAuto,
          value: ledger.directoryAuto,
          onChanged: (value) async {
            try {
              await ledger.setDirectoryAuto(value);
            } catch (error) {
              if (context.mounted) showFailure(context, error);
            }
          },
        ),
      ],
    );
  }
}
