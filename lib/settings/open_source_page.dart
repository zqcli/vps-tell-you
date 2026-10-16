import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/search_match.dart';
import '../core/ui/ui.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import 'about_common.dart';

/// A direct dependency (or bundled asset) shown in the curated list.
///
/// [registryNames] are the package names under which Flutter's
/// [LicenseRegistry] files its license texts (federated plugins list their
/// platform packages too); empty means just [name]. Keep this list, the
/// `r11OssAbout…` strings and `docs/LICENSES.md` in sync with `pubspec.yaml`.
class OpenSourceComponent {
  const OpenSourceComponent(
    this.name,
    this.license, [
    this.registryNames = const [],
  ]);
  final String name, license;
  final List<String> registryNames;

  /// Registry package names to look up.
  List<String> get lookup => registryNames.isEmpty ? [name] : registryNames;

  /// One-line purpose in the current language.
  String purpose(AppLocalizations l10n) => switch (name) {
    'Flutter' => l10n.r11OssAboutFlutter,
    'flutter_localizations' => l10n.r11OssAboutLocalizations,
    'intl' => l10n.r11OssAboutIntl,
    'sqflite' => l10n.r11OssAboutSqflite,
    'sqflite_common_ffi' => l10n.r11OssAboutSqfliteFfi,
    'path' => l10n.r11OssAboutPath,
    'path_provider' => l10n.r11OssAboutPathProvider,
    'flutter_secure_storage' => l10n.r11OssAboutSecureStorage,
    'local_auth' => l10n.r11OssAboutLocalAuth,
    'dartssh2' => l10n.r11OssAboutDartssh2,
    'xterm' => l10n.r11OssAboutXterm,
    'crypto' => l10n.r11OssAboutCrypto,
    'file_selector' => l10n.r11OssAboutFileSelector,
    'timezone' => l10n.r11OssAboutTimezone,
    'flutter_timezone' => l10n.r11OssAboutFlutterTimezone,
    'share_plus' => l10n.r11OssAboutSharePlus,
    'http' => l10n.r11OssAboutHttp,
    'xml' => l10n.r11OssAboutXml,
    'flutter_local_notifications' => l10n.r11OssAboutLocalNotifications,
    'DejaVu Sans Mono' => l10n.r11OssAboutDejaVu,
    _ => '',
  };
}

const kOpenSourceComponents = <OpenSourceComponent>[
  OpenSourceComponent('Flutter', 'BSD-3-Clause', ['flutter']),
  OpenSourceComponent('flutter_localizations', 'BSD-3-Clause'),
  OpenSourceComponent('intl', 'BSD-3-Clause'),
  OpenSourceComponent('sqflite', 'BSD-2-Clause', [
    'sqflite',
    'sqflite_android',
    'sqflite_darwin',
    'sqflite_common',
    'sqflite_platform_interface',
  ]),
  OpenSourceComponent('sqflite_common_ffi', 'BSD-2-Clause', [
    'sqflite_common_ffi',
    'sqlite3',
  ]),
  OpenSourceComponent('path', 'BSD-3-Clause'),
  OpenSourceComponent('path_provider', 'BSD-3-Clause', [
    'path_provider',
    'path_provider_android',
    'path_provider_foundation',
    'path_provider_linux',
    'path_provider_platform_interface',
    'path_provider_windows',
  ]),
  OpenSourceComponent('flutter_secure_storage', 'BSD-3-Clause', [
    'flutter_secure_storage',
    'flutter_secure_storage_darwin',
    'flutter_secure_storage_linux',
    'flutter_secure_storage_platform_interface',
    'flutter_secure_storage_web',
    'flutter_secure_storage_windows',
  ]),
  OpenSourceComponent('local_auth', 'BSD-3-Clause', [
    'local_auth',
    'local_auth_android',
    'local_auth_darwin',
    'local_auth_platform_interface',
    'local_auth_windows',
  ]),
  OpenSourceComponent('dartssh2', 'MIT'),
  OpenSourceComponent('xterm', 'MIT'),
  OpenSourceComponent('crypto', 'BSD-3-Clause'),
  OpenSourceComponent('file_selector', 'BSD-3-Clause', [
    'file_selector',
    'file_selector_android',
    'file_selector_ios',
    'file_selector_linux',
    'file_selector_macos',
    'file_selector_platform_interface',
    'file_selector_web',
    'file_selector_windows',
  ]),
  OpenSourceComponent('timezone', 'BSD-2-Clause'),
  OpenSourceComponent('flutter_timezone', 'Apache-2.0'),
  OpenSourceComponent('share_plus', 'BSD-3-Clause', [
    'share_plus',
    'share_plus_platform_interface',
  ]),
  OpenSourceComponent('http', 'BSD-3-Clause', ['http', 'http_parser']),
  OpenSourceComponent('xml', 'MIT', ['xml', 'petitparser']),
  OpenSourceComponent('flutter_local_notifications', 'BSD-3-Clause', [
    'flutter_local_notifications',
    'flutter_local_notifications_linux',
    'flutter_local_notifications_platform_interface',
    'flutter_local_notifications_web',
    'flutter_local_notifications_windows',
  ]),
  OpenSourceComponent('DejaVu Sans Mono', 'Bitstream Vera / DejaVu'),
];

