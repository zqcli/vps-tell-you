import 'package:flutter/material.dart';

import 'core/ui/ui.dart';
import 'finance/finance_page.dart';
import 'l10n/locale_preference.dart';
import 'servers/ledger_controller.dart';
import 'servers/server_list.dart';
import 'settings/settings_page.dart';
import 'tools_page.dart';

/// Root shell with the four tabs and an iOS-style translucent tab bar.
///
/// Tabs are created lazily and keep their state (scroll position, search
/// text) while hidden. Tapping the selected tab scrolls its page to the top.
/// Pushed pages are full-screen routes above the shell.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});
  final LedgerController controller;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  final _visited = <int>{0};
  final _scrollControllers = List.generate(4, (_) => ScrollController());

  @override
  void dispose() {
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _select(int index) {
    if (index == tab) {
      final scroll = _scrollControllers[index];
      if (scroll.hasClients && scroll.offset > 0) {
        scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    setState(() {
      tab = index;
      _visited.add(index);
    });
  }

  // Built once per tab: switching tabs must not rebuild the other pages
  // (identical widget instances are skipped by the framework).
  final _pages = <int, Widget>{};

  @override
  void didUpdateWidget(HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _pages.clear();
  }

  Widget _page(int index) => _pages[index] ??= switch (index) {
    0 => ServerList(controller: widget.controller),
    1 => FinancePage(controller: widget.controller),
    2 => ToolsPage(controller: widget.controller),
    _ => SettingsPage(controller: widget.controller),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    // Every tab page is an [AppScaffold], which pads its end by the inset
    // this adds, so content can scroll under the translucent tab bar.
    extendBody: true,
    body: Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < 4; i++)
          if (_visited.contains(i))
            Offstage(
              key: ValueKey('tab-page-$i'),
              offstage: tab != i,
              child: TickerMode(
                enabled: tab == i,
                child: PrimaryScrollController(
                  controller: _scrollControllers[i],
                  child: _page(i),
                ),
              ),
            ),
      ],
    ),
    bottomNavigationBar: _AppTabBar(selected: tab, onSelect: _select),
  );
}

class _AppTabBar extends StatelessWidget {
  const _AppTabBar({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  static const _icons = [
    (Icons.dns_outlined, Icons.dns_rounded),
    (Icons.bar_chart_rounded, Icons.bar_chart_rounded),
    (Icons.build_outlined, Icons.build_rounded),
    (Icons.settings_outlined, Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final labels = [
      context.l10n.servers,
      context.l10n.costs,
      context.l10n.tools,
      context.l10n.settings,
    ];
    final idle = p.isDark ? p.text3 : const Color(0xFF8E939E);
    final liquid = context.glassStyle.isLiquid;
    final items = Row(
      children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: Semantics(
              selected: selected == i,
              button: true,
              enabled: true,
              child: GestureDetector(
                key: ValueKey('tab-$i'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                // iOS 26: the selected tab sits in a soft lozenge.
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: liquid && selected == i
                        ? p.primary.withValues(alpha: p.isDark ? .20 : .11)
                        : null,
                    borderRadius: AppGlass.capsule,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: liquid ? 4 : 2,
                      horizontal: 2,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected == i ? _icons[i].$2 : _icons[i].$1,
                          size: 26,
                          color: selected == i ? p.primary : idle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                            color: selected == i ? p.primary : idle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    final scaled = MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: items,
    );
    if (liquid) {
      // iOS 26: a capsule floating above the home indicator, inset from the
      // edges. The transparent margin is part of this widget, so the
      // Scaffold's `extendBody` inset still covers it and nothing scrolls
      // out of reach beneath the bar.
      final bottom = MediaQuery.paddingOf(context).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottom > 12 ? bottom - 12 : 8),
        child: AppGlass(
          kind: AppGlassKind.floating,
          borderRadius: AppGlass.capsule,
          child: Padding(padding: const EdgeInsets.all(4), child: scaled),
        ),
      );
    }
    return AppGlass(
      edge: AppGlassEdge.top,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
          child: scaled,
        ),
      ),
    );
  }
}
