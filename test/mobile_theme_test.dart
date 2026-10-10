import 'support/provider_fixture.dart';

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xterm/xterm.dart';
import 'package:vps_tell_you/cloud/cloud_controller.dart';
import 'package:vps_tell_you/cloud/cloud_models.dart';
import 'package:vps_tell_you/cloud/cloud_pages.dart';
import 'package:vps_tell_you/cloud/cloud_widgets.dart';
import 'package:vps_tell_you/connections/ssh_service.dart';
import 'package:vps_tell_you/connections/terminal_page.dart';
import 'package:vps_tell_you/connections/terminal_widgets.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/finance/finance_page.dart';
import 'package:vps_tell_you/finance/payment_pages.dart';
import 'package:vps_tell_you/security/host_trust_pages.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/security/security_pages.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_list.dart';

import 'security_store_test.dart' show FakeDeviceAuth, FakeSecretStore;
import 'terminal_widget_test.dart' show SpySshService;

// WCAG relative luminance, independently computed rather than inferred from a
// theme's brightness flag. All tested roles are opaque rendered colors.
double _contrast(Color a, Color b) {
  double luminance(Color color) {
    double linear(double channel) => channel <= .04045
        ? channel / 12.92
        : math.pow((channel + .055) / 1.055, 2.4).toDouble();
    return .2126 * linear(color.r) +
        .7152 * linear(color.g) +
        .0722 * linear(color.b);
  }

  final first = luminance(a), second = luminance(b);
  return (math.max(first, second) + .05) / (math.min(first, second) + .05);
}

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  required Brightness brightness,
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

Widget _opener(Widget Function() page) => Builder(
  builder: (context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => page()),
        ),
        child: const Text('Open synthetic page'),
      ),
    ),
  ),
);

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 50,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _scanPage(WidgetTester tester, String page) async {
  expect(tester.takeException(), isNull, reason: '$page at top');
  // The vertical page scroller (a horizontal chip row may come first).
  final finder = find
      .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
      .first;
  final scrollable = tester.state<ScrollableState>(finder);
  // Build every lazy section, including lower forms and warning controls.
  while (scrollable.position.extentAfter > 0) {
    final before = scrollable.position.pixels;
    await tester.drag(finder, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '$page while scrolling');
    if (scrollable.position.pixels <= before) {
      // A large title snaps back when only its own collapse distance (less
      // than half of the bar) is left; there is no further content then.
      if (scrollable.position.extentAfter <= 52) break;
      fail('$page could not reach its remaining content');
    }
  }
}

class _SyntheticAdapter implements CloudAdapter {
  @override
  Future<CloudSnapshot> read({required CloudCancellation cancellation}) async {
    final at = DateTime.utc(2026, 10, 6, 8);
    return CloudSnapshot(
      provider: CloudProvider.solusVm2,
      completedAt: at,
      remoteAccountId: 7,
      instances: [
        CloudInstance(
          observedAt: at,
          projectId: 11,
          serverId: 101,
          name: 'Synthetic cloud server',
          ipv4: '192.0.2.101',
          hostname: 'fixture-101.example',
          vcpu: 2,
          ramBytes: 2147483648,
          diskBytes: 32212254720,
          trafficBytes: 1099511627776,
          power: CloudPower.unknown,
        ),
      ],
    );
  }
}

// Tiny deterministic reference: no dates, real names, network, platform fonts,
// animations or private data. Tests retain Flutter's bundled test font.
class _ThemeSample extends StatelessWidget {
  const _ThemeSample();
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: const ValueKey('theme-sample'),
    child: ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SizedBox(
        width: 350,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LedgerCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Synthetic VPS',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const InfoNote('Local ledger'),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    LedgerBadge('Cached'),
                    LedgerBadge('Due soon', warning: true),
                    LedgerBadge('Overdue', danger: true),
                  ],
                ),
                const CloudNotice('Synthetic observation'),
                const CloudNotice('Synthetic warning', error: true),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Alias',
                    hintText: 'Example',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _noop, child: const Text('Continue')),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _noop, child: const Text('Cancel')),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void _noop() {}

