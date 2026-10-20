import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_info.dart';
import '../core/ui/ui.dart';
import '../l10n/locale_preference.dart';
import 'about_common.dart';
import 'markdown_lite.dart';

/// Asset holding the policy for [languageCode]; Chinese is the fallback.
String privacyAsset(String languageCode) =>
    languageCode == 'en' ? 'PRIVACY.en.md' : 'PRIVACY.md';

Future<String> _loadAsset(String asset) =>
    rootBundle.loadString(asset, cache: false);

/// Settings › About › Privacy Policy: the bundled `PRIVACY*.md`, with the
/// public address to copy underneath.
class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key, this.load});

  /// Test seam; defaults to `rootBundle.loadString`.
  final Future<String> Function(String asset)? load;

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  Future<List<DocBlock>>? blocks;
  String? asset;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = privacyAsset(Localizations.localeOf(context).languageCode);
    if (next == asset) return;
    asset = next;
    blocks = (widget.load ?? _loadAsset)(next).then(parseDoc);
  }

  Future<void> _copyLink(BuildContext context) async {
    final language = Localizations.localeOf(context).languageCode;
    await Clipboard.setData(ClipboardData(text: privacyUrl(language)));
    if (context.mounted) {
      showAppToast(context, context.l10n.r18PrivacyLinkCopied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final url = privacyUrl(Localizations.localeOf(context).languageCode);
    final link = AppSection(
      footer: l10n.r18PrivacyPublicFooter,
      children: [
        AppRow(
          key: const ValueKey('privacy-copy-link'),
          icon: Icons.link,
          iconColor: AppTints.slate,
          title: l10n.r18PrivacyCopyLink,
          subtitle: url.replaceFirst('https://', ''),
          onTap: () => _copyLink(context),
        ),
      ],
    );
    return AppScaffold(
      title: l10n.r18PrivacyPolicy,
      largeTitle: false,
      children: [
        FutureBuilder<List<DocBlock>>(
          future: blocks,
          builder: (context, snapshot) {
            if (snapshot.hasError || (snapshot.data?.isEmpty ?? false)) {
              return Column(
                children: [AboutNotice(l10n.r18PrivacyUnavailable), link],
              );
            }
            final data = snapshot.data;
            if (data == null) return const AboutLoading();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [..._sections(context, data), link],
            );
          },
        ),
      ],
    );
  }

  /// Text before the first heading is a note under the title; every heading
  /// starts a card.
  List<Widget> _sections(BuildContext context, List<DocBlock> data) {
    final widgets = <Widget>[];
    var header = '';
    var rows = <Widget>[];

    void flush() {
      if (rows.isEmpty && header.isEmpty) return;
      widgets.add(
        header.isEmpty
            ? Padding(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rows,
                ),
              )
            : AppSection(header: header, children: rows),
      );
      rows = [];
    }

    for (final block in data) {
      switch (block.kind) {
        case DocBlockKind.heading:
          flush();
          header = block.text;
        case DocBlockKind.bullet:
          rows.add(AboutBullet(block.text));
        case DocBlockKind.subheading:
        case DocBlockKind.paragraph:
          rows.add(
            header.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text.rich(
                      boldSpans(block.text),
                      style: context.footnoteStyle,
                    ),
                  )
                : _TextRow(
                    block.text,
                    strong: block.kind == DocBlockKind.subheading,
                  ),
          );
      }
    }
    flush();
    return widgets;
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow(this.text, {this.strong = false});
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) => AppRow.custom(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Text.rich(
        boldSpans(text),
        style: TextStyle(
          fontSize: 15,
          height: 1.35,
          fontWeight: strong ? FontWeight.w700 : null,
          color: context.palette.text,
        ),
      ),
    ),
  );
}
