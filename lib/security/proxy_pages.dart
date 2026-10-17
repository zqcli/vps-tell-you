import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/net_address.dart';
import '../core/ui/ui.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../servers/ledger_controller.dart';
import 'proxy_models.dart';
import 'security_controller.dart';
import 'security_pages.dart';

const proxyTint = AppTints.indigo;
const proxyIcon = Icons.alt_route_rounded;

String proxySummary(ProxyRecord proxy) =>
    '${proxy.kind.label} · ${proxy.address}'
    '${proxy.hasCredentials ? ' · ${proxy.username}' : ''}';

/// What a proxy picker returns. `direct` clears the proxy; otherwise exactly
/// one of [savedId] / [temporary] is set.
class ProxyChoice {
  const ProxyChoice.direct() : savedId = null, temporary = null;
  const ProxyChoice.saved(String this.savedId) : temporary = null;
  const ProxyChoice.temporary(ProxyEndpoint this.temporary) : savedId = null;
  final String? savedId;
  final ProxyEndpoint? temporary;
  bool get isDirect => savedId == null && temporary == null;
}

const _directValue = '';
const _newValue = '\u0000new';
const _temporaryValue = '\u0000temporary';

/// Direct / saved proxies / "New Proxy…" (SSH settings) or "Enter Proxy…"
/// (one-off, TCP test). Returns null when dismissed.
Future<ProxyChoice?> chooseProxy(
  BuildContext context,
  LedgerController ledger, {
  String? selectedId,
  bool temporarySelected = false,
  bool allowTemporary = false,
  ProxyEndpoint? previousTemporary,
}) async {
  final l10n = context.l10n;
  final security = ledger.security;
  final value = await showAppPicker<String>(
    context,
    title: l10n.r13ProxyChoose,
    selected: temporarySelected
        ? _temporaryValue
        : (selectedId ?? _directValue),
    options: [
      AppPickerOption(
        key: const ValueKey('proxy-option-direct'),
        value: _directValue,
        title: l10n.r13ProxyDirect,
        subtitle: l10n.r13ProxyDirectSubtitle,
        icon: Icons.arrow_outward_rounded,
        iconColor: AppTints.slate,
      ),
      for (final proxy in security.proxies)
        AppPickerOption(
          key: ValueKey('proxy-option-${proxy.id}'),
          value: proxy.id,
          title: proxy.name,
          subtitle: proxySummary(proxy),
          icon: proxyIcon,
          iconColor: proxyTint,
        ),
      if (allowTemporary)
        AppPickerOption(
          key: const ValueKey('proxy-option-temporary'),
          value: _temporaryValue,
          title: l10n.r13TcpEnterProxy,
          icon: Icons.edit_outlined,
          iconColor: AppTints.orange,
        )
      else
        AppPickerOption(
          key: const ValueKey('proxy-option-new'),
          value: _newValue,
          title: l10n.r13ProxyNew,
          icon: Icons.add_circle_outline,
          iconColor: AppTints.green,
        ),
    ],
  );
  if (value == null || !context.mounted) return null;
  switch (value) {
    case _directValue:
      return const ProxyChoice.direct();
    case _newValue:
      final id = await Navigator.push<Object>(
        context,
        MaterialPageRoute(builder: (_) => ProxyForm(ledger: ledger)),
      );
      return id is String ? ProxyChoice.saved(id) : null;
    case _temporaryValue:
      final endpoint = await Navigator.push<Object>(
        context,
        MaterialPageRoute(
          builder: (_) => ProxyForm(
            ledger: ledger,
            temporary: true,
            initialTemporary: previousTemporary,
          ),
        ),
      );
      return endpoint is ProxyEndpoint ? ProxyChoice.temporary(endpoint) : null;
    default:
      return ProxyChoice.saved(value);
  }
}

/// Settings › Keys & Security › Proxies.
class ProxyListPage extends StatefulWidget {
  const ProxyListPage({super.key, required this.ledger});
  final LedgerController ledger;
  @override
  State<ProxyListPage> createState() => _ProxyListPageState();
}

