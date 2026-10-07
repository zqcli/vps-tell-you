import 'dart:async';

import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'core/app_viewport.dart';
import 'connections/connection_pages.dart';
import 'connections/snippet_pages.dart';
import 'connections/tcp_test_page.dart';
import 'data/ledger_store.dart';
import 'data/open_ledger.dart';
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
    navigatorObservers: [securityRouteObserver, _viewport],
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    darkTheme: appTheme(brightness: Brightness.dark),
    themeMode: switch (controller?.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    },
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
                            const Text(
                              '无法打开本地台账',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '原有数据仍保留。请检查设备存储空间和文件权限；如果曾使用较新版本，请用相同或更新版本重试。',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: load,
                              child: const Text('重试打开'),
                            ),
                            const InfoNote('请勿清除应用数据或卸载重装来尝试修复。'),
                          ],
                        ),
                ),
              ),
            ),
          ),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});
  final LedgerController controller;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => Scaffold(
      body: SafeArea(
        bottom: false,
        child: switch (tab) {
          0 => ServerList(controller: widget.controller),
          1 => FinancePage(controller: widget.controller),
          2 => ToolsPage(controller: widget.controller),
          _ => SettingsPage(controller: widget.controller),
        },
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Semantics(
                      selected: tab == i,
                      button: true,
                      enabled: true,
                      child: InkWell(
                        key: ValueKey('tab-$i'),
                        onTap: () => setState(() => tab = i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 2,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                [
                                  Icons.dns_outlined,
                                  Icons.bar_chart_rounded,
                                  Icons.build_outlined,
                                  Icons.settings_outlined,
                                ][i],
                                color: tab == i
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                size: 23,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ['服务器', '费用', '工具', '设置'][i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: tab == i
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: tab == i
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
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
  );
}

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key, required this.controller});
  final LedgerController controller;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        '工具',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
      const InfoNote('计算费用、连接服务器或管理常用命令。'),
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
          title: '剩余价值计算器',
          subtitle: '独立试算或引用服务器资料 · 可导出图片',
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => CalculatorPage(controller: controller),
            ),
          ),
        ),
      ),
      const SectionTitle('连接与排障'),
      LedgerCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            SettingRow(
              icon: Icons.terminal,
              title: 'SSH 快速连接',
              subtitle: '选择服务器或临时目标 · 核验主机后登录',
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
              title: 'TCP 连接测试',
              subtitle: '从当前设备检查单个地址和端口',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const TcpTestPage()),
              ),
            ),
            const Divider(),
            SettingRow(
              icon: Icons.code,
              title: '命令片段',
              subtitle: '保存常用命令 · 插入终端草稿后发送',
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
      const SectionTitle('单机维护'),
      LedgerCard(
        padding: EdgeInsets.zero,
        child: SettingRow(
          icon: Icons.power_settings_new,
          title: '电源控制',
          subtitle: '通过 SSH 重启或关机 · 操作前核对目标',
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SshConnectPage(ledger: controller, powerMode: true),
            ),
          ),
        ),
      ),
      const InfoNote('关机后无法通过 SSH 开机，需使用厂商面板。重启或关机不会停止厂商计费。'),
    ],
  );
}
