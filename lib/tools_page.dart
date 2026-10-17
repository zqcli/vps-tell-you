import 'package:flutter/material.dart';

import 'connections/connection_pages.dart';
import 'connections/snippet_pages.dart';
import 'connections/tcp_test_page.dart';
import 'core/ui/ui.dart';
import 'finance/calculator_page.dart';
import 'l10n/locale_preference.dart';
import 'servers/ledger_controller.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key, required this.controller});
  final LedgerController controller;

  void _open(BuildContext context, WidgetBuilder builder) =>
      Navigator.push<void>(context, MaterialPageRoute(builder: builder));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      title: l10n.tools,
      children: [
        const SizedBox(height: 4),
        _ToolTile(
          wide: true,
          icon: Icons.calculate_outlined,
          color: AppTints.blue,
          title: l10n.remainingValueCalculator,
          subtitle: l10n.uiTabsCalculatorTile,
          onTap: () =>
              _open(context, (_) => CalculatorPage(controller: controller)),
        ),
        _ToolRow(
          left: _ToolTile(
            icon: Icons.terminal,
            color: AppTints.slate,
            title: l10n.sshQuickConnect,
            subtitle: l10n.uiTabsSshTile,
            onTap: () =>
                _open(context, (_) => SshConnectPage(ledger: controller)),
          ),
          right: _ToolTile(
            icon: Icons.monitor_heart_outlined,
            color: AppTints.green,
            title: l10n.tcpConnectionTest,
            subtitle: l10n.uiTabsTcpTile,
            onTap: () => _open(context, (_) => TcpTestPage(ledger: controller)),
          ),
        ),
        _ToolRow(
          left: _ToolTile(
            icon: Icons.code,
            color: AppTints.purple,
            title: l10n.commandSnippets,
            subtitle: l10n.uiTabsSnippetsTile,
            onTap: () =>
                _open(context, (_) => SnippetListPage(store: controller.store)),
          ),
          right: _ToolTile(
            icon: Icons.power_settings_new,
            color: AppTints.red,
            title: l10n.powerControl,
            subtitle: l10n.uiTabsPowerTile,
            onTap: () => _open(
              context,
              (_) => SshConnectPage(ledger: controller, powerMode: true),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
          child: Text(l10n.powerControlWarning, style: context.footnoteStyle),
        ),
      ],
    );
  }
}

/// Two equally tall square-ish tiles side by side.
class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.left, required this.right});
  final Widget left, right;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 10),
          Expanded(child: right),
        ],
      ),
    ),
  );
}

/// Tile of the tools grid: coloured icon square, title and a short caption.
/// [wide] tiles span the full width (icon left, chevron right).
class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.wide = false,
  });
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final titleText = Text(
      title,
      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
    );
    final subtitleText = Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        subtitle,
        style: TextStyle(fontSize: 12.5, height: 1.35, color: p.text2),
      ),
    );
    final Widget content = wide
        ? Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                AppIconSquare(icon: icon, color: color, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [titleText, subtitleText],
                  ),
                ),
                const SizedBox(width: 8),
                const AppChevron(),
              ],
            ),
          )
        : ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 118),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIconSquare(icon: icon, color: color, size: 38),
                  const Spacer(),
                  const SizedBox(height: 14),
                  titleText,
                  subtitleText,
                ],
              ),
            ),
          );
    return Padding(
      padding: wide
          ? const EdgeInsets.symmetric(horizontal: 16)
          : EdgeInsets.zero,
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          child: InkWell(onTap: onTap, child: content),
        ),
      ),
    );
  }
}