class _ProxyListPageState extends State<ProxyListPage> {
  bool loading = true;
  SecurityController get security => widget.ledger.security;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await security.initialize();
    if (mounted) setState(() => loading = false);
  }

  Future<void> _open([ProxyRecord? proxy]) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => ProxyForm(ledger: widget.ledger, existing: proxy),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: security,
    builder: (context, _) {
      final l10n = context.l10n;
      return AppScaffold(
        title: l10n.r13ProxiesTitle,
        actions: [
          AppNavButton.icon(
            Icons.add,
            key: const ValueKey('proxy-add'),
            tooltip: l10n.r13ProxyAdd,
            onPressed: security.busy || security.needsReload ? null : _open,
          ),
        ],
        children: loading
            ? const [
                Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CupertinoActivityIndicator()),
                ),
              ]
            : [
                SecurityNotice(controller: security),
                AppSection(
                  header: l10n.r13ProxyCount(security.proxies.length),
                  footer: l10n.r13ProxyListFooter,
                  children: [
                    if (security.proxies.isEmpty)
                      AppRow.custom(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            l10n.r13ProxyEmpty,
                            textAlign: TextAlign.center,
                            style: context.footnoteStyle.copyWith(fontSize: 14),
                          ),
                        ),
                      ),
                    for (final proxy in security.proxies)
                      AppRow(
                        key: ValueKey('proxy-${proxy.id}'),
                        icon: proxyIcon,
                        iconColor: proxyTint,
                        title: proxy.name,
                        subtitle: proxySummary(proxy),
                        trailing: StatusPill(
                          l10n.securityLinkedServerCount(
                            security.proxyReferences(proxy.id).length,
                          ),
                        ),
                        chevron: true,
                        onTap: () => _open(proxy),
                      ),
                  ],
                ),
              ],
      );
    },
  );
}

/// Add / edit a saved proxy, or (temporary) enter one for a single TCP test.
/// Pops the saved proxy id, or the temporary [ProxyEndpoint].
class ProxyForm extends StatefulWidget {
  const ProxyForm({
    super.key,
    required this.ledger,
    this.existing,
    this.temporary = false,
    this.initialTemporary,
  });
  final LedgerController ledger;
  final ProxyRecord? existing;
  final bool temporary;
  final ProxyEndpoint? initialTemporary;
  @override
  State<ProxyForm> createState() => _ProxyFormState();
}

class _ProxyFormState extends State<ProxyForm> with WidgetsBindingObserver {
  late final name = TextEditingController(text: widget.existing?.name);
  late final host = TextEditingController(
    text: widget.existing?.host ?? widget.initialTemporary?.host,
  );
  late final port = TextEditingController(
    text:
        '${widget.existing?.port ?? widget.initialTemporary?.port ?? ProxyKind.socks5.defaultPort}',
  );
  late final username = TextEditingController(
    text: widget.existing?.username ?? widget.initialTemporary?.username,
  );
  late final password = TextEditingController(
    text: widget.initialTemporary?.password,
  );
  late ProxyKind kind =
      widget.existing?.kind ??
      widget.initialTemporary?.kind ??
      ProxyKind.socks5;
  bool dirty = false, saving = false, allowPop = false;
  bool validationAttempted = false;

  SecurityController get security => widget.ledger.security;
  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      password.clear();
      security.hideSensitive();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    name.dispose();
    host.dispose();
    port.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  void _changed() => setState(() => dirty = true);

  void _setKind(ProxyKind next) {
    setState(() {
      final typed = int.tryParse(port.text.trim());
      if (port.text.trim().isEmpty || typed == kind.defaultPort) {
        port.text = '${next.defaultPort}';
      }
      kind = next;
      dirty = true;
    });
  }

  String? nameError(AppLocalizations l10n) =>
      validationAttempted && !widget.temporary && name.text.trim().isEmpty
      ? l10n.r13ProxyNameRequired
      : null;

  String? hostError(AppLocalizations l10n) {
    if (!validationAttempted) return null;
    final address = NetAddress.tryParse(host.text.trim());
    return address == null || address.zone != null
        ? l10n.connectionValidHost
        : null;
  }

  String? portError(AppLocalizations l10n) {
    if (!validationAttempted) return null;
    final n = int.tryParse(port.text.trim());
    return n == null || n < 1 || n > 65535 ? l10n.securityPortRequired : null;
  }

  String? usernameError(AppLocalizations l10n) {
    if (!validationAttempted) return null;
    final user = username.text.trim();
    if (user.isEmpty) return null;
    return validProxyCredential(user, allowColon: kind == ProxyKind.socks5)
        ? null
        : l10n.r13ProxyCredentialInvalid;
  }

