import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../connections/connection_pages.dart';
import '../core/app_theme.dart' show showFailure;
import '../core/ui/ui.dart';
import '../finance/finance_math.dart';
import '../finance/payment_pages.dart';
import '../providers/directory_widgets.dart';
import '../providers/provider_pages.dart';
import 'ledger_controller.dart';
import 'server_detail.dart';
import 'server_duplicate.dart';
import 'server_record.dart';
import 'server_add.dart';
import 'server_archive.dart';

/// A ledger row with swipe-to-reveal actions and a long-press action menu.
/// Swiping towards the leading edge reveals SSH and favourite on the trailing
/// side; swiping towards the trailing edge reveals Duplicate on the leading
/// side. Archive is only in the menu (it needs a confirmation).
class ServerRow extends StatefulWidget {
  const ServerRow({super.key, required this.record, required this.controller});
  final ServerRecord record;
  final LedgerController controller;
  @override
  State<ServerRow> createState() => _ServerRowState();
}

class _ServerRowState extends State<ServerRow> {
  ServerRecord get s => widget.record;
  LedgerController get c => widget.controller;
  bool get canSsh => !s.isDemo && !s.archived;

  /// A demo row must not seed real data, and nothing is written read-only.
  bool get canDuplicate => c.canMutate && !s.isDemo && !s.archived;

