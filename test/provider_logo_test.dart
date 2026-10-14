import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show SynchronousFuture, ValueListenable;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/providers/directory_widgets.dart';
import 'package:vps_tell_you/providers/provider_directory.dart';
import 'package:vps_tell_you/providers/provider_pages.dart';
import 'package:vps_tell_you/providers/provider_record.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_detail.dart';
import 'package:vps_tell_you/servers/server_list.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'support/catalog_fixture.dart';

/// An image which always fails to load.
class _BrokenImage extends ImageProvider<_BrokenImage> {
  @override
  Future<_BrokenImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _BrokenImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(Future.error(StateError('corrupt')));

  @override
  bool operator ==(Object other) => other is _BrokenImage;
  @override
  int get hashCode => 1;
}

void main() {
  late Directory temp;
  late File logo;
  late LedgerStore store;
  late LedgerController ledger;
  final locale = ValueNotifier<Locale>(const Locale('en'));
  final theme = ValueNotifier<Brightness>(Brightness.light);
  final now = DateTime.utc(2026, 10, 14, 12);

  setUp(() async {
    locale.value = const Locale('en');
    theme.value = Brightness.light;
    sqfliteFfiInit();
    temp = await Directory.systemTemp.createTemp('vps-logo-');
    // A real 256 px PNG: the seed logo of the catalog.
    logo = await File('catalog/providers/aws/logo.png')
        .copy('${temp.path}/fixture-cloud-12345678.png');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${temp.path}/ledger.sqlite3',
      clock: () => now,
    );
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await temp.delete(recursive: true);
  });

  /// A controller whose directory has the fixture providers and [logo] for
  /// `fixture-cloud` only (or none).
  Future<void> boot({bool withLogo = true, List<Object?>? entries}) async {
    final snapshot = entries == null
        ? fixtureCatalog()
        : DirectorySnapshot.parse(
            jsonEncode(directoryIndexJson(providers: entries)),
          );
    ledger = LedgerController(
      store,
      clock: () => now,
      directory: ProviderDirectory.memory(snapshot, {
        if (withLogo) 'fixture-cloud': logo,
      }),
    );
    await ledger.refresh();
  }

  Future<void> mount(
    WidgetTester tester,
    Widget home, {
    double width = 390,
    double scale = 1,
    double dpr = 1,
  }) async {
    tester.view.physicalSize = Size(width * dpr, 900 * dpr);
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ValueListenableBuilder2<Locale, Brightness>(
        locale,
        theme,
        (context, value, brightness) => MaterialApp(
          theme: appTheme(brightness: brightness),
          locale: value,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> addLinkedServer(String id, {bool favorite = false}) async {
    await store.saveServer(
      ServerRecord(
        id: id,
        name: 'Server $id',
        vendor: 'Fixture Cloud',
        favorite: favorite,
        createdAt: now,
        updatedAt: now,
      ),
      isNew: true,
      catalogProvider: const CatalogProviderRef(
        catalogId: 'fixture-cloud',
        name: 'Fixture Cloud',
      ),
    );
    await ledger.refresh();
  }

  Finder avatarIn(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(ProviderAvatar),
  );

  group('ProviderAvatar', () {
    testWidgets('logo: white tile, hairline border, sized decode', (
      tester,
    ) async {
      await boot();
      await mount(
        tester,
        Scaffold(
          body: Center(
            child: ProviderAvatar(
              name: 'Fixture Cloud',
              logo: MemoryImage(logo.readAsBytesSync()),
            ),
          ),
        ),
        dpr: 3,
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.contain);
      expect(image.filterQuality, FilterQuality.medium);
      final resized = image.image as ResizeImage;
      expect(resized.width, (42 * 3), reason: 'cacheWidth = size × dpr');
      expect(resized.height, isNull, reason: 'aspect ratio is kept');
      final tile = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byType(Image),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = tile.decoration as BoxDecoration;
      expect(decoration.color, Colors.white);
      expect(decoration.border, isNotNull, reason: 'hairline border');
      expect(
        (decoration.border! as Border).top.width,
        lessThan(1),
        reason: 'a hairline',
      );
      // No initials under a logo.
      expect(find.text('FC'), findsNothing);
    });

    testWidgets('the tile is white in the dark theme too', (tester) async {
      theme.value = Brightness.dark;
      await boot();
      await mount(
        tester,
        Scaffold(
          body: Center(
            child: ProviderAvatar(
              name: 'Fixture Cloud',
              logo: MemoryImage(logo.readAsBytesSync()),
            ),
          ),
        ),
      );
      final tile = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byType(Image),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((tile.decoration as BoxDecoration).color, Colors.white);
      expect(
        Theme.of(tester.element(find.byType(Image))).brightness,
        Brightness.dark,
      );
    });

    testWidgets('without a logo the initials avatar is unchanged', (
      tester,
    ) async {
      await boot();
      await mount(
        tester,
        const Scaffold(
          body: Center(child: ProviderAvatar(name: 'RackNerd')),
        ),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.text('RN'), findsOneWidget);
    });

    testWidgets('an image which cannot be decoded falls back to initials', (
      tester,
    ) async {
      await boot();
      await mount(
        tester,
        Scaffold(
          body: Center(
            child: ProviderAvatar(name: 'RackNerd', logo: _BrokenImage()),
          ),
        ),
      );
      expect(find.text('RN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the favourite star badge is kept on a logo', (tester) async {
      await boot();
      await mount(
        tester,
        Scaffold(
          body: Center(
            child: ProviderAvatar(
              name: 'Fixture Cloud',
              starred: true,
              logo: MemoryImage(logo.readAsBytesSync()),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      // The badge sits at the bottom-right corner, outside the tile.
      final tile = tester.getRect(find.byType(ProviderAvatar));
      final star = tester.getCenter(find.byIcon(Icons.star_rounded));
      expect(star.dx, greaterThan(tile.center.dx));
      expect(star.dy, greaterThan(tile.center.dy));
      expect(tile.size, const Size(42, 42), reason: 'same slot as before');
    });

    testWidgets('the semantics label is the provider name', (tester) async {
      await boot();
      final handle = tester.ensureSemantics();
      await mount(
        tester,
        Scaffold(
          body: Center(
            child: ProviderAvatar(
              name: 'Fixture Cloud',
              logo: MemoryImage(logo.readAsBytesSync()),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Fixture Cloud'), findsOneWidget);
      handle.dispose();
    });
  });

  group('ProviderLogo', () {
    testWidgets('uses the cached directory logo of a linked provider', (
      tester,
    ) async {
      await boot();
      await addLinkedServer('a');
      await store.saveProvider(
        ProviderRecord(id: 'mine', name: 'Mine', createdAt: now),
        isNew: true,
      );
      await ledger.refresh();
      final linked = ledger.providers.firstWhere(
        (p) => p.catalogId == 'fixture-cloud',
      );
      final custom = ledger.providers.firstWhere((p) => p.id == 'mine');
      await mount(
        tester,
        Scaffold(
          body: Column(
            children: [
              ProviderLogo(
                key: const ValueKey('linked'),
                ledger: ledger,
                provider: linked,
              ),
              ProviderLogo(
                key: const ValueKey('custom'),
                ledger: ledger,
                provider: custom,
              ),
              ProviderLogo(
                key: const ValueKey('entry'),
                ledger: ledger,
                directoryId: 'fixture-cloud',
                name: 'Fixture Cloud',
              ),
              ProviderLogo(
                key: const ValueKey('no-logo'),
                ledger: ledger,
                directoryId: 'empty-host',
                name: 'Empty Host',
              ),
              ProviderLogo(
                key: const ValueKey('unknown'),
                ledger: ledger,
                directoryId: 'not-in-directory',
                name: 'Gone',
              ),
            ],
          ),
        ),
      );
      ProviderAvatar avatar(String key) =>
          tester.widget<ProviderAvatar>(avatarIn(key));
      expect((avatar('linked').logo! as FileImage).file.path, logo.path);
      expect((avatar('entry').logo! as FileImage).file.path, logo.path);
      expect(avatar('custom').logo, isNull);
      expect(avatar('no-logo').logo, isNull);
      expect(avatar('unknown').logo, isNull, reason: 'initials, no error');
      expect(avatar('unknown').name, 'Gone');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the server list shows the logo of linked providers only', (
      tester,
    ) async {
      await boot();
      await addLinkedServer('a', favorite: true);
      await store.saveServer(
        ServerRecord(
          id: 'plain',
          name: 'Plain',
          vendor: 'Somewhere',
          createdAt: now,
          updatedAt: now,
        ),
        isNew: true,
      );
      await ledger.refresh();
      await mount(tester, Scaffold(body: ServerList(controller: ledger)));
      final linked = tester.widget<ProviderAvatar>(avatarIn('server-a'));
      expect(linked.logo, isA<FileImage>());
      expect(linked.starred, isTrue, reason: 'favourite badge kept');
      expect(linked.size, 42);
      final plain = tester.widget<ProviderAvatar>(avatarIn('server-plain'));
      expect(plain.logo, isNull);
      expect(plain.name, isNull, reason: 'no provider: grey avatar as before');
    });

    testWidgets('a logo downloaded later appears without reopening', (
      tester,
    ) async {
      final late = _LateDirectory(fixtureCatalog());
      ledger = LedgerController(store, clock: () => now, directory: late);
      await ledger.refresh();
      await addLinkedServer('a');
      await mount(tester, Scaffold(body: ServerList(controller: ledger)));
      expect(tester.widget<ProviderAvatar>(avatarIn('server-a')).logo, isNull);
      late.arrive(logo);
      await tester.pump();
      expect(
        tester.widget<ProviderAvatar>(avatarIn('server-a')).logo,
        isA<FileImage>(),
      );
    });

    testWidgets('server detail header and provider row use the same logo', (
      tester,
    ) async {
      await boot();
      await addLinkedServer('a');
      await mount(tester, ServerDetail(controller: ledger, id: 'a'));
      ProviderAvatar header() =>
          tester.widget<ProviderAvatar>(find.byType(ProviderAvatar).first);
      expect(header().size, 60);
      expect(header().logo, isA<FileImage>());
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('server-provider-link')),
        300,
      );
      final row = tester.widget<ProviderAvatar>(
        avatarIn('server-provider-link'),
      );
      expect(row.size, 30);
      expect(row.logo, isA<FileImage>());
    });
  });

  group('provider page', () {
    Future<void> openEntry(WidgetTester tester, {double width = 390}) => mount(
      tester,
      ProviderDetailsPage(ledger: ledger, catalogId: 'fixture-cloud'),
      width: width,
    );

    testWidgets('shows logo, description and website of a directory entry', (
      tester,
    ) async {
      await boot();
      await openEntry(tester);
      expect(
        tester.widget<ProviderAvatar>(find.byType(ProviderAvatar).first).logo,
        isA<FileImage>(),
      );
      expect(find.text('Fixture Cloud'), findsWidgets);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('provider-description')))
            .data,
        'A cloud provider for tests.',
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('provider-website')),
          matching: find.text('https://fixture-cloud.example.com'),
        ),
        findsOneWidget,
      );
      // Not yet added: the same page offers adding it and a first server.
      expect(
        find.byKey(const ValueKey('provider-add-catalog')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('provider-add-server')), findsOneWidget);
    });

    testWidgets('the description follows the language, then falls back', (
      tester,
    ) async {
      await boot(
        entries: [
          directoryEntry(
            'fixture-cloud',
            descriptionZh: '只有中文说明。',
            descriptionEn: '',
          ),
        ],
      );
      await openEntry(tester);
      expect(find.text('只有中文说明。'), findsOneWidget, reason: 'en → zh');
      locale.value = const Locale('zh');
      await tester.pump();
      expect(find.text('只有中文说明。'), findsOneWidget);
    });

    testWidgets('tapping the website copies it (no browser)', (tester) async {
      await boot();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
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
      await openEntry(tester);
      await tester.tap(find.byKey(const ValueKey('provider-website')));
      await tester.pump();
      expect(copied, 'https://fixture-cloud.example.com');
      expect(find.text('Website address copied'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('a custom provider has no description or website', (
      tester,
    ) async {
      await boot();
      await store.saveProvider(
        ProviderRecord(id: 'mine', name: 'Mine', createdAt: now),
        isNew: true,
      );
      await ledger.refresh();
      await mount(
        tester,
        ProviderDetailsPage(ledger: ledger, providerId: 'mine'),
      );
      expect(find.byKey(const ValueKey('provider-description')), findsNothing);
      expect(find.byKey(const ValueKey('provider-website')), findsNothing);
      expect(
        tester.widget<ProviderAvatar>(find.byType(ProviderAvatar).first).logo,
        isNull,
      );
    });

    testWidgets('an added entry keeps the local name but the directory text', (
      tester,
    ) async {
      await boot();
      await addLinkedServer('a');
      final local = ledger.providers.single;
      await store.saveProvider(
        ProviderRecord(
          id: local.id,
          name: 'My cloud',
          createdAt: local.createdAt,
          revision: local.revision,
        ),
        isNew: false,
      );
      await ledger.refresh();
      await mount(
        tester,
        ProviderDetailsPage(ledger: ledger, providerId: local.id),
      );
      expect(find.text('My cloud'), findsWidgets);
      expect(
        find.byKey(const ValueKey('provider-description')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('provider-device-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('provider-add-catalog')), findsNothing);
    });

    testWidgets('delete: confirms, unlinks the servers and closes the page', (
      tester,
    ) async {
      await boot();
      await addLinkedServer('a');
      await addLinkedServer('b');
      final local = ledger.providers.single;
      await mount(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open'),
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProviderDetailsPage(ledger: ledger, providerId: local.id),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('provider-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('provider-delete')));
      await tester.pumpAndSettle();
      expect(find.text('Delete “Fixture Cloud”?'), findsOneWidget);
      expect(find.textContaining('Its 2 servers stay'), findsOneWidget);
      // Declining changes nothing.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await store.providers(), hasLength(1));

      await tester.tap(find.byKey(const ValueKey('provider-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('provider-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Provider').last);
      await tester.pumpAndSettle();
      expect(await store.providers(), isEmpty);
      expect(ledger.records.map((s) => s.providerId), [null, null]);
      expect(find.byType(ProviderDetailsPage), findsNothing);
      // Back in the directory list, as "not added".
      expect(notAddedIds(ledger), contains('fixture-cloud'));
    });
  });

  group('320px and 2x text', () {
    for (final lang in ['en', 'zh']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$lang ${scale}x: lists and detail with logos fit', (
          tester,
        ) async {
          locale.value = Locale(lang);
          await boot(
            entries: [
              directoryEntry(
                'fixture-cloud',
                zh: '一个名字相当长的云服务提供商名称用来测试窄屏',
                en: 'A cloud provider with a rather long name for narrow phones',
                descriptionZh: '这是一段相当长的简介，用来确认窄屏和两倍字号下不会被截断或溢出。',
                descriptionEn:
                    'A deliberately long description which has to wrap on a '
                    'narrow screen at twice the text size without overflowing.',
              ),
            ],
          );
          await addLinkedServer('a', favorite: true);
          final pages = <String, Widget Function()>{
            'server list': () => Scaffold(body: ServerList(controller: ledger)),
            'providers': () => ProvidersPage(ledger: ledger),
            'all providers': () => AllProvidersPage(ledger: ledger),
            'details': () => ProviderDetailsPage(
              ledger: ledger,
              providerId: ledger.providers.single.id,
            ),
            'entry': () =>
                ProviderDetailsPage(ledger: ledger, catalogId: 'fixture-cloud'),
            'server detail': () => ServerDetail(controller: ledger, id: 'a'),
          };
          for (final entry in pages.entries) {
            await mount(
              tester,
              entry.value(),
              width: 320,
              scale: scale,
              dpr: 2,
            );
            expect(tester.takeException(), isNull, reason: entry.key);
            for (final avatar in tester.widgetList<ProviderAvatar>(
              find.byType(ProviderAvatar),
            )) {
              expect(avatar.logo, isA<FileImage>(), reason: entry.key);
            }
            final scrollable = find
                .byWidgetPredicate(
                  (w) => w is Scrollable && w.axis == Axis.vertical,
                )
                .first;
            for (var i = 0; i < 4; i++) {
              await tester.drag(scrollable, const Offset(0, -500));
              await tester.pump(const Duration(milliseconds: 200));
              expect(
                tester.takeException(),
                isNull,
                reason: '${entry.key} scrolled',
              );
            }
          }
        });
      }
    }
  });
}

List<String> notAddedIds(LedgerController ledger) => [
  for (final p in ledger.directory.providers)
    if (!ledger.providers.any((l) => l.catalogId == p.id)) p.id,
];

/// A directory whose logo arrives after the screen is already showing.
class _LateDirectory extends ProviderDirectory {
  _LateDirectory(DirectorySnapshot super.snapshot) : super.memory();
  File? _file;
  void arrive(File file) {
    _file = file;
    notifyListeners();
  }

  @override
  File? logoFor(String id) => id == 'fixture-cloud' ? _file : null;
}

/// Rebuilds when either notifier changes.
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  const ValueListenableBuilder2(this.a, this.b, this.builder, {super.key});
  final ValueListenable<A> a;
  final ValueListenable<B> b;
  final Widget Function(BuildContext, A, B) builder;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([a, b]),
    builder: (context, _) => builder(context, a.value, b.value),
  );
}
