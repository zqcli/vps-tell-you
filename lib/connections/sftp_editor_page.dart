import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/ui/ui.dart';
import '../l10n/locale_preference.dart';
import 'sftp_session.dart';
import 'sftp_support.dart';

/// Plain-text editor for one remote file (UTF-8, up to 512 KiB).
///
/// Saving first compares the file's size and modification time with what was
/// loaded; if the server copy changed, the user decides whether to overwrite.
/// Pops `true` if something was saved.
class SftpTextEditorPage extends StatefulWidget {
  const SftpTextEditorPage({
    super.key,
    required this.session,
    required this.path,
    required this.name,
    required this.file,
  });
  final SftpSession session;
  final String path, name;
  final SftpTextFile file;

  @override
  State<SftpTextEditorPage> createState() => _SftpTextEditorPageState();
}

class _SftpTextEditorPageState extends State<SftpTextEditorPage> {
  late final TextEditingController _text = TextEditingController(
    text: widget.file.text,
  )..addListener(_edited);
  late String _saved = widget.file.text;
  late int _baseSize = widget.file.size;
  late DateTime? _baseTime = widget.file.mtime;
  bool _saving = false, _wrote = false, _leaving = false;

  bool get _dirty => _text.text != _saved;

  void _edited() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _text.removeListener(_edited);
    _text.dispose();
    super.dispose();
  }

  Future<bool> _changedOnServer() async {
    try {
      final now = await widget.session.stat(widget.path);
      return now.size != _baseSize || now.mtime != _baseTime;
    } on SftpException catch (problem) {
      // Deleted in the meantime: saving simply recreates it.
      if (problem.kind == SftpErrorKind.notFound) return false;
      rethrow;
    }
  }

  Future<void> _save() async {
    if (_saving || !_dirty) return;
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      if (await _changedOnServer()) {
        if (!mounted) return;
        final overwrite = await showAppConfirm(
          context,
          title: l10n.r3SftpConflictTitle,
          message: l10n.r3SftpConflictMessage,
          action: l10n.r3SftpOverwrite,
          dangerous: true,
        );
        if (!overwrite || !mounted) return;
      }
      final content = _text.text;
      await widget.session.writeText(widget.path, content, overwrite: true);
      SftpEntry? after;
      try {
        after = await widget.session.stat(widget.path);
      } on SftpException {
        // The next save will see a changed file and ask; that is safe.
      }
      if (!mounted) return;
      setState(() {
        _saved = content;
        _baseSize = after?.size ?? utf8.encode(content).length;
        _baseTime = after?.mtime;
        _wrote = true;
      });
      showAppToast(context, l10n.r3SftpSaved);
    } on SftpException catch (problem) {
      if (mounted) showAppToast(context, sftpErrorText(l10n, problem));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _close() async {
    if (_leaving) return;
    if (_dirty) {
      final l10n = context.l10n;
      final discard = await showAppConfirm(
        context,
        title: l10n.r3SftpUnsavedTitle,
        message: l10n.r3SftpUnsavedMessage,
        action: l10n.r3SftpDiscard,
        dangerous: true,
      );
      if (!discard || !mounted) return;
    }
    _leaving = true;
    Navigator.of(context).pop(_wrote);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final height = MediaQuery.sizeOf(context).height;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_close());
      },
      child: AppScaffold(
        title: widget.name,
        largeTitle: false,
        leading: AppNavButton.text(
          l10n.r3SftpClose,
          key: const ValueKey('sftp-editor-close'),
          onPressed: _close,
        ),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : AppNavButton.text(
                  l10n.save,
                  key: const ValueKey('sftp-editor-save'),
                  bold: true,
                  onPressed: _dirty ? _save : null,
                ),
        ],
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              l10n.r3SftpEditorSize(
                formatBytes(utf8.encode(_text.text).length),
              ),
              style: TextStyle(fontSize: 12, color: palette.text3),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: height * .6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const ValueKey('sftp-editor-field'),
                controller: _text,
                maxLines: null,
                minLines: 12,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                enableSuggestions: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                style: kMonoTextStyle.copyWith(
                  fontSize: 14,
                  height: 1.4,
                  color: palette.text,
                ),
                cursorColor: palette.primary,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
