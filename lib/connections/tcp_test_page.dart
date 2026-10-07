import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';

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
  bool _hasValidated = false;
  String? _validationLocale;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.l10n.localeName;
    if (_validationLocale != null &&
        _validationLocale != next &&
        _hasValidated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          form.currentState?.validate();
        }
      });
    }
    _validationLocale = next;
  }

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
    if (state != AppLifecycleState.resumed) {
      controller.cancel();
    }
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
    if (controller.running) {
      return;
    }
    _hasValidated = true;
    if (!form.currentState!.validate()) {
      return;
    }
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
        appBar: AppBar(title: Text(context.l10n.tcpSingleTarget)),
        body: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              InfoNote(context.l10n.tcpTestExplanation),
              TextFormField(
                key: const Key('tcp-host'),
                controller: host,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: context.l10n.tcpAddress),
                onChanged: (_) => controller.clearTarget(),
                validator: (value) {
                  try {
                    TcpTarget(host: value ?? '', port: 22);
                    return null;
                  } on ArgumentError catch (error) {
                    return localizedText(error, context.l10n);
                  }
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('tcp-port'),
                controller: port,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.connectionPort,
                ),
                onChanged: (_) => controller.clearTarget(),
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  return parsed == null || parsed < 1 || parsed > 65535
                      ? context.l10n.tcpValidPort
                      : null;
                },
              ),
              const SizedBox(height: 20),
              if (controller.running) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  context.l10n.tcpTestingTarget(
                    (controller.target!.label).toString(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: controller.cancel,
                  child: Text(context.l10n.tcpCancel),
                ),
              ] else
                FilledButton(
                  onPressed: start,
                  child: Text(context.l10n.tcpStart),
                ),
              InfoNote(
                context.l10n.tcpTimeoutHelp(controller.timeout.inSeconds),
              ),
              if (result != null)
                LedgerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.labelFor(context.l10n),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        context.l10n.tcpTarget(
                          (result.target.label).toString(),
                        ),
                      ),
                      if (result.remoteAddress != null)
                        SelectableText(
                          context.l10n.tcpActualAddress(
                            (result.remoteAddress).toString(),
                          ),
                        ),
                      Text(
                        context.l10n.tcpResultSource(
                          result.sourceFor(context.l10n),
                        ),
                      ),
                      Text(
                        context.l10n.tcpFinished(
                          (result.finishedAt.toLocal().toIso8601String())
                              .toString(),
                        ),
                      ),
                      Text(
                        context.l10n.tcpElapsed(
                          (result.elapsed.inMilliseconds).toString(),
                        ),
                      ),
                      InfoNote(context.l10n.tcpOneObservation),
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
