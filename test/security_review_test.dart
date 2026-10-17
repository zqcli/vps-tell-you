import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/security/host_trust.dart';
import 'package:vps_tell_you/security/host_trust_pages.dart';
import 'package:vps_tell_you/security/secret_store.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/security/credential_form.dart';
import 'package:vps_tell_you/security/credential_pages.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';

class ReviewSecrets implements SecretStore {
  final values = <String, String>{};
  int reads = 0;
  @override
  Future<String?> read(String reference) async {
    reads++;
    return values[reference];
  }

  @override
  Future<void> write(String reference, String value) async {
    values[reference] = value;
  }

  @override
  Future<void> delete(String reference) async {
    values.remove(reference);
  }
}

class ReviewAuthentication implements DeviceAuthenticator {
  final result = Completer<bool>();
  @override
  Future<bool> authenticate() => result.future;
  @override
  Future<void> cancel() async {}
}

class HoldingTrustController extends SecurityController {
  HoldingTrustController({
    required super.store,
    required super.secrets,
    required super.authenticator,
  });
  final ready = Completer<void>();
  @override
  Future<bool> verifyHost(
    HostKeyIdentity identity, {
    HostTrustRecord? expected,
  }) async {
    await ready.future;
    return super.verifyHost(identity, expected: expected);
  }
}

