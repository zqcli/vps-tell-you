import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:local_auth_darwin/types/auth_messages_macos.dart';

import 'security_models.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';

abstract interface class SecretStore {
  Future<String?> read(String reference);
  Future<void> write(String reference, String value);
  Future<void> delete(String reference);
}

/// Native-only. Missing/locked storage stays an error; there is no alternate
/// database, file or production memory vault. No bulk deletion/reset is used.
class NativeSecretStore implements SecretStore {
  NativeSecretStore({
    FlutterSecureStorage? storage,
    this.timeout = const Duration(seconds: 8),
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(resetOnError: false),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.unlocked_this_device,
               synchronizable: false,
             ),
           );
  final FlutterSecureStorage _storage;
  final Duration timeout;
  final Map<String, Future<void>> _tails = {};

  /// Keep the *underlying* operation in the queue after a caller timeout. If a
  /// native write completes late, queued cleanup runs after it, not before it.
  Future<T> _run<T>(String ref, Future<T> Function() action) async {
    if (kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.linux,
          TargetPlatform.macOS,
          TargetPlatform.windows,
        }.contains(defaultTargetPlatform)) {
      throw SecurityFailure(
        LocalizedText((l10n) => l10n.securityNativeStorageUnsupported),
      );
    }
    final previous = _tails[ref] ?? Future<void>.value();
    final actual = previous.then((_) => action());
    final tail = actual.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tails[ref] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_tails[ref], tail)) _tails.remove(ref);
      }),
    );
    try {
      return await actual.timeout(timeout);
    } catch (_) {
      throw SecurityFailure(
        LocalizedText((l10n) => l10n.securityNativeStorageUnavailable),
      );
    }
  }

  @override
  Future<String?> read(String reference) =>
      _run(reference, () => _storage.read(key: reference));
  @override
  Future<void> write(String reference, String value) =>
      _run(reference, () => _storage.write(key: reference, value: value));
  @override
  Future<void> delete(String reference) =>
      _run(reference, () => _storage.delete(key: reference));
}

abstract interface class DeviceAuthenticator {
  Future<bool> authenticate();
  Future<void> cancel();
}

/// Optional explicit-locale contract; existing test and external adapters keep
/// implementing DeviceAuthenticator without mutable locale state.
abstract interface class LocalizedDeviceAuthenticator {
  Future<bool> authenticateWithLocalizations(AppLocalizations l10n);
}

/// An application-level reveal gate. This is not a claim that each keychain
/// item is cryptographically bound to biometrics or protected from rooted OSes.
class NativeDeviceAuthenticator
    implements DeviceAuthenticator, LocalizedDeviceAuthenticator {
  NativeDeviceAuthenticator({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();
  final LocalAuthentication _authentication;
  bool get supportedPlatform =>
      !kIsWeb &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      }.contains(defaultTargetPlatform);

  @override
  Future<bool> authenticate() =>
      authenticateWithLocalizations(defaultLocalizations);

  @override
  Future<bool> authenticateWithLocalizations(AppLocalizations l10n) async {
    if (!supportedPlatform) {
      throw SecurityFailure(
        LocalizedText((l10n) => l10n.securityDeviceAuthUnsupported),
      );
    }
    try {
      if (!await _authentication.isDeviceSupported().timeout(
        const Duration(seconds: 3),
      )) {
        return false;
      }
      return await _authentication
          .authenticate(
            localizedReason: l10n.securityDeviceAuthReason,
            authMessages: [
              AndroidAuthMessages(
                cancelButton: l10n.securityAuthCancel,
                signInTitle: l10n.securityAuthSignInTitle,
                signInHint: l10n.securityAuthBiometricHint,
              ),
              IOSAuthMessages(cancelButton: l10n.securityAuthCancel),
              MacOSAuthMessages(cancelButton: l10n.securityAuthCancel),
            ],
            biometricOnly: false,
            sensitiveTransaction: true,
            persistAcrossBackgrounding: false,
          )
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      await cancel();
      throw SecurityFailure(
        LocalizedText((l10n) => l10n.securityDeviceAuthIncomplete),
      );
    }
  }

  @override
  Future<void> cancel() async {
    if (!supportedPlatform) return;
    try {
      await _authentication.stopAuthentication().timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {
      // Local cancellation tokens are authoritative even when OS cancel fails.
    }
  }
}
