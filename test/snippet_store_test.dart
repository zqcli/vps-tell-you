import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/connections/snippet.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/servers/server_record.dart';

void main() {
  late Directory directory;
  late String path;
  late LedgerStore store;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('snippet-synthetic-');
    path = '${directory.path}/ledger.sqlite3';
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
    );
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  test('snippets CRUD preserves full content across restart and versions stale edits', () async {
    const content = '  echo first\r\nsecond\t\x00\x1b[31m\x7f\u202eend  \n';
    final created = await store.saveSnippet(
      const CommandSnippet(id: 'fixture', name: '  Test ', content: content),
      isNew: true,
    );
    expect(created.name, 'Test');
    expect(created.content, content);
    await store.close();
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
    );
    final loaded = (await store.snippets()).single;
    expect(loaded.toMap(), created.toMap());
    final updated = await store.saveSnippet(
      CommandSnippet(
        id: loaded.id,
        name: 'Updated',
        content: '${loaded.content}\r',
      ),
      isNew: false,
    );
    expect(updated.revision, 1);
    await expectLater(
      store.saveSnippet(loaded, isNew: false),
      throwsA(isA<LedgerConflict>()),
    );
    await expectLater(
      store.deleteSnippet(loaded),
      throwsA(isA<LedgerConflict>()),
    );
    await expectLater(
      store.saveSnippet(loaded, isNew: true),
      throwsA(isA<LedgerConflict>()),
    );
    expect((await store.snippets()).single.toMap(), updated.toMap());
    await store.deleteSnippet(updated);
    expect(await store.snippets(), isEmpty);
  });

  test(
    'empty and oversized values rejected, maximum full content retained',
    () async {
      for (final snippet in [
        const CommandSnippet(id: '', name: 'x', content: 'echo'),
        const CommandSnippet(id: 'x', name: '  ', content: 'echo'),
        const CommandSnippet(id: 'x', name: 'x', content: ' \r\n\t'),
        CommandSnippet(id: 'x', name: 'x' * 81, content: 'echo'),
        CommandSnippet(id: 'x', name: 'x', content: 'x' * 16385),
      ]) {
        await expectLater(
          store.saveSnippet(snippet, isNew: true),
          throwsArgumentError,
        );
      }
      expect(await store.snippets(), isEmpty);
      final saved = await store.saveSnippet(
        CommandSnippet(id: 'x', name: 'x' * 80, content: 'x' * 16384),
        isNew: true,
      );
      expect((await store.snippets()).single.content, saved.content);
    },
  );

  test(
    'complete preview visibly escapes CR, LF, controls, bidi and literal slash',
    () {
      const content = 'a\r\nb\t\x00\x1b\x7f\u0085\u202e\\r';
      expect(
        escapedCommandPreview(content),
        'a\\r\\n\nb\\t\\u{0000}\\u{001b}\\u{007f}\\u{0085}\\u{202e}\\\\r',
      );
      final large = '${'x' * CommandSnippet.maxContentLength}\rEND';
      expect(escapedCommandPreview(large), endsWith(r'\rEND'));
      expect(escapedCommandPreview('中文 😀'), '中文 😀');
    },
  );

  test(
    'v3 to v4 only adds snippet table, preserving ledger/security data',
    () async {
      final now = DateTime.utc(2026, 10, 6);
      await store.saveServer(
        ServerRecord(
          id: 'server',
          name: 'fixture',
          vendor: 'fixture',
          host: '127.0.0.1',
          createdAt: now,
          updatedAt: now,
        ),
        isNew: true,
      );
      final serverBefore = (await store.servers()).single.toMap();
      final fxBefore = (await store.fxSettings()).toMap();
      final raw = await databaseFactoryFfiNoIsolate.openDatabase(path);
      await raw.insert('host_trust', {
        'generation': 'fixture-gen',
        'host': '127.0.0.1',
        'port': 22,
        'algorithm': 'fixture',
        'public_key': 'PUBLIC_FIXTURE',
        'fingerprint': 'fixture',
        'verified_at': now.toIso8601String(),
        'revision': 2,
      });
      final trustBefore = await raw.query('host_trust');
      for (final table in [
        'cloud_bindings',
        'cloud_observations',
        'cloud_accounts',
      ]) {
        await raw.execute('DROP TABLE $table');
      }
      await raw.execute('DROP TABLE snippets');
      await raw.execute('DROP TRIGGER server_reminder');
      await raw.execute('DROP TABLE reminder_rules');
      await raw.execute('DROP TABLE app_settings');
      await raw.execute('ALTER TABLE servers DROP COLUMN resources_json');
      await raw.setVersion(3);
      await store.close();
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      expect((await store.servers()).single.toMap(), serverBefore);
      expect((await store.fxSettings()).toMap(), fxBefore);
      final reopened = await databaseFactoryFfiNoIsolate.openDatabase(path);
      expect(await reopened.query('host_trust'), trustBefore);
      expect(await reopened.getVersion(), LedgerStore.schemaVersion);
      expect(await store.snippets(), isEmpty);
      await store.saveSnippet(
        const CommandSnippet(id: 'new', name: 'Test', content: 'echo fixture'),
        isNew: true,
      );
      await store.close();
      store = await LedgerStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      expect((await store.snippets()).single.content, 'echo fixture');
    },
  );
}