void main() {
  for (final brightness in Brightness.values) {
    final mode = brightness.name;
    test(
      '$mode normal text, semantic containers and controls meet contrast',
      () {
        final theme = appTheme(brightness: brightness);
        final colors = theme.colorScheme;
        final textPairs = <String, (Color, Color)>{
          'surface text': (colors.onSurface, colors.surface),
          'surface metadata': (colors.onSurfaceVariant, colors.surface),
          'canvas text': (colors.onSurface, theme.scaffoldBackgroundColor),
          'canvas metadata': (
            colors.onSurfaceVariant,
            theme.scaffoldBackgroundColor,
          ),
          'primary action': (colors.onPrimary, colors.primary),
          'primary notice': (
            colors.onPrimaryContainer,
            colors.primaryContainer,
          ),
          'primary text on canvas': (
            colors.primary,
            theme.scaffoldBackgroundColor,
          ),
          'warning': (colors.onTertiaryContainer, colors.tertiaryContainer),
          'error action': (colors.onError, colors.error),
          'error badge': (colors.onErrorContainer, colors.errorContainer),
          'neutral badge': (
            colors.onSurfaceVariant,
            colors.surfaceContainerLow,
          ),
          'danger text': (colors.error, colors.surface),
        };
        for (final pair in textPairs.entries) {
          expect(
            _contrast(pair.value.$1, pair.value.$2),
            greaterThanOrEqualTo(4.5),
            reason: '$mode ${pair.key}',
          );
        }
        // Fields are borderless inline controls and outlined buttons render
        // as tonal buttons: there is no border to contrast, so the tonal
        // label must be legible on its fill instead.
        expect(
          theme.inputDecorationTheme.enabledBorder,
          same(InputBorder.none),
        );
        final tonal = theme.outlinedButtonTheme.style!;
        expect(tonal.side!.resolve({}), BorderSide.none);
        expect(
          _contrast(
            tonal.foregroundColor!.resolve({})!,
            tonal.backgroundColor!.resolve({})!,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          colors.surface.computeLuminance(),
          brightness == Brightness.dark ? lessThan(.03) : greaterThan(.9),
        );
      },
    );

    testWidgets('$mode representative component golden and paired roles', (
      tester,
    ) async {
      await _mount(
        tester,
        const Scaffold(body: Center(child: _ThemeSample())),
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      final card = find
          .descendant(
            of: find.byType(LedgerCard),
            matching: find.byType(Material),
          )
          .first;
      final colors = appTheme(brightness: brightness).colorScheme;
      expect(tester.widget<Material>(card).color, colors.surface);
      expect(
        tester.widget<Text>(find.text('Synthetic observation')).style!.color,
        colors.onPrimaryContainer,
      );
      expect(
        tester.widget<Text>(find.text('Synthetic warning')).style!.color,
        colors.onTertiaryContainer,
      );
      expect(
        tester.widget<Text>(find.text('Overdue')).style!.color,
        colors.onErrorContainer,
      );
      await expectLater(
        find.byKey(const ValueKey('theme-sample')),
        matchesGoldenFile('goldens/mobile_theme_$mode.png'),
      );
    });
  }

  group('real mobile pages with synthetic local records', () {
    late Directory directory;
    late LedgerStore store;
    late LedgerController ledger;
    late FakeSecretStore secrets;
    setUp(() async {
      sqfliteFfiInit();
      directory = await Directory.systemTemp.createTemp('vps-mobile-theme-');
      DateTime clock() => DateTime(2026, 10, 6, 8);
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${directory.path}/ledger.sqlite3',
        clock: clock,
      );
      await addTestProvider(store);
      secrets = FakeSecretStore();
      ledger = LedgerController(
        store,
        clock: clock,
        security: SecurityController(
          store: store,
          secrets: secrets,
          authenticator: FakeDeviceAuth(),
        ),
        cloud: CloudController(
          store: store,
          secrets: secrets,
          adapterFactory: (_, _, _) => _SyntheticAdapter(),
        ),
      );
      await store.loadDemo();
      await ledger.refresh();
      await ledger.security.initialize();
      expect(
        await ledger.security.saveCredential(
          name: 'Synthetic credential',
          kind: CredentialKind.password,
          defaultUsername: 'fixture',
          secret: 'SYNTHETIC_TEST_ONLY',
        ),
        isTrue,
      );
      final verified = (await ledger.cloud.verifyConnection(
        businessProvider: testProvider,
        provider: CloudProvider.solusVm2,
        endpoint: 'https://panel.example',
        credentials: SolusVm2Credentials('SYNTHETIC_TEST_ONLY'),
      ))!;
      expect(
        await ledger.cloud.saveAccount(
          verified,
          alias: 'Synthetic cloud account',
          selectedInstanceKeys: {
            verified.keyFor(verified.snapshot.instances.single),
          },
        ),
        isTrue,
      );
      await ledger.refresh();
    });
    tearDown(() async {
      ledger.dispose();
      await store.close();
      await directory.delete(recursive: true);
    });

    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '${brightness.name} 390px ${scale}x: every real page scrolls without overflow',
          (tester) async {
            final pages = <String, Widget Function()>{
              'terminal': () => TerminalPage(
                ledger: ledger,
                target: const SshTarget(
                  name: 'Synthetic terminal',
                  host: '192.0.2.1',
                  username: 'fixture',
                  credentialId: 'synthetic',
                ),
                serviceFactory: (_) => SpySshService(),
              ),
              'server list': () =>
                  Scaffold(body: ServerList(controller: ledger)),
              'finance': () => Scaffold(body: FinancePage(controller: ledger)),
              'finance details': () => FinanceDetailPage(
                controller: ledger,
                metric: FinanceMetric.monthly,
              ),
              'renewals': () => RenewalsPage(controller: ledger),
              'payments': () => PaymentListPage(controller: ledger),
              'payment form': () =>
                  PaymentForm(controller: ledger, server: ledger.active.first),
              'security': () => SecurityPage(ledger: ledger),
              'credential form': () =>
                  CredentialForm(ledger: ledger, kind: CredentialKind.password),
              'host trust': () => HostTrustPage(ledger: ledger),
              'host trust form': () => HostTrustForm(ledger: ledger),
              'cloud accounts': () => CloudAccountsPage(ledger: ledger),
              'cloud templates': () => CloudTemplatesPage(
                businessProvider: testProvider,
                ledger: ledger,
              ),
              'SolusVM 1 authorization': () => CloudAuthorizationPage(
                businessProvider: testProvider,
                ledger: ledger,
                provider: CloudProvider.solusVm1,
              ),
              'SolusVM 2 authorization': () => CloudAuthorizationPage(
                businessProvider: testProvider,
                ledger: ledger,
                provider: CloudProvider.solusVm2,
              ),
              'cloud account details': () => CloudAccountDetailsPage(
                ledger: ledger,
                accountId: ledger.cloud.accounts.single.id,
              ),
            };
            for (final page in pages.entries) {
              await _mount(
                tester,
                page.value(),
                brightness: brightness,
                scale: scale,
              );
              if (page.key == 'terminal') {
                final terminal = tester.widget<TerminalView>(
                  find.byType(TerminalView),
                );
                expect(terminal.theme, mobileTerminalTheme);
                expect(
                  terminal.theme.background.computeLuminance(),
                  lessThan(.1),
                );
                expect(
                  _contrast(
                    terminal.theme.foreground,
                    terminal.theme.background,
                  ),
                  greaterThanOrEqualTo(4.5),
                );
                expect(terminal.readOnly, isTrue);
              }
              if (page.key == 'server list') {
                final p = appTheme(brightness: brightness)
                    .extension<AppPalette>()!;
                final chips = tester.widgetList<AppChip>(find.byType(AppChip));
                expect(chips, isNotEmpty);
                for (final chip in chips) {
                  // Selected: inverted fill; others sit on the surface (the
                  // outlined filter chip on the page background).
                  final (fg, bg) = chip.selected
                      ? (p.surface, p.text)
                      : (chip.outlined ? (p.text2, p.bg) : (p.text, p.surface));
                  expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
                }
              }
              await _scanPage(tester, page.key);
            }
            await tester.pumpWidget(const SizedBox());
          },
        );
      }

      testWidgets(
        '${brightness.name} cloud Back clears keyboard and unsaved authorization on repeat',
        (tester) async {
          final accountCount = ledger.cloud.accounts.length;
          final writes = secrets.writes;
          await _mount(
            tester,
            _opener(
              () => CloudAuthorizationPage(
                businessProvider: testProvider,
                ledger: ledger,
                provider: CloudProvider.solusVm2,
              ),
            ),
            brightness: brightness,
            scale: 2,
          );
          for (var attempt = 0; attempt < 2; attempt++) {
            await tester.tap(find.text('Open synthetic page'));
            await tester.pumpAndSettle();
            final field = find.byKey(const ValueKey('cloud-token'));
            await _reveal(tester, field);
            expect(
              tester
                  .widget<EditableText>(
                    find.descendant(
                      of: field,
                      matching: find.byType(EditableText),
                    ),
                  )
                  .controller
                  .text,
              isEmpty,
            );
            await tester.enterText(field, 'UNSAVED_SYNTHETIC_TOKEN');
            expect(tester.testTextInput.isVisible, isTrue);
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.pageBack();
            await tester.pumpAndSettle();
            tester.view.resetViewInsets();
            await tester.pumpAndSettle();
            expect(find.byType(CloudAuthorizationPage), findsNothing);
            expect(tester.testTextInput.isVisible, isFalse);
            expect(
              FocusManager.instance.primaryFocus?.context?.widget,
              isNot(isA<EditableText>()),
            );
            expect(ledger.cloud.accounts.length, accountCount);
            expect(secrets.writes, writes);
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        },
      );

      testWidgets(
        '${brightness.name} payment Cancel dismisses keyboard and never writes',
        (tester) async {
          await _mount(
            tester,
            _opener(() => PaymentForm(controller: ledger)),
            brightness: brightness,
            scale: 2,
          );
          for (var attempt = 0; attempt < 2; attempt++) {
            await tester.tap(find.text('Open synthetic page'));
            await tester.pumpAndSettle();
            final field = find.byKey(const ValueKey('pay-account'));
            await _reveal(tester, field);
            expect(
              tester
                  .widget<EditableText>(
                    find.descendant(
                      of: field,
                      matching: find.byType(EditableText),
                    ),
                  )
                  .controller
                  .text,
              isEmpty,
            );
            await tester.enterText(field, 'Unsaved synthetic bill');
            expect(tester.testTextInput.isVisible, isTrue);
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await tester.pumpAndSettle();
            await tester.tap(find.text('取消'));
            await tester.pumpAndSettle();
            tester.view.resetViewInsets();
            await tester.pumpAndSettle();
            expect(find.byType(PaymentForm), findsNothing);
            expect(tester.testTextInput.isVisible, isFalse);
            expect(ledger.payments, isEmpty);
            expect(await store.payments(), isEmpty);
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  });
}