/// All license texts of one package, as registered with [LicenseRegistry].
class PackageLicenses {
  const PackageLicenses(this.name, this.entries);
  final String name;

  /// One list of paragraphs per license entry.
  final List<List<LicenseParagraph>> entries;
}

/// Groups [LicenseRegistry.licenses] by package, once and on demand. The
/// registry is large (hundreds of packages) so this is never built before a
/// page asks for it.
class LicenseIndex {
  LicenseIndex();
  Future<List<PackageLicenses>>? _packages;

  Future<List<PackageLicenses>> get packages => _packages ??= _load();

  Future<List<PackageLicenses>> _load() async {
    final byName = <String, List<List<LicenseParagraph>>>{};
    await for (final entry in LicenseRegistry.licenses) {
      final paragraphs = entry.paragraphs.toList(growable: false);
      for (final name in entry.packages) {
        (byName[name] ??= []).add(paragraphs);
      }
    }
    final names = byName.keys.toList()..sort(compareNames);
    return [for (final name in names) PackageLicenses(name, byName[name]!)];
  }
}

/// Shared by the About pages; tests pass their own index.
final appLicenseIndex = LicenseIndex();

/// Settings › About › Open-Source Components.
class OpenSourcePage extends StatelessWidget {
  OpenSourcePage({super.key, LicenseIndex? index})
    : index = index ?? appLicenseIndex;
  final LicenseIndex index;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      title: l10n.r11AboutOpenSource,
      largeTitle: false,
      children: [
        AppSection(
          header: l10n.r11OssBuiltWith,
          footer: l10n.r11OssBuiltWithFootnote,
          children: [
            for (final component in kOpenSourceComponents)
              AppRow(
                key: ValueKey('oss-${component.name}'),
                title: component.name,
                subtitle: component.purpose(l10n),
                value: component.license,
                valueMaxLines: 2,
                chevron: true,
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ComponentLicensePage(
                      component: component,
                      index: index,
                    ),
                  ),
                ),
              ),
          ],
        ),
        FutureBuilder<List<PackageLicenses>>(
          future: index.packages,
          builder: (context, snapshot) {
            final count = snapshot.data?.length;
            return AppSection(
              children: [
                AppRow(
                  key: const ValueKey('oss-all-licenses'),
                  icon: Icons.list_alt_outlined,
                  iconColor: AppTints.slate,
                  title: count == null
                      ? l10n.r11OssAllLicensesTitle
                      : l10n.r11OssAllLicenses(count.toString()),
                  trailing: snapshot.connectionState == ConnectionState.done
                      ? null
                      : const SizedBox(
                          width: 16,
                          height: 16,
                          child: CupertinoActivityIndicator(radius: 8),
                        ),
                  chevron: true,
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllLicensesPage(index: index),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The license text(s) of one curated component.
class ComponentLicensePage extends StatelessWidget {
  const ComponentLicensePage({
    super.key,
    required this.component,
    required this.index,
  });
  final OpenSourceComponent component;
  final LicenseIndex index;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<List<PackageLicenses>>(
      future: index.packages,
      builder: (context, snapshot) {
        final wanted = {for (final n in component.lookup) n.toLowerCase()};
        final found = [
          for (final package in snapshot.data ?? const <PackageLicenses>[])
            if (wanted.contains(package.name.toLowerCase())) package,
        ];
        final done = snapshot.connectionState == ConnectionState.done;
        return LicenseDetailPage(
          title: component.name,
          subtitle: component.license,
          packages: found,
          loading: !done,
          emptyMessage: snapshot.hasError
              ? l10n.r11OssLoadFailed
              : l10n.r11OssLicenseMissing,
        );
      },
    );
  }
}

/// Every package in [LicenseRegistry], searchable and lazily built.
class AllLicensesPage extends StatefulWidget {
  const AllLicensesPage({super.key, required this.index});
  final LicenseIndex index;

  @override
  State<AllLicensesPage> createState() => _AllLicensesPageState();
}

class _AllLicensesPageState extends State<AllLicensesPage> {
  final query = TextEditingController();
  List<PackageLicenses>? packages;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    widget.index.packages.then(
      (value) {
        if (mounted) setState(() => packages = value);
      },
      onError: (Object _) {
        if (mounted) setState(() => failed = true);
      },
    );
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final all = packages;
    final tokens = searchTokens(query.text);
    final shown = all == null
        ? const <PackageLicenses>[]
        : [
            for (final package in all)
              if (tokens.isEmpty ||
                  matchesTokens(searchHaystack([package.name]), tokens))
                package,
          ];
    return AppScaffold(
      title: l10n.r11OssAllLicensesTitle,
      largeTitle: false,
      slivers: [
        AppPinnedSearch(
          controller: query,
          placeholder: l10n.r11OssSearch,
          onChanged: (_) => setState(() {}),
        ),
        if (failed)
          AppListMessage(l10n.r11OssLoadFailed)
        else if (all == null)
          const SliverToBoxAdapter(child: AboutLoading())
        else if (shown.isEmpty)
          AppListMessage(
            l10n.r11OssNoMatch,
            key: const ValueKey('licenses-no-match'),
          )
        else
          AppLazySections(
            sections: [
              AppListSection(
                count: shown.length,
                itemBuilder: (context, i) {
                  final package = shown[i];
                  return AppRow(
                    key: ValueKey('license-${package.name}'),
                    title: package.name,
                    value: package.entries.length > 1
                        ? package.entries.length.toString()
                        : null,
                    chevron: true,
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LicenseDetailPage(
                          title: package.name,
                          packages: [package],
                          emptyMessage: l10n.r11OssLicenseMissing,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
      ],
    );
  }
}

/// All paragraphs of the given packages' licenses, in a lazy list.
class LicenseDetailPage extends StatelessWidget {
  const LicenseDetailPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.packages,
    required this.emptyMessage,
    this.loading = false,
  });
  final String title;

  /// License identifier shown above the text (curated components).
  final String? subtitle;
  final List<PackageLicenses> packages;
  final String emptyMessage;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // Flatten to (paragraph | divider | package heading) rows so a long
    // license (hundreds of paragraphs) builds lazily.
    final rows = <Object>[];
    for (final package in packages) {
      if (packages.length > 1) rows.add(package.name);
      for (var i = 0; i < package.entries.length; i++) {
        if (i > 0) rows.add(const Divider(height: 32));
        rows.addAll(package.entries[i]);
      }
    }
    return AppScaffold(
      title: title,
      largeTitle: false,
      slivers: [
        if (subtitle != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
              child: Text(
                subtitle!,
                style: TextStyle(fontSize: 13, color: p.text2),
              ),
            ),
          ),
        if (rows.isEmpty)
          SliverToBoxAdapter(
            child: loading ? const AboutLoading() : AboutNotice(emptyMessage),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
            sliver: SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) => switch (rows[i]) {
                final String name => Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                ),
                final LicenseParagraph paragraph => Padding(
                  padding: EdgeInsets.only(
                    bottom: 8,
                    left: paragraph.indent > 0 ? paragraph.indent * 12.0 : 0,
                  ),
                  child: Text(
                    paragraph.text,
                    textAlign:
                        paragraph.indent == LicenseParagraph.centeredIndent
                        ? TextAlign.center
                        : TextAlign.start,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: p.text,
                    ),
                  ),
                ),
                final Widget divider => divider,
                _ => const SizedBox.shrink(),
              },
            ),
          ),
      ],
    );
  }
}
