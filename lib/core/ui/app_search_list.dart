import 'package:flutter/material.dart';

import '../app_palette.dart';
import 'app_glass.dart';
import 'app_list.dart';
import 'app_controls.dart';

/// Search field pinned under the navigation bar of an [AppScaffold] whose body
/// is given as `slivers`. Put it first in the list:
///
/// ```dart
/// AppScaffold(title: l10n.providers, slivers: [
///   AppPinnedSearch(controller: query, placeholder: l10n.search,
///       onChanged: (_) => setState(() {})),
///   AppLazySections(sections: [...]),
/// ])
/// ```
///
/// Autofocus is off by default: on a phone the keyboard would cover the list.
class AppPinnedSearch extends StatelessWidget {
  const AppPinnedSearch({
    super.key,
    required this.controller,
    this.placeholder,
    this.onChanged,
    this.focusNode,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    // 16 px text grows with the text scale; the field adds ~18 px padding.
    final scaled = MediaQuery.textScalerOf(context).scale(16);
    final extent = 6 + 18 + scaled * 1.3 + 12;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SearchDelegate(
        extent: extent,
        background: context.palette.bg,
        fade: context.glassStyle.isLiquid,
        field: AppSearchField(
          key: const ValueKey('list-search'),
          controller: controller,
          placeholder: placeholder,
          onChanged: onChanged,
          focusNode: focusNode,
          autofocus: autofocus,
        ),
      ),
    );
  }
}

class _SearchDelegate extends SliverPersistentHeaderDelegate {
  _SearchDelegate({
    required this.extent,
    required this.background,
    required this.fade,
    required this.field,
  });
  final double extent;
  final Color background;

  /// iOS 26: the page colour fades out under the glass field, so rows slide
  /// under it instead of being cut off by an opaque band.
  final bool fade;
  final Widget field;

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final padded = Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Align(alignment: Alignment.center, child: field),
    );
    if (!fade) return ColoredBox(color: background, child: padded);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            background.withValues(alpha: .96),
            background.withValues(alpha: .7),
            background.withValues(alpha: 0),
          ],
          stops: const [0, .6, 1],
        ),
      ),
      child: padded,
    );
  }

  // The field keeps its state (focus, text) in its controller.
  @override
  bool shouldRebuild(_SearchDelegate old) => true;
}

/// A titled run of rows of an [AppLazySections] list. Rows are created on
/// demand by [itemBuilder], so a section may hold hundreds of entries.
class AppListSection {
  const AppListSection({
    this.header,
    this.footer,
    required this.count,
    required this.itemBuilder,
  });
  final String? header, footer;
  final int count;

  /// Usually returns an [AppRow] (or any widget; [AppSectionItem]s control the
  /// separator inset).
  final Widget Function(BuildContext context, int index) itemBuilder;
}

/// Lazy, grouped-inset list (the look of [AppSection], built as one sliver
/// so only the visible rows exist). Empty sections are skipped.
class AppLazySections extends StatelessWidget {
  const AppLazySections({super.key, required this.sections});
  final List<AppListSection> sections;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shown = [
      for (final s in sections)
        if (s.count > 0) s,
    ];
    // slot layout per section: header/spacer, rows..., optional footer
    final starts = <int>[];
    var total = 0;
    for (final s in shown) {
      starts.add(total);
      total += 1 + s.count + (s.footer != null ? 1 : 0);
    }
    Widget build(BuildContext context, int index) {
      var at = starts.length - 1;
      while (starts[at] > index) {
        at--;
      }
      final section = shown[at];
      final local = index - starts[at];
      if (local == 0) {
        return section.header == null
            ? SizedBox(height: at == 0 ? 8 : 16)
            : Padding(
                padding: EdgeInsets.fromLTRB(32, at == 0 ? 8 : 22, 32, 7),
                child: Text(
                  section.header!,
                  style: TextStyle(fontSize: 13, color: p.text2),
                ),
              );
      }
      if (local > section.count) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(32, 7, 32, 0),
          child: Text(section.footer!, style: context.footnoteStyle),
        );
      }
      final i = local - 1;
      final row = section.itemBuilder(context, i);
      final first = i == 0, last = i == section.count - 1;
      final inset = row is AppSectionItem
          ? (row as AppSectionItem).separatorInset
          : 16.0;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Material(
          color: p.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(first ? 14 : 0),
              bottom: Radius.circular(last ? 14 : 0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!first)
                Padding(
                  padding: EdgeInsetsDirectional.only(start: inset),
                  child: SizedBox(
                    height: .5,
                    child: ColoredBox(color: p.separator),
                  ),
                ),
              row,
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(build, childCount: total),
    );
  }
}

/// Centred grey message for an empty search result or list.
class AppListMessage extends StatelessWidget {
  const AppListMessage(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          height: 1.4,
          color: context.palette.text2,
        ),
      ),
    ),
  );
}