  void openDetail() => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => ServerDetail(controller: c, id: s.id),
    ),
  );

  void openSsh() => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => SshConnectPage(ledger: c, initialServerId: s.id),
    ),
  );

  Future<void> toggleFavorite() async {
    try {
      await c.mutate(() => c.store.setFavorite(s, !s.favorite));
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> copyHost() async {
    try {
      await Clipboard.setData(ClipboardData(text: s.primaryAddress));
      if (mounted) showAppToast(context, context.l10n.serverHostCopied);
    } catch (error) {
      if (mounted) {
        showFailure(
          context,
          error,
          fallbackMessage: LocalizedText((l10n) => l10n.serverCopyHostFailed),
        );
      }
    }
  }

  void duplicate() =>
      addServer(context, c, template: duplicateServerTemplate(s, context.l10n));

  void recordPayment() => showAppModal<bool>(
    context,
    builder: (_) => PaymentForm(controller: c, server: s),
  );

  Future<void> openMenu() {
    final l10n = context.l10n;
    final canRecordPayment =
        c.canMutate && s.billing == BillingKind.prepaid && canRenew(s);
    return showAppActionMenu<void>(
      context,
      title: s.primaryAddress.isEmpty
          ? s.name
          : '${s.name} · ${s.primaryAddress}',
      actions: [
        if (s.primaryAddress.isNotEmpty)
          AppMenuAction(label: l10n.serverCopyHost, onPressed: copyHost),
        if (canSsh)
          AppMenuAction(label: l10n.serverConnectSsh, onPressed: openSsh),
        if (canRecordPayment)
          AppMenuAction(
            label: l10n.serverRecordPayment,
            onPressed: recordPayment,
          ),
        if (c.canMutate)
          AppMenuAction(
            label: s.favorite
                ? l10n.serverRemoveFavorite
                : l10n.serverSetFavorite,
            onPressed: toggleFavorite,
          ),
        if (canDuplicate)
          AppMenuAction(label: l10n.r14ServerDuplicate, onPressed: duplicate),
        if (c.canMutate)
          AppMenuAction(
            label: l10n.uiServersArchive,
            destructive: true,
            onPressed: () => confirmAndArchiveServer(context, c, s),
          ),
      ],
    );
  }

  Widget _price(BuildContext context) {
    final p = context.palette;
    final text = s.billing == BillingKind.unknown
        ? '—'
        : s.billingLabelFor(context.l10n);
    final slash = text.indexOf('/');
    final main = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: p.text,
      fontFeatures: kTabularFigures,
    );
    return Text.rich(
      TextSpan(
        style: main,
        children: [
          TextSpan(text: slash < 0 ? text : text.substring(0, slash)),
          if (slash >= 0)
            TextSpan(
              text: text.substring(slash),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: p.text2,
              ),
            ),
        ],
      ),
      textAlign: TextAlign.end,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _content(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final days = c.dueIn(s);
    final due = switch (s.billing) {
      BillingKind.unknown => l10n.serverCostsMissing,
      BillingKind.metered => l10n.serverMeteredBilling,
      BillingKind.prepaid =>
        days == null
            ? l10n.serverDueUnknown
            : days < 0
            ? l10n.serverExpiredDays(-days)
            : days == 0
            ? l10n.serverDueToday
            : l10n.serverDueInDays(days),
    };
    final tone = days == null
        ? AppTone.neutral
        : days < 0
        ? AppTone.red
        : days < 30
        ? AppTone.amber
        : AppTone.neutral;
    final pill = StatusPill(due, tone: tone, dot: tone != AppTone.neutral);
    final big = MediaQuery.textScalerOf(context).scale(14) > 20;
    final provider = c.providerFor(s);
    final titleLine = Text.rich(
      TextSpan(
        children: [
          if (big && s.favorite)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: Icon(Icons.star_rounded, size: 16, color: p.amberSolid),
              ),
            ),
          TextSpan(
            text: s.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: p.text,
            ),
          ),
          if (s.purpose.isNotEmpty)
            TextSpan(
              text: '  ${s.purpose}',
              style: TextStyle(fontSize: 13, color: p.text2),
            ),
        ],
      ),
      maxLines: big ? 2 : 1,
      overflow: TextOverflow.ellipsis,
    );
    final subLine = Row(
      children: [
        Flexible(
          child: Text(
            [
              serverProviderLabel(context, c, s),
              s.region,
            ].where((e) => e.isNotEmpty).join(' · '),
            maxLines: big ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: p.text2),
          ),
        ),
        if (s.isDemo) ...[
          const SizedBox(width: 6),
          StatusPill(l10n.serverDemo),
        ],
      ],
    );
    final avatar = ProviderLogo(
      ledger: c,
      provider: provider,
      mark: provider == null ? null : serverProviderMark(c, s),
      starred: s.favorite,
    );
    Widget body(bool stacked) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleLine,
        const SizedBox(height: 3),
        subLine,
        if (stacked) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [_price(context), pill],
          ),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        // Price and status move below the text on narrow rows or when the
        // text is enlarged; at very large sizes the avatar goes as well.
        final stacked =
            big ||
            box.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(14) > 16;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: big
              ? body(true)
              : Row(
                  children: [
                    avatar,
                    const SizedBox(width: 12),
                    Expanded(child: body(stacked)),
                    if (!stacked) ...[
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 156),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _price(context),
                            const SizedBox(height: 5),
                            pill,
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return AppSwipeRow(
      leadingKey: const ValueKey('server-swipe-leading'),
      trailingKey: const ValueKey('server-swipe-trailing'),
      leading: [
        AppSwipeAction(
          color: p.green,
          icon: Icons.copy_rounded,
          label: l10n.r14ServerDuplicate,
          onTap: canDuplicate ? duplicate : null,
        ),
      ],
      trailing: [
        AppSwipeAction(
          color: p.primary,
          icon: Icons.terminal_rounded,
          label: 'SSH',
          onTap: canSsh ? openSsh : null,
        ),
        AppSwipeAction(
          color: p.amberSolid,
          icon: s.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
          label: s.favorite ? l10n.serverRemoveFavorite : l10n.serverFavorites,
          onTap: c.canMutate ? toggleFavorite : null,
        ),
      ],
      child: InkWell(
        key: ValueKey('server-${s.id}'),
        onTap: openDetail,
        onLongPress: openMenu,
        child: _content(context),
      ),
    );
  }
}
