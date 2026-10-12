import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_palette.dart';
import 'app_list.dart';

/// One choice of an [AppDropdownRow].
class AppDropdownItem<T> {
  const AppDropdownItem({
    required this.value,
    required this.title,
    this.subtitle,
    this.key,
  });
  final T value;
  final String title;

  /// Secondary line (price, package count …); wraps instead of clipping.
  final String? subtitle;

  /// Key of the menu item (for tests).
  final Key? key;
}

/// A titled run of choices; groups are separated by a thick hairline band.
class AppDropdownGroup<T> {
  const AppDropdownGroup({this.header, required this.items});

  /// Small grey caption above the group (omit for the first, untitled one).
  final String? header;
  final List<AppDropdownItem<T>> items;
}

/// Form row whose value opens an anchored popup menu (a dropdown) instead of
/// a page or sheet: label left, current value and an up/down chevron right.
/// The menu hangs below the row, is card-styled with the palette, scrolls when
/// taller than the screen and marks [selected] with a check.
///
/// ```dart
/// AppDropdownRow<String>(
///   key: const ValueKey('form-provider'),
///   label: l10n.provider,
///   value: provider?.name,
///   placeholder: l10n.none,
///   selected: providerKey,
///   groups: [AppDropdownGroup(items: [AppDropdownItem(value: '', title: l10n.none)])],
///   onSelected: setProvider,
/// )
/// ```
class AppDropdownRow<T> extends StatefulWidget implements AppSectionItem {
  const AppDropdownRow({
    super.key,
    required this.label,
    required this.groups,
    required this.onSelected,
    this.value,
    this.placeholder,
    this.selected,
    this.enabled = true,
  });

  final String label;

  /// Text shown on the row (the chosen item's title).
  final String? value;
  final String? placeholder;
  final T? selected;
  final bool enabled;
  final List<AppDropdownGroup<T>> groups;
  final ValueChanged<T> onSelected;

  @override
  double get separatorInset => 16;

  @override
  State<AppDropdownRow<T>> createState() => _AppDropdownRowState<T>();
}

class _AppDropdownRowState<T> extends State<AppDropdownRow<T>> {
  final _menu = MenuController();

  @override
  void didUpdateWidget(AppDropdownRow<T> old) {
    super.didUpdateWidget(old);
    if (!widget.enabled && _menu.isOpen) _menu.close();
  }

  Widget _item(BuildContext context, AppDropdownItem<T> item, double width) {
    final p = context.palette;
    final on = item.value == widget.selected;
    return Semantics(
      selected: on,
      child: MenuItemButton(
        key: item.key,
        onPressed: () => widget.onSelected(item.value),
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          minimumSize: WidgetStatePropertyAll(Size(width, 44)),
          maximumSize: WidgetStatePropertyAll(Size(width, double.infinity)),
          shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
          overlayColor: WidgetStatePropertyAll(p.fill),
          foregroundColor: WidgetStatePropertyAll(p.text),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(fontSize: 16, height: 1.25, color: p.text),
                  ),
                  if (item.subtitle != null && item.subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.subtitle!,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: p.text2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (on) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_rounded, size: 20, color: p.primary),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _children(BuildContext context, double width) {
    final p = context.palette;
    final out = <Widget>[];
    for (var i = 0; i < widget.groups.length; i++) {
      final group = widget.groups[i];
      if (group.items.isEmpty) continue;
      if (out.isNotEmpty) {
        out.add(
          SizedBox(
            height: 6,
            width: width,
            child: ColoredBox(color: p.fill),
          ),
        );
      }
      final header = group.header;
      if (header != null) {
        out.add(
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: SizedBox(
                width: width - 32,
                child: Text(
                  header,
                  style: TextStyle(fontSize: 12.5, color: p.text3),
                ),
              ),
            ),
          ),
        );
      }
      for (var j = 0; j < group.items.length; j++) {
        if (j > 0) {
          out.add(
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: SizedBox(
                height: .5,
                width: width - 16,
                child: ColoredBox(color: p.separator),
              ),
            ),
          );
        }
        out.add(_item(context, group.items[j], width));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        // Narrower than the row so the card floats over it, never wider than
        // a comfortable menu.
        final width = math.max(
          200.0,
          math.min(
            box.maxWidth - 32,
            340.0 * math.min(media.textScaler.scale(1), 1.3),
          ),
        );
        final text = widget.value;
        final empty = text == null || text.isEmpty;
        return MenuAnchor(
          controller: _menu,
          alignmentOffset: const Offset(-16, -4),
          style: MenuStyle(
            alignment: AlignmentDirectional.bottomEnd,
            backgroundColor: WidgetStatePropertyAll(p.surface),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            shadowColor: WidgetStatePropertyAll(
              Colors.black.withValues(alpha: p.isDark ? .5 : .16),
            ),
            elevation: const WidgetStatePropertyAll(8),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: p.separator, width: .5),
              ),
            ),
            minimumSize: WidgetStatePropertyAll(Size(width, 0)),
            maximumSize: WidgetStatePropertyAll(
              Size(width, math.max(240, media.size.height * .8)),
            ),
          ),
          menuChildren: _children(context, width),
          builder: (context, controller, _) => Semantics(
            button: true,
            expanded: controller.isOpen,
            enabled: widget.enabled,
            label: widget.label,
            value: empty ? widget.placeholder : text,
            excludeSemantics: true,
            onTap: widget.enabled
                ? () =>
                      controller.isOpen ? controller.close() : controller.open()
                : null,
            child: AppFormRow(
              label: widget.label,
              onTap: widget.enabled
                  ? () => controller.isOpen
                        ? controller.close()
                        : controller.open()
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      empty ? (widget.placeholder ?? '') : text,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 16,
                        color: empty ? p.text3 : p.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.unfold_more_rounded, size: 18, color: p.text3),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
