import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'core/app_viewport.dart';
import 'core/ui/ui.dart';
import 'connections/connection_pages.dart';
import 'connections/snippet_pages.dart';
import 'connections/tcp_test_page.dart';
import 'data/ledger_store.dart';
import 'data/open_ledger.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/locale_preference.dart';
import 'finance/finance_page.dart';
import 'finance/calculator_page.dart';
import 'servers/ledger_controller.dart';
import 'servers/server_list.dart';
import 'servers/server_detail.dart';
import 'settings/reminder_scheduler.dart';
import 'settings/settings_page.dart';
import 'security/security_pages.dart';

class LedgerApp extends StatefulWidget {
  const LedgerApp({
    super.key,
    this.openStore = openLedger,
    this.reminderPlatform,
  });
  final Future<LedgerStore> Function() openStore;
  final ReminderPlatform? reminderPlatform;
  @override
  State<LedgerApp> createState() => _LedgerAppState();
}

class _LedgerAppState extends State<LedgerApp> with WidgetsBindingObserver {
  LedgerController? controller;
  final navigatorKey = GlobalKey<NavigatorState>();
  final _viewport = AppViewportObserver();
  final _titleObserver = AppRouteTitles.createObserver();
  String? pendingReminder;
  bool reminderFrameQueued = false;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    LedgerStore? store;
    LedgerController? ready;
    try {
      store = await widget.openStore();
      ready = LedgerController(
        store,
        reminderPlatform:
            widget.reminderPlatform ??
            NativeReminderPlatform(onOpen: openReminder),
      );
      await ready.refresh();
      if (!mounted) {
        ready.dispose();
        await store.close();
        return;
      }
      setState(() {
        controller = ready;
        loading = false;
      });
      ready.addListener(ledgerChanged);
      queuePendingReminder();
    } catch (_) {
      ready?.dispose();
      await store?.close();
      if (mounted) setState(() => loading = false);
    }
  }

  void ledgerChanged() {
    if (mounted) setState(() {});
    queuePendingReminder();
  }

  void queuePendingReminder() {
    final ledger = controller;
    if (!mounted ||
        pendingReminder == null ||
        reminderFrameQueued ||
        ledger == null ||
        ledger.busy ||
        ledger.refreshFailed) {
      return;
    }
    reminderFrameQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      reminderFrameQueued = false;
      if (!mounted ||
          controller == null ||
          controller!.busy ||
          controller!.refreshFailed) {
        return;
      }
      final id = pendingReminder;
      pendingReminder = null;
      if (id != null) openReminder(id);
    });
  }

  void openReminder(String id) {
    if (!mounted) return;
    final ledger = controller;
    final navigator = navigatorKey.currentState;
    if (ledger == null ||
        navigator == null ||
        ledger.busy ||
        ledger.refreshFailed) {
      pendingReminder = id;
      queuePendingReminder();
      return;
    }
    // A newer tap supersedes a previously deferred target, even when its
    // already-queued post-frame callback has not run yet.
    pendingReminder = null;
    final server = ledger.byId(id);
    if (server == null || server.archived) return;
    navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => ServerDetail(controller: ledger, id: id),
      ),
    );
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (mounted && controller?.languagePreference == LocalePreference.system) {
      setState(() {});
      unawaited(controller!.reminders.reconcile());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && controller != null) {
      unawaited(controller!.reminders.reconcile());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewport.dispose();
    controller?.removeListener(ledgerChanged);
    controller?.dispose();
    controller?.store.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'vps tell you',
    navigatorKey: navigatorKey,
    navigatorObservers: [securityRouteObserver, _viewport, _titleObserver],
    scrollBehavior: const AppScrollBehavior(),
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    darkTheme: appTheme(brightness: Brightness.dark),
    themeMode: switch (controller?.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    },
    locale: (controller?.languagePreference ?? LocalePreference.chinese)
        .resolve(WidgetsBinding.instance.platformDispatcher.locales),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ValueListenableBuilder<bool>(
        valueListenable: _viewport.fullWidth,
        builder: (context, fullWidth, child) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: fullWidth ? double.infinity : 760,
            ),
            child: child!,
          ),
        ),
        child: child,
      ),
    ),
    home: controller != null
        ? HomeShell(controller: controller!)
        : Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: loading
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.storage_outlined,
                              size: 48,
                              color: AppColors.blue,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              context.l10n.ledgerOpenFailed,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.l10n.ledgerOpenHelp,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: load,
                              child: Text(context.l10n.retryOpen),
                            ),
                            InfoNote(context.l10n.ledgerDoNotErase),
                          ],
                        ),
                ),
              ),
            ),
          ),
  );
}

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

  Widget _page(int index) => switch (index) {
    0 => ServerList(controller: widget.controller),
    1 => FinancePage(controller: widget.controller),
    2 => ToolsPage(controller: widget.controller),
    _ => SettingsPage(controller: widget.controller),
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => Scaffold(
      // Flip to `true` once every tab page is an [AppScaffold] to let content
      // scroll under the translucent tab bar.
      extendBody: false,
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
    ),
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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.barBg,
            border: Border(top: BorderSide(color: p.separator, width: .5)),
          ),
          child: SafeArea(
            top: false,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
                child: Row(
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
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2,
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key, required this.controller});
  final LedgerController controller;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        context.l10n.tools,
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
      InfoNote(context.l10n.toolsDescription),
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: SettingRow(
          icon: Icons.calculate_outlined,
          title: context.l10n.remainingValueCalculator,
          subtitle: context.l10n.calculatorDescription,
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => CalculatorPage(controller: controller),
            ),
          ),
        ),
      ),
      SectionTitle(context.l10n.connectionsTroubleshooting),
      LedgerCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            SettingRow(
              icon: Icons.terminal,
              title: context.l10n.sshQuickConnect,
              subtitle: context.l10n.sshQuickConnectDescription,
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => SshConnectPage(ledger: controller),
                ),
              ),
            ),
            const Divider(),
            SettingRow(
              icon: Icons.monitor_heart_outlined,
              title: context.l10n.tcpConnectionTest,
              subtitle: context.l10n.tcpConnectionDescription,
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const TcpTestPage()),
              ),
            ),
            const Divider(),
            SettingRow(
              icon: Icons.code,
              title: context.l10n.commandSnippets,
              subtitle: context.l10n.commandSnippetsDescription,
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => SnippetListPage(store: controller.store),
                ),
              ),
            ),
          ],
        ),
      ),
      SectionTitle(context.l10n.singleServerMaintenance),
      LedgerCard(
        padding: EdgeInsets.zero,
        child: SettingRow(
          icon: Icons.power_settings_new,
          title: context.l10n.powerControl,
          subtitle: context.l10n.powerControlDescription,
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SshConnectPage(ledger: controller, powerMode: true),
            ),
          ),
        ),
      ),
      InfoNote(context.l10n.powerControlWarning),
    ],
  );
}
