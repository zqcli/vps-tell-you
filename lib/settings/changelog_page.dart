import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ui/ui.dart';
import '../l10n/locale_preference.dart';
import '../core/app_info.dart';
import 'about_common.dart';
import 'changelog.dart';

/// Asset holding the changelog for [languageCode]; Chinese is the fallback.
String changelogAsset(String languageCode) =>
    languageCode == 'en' ? 'CHANGELOG.en.md' : 'CHANGELOG.md';

// Uncached: the text is read once per visit and never kept in memory.
Future<String> _loadAsset(String asset) =>
    rootBundle.loadString(asset, cache: false);

/// Settings › About › What's New: renders the bundled changelog.
class ChangelogPage extends StatefulWidget {
  const ChangelogPage({super.key, this.load});

  /// Test seam; defaults to `rootBundle.loadString`.
  final Future<String> Function(String asset)? load;

  @override
  State<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<ChangelogPage> {
  Future<List<ChangelogRelease>>? releases;
  String? asset;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = changelogAsset(Localizations.localeOf(context).languageCode);
    if (next == asset) return;
    asset = next;
    releases = (widget.load ?? _loadAsset)(next).then(parseChangelog);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      title: l10n.r11AboutWhatsNew,
      largeTitle: false,
      children: [
        FutureBuilder<List<ChangelogRelease>>(
          future: releases,
          builder: (context, snapshot) {
            if (snapshot.hasError || (snapshot.data?.isEmpty ?? false)) {
              return AboutNotice(l10n.r11ChangelogUnavailable);
            }
            final data = snapshot.data;
            if (data == null) return const AboutLoading();
            return AppSection(
              topSpacing: 12,
              footer: l10n.r17ChangelogFooter,
              children: [
                for (final release in data)
                  AppRow(
                    key: ValueKey('changelog-${release.version}'),
                    title: release.version,
                    subtitle: release.label.isEmpty ? null : release.label,
                    value: release.version == kAppVersion
                        ? l10n.r17CurrentVersion
                        : l10n.r17ChangelogCount(release.bulletCount),
                    chevron: true,
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangelogReleasePage(release: release),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One version: its sections, and the matching GitHub release when tagged.
class ChangelogReleasePage extends StatelessWidget {
  const ChangelogReleasePage({super.key, required this.release});
  final ChangelogRelease release;

  String get releaseUrl => '$kRepoUrl/releases/tag/${release.tag}';

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: releaseUrl));
    if (context.mounted) {
      showAppToast(context, context.l10n.r17ReleaseLinkCopied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      title: release.version,
      largeTitle: false,
      children: [
        if (release.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
            child: Text(release.label, style: context.footnoteStyle),
          ),
        for (final section in release.sections) _Section(section),
        if (release.released)
          AppSection(
            children: [
              AppRow(
                key: const ValueKey('changelog-github-release'),
                icon: Icons.sell_outlined,
                iconColor: AppTints.slate,
                title: l10n.r17GithubRelease,
                subtitle: release.tag,
                onTap: () => _copyLink(context),
              ),
            ],
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.section);
  final ChangelogSection section;

  @override
  Widget build(BuildContext context) {
    final bullets = [
      for (final i in section.items)
        if (i.bullet) i,
    ];
    final notes = [
      for (final i in section.items)
        if (!i.bullet) i,
    ];
    final noteWidgets = [
      for (final note in notes)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text.rich(boldSpans(note.text), style: context.footnoteStyle),
        ),
    ];
    // Paragraphs without bullets (or a lone intro) are plain text, not an
    // empty card.
    if (bullets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: noteWidgets,
        ),
      );
    }
    return AppSection(
      header: section.title,
      footerWidget: notes.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: noteWidgets,
            ),
      children: [for (final item in bullets) _Bullet(item.text)],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = TextStyle(fontSize: 15, height: 1.35, color: p.text);
    return AppRow.custom(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 10),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: p.text3,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Expanded(child: Text.rich(boldSpans(text), style: style)),
          ],
        ),
      ),
    );
  }
}

/// [parseBold] as an [InlineSpan]; the base style comes from the [Text].
TextSpan boldSpans(String text) => TextSpan(
  children: [
    for (final (segment, bold) in parseBold(text))
      TextSpan(
        text: segment,
        style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
  ],
);
