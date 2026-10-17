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
