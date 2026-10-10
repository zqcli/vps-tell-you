import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';

/// A page showing every design-system component, used for layout checks.
class Gallery extends StatefulWidget {
  const Gallery({super.key});
  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  String segment = 'a';
  int stepper = 2;
  bool on = true;
  int chip = 0;
  final text = TextEditingController(text: 'HK-01');
  String? last;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Servers and very long English navigation title',
    subtitle: '6 servers · stored only on this device',
    actions: [
      AppNavButton.icon(Icons.business_outlined, onPressed: () {}),
      AppNavButton.icon(Icons.add, onPressed: () {}, tooltip: 'Add'),
    ],
    onRefresh: () async {},
    children: [
      AppSearchField(placeholder: 'Name, address, provider or region'),
      AppChipRow(
        children: [
          AppChip(
            label: 'All',
            count: 6,
            selected: chip == 0,
            onTap: () => setState(() => chip = 0),
          ),
          AppChip(
            label: 'Favourites',
            count: 2,
            selected: chip == 1,
            onTap: () => setState(() => chip = 1),
          ),
          AppChip(
            label: 'Renewal due soon',
            count: 3,
            selected: chip == 2,
            onTap: () => setState(() => chip = 2),
          ),
          AppChip(
            label: 'Filter',
            icon: Icons.tune_rounded,
            outlined: true,
            onTap: () {},
          ),
        ],
      ),
      AppStatGrid(
        children: [
          AppStatTile(value: '1', label: 'Expired', tone: AppTone.red),
          AppStatTile(value: '2', label: 'Due in 30 days', tone: AppTone.amber),
          AppStatTile(
            value: '¥1,184.50',
            label: 'Monthly reference',
            compactValue: true,
          ),
        ],
      ),
      AppSection(
        header: 'All servers',
        headerAction: AppLinkButton(label: 'Edit', onPressed: () {}),
        footer:
            'Only the name is required. Everything else can be completed '
            'later and is stored only on this device.',
        children: [
          AppRow(
            leading: const ProviderAvatar(name: 'DigitalOcean', starred: true),
            title: 'US-01 API service for the production cluster',
            subtitle: 'DigitalOcean · United States of America',
            trailing: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\$12.00/mo'),
                StatusPill('Expired 12 days ago', tone: AppTone.red, dot: true),
              ],
            ),
            onTap: () => setState(() => last = 'row'),
          ),
          const AppRow(
            icon: Icons.folder_outlined,
            iconColor: AppTints.orange,
            title: 'Groups and a very long English setting title',
            subtitle: 'Organise servers by environment',
            value: 'Production',
            chevron: true,
          ),
          const AppRow(title: 'Archive', destructive: true),
          const AppRow(title: 'Add server', center: true),
          const AppRow(title: 'Disabled', enabled: false, chevron: true),
          AppSwitchRow(
            icon: Icons.notifications_none,
            iconColor: AppTints.red,
            title: 'Expiry notifications',
            subtitle: 'Remind before renewal',
            value: on,
            onChanged: (v) => setState(() => on = v),
          ),
        ],
      ),
      AppSection(
        header: 'Basics',
        children: [
          AppFormRow(
            label: 'Name',
            required: true,
            child: AppTextField(controller: text, hint: 'e.g. HK-01'),
          ),
          const AppFormRow.pick(
            label: 'Provider',
            placeholder: 'Unspecified',
            onTap: null,
          ),
          AppFormRow(
            label: 'Billing cycle and a long label',
            errorText: 'Required',
            child: AppSegmented<String>(
              compact: true,
              options: const {'a': 'GiB', 'b': 'TiB'},
              value: segment,
              onChanged: (v) => setState(() => segment = v),
            ),
          ),
          AppFormRow(
            label: 'vCPU',
            child: AppStepper(
              value: stepper,
              min: 1,
              max: 8,
              onChanged: (v) => setState(() => stepper = v),
              decrementKey: const ValueKey('dec'),
              incrementKey: const ValueKey('inc'),
            ),
          ),
          AppFormRow(
            label: 'Notes',
            stacked: true,
            child: AppTextField(
              hint: 'Notes',
              maxLines: 3,
              textAlign: TextAlign.start,
            ),
          ),
          const AppKeyValueRow(label: 'Hostname', value: 'hk01.example.com'),
          const AppKeyValueRow(
            label: 'Address',
            value: '192.0.2.18',
            mono: true,
          ),
          const AppKeyValueRow(label: 'Region', value: ''),
        ],
      ),
      const SizedBox(height: 16),
      AppSegmented<String>(
        options: const {
          'a': 'Provider',
          'b': 'Group',
          'c': 'Billing cycle',
          'd': 'Region',
        },
        value: segment,
        onChanged: (v) => setState(() => segment = v),
      ),
      AppQuickActionRow(
        children: [
          AppQuickAction(
            icon: Icons.terminal,
            label: 'SSH connect',
            onTap: () {},
          ),
          AppQuickAction(
            icon: Icons.monitor_heart_outlined,
            label: 'TCP test',
            onTap: () {},
          ),
          AppQuickAction(
            icon: Icons.credit_card,
            label: 'Record payment',
            dimmed: true,
            onTap: () {},
          ),
          AppQuickAction(
            icon: Icons.power_settings_new,
            label: 'Power',
            tone: AppTone.red,
            onTap: () {},
          ),
        ],
      ),
      const SizedBox(height: 14),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '\$49.99',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: StatusPill(
                    '7 days left',
                    tone: AppTone.amber,
                    dot: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const AppProgressBar(value: .92, tone: AppTone.amber),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Payments · 1',
                    kind: AppButtonKind.tonal,
                    compact: true,
                    icon: Icons.receipt_long_outlined,
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: 'Value calculator',
                    kind: AppButtonKind.tonal,
                    compact: true,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      AppBanner(
        tone: AppTone.amber,
        icon: Icons.warning_amber_rounded,
        text: 'Two servers have no exchange rate and are excluded from totals.',
        onTap: () {},
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            StatusPill('Neutral'),
            StatusPill('Blue', tone: AppTone.blue),
            StatusPill('Verified', tone: AppTone.green, dot: true),
            StatusPill('Metered billing with long text', tone: AppTone.amber),
            LedgerBadge('Legacy badge'),
            LedgerBadge('Legacy warning', warning: true),
            LedgerBadge('Legacy danger', danger: true),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            ProviderAvatar(name: '搬瓦工', mark: 'BWG', size: 60),
            SizedBox(width: 8),
            ProviderAvatar(name: 'RackNerd'),
            SizedBox(width: 8),
            ProviderAvatar(name: null),
            SizedBox(width: 8),
            ProviderAvatar(name: '阿里云', starred: true),
          ],
        ),
      ),
      const SizedBox(height: 12),
      AppEmptyState(
        icon: Icons.dns_outlined,
        title: 'Record your first VPS',
        message: 'Expiry, cost, hardware and SSH in one place.',
        actions: [
          AppButton(
            label: 'Add manually',
            icon: Icons.edit_outlined,
            onPressed: () {},
          ),
          AppButton(
            label: 'Import from panel account',
            kind: AppButtonKind.tonal,
            onPressed: () {},
          ),
          AppButton(
            label: 'Delete everything',
            kind: AppButtonKind.plain,
            destructive: true,
            onPressed: () {},
          ),
        ],
      ),
      InfoNote('Legacy info note in footnote style.'),
      const SectionTitle('Legacy section title'),
      const LedgerCard(child: Text('Legacy ledger card')),
      SettingRow(
        icon: Icons.settings_outlined,
        title: 'Legacy setting row',
        subtitle: 'subtitle',
        onTap: () {},
      ),
      if (last != null) Text('last=$last'),
    ],
  );
}

