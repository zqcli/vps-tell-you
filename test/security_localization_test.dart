import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/core/ui/ui.dart';
import 'package:vps_tell_you/data/ledger_store.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_en.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';
import 'package:vps_tell_you/security/host_trust.dart';
import 'package:vps_tell_you/security/host_trust_pages.dart';
import 'package:vps_tell_you/security/key_import.dart';
import 'package:vps_tell_you/security/secret_store.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';
import 'package:vps_tell_you/security/credential_form.dart';
import 'package:vps_tell_you/security/credential_pages.dart';
import 'package:vps_tell_you/security/security_pages.dart';
import 'package:vps_tell_you/security/security_widgets.dart';
import 'package:vps_tell_you/security/ssh_configuration_page.dart';
import 'package:vps_tell_you/servers/ledger_controller.dart';
import 'package:vps_tell_you/servers/server_record.dart';

class LocalizationSecrets implements SecretStore {
  final values = <String, String>{};
  int reads = 0, writes = 0, deletes = 0;
  @override
  Future<String?> read(String reference) async {
    reads++;
    return values[reference];
  }

  @override
  Future<void> write(String reference, String value) async {
    writes++;
    values[reference] = value;
  }

  @override
  Future<void> delete(String reference) async {
    deletes++;
    values.remove(reference);
  }
}

class LocalizationAuthentication
    implements DeviceAuthenticator, LocalizedDeviceAuthenticator {
  int calls = 0, cancels = 0;
  final locales = <String>[];
  Completer<bool>? pending;
  @override
  Future<bool> authenticate() async {
    calls++;
    return pending?.future ?? false;
  }

  @override
  Future<bool> authenticateWithLocalizations(AppLocalizations l10n) {
    locales.add(l10n.localeName);
    return authenticate();
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }
}

class CapturingLocalAuthentication implements LocalAuthentication {
  Map<Symbol, dynamic>? lastArguments;
  int attempts = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #isDeviceSupported) {
      return Future<bool>.value(true);
    }
    if (invocation.memberName == #authenticate) {
      attempts++;
      lastArguments = invocation.namedArguments;
      return Future<bool>.value(false);
    }
    if (invocation.memberName == #stopAuthentication) {
      return Future<bool>.value(true);
    }
    return super.noSuchMethod(invocation);
  }
}

HostKeyIdentity localizationIdentity([int change = 0]) {
  final raw = File('test/fixtures/security/ed25519_encrypted.fixture.pub')
      .readAsStringSync()
      .trim()
      .split(' ')[1];
  final bytes = base64Decode(raw);
  bytes[bytes.length - 1] ^= change;
  return HostKeyIdentity.validated(
    host: 'synthetic.example',
    algorithm: 'ssh-ed25519',
    publicKey: base64Encode(bytes),
  );
}

