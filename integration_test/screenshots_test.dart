// Scripted tour of the REAL app for the README / wiki screenshots and GIFs.
//
// Not a regression test: it needs the host-side orchestrator
// (`tool/make_screenshots.py`), which takes the pixel-real simulator
// screenshots / videos when this test asks for them over loopback HTTP.
// See docs/SCREENSHOTS.md.
//
// Order matters: the first-connection host-key dialog is part of terminal.gif,
// so that tour runs before anything else trusts the demo SSH server; the
// tours that change the ledger (add-server, renew) run last.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:vps_tell_you/app.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/providers/provider_directory.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/settings/reminder_planner.dart';
import 'package:vps_tell_you/settings/reminder_scheduler.dart';

import 'demo_ledger.dart';

const _lang = String.fromEnvironment('SHOT_LOCALE', defaultValue: 'zh');
const _theme = String.fromEnvironment('SHOT_THEME', defaultValue: 'light');
const _hostPort = int.fromEnvironment('SHOT_PORT', defaultValue: 0);
const _sshPort = int.fromEnvironment('SHOT_SSH_PORT', defaultValue: 22022);
const _only = String.fromEnvironment('SHOT_ONLY');
bool get zh => _lang == 'zh';

/// Picks the zh or en label of the language being captured.
String t(String zhText, String enText) => zh ? zhText : enText;

/// Notification permission is granted and scheduling only remembers ids:
/// the reminder screens render from the ledger, and no system dialog may
/// appear over a screenshot.
class _QuietReminders implements ReminderPlatform {
  @override
  bool get supported => true;
  @override
  int get capacity => 64;
  @override
  Future<ReminderPermission> permission() async => ReminderPermission.allowed;
  @override
  Future<void> requestPermission() async {}
  @override
  Future<String> timezone() async {
    tz_data.initializeTimeZones();
    return 'Asia/Shanghai';
  }

  final _pending = <int>{};
  @override
  Future<List<int>> pendingIds() async => _pending.toList();
  @override
  Future<void> cancel(int id) async => _pending.remove(id);
  @override
  Future<void> schedule(PlannedReminder reminder) async =>
      _pending.add(reminder.notificationId);
}

/// Asks the host orchestrator to act (screenshot, start/stop recording).
Future<void> host(String path) async {
  if (_hostPort == 0) return;
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:$_hostPort$path'),
    );
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode != 200) {
      throw StateError('host refused $path: ${response.statusCode}');
    }
  } finally {
    client.close(force: true);
  }
}

