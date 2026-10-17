import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import '../core/ui/ui.dart';
import '../data/ledger_store.dart';
import '../servers/server_record.dart';
import 'connection_form.dart';
import 'snippet.dart';

/// Full escaped preview. In picker mode it ends with the explicit
/// "insert into draft" action; closing never inserts or sends anything.
Future<bool> _preview(
  BuildContext context,
  CommandSnippet snippet, {
  bool selectForDraft = false,
}) async =>
    await showAppSheet<bool>(
      context,
      title: escapedCommandPreview(snippet.name),
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        final palette = sheetContext.palette;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSection(
              topSpacing: 4,
              header: l10n.snippetFullEscapedPreview,
              footer: l10n.snippetEscapeLegend,
              children: [
                AppRow.custom(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SelectableText(
                      escapedCommandPreview(snippet.content),
                      textDirection: TextDirection.ltr,
                      style: kMonoTextStyle.copyWith(
                        fontSize: 13.5,
                        height: 1.45,
                        color: palette.text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 10, 32, 0),
              child: Text(
                l10n.snippetPreviewNoSend,
                style: sheetContext.footnoteStyle,
              ),
            ),
            if (selectForDraft)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      label: l10n.snippetInsertDraftOnly,
                      expand: true,
                      onPressed: () => Navigator.pop(sheetContext, true),
                    ),
                    const SizedBox(height: 8),
                    AppButton(
                      label: l10n.cancel,
                      kind: AppButtonKind.plain,
                      expand: true,
                      onPressed: () => Navigator.pop(sheetContext, false),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    ) ??
    false;

void _failure(BuildContext context, Object error) {
  final l10n = context.l10n;
  showAppToast(
    context,
    error is LedgerConflict
        ? l10n.snippetChanged
        : error is LocalizedMessage
        ? error.messageFor(l10n)
        : error is ArgumentError
        ? localizedText(error.message ?? '', l10n)
        : l10n.snippetOperationFailed,
  );
}

class SnippetListPage extends StatefulWidget {
  const SnippetListPage({
    super.key,
    required this.store,
    this.selectForDraft = false,
  });
  final LedgerStore store;
  final bool selectForDraft;
  @override
  State<SnippetListPage> createState() => _SnippetListPageState();
}

class _SnippetListPageState extends State<SnippetListPage> {
  List<CommandSnippet> snippets = [];
  bool loading = true, failed = false, busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final items = await widget.store.snippets();
      if (!mounted) {
        return;
      }
      setState(() {
        snippets = items;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  Future<void> edit([CommandSnippet? snippet]) async {
    if (busy) {
      return;
    }
    setState(() => busy = true);
    final saved = await showAppModal<CommandSnippet>(
      context,
      builder: (_) => SnippetEditorPage(store: widget.store, snippet: snippet),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      busy = false;
      if (saved != null) {
        snippets = [
          ...snippets.where((s) => s.id != saved.id),
          saved,
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }
    });
  }

  Future<void> preview(CommandSnippet snippet) async {
    if (busy) {
      return;
    }
    setState(() => busy = true);
    final selected = await _preview(
      context,
      snippet,
      selectForDraft: widget.selectForDraft,
    );
    if (!mounted) {
      return;
    }
    setState(() => busy = false);
    if (selected && widget.selectForDraft) {
      Navigator.pop(context, snippet);
    }
  }

  Future<void> remove(CommandSnippet snippet) async {
    if (busy) {
      return;
    }
    setState(() => busy = true);
    final confirmed = await showAppConfirm(
      context,
      title: LocalizedText((l10n) => l10n.snippetDeleteQuestion),
      message: LocalizedText(
        (l10n) => l10n.snippetDeleteHelp(
          (escapedCommandPreview(snippet.name)).toString(),
        ),
      ),
      action: LocalizedText((l10n) => l10n.snippetDelete),
      dangerous: true,
    );
    if (!mounted) {
      return;
    }
    if (!confirmed) {
      setState(() => busy = false);
      return;
    }
    try {
      await widget.store.deleteSnippet(snippet);
      if (!mounted) {
        return;
      }
      setState(
        () => snippets = snippets.where((s) => s.id != snippet.id).toList(),
      );
    } catch (error) {
      if (mounted) {
        _failure(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  void _menu(CommandSnippet snippet) {
    final l10n = context.l10n;
    showAppActionMenu<void>(
      context,
      title: escapedCommandPreview(snippet.name),
      actions: [
        AppMenuAction(
          label: widget.selectForDraft
              ? l10n.snippetPreviewInsert
              : l10n.snippetFullPreview,
          onPressed: () => preview(snippet),
        ),
        AppMenuAction(label: l10n.serverEdit, onPressed: () => edit(snippet)),
        AppMenuAction(
          label: l10n.connectionDelete,
          destructive: true,
          onPressed: () => remove(snippet),
        ),
      ],
    );
  }

  /// First characters only: the full escaped text lives in the preview.
  String _excerpt(String content) =>
      escapedCommandPreview(String.fromCharCodes(content.runes.take(160)));

  Widget _row(BuildContext context, CommandSnippet snippet) {
    final palette = context.palette;
    final l10n = context.l10n;
    return AppRow.custom(
      key: ValueKey('snippet-${snippet.id}'),
      onTap: () => preview(snippet),
      trailing: IconButton(
        tooltip: l10n.uiConnMoreActions,
        onPressed: busy ? null : () => _menu(snippet),
        icon: Icon(Icons.more_horiz_rounded, color: palette.text2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              escapedCommandPreview(snippet.name),
              style: TextStyle(fontSize: 16, height: 1.3, color: palette.text),
            ),
            const SizedBox(height: 3),
            Text(
              _excerpt(snippet.content),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              style: kMonoTextStyle.copyWith(
                fontSize: 12.5,
                height: 1.35,
                color: palette.text2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              l10n.snippetCharacterCount(snippet.content.length.toString()),
              style: TextStyle(fontSize: 12, color: palette.text3),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    final l10n = context.l10n;
    if (loading) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CupertinoActivityIndicator()),
        ),
      ];
    }
    if (failed) {
      return [
        AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: l10n.snippetReadFailed,
          actions: [
            AppButton(
              label: l10n.serverReload,
              kind: AppButtonKind.tonal,
              onPressed: load,
            ),
          ],
        ),
      ];
    }
    final note = Padding(
      padding: const EdgeInsets.fromLTRB(32, 10, 32, 0),
      child: Text(
        widget.selectForDraft
            ? l10n.snippetSelectPreviewHelp
            : l10n.snippetPlaintextHelp,
        style: context.footnoteStyle,
      ),
    );
    if (snippets.isEmpty) {
      return [
        AppEmptyState(
          icon: Icons.bookmarks_outlined,
          title: l10n.commandSnippets,
          message: l10n.snippetEmptyHelp,
          actions: [
            AppButton(
              label: l10n.snippetAdd,
              icon: Icons.add,
              onPressed: busy ? null : () => edit(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        note,
      ];
    }
    return [
      AppSection(
        children: [for (final snippet in snippets) _row(context, snippet)],
      ),
      note,
    ];
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: widget.selectForDraft
        ? context.l10n.snippetChoose
        : context.l10n.commandSnippets,
    largeTitle: !widget.selectForDraft,
    actions: [
      AppNavButton.icon(
        Icons.add,
        tooltip: context.l10n.snippetAdd,
        onPressed: busy || loading || failed ? null : () => edit(),
      ),
    ],
    children: _body(context),
  );
}

class SnippetEditorPage extends StatefulWidget {
  const SnippetEditorPage({super.key, required this.store, this.snippet});
  final LedgerStore store;
  final CommandSnippet? snippet;
  @override
  State<SnippetEditorPage> createState() => _SnippetEditorPageState();
}

class _SnippetEditorPageState extends State<SnippetEditorPage>
    with LocaleRevalidatingForm<SnippetEditorPage> {
  late final TextEditingController name, content;
  late final String id;
  bool saving = false, dirty = false, allowPop = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.snippet?.name ?? '');
    content = TextEditingController(text: widget.snippet?.content ?? '');
    id = widget.snippet?.id ?? newLocalId();
  }

  @override
  void dispose() {
    name.dispose();
    content.dispose();
    super.dispose();
  }

  CommandSnippet get draft => CommandSnippet(
    id: id,
    name: name.text,
    content: content.text,
    revision: widget.snippet?.revision ?? 0,
  );

  Future<void> cancel() async {
    if (saving) {
      return;
    }
    if (dirty &&
        !await showAppConfirm(
          context,
          title: LocalizedText((l10n) => l10n.snippetDiscardQuestion),
          message: LocalizedText((l10n) => l10n.snippetDiscardHelp),
          action: LocalizedText((l10n) => l10n.connectionDiscardChanges),
        )) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => allowPop = true);
    Navigator.pop(context);
  }

  Future<void> save() async {
    if (saving) {
      return;
    }
    if (!validateForm()) {
      return;
    }
    setState(() => saving = true);
    try {
      final saved = await widget.store.saveSnippet(
        draft,
        isNew: widget.snippet == null,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        allowPop = true;
        saving = false;
      });
      Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        _failure(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    return PopScope(
      canPop: allowPop || (!dirty && !saving),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          cancel();
        }
      },
      child: AppScaffold.modal(
        title: widget.snippet == null ? l10n.snippetAdd : l10n.snippetEdit,
        onCancel: saving ? null : cancel,
        onAction: saving ? null : save,
        actionBusy: saving,
        children: [
          Form(
            key: formKey,
            onChanged: () {
              if (!dirty) {
                setState(() => dirty = true);
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSection(
                  topSpacing: 8,
                  footer: l10n.snippetSaveSafety,
                  children: [
                    ValidatedTextRow(
                      fieldKey: const Key('snippet-name'),
                      label: l10n.snippetName,
                      controller: name,
                      enabled: !saving,
                      maxLength: CommandSnippet.maxNameLength,
                      autocorrect: true,
                      enableSuggestions: true,
                      validator: (value) =>
                          value.trim().isEmpty ||
                              value.length > CommandSnippet.maxNameLength
                          ? l10n.serverNameRange
                          : null,
                    ),
                  ],
                ),
                AppSection(
                  footer: l10n.snippetExactContentHelp,
                  children: [
                    ValidatedTextRow(
                      fieldKey: const Key('snippet-content'),
                      label: l10n.snippetFullContent,
                      controller: content,
                      stacked: true,
                      enabled: !saving,
                      minLines: 6,
                      maxLines: 16,
                      maxLength: CommandSnippet.maxContentLength,
                      exactText: true,
                      mono: true,
                      keyboardType: TextInputType.multiline,
                      validator: (value) =>
                          value.trim().isEmpty ||
                              value.length > CommandSnippet.maxContentLength
                          ? l10n.snippetContentRange
                          : null,
                    ),
                  ],
                ),
                ListenableBuilder(
                  listenable: content,
                  builder: (context, _) => AppSection(
                    header: l10n.snippetFullEscapedPreview,
                    footer: l10n.snippetEscapeLegend,
                    children: [
                      AppRow.custom(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 180),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                escapedCommandPreview(content.text),
                                key: const ValueKey('snippet-escaped-preview'),
                                textDirection: TextDirection.ltr,
                                style: kMonoTextStyle.copyWith(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: palette.text,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
