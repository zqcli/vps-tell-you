import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import '../core/net_address.dart';
import '../core/ui/ui.dart';
import '../security/proxy_models.dart';
import '../security/proxy_pages.dart';
import '../servers/ledger_controller.dart';
import 'connection_form.dart';
import 'error_details_ui.dart';
import 'tcp_test.dart';

class TcpTestPage extends StatefulWidget {
  const TcpTestPage({
    super.key,
    this.initialHost = '',
    this.initialPort = 22,
    this.controller,
    this.ledger,
  });

  /// Source of the saved proxies. Without it the page has no Proxy row.
  final LedgerController? ledger;
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

  // The route for the next test: saved proxy id, a one-off endpoint (kept in
  // memory only, never persisted), or neither (direct).
  String? _proxyId;
  ProxyEndpoint? _temporaryProxy;
  LocalizedMessage? _proxyError;
  bool _loadingProxy = false;

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

  Future<void> _chooseProxy() async {
    final ledger = widget.ledger!;
    final choice = await chooseProxy(
      context,
      ledger,
      selectedId: _proxyId,
      temporarySelected: _temporaryProxy != null,
      allowTemporary: true,
      previousTemporary: _temporaryProxy,
    );
    if (!mounted || choice == null) return;
    controller.clearTarget();
    setState(() {
      _proxyId = choice.savedId;
      _temporaryProxy = choice.temporary;
      _proxyError = null;
    });
  }

  Future<void> start() async {
    if (controller.running || _loadingProxy) {
      return;
    }
    _hasValidated = true;
    // `host:port` / `[v6]:port` in the address field wins over the port field
    // and is split back into the two fields so the tested target is visible.
    final split = splitHostPort(host.text.trim());
    if (split?.port != null && RegExp(r'^[0-9]+$').hasMatch(split!.port!)) {
      host.text = split.host;
      port.text = split.port!;
    }
    if (!form.currentState!.validate()) {
      return;
    }
    final target = TcpTarget(
      host: host.text,
      port: int.parse(port.text.trim()),
    );
    ProxyEndpoint? proxy = _temporaryProxy;
    String? proxyName;
    if (_proxyId != null) {
      final security = widget.ledger!.security;
      setState(() {
        _loadingProxy = true;
        _proxyError = null;
      });
      try {
        proxy = await security.loadProxyEndpoint(
          _proxyId!,
          isCancelled: () => !mounted,
        );
        proxyName = security.proxyById(_proxyId)?.name;
      } on LocalizedMessage catch (problem) {
        // Never falls back to a direct test.
        if (mounted) setState(() => _proxyError = problem);
        return;
      } finally {
        if (mounted && _loadingProxy) setState(() => _loadingProxy = false);
      }
      if (!mounted) return;
    }
    controller.test(target, proxy: proxy, proxyName: proxyName);
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
  Widget _resultRow(
    BuildContext context,
    Widget pill, {
    bool busy = false,
    Widget? accessory,
  }) => AppRow.custom(
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
              ?accessory,
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
      final savedProxy = widget.ledger?.security.proxyById(_proxyId);
      final routeName = savedProxy?.name;
      final routeProxy =
          _temporaryProxy ??
          (savedProxy == null
              ? null
              : ProxyEndpoint(
                  kind: savedProxy.kind,
                  host: savedProxy.host,
                  port: savedProxy.port,
                ));
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
                          TcpTarget.parse(value, defaultPort: 22);
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
                if (widget.ledger != null)
                  AppSection(
                    header: l10n.r13ProxyRow,
                    footer: _temporaryProxy != null
                        ? l10n.r13TcpProxyFooter
                        : null,
                    children: [
                      AppRow(
                        key: const ValueKey('tcp-proxy-row'),
                        icon: routeProxy == null
                            ? Icons.arrow_outward_rounded
                            : proxyIcon,
                        iconColor: routeProxy == null
                            ? AppTints.slate
                            : proxyTint,
                        title: routeProxy == null
                            ? l10n.r13ProxyDirect
                            : _proxyId != null
                            ? routeName!
                            : l10n.r13ProxyTemporaryTitle,
                        subtitle: routeProxy == null
                            ? l10n.r13ProxyDirectSubtitle
                            : routeProxy.label,
                        chevron: true,
                        enabled: !running && !_loadingProxy,
                        onTap: _chooseProxy,
                      ),
                    ],
                  ),
                if (_proxyError != null)
                  AppBanner(
                    tone: AppTone.red,
                    icon: Icons.error_outline_rounded,
                    text: _proxyError!.messageFor(l10n),
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
                    footerWidget: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tcpOneObservation,
                          style: context.footnoteStyle,
                        ),
                        if (result.viaProxy &&
                            result.outcome == TcpOutcome.connected) ...[
                          const SizedBox(height: 6),
                          Text(
                            l10n.r13TcpProxiedNote,
                            key: const ValueKey('tcp-proxied-note'),
                            style: context.footnoteStyle,
                          ),
                        ],
                      ],
                    ),
                    children: [
                      _resultRow(
                        context,
                        StatusPill(
                          result.labelFor(l10n),
                          tone: _tone(result.outcome),
                          dot: true,
                        ),
                        accessory: result.errorDetails == null
                            ? null
                            : ErrorDetailsButton(details: result.errorDetails!),
                      ),
                      AppKeyValueRow(
                        label: l10n.uiConnTarget,
                        value: result.target.label,
                        mono: true,
                      ),
                      AppKeyValueRow(
                        label: l10n.r13TcpRoute,
                        value: result.viaProxy
                            ? l10n.r13TcpRouteVia(
                                result.proxyName == null
                                    ? result.proxy!.label
                                    : '${result.proxyName} · ${result.proxy!.label}',
                              )
                            : l10n.r13ProxyDirect,
                      ),
                      if (result.proxyFailure != null)
                        AppKeyValueRow(
                          key: const ValueKey('tcp-proxy-reason'),
                          label: l10n.r13TcpProxyReason,
                          value: result.proxyFailure!.messageFor(l10n),
                        ),
                      if (result.remoteAddress != null)
                        AppKeyValueRow(
                          label: result.viaProxy
                              ? l10n.r13TcpProxyAddress
                              : l10n.uiConnActualAddress,
                          value: result.remoteFamily == null
                              ? result.remoteAddress
                              : '${result.remoteAddress} · '
                                    '${result.remoteFamily == NetHostKind.ipv6 ? 'IPv6' : 'IPv4'}',
                          mono: true,
                        ),
                      AppKeyValueRow(
                        label: l10n.uiConnSource,
                        value: result.viaProxy
                            ? l10n.r13TcpSourceProxy
                            : result.sourceFor(l10n),
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
