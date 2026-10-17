import 'package:flutter/material.dart';

import '../core/ui/ui.dart';
import '../l10n/locale_preference.dart';
import 'sftp_session.dart';

/// Tappable path segments; scrolls so the current folder stays visible.
class SftpBreadcrumb extends StatefulWidget {
  const SftpBreadcrumb({super.key, required this.path, required this.onOpen});
  final String path;
  final ValueChanged<String> onOpen;

  @override
  State<SftpBreadcrumb> createState() => _SftpBreadcrumbState();
}

class _SftpBreadcrumbState extends State<SftpBreadcrumb> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(SftpBreadcrumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _toEnd();
  }

  @override
  void initState() {
    super.initState();
    _toEnd();
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  });

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final segments = widget.path.split('/').where((s) => s.isNotEmpty).toList();
    Widget crumb(int index, String label, String target, {Widget? icon}) {
      final last = index == segments.length;
      return Semantics(
        button: true,
        child: InkWell(
          key: ValueKey('sftp-crumb-$index'),
          borderRadius: BorderRadius.circular(8),
          onTap: last ? null : () => widget.onOpen(target),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child:
                icon ??
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: last ? FontWeight.w600 : FontWeight.w400,
                    color: last ? palette.text : palette.primary,
                  ),
                ),
          ),
        ),
      );
    }

    final children = <Widget>[
      crumb(
        0,
        '/',
        '/',
        icon: Icon(
          Icons.dns_outlined,
          size: 20,
          color: segments.isEmpty ? palette.text : palette.primary,
        ),
      ),
    ];
    var built = '';
    for (var i = 0; i < segments.length; i++) {
      built = '$built/${segments[i]}';
      children
        ..add(Icon(Icons.chevron_right_rounded, size: 18, color: palette.text3))
        ..add(crumb(i + 1, segments[i], built));
    }
    // Grows with the text size so large type is never cut off.
    final height = (MediaQuery.textScalerOf(context).scale(15) * 1.4 + 18)
        .clamp(44.0, 120.0);
    return SizedBox(
      height: height,
      child: ListView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [Row(children: children)],
      ),
    );
  }
}

class SftpSwipeAction {
  const SftpSwipeAction({
    this.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final Key? key;
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Row with swipe-to-reveal buttons, same gesture as the server list; only
/// one row stays open.
class SftpSwipeRow extends StatefulWidget implements AppSectionItem {
  const SftpSwipeRow({super.key, required this.actions, required this.child});
  final List<SftpSwipeAction> actions;
  final Widget child;

  @override
  double get separatorInset => 58;

  @override
  State<SftpSwipeRow> createState() => _SftpSwipeRowState();
}

class _SftpSwipeRowState extends State<SftpSwipeRow> {
  static const _buttonWidth = 76.0;
  static _SftpSwipeRowState? _open;
  double _extent = 0;
  bool _dragging = false, _visible = false;

  double get _full => _buttonWidth * widget.actions.length;

  void _set(double value, {bool drag = false}) {
    if (!mounted) return;
    setState(() {
      if (value > 0 || drag) {
        _visible = true;
      } else if (_extent == 0) {
        _visible = false;
      }
      _extent = value;
      _dragging = drag;
    });
    if (value > 0) {
      if (_open != this) {
        final previous = _open;
        _open = this;
        previous?._set(0);
      }
    } else if (_open == this) {
      _open = null;
    }
  }

  @override
  void dispose() {
    if (_open == this) _open = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sign = Directionality.of(context) == TextDirection.rtl ? 1.0 : -1.0;
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: !_visible
                  ? const SizedBox.shrink()
                  : ExcludeSemantics(
                      excluding: _extent == 0,
                      child: IgnorePointer(
                        ignoring: _extent == 0,
                        child: SizedBox(
                          width: _full,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final action in widget.actions)
                                SizedBox(
                                  width: _buttonWidth,
                                  child: Material(
                                    color: action.color,
                                    child: InkWell(
                                      key: action.key,
                                      onTap: () {
                                        _set(0);
                                        action.onTap();
                                      },
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            action.icon,
                                            size: 22,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(height: 3),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                action.label,
                                                maxLines: 1,
                                                textScaler:
                                                    TextScaler.noScaling,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _set(_extent, drag: true),
            onHorizontalDragUpdate: (details) => _set(
              (_extent + details.delta.dx * sign).clamp(0.0, _full + 30),
              drag: true,
            ),
            onHorizontalDragEnd: (_) => _set(_extent > 50 ? _full : 0),
            onHorizontalDragCancel: () => _set(_extent > 50 ? _full : 0),
            child: AnimatedContainer(
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(-sign * _extent * -1, 0, 0),
              color: context.palette.surface,
              child: IgnorePointer(ignoring: _extent > 0, child: widget.child),
            ),
          ),
          if (_extent > 0)
            Positioned.fill(
              right: _full,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _set(0),
              ),
            ),
        ],
      ),
    );
  }
}

/// Name (and optionally folder) prompt in a bottom sheet. Returns
/// `(name, folder?)`, or `null` when cancelled.
Future<(String, String?)?> promptSftpName(
  BuildContext context, {
  required String title,
  required String action,
  String? name,
  String? folder,
  String? hint,
}) => showAppSheet<(String, String?)>(
  context,
  title: title,
  builder: (_) =>
      _NamePrompt(action: action, name: name, folder: folder, hint: hint),
);

class _NamePrompt extends StatefulWidget {
  const _NamePrompt({required this.action, this.name, this.folder, this.hint});
  final String action;
  final String? name, folder, hint;

  @override
  State<_NamePrompt> createState() => _NamePromptState();
}

class _NamePromptState extends State<_NamePrompt> {
  late final _name = TextEditingController(text: widget.name ?? '');
  late final _folder = TextEditingController(text: widget.folder ?? '');
  bool _touched = false;

  @override
  void dispose() {
    _name.dispose();
    _folder.dispose();
    super.dispose();
  }

  bool get _nameOk =>
      _name.text.trim().isNotEmpty && SftpPath.isValidName(_name.text);
  bool get _folderOk =>
      widget.folder == null ||
      (_folder.text.startsWith('/') && !_folder.text.contains('\u0000'));
  bool get _valid => _nameOk && _folderOk;

  void _submit() {
    setState(() => _touched = true);
    if (!_valid) return;
    final folder = widget.folder == null
        ? null
        : (_folder.text.length > 1 && _folder.text.endsWith('/')
              ? _folder.text.substring(0, _folder.text.length - 1)
              : _folder.text);
    Navigator.pop(context, (_name.text, folder));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSection(
          topSpacing: 4,
          footer: widget.hint,
          children: [
            AppFormRow(
              label: l10n.r3SftpNameLabel,
              errorText: _touched && !_nameOk ? l10n.r3SftpInvalidName : null,
              child: AppTextField(
                key: const ValueKey('sftp-name-field'),
                controller: _name,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (widget.folder != null)
              AppFormRow(
                label: l10n.r3SftpFolderLabel,
                errorText: _touched && !_folderOk
                    ? l10n.r3SftpInvalidFolder
                    : null,
                child: AppTextField(
                  key: const ValueKey('sftp-folder-field'),
                  controller: _folder,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) => setState(() {}),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: AppButton(
            key: const ValueKey('sftp-name-submit'),
            label: widget.action,
            expand: true,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}
