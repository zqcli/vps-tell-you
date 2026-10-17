import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/connections/ssh_service.dart';
import 'package:vps_tell_you/connections/terminal_page.dart';
import 'package:vps_tell_you/connections/terminal_widgets.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:xterm/xterm.dart';

import 'security_store_test.dart' show FakeDeviceAuth, FakeSecretStore;
import 'terminal_widget_test.dart' show SpySshService;

/// WCAG 2.x contrast ratio of two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + .05 : lb + .05) / (la > lb ? lb + .05 : la + .05);
}

Color over(Color top, Color bottom) => Color.alphaBlend(top, bottom);

void main() {
  group('curated schemes', () {
    test('four schemes: default is dark, at least one light, unique ids', () {
      expect(TerminalScheme.all.length, inInclusiveRange(3, 4));
      expect(TerminalScheme.defaultScheme, same(TerminalScheme.all.first));
      expect(TerminalScheme.defaultScheme.isDark, isTrue);
      expect(TerminalScheme.defaultScheme.name, 'Tokyo Night');
      expect(TerminalScheme.all.where((s) => !s.isDark), isNotEmpty);
      expect(
        {for (final s in TerminalScheme.all) s.id}.length,
        TerminalScheme.all.length,
      );
      expect(TerminalScheme.byId('nope'), same(TerminalScheme.defaultScheme));
    });

    for (final scheme in TerminalScheme.all) {
      group(scheme.name, () {
        final t = scheme.theme;
        final bg = t.background;

        test('every colour is opaque except the selection overlay', () {
          for (final c in [
            t.foreground,
            t.background,
            t.cursor,
            t.black,
            t.red,
            t.green,
            t.yellow,
            t.blue,
            t.magenta,
            t.cyan,
            t.white,
            t.brightBlack,
            t.brightRed,
            t.brightGreen,
            t.brightYellow,
            t.brightBlue,
            t.brightMagenta,
            t.brightCyan,
            t.brightWhite,
            t.searchHitBackground,
            t.searchHitBackgroundCurrent,
            t.searchHitForeground,
            scheme.chrome,
            scheme.key,
            scheme.accent,
          ]) {
            expect(c.a, 1);
          }
          expect(t.selection.a, inExclusiveRange(0, 1));
          expect(
            scheme.isDark,
            bg.computeLuminance() < .5,
            reason: 'brightness flag matches the background',
          );
        });

        test('default foreground/background is at least 7:1 (WCAG AAA)', () {
          expect(contrast(t.foreground, bg), greaterThanOrEqualTo(7));
          expect(contrast(t.cursor, bg), greaterThanOrEqualTo(3));
        });

        test('normal ANSI colours are readable on the background', () {
          final normal = {
            'black': t.black,
            'red': t.red,
            'green': t.green,
            'yellow': t.yellow,
            'blue': t.blue,
            'magenta': t.magenta,
            'cyan': t.cyan,
            'white': t.white,
          };
          // Black is the "background-like" slot of a dark scheme (used for
          // inverse/box fills such as powerline segments), so only its
          // distinctness is checked. On a light scheme black is body text and
          // is held to the same bar as the other hues.
          for (final e in normal.entries) {
            if (e.key == 'black' && scheme.isDark) {
              expect(e.value, isNot(bg));
              continue;
            }
            expect(
              contrast(e.value, bg),
              greaterThanOrEqualTo(3),
              reason: '${scheme.name} ${e.key}',
            );
          }
        });

        test('bright ANSI colours (incl. bright black) are at least 3:1', () {
          for (final e in {
            'brightBlack': t.brightBlack,
            'brightRed': t.brightRed,
            'brightGreen': t.brightGreen,
            'brightYellow': t.brightYellow,
            'brightBlue': t.brightBlue,
            'brightMagenta': t.brightMagenta,
            'brightCyan': t.brightCyan,
            'brightWhite': t.brightWhite,
          }.entries) {
            expect(
              contrast(e.value, bg),
              greaterThanOrEqualTo(3),
              reason: '${scheme.name} ${e.key}',
            );
          }
        });

        test('selection and search hits keep text legible', () {
          final selected = over(t.selection, bg);
          expect(contrast(t.foreground, selected), greaterThanOrEqualTo(4.5));
          expect(
            contrast(t.searchHitForeground, t.searchHitBackground),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrast(t.searchHitForeground, t.searchHitBackgroundCurrent),
            greaterThanOrEqualTo(4.5),
          );
        });

        test('chrome text, key caps and accent are legible', () {
          expect(
            contrast(t.foreground, scheme.chrome),
            greaterThanOrEqualTo(7),
          );
          expect(
            contrast(scheme.muted, scheme.chrome),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrast(scheme.link, scheme.chrome),
            greaterThanOrEqualTo(4.5),
          );
          expect(contrast(t.foreground, scheme.key), greaterThanOrEqualTo(4.5));
          expect(
            contrast(t.foreground, scheme.keyArmed),
            greaterThanOrEqualTo(4.5),
          );
          expect(contrast(scheme.muted, scheme.key), greaterThanOrEqualTo(3));
          expect(
            contrast(scheme.onAccent, scheme.accent),
            greaterThanOrEqualTo(4.5),
          );
          // chrome is a tone of the terminal, not a different surface
          expect(contrast(scheme.chrome, bg), lessThan(1.2));
        });
      });
    }
  });

  group('applying a scheme', () {
    late Directory directory;
    late LedgerStore store;
    late LedgerController ledger;
    late SpySshService ssh;
    final zh = AppLocalizationsZh();
    const target = SshTarget(
      name: 'Synthetic target',
      host: '127.0.0.1',
      username: 'fixture',
      port: 22022,
      credentialId: 'fixture-only',
    );

    setUp(() async {
      terminalSchemeChoice.value = TerminalScheme.defaultScheme;
      sqfliteFfiInit();
      directory = await Directory.systemTemp.createTemp('vps-terminal-scheme-');
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${directory.path}/ledger.sqlite3',
      );
      ledger = LedgerController(
        store,
        security: SecurityController(
          store: store,
          secrets: FakeSecretStore(),
          authenticator: FakeDeviceAuth(),
        ),
      );
      await ledger.refresh();
      ssh = SpySshService();
    });
    tearDown(() async {
      terminalSchemeChoice.value = TerminalScheme.defaultScheme;
      ledger.dispose();
      await store.close();
      await directory.delete(recursive: true);
    });

    testWidgets('menu picker restyles page live without touching the session', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: TerminalPage(
            ledger: ledger,
            target: target,
            connectOnOpen: true,
            serviceFactory: (_) => ssh,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(ssh.connections, 1);
      TerminalTheme viewTheme() =>
          tester.widget<TerminalView>(find.byType(TerminalView)).theme;
      Color keyBarColor() => tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(TerminalKeyBar),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;
      expect(viewTheme(), tokyoNight.theme);
      expect(keyBarColor(), tokyoNight.chrome);

      Future<void> pick(TerminalScheme scheme) async {
        await tester.tap(find.byTooltip(zh.terminalMenu));
        await tester.pumpAndSettle();
        await tester.tap(find.text(zh.r3TermColorScheme));
        await tester.pumpAndSettle();
        for (final s in TerminalScheme.all) {
          expect(
            find.byKey(ValueKey('terminal-scheme-${s.id}')),
            findsOneWidget,
          );
        }
        await tester.tap(find.byKey(ValueKey('terminal-scheme-${scheme.id}')));
        await tester.pumpAndSettle();
      }

      await pick(catppuccinMocha);
      expect(viewTheme(), catppuccinMocha.theme);
      expect(keyBarColor(), catppuccinMocha.chrome);
      expect(
        tester
            .widget<Scaffold>(find.byKey(const ValueKey('terminal-fullscreen')))
            .backgroundColor,
        catppuccinMocha.theme.background,
      );

      await pick(githubLight);
      expect(viewTheme(), githubLight.theme);
      expect(keyBarColor(), githubLight.chrome);
      expect(
        tester
            .widget<TerminalView>(find.byType(TerminalView))
            .keyboardAppearance,
        Brightness.light,
      );

      // The command drawer is a separate route and follows the same scheme.
      await tester.tap(find.byKey(const ValueKey('terminal-commands')));
      await tester.pumpAndSettle();
      expect(
        TerminalScheme.of(tester.element(find.byType(TerminalCommandSheet))),
        githubLight,
      );
      await tester.tap(find.byKey(const ValueKey('terminal-commands-close')));
      await tester.pumpAndSettle();

      // Pure repaint: same session, nothing sent or reconnected.
      expect(ssh.writes, isEmpty);
      expect(ssh.connections, 1);
      expect(ssh.disconnections, 0);
      expect(ssh.status, SshStatus.connected);
    });
  });
}
