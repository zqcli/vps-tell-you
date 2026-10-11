import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/connections/sftp_pages.dart';
import 'package:vps_tell_you/connections/sftp_session.dart';
import 'package:vps_tell_you/connections/ssh_service.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/security/secret_store.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';

import 'support/fake_sftp_session.dart' show FakeLocalFiles;
import 'support/ssh_fixture.dart';

class _Secrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String reference) async => values[reference];
  @override
  Future<void> write(String reference, String value) async =>
      values[reference] = value;
  @override
  Future<void> delete(String reference) async => values.remove(reference);
}

class _NoDeviceAuth implements DeviceAuthenticator {
  @override
  Future<bool> authenticate() async => false;
  @override
  Future<void> cancel() async {}
}

/// The browser on a real loopback SFTP subsystem (AsyncSSH fixture, chrooted
/// to a temporary directory): protocol, real files, real UI.
void main() {
  late Directory work, root;
  late LedgerStore store;
  late SecurityController security;
  late NativeSshService service;
  late SshFixture fixture;

  setUp(() async {
    sqfliteFfiInit();
    work = await Directory.systemTemp.createTemp('sftp-ui-loopback-');
    root = await Directory('${work.path}/root').create();
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${work.path}/ledger.db',
    );
    security = SecurityController(
      store: store,
      secrets: _Secrets(),
      authenticator: _NoDeviceAuth(),
    );
    await security.initialize();
    await security.saveCredential(
      name: 'Fixture',
      kind: CredentialKind.password,
      defaultUsername: 'fixture',
      secret: 'synthetic-password-only',
      passphrase: null,
      savePassphrase: false,
    );
    service = NativeSshService(security: security);
    fixture = await SshFixture.start(sftpRoot: root.path);
  });

  tearDown(() async {
    service.dispose();
    await fixture.close();
    security.dispose();
    await store.close();
    await work.delete(recursive: true);
  });

  Future<void> pumpReal(WidgetTester tester, [int rounds = 20]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('browse, create, upload, edit and delete against real SFTP', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    File('${root.path}/readme.txt').writeAsStringSync('hello 你好');
    Directory('${root.path}/docs').createSync();
    final upload = File('${work.path}/upload.bin')
      ..writeAsBytesSync(List.generate(200000, (i) => i % 251));
    final local = FakeLocalFiles(work)..picks = [upload];

    late SftpSession session;
    await tester.runAsync(() async {
      session = await service.connectSftp(
        SshTarget(
          name: 'loopback',
          host: '127.0.0.1',
          port: fixture.port,
          username: 'fixture',
          credentialId: security.credentials.single.id,
        ),
        verifyHost: (_) async => true,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SftpBrowserPage(session: session, localFiles: local),
      ),
    );
    await pumpReal(tester);
    Finder entry(String name) => find.byKey(ValueKey('sftp-entry-$name'));
    expect(entry('docs'), findsOneWidget);
    expect(entry('readme.txt'), findsOneWidget);
    expect(find.text('Root'), findsOneWidget); // chroot root is "/"

    // Create a folder and enter it.
    await tester.tap(find.byKey(const ValueKey('sftp-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sftp-new-folder')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('sftp-name-field')),
      'inbox',
    );
    await tester.tap(find.byKey(const ValueKey('sftp-name-submit')));
    await pumpReal(tester);
    expect(Directory('${root.path}/inbox').existsSync(), isTrue);
    await tester.tap(entry('inbox'));
    await pumpReal(tester);

    // Upload a file into it; the list shows it afterwards.
    await tester.tap(find.byKey(const ValueKey('sftp-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sftp-upload')));
    await pumpReal(tester, 60);
    expect(
      File('${root.path}/inbox/upload.bin').readAsBytesSync(),
      upload.readAsBytesSync(),
    );
    expect(entry('upload.bin'), findsOneWidget);
    expect(Directory('${root.path}/inbox').listSync().map((e) => e.path), [
      '${root.path}/inbox/upload.bin',
    ], reason: 'no temporary files left behind');

    // Download it back through the UI.
    await tester.tap(entry('upload.bin'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sftp-action-download')));
    await pumpReal(tester, 60);
    expect(
      File('${work.path}/SFTP Downloads/upload.bin').readAsBytesSync(),
      upload.readAsBytesSync(),
    );

    // Edit the text file at the top level and save.
    await tester.tap(find.byKey(const ValueKey('sftp-up')));
    await pumpReal(tester);
    await tester.tap(entry('readme.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sftp-action-edit')));
    await pumpReal(tester);
    await tester.enterText(
      find.byKey(const ValueKey('sftp-editor-field')),
      'edited 你好',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sftp-editor-save')));
    await pumpReal(tester);
    expect(File('${root.path}/readme.txt').readAsStringSync(), 'edited 你好');
    await tester.tap(find.byKey(const ValueKey('sftp-editor-close')));
    await tester.pumpAndSettle();

    // Delete the (now non-empty) folder recursively.
    await tester.longPress(entry('inbox'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sftp-action-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await pumpReal(tester);
    expect(find.text('Delete folder and everything in it?'), findsOneWidget);
    await tester.tap(find.text('Delete everything'));
    await pumpReal(tester, 60);
    expect(Directory('${root.path}/inbox').existsSync(), isFalse);
    expect(entry('inbox'), findsNothing);
    expect(tester.takeException(), isNull);

    // Leaving closes the connection (and lets its close timer finish).
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(seconds: 4));
    await fixture.waitFor('closed');
  });
}