void main() {
  final evidence = Platform.environment['VPS_SECURITY_I18N_EVIDENCE_DIR'];
  final fontPath = Platform.environment['VPS_SECURITY_I18N_FONT'];
  var fontsLoaded = false;
  final zh = AppLocalizationsZh();
  final en = AppLocalizationsEn();
  late Directory directory;
  late LedgerStore store;
  late SecurityController security;
  late LedgerController ledger;
  late LocalizationSecrets secrets;
  late LocalizationAuthentication auth;
  late ValueNotifier<Locale> locale;

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('security-localization-');
    store = await LedgerStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${directory.path}/ledger.sqlite',
    );
    secrets = LocalizationSecrets();
    auth = LocalizationAuthentication();
    security = SecurityController(
      store: store,
      secrets: secrets,
      authenticator: auth,
    );
    ledger = LedgerController(store, security: security);
    locale = ValueNotifier(const Locale('zh'));
    await ledger.refresh();
    await security.initialize();
  });
  tearDown(() async {
    locale.dispose();
    ledger.dispose();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<CredentialMetadata> credential() async {
    expect(
      await security.saveCredential(
        name: 'User-entered 中文 name',
        kind: CredentialKind.password,
        defaultUsername: 'root',
        secret: 'SYNTHETIC_PASSWORD',
      ),
      isTrue,
    );
    secrets.reads = secrets.writes = secrets.deletes = 0;
    return security.credentials.single;
  }

  Future<void> mount(
    WidgetTester tester,
    Widget page, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (fontPath != null && !fontsLoaded) {
      await tester.runAsync(() async {
        final loader = FontLoader('Security I18n Review');
        loader.addFont(File(fontPath).readAsBytes().then(ByteData.sublistView));
        await loader.load();
        final icons = FontLoader('MaterialIcons');
        icons.addFont(
          File(
            '${Platform.environment['FLUTTER_BOOTSTRAP_ROOT']}/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then(ByteData.sublistView),
        );
        await icons.load();
        fontsLoaded = true;
      });
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (context, current, _) => MaterialApp(
          locale: current,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: fontPath == null
              ? appTheme()
              : appTheme().copyWith(
                  textTheme: appTheme().textTheme.apply(
                    fontFamily: 'Security I18n Review',
                  ),
                  appBarTheme: appTheme().appBarTheme.copyWith(
                    titleTextStyle: appTheme().appBarTheme.titleTextStyle
                        ?.copyWith(fontFamily: 'Security I18n Review'),
                  ),
                ),
          navigatorObservers: [securityRouteObserver],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(
              key: const ValueKey('security-i18n-evidence'),
              child: child!,
            ),
          ),
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (evidence == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('security-i18n-evidence')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('$evidence/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> switchEnglish(WidgetTester tester) async {
    locale.value = const Locale('en');
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    if (find.text(text).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(text),
        350,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
    }
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  test('safe validation errors retain their identity and resolve in either language', () {
    for (final action in <void Function()>[
      () => normalizedHost('https://synthetic.example'),
      () => HostKeyIdentity.validated(
        host: 'synthetic.example',
        port: 0,
        algorithm: 'ssh-ed25519',
        publicKey: 'SYNTHETIC_KEY',
      ),
      () => inspectPrivateKey('SYNTHETIC_PRIVATE_KEY_DO_NOT_LEAK'),
    ]) {
      try {
        action();
        fail('Expected validation failure');
      } on SecurityFailure catch (failure) {
        expect(failure.messageFor(zh), failure.message);
        expect(failure.messageFor(en), isNot(failure.message));
        expect(failure.messageFor(en), isNot(contains('SYNTHETIC')));
        expect(
          failure.messageFor(en),
          isNot(matches(RegExp(r'[\u4e00-\u9fff]'))),
        );
      }
    }
  });

  testWidgets(
    'stored failure changes language without retrying secure operations',
    (tester) async {
      expect(
        await security.saveCredential(
          name: '',
          kind: CredentialKind.password,
          defaultUsername: '',
          secret: 'SYNTHETIC_DRAFT',
        ),
        isFalse,
      );
      final original = security.localizedError;
      await mount(tester, Scaffold(body: SecurityNotice(controller: security)));
      expect(find.text(zh.securityInvalidCredentialIdentity), findsOneWidget);
      await switchEnglish(tester);
      expect(find.text(en.securityInvalidCredentialIdentity), findsOneWidget);
      expect(identical(security.localizedError, original), isTrue);
      expect(security.error, zh.securityInvalidCredentialIdentity);
      expect(security.errorFor(en), en.securityInvalidCredentialIdentity);
      expect(
        [secrets.reads, secrets.writes, secrets.deletes, auth.calls],
        [0, 0, 0, 0],
      );
    },
  );

  testWidgets(
    'invalid credential form revalidates and preserves all drafts on language change',
    (tester) async {
      await mount(
        tester,
        CredentialForm(ledger: ledger, kind: CredentialKind.password),
      );
      await tester.enterText(
        find.byKey(const ValueKey('credential-secret')),
        'SYNTHETIC_UNSAVED_PASSWORD',
      );
      await tapText(tester, zh.securitySaveCredential);
      expect(find.text(zh.securityCredentialNameRequired), findsOneWidget);
      await switchEnglish(tester);
      expect(find.text(en.securityCredentialNameRequired), findsOneWidget);
      expect(find.text(en.securityDefaultUsernameRequired), findsOneWidget);
      final field = tester.widget<AppTextField>(
        find.byKey(const ValueKey('credential-secret')),
      );
      expect(field.controller!.text, 'SYNTHETIC_UNSAVED_PASSWORD');
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const ValueKey('credential-secret')),
                matching: find.byType(EditableText),
              ),
            )
            .obscureText,
        isTrue,
      );
      expect(secrets.reads + secrets.writes + auth.calls, 0);
    },
  );

  testWidgets(
    'private-key draft, passphrase, and save preference survive language change',
    (tester) async {
      await mount(
        tester,
        CredentialForm(
          ledger: ledger,
          kind: CredentialKind.privateKey,
          pickKey: () async => 'SYNTHETIC_PRIVATE_KEY\nSECOND_LINE',
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('credential-name')),
        'My 中文 key',
      );
      await tapText(tester, zh.securityChoosePrivateKeyFile);
      await tester.ensureVisible(
        find.byKey(const ValueKey('credential-passphrase')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('credential-passphrase')),
        'SYNTHETIC_PASSPHRASE',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('credential-save-passphrase')),
      );
      await tester.tap(
        find.byKey(const ValueKey('credential-save-passphrase')),
      );
      await tester.pump();
      await switchEnglish(tester);
      expect(
        tester
            .widget<AppTextField>(
              find.byKey(const ValueKey('credential-secret')),
            )
            .controller!
            .text,
        'SYNTHETIC_PRIVATE_KEY\nSECOND_LINE',
      );
      expect(
        tester
            .widget<AppTextField>(
              find.byKey(const ValueKey('credential-passphrase')),
            )
            .controller!
            .text,
        'SYNTHETIC_PASSPHRASE',
      );
      expect(
        tester
            .widget<AppSwitchRow>(
              find.byKey(const ValueKey('credential-save-passphrase')),
            )
            .value,
        isTrue,
      );
      expect(secrets.reads + secrets.writes + auth.calls, 0);
    },
  );

  testWidgets(
    'open discard dialog and pending snackbar switch without clearing draft',
    (tester) async {
      await mount(
        tester,
        CredentialForm(
          ledger: ledger,
          kind: CredentialKind.privateKey,
          pickKey: () async => 'SYNTHETIC_KEY',
        ),
      );
      await tapText(tester, zh.securityChoosePrivateKeyFile);
      expect(find.text(zh.securityKeyImported), findsOneWidget);
      await tester.tap(find.byTooltip(zh.securityCancelCredentialEdit));
      await tester.pumpAndSettle();
      expect(find.text(zh.securityDiscardCredentialTitle), findsOneWidget);
      await switchEnglish(tester);
      expect(find.text(en.securityDiscardCredentialTitle), findsOneWidget);
      expect(find.text(en.securityDiscardCredentialMessage), findsOneWidget);
      expect(find.text(en.securityKeyImported), findsOneWidget);
      await tapText(tester, en.cancel);
      expect(
        tester
            .widget<AppTextField>(
              find.byKey(const ValueKey('credential-secret')),
            )
            .controller!
            .text,
        'SYNTHETIC_KEY',
      );
      expect(secrets.reads + secrets.writes + auth.calls, 0);
    },
  );

  testWidgets(
    'pending reveal retains one explicit authentication attempt after switching',
    (tester) async {
      final record = await credential();
      auth.pending = Completer<bool>();
      await mount(
        tester,
        CredentialDetailPage(ledger: ledger, credentialId: record.id),
      );
      await tapText(tester, zh.securityVerifyViewPassword);
      // Controller initialization happened outside the widget fake-time zone.
      // Let its already-completed cancellation future deliver its continuation.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(
        auth.calls,
        1,
        reason:
            'busy=${security.busy}, auth=${security.authenticating}, reload=${security.needsReload}, error=${security.error}, locales=${auth.locales}, cancels=${auth.cancels}',
      );
      expect(auth.locales, ['zh']);
      locale.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(auth.calls, 1);
      expect(secrets.reads, 0);
      auth.pending!.complete(false);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text(en.securityAuthenticationHidden), findsOneWidget);
      expect(secrets.reads, 0);
      expect(security.revealedSecret, isNull);
      auth.pending = null;
      await tapText(tester, en.securityVerifyViewPassword);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(auth.locales, ['zh', 'en']);
      expect(auth.calls, 2);
      expect(secrets.reads, 0);
    },
  );

  test('native auth reason and supplied prompt labels use the explicit app language', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final native = CapturingLocalAuthentication();
    final adapter = NativeDeviceAuthenticator(authentication: native);
    await adapter.authenticateWithLocalizations(en);
    expect(
      native.lastArguments![#localizedReason],
      en.securityDeviceAuthReason,
    );
    final messages = native.lastArguments![#authMessages] as Iterable<dynamic>;
    expect(messages.first.args['cancelButton'], en.securityAuthCancel);
    expect(messages.first.args['signInTitle'], en.securityAuthSignInTitle);
    expect(native.lastArguments![#persistAcrossBackgrounding], isFalse);
    await adapter.authenticateWithLocalizations(zh);
    expect(
      native.lastArguments![#localizedReason],
      zh.securityDeviceAuthReason,
    );
    expect(native.attempts, 2);
  });

  testWidgets(
    'changed host verification stays gated and retains consent across locale change',
    (tester) async {
      await security.verifyHost(localizationIdentity());
      await mount(
        tester,
        HostVerificationPage(
          ledger: ledger,
          identity: localizationIdentity(1),
          previous: security.hostTrusts.single,
        ),
      );
      await switchEnglish(tester);
      expect(find.text(en.securityHostKeyMismatch), findsOneWidget);
      expect(find.text(en.securityReverifyReplaceTrust), findsNothing);
      await tapText(tester, en.securityBeginHostReverification);
      expect(
        tester
            .widget<AppButton>(
              find.widgetWithText(AppButton, en.securityReverifyReplaceTrust),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byType(AppSwitchRow));
      await tester.tap(find.byType(AppSwitchRow));
      await tester.pump();
      locale.value = const Locale('zh');
      await tester.pumpAndSettle();
      expect(
        tester.widget<AppSwitchRow>(find.byType(AppSwitchRow)).value,
        isTrue,
      );
      expect(
        security.hostTrusts.single.publicKey,
        localizationIdentity().publicKey,
      );
      expect(auth.calls + secrets.reads, 0);
    },
  );

  testWidgets('SSH validation and draft configuration survive locale changes', (
    tester,
  ) async {
    await mount(
      tester,
      SshConfigurationPage(ledger: ledger, serverId: 'draft-only'),
    );
    await tester.enterText(
      find.byKey(const ValueKey('ssh-host')),
      'synthetic.example',
    );
    await tester.enterText(find.byKey(const ValueKey('ssh-port')), '70000');
    await tapText(tester, zh.securitySaveSshConfiguration);
    await switchEnglish(tester);
    expect(find.text(en.securityPortRequired), findsOneWidget);
    expect(find.text(en.securityConnectionUsernameRequired), findsOneWidget);
    expect(
      tester
          .widget<AppTextField>(find.byKey(const ValueKey('ssh-host')))
          .controller!
          .text,
      'synthetic.example',
    );
    expect(
      tester
          .widget<AppTextField>(find.byKey(const ValueKey('ssh-port')))
          .controller!
          .text,
      '70000',
    );
    expect(security.sshConfigurations, isEmpty);
    expect(secrets.reads + secrets.writes + auth.calls, 0);
  });

  testWidgets(
    'host error snackbar changes without repeating lookup and keeps key input',
    (tester) async {
      var lookups = 0;
      await mount(
        tester,
        HostTrustForm(
          ledger: ledger,
          lookup: (_, _) async {
            lookups++;
            throw StateError('SYNTHETIC_NATIVE_ERROR_DO_NOT_LEAK');
          },
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('trust-host')),
        'synthetic.example',
      );
      await tester.enterText(
        find.byKey(const ValueKey('trust-public-key')),
        localizationIdentity().publicKey,
      );
      await tapText(tester, zh.securityCheckFingerprint);
      expect(lookups, 1);
      await switchEnglish(tester);
      expect(find.text(en.securityHostTrustReadFailed), findsOneWidget);
      expect(
        find.textContaining('SYNTHETIC_NATIVE_ERROR_DO_NOT_LEAK'),
        findsNothing,
      );
      expect(
        tester
            .widget<AppTextField>(
              find.byKey(const ValueKey('trust-public-key')),
            )
            .controller!
            .text,
        localizationIdentity().publicKey,
      );
      expect(lookups, 1);
      expect(auth.calls + secrets.reads, 0);
    },
  );

  testWidgets(
    'important English dialogs and add sheet fit 320 pixels at 2x text',
    (tester) async {
      await security.verifyHost(localizationIdentity());
      locale.value = const Locale('en');
      await mount(tester, HostTrustPage(ledger: ledger), scale: 2);
      await tapText(tester, en.securityRemoveHostTrust);
      expect(find.text(en.securityRemoveHostTrustTitle), findsOneWidget);
      await capture(tester, 'host-trust-removal-en-320x2');
      expect(tester.takeException(), isNull);
      locale.value = const Locale('zh');
      await tester.pumpAndSettle();
      expect(find.text(zh.securityRemoveHostTrustTitle), findsOneWidget);
      await tapText(tester, zh.cancel);
      expect(security.hostTrusts.length, 1);
      locale.value = const Locale('en');
      await mount(tester, SecurityPage(ledger: ledger), scale: 2);
      await tapText(tester, en.securityCredentialProtection);
      expect(find.text(en.securityCredentialProtectionDetail), findsOneWidget);
      await capture(tester, 'credential-protection-en-320x2');
      expect(tester.takeException(), isNull);
      await tapText(tester, en.gotIt);
      await tester.tap(find.byTooltip(en.securityAddCredential));
      await tester.pumpAndSettle();
      expect(find.text(en.securityAddLoginCredential), findsOneWidget);
      await capture(tester, 'add-credential-sheet-en-320x2');
      expect(tester.takeException(), isNull);
      expect(auth.calls + secrets.reads, 0);
    },
  );

  testWidgets(
    'all security pages fit 320 pixels with long English and 2x text',
    (tester) async {
      final record = await credential();
      final now = DateTime.utc(2026, 10, 7);
      await store.saveServer(
        ServerRecord(
          id: 'synthetic-server',
          name: 'Synthetic server with a long user-entered name',
          vendor: 'fixture',
          host: '192.0.2.1',
          createdAt: now,
          updatedAt: now,
        ),
        isNew: true,
      );
      await ledger.refresh();
      await security.saveSshConfiguration(
        SshConfiguration(
          serverId: 'synthetic-server',
          host: '192.0.2.1',
          username: 'explicit-user',
          credentialId: record.id,
        ),
      );
      await security.verifyHost(localizationIdentity());
      locale.value = const Locale('en');
      for (final page in <Widget>[
        SecurityPage(ledger: ledger),
        CredentialForm(ledger: ledger, kind: CredentialKind.password),
        CredentialForm(ledger: ledger, kind: CredentialKind.privateKey),
        CredentialDetailPage(ledger: ledger, credentialId: record.id),
        CredentialReferencesPage(ledger: ledger, credential: record),
        CredentialDeletePage(ledger: ledger, credential: record),
        SshConfigurationPage(ledger: ledger, serverId: 'synthetic-server'),
        HostTrustPage(ledger: ledger),
        HostTrustForm(ledger: ledger),
        HostVerificationPage(
          ledger: ledger,
          identity: localizationIdentity(1),
          previous: security.hostTrusts.single,
        ),
      ]) {
        await mount(tester, page, scale: 2);
        await capture(tester, '${page.runtimeType}-top-en-320x2');
        for (var step = 0; step < 45; step++) {
          expect(
            tester.takeException(),
            isNull,
            reason: '${page.runtimeType}, step $step',
          );
          final scroll = tester
              .stateList<ScrollableState>(find.byType(Scrollable))
              .firstWhere(
                (state) =>
                    state.axisDirection == AxisDirection.down &&
                    state.position.hasContentDimensions,
              );
          if (scroll.position.extentAfter <= 1) break;
          scroll.position.jumpTo(
            (scroll.position.pixels + 400).clamp(
              0.0,
              scroll.position.maxScrollExtent,
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
        await capture(tester, '${page.runtimeType}-bottom-en-320x2');
      }
      expect(auth.calls + secrets.reads, 0);
    },
  );
}
