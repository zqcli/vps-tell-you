import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';

/// Deliberately contains only a fixed, safe message: never wrap plugin errors,
/// private key text, passphrases or SQL exception arguments.
class SecurityFailure implements Exception, LocalizedMessage {
  const SecurityFailure([this.details]);
  final Object? details;
  String get message => messageFor(defaultLocalizations);
  @override
  String messageFor(AppLocalizations l10n) => details == null
      ? l10n.securityOperationIncomplete
      : localizedText(details!, l10n);
  @override
  String toString() => message;
}

enum CredentialKind { password, privateKey }

/// Public metadata. The opaque secretRef is an immutable native-store key, not
/// secret material. Passwords, private keys and passphrases never enter SQLite.
class CredentialMetadata {
  const CredentialMetadata({
    required this.id,
    required this.name,
    required this.kind,
    required this.defaultUsername,
    required this.secretRef,
    required this.createdAt,
    required this.updatedAt,
    this.keyAlgorithm,
    this.fingerprint,
    this.revision = 0,
  });
  final String id, name, defaultUsername, secretRef;
  final CredentialKind kind;
  final String? keyAlgorithm, fingerprint;
  final int revision;
  final DateTime createdAt, updatedAt;
  factory CredentialMetadata.fromMap(Map<String, Object?> row) =>
      CredentialMetadata(
        id: row['id'] as String,
        name: row['name'] as String,
        kind: CredentialKind.values.byName(row['kind'] as String),
        defaultUsername: row['default_username'] as String,
        secretRef: row['secret_ref'] as String,
        keyAlgorithm: row['key_algorithm'] as String?,
        fingerprint: row['fingerprint'] as String?,
        revision: row['revision'] as int,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'default_username': defaultUsername,
    'secret_ref': secretRef,
    'key_algorithm': keyAlgorithm,
    'fingerprint': fingerprint,
    'revision': revision,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

/// Independent from editable ledger fields. Selecting or replacing a credential
/// never changes this explicit username, even when it matches an old default.
class SshConfiguration {
  const SshConfiguration({
    required this.serverId,
    required this.host,
    required this.username,
    this.port = 22,
    this.credentialId,
    this.proxyId,
    this.revision = -1,
  });
  final String serverId, host, username;
  final int port, revision;
  final String? credentialId;

  /// Saved proxy the SSH (and SFTP) connection goes through; null is direct.
  final String? proxyId;
  factory SshConfiguration.fromMap(Map<String, Object?> row) =>
      SshConfiguration(
        serverId: row['server_id'] as String,
        host: row['host'] as String,
        port: row['port'] as int,
        username: row['username'] as String,
        credentialId: row['credential_id'] as String?,
        proxyId: row['proxy_id'] as String?,
        revision: row['revision'] as int,
      );
  Map<String, Object?> toMap() => {
    'server_id': serverId,
    'host': host,
    'port': port,
    'username': username,
    'credential_id': credentialId,
    'proxy_id': proxyId,
    'revision': revision,
  };
}

class HostTrustRecord {
  const HostTrustRecord({
    required this.host,
    required this.port,
    required this.algorithm,
    required this.publicKey,
    required this.fingerprint,
    required this.verifiedAt,
    this.revision = 0,
    this.generation = '',
  });
  final String host, algorithm, publicKey, fingerprint, generation;
  final int port, revision;
  final DateTime verifiedAt;
  factory HostTrustRecord.fromMap(Map<String, Object?> row) => HostTrustRecord(
    generation: row['generation'] as String,
    host: row['host'] as String,
    port: row['port'] as int,
    algorithm: row['algorithm'] as String,
    publicKey: row['public_key'] as String,
    fingerprint: row['fingerprint'] as String,
    verifiedAt: DateTime.parse(row['verified_at'] as String),
    revision: row['revision'] as int,
  );
  Map<String, Object?> toMap() => {
    'generation': generation,
    'host': host,
    'port': port,
    'algorithm': algorithm,
    'public_key': publicKey,
    'fingerprint': fingerprint,
    'verified_at': verifiedAt.toUtc().toIso8601String(),
    'revision': revision,
  };
}

/// Ephemeral connection data, never a database row or user-facing string.
class SshCredential {
  const SshCredential({
    required this.metadata,
    required this.secret,
    this.passphrase,
  });
  final CredentialMetadata metadata;
  final String secret;
  final String? passphrase;
}
