import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import '../core/ui/ui.dart';
import 'connection_form.dart';
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

  String _clock(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  AppTone _tone(TcpOutcome outcome) => switch (outcome) {
    TcpOutcome.connected => AppTone.green,
    TcpOutcome.cancelled => AppTone.neutral,
    TcpOutcome.refused ||
    TcpOutcome.timedOut ||
    TcpOutcome.failed => AppTone.red,
  };

  /// Label and pill share one wrapping row so a long failure text is never
  /// truncated at large text scales.
  Widget _resultRow(BuildContext context, Widget pill, {bool busy = false}) =>
      AppRow.custom(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                context.l10n.uiConnResult,
                style: TextStyle(fontSize: 16, color: context.palette.text),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy) ...[
                    const CupertinoActivityIndicator(radius: 8),
                    const SizedBox(width: 8),
                  ],
                  Flexible(child: pill),
                ],
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l10n = context.l10n;
      final result = controller.result;
      final running = controller.running;
      return AppScaffold(
        title: l10n.tcpSingleTarget,
        largeTitle: false,
        bottomBar: running
            ? AppButton(
                label: l10n.tcpCancel,
                kind: AppButtonKind.tonal,
                expand: true,
                onPressed: controller.cancel,
              )
            : AppButton(
                label: l10n.tcpStart,
                icon: Icons.network_check_rounded,
                expand: true,
                onPressed: start,
              ),
        children: [
          Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSection(
                  header: l10n.uiConnTarget,
                  footerWidget: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tcpTestExplanation,
                        style: context.footnoteStyle,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.tcpTimeoutHelp(controller.timeout.inSeconds),
                        style: context.footnoteStyle,
                      ),
                    ],
                  ),
                  children: [
                    ValidatedTextRow(
                      fieldKey: const Key('tcp-host'),
                      label: l10n.tcpAddress,
                      controller: host,
                      mono: true,
                      keyboardType: TextInputType.url,
                      onChanged: (_) => controller.clearTarget(),
                      validator: (value) {
                        try {
                          TcpTarget(host: value, port: 22);
                          return null;
                        } on ArgumentError catch (error) {
                          return localizedText(error, l10n);
                        }
                      },
                    ),
                    ValidatedTextRow(
                      fieldKey: const Key('tcp-port'),
                      label: l10n.connectionPort,
                      controller: port,
                      mono: true,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => controller.clearTarget(),
                      validator: (value) {
                        final parsed = int.tryParse(value.trim());
                        return parsed == null || parsed < 1 || parsed > 65535
                            ? l10n.tcpValidPort
                            : null;
                      },
                    ),
                  ],
                ),
                if (running)
                  AppSection(
                    header: l10n.uiConnResult,
                    children: [
                      _resultRow(
                        context,
                        StatusPill(
                          l10n.tcpTestingTarget(controller.target!.label),
                        ),
                        busy: true,
                      ),
                    ],
                  )
                else if (result != null)
                  AppSection(
                    header: l10n.uiConnResult,
                    footer: l10n.tcpOneObservation,
                    children: [
                      _resultRow(
                        context,
                        StatusPill(
                          result.labelFor(l10n),
                          tone: _tone(result.outcome),
                          dot: true,
                        ),
                      ),
                      AppKeyValueRow(
                        label: l10n.uiConnTarget,
                        value: result.target.label,
                        mono: true,
                      ),
                      if (result.remoteAddress != null)
                        AppKeyValueRow(
                          label: l10n.uiConnActualAddress,
                          value: result.remoteAddress,
                          mono: true,
                        ),
                      AppKeyValueRow(
                        label: l10n.uiConnSource,
                        value: result.sourceFor(l10n),
                      ),
                      AppKeyValueRow(
                        label: l10n.uiConnFinished,
                        value: _clock(result.finishedAt.toLocal()),
                      ),
                      AppKeyValueRow(
                        label: l10n.uiConnElapsed,
                        value: '${result.elapsed.inMilliseconds} ms',
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
