import 'dart:async';

import 'package:flutter/material.dart';

import 'core/app_info.dart';
import 'core/app_theme.dart';
import 'core/app_viewport.dart';
import 'core/ui/ui.dart';
import 'data/ledger_store.dart';
import 'data/open_ledger.dart';
import 'home_shell.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/locale_preference.dart';
import 'providers/provider_directory.dart';
import 'servers/ledger_controller.dart';
import 'servers/server_detail.dart';
import 'security/credential_pages.dart' show securityRouteObserver;
import 'settings/reminder_scheduler.dart';

export 'home_shell.dart';
export 'tools_page.dart';

class LedgerApp extends StatefulWidget {
  const LedgerApp({
    super.key,
    this.openStore = openLedger,
    this.reminderPlatform,
    this.directory,
    this.deviceLocales,
  });
  final Future<LedgerStore> Function() openStore;
  final ReminderPlatform? reminderPlatform;

  /// The provider directory. `main` passes the real, downloading one; without
  /// it (tests) the app uses an empty directory and never touches the network.
  final ProviderDirectory? directory;

  /// The device's preferred languages. When given, a ledger created by this
  /// launch starts in the matching language ([LocalePreference.forNewLedger]);
  /// `main` passes the real ones. Existing ledgers keep their stored choice.
  final List<Locale>? deviceLocales;
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
  // What the MaterialApp currently shows; the rest of the ledger is rendered
  // by pages that listen to the controller themselves.
  String? _themeMode;
  LocalePreference? _language;
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
      final locales = widget.deviceLocales;
      if (store.isNewLedger && locales != null) {
        try {
          await store.saveLanguagePreference(
            LocalePreference.forNewLedger(locales),
          );
        } catch (_) {
          // Keep the schema default (Chinese); the choice stays in Settings.
        }
      }
      ready = LedgerController(
        store,
        reminderPlatform:
            widget.reminderPlatform ??
            NativeReminderPlatform(onOpen: openReminder),
        directory: widget.directory,
      );
      await ready.refresh();
      // The directory is independent of the ledger: reading its cache and the
      // background refresh never delay or block opening it.
      unawaited(ready.startDirectory());
      // Metadata only (no keychain access): lets every page know which servers
      // have SSH configured without first visiting a connection page.
      unawaited(ready.security.initialize());
      if (!mounted) {
        ready.dispose();
        await store.close();
        return;
      }
      setState(() {
        controller = ready;
        loading = false;
        _themeMode = ready!.themeMode;
        _language = ready.languagePreference;
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
    final ledger = controller;
    // Rebuilding the MaterialApp re-evaluates every theme-dependent widget, so
    // only do it when the theme or language actually changed.
    if (mounted &&
        ledger != null &&
        (ledger.themeMode != _themeMode ||
            ledger.languagePreference != _language)) {
      setState(() {
        _themeMode = ledger.themeMode;
        _language = ledger.languagePreference;
      });
    }
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
    title: kAppName,
    navigatorKey: navigatorKey,
    navigatorObservers: [securityRouteObserver, _viewport, _titleObserver],
    scrollBehavior: const AppScrollBehavior(),
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    darkTheme: appTheme(brightness: Brightness.dark),
    themeMode: switch (_themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    },
    locale: (_language ?? LocalePreference.chinese).resolve(
      WidgetsBinding.instance.platformDispatcher.locales,
    ),
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
