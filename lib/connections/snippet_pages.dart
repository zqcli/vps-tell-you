import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/ledger_store.dart';
import '../servers/server_record.dart';
import 'snippet.dart';

Future<bool> _preview(
  BuildContext context,
  CommandSnippet snippet, {
  bool selectForDraft = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(escapedCommandPreview(snippet.name)),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.snippetFullEscapedPreview),
            InfoNote(context.l10n.snippetEscapeLegend),
            SelectableText(
              escapedCommandPreview(snippet.content),
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            InfoNote(context.l10n.snippetPreviewNoSend),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              selectForDraft
                  ? context.l10n.cancel
                  : context.l10n.connectionClose,
            ),
          ),
          if (selectForDraft)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.snippetInsertDraftOnly),
            ),
        ],
      ),
    ) ??
    false;

void _failure(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Builder(
        builder: (context) => Text(
          error is LedgerConflict
              ? context.l10n.snippetChanged
              : error is LocalizedMessage
              ? error.messageFor(context.l10n)
              : error is ArgumentError
              ? localizedText(error.message ?? '', context.l10n)
              : context.l10n.snippetOperationFailed,
        ),
      ),
    ),
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
    final saved = await Navigator.push<CommandSnippet>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SnippetEditorPage(store: widget.store, snippet: snippet),
      ),
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
    final confirmed = await confirmAction(
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.selectForDraft
            ? context.l10n.snippetChoose
            : context.l10n.commandSnippets,
      ),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : failed
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.snippetReadFailed),
                TextButton(
                  onPressed: load,
                  child: Text(context.l10n.serverReload),
                ),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              InfoNote(
                widget.selectForDraft
                    ? context.l10n.snippetSelectPreviewHelp
                    : context.l10n.snippetPlaintextHelp,
              ),
              FilledButton.icon(
                onPressed: busy ? null : () => edit(),
                icon: const Icon(Icons.add),
                label: Text(context.l10n.snippetAdd),
              ),
              const SizedBox(height: 16),
              if (snippets.isEmpty) InfoNote(context.l10n.snippetEmptyHelp),
              for (final snippet in snippets) ...[
                LedgerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        escapedCommandPreview(snippet.name),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        context.l10n.snippetCharacterCount(
                          (snippet.content.length).toString(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: busy ? null : () => preview(snippet),
                            child: Text(
                              widget.selectForDraft
                                  ? context.l10n.snippetPreviewInsert
                                  : context.l10n.snippetFullPreview,
                            ),
                          ),
                          TextButton(
                            onPressed: busy ? null : () => edit(snippet),
                            child: Text(context.l10n.serverEdit),
                          ),
                          TextButton(
                            onPressed: busy ? null : () => remove(snippet),
                            child: Text(context.l10n.connectionDelete),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
  );
}

class SnippetEditorPage extends StatefulWidget {
  const SnippetEditorPage({super.key, required this.store, this.snippet});
  final LedgerStore store;
  final CommandSnippet? snippet;
  @override
  State<SnippetEditorPage> createState() => _SnippetEditorPageState();
}

class _SnippetEditorPageState extends State<SnippetEditorPage> {
  final form = GlobalKey<FormState>();
  bool _hasValidated = false;
  String? _validationLocale;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.l10n.localeName;
    if (_validationLocale != null &&
        _validationLocale != next &&
        _hasValidated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          form.currentState?.validate();
        }
      });
    }
    _validationLocale = next;
  }

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
        !await confirmAction(
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
    _hasValidated = true;
    if (!form.currentState!.validate()) {
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
  Widget build(BuildContext context) => PopScope(
    canPop: allowPop || (!dirty && !saving),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) {
        cancel();
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.snippet == null
              ? context.l10n.snippetAdd
              : context.l10n.snippetEdit,
        ),
        leading: IconButton(
          tooltip: context.l10n.snippetCancelEdit,
          onPressed: saving ? null : cancel,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Form(
        key: form,
        onChanged: () {
          if (!dirty) {
            setState(() => dirty = true);
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            InfoNote(context.l10n.snippetSaveSafety),
            TextFormField(
              key: const Key('snippet-name'),
              controller: name,
              enabled: !saving,
              maxLength: CommandSnippet.maxNameLength,
              decoration: InputDecoration(labelText: context.l10n.snippetName),
              validator: (value) =>
                  value == null ||
                      value.trim().isEmpty ||
                      value.length > CommandSnippet.maxNameLength
                  ? context.l10n.serverNameRange
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('snippet-content'),
              controller: content,
              enabled: !saving,
              minLines: 6,
              maxLines: 16,
              maxLength: CommandSnippet.maxContentLength,
              autocorrect: false,
              enableSuggestions: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                labelText: context.l10n.snippetFullContent,
              ),
              validator: (value) =>
                  value == null ||
                      value.trim().isEmpty ||
                      value.length > CommandSnippet.maxContentLength
                  ? context.l10n.snippetContentRange
                  : null,
            ),
            InfoNote(context.l10n.snippetExactContentHelp),
            OutlinedButton(
              onPressed: saving ? null : () => _preview(context, draft),
              child: Text(context.l10n.snippetFullPreview),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: saving ? null : save,
              child: Text(
                saving
                    ? context.l10n.connectionSaving
                    : context.l10n.snippetSave,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