Future<void> pumpApp(
  WidgetTester tester,
  Widget home, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('zh'),
  double scale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(brightness: brightness),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      scrollBehavior: const AppScrollBehavior(),
      navigatorObservers: [AppRouteTitles.createObserver()],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens [open] from a button and returns the result via [result].
class Launcher extends StatefulWidget {
  const Launcher({super.key, required this.open});
  final Future<Object?> Function(BuildContext context) open;
  @override
  State<Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<Launcher> {
  Object? result = 'unset';
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextButton(
          key: const ValueKey('open'),
          onPressed: () async {
            final value = await widget.open(context);
            if (mounted) setState(() => result = value);
          },
          child: const Text('open'),
        ),
        Text('result=$result'),
      ],
    ),
  );
}

void main() {
  group('gallery layout', () {
    for (final brightness in Brightness.values) {
      for (final locale in const [Locale('zh'), Locale('en')]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            '${brightness.name} ${locale.languageCode} ${scale}x renders without overflow',
            (tester) async {
              // Tall viewport so every lazily built sliver child is laid out.
              await pumpApp(
                tester,
                const Gallery(),
                brightness: brightness,
                locale: locale,
                scale: scale,
                size: const Size(390, 6000),
              );
              expect(tester.takeException(), isNull);
              // Narrow phone too.
              await pumpApp(
                tester,
                const Gallery(),
                brightness: brightness,
                locale: locale,
                scale: scale,
                size: const Size(320, 7000),
              );
              expect(tester.takeException(), isNull);
              expect(find.byType(AppSection), findsWidgets);
            },
          );
        }
      }
    }
  });

  testWidgets('palette is exposed through the theme in both modes', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      late AppPalette palette;
      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            palette = context.palette;
            return const SizedBox();
          },
        ),
        brightness: brightness,
      );
      expect(palette.isDark, brightness == Brightness.dark);
      expect(
        palette.bg,
        appTheme(brightness: brightness).scaffoldBackgroundColor,
      );
    }
    expect(AppPalette.light.bg, const Color(0xFFF2F3F7));
    expect(AppPalette.dark.surface, const Color(0xFF171A21));
    expect(AppPalette.dark.primary, const Color(0xFF6F95FF));
  });

  testWidgets('theme uses Cupertino transitions and bouncing physics', (
    tester,
  ) async {
    for (final platform in TargetPlatform.values) {
      expect(
        appTheme().pageTransitionsTheme.builders[platform],
        isA<CupertinoPageTransitionsBuilder>(),
      );
    }
    await pumpApp(tester, const Gallery());
    final view = tester.widget<CustomScrollView>(find.byType(CustomScrollView));
    expect(view.physics, isA<BouncingScrollPhysics>());
    expect(
      const AppScrollBehavior().getScrollPhysics(
        tester.element(find.byType(Gallery)),
      ),
      isA<BouncingScrollPhysics>(),
    );
  });

  group('interactions', () {
    testWidgets('showAppSheet opens, returns a value and closes with ✕', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Launcher(
          open: (context) => showAppSheet<String>(
            context,
            title: 'Sheet title',
            builder: (sheet) => AppSection(
              children: [
                AppRow(
                  key: const ValueKey('choose'),
                  title: 'Choose me',
                  onTap: () => Navigator.pop(sheet, 'chosen'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(find.text('Sheet title'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('app-sheet-close')));
      await tester.pumpAndSettle();
      expect(find.text('Sheet title'), findsNothing);
      expect(find.text('result=null'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('choose')));
      await tester.pumpAndSettle();
      expect(find.text('result=chosen'), findsOneWidget);
    });

    testWidgets('showAppConfirm returns true / false for both styles', (
      tester,
    ) async {
      for (final dangerous in [false, true]) {
        await pumpApp(
          tester,
          Launcher(
            open: (context) => showAppConfirm(
              context,
              title: 'Archive server',
              message: 'The server is hidden but its history is kept.',
              action: 'Archive',
              dangerous: dangerous,
            ),
          ),
          locale: const Locale('en'),
        );
        await tester.tap(find.byKey(const ValueKey('open')));
        await tester.pumpAndSettle();
        // The full message is shown in both presentations.
        expect(
          find.text('The server is hidden but its history is kept.'),
          findsOneWidget,
        );
        expect(
          find.byType(dangerous ? CupertinoActionSheet : CupertinoAlertDialog),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('result=false'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('open')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Archive'));
        await tester.pumpAndSettle();
        expect(find.text('result=true'), findsOneWidget);
      }
    });

    testWidgets('legacy confirmAction keeps AlertDialog and its semantics', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Launcher(
          open: (context) => confirmAction(
            context,
            title: 'Delete',
            message: 'This cannot be undone.',
            action: 'Delete now',
            dangerous: true,
          ),
        ),
        locale: const Locale('en'),
        brightness: Brightness.dark,
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('result=false'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete now'));
      await tester.pumpAndSettle();
      expect(find.text('result=true'), findsOneWidget);
    });

    testWidgets('showAppPicker returns the tapped value and marks current', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Launcher(
          open: (context) => showAppPicker<int>(
            context,
            title: 'Cycle',
            selected: 12,
            footnote: 'Footnote text',
            options: const [
              AppPickerOption(value: 1, title: 'Monthly'),
              AppPickerOption(value: 12, title: 'Yearly', subtitle: 'sub'),
            ],
          ),
        ),
        locale: const Locale('en'),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('Footnote text'), findsOneWidget);
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      expect(find.text('result=1'), findsOneWidget);
    });

    testWidgets('showAppActionMenu runs the chosen callback after closing', (
      tester,
    ) async {
      var ran = 0;
      await pumpApp(
        tester,
        Launcher(
          open: (context) => showAppActionMenu<String>(
            context,
            title: 'HK-01',
            actions: [
              AppMenuAction(
                label: 'Copy address',
                value: 'copy',
                onPressed: () => ran++,
              ),
              const AppMenuAction(label: 'Archive', destructive: true),
            ],
          ),
        ),
        locale: const Locale('en'),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(ran, 0);
      expect(find.text('result=null'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy address'));
      await tester.pumpAndSettle();
      expect(ran, 1);
      expect(find.text('result=copy'), findsOneWidget);
    });

    testWidgets('showAppToast shows an undo action', (tester) async {
      var undone = false;
      await pumpApp(
        tester,
        Launcher(
          open: (context) async {
            showAppToast(
              context,
              'Archived',
              actionLabel: 'Undo',
              onAction: () => undone = true,
            );
            return null;
          },
        ),
        locale: const Locale('en'),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(find.text('Archived'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(undone, isTrue);
    });

    testWidgets('segmented, stepper, switch and chips change state', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const Gallery(),
        locale: const Locale('en'),
        size: const Size(390, 6000),
      );
      // Segmented (compact, unit picker).
      await tester.tap(find.text('TiB'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CupertinoSlidingSegmentedControl<String>>(
              find.byType(CupertinoSlidingSegmentedControl<String>).first,
            )
            .groupValue,
        'b',
      );
      // Stepper.
      await tester.tap(find.byKey(const ValueKey('inc')));
      await tester.pump();
      Finder stepperValue(String value) => find.descendant(
        of: find.byType(AppStepper),
        matching: find.text(value),
      );
      expect(stepperValue('3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('dec')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('dec')));
      await tester.pump();
      expect(stepperValue('1'), findsOneWidget);
      // Min bound: the button is disabled and the value stays.
      await tester.tap(find.byKey(const ValueKey('dec')));
      await tester.pump();
      expect(stepperValue('1'), findsOneWidget);
      // Switch row toggles by tapping the row.
      expect(
        tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
        isTrue,
      );
      await tester.tap(find.text('Expiry notifications'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
        isFalse,
      );
      // Chips: selected is the dark filled one.
      await tester.tap(find.text('Favourites'));
      await tester.pumpAndSettle();
      final material = tester.widget<Material>(
        find
            .ancestor(
              of: find.text('Favourites'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, AppPalette.light.text);
    });

    testWidgets('AppScaffold shows previous title on back, modal save state', (
      tester,
    ) async {
      var saved = 0;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => AppScaffold(
            title: 'Servers',
            children: [
              AppSection(
                children: [
                  AppRow(
                    key: const ValueKey('push'),
                    title: 'Open detail',
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AppScaffold(
                          title: 'Detail',
                          largeTitle: false,
                          children: [Text('detail body')],
                        ),
                      ),
                    ),
                  ),
                  AppRow(
                    key: const ValueKey('modal'),
                    title: 'Open modal',
                    onTap: () => showAppModal<void>(
                      context,
                      builder: (_) => AppScaffold.modal(
                        title: 'Add server',
                        onAction: () => saved++,
                        children: const [Text('form body')],
                      ),
                    ),
                  ),
                  AppRow(
                    key: const ValueKey('modal-disabled'),
                    title: 'Open disabled modal',
                    onTap: () => showAppModal<void>(
                      context,
                      builder: (_) => AppScaffold.modal(
                        title: 'Edit server',
                        actionLabel: 'Done',
                        children: const [Text('disabled body')],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        locale: const Locale('en'),
      );
      await tester.tap(find.byKey(const ValueKey('push')));
      await tester.pumpAndSettle();
      expect(find.text('detail body'), findsOneWidget);
      // Back button is labelled with the previous page's title.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('app-nav-back')),
          matching: find.text('Servers'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('app-nav-back')));
      await tester.pumpAndSettle();
      expect(find.text('detail body'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('modal')));
      await tester.pumpAndSettle();
      expect(find.text('form body'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Save'));
      expect(saved, 1);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('form body'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('modal-disabled')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pump();
      expect(saved, 1);
      expect(find.text('disabled body'), findsOneWidget);
    });

    testWidgets('pull to refresh invokes onRefresh', (tester) async {
      var refreshed = 0;
      await pumpApp(
        tester,
        AppScaffold(
          title: 'Servers',
          onRefresh: () async => refreshed++,
          children: const [SizedBox(height: 200, child: Text('content'))],
        ),
      );
      await tester.fling(find.text('content'), const Offset(0, 400), 1000);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(refreshed, 1);
    });

    testWidgets('large title collapses into the small title on scroll', (
      tester,
    ) async {
      await pumpApp(
        tester,
        AppScaffold(
          title: 'Settings',
          children: [for (var i = 0; i < 30; i++) AppRow(title: 'Row $i')],
        ),
        locale: const Locale('en'),
      );
      // Large + collapsed copies of the title exist while expanded.
      expect(find.text('Settings'), findsWidgets);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Settings'), findsWidgets);
    });
  });

  test('ProviderAvatar helpers are stable and sensible', () {
    expect(
      ProviderAvatar.colorFor('RackNerd'),
      ProviderAvatar.colorFor(' racknerd '),
    );
    expect(ProviderAvatar.colorFor(null), AppTints.grey);
    expect(ProviderAvatar.initialsFor('RackNerd'), 'RN');
    expect(ProviderAvatar.initialsFor('Digital Ocean'), 'DO');
    expect(ProviderAvatar.initialsFor('Hetzner'), 'He');
    expect(ProviderAvatar.initialsFor('搬瓦工'), '搬');
    expect(ProviderAvatar.initialsFor(''), '?');
  });

  testWidgets('AppInfoLink opens its explanation in a sheet', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: AppInfoLink(label: 'About keys', message: 'Long explanation'),
      ),
      locale: const Locale('en'),
    );
    expect(find.text('Long explanation'), findsNothing);
    await tester.tap(find.text('About keys'));
    await tester.pumpAndSettle();
    expect(find.text('Long explanation'), findsOneWidget);
  });

  group('AppMetricStrip', () {
    // The test font (Ahem) is one em wide per glyph, so keep the strings short.
    const metrics = [
      AppMetric(label: 'Val', value: '12.4'),
      AppMetric(label: 'Day', value: '7 d'),
      AppMetric(label: 'Avg', value: '0.13'),
    ];
    Future<void> pump(WidgetTester tester, double width, double scale) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: AppMetricStrip(metrics: metrics),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('wide: one row, equal columns, shared baselines', (
      tester,
    ) async {
      await pump(tester, 390, 1);
      final tops = [
        for (final m in metrics) tester.getTopLeft(find.text(m.label)).dy,
      ];
      expect(tops.toSet(), hasLength(1));
      final valueTops = [
        for (final m in metrics) tester.getTopLeft(find.text(m.value)).dy,
      ];
      expect(valueTops.toSet(), hasLength(1));
      expect(tester.takeException(), isNull);
    });

    for (final width in [320.0, 390.0]) {
      testWidgets('${width}px at 2x text never clips or overflows', (
        tester,
      ) async {
        await pump(tester, width, 2);
        for (final m in metrics) {
          final box = tester.getRect(find.text(m.value));
          expect(box.right, lessThanOrEqualTo(width));
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('tappable columns call back; onGradient renders white', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            body: AppMetricStrip(
              onGradient: true,
              metrics: [
                const AppMetric(label: 'Val', value: '12.4'),
                AppMetric(label: 'Day', value: '7 d', onTap: () => taps++),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('7 d'));
      expect(taps, 1);
      await tester.tap(find.text('12.4'));
      expect(taps, 1);
      expect(tester.widget<Text>(find.text('12.4')).style!.color, Colors.white);
      expect(tester.takeException(), isNull);
    });
  });
}
