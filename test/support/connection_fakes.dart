import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/security/secret_store.dart';
import 'package:vps_tell_you/security/security_controller.dart';
import 'package:vps_tell_you/security/security_models.dart';

class MemorySecrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String reference) async => values[reference];
  @override
  Future<void> write(String reference, String value) async =>
      values[reference] = value;
  @override
  Future<void> delete(String reference) async => values.remove(reference);
}

class DeniedDeviceAuth implements DeviceAuthenticator {
  @override
  Future<bool> authenticate(AppLocalizations l10n) async => false;
  @override
  Future<void> cancel() async {}
}

Future<String> saveFixtureCredential(SecurityController security) async {
  expect(
    await security.saveCredential(
      name: 'Synthetic SSH fixture',
      kind: CredentialKind.password,
      defaultUsername: 'fixture',
      secret: 'synthetic-password-only',
    ),
    isTrue,
    reason: security.error,
  );
  return security.credentials.last.id;
}
