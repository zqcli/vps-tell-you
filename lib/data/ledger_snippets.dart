part of 'ledger_store.dart';

extension LedgerSnippets on LedgerStore {
  Future<List<CommandSnippet>> snippets() async => (await _db.query(
    'snippets',
    orderBy: 'name COLLATE NOCASE, id',
  )).map(CommandSnippet.fromMap).toList(growable: false);

  /// Returns the committed value without a fallible post-commit read. Content
  /// is stored byte-for-byte as supplied, including CR, whitespace and controls.
  Future<CommandSnippet> saveSnippet(
    CommandSnippet snippet, {
    required bool isNew,
  }) async {
    final error = snippet.validate();
    if (error != null) {
      throw LocalizedArgumentError((l10n) => snippet.validate(l10n: l10n)!);
    }
    final saved = CommandSnippet(
      id: snippet.id,
      name: snippet.name.trim(),
      content: snippet.content,
      revision: isNew ? 0 : snippet.revision + 1,
    );
    await _db.transaction((txn) async {
      if (isNew) {
        if ((await txn.query(
          'snippets',
          where: 'id = ?',
          whereArgs: [saved.id],
        )).isNotEmpty) {
          throw const LedgerConflict();
        }
        await txn.insert('snippets', saved.toMap());
      } else {
        final map = saved.toMap()..remove('id');
        final changed = await txn.update(
          'snippets',
          map,
          where: 'id = ? AND revision = ?',
          whereArgs: [saved.id, snippet.revision],
        );
        if (changed != 1) {
          throw const LedgerConflict();
        }
      }
    });
    return saved;
  }

  Future<void> deleteSnippet(CommandSnippet snippet) async {
    final changed = await _db.delete(
      'snippets',
      where: 'id = ? AND revision = ?',
      whereArgs: [snippet.id, snippet.revision],
    );
    if (changed != 1) {
      throw const LedgerConflict();
    }
  }
}
