import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/security/host_trust.dart';
import 'package:vps_tell_you/security/key_import.dart';
import 'package:vps_tell_you/security/security_models.dart';

String fixture(String name) =>
    File('test/fixtures/security/$name').readAsStringSync();

const encryptedPassphrase = 'fixture-passphrase-only';
const ed25519Fingerprint = 'SHA256:XhNqca+sae/S3LbmMGJ/fEKdHddx3NlGKid1sOszhP8';

Matcher get invalidPrivateKey => throwsA(
  isA<SecurityFailure>().having(
    (error) => error.toString(),
    'safe message',
    '密钥格式或口令无效',
  ),
);

Uint8List wireFields(List<List<int>> fields) {
  final builder = BytesBuilder();
  for (final field in fields) {
    final length = ByteData(4)..setUint32(0, field.length);
    builder
      ..add(length.buffer.asUint8List())
      ..add(field);
  }
  return builder.takeBytes();
}

HostKeyIdentity hostKey(String key, {String algorithm = 'ssh-ed25519'}) =>
    HostKeyIdentity.validated(
      host: 'Example.COM.',
      algorithm: algorithm,
      publicKey: key,
    );

void main() {
  group('private-key import', () {
    test('OpenSSH Ed25519 fingerprint matches ssh-keygen fixture', () {
      final result = inspectPrivateKey(fixture('ed25519.fixture'));
      expect(result.algorithm, 'ssh-ed25519');
      expect(result.fingerprint, ed25519Fingerprint);
      expect(
        inspectPrivateKey(
          fixture('ed25519.fixture'),
          passphrase: '',
        ).fingerprint,
        ed25519Fingerprint,
      );
    });

    test('encrypted key decrypts with correct passphrase only', () {
      final key = fixture('ed25519_encrypted.fixture');
      expect(
        inspectPrivateKey(key, passphrase: encryptedPassphrase).fingerprint,
        ed25519Fingerprint,
      );
      expect(() => inspectPrivateKey(key), invalidPrivateKey);
      expect(
        () => inspectPrivateKey(key, passphrase: 'wrong'),
        invalidPrivateKey,
      );
      expect(() => inspectPrivateKey(key, passphrase: ''), invalidPrivateKey);
    });

    test('PKCS#1 RSA and SEC1 ECDSA use the maintained parser', () {
      final rsa = inspectPrivateKey(fixture('rsa.fixture'));
      expect(rsa.algorithm, 'ssh-rsa');
      expect(
        rsa.fingerprint,
        'SHA256:5lMYf5wT+/Qmube1W15H5Wus9q19LjZc5DPLMweB/K4',
      );
      final ecdsa = inspectPrivateKey(fixture('ecdsa.fixture'));
      expect(ecdsa.algorithm, 'ecdsa-sha2-nistp256');
      expect(
        ecdsa.fingerprint,
        'SHA256:gTc7eTgcDTTxo7YDPDg+OENisHosnc1ZHAWbcZlS8E0',
      );
    });

    test(
      'all supported ECDSA curves validate private/public correspondence',
      () {
        const expected = {
          384: 'SHA256:KwXTPR4HcSWEW8Zt3Wy4b2+LLua6pOOr6lQWvf3b3+8',
          521: 'SHA256:Pdz3Wtt5QMlKEf+cz4xV+fOwUTAOv24qcR0yQphcqfg',
        };
        for (final entry in expected.entries) {
          final result = inspectPrivateKey(
            fixture('ecdsa${entry.key}.fixture'),
          );
          expect(result.algorithm, 'ecdsa-sha2-nistp${entry.key}');
          expect(result.fingerprint, entry.value);
          expect(
            hostKey(
              fixture('ecdsa${entry.key}.fixture.pub'),
              algorithm: result.algorithm,
            ).fingerprint,
            entry.value,
          );
        }
      },
    );

    test('malformed inputs cannot leak text through parser exceptions', () {
      for (final input in [
        '',
        'SECRET_VALUE',
        '-----BEGIN SECRET_VALUE-----\nAQ==\n-----END SECRET_VALUE-----',
        '-----BEGIN OPENSSH PRIVATE KEY-----\nSECRET_VALUE\n'
            '-----END OPENSSH PRIVATE KEY-----',
        fixture('ed25519.fixture').replaceFirst('PRIVATE KEY', 'SECRET_VALUE'),
        '${fixture('ed25519.fixture')}${fixture('ed25519.fixture')}',
        'a' * (256 * 1024 + 1),
      ]) {
        expect(() => inspectPrivateKey(input), invalidPrivateKey);
      }
    });

    test('rejects trailing OpenSSH container bytes', () {
      final pem = SSHPem.decode(fixture('ed25519.fixture'));
      final modified = SSHPem(
        pem.type,
        {},
        Uint8List.fromList([...pem.content, 0]),
      ).encode();
      expect(() => inspectPrivateKey(modified), invalidPrivateKey);
    });

    test(
      'rejects inconsistent outer public keys and malformed Ed25519 fields',
      () {
        final pem = SSHPem.decode(fixture('ed25519.fixture'));
        final container = OpenSSHKeyPairs.decode(pem.content);
        final public = Uint8List.fromList(container.publicKeys.single);
        public[public.length - 1] ^= 1;
        final inconsistent = OpenSSHKeyPairs.unencrypted(
          publicKeys: [public],
          privateKeyBlob: container.privateKeyBlob,
        ).toPem();
        expect(() => inspectPrivateKey(inconsistent), invalidPrivateKey);

        final pair =
            SSHKeyPair.fromPem(fixture('ed25519.fixture')).single
                as OpenSSHEd25519KeyPair;
        final malformed = OpenSSHEd25519KeyPair(
          pair.publicKey,
          Uint8List(8),
          'SYNTHETIC_TEST_ONLY',
        ).toPem();
        expect(() => inspectPrivateKey(malformed), invalidPrivateKey);
      },
    );

    test('bounds encrypted KDF work before decrypting', () {
      final pem = SSHPem.decode(fixture('ed25519_encrypted.fixture'));
      final container = OpenSSHKeyPairs.decode(pem.content);
      final kdf = container.kdfOptions as OpenSSHBcryptKdfOptions;
      final excessive = OpenSSHKeyPairs(
        cipherName: container.cipherName,
        kdfName: container.kdfName,
        kdfOptions: OpenSSHBcryptKdfOptions(kdf.salt, 0xffffffff),
        publicKeys: container.publicKeys,
        privateKeyBlob: container.privateKeyBlob,
      ).toPem();
      expect(
        () => inspectPrivateKey(excessive, passphrase: encryptedPassphrase),
        invalidPrivateKey,
      );
    });

    test('rejects an Ed25519 private seed that does not match its repeated public key', () {
      final pair =
          SSHKeyPair.fromPem(fixture('ed25519.fixture')).single
              as OpenSSHEd25519KeyPair;
      final corruptedSeed = Uint8List.fromList(pair.privateKey)..[0] ^= 1;
      final corrupted = OpenSSHEd25519KeyPair(
        pair.publicKey,
        corruptedSeed,
        'SYNTHETIC_TEST_ONLY',
      ).toPem();
      expect(() => inspectPrivateKey(corrupted), invalidPrivateKey);
    });

    test('rejects RSA and ECDSA private components inconsistent with their public keys', () {
      final rsa =
          SSHKeyPair.fromPem(fixture('rsa.fixture')).single as RsaPrivateKey;
      final validOpenSshRsa = OpenSSHRsaKeyPair(
        rsa.n,
        rsa.e,
        rsa.d,
        rsa.coefficient,
        rsa.p,
        rsa.q,
        'SYNTHETIC_TEST_ONLY',
      ).toPem();
      expect(
        inspectPrivateKey(validOpenSshRsa).fingerprint,
        inspectPrivateKey(fixture('rsa.fixture')).fingerprint,
      );
      final corruptedRsa = RsaPrivateKey(
        rsa.version,
        rsa.n,
        rsa.e,
        rsa.d + BigInt.one,
        rsa.p,
        rsa.q,
        rsa.exponent1,
        rsa.exponent2,
        rsa.coefficient,
      ).toPem();
      expect(() => inspectPrivateKey(corruptedRsa), invalidPrivateKey);
      final corruptedOpenSshRsa = OpenSSHRsaKeyPair(
        rsa.n,
        rsa.e,
        rsa.d + BigInt.one,
        rsa.coefficient,
        rsa.p,
        rsa.q,
        'SYNTHETIC_TEST_ONLY',
      ).toPem();
      expect(() => inspectPrivateKey(corruptedOpenSshRsa), invalidPrivateKey);

      final ec =
          SSHKeyPair.fromPem(fixture('ecdsa.fixture')).single
              as OpenSSHEcdsaKeyPair;
      final corruptedEc = OpenSSHEcdsaKeyPair(
        ec.curveId,
        ec.q,
        ec.d + BigInt.one,
        'SYNTHETIC_TEST_ONLY',
      ).toPem();
      expect(() => inspectPrivateKey(corruptedEc), invalidPrivateKey);
    });

    test('one metadata record cannot silently represent multiple keys', () {
      final container = OpenSSHKeyPairs.decode(
        SSHPem.decode(fixture('ed25519.fixture')).content,
      );
      final multiple = OpenSSHKeyPairs.unencrypted(
        publicKeys: [...container.publicKeys, ...container.publicKeys],
        privateKeyBlob: container.privateKeyBlob,
      ).toPem();
      expect(() => inspectPrivateKey(multiple), invalidPrivateKey);
    });
  });

  group('host normalization', () {
    test('canonical DNS, IPv4 and IPv6 identities', () {
      const examples = {
        '  Example.COM.  ': 'example.com',
        'localhost': 'localhost',
        'xn--bcher-kva.example': 'xn--bcher-kva.example',
        '192.0.2.1': '192.0.2.1',
        '[2001:0DB8:0000:0000:0000:0000:0000:0001]': '2001:db8::1',
        '2001:db8::1': '2001:db8::1',
        '0:0:0:0:0:0:0:0': '::',
        '0:0:0:0:0:0:0:1': '::1',
        '1:0:0:2:0:0:3:4': '1::2:0:0:3:4',
        '2001:db8:0:1:2:3:4:5': '2001:db8:0:1:2:3:4:5',
        '::ffff:192.0.2.1': '::ffff:c000:201',
      };
      for (final entry in examples.entries) {
        expect(normalizedHost(entry.key), entry.value);
        expect(normalizedHost(entry.value), entry.value);
      }
    });

    test('rejects ambiguous aliases and non-host inputs', () {
      for (final value in [
        '',
        '.',
        'example..com',
        'example.com..',
        '-example.com',
        'example-.com',
        'https://example.com',
        'user@example.com',
        'example.com/path',
        'example.com:22',
        'example.com?query',
        'example.com#fragment',
        '192.0.2.999',
        '192.000.2.1',
        '127.1',
        '2130706433',
        '0x7f000001',
        '0x7f.0.0.1',
        '[192.0.2.1]',
        '[::1]:22',
        '2001:::1',
        '[::1',
        'fe80::1%eth0',
        'bücher.example',
        'example\n.com',
        '${'a' * 64}.example',
      ]) {
        expect(
          () => normalizedHost(value),
          throwsA(isA<SecurityFailure>()),
          reason: value,
        );
      }
    });
  });

  group('complete host public-key validation', () {
    test('raw blob and OpenSSH line produce identical canonical identity', () {
      final line = fixture('ed25519_encrypted.fixture.pub').trim();
      final raw = line.split(' ')[1];
      final identity = hostKey(line);
      final other = hostKey(raw);
      expect(identity.host, 'example.com');
      expect(identity.port, 22);
      expect(identity.algorithm, 'ssh-ed25519');
      expect(identity.publicKey, raw);
      expect(identity.fingerprint, ed25519Fingerprint);
      expect(other.publicKey, identity.publicKey);
      expect(other.fingerprint, identity.fingerprint);
    });

    test('RSA and ECDSA public fixtures match private-key fingerprints', () {
      for (final name in ['rsa', 'ecdsa']) {
        final private = inspectPrivateKey(fixture('$name.fixture'));
        final identity = hostKey(
          fixture('$name.fixture.pub'),
          algorithm: private.algorithm,
        );
        expect(identity.fingerprint, private.fingerprint);
      }
    });

    test('requires exact algorithm in both label and wire blob', () {
      final line = fixture('ed25519_encrypted.fixture.pub').trim();
      final raw = line.split(' ')[1];
      for (final action in [
        () => hostKey(raw, algorithm: 'ssh-rsa'),
        () => hostKey('ssh-rsa $raw'),
        () => hostKey(line, algorithm: 'rsa-sha2-256'),
        () => hostKey('unsupported $raw', algorithm: 'unsupported'),
      ]) {
        expect(action, throwsA(isA<SecurityFailure>()));
      }
    });

    test('rejects truncated lengths, invalid base64, extra records and trailing bytes', () {
      final line = fixture('ed25519_encrypted.fixture.pub').trim();
      final raw = line.split(' ')[1];
      final bytes = base64Decode(raw);
      final invalid = [
        '',
        'not_a_key',
        '%41AAA',
        'SHA256:some-fingerprint',
        base64Encode([0, 0, 0, 255, 1]),
        base64Encode(bytes.sublist(0, bytes.length - 1)),
        base64Encode([...bytes, 0]),
        '$line\n$line',
      ];
      for (final key in invalid) {
        expect(() => hostKey(key), throwsA(isA<SecurityFailure>()));
      }
    });

    test('Ed25519 must contain exactly a nonzero 32-byte public key', () {
      for (final key in [
        <int>[],
        List.filled(31, 1),
        List.filled(33, 1),
        List.filled(32, 0),
      ]) {
        final blob = wireFields([utf8.encode('ssh-ed25519'), key]);
        expect(
          () => hostKey(base64Encode(blob)),
          throwsA(isA<SecurityFailure>()),
        );
      }
    });

    test(
      'RSA mpints reject negative, zero, noncanonical and weak structures',
      () {
        for (final exponent in [
          <int>[],
          [0],
          [128],
          [0, 3],
          [2],
        ]) {
          final blob = wireFields([
            utf8.encode('ssh-rsa'),
            exponent,
            [7],
          ]);
          expect(
            () => hostKey(base64Encode(blob), algorithm: 'ssh-rsa'),
            throwsA(isA<SecurityFailure>()),
          );
        }
      },
    );

    test('ECDSA requires matching curve and uncompressed point structure', () {
      for (final fields in [
        [utf8.encode('nistp384'), List.filled(65, 4)],
        [utf8.encode('nistp256'), List.filled(64, 4)],
        [utf8.encode('nistp256'), List.filled(65, 2)],
        [
          utf8.encode('nistp256'),
          [4, ...List.filled(64, 0)],
        ],
      ]) {
        final blob = wireFields([
          utf8.encode('ecdsa-sha2-nistp256'),
          ...fields,
        ]);
        expect(
          () => hostKey(base64Encode(blob), algorithm: 'ecdsa-sha2-nistp256'),
          throwsA(isA<SecurityFailure>()),
        );
      }
    });

    test('port remains part of identity and stays within TCP range', () {
      final key = fixture('ed25519_encrypted.fixture.pub');
      for (final port in [1, 22, 2222, 65535]) {
        expect(
          HostKeyIdentity.validated(
            host: 'example.com',
            port: port,
            algorithm: 'ssh-ed25519',
            publicKey: key,
          ).port,
          port,
        );
      }
      for (final port in [-1, 0, 65536]) {
        expect(
          () => HostKeyIdentity.validated(
            host: 'example.com',
            port: port,
            algorithm: 'ssh-ed25519',
            publicKey: key,
          ),
          throwsA(isA<SecurityFailure>()),
        );
      }
    });
  });
}
