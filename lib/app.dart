import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'data/ledger_store.dart';
import 'data/open_ledger.dart';
import 'finance/finance_page.dart';
import 'finance/calculator_page.dart';
import 'servers/ledger_controller.dart';
import 'servers/server_list.dart';
import 'settings/settings_page.dart';
import 'security/security_pages.dart';

class LedgerApp extends StatefulWidget {
  const LedgerApp({super.key, this.openStore = openLedger});
  final Future<LedgerStore> Function() openStore;
  @override
  State<LedgerApp> createState() => _LedgerAppState();
}

class _LedgerAppState extends State<LedgerApp> {
  LedgerController? controller;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    LedgerStore? store;
    try {
      store = await widget.openStore();
      final ready = LedgerController(store);
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
    } catch (_) {
      await store?.close();
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    controller?.store.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'vps tell you',
    navigatorObservers: [securityRouteObserver],
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    builder: (context, child) => ColoredBox(
      color: AppColors.canvas,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: child!,
        ),
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
                              '原有数据库不会被删除或重建。请检查设备储存空间、文件权限，或恢复使用较新的应用版本后重试。',
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
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
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
                                    ? AppColors.blue
                                    : AppColors.muted,
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
                                      ? AppColors.blue
                                      : AppColors.muted,
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
      const InfoNote('选择任务，再确认操作对象。'),
      Container(
        decoration: BoxDecoration(
          color: AppColors.soft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCE5FA)),
        ),
        child: SettingRow(
          icon: Icons.calculate_outlined,
          title: '剩余价值计算器',
          subtitle: '独立 / 引用试算 · PNG 预览与保存',
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
              subtitle: '阶段 4 · 选择目标后进入终端',
              onTap: () => showStage(
                context,
                'SSH 尚未接入',
                '先完成凭据与主机信任，再提供真实 SSH 连接。当前没有网络连接。',
              ),
            ),
            const Divider(),
            SettingRow(
              icon: Icons.monitor_heart_outlined,
              title: 'TCP 连接测试',
              subtitle: '阶段 4 · 检查单个端口',
              onTap: () =>
                  showStage(context, 'TCP 测试待实现', '当前不会发起测试或显示模拟连通结果。'),
            ),
            const Divider(),
            SettingRow(
              icon: Icons.code,
              title: '命令片段',
              subtitle: '阶段 4 · 预览后插入待发送区',
              onTap: () =>
                  showStage(context, '命令片段待实现', '片段将先进入待发送区，明确发送前不会向终端写入字节。'),
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
          subtitle: '阶段 4 · SSH 单机确认操作',
          onTap: () => showStage(
            context,
            '电源控制尚未接入',
            '当前不会执行电源操作。计划仅支持 SSH 重启和关机，不提供 API 电源控制或开机。',
          ),
        ),
      ),
      const InfoNote('后续能力在完成后开放，不提供批量命令或批量电源操作。'),
    ],
  );
}
