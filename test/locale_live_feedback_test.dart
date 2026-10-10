import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/app.dart';
import 'package:vps_tell_you/connections/connection_pages.dart';
import 'package:vps_tell_you/connections/ssh_service.dart';
import 'package:vps_tell_you/connections/terminal_page.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/core/value_types.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';
import 'package:vps_tell_you/l10n/locale_preference.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/security/security_pages.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/refresh_failure_notice.dart';
import 'package:vps_tell_you/servers/server_detail.dart';
import 'package:vps_tell_you/servers/server_form.dart';
import 'package:vps_tell_you/servers/server_list.dart';
import 'package:vps_tell_you/servers/server_record.dart';
import 'package:vps_tell_you/servers/server_resources.dart';
import 'package:vps_tell_you/settings/reminder_page.dart';
import 'package:vps_tell_you/settings/settings_page.dart';
import 'package:xterm/xterm.dart';

import 'security_store_test.dart' show FakeDeviceAuth, FakeSecretStore;
import 'support/form_test_helpers.dart';
import 'support/reminder_platform.dart';
import 'terminal_widget_test.dart' show SpySshService;

class FeedbackLedgerController extends LedgerController {
  FeedbackLedgerController(
    super.store, {
    required super.security,
    required super.reminderPlatform,
  });
  int mutations = 0, languageWrites = 0, reloads = 0;
  bool failMutation = false, failLanguage = false, failReload = false;

  @override
  Future<T> mutate<T>(Future<T> Function() action) {
    mutations++;
    if (failMutation) throw StateError('Synthetic mutation failure');
    return super.mutate(action);
  }

  @override
  Future<void> setLanguage(LocalePreference preference) {
    languageWrites++;
    if (failLanguage) throw StateError('Synthetic preference failure');
    return super.setLanguage(preference);
  }

