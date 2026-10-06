import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
// dartssh2 4.1.0 exposes signing publicly, but its typed verification classes
// are not re-exported. Keep these pinned imports local and covered by fixtures;
// do not replace correspondence checks with hand-written cryptography.
// ignore: implementation_imports
import 'package:dartssh2/src/hostkey/hostkey_ecdsa.dart';
// ignore: implementation_imports
import 'package:dartssh2/src/hostkey/hostkey_ed25519.dart';
// ignore: implementation_imports
import 'package:dartssh2/src/hostkey/hostkey_rsa.dart';

import 'host_trust.dart';
import 'security_models.dart';

/// Non-secret metadata only. Parsed private-key objects never leave this file.
class KeyImportResult {
  const KeyImportResult({required this.algorithm, required this.fingerprint});

  final String algorithm;
  final String fingerprint;
}

/// Parses locally with dartssh2. No socket, agent, or authentication is created.
KeyImportResult inspectPrivateKey(String privateKey, {String? passphrase}) {
  try {
    if (privateKey.isEmpty ||
        privateKey.length > 256 * 1024 ||
        (passphrase?.length ?? 0) > 16 * 1024) {
      throw const FormatException();
    }
    final pem = SSHPem.decode(privateKey);
    OpenSSHKeyPairs? container;
    if (pem.type == 'OPENSSH PRIVATE KEY') {
      container = OpenSSHKeyPairs.decode(pem.content);
      if (container.publicKeys.length != 1 ||
          !_sameBytes(pem.content, SSHPem.decode(container.toPem()).content)) {
        throw const FormatException();
      }
      // Bound attacker-controlled KDF work before dartssh2 decrypts the key.
      // Normal ssh-keygen files use 16 rounds; deliberately expensive files
      // above 256 rounds must be re-exported before importing here.
      final kdf = container.kdfOptions;
      if (kdf is OpenSSHBcryptKdfOptions &&
          (kdf.rounds < 1 ||
              kdf.rounds > 256 ||
              kdf.salt.isEmpty ||
              kdf.salt.length > 1024)) {
        throw const FormatException();
      }
    }
    final keys = SSHKeyPair.fromPem(
      privateKey,
      passphrase?.isEmpty == true ? null : passphrase,
    );
    if (keys.length != 1) throw const FormatException();
    final key = keys.single;
    final publicBytes = key.toPublicKey().encode();
    if (container != null &&
        !_sameBytes(container.publicKeys.single, publicBytes)) {
      throw const FormatException();
    }
    if (key is OpenSSHEd25519KeyPair &&
        (key.privateKey.length != 64 ||
            key.publicKey.length != 32 ||
            !_sameBytes(key.privateKey.sublist(32), key.publicKey))) {
      throw const FormatException();
    }
    // Validate the complete public wire structure, rather than its type alone.
    HostKeyIdentity.validated(
      host: 'localhost',
      algorithm: key.name,
      publicKey: base64Encode(publicBytes),
    );
    _verifyPrivatePublicCorrespondence(key);
    return KeyImportResult(
      algorithm: key.name,
      fingerprint:
          'SHA256:${base64Encode(sha256.convert(publicBytes).bytes).replaceAll('=', '')}',
    );
  } catch (_) {
    // Never surface parser exceptions: malformed PEM headers/comments can
    // contain secrets, and dependencies may put input bytes in their errors.
    throw const SecurityFailure('密钥格式或口令无效');
  }
}

void _verifyPrivatePublicCorrespondence(SSHKeyPair key) {
  // A parser can accept an internally inconsistent key. In particular, an
  // OpenSSH Ed25519 file repeats a public key beside the private seed, and
  // matching those repeated bytes does not prove they belong to that seed.
  // This signature is purely local and is never sent or stored.
  final challenge = Uint8List.fromList(
    utf8.encode('vps-tell-you/local-key-import-validation/v1'),
  );
  if (key is OpenSSHRsaKeyPair) {
    _boundRsaPrivateComponents(key.n, key.d, key.p, key.q);
  } else if (key is RsaPrivateKey) {
    _boundRsaPrivateComponents(key.n, key.d, key.p, key.q);
  } else if (key is OpenSSHEcdsaKeyPair) {
    final maxBits = switch (key.curveId) {
      'nistp256' => 256,
      'nistp384' => 384,
      'nistp521' => 521,
      _ => throw const FormatException(),
    };
    if (key.d <= BigInt.zero || key.d.bitLength > maxBits) {
      throw const FormatException();
    }
  }
  final public = key.toPublicKey();
  final signature = key.sign(challenge);
  final verified = switch ((public, signature)) {
    (SSHEd25519PublicKey p, SSHEd25519Signature s) => p.verify(challenge, s),
    (SSHRsaPublicKey p, SSHRsaSignature s) => p.verify(challenge, s),
    (SSHEcdsaPublicKey p, SSHEcdsaSignature s) => p.verify(challenge, s),
    _ => false,
  };
  if (!verified) throw const FormatException();
}

void _boundRsaPrivateComponents(BigInt n, BigInt d, BigInt p, BigInt q) {
  if (d <= BigInt.zero ||
      d.bitLength > n.bitLength ||
      p <= BigInt.one ||
      p.bitLength > n.bitLength ||
      q <= BigInt.one ||
      q.bitLength > n.bitLength ||
      p * q != n) {
    throw const FormatException();
  }
}

bool _sameBytes(List<int> first, List<int> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
