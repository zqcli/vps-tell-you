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
            const Text('完整内容预览（转义显示）'),
            const InfoNote(r'换行显示为 \n；回车为 \r；制表为 \t；其他控制字符显示为 \u{…}。反斜线也已转义。'),
            SelectableText(
              escapedCommandPreview(snippet.content),
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            const InfoNote('不会执行或发送任何内容。插入后仍需在终端核对目标、完整草稿并明确 Send。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(selectForDraft ? '取消' : '关闭'),
          ),
          if (selectForDraft)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('仅插入待发送草稿'),
            ),
        ],
      ),
    ) ??
    false;

void _failure(BuildContext context, Object error) {
  final message = error is LedgerConflict
      ? '片段已被修改或删除，请重新打开列表后重试。'
      : error is ArgumentError
      ? error.message.toString()
      : '片段操作未完成，请重试。已保存的内容仍保留。';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      if (!mounted) return;
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
    if (busy) return;
    setState(() => busy = true);
    final saved = await Navigator.push<CommandSnippet>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SnippetEditorPage(store: widget.store, snippet: snippet),
      ),
    );
    if (!mounted) return;
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
    if (busy) return;
    setState(() => busy = true);
    final selected = await _preview(
      context,
      snippet,
      selectForDraft: widget.selectForDraft,
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (selected && widget.selectForDraft) Navigator.pop(context, snippet);
  }

  Future<void> remove(CommandSnippet snippet) async {
    if (busy) return;
    setState(() => busy = true);
    final confirmed = await confirmAction(
      context,
      title: '删除本地片段？',
      message:
          '将删除“${escapedCommandPreview(snippet.name)}”的本地模板，不影响服务器或已插入的草稿。',
      action: '删除片段',
      dangerous: true,
    );
    if (!mounted) return;
    if (!confirmed) {
      setState(() => busy = false);
      return;
    }
    try {
      await widget.store.deleteSnippet(snippet);
      if (!mounted) return;
      setState(
        () => snippets = snippets.where((s) => s.id != snippet.id).toList(),
      );
    } catch (error) {
      if (mounted) _failure(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.selectForDraft ? '选择片段插入草稿' : '命令片段')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : failed
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('片段读取失败，未修改本地数据'),
                TextButton(onPressed: load, child: const Text('重新读取')),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              InfoNote(
                widget.selectForDraft
                    ? '选择后先预览完整内容，只插入待发送草稿。不会自动发送或回车。'
                    : '片段是本地普通文本，请勿保存密码、私钥或令牌。从终端“插入片段”可选入待发送草稿。',
              ),
              FilledButton.icon(
                onPressed: busy ? null : () => edit(),
                icon: const Icon(Icons.add),
                label: const Text('新增片段'),
              ),
              const SizedBox(height: 16),
              if (snippets.isEmpty) const InfoNote('还没有片段。新增自己的常用命令模板。'),
              for (final snippet in snippets) ...[
                LedgerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        escapedCommandPreview(snippet.name),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text('${snippet.content.length} 个字符 · 本地模板'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: busy ? null : () => preview(snippet),
                            child: Text(
                              widget.selectForDraft ? '预览并插入草稿' : '完整预览',
                            ),
                          ),
                          TextButton(
                            onPressed: busy ? null : () => edit(snippet),
                            child: const Text('编辑'),
                          ),
                          TextButton(
                            onPressed: busy ? null : () => remove(snippet),
                            child: const Text('删除'),
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
    if (saving) return;
    if (dirty &&
        !await confirmAction(
          context,
          title: '放弃片段修改？',
          message: '未保存的内容不会写入本地片段。',
          action: '放弃修改',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => allowPop = true);
    Navigator.pop(context);
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final saved = await widget.store.saveSnippet(
        draft,
        isNew: widget.snippet == null,
      );
      if (!mounted) return;
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
      if (!didPop) cancel();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.snippet == null ? '新增片段' : '编辑片段'),
        leading: IconButton(
          tooltip: '取消片段编辑',
          onPressed: saving ? null : cancel,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Form(
        key: form,
        onChanged: () {
          if (!dirty) setState(() => dirty = true);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const InfoNote('本地普通文本，不加密保存。请勿填写秘密。保存不会执行或发送内容。'),
            TextFormField(
              key: const Key('snippet-name'),
              controller: name,
              enabled: !saving,
              maxLength: CommandSnippet.maxNameLength,
              decoration: const InputDecoration(labelText: '片段名称'),
              validator: (value) =>
                  value == null ||
                      value.trim().isEmpty ||
                      value.length > CommandSnippet.maxNameLength
                  ? '名称需为 1–80 个字符'
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
              decoration: const InputDecoration(labelText: '完整内容（保留原始换行与控制字符）'),
              validator: (value) =>
                  value == null ||
                      value.trim().isEmpty ||
                      value.length > CommandSnippet.maxContentLength
                  ? '内容不能为空，最多 16384 个字符'
                  : null,
            ),
            const InfoNote('保存会原样保留内容，包括前后空白、多行、回车及控制字符。请使用完整预览核对。'),
            OutlinedButton(
              onPressed: saving ? null : () => _preview(context, draft),
              child: const Text('完整预览'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? '保存中…' : '保存片段'),
            ),
          ],
        ),
      ),
    ),
  );
}
