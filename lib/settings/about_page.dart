import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_info.dart';
import '../core/ui/ui.dart';
import '../l10n/locale_preference.dart';
import 'about_common.dart';
import 'changelog_page.dart';
import 'open_source_page.dart';

/// Small indigo pill with the version label (settings banner and About page).
class VersionPill extends StatelessWidget {
  const VersionPill(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: AppTints.indigo.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppTints.indigo,
      ),
    ),
  );
}

/// Settings › About: identity, changelog, source, license and components.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  void _push(BuildContext context, WidgetBuilder builder) =>
      Navigator.push<void>(context, MaterialPageRoute(builder: builder));

  Future<void> _copyRepo(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: kRepoUrl));
    if (context.mounted) {
      showAppToast(context, context.l10n.r11AboutRepoCopied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return AppScaffold(
      title: l10n.about,
      largeTitle: false,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(
            children: [
              const AppLogo(size: 76),
              const SizedBox(height: 14),
              Text(
                kAppName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: p.text,
                ),
              ),
              const SizedBox(height: 6),
              VersionPill(l10n.developmentVersion(kAppVersion)),
              const SizedBox(height: 10),
              Text(
                l10n.r11AppSlogan,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: p.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.appDescription,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.35, color: p.text2),
              ),
            ],
          ),
        ),
        AppSection(
          footerWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.r11AboutFootnote, style: context.footnoteStyle),
              const SizedBox(height: 8),
              Text(l10n.r11AboutTrademark, style: context.footnoteStyle),
            ],
          ),
          children: [
            AppRow(
              key: const ValueKey('about-changelog'),
              icon: Icons.auto_awesome_outlined,
              iconColor: AppTints.orange,
              title: l10n.r11AboutWhatsNew,
              chevron: true,
              onTap: () => _push(context, (_) => const ChangelogPage()),
            ),
            AppRow(
              key: const ValueKey('about-source'),
              icon: Icons.code,
              iconColor: AppTints.slate,
              title: l10n.r11AboutSourceCode,
              subtitle: kRepoDisplay,
              onTap: () => _copyRepo(context),
            ),
            AppRow(
              key: const ValueKey('about-license'),
              icon: Icons.description_outlined,
              iconColor: AppTints.blue,
              title: l10n.r11AboutLicense,
              value: 'MIT',
              chevron: true,
              onTap: () => _push(context, (_) => const LicenseTextPage()),
            ),
            AppRow(
              key: const ValueKey('about-open-source'),
              icon: Icons.extension_outlined,
              iconColor: AppTints.purple,
              title: l10n.r11AboutOpenSource,
              chevron: true,
              onTap: () => _push(context, (_) => OpenSourcePage()),
            ),
          ],
        ),
      ],
    );
  }
}

/// The bundled project `LICENSE`, monospace and selectable.
class LicenseTextPage extends StatefulWidget {
  const LicenseTextPage({super.key, this.load});

  /// Test seam; defaults to the bundled asset.
  final Future<String> Function()? load;

  @override
  State<LicenseTextPage> createState() => _LicenseTextPageState();
}

class _LicenseTextPageState extends State<LicenseTextPage> {
  late final Future<String> text =
      widget.load?.call() ?? rootBundle.loadString('LICENSE', cache: false);

  /// Joins the hard-wrapped lines of each paragraph so the text re-flows at
  /// any width; blank lines still separate paragraphs.
  static String reflow(String raw) => raw
      .replaceAll('\r\n', '\n')
      .trim()
      .replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), ' ');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return AppScaffold(
      title: l10n.r11AboutLicense,
      largeTitle: false,
      children: [
        FutureBuilder<String>(
          future: text,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AboutNotice(l10n.r11LicenseUnavailable);
            }
            if (!snapshot.hasData) return const AboutLoading();
            return AppCard(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SelectableText(
                reflow(snapshot.data!),
                key: const ValueKey('license-text'),
                style: kMonoTextStyle.copyWith(
                  fontSize: 12.5,
                  height: 1.5,
                  color: p.text,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
