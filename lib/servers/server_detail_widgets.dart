import 'package:flutter/material.dart';

import '../core/ui/ui.dart';
import '../l10n/locale_preference.dart';
import '../providers/directory_widgets.dart';
import '../providers/provider_pages.dart';
import 'ledger_controller.dart';
import 'server_record.dart';

/// Small grey caption above a free-form card (same metrics as the
/// [AppSection] header).
class DetailSectionHeader extends StatelessWidget {
  const DetailSectionHeader(this.title, {super.key, this.action});
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

/// Wraps an [AppRow] to indent it under its parent row or dim it while keeping
/// taps alive (unavailable action rows that explain themselves when tapped).
class DetailRowFrame extends StatelessWidget implements AppSectionItem {
  const DetailRowFrame({super.key, required this.child, this.dimmed = false});
  final AppRow child;
  final bool dimmed;

  @override
  double get separatorInset => child.separatorInset;

  @override
  Widget build(BuildContext context) =>
      Opacity(opacity: dimmed ? .45 : 1, child: child);
}

class DetailFootnote extends StatelessWidget {
  const DetailFootnote(this.text, {super.key, this.top = 7, this.padding = 16});
  final String text;
  final double top, padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(padding, top, padding, 0),
    child: Text(text, style: context.footnoteStyle),
  );
}

class ServerProviderCard extends StatefulWidget {
  const ServerProviderCard({
    super.key,
    required this.controller,
    required this.server,
  });
  final LedgerController controller;
  final ServerRecord server;
  @override
  State<ServerProviderCard> createState() => _ServerProviderCardState();
}

class _ServerProviderCardState extends State<ServerProviderCard> {
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
    final provider = controller.providerFor(server);
    return AppSection(
      header: l10n.r6CatServerSection,
      footer: l10n.r6CatServerFooter,
      children: [
        AppRow(
          key: const ValueKey('server-provider-link'),
          leading: ProviderLogo(
            ledger: controller,
            provider: provider,
            mark: provider == null
                ? null
                : serverProviderMark(controller, server),
            size: 30,
          ),
          title: provider?.name ?? l10n.providerUiUnspecified,
          subtitle: l10n.providerUiOpenProvider,
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
      ],
    );
  }
}
