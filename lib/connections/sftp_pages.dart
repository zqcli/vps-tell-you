import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../core/ui/ui.dart';
import '../l10n/locale_preference.dart';
import 'sftp_editor_page.dart';
import 'sftp_session.dart';
import 'sftp_support.dart';
import 'sftp_transfer_widgets.dart';

enum SftpSort { name, size, time }

const _pageSize = 200;

/// File manager for one [SftpSession].
///
/// Used full-screen after a standalone SFTP connection, and as a page sheet on
/// top of a running terminal ([sheet]), where closing only ends the SFTP
/// channel. With [ownsSession] the session is closed when the page goes away.
class SftpBrowserPage extends StatefulWidget {
  const SftpBrowserPage({
    super.key,
    required this.session,
    this.ownsSession = true,
    this.sheet = false,
    this.initialPath,
    this.localFiles = const SystemSftpLocalFiles(),
    this.onClosed,
  });
  final SftpSession session;
  final bool ownsSession, sheet;
  final String? initialPath;
  final SftpLocalFiles localFiles;

  /// Runs once after the session was closed because this page went away.
  final FutureOr<void> Function()? onClosed;

  @override
  State<SftpBrowserPage> createState() => _SftpBrowserPageState();
}

class _SftpBrowserPageState extends State<SftpBrowserPage>
    with WidgetsBindingObserver {
  late final SftpTransferQueue _queue;
  final _search = TextEditingController();
  String _path = '/';
  List<SftpEntry> _entries = const [];
  bool _loaded = false, _loading = true, _ended = false, _closing = false;
  SftpException? _loadError;
  SftpSort _sort = SftpSort.name;
  bool _showHidden = false;
  int _limit = _pageSize, _working = 0, _loadSeq = 0;
  String _requested = '/';
  // A system picker or share sheet backgrounds the app on Android; that must
  // not look like the app being left.
  bool _externalUi = false;

  SftpSession get _session => widget.session;
  bool get _isRoot => _path == '/';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _queue = SftpTransferQueue(
      session: _session,
      local: widget.localFiles,
      resolveConflict: _resolveConflict,
      onFinished: _transferFinished,
    )..addListener(_queueChanged);
    _start();
  }

  Future<void> _start() async {
    var start = widget.initialPath;
    if (start == null) {
      try {
        start = await _session.home();
      } on SftpException catch (problem) {
        if (_isLost(problem)) return _markEnded();
        start = '/';
      }
    }
    if (mounted) await _open(start, initial: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _queue.removeListener(_queueChanged);
    final owns = widget.ownsSession;
    final onClosed = widget.onClosed;
    final session = _session;
    final queue = _queue;
    // Let a running transfer clean up its partial files before the channel
    // goes away.
    unawaited(
      queue.shutdown().whenComplete(() async {
        if (owns) {
          await session.close();
          await onClosed?.call();
        }
        queue.dispose();
      }),
    );
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.sheet || !widget.ownsSession || _externalUi) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _exit(context.l10n.r3SftpBackgroundClosed);
    }
  }

  void _queueChanged() {
    if (mounted) setState(() {});
  }

  bool _isLost(SftpException problem) =>
      problem.kind == SftpErrorKind.connectionLost || !_session.isAlive;

  void _markEnded() {
    if (mounted && !_ended) setState(() => _ended = true);
  }

  /// Leaves the page, handing [reason] to whoever pushed it.
  void _exit([String? reason]) {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop(reason);
  }

  // ------------------------------------------------------------- loading

  Future<void> _open(String path, {bool initial = false}) async {
    final seq = ++_loadSeq;
    _requested = path;
    setState(() => _loading = true);
    try {
      final list = await _session.list(path);
      if (!mounted || seq != _loadSeq) return;
      final scroll = PrimaryScrollController.maybeOf(context);
      final changed = path != _path;
      setState(() {
        _path = path;
        _entries = list;
        _loaded = true;
        _loadError = null;
        _loading = false;
        _limit = _pageSize;
        if (changed) _search.clear();
      });
      if (changed && scroll != null && scroll.hasClients) scroll.jumpTo(0);
    } on SftpException catch (problem) {
      if (!mounted || seq != _loadSeq) return;
      if (_isLost(problem)) return _markEnded();
      setState(() {
        _loading = false;
        if (!_loaded) _loadError = problem;
      });
      if (_loaded) _toastError(problem);
    }
  }

  Future<void> _refresh() => _open(_path);

  void _toast(String message, {String? action, VoidCallback? onAction}) {
    if (mounted) {
      showAppToast(context, message, actionLabel: action, onAction: onAction);
    }
  }

  void _toastError(Object problem, {int? maxEntries}) {
    if (!mounted) return;
    if (problem is SftpException && _isLost(problem)) {
      return _markEnded();
    }
    _toast(sftpErrorText(context.l10n, problem, maxEntries: maxEntries));
  }

  /// Runs a mutation with a busy overlay; reports typed errors as toasts.
  Future<bool> _work(
    Future<void> Function() action, {
    int? maxEntries,
    bool reload = true,
  }) async {
    setState(() => _working++);
    try {
      await action();
      if (mounted && reload) unawaited(_open(_path));
      return true;
    } on SftpException catch (problem) {
      _toastError(problem, maxEntries: maxEntries);
      return false;
    } finally {
      if (mounted) setState(() => _working--);
    }
  }

  List<SftpEntry> _visible() {
    final needle = _search.text.trim().toLowerCase();
    final list = [
      for (final entry in _entries)
        if ((_showHidden || !entry.name.startsWith('.')) &&
            (needle.isEmpty || entry.name.toLowerCase().contains(needle)))
          entry,
    ];
    int byName(SftpEntry a, SftpEntry b) {
      final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return c != 0 ? c : a.name.compareTo(b.name);
    }

    list.sort((a, b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      return switch (_sort) {
        SftpSort.name => byName(a, b),
        SftpSort.size =>
          (b.size ?? -1) != (a.size ?? -1)
              ? (b.size ?? -1).compareTo(a.size ?? -1)
              : byName(a, b),
        SftpSort.time =>
          (b.mtime?.millisecondsSinceEpoch ?? 0) !=
                  (a.mtime?.millisecondsSinceEpoch ?? 0)
              ? (b.mtime?.millisecondsSinceEpoch ?? 0).compareTo(
                  a.mtime?.millisecondsSinceEpoch ?? 0,
                )
              : byName(a, b),
      };
    });
    return list;
  }

  // ------------------------------------------------------------- actions

  void _tap(SftpEntry entry) {
    if (_working > 0) return;
    if (entry.isDir) {
      unawaited(_open(entry.path));
    } else {
      unawaited(_showActions(entry));
    }
  }

  Future<void> _showActions(SftpEntry entry) {
    final l10n = context.l10n;
    final canEdit =
        !entry.isDir &&
        (entry.isFile || !entry.isLink) &&
        (entry.size == null || entry.size! <= sftpDefaultTextLimit);
    return showAppActionMenu<void>(
      context,
      title: entry.name,
      actions: [
        if (entry.isDir)
          AppMenuAction(
            key: const ValueKey('sftp-action-open'),
            label: l10n.r3SftpOpen,
            onPressed: () => _open(entry.path),
          ),
        if (canEdit)
          AppMenuAction(
            key: const ValueKey('sftp-action-edit'),
            label: l10n.r3SftpView,
            onPressed: () => _edit(entry),
          ),
        if (entry.isFile)
          AppMenuAction(
            key: const ValueKey('sftp-action-download'),
            label: l10n.r3SftpDownload,
            onPressed: () => _download(entry),
          ),
        AppMenuAction(
          key: const ValueKey('sftp-action-rename'),
          label: l10n.r3SftpRename,
          onPressed: () => _rename(entry),
        ),
        AppMenuAction(
          key: const ValueKey('sftp-action-copy'),
          label: l10n.r3SftpCopyPath,
          onPressed: () => _copyPath(entry),
        ),
        AppMenuAction(
          key: const ValueKey('sftp-action-delete'),
          label: l10n.r3SftpDelete,
          destructive: true,
          onPressed: () => _delete(entry),
        ),
      ],
    );
  }

  Future<void> _copyPath(SftpEntry entry) async {
    final message = context.l10n.r3SftpPathCopied;
    await Clipboard.setData(ClipboardData(text: entry.path));
    _toast(message);
  }

  Future<void> _edit(SftpEntry entry) async {
    SftpTextFile? file;
    final ok = await _work(() async {
      file = await _session.readText(entry.path);
    }, reload: false);
    if (!ok || file == null || !mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SftpTextEditorPage(
          session: _session,
          path: entry.path,
          name: entry.name,
          file: file!,
        ),
      ),
    );
    if (changed == true && mounted) unawaited(_open(_path));
  }

  Future<bool> _confirmLarge(String name, int? size) async {
    if (size == null || size < sftpLargeFileBytes) return true;
    final l10n = context.l10n;
    return showAppConfirm(
      context,
      title: l10n.r3SftpLargeTitle,
      message: l10n.r3SftpLargeMessage(name, formatBytes(size)),
      action: l10n.r3SftpContinue,
    );
  }

  Future<void> _download(SftpEntry entry) async {
    if (!await _confirmLarge(entry.name, entry.size) || !mounted) return;
    _queue.enqueueDownload(entry);
  }

  Future<void> _upload() async {
    List<File> picked;
    _externalUi = true;
    try {
      picked = await widget.localFiles.pickUploads();
    } catch (_) {
      picked = const [];
    } finally {
      _externalUi = false;
    }
    if (!mounted) return;
    var queued = 0;
    for (final file in picked) {
      int? size;
      try {
        size = await file.length();
      } catch (_) {}
      if (!mounted) return;
      if (!await _confirmLarge(p.basename(file.path), size) || !mounted) {
        unawaited(widget.localFiles.discardPicked(file));
        continue;
      }
      _queue.enqueueUpload(file, _path);
      queued++;
    }
    if (queued > 1) _toast(context.l10n.r3SftpUploadsQueued(queued));
  }

  Future<bool> _resolveConflict(String name) async {
    if (!mounted) return false;
    final l10n = context.l10n;
    return showAppConfirm(
      context,
      title: l10n.r3SftpExistsTitle(name),
      message: l10n.r3SftpExistsMessage,
      action: l10n.r3SftpOverwrite,
      dangerous: true,
    );
  }

  void _transferFinished(SftpTransferItem item) {
    if (!mounted) return;
    final l10n = context.l10n;
    if (item.kind == SftpTransferKind.upload &&
        item.state == SftpTransferState.done &&
        p.posix.dirname(item.remotePath) == _path) {
      unawaited(_open(_path));
    }
    if (item.state == SftpTransferState.done &&
        item.kind == SftpTransferKind.download &&
        item.savedPath != null) {
      final saved = File(item.savedPath!);
      _toast(
        l10n.r3SftpSavedTo('$sftpDownloadsFolder/${p.basename(saved.path)}'),
        action: l10n.r3SftpShare,
        onAction: () => _share(saved),
      );
    } else if (item.state == SftpTransferState.failed && item.error != null) {
      if (_isLost(item.error!)) return _markEnded();
      _toast('${item.name}: ${sftpErrorText(l10n, item.error!)}');
    }
  }

  Future<void> _share(File file) async {
    _externalUi = true;
    try {
      final box = context.findRenderObject();
      await widget.localFiles.share(
        file,
        origin: box is RenderBox && box.hasSize
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } finally {
      _externalUi = false;
    }
  }

  Future<void> _createFolder() async {
    final l10n = context.l10n;
    final name = await _promptName(
      context,
      title: l10n.r3SftpNewFolder,
      action: l10n.r3SftpCreate,
    );
    if (name == null || !mounted) return;
    await _work(() => _session.mkdir(SftpPath.join(_path, name.$1)));
  }

  Future<void> _createFile() async {
    final l10n = context.l10n;
    final name = await _promptName(
      context,
      title: l10n.r3SftpNewFile,
      action: l10n.r3SftpCreate,
    );
    if (name == null || !mounted) return;
    await _work(() => _session.createEmptyFile(SftpPath.join(_path, name.$1)));
  }

  Future<void> _rename(SftpEntry entry) async {
    final l10n = context.l10n;
    final result = await _promptName(
      context,
      title: l10n.r3SftpRenameTitle,
      action: l10n.save,
      name: entry.name,
      folder: SftpPath.parent(entry.path),
      hint: l10n.r3SftpRenameHint,
    );
    if (result == null || !mounted) return;
    final target = SftpPath.join(result.$2 ?? _path, result.$1);
    if (target == entry.path) return;
    await _work(() => _session.rename(entry.path, target));
  }

  Future<void> _delete(SftpEntry entry) async {
    final l10n = context.l10n;
    // Links are removed, never followed, whatever they point to.
    final plain = !entry.isDir || entry.isLink;
    final first = await showAppConfirm(
      context,
      title: l10n.r3SftpDeleteTitle(entry.name),
      message: plain
          ? l10n.r3SftpDeleteFileMessage
          : l10n.r3SftpDeleteFolderMessage,
      action: l10n.r3SftpDelete,
      dangerous: true,
    );
    if (!first || !mounted) return;
    if (plain) {
      if (await _work(() => _session.deleteFile(entry.path)) && mounted) {
        _toast(l10n.r3SftpDeleted);
      }
      return;
    }
    var notEmpty = false;
    final done = await _work(() async {
      try {
        await _session.deleteEmptyDirectory(entry.path);
      } on SftpException catch (problem) {
        if (problem.kind != SftpErrorKind.notEmpty) rethrow;
        notEmpty = true;
      }
    }, reload: false);
    if (!mounted) return;
    if (done && !notEmpty) {
      unawaited(_open(_path));
      return _toast(l10n.r3SftpDeleted);
    }
    if (!notEmpty) return;
    final second = await showAppConfirm(
      context,
      title: l10n.r3SftpDeleteRecursiveTitle,
      message: l10n.r3SftpDeleteRecursiveMessage(
        entry.name,
        sftpDefaultRecursiveLimit,
      ),
      action: l10n.r3SftpDeleteRecursiveAction,
      dangerous: true,
    );
    if (!second || !mounted) return;
    var removed = 0;
    final ok = await _work(() async {
      removed = await _session.deleteRecursive(entry.path);
    }, maxEntries: sftpDefaultRecursiveLimit);
    if (ok && mounted) _toast(l10n.r3SftpDeletedCount(removed));
  }

  Future<void> _addMenu() {
    final l10n = context.l10n;
    return showAppActionMenu<void>(
      context,
      actions: [
        AppMenuAction(
          key: const ValueKey('sftp-new-folder'),
          label: l10n.r3SftpNewFolder,
          onPressed: _createFolder,
        ),
        AppMenuAction(
          key: const ValueKey('sftp-new-file'),
          label: l10n.r3SftpNewFile,
          onPressed: _createFile,
        ),
        AppMenuAction(
          key: const ValueKey('sftp-upload'),
          label: l10n.r3SftpUpload,
          onPressed: _upload,
        ),
      ],
    );
  }

  Future<void> _viewMenu() => showAppSheet<void>(
    context,
    title: context.l10n.r3SftpSort,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheet) {
        final l10n = sheetContext.l10n;
        final p = sheetContext.palette;
        void pick(SftpSort value) {
          setState(() => _sort = value);
          setSheet(() {});
        }

        Widget option(SftpSort value, String label) => AppRow(
          key: ValueKey('sftp-sort-${value.name}'),
          title: label,
          trailing: _sort == value
              ? Icon(Icons.check_rounded, size: 22, color: p.primary)
              : null,
          onTap: () => pick(value),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSection(
              topSpacing: 4,
              children: [
                option(SftpSort.name, l10n.r3SftpSortName),
                option(SftpSort.size, l10n.r3SftpSortSize),
                option(SftpSort.time, l10n.r3SftpSortTime),
              ],
            ),
            AppSection(
              topSpacing: 16,
              children: [
                AppSwitchRow(
                  key: const ValueKey('sftp-hidden'),
                  title: l10n.r3SftpShowHidden,
                  value: _showHidden,
                  onChanged: (value) {
                    setState(() {
                      _showHidden = value;
                      _limit = _pageSize;
                    });
                    setSheet(() {});
                  },
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  Future<void> _requestClose() async {
    if (_closing) return;
    if (_queue.busy) {
      final l10n = context.l10n;
      final confirmed = await showAppConfirm(
        context,
        title: l10n.r3SftpCloseBusyTitle,
        message: l10n.r3SftpCloseBusyMessage,
        action: l10n.r3SftpCloseBusyAction,
        dangerous: true,
      );
      if (!confirmed || !mounted) return;
    }
    _exit();
  }

  // --------------------------------------------------------------- build

  IconData _icon(SftpEntry e) => e.isDir
      ? (e.isLink ? Icons.folder_shared_outlined : Icons.folder_rounded)
      : e.isLink
      ? Icons.link_rounded
      : Icons.insert_drive_file_outlined;

  Color _tint(SftpEntry e) => e.isDir
      ? AppTints.blue
      : e.isLink
      ? AppTints.teal
      : AppTints.slate;

  Widget _row(SftpEntry e) {
    final l10n = context.l10n;
    final detail = [
      if (!e.isDir && e.size != null) formatBytes(e.size!),
      if (e.mtime != null) formatModified(e.mtime!),
    ].join(' · ');
    // Permissions as a second, quieter line: a side column would squeeze the
    // name at large text sizes.
    final subtitle = [
      if (detail.isNotEmpty) detail,
      if (e.mode.length > 1) e.mode.substring(1),
    ].join('\n');
    return _SwipeRow(
      key: ValueKey('sftp-entry-${e.name}'),
      actions: [
        _SwipeAction(
          key: ValueKey('sftp-swipe-rename-${e.name}'),
          color: context.palette.primary,
          icon: Icons.drive_file_rename_outline_rounded,
          label: l10n.rename,
          onTap: () => _rename(e),
        ),
        _SwipeAction(
          key: ValueKey('sftp-swipe-delete-${e.name}'),
          color: context.palette.red,
          icon: Icons.delete_outline_rounded,
          label: l10n.r3SftpDelete,
          onTap: () => _delete(e),
        ),
      ],
      // Long names stop at three lines; the action sheet shows the full one.
      child: AppRow.custom(
        leading: AppIconSquare(icon: _icon(e), color: _tint(e)),
        chevron: e.isDir,
        onTap: () => _tap(e),
        onLongPress: () => _showActions(e),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                e.name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.3,
                  color: context.palette.text,
                ),
              ),
              if (subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: context.palette.text2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    if (_ended) {
      return AppEmptyState(
        icon: Icons.link_off_rounded,
        title: l10n.r3SftpErrConnectionLost,
        actions: [
          AppButton(
            key: const ValueKey('sftp-ended-close'),
            label: l10n.r3SftpClose,
            kind: AppButtonKind.tonal,
            onPressed: _exit,
          ),
        ],
      );
    }
    if (!_loaded) {
      if (_loadError != null) {
        return AppEmptyState(
          icon: Icons.folder_off_outlined,
          title: l10n.r3SftpLoadFailed,
          message: sftpErrorText(l10n, _loadError!),
          actions: [
            AppButton(
              key: const ValueKey('sftp-retry'),
              label: l10n.r3SftpRetry,
              kind: AppButtonKind.tonal,
              onPressed: () => _open(_requested),
            ),
          ],
        );
      }
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    final visible = _visible();
    final shown = visible.take(_limit).toList();
    final rows = <Widget>[
      if (!_isRoot)
        AppRow(
          key: const ValueKey('sftp-up'),
          icon: Icons.drive_folder_upload_outlined,
          iconColor: AppTints.slate,
          title: l10n.r3SftpUp,
          subtitle: SftpPath.parent(_path),
          onTap: () => _open(SftpPath.parent(_path)),
        ),
      for (final entry in shown) _row(entry),
      if (visible.length > shown.length)
        AppRow(
          key: const ValueKey('sftp-more-rows'),
          title: l10n.r3SftpShowMore(visible.length - shown.length),
          center: true,
          onTap: () => setState(() => _limit += _pageSize),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Center(child: CupertinoActivityIndicator()),
          ),
        if (rows.isNotEmpty) AppSection(topSpacing: 12, children: rows),
        if (visible.isEmpty)
          AppEmptyState(
            icon: Icons.folder_open_rounded,
            title: _search.text.trim().isEmpty
                ? l10n.r3SftpEmpty
                : l10n.r3SftpNoMatch,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = _isRoot ? l10n.r3SftpRoot : SftpPath.basename(_path);
    return PopScope(
      canPop: !_queue.busy && !_closing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_closing) unawaited(_requestClose());
      },
      child: Stack(
        children: [
          AppScaffold(
            title: title,
            largeTitle: false,
            leading: widget.sheet
                ? AppNavButton.text(
                    l10n.r3SftpClose,
                    key: const ValueKey('sftp-close'),
                    onPressed: _requestClose,
                  )
                : null,
            actions: _ended
                ? const []
                : [
                    AppNavButton.icon(
                      Icons.add_rounded,
                      key: const ValueKey('sftp-add'),
                      tooltip: l10n.r3SftpAdd,
                      onPressed: _loaded ? _addMenu : null,
                    ),
                    AppNavButton.icon(
                      Icons.more_horiz_rounded,
                      key: const ValueKey('sftp-more'),
                      tooltip: l10n.r3SftpMore,
                      onPressed: _viewMenu,
                    ),
                  ],
            onRefresh: _ended ? null : _refresh,
            bottomBar: _queue.items.isEmpty
                ? null
                : SftpTransferBar(
                    key: const ValueKey('sftp-transfer-bar'),
                    queue: _queue,
                    onShare: _share,
                  ),
            children: [
              if (!_ended) ...[
                SftpBreadcrumb(path: _path, onOpen: _open),
                AppSearchField(
                  controller: _search,
                  placeholder: l10n.r3SftpSearch,
                  onChanged: (_) => setState(() => _limit = _pageSize),
                ),
              ],
              _body(context),
            ],
          ),
          if (_working > 0)
            const Positioned.fill(
              child: ModalBarrier(dismissible: false, color: Color(0x14000000)),
            ),
          if (_working > 0)
            const Center(
              child: CupertinoActivityIndicator(
                key: ValueKey('sftp-working'),
                radius: 14,
              ),
            ),
        ],
      ),
    );
  }
}

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

class _SwipeAction {
  const _SwipeAction({
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
class _SwipeRow extends StatefulWidget implements AppSectionItem {
  const _SwipeRow({super.key, required this.actions, required this.child});
  final List<_SwipeAction> actions;
  final Widget child;

  @override
  double get separatorInset => 58;

  @override
  State<_SwipeRow> createState() => _SwipeRowState();
}

class _SwipeRowState extends State<_SwipeRow> {
  static const _buttonWidth = 76.0;
  static _SwipeRowState? _open;
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
Future<(String, String?)?> _promptName(
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