  @override
  Future<void> refresh() {
    reloads++;
    if (failReload) throw StateError('Synthetic reload failure');
    return super.refresh();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final en = AppLocalizationsEn(), zh = AppLocalizationsZh();
  late Directory directory;
  late LedgerStore store;
  late FeedbackLedgerController ledger;
  late FakeReminderPlatform reminders;
  late ValueNotifier<Locale> locale;
  late GlobalKey<ScaffoldMessengerState> messenger;
  late SpySshService ssh;
  const target = SshTarget(
    name: 'Synthetic terminal',
    host: '192.0.2.10',
    username: 'fixture',
    credentialId: 'synthetic',
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('locale-live-feedback-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.db',
    );
    final now = DateTime(2026, 10, 7, 12);
    await store.saveServer(
      ServerRecord(
        id: 'fixture',
        name: '用户自填名称',
        vendor: 'Synthetic provider',
        host: '192.0.2.10',
        billing: BillingKind.prepaid,
        amountMinor: 3650,
        dueDate: const LedgerDate(2027, 1, 1),
        createdAt: now,
        updatedAt: now,
      ),
      isNew: true,
    );
    reminders = FakeReminderPlatform()..supported = false;
    ledger = FeedbackLedgerController(
      store,
      security: SecurityController(
        store: store,
        secrets: FakeSecretStore(),
        authenticator: FakeDeviceAuth(),
      ),
      reminderPlatform: reminders,
    );
    await ledger.refresh();
    locale = ValueNotifier(const Locale('en'));
    messenger = GlobalKey<ScaffoldMessengerState>();
    ssh = SpySshService();
  });
  tearDown(() async {
    locale.dispose();
    ledger.dispose();
    if (!ssh.disposed) ssh.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester,
    Widget page, {
    double scale = 1,
    Size size = const Size(390, 844),
    bool reviewFont = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final baseTheme = appTheme();
    if (reviewFont) {
      // Actual glyph metrics matter for the compact fee row. Ahem's square
      // Latin glyphs are intentionally unlike any of the shipped UI fonts.
      await tester.runAsync(() async {
        final font = FontLoader('Live locale review');
        font.addFont(
          File(
            Platform.environment['VPS_I18N_FONT'] ??
                'assets/fonts/DejaVuSansMono.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        );
        await font.load();
        if (Platform.environment['FLUTTER_BOOTSTRAP_ROOT'] case final sdk?) {
          final icons = FontLoader('MaterialIcons');
          icons.addFont(
            File(
              '$sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes().then(ByteData.sublistView),
          );
          await icons.load();
        }
      });
    }
    final theme = reviewFont
        ? baseTheme.copyWith(
            textTheme: baseTheme.textTheme.apply(
              fontFamily: 'Live locale review',
            ),
            appBarTheme: baseTheme.appBarTheme.copyWith(
              titleTextStyle: baseTheme.appBarTheme.titleTextStyle?.copyWith(
                fontFamily: 'Live locale review',
              ),
            ),
          )
        : baseTheme;
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (_, language, _) => MaterialApp(
          theme: theme,
          locale: language,
          scaffoldMessengerKey: messenger,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => page),
                ),
                child: const Text('Open fixture'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open fixture'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> change(WidgetTester tester, String language) async {
    locale.value = Locale(language);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.pumpAndSettle();
    final scrolling = find.byType(Scrollable).first;
    if (finder.evaluate().isEmpty) {
      tester.state<ScrollableState>(scrolling).position.jumpTo(0);
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(finder, 240, scrollable: scrolling);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pumpAndSettle();
    expect(finder.hitTestable(), findsOneWidget);
  }

  Future<void> blockSnacks(WidgetTester tester) async {
    messenger.currentState!.showSnackBar(
      const SnackBar(persist: true, content: Text('Queue blocker')),
    );
    await tester.pumpAndSettle();
  }

  Future<void> showQueued(WidgetTester tester) async {
    messenger.currentState!.removeCurrentSnackBar();
    await tester.pumpAndSettle();
  }

  Future<void> archive(WidgetTester tester) async {
    await tester.tap(find.byTooltip(en.serverMoreActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.serverArchiveLocal));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, en.serverArchiveLocal));
    await tester.pumpAndSettle();
  }

  testWidgets('queued and visible archive undo relocalizes and executes once', (
    tester,
  ) async {
    await mount(tester, ServerDetail(controller: ledger, id: 'fixture'));
    await blockSnacks(tester);
    await archive(tester);
    expect(ledger.mutations, 1);
    expect((await store.servers()).single.archived, isTrue);
    await change(tester, 'zh');
    await showQueued(tester);
    expect(find.text(zh.serverArchived), findsOneWidget);
    expect(find.text(zh.serverUndo), findsOneWidget);
    final actionState = tester.state(find.byType(SnackBarAction));
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isTrue);
    await tester.pump(const Duration(seconds: 9));
    expect(find.byType(SnackBarAction), findsOneWidget);
    await change(tester, 'en');
    expect(find.text(en.serverArchived), findsOneWidget);
    expect(find.text(en.serverUndo), findsOneWidget);
    expect(tester.state(find.byType(SnackBarAction)), same(actionState));
    expect(ledger.mutations, 1);
    final button = find.descendant(
      of: find.byType(SnackBarAction),
      matching: find.byType(TextButton),
    );
    final activate = tester.widget<TextButton>(button).onPressed!;
    activate();
    activate();
    await tester.pumpAndSettle();
    expect(ledger.mutations, 2);
    final restored = (await store.servers()).single;
    expect(restored.archived, isFalse);
    expect(restored.revision, 2);
    expect(find.byType(SnackBarAction), findsNothing);
  });

  testWidgets('archive after reload failure still omits undo and expires', (
    tester,
  ) async {
    await mount(tester, ServerDetail(controller: ledger, id: 'fixture'));
    ledger.failReload = true;
    await archive(tester);
    expect(ledger.refreshFailed, isTrue);
    expect((await store.servers()).single.archived, isTrue);
    expect(find.byType(SnackBarAction), findsNothing);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isFalse);
    await change(tester, 'zh');
    expect(find.text(zh.serverArchived), findsOneWidget);
    expect(ledger.mutations, 1);
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'reminder save feedback relocalizes queued and open without resave',
    (tester) async {
      await mount(
        tester,
        ReminderPage(controller: ledger, serverId: 'fixture'),
      );
      await tester.tap(find.byType(SwitchListTile));
      final save = find.text(en.saveReminderRules);
      await reveal(tester, save);
      await blockSnacks(tester);
      // The queue blocker obscures the lower page; invoke this visible button's
      // existing action rather than changing or reissuing the save operation.
      final saveButton = find.ancestor(
        of: save,
        matching: find.byType(FilledButton),
      );
      tester.widget<FilledButton>(saveButton).onPressed!();
      await tester.pumpAndSettle();
      final saved = (await store.reminderRules()).single;
      expect(saved.enabled, isFalse);
      expect(saved.revision, 1);
      expect(ledger.mutations, 1);
      await change(tester, 'zh');
      await showQueued(tester);
      expect(find.text(zh.reminderRulesSaved), findsOneWidget);
      await change(tester, 'en');
      expect(find.text(en.reminderRulesSaved), findsOneWidget);
      expect(ledger.mutations, 1);
      expect((await store.reminderRules()).single.revision, 1);
      expect(reminders.schedules, 0);
      expect(reminders.requests, 0);
    },
  );

  testWidgets(
    'language save failure follows locale without retrying the write',
    (tester) async {
      ledger.failLanguage = true;
      await mount(tester, Scaffold(body: SettingsPage(controller: ledger)));
      final language = find.byKey(const ValueKey('language-setting'));
      await reveal(tester, language);
      await tester.tap(language);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-en')));
      await tester.pumpAndSettle();
      expect(find.text(en.languageSaveFailed), findsOneWidget);
      await change(tester, 'zh');
      expect(find.text(zh.languageSaveFailed), findsOneWidget);
      expect(ledger.languageWrites, 1);
      expect(await store.languagePreference(), LocalePreference.chinese);
    },
  );

  testWidgets('reload failure feedback follows locale without another reload', (
    tester,
  ) async {
    ledger.failReload = true;
    await mount(
      tester,
      Scaffold(body: RefreshFailureNotice(controller: ledger)),
    );
    final before = ledger.reloads;
    await tester.tap(find.text(en.serverReload));
    await tester.pumpAndSettle();
    expect(find.text(en.serverReloadStillFailed), findsOneWidget);
    await change(tester, 'zh');
    expect(find.text(zh.serverReloadStillFailed), findsOneWidget);
    expect(ledger.reloads, before + 1);
    expect(ledger.mutations, 0);
  });

  testWidgets(
    'group save fallback follows locale without retrying a mutation',
    (tester) async {
      ledger.failMutation = true;
      await mount(tester, GroupsPage(controller: ledger));
      await tester.tap(find.byTooltip(en.addGroup));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('group-name')),
        'Raw group',
      );
      await tester.tap(find.widgetWithText(FilledButton, en.save));
      await tester.pumpAndSettle();
      expect(find.text(en.groupSaveFailed), findsOneWidget);
      await change(tester, 'zh');
      expect(find.text(zh.groupSaveFailed), findsOneWidget);
      expect(ledger.mutations, 1);
      expect(await store.groups(), isEmpty);
    },
  );

  for (final fails in [false, true]) {
    testWidgets('host copy feedback stays live, failure=$fails', (
      tester,
    ) async {
      var copies = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copies++;
            expect((call.arguments as Map)['text'], '192.0.2.10');
            if (fails) throw PlatformException(code: 'synthetic-denial');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await mount(tester, ServerDetail(controller: ledger, id: 'fixture'));
      final copy = find.byTooltip(en.serverCopyHost);
      await reveal(tester, copy);
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(
        find.text(fails ? en.serverCopyHostFailed : en.serverHostCopied),
        findsOneWidget,
      );
      await change(tester, 'zh');
      expect(
        find.text(fails ? zh.serverCopyHostFailed : zh.serverHostCopied),
        findsOneWidget,
      );
      expect(copies, 1);
      expect(ledger.mutations, 0);
    });

    testWidgets(
      'terminal copy feedback relocalizes queued and open, failure=$fails',
      (tester) async {
        var copies = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copies++;
              expect((call.arguments as Map)['text'], 'syntheticcopy');
              if (fails) throw PlatformException(code: 'synthetic-denial');
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await mount(
          tester,
          TerminalPage(
            ledger: ledger,
            target: target,
            connectOnOpen: true,
            serviceFactory: (_) => ssh,
          ),
        );
        ssh.events.add('syntheticcopy\r\n');
        await tester.pumpAndSettle();
        final terminal = find.byType(TerminalView);
        final view = tester.state<TerminalViewState>(terminal);
        await tester.longPressAt(
          tester.getTopLeft(terminal) +
              Offset(
                8 + view.renderTerminal.cellSize.width * 2,
                8 + view.renderTerminal.cellSize.height / 2,
              ),
        );
        await tester.pumpAndSettle();
        final controller = tester.widget<TerminalView>(terminal).controller!;
        final selection = controller.selection;
        expect(selection, isNotNull);
        await blockSnacks(tester);
        await tester.tap(find.byKey(const ValueKey('terminal-copy-selection')));
        await tester.pumpAndSettle();
        expect(copies, 1);
        await change(tester, 'zh');
        await showQueued(tester);
        expect(
          find.text(fails ? zh.terminalCopyFailed : zh.terminalSelectionCopied),
          findsOneWidget,
        );
        await change(tester, 'en');
        expect(
          find.text(fails ? en.terminalCopyFailed : en.terminalSelectionCopied),
          findsOneWidget,
        );
        expect(controller.selection, fails ? equals(selection) : isNull);
        expect(copies, 1);
        expect(ssh.connections, 1);
        expect(ssh.authentications, 1);
        expect(ssh.writes, isEmpty);
        expect(ssh.powers, isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('open time picker relocalizes all labels and keeps 24h draft', (
    tester,
  ) async {
    await mount(tester, ReminderPage(controller: ledger, serverId: 'fixture'));
    await reveal(tester, find.text('09:00'));
    await tester.tap(find.text('09:00'));
    await tester.pumpAndSettle();
    final dialog = find.byType(TimePickerDialog);
    Finder pickerText(String value) =>
        find.descendant(of: dialog, matching: find.text(value));
    final pickerState = tester.state(dialog);
    var material = MaterialLocalizations.of(tester.element(dialog));
    expect(pickerText(material.timePickerDialHelpText), findsOneWidget);
    expect(MediaQuery.of(tester.element(dialog)).alwaysUse24HourFormat, isTrue);
    await tester.tap(find.byTooltip(material.inputTimeModeButtonLabel));
    await tester.pumpAndSettle();
    final inputs = find.descendant(
      of: dialog,
      matching: find.byType(TextFormField),
    );
    await tester.enterText(inputs.at(0), '17');
    await tester.enterText(inputs.at(1), '42');
    final hour = tester.widget<TextFormField>(inputs.at(0)).controller!;
    final minute = tester.widget<TextFormField>(inputs.at(1)).controller!;
    await change(tester, 'zh');
    material = MaterialLocalizations.of(tester.element(dialog));
    expect(tester.state(dialog), same(pickerState));
    expect(pickerText(material.timePickerInputHelpText), findsOneWidget);
    expect(pickerText(material.timePickerHourLabel), findsOneWidget);
    expect(pickerText(material.timePickerMinuteLabel), findsOneWidget);
    expect(pickerText(material.cancelButtonLabel), findsOneWidget);
    expect(pickerText(material.okButtonLabel), findsOneWidget);
    expect(find.byTooltip(material.dialModeButtonLabel), findsOneWidget);
    expect(tester.widget<TextFormField>(inputs.at(0)).controller, same(hour));
    expect(tester.widget<TextFormField>(inputs.at(1)).controller, same(minute));
    expect(hour.text, '17');
    expect(minute.text, '42');
    expect(ledger.mutations, 0);
    expect((await store.reminderRules()).single.minuteOfDay, 9 * 60);
    await tester.tap(pickerText(material.okButtonLabel));
    await tester.pumpAndSettle();
    expect(find.text('17:42'), findsOneWidget);
    expect((await store.reminderRules()).single.minuteOfDay, 9 * 60);
    await tester.tap(find.text('17:42'));
    await tester.pumpAndSettle();
    await change(tester, 'en');
    material = MaterialLocalizations.of(tester.element(dialog));
    await tester.tap(find.byTooltip(material.inputTimeModeButtonLabel));
    await tester.pumpAndSettle();
    await tester.enterText(inputs.at(0), '99');
    await tester.tap(pickerText(material.okButtonLabel));
    await tester.pumpAndSettle();
    expect(pickerText(material.invalidTimeLabel), findsOneWidget);
    await change(tester, 'zh');
    material = MaterialLocalizations.of(tester.element(dialog));
    expect(pickerText(material.invalidTimeLabel), findsOneWidget);
    await tester.tap(pickerText(material.cancelButtonLabel));
    await tester.pumpAndSettle();
    expect(find.text('17:42'), findsOneWidget);
    await tester.tap(find.text('17:42'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('17:42'), findsOneWidget);
    expect(ledger.mutations, 0);
    expect(reminders.schedules, 0);
    expect(reminders.requests, 0);
    final save = find.text(zh.saveReminderRules);
    await reveal(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect((await store.reminderRules()).single.minuteOfDay, 17 * 60 + 42);
    expect(ledger.mutations, 1);
  });

  test('temporary target marker survives normalization without changing user names', () {
    final temporary = SshTarget(
      name: '',
      host: 'EXAMPLE.TEST',
      username: target.username,
      credentialId: target.credentialId,
      isTemporary: true,
    ).normalized();
    expect(temporary.isTemporary, isTrue);
    expect(temporary.host, 'example.test');
    expect(temporary.displayNameFor(en), en.connectionTemporary);
    expect(temporary.displayNameFor(zh), zh.connectionTemporary);
    final named = SshTarget(
      name: '临时连接',
      host: target.host,
      username: target.username,
      credentialId: target.credentialId,
    ).normalized();
    expect(named.isTemporary, isFalse);
    expect(named.displayNameFor(en), '临时连接');
    expect(named.displayNameFor(zh), '临时连接');
    expect(named.label, target.label);
  });

  for (final isTemporary in [false, true]) {
    testWidgets(
      'live SSH target relocalizes only generated name, temporary=$isTemporary',
      (tester) async {
        final liveTarget = SshTarget(
          name: '临时连接',
          host: target.host,
          username: target.username,
          credentialId: target.credentialId,
          isTemporary: isTemporary,
        );
        await mount(
          tester,
          TerminalPage(
            ledger: ledger,
            target: liveTarget,
            connectOnOpen: true,
            serviceFactory: (_) => ssh,
          ),
        );
        final generation = ssh.generation;
        expect(
          find.text(isTemporary ? en.connectionTemporary : '临时连接'),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip(en.terminalMenu));
        await tester.pumpAndSettle();
        final menuRoute = ModalRoute.of(
          tester.element(find.text(en.terminalSessionDetails)),
        );
        await change(tester, 'zh');
        expect(find.text(zh.terminalSessionDetails), findsOneWidget);
        expect(find.text(en.terminalSessionDetails), findsNothing);
        expect(
          ModalRoute.of(tester.element(find.text(zh.terminalSessionDetails))),
          same(menuRoute),
        );
        expect(ssh.connections, 1);
        expect(ssh.writes, isEmpty);
        await change(tester, 'en');
        await tester.tap(find.text(en.terminalSessionDetails));
        await tester.pumpAndSettle();
        await change(tester, 'zh');
        expect(find.text('临时连接'), findsWidgets);
        await change(tester, 'en');
        expect(
          find.text(isTemporary ? en.connectionTemporary : '临时连接'),
          findsWidgets,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(en.terminalMenu));
        await tester.pumpAndSettle();
        await tester.tap(find.text(en.terminalSshShutdown));
        await tester.pumpAndSettle();
        final englishName = isTemporary ? en.connectionTemporary : '临时连接';
        expect(find.textContaining(englishName), findsWidgets);
        await change(tester, 'zh');
        expect(find.textContaining('临时连接'), findsWidgets);
        await change(tester, 'en');
        expect(find.textContaining(englishName), findsWidgets);
        expect(ssh.target, same(liveTarget));
        expect(ssh.target!.label, target.label);
        expect(ssh.connections, 1);
        expect(ssh.authentications, 1);
        expect(ssh.disconnections, 0);
        expect(ssh.generation, generation);
        expect(ssh.writes, isEmpty);
        expect(ssh.powers, isEmpty);
        await tester.tap(find.text(en.cancel));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'open sort popup follows locale and applies only the selected stable value',
    (tester) async {
      await mount(tester, Scaffold(body: ServerList(controller: ledger)));
      final sort = find.byTooltip(en.serverSort);
      await reveal(tester, sort);
      await tester.tap(sort);
      await tester.pumpAndSettle();
      final popup = ModalRoute.of(tester.element(find.text(en.serverSortName)));
      await change(tester, 'zh');
      expect(find.text(zh.serverSortName), findsOneWidget);
      expect(find.text(en.serverSortName), findsNothing);
      expect(
        ModalRoute.of(tester.element(find.text(zh.serverSortName))),
        same(popup),
      );
      expect(ledger.sort, ServerSort.favorites);
      await tester.tap(find.text(zh.serverSortName));
      await tester.pumpAndSettle();
      expect(ledger.sort, ServerSort.name);
      expect(ledger.mutations, 0);
      expect((await store.servers()).single.name, '用户自填名称');
    },
  );

  testWidgets(
    'billing choices and the open cycle picker follow locale without changing draft values',
    (tester) async {
      await mount(
        tester,
        ServerForm(controller: ledger, record: ledger.records.single),
      );
      final name = find.byKey(const ValueKey('field-name'));
      await reveal(tester, name);
      await tester.enterText(name, 'User draft 原样');
      final nameController = fieldController(tester, 'field-name');
      final formState = tester.state(find.byType(ServerForm));
      final billing = find.byKey(const ValueKey('field-billing'));
      await reveal(tester, billing);
      expect(
        find.descendant(of: billing, matching: find.text('Metered')),
        findsOneWidget,
      );
      await change(tester, 'zh');
      expect(
        find.descendant(of: billing, matching: find.text('按量')),
        findsOneWidget,
      );
      expect(
        tester.widget<AppSegmented<BillingKind>>(billing).value,
        BillingKind.prepaid,
      );
      await change(tester, 'en');
      final cycle = find.byKey(const ValueKey('field-cycle'));
      await reveal(tester, cycle);
      await tester.tap(cycle);
      await tester.pumpAndSettle();
      final sheetRoute = ModalRoute.of(
        tester.element(find.text(en.serverEveryMonths(3))),
      );
      expect(find.text(en.serverEveryMonths(3)), findsOneWidget);
      await change(tester, 'zh');
      expect(find.text(zh.serverEveryMonths(3)), findsOneWidget);
      expect(find.text(en.serverEveryMonths(3)), findsNothing);
      expect(
        ModalRoute.of(tester.element(find.text(zh.serverEveryMonths(3)))),
        same(sheetRoute),
      );
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(zh.serverEveryYear),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(zh.serverEveryMonths(3)));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: cycle,
          matching: find.text(zh.serverEveryMonths(3)),
        ),
        findsOneWidget,
      );
      expect(tester.state(find.byType(ServerForm)), same(formState));
      expect(nameController.text, 'User draft 原样');
      expect(ledger.mutations, 0);
      final unchanged = (await store.servers()).single;
      expect(unchanged.billing, BillingKind.prepaid);
      expect(unchanged.cycleMonths, 12);
      expect(unchanged.name, '用户自填名称');
    },
  );

  testWidgets(
    'quick connect marks generated targets and localizes open credential options',
    (tester) async {
      expect(
        await ledger.security.saveCredential(
          name: 'Synthetic password',
          kind: CredentialKind.password,
          defaultUsername: 'fixture',
          secret: 'SYNTHETIC-ONLY',
        ),
        isTrue,
      );
      await mount(
        tester,
        SshConnectPage(ledger: ledger, serviceFactory: (_) => ssh),
      );
      final host = find.byKey(const ValueKey('connect-host'));
      await reveal(tester, host);
      await tester.enterText(host, '192.0.2.20');
      final username = find.byKey(const ValueKey('connect-user'));
      await reveal(tester, username);
      await tester.enterText(username, 'fixture');
      final credentials = find.byKey(
        const ValueKey('connect-credential-null-null'),
      );
      await reveal(tester, credentials);
      await tester.tap(credentials);
      await tester.pumpAndSettle();
      final credential = ledger.security.credentials.single;
      final english =
          'Synthetic password · ${credentialKind(credential, l10n: en)}';
      expect(find.text(english), findsOneWidget);
      await change(tester, 'zh');
      final chinese =
          'Synthetic password · ${credentialKind(credential, l10n: zh)}';
      expect(find.text(chinese), findsOneWidget);
      expect(find.text(english), findsNothing);
      expect(ssh.connections, 0);
      await tester.tap(find.text(chinese));
      await tester.pumpAndSettle();
      final connect = find.byKey(const ValueKey('connect-start'));
      await reveal(tester, connect);
      await tester.tap(connect);
      await tester.pumpAndSettle();
      expect(ssh.target!.isTemporary, isTrue);
      expect(ssh.target!.serverId, isNull);
      expect(ssh.target!.host, '192.0.2.20');
      expect(ssh.target!.credentialId, credential.id);
      expect(find.text(zh.connectionTemporary), findsOneWidget);
      await change(tester, 'en');
      expect(find.text(en.connectionTemporary), findsOneWidget);
      expect(ssh.connections, 1);
      expect(ssh.authentications, 1);
      expect(ssh.writes, isEmpty);
      expect(ssh.powers, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    '320px 2x open Chinese cycle choices remain readable after English switch',
    (tester) async {
      locale.value = const Locale('zh');
      await mount(
        tester,
        ServerForm(controller: ledger, record: ledger.records.single),
        size: const Size(320, 844),
        scale: 2,
        reviewFont: true,
      );
      final cycle = find.byKey(const ValueKey('field-cycle'));
      await reveal(tester, cycle);
      await tester.tap(cycle);
      await tester.pumpAndSettle();
      await change(tester, 'en');
      final sheet = find.byType(BottomSheet);
      final scrolling = find.descendant(
        of: sheet,
        matching: find.byType(Scrollable),
      );
      for (final months in [1, 3, 6, 12, 24, 36]) {
        final label = months == 12
            ? en.serverEveryYear
            : en.serverEveryMonths(months);
        final option = find.descendant(of: sheet, matching: find.text(label));
        await tester.scrollUntilVisible(
          option,
          100,
          scrollable: scrolling.first,
        );
        await tester.pumpAndSettle();
        expect(option.hitTestable(), findsOneWidget, reason: label);
        final rect = tester.getRect(option);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(844));
        expect(
          tester.renderObject<RenderParagraph>(option).didExceedMaxLines,
          isFalse,
        );
        expect(tester.takeException(), isNull, reason: label);
      }
      await tester.tap(find.byKey(const ValueKey('app-sheet-close')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: cycle, matching: find.text(en.serverEveryYear)),
        findsOneWidget,
      );
      expect(ledger.mutations, 0);
      expect((await store.servers()).single.cycleMonths, 12);
    },
  );

  testWidgets(
    'open traffic period picker translates key-based labels without a save',
    (tester) async {
      await mount(
        tester,
        ServerForm(controller: ledger, record: ledger.records.single),
      );
      final period = find.byKey(const ValueKey('resource-traffic-period'));
      await reveal(tester, period);
      await tester.tap(period);
      await tester.pumpAndSettle();
      String every(AppLocalizations l10n, int months) =>
          l10n.resourceEveryPeriod(
            ServerResources.trafficPeriodsFor(l10n)[months]!.toLowerCase(),
          );
      for (final months in [1, 3, 12]) {
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(every(en, months)),
          ),
          findsOneWidget,
        );
      }
      await change(tester, 'zh');
      final sheet = find.byType(BottomSheet);
      for (final months in [1, 3, 12]) {
        expect(
          find.descendant(of: sheet, matching: find.text(every(zh, months))),
          findsOneWidget,
        );
        expect(find.text(every(en, months)), findsNothing);
      }
      expect(find.text(zh.notSet), findsWidgets);
      await tester.tap(
        find.descendant(of: sheet, matching: find.text(every(zh, 3))),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: period, matching: find.text(every(zh, 3))),
        findsOneWidget,
      );
      expect(ledger.mutations, 0);
      expect((await store.servers()).single.resources, isNull);
    },
  );

  testWidgets(
    '320px 2x traffic periods retain full labels and numeric drafts',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await mount(
          tester,
          ServerForm(controller: ledger, record: ledger.records.single),
          size: const Size(320, 844),
          scale: 2,
          reviewFont: true,
        );
        final capacity = find.byKey(const ValueKey('resource-trafficBytes'));
        final unit = find.byKey(const ValueKey('resource-unit-trafficBytes'));
        final period = find.byKey(const ValueKey('resource-traffic-period'));
        await reveal(tester, capacity);
        await tester.enterText(capacity, '12.50');
        final draft = fieldController(tester, 'resource-trafficBytes');
        final originalUnit = tester.widget<AppSegmented<int>>(unit).value;
        String every(AppLocalizations l10n, int months) =>
            l10n.resourceEveryPeriod(
              ServerResources.trafficPeriodsFor(l10n)[months]!.toLowerCase(),
            );
        final labels = {
          0: en.notSet,
          1: every(en, 1),
          3: every(en, 3),
          12: every(en, 12),
        };
        for (final entry in labels.entries) {
          await reveal(tester, period);
          await tester.tap(period);
          await tester.pumpAndSettle();
          for (final full in labels.values) {
            final row = find.descendant(
              of: find.byType(BottomSheet),
              matching: find.text(full),
            );
            expect(row, findsOneWidget);
          }
          final option = find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(entry.value),
          );
          await tester.ensureVisible(option);
          await tester.pumpAndSettle();
          expect(option.hitTestable(), findsOneWidget);
          await tester.tap(option);
          await tester.pumpAndSettle();
          final selected = find.descendant(
            of: period,
            matching: find.text(entry.value),
          );
          expect(selected, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(selected);
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(
            tester.getRect(selected).right,
            lessThanOrEqualTo(tester.getRect(period).right),
          );
          expect(tester.getRect(period).height, greaterThanOrEqualTo(48));
          expect(tester.getRect(period).right, lessThanOrEqualTo(320));
          expect(fieldController(tester, 'resource-trafficBytes'), same(draft));
          expect(draft.text, '12.50');
          expect(tester.widget<AppSegmented<int>>(unit).value, originalUnit);
          expect(ledger.mutations, 0);
          expect(tester.takeException(), isNull);
        }
        await change(tester, 'zh');
        expect(
          find.descendant(of: period, matching: find.text(every(zh, 12))),
          findsOneWidget,
        );
        expect(draft.text, '12.50');
        await change(tester, 'en');
        expect(
          find.descendant(of: period, matching: find.text(every(en, 12))),
          findsOneWidget,
        );
        expect((await store.servers()).single.resources, isNull);
        expect(ledger.mutations, 0);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'LedgerApp follows device languages only for saved system choice',
    (tester) async {
      await store.saveLanguagePreference(LocalePreference.system);
      tester.platformDispatcher.localesTestValue = [const Locale('en', 'GB')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      var opens = 0;
      await tester.pumpWidget(
        LedgerApp(
          openStore: () async {
            opens++;
            return store;
          },
          reminderPlatform: reminders,
        ),
      );
      await tester.pumpAndSettle();
      final current = tester
          .widget<HomeShell>(find.byType(HomeShell))
          .controller;
      final material = find.byType(MaterialApp);
      expect(tester.widget<MaterialApp>(material).locale, const Locale('en'));
      for (final (device, expected) in [
        (const Locale('zh', 'TW'), const Locale('zh')),
        (const Locale('en', 'US'), const Locale('en')),
        (const Locale('fr', 'FR'), const Locale('en')),
      ]) {
        tester.platformDispatcher.localesTestValue = [device];
        await tester.pumpAndSettle();
        expect(tester.widget<MaterialApp>(material).locale, expected);
        expect(
          tester.widget<HomeShell>(find.byType(HomeShell)).controller,
          same(current),
        );
        expect(opens, 1);
      }
      await current.setLanguage(LocalePreference.chinese);
      tester.platformDispatcher.localesTestValue = [const Locale('en')];
      await tester.pumpAndSettle();
      expect(tester.widget<MaterialApp>(material).locale, const Locale('zh'));
      await current.setLanguage(LocalePreference.english);
      tester.platformDispatcher.localesTestValue = [const Locale('zh')];
      await tester.pumpAndSettle();
      expect(tester.widget<MaterialApp>(material).locale, const Locale('en'));
      expect(
        tester.widget<HomeShell>(find.byType(HomeShell)).controller,
        same(current),
      );
      expect(opens, 1);
      expect(reminders.schedules, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