late String _ledgerPath;
final directory = ProviderDirectory.remote();
bool _sshReady = false;

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'screenshots'));
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    _ledgerPath = p.join(dir.path, 'ledger.sqlite3');
    final seeded = await openDemoLedger(_ledgerPath, zh: zh, theme: _theme);
    await seeded.close();
  });

  void tour(String name, Future<void> Function(WidgetTester) body) {
    if (_only.isNotEmpty && !_only.split(',').contains(name)) return;
    testWidgets(name, (tester) async {
      await tester.pumpWidget(
        LedgerApp(
          openStore: () => LedgerStore.open(
            factory: mobile.databaseFactory,
            path: _ledgerPath,
          ),
          reminderPlatform: _QuietReminders(),
          directory: directory,
        ),
      );
      await settle(tester, 1500);
      await waitForLogos(tester);
      await body(tester);
    });
  }

  // ---- GIF: SSH (first connection, trust the host key) --------------------
  tour('gif-terminal', (tester) async {
    await ensureSsh(tester);
    await record(tester, 'terminal', () async {
      await tap(tester, find.textContaining('hk-01'));
      await tap(tester, find.byKey(const ValueKey('server-quick-ssh')));
      await tap(
        tester,
        find.byKey(const ValueKey('connect-start')),
        wait: 2200,
      );
      tester.takeException(); // known: SecurityController notifies in initState
      await acceptHostKey(tester, slow: true);
      await settle(tester, 1800);
      await runCommand(tester, 'uptime');
      await runCommand(tester, 'df');
      // Ends on the default again: the scheme is process-wide until restart.
      for (final scheme in ['Dracula', 'GitHub Light', 'Tokyo Night']) {
        await tap(tester, find.byTooltip(t('终端菜单', 'Terminal Menu')));
        await tap(tester, find.text(t('配色与高亮', 'Colors & Highlighting')));
        await tap(tester, find.text(scheme), wait: 2200);
      }
    });
  });

  // ---- Screenshots --------------------------------------------------------
  tour('servers', (tester) async {
    await shot(tester, 'servers');
  });

  tour('servers-dark', (tester) async {
    await tab(tester, 'settings');
    await tap(tester, find.text(t('外观', 'Appearance')));
    await tap(
      tester,
      find.byKey(const ValueKey('appearance-dark')),
      wait: 1200,
    );
    await tab(tester, 'servers');
    await shot(tester, 'servers-dark');
    await tab(tester, 'settings');
    await tap(tester, find.text(t('外观', 'Appearance')));
    await tap(
      tester,
      find.byKey(const ValueKey('appearance-light')),
      wait: 1200,
    );
  });

  tour('detail', (tester) async {
    await tap(tester, find.textContaining('hk-01'));
    await shot(tester, 'detail');
  });

  tour('form', (tester) async {
    await tap(tester, find.byKey(const ValueKey('add-server')));
    await tap(tester, find.byKey(const ValueKey('form-provider')));
    await shot(tester, 'provider-picker');
    await typeText(tester, find.byType(EditableText).last, 'vul');
    await tap(tester, find.text('Vultr'));
    await typeText(tester, find.byKey(const ValueKey('field-name')), 'ams-lab');
    await typeText(
      tester,
      find.byKey(const ValueKey('field-region')),
      t('阿姆斯特丹', 'Amsterdam'),
    );
    await typeText(
      tester,
      find.byKey(const ValueKey('field-purpose')),
      t('实验环境', 'Lab'),
    );
    await typeText(tester, find.byKey(const ValueKey('field-os')), 'Debian 12');
    unfocus();
    await shot(tester, 'form');
  });

  tour('costs', (tester) async {
    await tab(tester, 'costs');
    await shot(tester, 'costs');
  });

  tour('calculator', (tester) async {
    await tap(tester, find.textContaining('la-ci'));
    await tap(tester, find.byKey(const ValueKey('server-valuation')));
    await tap(
      tester,
      find.byKey(const ValueKey('calculate-value')),
      wait: 1500,
    );
    await shot(tester, 'calculator');
  });

  tour('reminders', (tester) async {
    await tab(tester, 'settings');
    await tap(tester, find.text(t('通知权限', 'Notification Access')), wait: 2000);
    await shot(tester, 'reminders');
  });

  tour('tcp', (tester) async {
    await tab(tester, 'tools');
    await tap(tester, find.text(t('TCP 连接测试', 'TCP Connection Test')));
    await typeText(tester, find.byKey(const ValueKey('tcp-host')), '127.0.0.1');
    await typeText(tester, find.byKey(const ValueKey('tcp-port')), '$_sshPort');
    unfocus();
    await tap(tester, find.text(t('开始测试', 'Start Test')), wait: 2500);
    await shot(tester, 'tcp');
  });

  tour('pages', (tester) async {
    await tab(tester, 'settings');
    await shot(tester, 'settings');
    await tap(tester, find.byKey(const ValueKey('settings-providers')));
    await shot(tester, 'providers');
    await back(tester);
    await tap(tester, find.byKey(const ValueKey('settings-about')));
    await shot(tester, 'about');
  });

  tour('terminal', (tester) async {
    await ensureSsh(tester);
    await tap(tester, find.textContaining('hk-01'));
    await tap(tester, find.byKey(const ValueKey('server-quick-ssh')));
    await tap(tester, find.byKey(const ValueKey('connect-start')), wait: 2200);
    tester.takeException();
    await acceptHostKey(tester);
    await settle(tester, 2000);
    for (final id in ['uptime', 'df', 'free', 'ls']) {
      await runCommand(tester, id);
    }
    await shot(tester, 'terminal');
  });

  tour('sftp', (tester) async {
    await ensureSsh(tester);
    await tap(tester, find.textContaining('hk-01'));
    await tap(tester, find.byKey(const ValueKey('server-sftp')), wait: 2500);
    tester.takeException();
    await acceptHostKey(tester);
    await settle(tester, 2500);
    await shot(tester, 'sftp');
    await tap(tester, find.text('nginx.conf'));
    await tap(
      tester,
      find.byKey(const ValueKey('sftp-action-edit')),
      wait: 2000,
    );
    await shot(tester, 'sftp-editor');
  });

  // ---- GIFs that change the ledger (last) ---------------------------------
  tour('gif-add-server', (tester) async {
    await record(tester, 'add-server', () async {
      await tap(tester, find.byKey(const ValueKey('add-server')));
      await typeText(
        tester,
        find.byKey(const ValueKey('field-name')),
        'ams-lab',
      );
      unfocus();
      await settle(tester, 700);
      await tap(
        tester,
        find.byKey(const ValueKey('form-provider')),
        wait: 1200,
      );
      await typeText(tester, find.byType(EditableText).last, 'vul');
      await tap(tester, find.text('Vultr'), wait: 1200);
      await typeText(
        tester,
        find.byKey(const ValueKey('field-region')),
        t('阿姆斯特丹', 'Amsterdam'),
      );
      unfocus();
      await settle(tester, 800);
      await tap(tester, find.text(t('保存', 'Save')), wait: 2200);
      await back(tester, wait: 2200);
    });
  });

  tour('gif-renew', (tester) async {
    await record(tester, 'renew', () async {
      await tap(tester, find.textContaining('hk-01'), wait: 1500);
      await tap(
        tester,
        find.byKey(const ValueKey('server-quick-payment')),
        wait: 1800,
      );
      await tap(tester, find.byKey(const ValueKey('pay-confirm')), wait: 1200);
      await tap(tester, find.text(t('保存付款记录', 'Save Payment')), wait: 2500);
      // Back to the top of the page, where the renewed due date is.
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, 900),
        2500,
      );
      await settle(tester, 2800);
    });
  });
}

