import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'tcp_test.dart';

class TcpTestPage extends StatefulWidget {
  const TcpTestPage({
    super.key,
    this.initialHost = '',
    this.initialPort = 22,
    this.controller,
  });
  final String initialHost;
  final int initialPort;
  final TcpTestController? controller;

  @override
  State<TcpTestPage> createState() => _TcpTestPageState();
}

class _TcpTestPageState extends State<TcpTestPage> with WidgetsBindingObserver {
  final form = GlobalKey<FormState>();
  late final TextEditingController host;
  late final TextEditingController port;
  late final TcpTestController controller;

  @override
  void initState() {
    super.initState();
    host = TextEditingController(text: widget.initialHost);
    port = TextEditingController(text: '${widget.initialPort}');
    controller = widget.controller ?? TcpTestController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) controller.cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) {
      controller.dispose();
    } else {
      controller.cancel();
    }
    host.dispose();
    port.dispose();
    super.dispose();
  }

  void start() {
    if (controller.running || !form.currentState!.validate()) return;
    controller.test(
      TcpTarget(host: host.text, port: int.parse(port.text.trim())),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final result = controller.result;
      return Scaffold(
        appBar: AppBar(title: const Text('单目标 TCP 测试')),
        body: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const InfoNote(
                '从当前设备测试一个地址和端口，仅建立并关闭 TCP 连接，不发送应用数据。成功不代表 SSH 可登录、服务器开机状态或业务健康。',
              ),
              TextFormField(
                key: const Key('tcp-host'),
                controller: host,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'IP / 域名'),
                onChanged: (_) => controller.clearTarget(),
                validator: (value) {
                  try {
                    TcpTarget(host: value ?? '', port: 22);
                    return null;
                  } on ArgumentError catch (error) {
                    return error.message.toString();
                  }
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('tcp-port'),
                controller: port,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '端口'),
                onChanged: (_) => controller.clearTarget(),
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  return parsed == null || parsed < 1 || parsed > 65535
                      ? '端口需为 1–65535'
                      : null;
                },
              ),
              const SizedBox(height: 20),
              if (controller.running) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Text('正在测试 ${controller.target!.label}'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: controller.cancel,
                  child: const Text('取消测试'),
                ),
              ] else
                FilledButton(onPressed: start, child: const Text('开始测试')),
              InfoNote(
                '单次最多 ${controller.timeout.inSeconds} 秒；修改目标、离开页面或进入后台会取消测试。',
              ),
              if (result != null)
                LedgerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.label,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      SelectableText('目标：${result.target.label}'),
                      if (result.remoteAddress != null)
                        SelectableText('实际地址：${result.remoteAddress}'),
                      Text('来源：${result.source}'),
                      Text(
                        '结束时间：${result.finishedAt.toLocal().toIso8601String()}（本机时间）',
                      ),
                      Text('耗时：${result.elapsed.inMilliseconds} ms'),
                      const InfoNote('此结果仅反映当次观察，不是持续状态。'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
