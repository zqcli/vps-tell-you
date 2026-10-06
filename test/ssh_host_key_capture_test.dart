import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/connections/ssh_host_key_capture.dart';
import 'package:vps_tell_you/security/host_trust.dart';
import 'package:vps_tell_you/security/security_models.dart';

Uint8List packet(List<int> payload) {
  var padding = 4;
  while ((payload.length + padding + 5) % 8 != 0) {
    padding++;
  }
  final size = payload.length + padding + 1;
  return Uint8List.fromList([
    ...u32(size),
    padding,
    ...payload,
    ...List.filled(padding, 0),
  ]);
}

List<int> u32(int value) => [
  value >> 24 & 255,
  value >> 16 & 255,
  value >> 8 & 255,
  value & 255,
];
List<int> field(List<int> bytes) => [...u32(bytes.length), ...bytes];

void main() {
  final line = File('test/fixtures/security/ecdsa.fixture.pub')
      .readAsStringSync()
      .trim();
  final type = line.split(' ').first;
  final key = base64Decode(line.split(' ')[1]);
  final identity = HostKeyIdentity.validated(
    host: 'localhost',
    algorithm: type,
    publicKey: base64Encode(key),
  );
  HostKeyIdentity verify(
    SshHostKeyCapture capture, {
    String? fingerprint,
    String? algorithm,
  }) => capture.verifiedIdentity(
    host: 'localhost',
    port: 22,
    negotiatedType: algorithm ?? type,
    fingerprint: Uint8List.fromList(
      utf8.encode(fingerprint ?? identity.fingerprint),
    ),
  );

  test('fragmented SSH identification and DH/ECDH reply bind full key to verified SHA256', () {
    final bytes = [
      ...utf8.encode('fixture banner\r\nSSH-2.0-Fixture\r\n'),
      ...packet([20, ...List.filled(40, 0)]),
      ...packet([
        31,
        ...field(key),
        ...field([1, 2]),
        ...field([3]),
      ]),
    ];
    for (final chunkSize in [1, 3, 11, 10000]) {
      final capture = SshHostKeyCapture();
      for (var i = 0; i < bytes.length; i += chunkSize) {
        capture.add(
          Uint8List.fromList(
            bytes.sublist(i, (i + chunkSize).clamp(0, bytes.length)),
          ),
        );
      }
      expect(verify(capture).publicKey, identity.publicKey);
      expect(
        () => verify(capture, fingerprint: 'SHA256:wrong'),
        throwsA(isA<SecurityFailure>()),
      );
      expect(
        () => verify(capture, algorithm: 'ssh-ed25519'),
        throwsA(isA<SecurityFailure>()),
      );
    }
  });

  test('GEX prime is not a key; message 33 accepted and NEWKEYS stops observing rekeys', () {
    final capture = SshHostKeyCapture();
    capture.add(
      Uint8List.fromList([
        ...utf8.encode('SSH-2.0-Fixture\r\n'),
        ...packet([
          31,
          ...field(List.filled(256, 251)),
          ...field([2]),
        ]),
        ...packet([
          33,
          ...field(key),
          ...field([1]),
          ...field([2]),
        ]),
        ...packet([21]),
        ...List.filled(300000, 255),
      ]),
    );
    expect(verify(capture).fingerprint, identity.fingerprint);
    // Later network bytes, including encrypted rekeys, are solely the library's
    // concern. They must not expand memory or replace the original candidate.
    capture.add(Uint8List.fromList(List.filled(300000, 255)));
    expect(verify(capture).fingerprint, identity.fingerprint);
  });

  test('RSA SHA2 signature algorithm binds to ssh-rsa wire type', () {
    final rsaLine = File('test/fixtures/security/rsa.fixture.pub')
        .readAsStringSync()
        .trim();
    final rsaKey = base64Decode(rsaLine.split(' ')[1]);
    final rsaIdentity = HostKeyIdentity.validated(
      host: 'localhost',
      algorithm: 'ssh-rsa',
      publicKey: base64Encode(rsaKey),
    );
    final capture = SshHostKeyCapture();
    capture.add(
      Uint8List.fromList([
        ...utf8.encode('SSH-2.0-Fixture\r\n'),
        ...packet([31, ...field(rsaKey)]),
      ]),
    );
    expect(
      verify(
        capture,
        algorithm: 'rsa-sha2-512',
        fingerprint: rsaIdentity.fingerprint,
      ).algorithm,
      'ssh-rsa',
    );
  });

  test(
    'malformed or oversized frames fail closed and erase prior candidates',
    () {
      final invalid = <List<int>>[
        u32(100000),
        [...u32(12), 0, ...List.filled(11, 0)],
        packet([31, ...u32(100000), 1]),
        packet([31, ...u32(20), 1]),
        [...u32(7), 4, ...List.filled(6, 0)],
      ];
      for (final tail in invalid) {
        final capture = SshHostKeyCapture();
        capture.add(
          Uint8List.fromList([
            ...utf8.encode('SSH-2.0-Fixture\r\n'),
            ...packet([31, ...field(key)]),
          ]),
        );
        expect(
          () => capture.add(Uint8List.fromList(tail)),
          throwsA(isA<SecurityFailure>()),
        );
        expect(() => verify(capture), throwsA(isA<SecurityFailure>()));
      }
    },
  );

  test(
    'bounded pre-NEWKEYS banner, aggregate packets, and candidate count',
    () {
      final cases = [
        utf8.encode('${'x' * 8193}\n'),
        utf8.encode('SSH-2.0-${'x' * 250}\r\n'),
        [
          ...utf8.encode('SSH-2.0-Fixture\r\n'),
          for (var i = 0; i < 9; i++) ...packet([31, ...field(key)]),
        ],
        [
          ...utf8.encode('SSH-2.0-Fixture\r\n'),
          for (var i = 0; i < 8; i++) ...packet([2, ...List.filled(60000, 0)]),
        ],
      ];
      for (final bytes in cases) {
        final capture = SshHostKeyCapture();
        expect(
          () => capture.add(Uint8List.fromList(bytes)),
          throwsA(isA<SecurityFailure>()),
        );
      }
    },
  );
}
