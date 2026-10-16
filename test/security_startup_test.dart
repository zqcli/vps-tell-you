import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/app.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/providers/provider_directory.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/servers/server_record.dart';

import 'security_store_test.dart' show FakeSecretStore, FakeDeviceAuth;

void main() {
  late Directory directory;
  late LedgerStore store;

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('vps-security-start-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite3',
    );
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  testWidgets('SSH metadata is loaded at launch, before any SSH page opens', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 10, 16);
    await tester.runAsync(() async {
      await store.saveServer(
        ServerRecord(
          id: 's1',
          name: 'hk-01',
          vendor: '',
          createdAt: now,
          updatedAt: now,
        ),
        isNew: true,
      );
      final seed = SecurityController(
        store: store,
        secrets: FakeSecretStore(),
        authenticator: FakeDeviceAuth(),
      );
      await seed.initialize();
      expect(
        await seed.saveCredential(
          name: 'demo',
          kind: CredentialKind.password,
          defaultUsername: 'root',
          secret: 'SYNTHETIC-NOT-A-REAL-PASSWORD',
        ),
        isTrue,
      );
      expect(
        await seed.saveSshConfiguration(
          SshConfiguration(
            serverId: 's1',
            host: '203.0.113.10',
            username: 'root',
            port: 22,
            credentialId: seed.credentials.single.id,
          ),
        ),
        isTrue,
      );
      seed.dispose();
    });

    await tester.pumpWidget(
      LedgerApp(
        openStore: () async => store,
        directory: ProviderDirectory.memory(),
      ),
    );
    await tester.pumpAndSettle();
    final shell = tester.widget<HomeShell>(find.byType(HomeShell));
    expect(shell.controller.security.configFor('s1'), isNotNull);
    expect(tester.takeException(), isNull);
  });

  test('reload never notifies listeners synchronously', () async {
    final security = SecurityController(
      store: store,
      secrets: FakeSecretStore(),
      authenticator: FakeDeviceAuth(),
    );
    addTearDown(security.dispose);
    var notified = 0;
    security.addListener(() => notified++);
    final loading = security.reload();
    expect(notified, 0, reason: 'callers may be inside build()');
    expect(await loading, isTrue);
    expect(notified, greaterThan(0));
  });
}