  String? passwordError(AppLocalizations l10n) {
    if (!validationAttempted) return null;
    final user = username.text.trim();
    final pass = password.text;
    if (user.isEmpty) {
      return pass.isEmpty ? null : l10n.r13ProxyUsernameRequired;
    }
    if (pass.isEmpty) {
      return widget.existing?.hasCredentials == true
          ? null
          : l10n.securityLoginPasswordRequired;
    }
    return validProxyCredential(pass, allowColon: true)
        ? null
        : l10n.r13ProxyCredentialInvalid;
  }

  bool _valid(AppLocalizations l10n) =>
      nameError(l10n) == null &&
      hostError(l10n) == null &&
      portError(l10n) == null &&
      usernameError(l10n) == null &&
      passwordError(l10n) == null;

  Future<void> cancel() async {
    if (saving) return;
    if (dirty &&
        !await showAppConfirm(
          context,
          title: LocalizedText((l10n) => l10n.r13ProxyDiscardTitle),
          message: LocalizedText((l10n) => l10n.r13ProxyDiscardMessage),
          action: LocalizedText((l10n) => l10n.securityDiscardChanges),
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => allowPop = true);
    Navigator.pop(context);
  }

  Future<void> save() async {
    if (saving) return;
    final l10n = context.l10n;
    setState(() => validationAttempted = true);
    if (!_valid(l10n)) return;
    final user = username.text.trim();
    final address = NetAddress.tryParse(host.text.trim())!;
    if (widget.temporary) {
      final endpoint = ProxyEndpoint(
        kind: kind,
        host: address.host,
        port: int.parse(port.text.trim()),
        username: user.isEmpty ? null : user,
        password: user.isEmpty ? null : password.text,
      );
      setState(() => allowPop = true);
      Navigator.pop<Object>(context, endpoint);
      return;
    }
    setState(() => saving = true);
    final id = await security.saveProxy(
      existing: widget.existing,
      name: name.text,
      kind: kind,
      host: host.text,
      port: int.parse(port.text.trim()),
      username: user,
      password: password.text.isEmpty ? null : password.text,
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (id != null) {
      password.clear();
      setState(() => allowPop = true);
      Navigator.pop<Object>(context, id);
      securityMessage(context, LocalizedText((l10n) => l10n.r13ProxySaved));
    }
  }

  Future<void> delete() async {
    final proxy = widget.existing!;
    if (!await showAppConfirm(
      context,
      title: LocalizedText((l10n) => l10n.r13ProxyDeleteTitle),
      message: LocalizedText((l10n) => l10n.r13ProxyDeleteMessage),
      action: LocalizedText((l10n) => l10n.r13ProxyDelete),
      dangerous: true,
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => saving = true);
    final ok = await security.deleteProxy(proxy);
    if (!mounted) return;
    setState(() => saving = false);
    if (ok) {
      setState(() => allowPop = true);
      Navigator.pop(context);
      securityMessage(context, LocalizedText((l10n) => l10n.r13ProxyDeleted));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: security,
    builder: (context, _) {
      final l10n = context.l10n;
      final p = context.palette;
      final existing = widget.existing;
      final references = existing == null
          ? 0
          : security.proxyReferences(existing.id).length;
      final revealed =
          existing != null &&
          security.revealedProxyId == existing.id &&
          security.revealedProxyPassword != null;
      return PopScope(
        canPop: allowPop || (!dirty && !saving),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            cancel();
          } else {
            security.hideSensitive();
          }
        },
        child: AppScaffold(
          title: widget.temporary
              ? l10n.r13ProxyTemporaryTitle
              : isEdit
              ? l10n.r13ProxyEdit
              : l10n.r13ProxyAdd,
          largeTitle: false,
          leading: AppNavButton.icon(
            Icons.close,
            tooltip: l10n.securityCancelCredentialEdit,
            onPressed: saving ? null : cancel,
          ),
          bottomBar: AppButton(
            key: const ValueKey('proxy-save'),
            label: saving
                ? l10n.securitySaving
                : widget.temporary
                ? l10n.r13ProxyUse
                : l10n.r13ProxySave,
            expand: true,
            onPressed: saving || security.busy || security.needsReload
                ? null
                : save,
          ),
          children: [
            if (!widget.temporary) SecurityNotice(controller: security),
            AppSection(
              footer: widget.temporary ? l10n.r13TcpProxyFooter : null,
              children: [
                if (!widget.temporary)
                  AppFormRow(
                    label: l10n.r13ProxyName,
                    required: true,
                    errorText: nameError(l10n),
                    child: AppTextField(
                      key: const ValueKey('proxy-name'),
                      controller: name,
                      enabled: !saving,
                      maxLength: 80,
                      hint: l10n.r13ProxyNameHint,
                      label: l10n.r13ProxyName,
                      onChanged: (_) => _changed(),
                    ),
                  ),
                AppFormRow(
                  label: l10n.r13ProxyType,
                  child: AppSegmented<ProxyKind>(
                    key: const ValueKey('proxy-kind'),
                    compact: true,
                    options: {for (final k in ProxyKind.values) k: k.label},
                    value: kind,
                    onChanged: saving ? (_) {} : _setKind,
                  ),
                ),
                AppFormRow(
                  label: l10n.r13ProxyHost,
                  required: true,
                  errorText: hostError(l10n),
                  child: AppTextField(
                    key: const ValueKey('proxy-host'),
                    controller: host,
                    enabled: !saving,
                    autocorrect: false,
                    keyboardType: TextInputType.url,
                    hint: l10n.securityHostHint,
                    label: l10n.r13ProxyHost,
                    onChanged: (_) => _changed(),
                  ),
                ),
                AppFormRow(
                  label: l10n.securityPort,
                  required: true,
                  errorText: portError(l10n),
                  child: AppTextField(
                    key: const ValueKey('proxy-port'),
                    controller: port,
                    enabled: !saving,
                    keyboardType: TextInputType.number,
                    label: l10n.securityPort,
                    onChanged: (_) => _changed(),
                  ),
                ),
              ],
            ),
            AppSection(
              footer: existing != null && existing.hasCredentials
                  ? l10n.r13ProxyKeepPassword
                  : null,
              children: [
                AppFormRow(
                  label: l10n.r13ProxyUsername,
                  errorText: usernameError(l10n),
                  child: AppTextField(
                    key: const ValueKey('proxy-username'),
                    controller: username,
                    enabled: !saving,
                    autocorrect: false,
                    enableSuggestions: false,
                    label: l10n.r13ProxyUsername,
                    onChanged: (_) => _changed(),
                  ),
                ),
                AppFormRow(
                  label: l10n.r13ProxyPassword,
                  errorText: passwordError(l10n),
                  child: AppTextField(
                    key: const ValueKey('proxy-password'),
                    controller: password,
                    enabled: !saving,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    autofillHints: const [],
                    label: l10n.r13ProxyPassword,
                    onChanged: (_) => _changed(),
                  ),
                ),
              ],
            ),
            if (!widget.temporary) SecurityFootnote(l10n.r13ProxyListFooter),
            if (existing != null && existing.hasCredentials) ...[
              AppSection(
                header: l10n.securityProtectedPassword,
                footer: revealed
                    ? l10n.securityPasswordRevealNotice
                    : l10n.securityPasswordHiddenNotice,
                children: [
                  AppRow.custom(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        revealed
                            ? security.revealedProxyPassword!
                            : '••••••••••••••••',
                        key: const ValueKey('revealed-proxy-password'),
                        style: kMonoTextStyle.copyWith(
                          fontSize: 16,
                          color: p.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SecurityAction(
                child: AppButton(
                  key: const ValueKey('proxy-reveal'),
                  label: revealed
                      ? l10n.securityHidePassword
                      : l10n.r13ProxyShowPassword,
                  icon: revealed
                      ? Icons.lock_outline
                      : Icons.visibility_outlined,
                  expand: true,
                  onPressed: security.busy || saving
                      ? null
                      : () {
                          if (revealed) {
                            security.hideSensitive();
                          } else {
                            security.revealProxy(existing, l10n: l10n);
                          }
                        },
                ),
              ),
            ],
            if (existing != null)
              AppSection(
                topSpacing: 18,
                footer: references > 0
                    ? l10n.r13ProxyDeleteBlocked(references)
                    : null,
                children: [
                  AppRow(
                    key: const ValueKey('proxy-delete'),
                    icon: Icons.delete_outline,
                    iconColor: AppTints.red,
                    title: l10n.r13ProxyDelete,
                    destructive: true,
                    enabled: references == 0 && !saving && !security.busy,
                    onTap: delete,
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}