// ---- helpers ----------------------------------------------------------------

/// Real-time wait that keeps frames flowing (animations play at human speed).
Future<void> settle(WidgetTester tester, int millis) async {
  final end = DateTime.now().add(Duration(milliseconds: millis));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Waits for the provider directory (and its logos) to be downloaded.
Future<void> waitForLogos(WidgetTester tester) async {
  const ids = [
    'bandwagonhost',
    'aliyun',
    'racknerd',
    'hetzner',
    'dmit',
    'vultr',
  ];
  for (var i = 0; i < 240; i++) {
    if (!directory.checking &&
        ids.every((id) => directory.logoFor(id) != null)) {
      break;
    }
    await settle(tester, 500);
  }
  expect(directory.logoFor('vultr'), isNotNull, reason: 'logos not cached');
  await settle(tester, 1200);
}

/// Pixel-real screenshot taken by the host with `simctl io screenshot`.
Future<void> shot(WidgetTester tester, String name, {int wait = 800}) async {
  await settle(tester, wait);
  await host('/shot?name=$name');
}

/// Records everything [body] does as `name.mp4` (host: `simctl io recordVideo`).
Future<void> record(
  WidgetTester tester,
  String name,
  Future<void> Function() body,
) async {
  await host('/rec/start?name=$name');
  try {
    await settle(tester, 900);
    await body();
    await settle(tester, 900);
  } finally {
    await host('/rec/stop');
  }
}

Future<void> back(WidgetTester tester, {int wait = 900}) => tap(
  tester,
  find.byKey(const ValueKey('app-nav-back')),
  wait: wait,
  ensure: false,
);

Future<void> tap(
  WidgetTester tester,
  Finder finder, {
  int wait = 900,
  bool ensure = true,
}) async {
  if (finder.evaluate().isEmpty) {
    // Lazily built list rows: scroll the page until the row exists.
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  expect(finder, findsAtLeastNWidgets(1), reason: 'missing $finder');
  if (ensure) {
    await tester.ensureVisible(finder.first);
    await settle(tester, 300);
  }
  await tester.tap(finder.first);
  await settle(tester, wait);
}

void unfocus() => FocusManager.instance.primaryFocus?.unfocus();

Future<void> tab(WidgetTester tester, String which) async {
  final labels = {
    'servers': t('服务器', 'Servers'),
    'costs': t('费用', 'Costs'),
    'tools': t('工具', 'Tools'),
    'settings': t('设置', 'Settings'),
  };
  await tap(tester, find.text(labels[which]!).last);
}

/// Types like a person: the field grows one character at a time.
Future<void> typeText(WidgetTester tester, Finder field, String text) async {
  expect(field, findsAtLeastNWidgets(1), reason: 'missing $field');
  for (var i = 1; i <= text.length; i++) {
    await tester.enterText(field.first, text.substring(0, i));
    await settle(tester, 90);
  }
  await settle(tester, 400);
}

LedgerController _ledger(WidgetTester tester) =>
    tester.widget<HomeShell>(find.byType(HomeShell)).controller;

/// Saves a demo password credential and points hk-01's SSH settings at the
/// loopback demo server (tool/demo_ssh_server.py). Secrets live in the
/// simulator keychain only; nothing here is a real credential.
Future<void> ensureSsh(WidgetTester tester) async {
  final ledger = _ledger(tester);
  final security = ledger.security;
  // A cold-started detail page only knows the SSH settings once the security
  // store has been read (opening any connection page does that).
  await security.reload();
  if (_sshReady) return;
  final saved = await security.saveCredential(
    name: t('演示密码', 'Demo password'),
    kind: CredentialKind.password,
    defaultUsername: 'demo',
    secret: 'demo-password',
  );
  expect(saved, isTrue, reason: security.error);
  final server = ledger.active.firstWhere((s) => s.name == 'hk-01');
  final ok = await security.saveSshConfiguration(
    SshConfiguration(
      serverId: server.id,
      host: '127.0.0.1',
      port: _sshPort,
      username: 'demo',
      credentialId: security.credentials.single.id,
    ),
  );
  expect(ok, isTrue, reason: security.error);
  _sshReady = true;
}

/// Ticks "I verified the host identity" and confirms, when asked.
Future<void> acceptHostKey(WidgetTester tester, {bool slow = false}) async {
  final check = find.byKey(const ValueKey('host-verified-check'));
  if (check.evaluate().isEmpty) return;
  await settle(tester, slow ? 2200 : 800);
  await tap(tester, check, wait: slow ? 1500 : 900);
  await tap(tester, find.byKey(const ValueKey('host-verified-confirm')));
}

/// Opens the Commands drawer, picks a built-in command and sends it with Enter.
Future<void> runCommand(WidgetTester tester, String id) async {
  await tap(tester, find.text(t('命令', 'Commands')).first, wait: 1200);
  await tap(tester, find.byKey(ValueKey('builtin-$id')), wait: 800);
  await tap(
    tester,
    find.byKey(const ValueKey('terminal-send-execute')),
    wait: 1200,
  );
  // Sending refocuses the terminal and raises the software keyboard.
  final hide = find.byTooltip(t('收起键盘', 'Hide Keyboard'));
  if (hide.evaluate().isNotEmpty) await tap(tester, hide, wait: 900);
}