class HoldingCredentialsStore implements LedgerStore {
  HoldingCredentialsStore(this.delegate);
  final LedgerStore delegate;
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<CredentialMetadata>> credentials() async {
    if (!started.isCompleted) started.complete();
    await release.future;
    return delegate.credentials();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

HostKeyIdentity reviewIdentity([int variation = 0]) {
  final public = File('test/fixtures/security/ed25519_encrypted.fixture.pub')
      .readAsStringSync()
      .trim()
      .split(' ')[1];
  final bytes = base64Decode(public);
  bytes[bytes.length - 1] ^= variation;
  return HostKeyIdentity.validated(
    host: 'review.example',
    algorithm: 'ssh-ed25519',
    publicKey: base64Encode(bytes),
  );
}

void main() {
  late Directory directory;
  late LedgerStore store;
  late SecurityController security;
  late LedgerController ledger;
  late ReviewSecrets secrets;
  late ReviewAuthentication auth;

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('security-review-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.db',
    );
    secrets = ReviewSecrets();
    auth = ReviewAuthentication();
    security = SecurityController(
      store: store,
      secrets: secrets,
      authenticator: auth,
    );
    ledger = LedgerController(store, security: security);
    await security.initialize();
  });
  tearDown(() async {
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mountRoute(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        navigatorObservers: [securityRouteObserver],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => page),
                ),
                child: const Text('Open review'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
  }

  Future<void> preparePassword() async {
    expect(
      await security.saveCredential(
        name: 'Synthetic password',
        kind: CredentialKind.password,
        defaultUsername: 'review',
        secret: 'SYNTHETIC_REVIEW_PASSWORD',
      ),
      isTrue,
    );
    secrets.reads = 0;
  }

  testWidgets(
    'reveal auth resolved during pop cannot read or display plaintext',
    (tester) async {
      await preparePassword();
      await mountRoute(
        tester,
        CredentialDetailPage(
          ledger: ledger,
          credentialId: security.credentials.single.id,
        ),
      );
      await tester.tap(find.text('设备验证后查看密码'));
      await tester.pump();
      expect(security.authenticating, isTrue);
      await tester.pageBack();
      // Deliberately do not settle the reverse animation before auth completes.
      auth.result.complete(true);
      await tester.pump();
      expect(secrets.reads, 0);
      expect(security.revealedSecret, isNull);
      await tester.pumpAndSettle();
      expect(find.text('Open review'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'covering reveal route invalidates pending device authentication',
    (tester) async {
      await preparePassword();
      await mountRoute(
        tester,
        CredentialDetailPage(
          ledger: ledger,
          credentialId: security.credentials.single.id,
        ),
      );
      await tester.tap(find.text('设备验证后查看密码'));
      await tester.pump();
      final context = tester.element(find.byType(CredentialDetailPage));
      unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Covering route')),
          ),
        ),
      );
      auth.result.complete(true);
      await tester.pump();
      expect(secrets.reads, 0);
      expect(security.revealedSecret, isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'host lookup completing during pop never resurrects verification route',
    (tester) async {
      final lookup = Completer<HostTrustRecord?>();
      await mountRoute(
        tester,
        HostTrustForm(ledger: ledger, lookup: (_, _) => lookup.future),
      );
      await tester.enterText(
        find.byKey(const ValueKey('trust-host')),
        'review.example',
      );
      await tester.enterText(
        find.byKey(const ValueKey('trust-public-key')),
        reviewIdentity().publicKey,
      );
      await tester.ensureVisible(find.text('检查并核对指纹'));
      await tester.tap(find.text('检查并核对指纹'));
      await tester.pump();
      await tester.pageBack();
      lookup.complete(null);
      await tester.pump();
      expect(find.byType(HostVerificationPage), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Open review'), findsOneWidget);
      expect(find.byType(HostVerificationPage), findsNothing);
      expect(await store.hostTrusts(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'private-key selection completing during pop is discarded immediately',
    (tester) async {
      final selection = Completer<String?>();
      await mountRoute(
        tester,
        CredentialForm(
          ledger: ledger,
          kind: CredentialKind.privateKey,
          pickKey: () => selection.future,
        ),
      );
      await tester.ensureVisible(find.text('选择私钥文件'));
      await tester.tap(find.text('选择私钥文件'));
      await tester.pump();
      final field = tester.widget<AppTextField>(
        find.byKey(const ValueKey('credential-secret')),
      );
      await tester.tap(find.byTooltip('取消编辑凭据'));
      selection.complete('SYNTHETIC_LATE_PRIVATE_KEY');
      await tester.pump();
      expect(field.controller!.text, isEmpty);
      expect(find.text('已导入待保存的私钥；保存时校验格式与口令'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Open review'), findsOneWidget);
      expect(await store.credentials(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'cancel while metadata loads prevents subsequent native secret read',
    () async {
      await preparePassword();
      final heldStore = HoldingCredentialsStore(store);
      final heldSecurity = SecurityController(
        store: heldStore,
        secrets: secrets,
        authenticator: auth,
      );
      try {
        final pending = heldSecurity.reveal(security.credentials.single);
        auth.result.complete(true);
        await heldStore.started.future;
        heldSecurity.hideSensitive();
        heldStore.release.complete();
        expect(await pending, isFalse);
        expect(secrets.reads, 0);
        expect(heldSecurity.revealedSecret, isNull);
      } finally {
        heldSecurity.dispose();
      }
    },
  );

  test(
    'stale trust snapshot cannot overwrite a deleted and recreated pin',
    () async {
      final first = reviewIdentity();
      expect(await security.verifyHost(first), isTrue);
      final stale = security.hostTrusts.single;
      expect(await security.removeHostTrust(stale), isTrue);
      final replacement = reviewIdentity(1);
      expect(await security.verifyHost(replacement), isTrue);
      expect(
        await security.verifyHost(reviewIdentity(2), expected: stale),
        isFalse,
      );
      expect(
        (await store.hostTrust(first.host, first.port))!.publicKey,
        replacement.publicKey,
      );
      expect(await security.removeHostTrust(stale), isFalse);
      expect(
        (await store.hostTrust(first.host, first.port))!.publicKey,
        replacement.publicKey,
      );
    },
  );

  test(
    'first-use attempt can authenticate only after explicit verification',
    () async {
      final identity = reviewIdentity();
      final attempt = security.beginHostVerification(identity);
      expect(await attempt.check(), HostTrustStatus.firstUse);
      expect(await attempt.confirm(), isTrue);
      var calls = 0;
      expect(
        await attempt.authenticate(() async {
          calls++;
        }),
        isTrue,
      );
      expect(calls, 1);
    },
  );

  test(
    'timed-out native writes remain ordered before cleanup that also timed out',
    () async {
      // Method-channel contract only; no operating-system keyring is accessed.
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final releaseWrite = Completer<void>();
      final deleted = Completer<void>();
      final calls = <String>[];
      String? stored;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'write':
            calls.add('write-started');
            await releaseWrite.future;
            stored = 'SYNTHETIC_METHOD_CHANNEL_VALUE';
            calls.add('write-completed');
          case 'delete':
            calls.add('delete');
            stored = null;
            deleted.complete();
          default:
            throw StateError('Unexpected storage method');
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final native = NativeSecretStore(
        timeout: const Duration(milliseconds: 10),
      );
      await expectLater(
        native.write('synthetic-review-ref', 'SYNTHETIC_METHOD_CHANNEL_VALUE'),
        throwsA(isA<SecurityFailure>()),
      );
      await expectLater(
        native.delete('synthetic-review-ref'),
        throwsA(isA<SecurityFailure>()),
      );
      expect(calls, ['write-started']);
      releaseWrite.complete();
      await deleted.future;
      expect(calls, ['write-started', 'write-completed', 'delete']);
      expect(stored, isNull);
    },
  );

  testWidgets(
    'host trust save locks back until its committed result is known',
    (tester) async {
      ledger.dispose();
      final held = HoldingTrustController(
        store: store,
        secrets: secrets,
        authenticator: auth,
      );
      security = held;
      ledger = LedgerController(store, security: security);
      await security.initialize();
      await mountRoute(
        tester,
        HostVerificationPage(ledger: ledger, identity: reviewIdentity()),
      );
      await tester.ensureVisible(find.byType(AppSwitchRow));
      await tester.tap(find.byType(AppSwitchRow));
      await tester.pump();
      await tester.ensureVisible(find.text('保存已核验的主机信任'));
      await tester.tap(find.text('保存已核验的主机信任'));
      await tester.pump();
      final context = tester.element(find.byType(HostVerificationPage));
      await Navigator.of(context).maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(HostVerificationPage), findsOneWidget);
      expect(await store.hostTrusts(), isEmpty);
      held.ready.complete();
      await tester.pumpAndSettle();
      expect((await store.hostTrusts()).length, 1);
      expect(find.text('Open review'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
