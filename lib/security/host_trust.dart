import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'security_models.dart';

enum HostTrustStatus { firstUse, trusted, changed }

/// Host identity excludes schemes, paths, usernames, ports, and scope IDs.
/// DNS is ASCII (IDNs must already be punycode); numeric IP aliases fail closed.
String normalizedHost(String value) {
  try {
    var host = value.trim().toLowerCase();
    if (host.isEmpty || host.length > 255) throw const FormatException();
    if (host.startsWith('[') && host.endsWith(']')) {
      host = host.substring(1, host.length - 1);
      if (!host.contains(':')) throw const FormatException();
    }
    if (host.contains(':')) return _ipv6Text(Uri.parseIPv6Address(host));
    if (host.endsWith('.')) host = host.substring(0, host.length - 1);
    if (host
        .split('.')
        .every((part) => RegExp(r'^(?:[0-9]+|0x[0-9a-f]+)$').hasMatch(part))) {
      return Uri.parseIPv4Address(host).join('.');
    }
    if (host.isEmpty || host.length > 253) throw const FormatException();
    final label = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
    if (host.split('.').any((part) => !label.hasMatch(part))) {
      throw const FormatException();
    }
    return host;
  } catch (_) {
    throw const SecurityFailure('主机地址无效，请填写 IP 或域名，不含协议、用户名、端口或路径');
  }
}

class HostKeyIdentity {
  const HostKeyIdentity._({
    required this.host,
    required this.port,
    required this.algorithm,
    required this.publicKey,
    required this.fingerprint,
  });

  /// [algorithm] is the wire key type, not a negotiated signature algorithm.
  /// RSA public blobs use `ssh-rsa` even with `rsa-sha2-256/512` signatures.
  /// Supports Ed25519, 1024–8192-bit RSA, and uncompressed NIST ECDSA keys.
  /// This validates key structure; the SSH adapter must still verify the
  /// server's handshake signature before any authentication is released.
  factory HostKeyIdentity.validated({
    required String host,
    int port = 22,
    required String algorithm,
    required String publicKey,
  }) {
    final normalized = normalizedHost(host);
    if (port < 1 || port > 65535) {
      throw const SecurityFailure('SSH 端口应为 1–65535');
    }
    try {
      if (publicKey.length > 32 * 1024) throw const FormatException();
      final type = algorithm.trim();
      final text = publicKey.trim();
      if (text.contains('\n') || text.contains('\r')) {
        throw const FormatException();
      }
      final parts = text.split(RegExp(r'\s+'));
      final encoded = parts.length == 1 ? parts.single : parts[1];
      if (parts.length > 1 && parts.first != type) {
        throw const FormatException();
      }
      // Accept standard base64 only, not URI escapes or URL-safe variants.
      if (!RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(encoded)) {
        throw const FormatException();
      }
      final bytes = base64Decode(encoded);
      final reader = _PublicKeyReader(bytes);
      if (reader.text() != type) throw const FormatException();
      switch (type) {
        case 'ssh-ed25519':
          final key = reader.field();
          if (key.length != 32 || key.every((byte) => byte == 0)) {
            throw const FormatException();
          }
        case 'ssh-rsa':
          final exponent = reader.positiveMpint();
          final modulus = reader.positiveMpint();
          if (exponent < BigInt.from(3) ||
              exponent.isEven ||
              modulus <= exponent ||
              modulus.isEven ||
              modulus.bitLength < 1024 ||
              modulus.bitLength > 8192) {
            throw const FormatException();
          }
        case 'ecdsa-sha2-nistp256':
        case 'ecdsa-sha2-nistp384':
        case 'ecdsa-sha2-nistp521':
          final curve = reader.text();
          if (type != 'ecdsa-sha2-$curve') throw const FormatException();
          final size = switch (curve) {
            'nistp256' => 65,
            'nistp384' => 97,
            'nistp521' => 133,
            _ => throw const FormatException(),
          };
          final point = reader.field();
          if (point.length != size ||
              point.first != 4 ||
              point.skip(1).every((byte) => byte == 0)) {
            throw const FormatException();
          }
        default:
          throw const FormatException();
      }
      if (!reader.isDone) throw const FormatException();
      return HostKeyIdentity._(
        host: normalized,
        port: port,
        algorithm: type,
        publicKey: base64Encode(bytes),
        fingerprint:
            'SHA256:${base64Encode(sha256.convert(bytes).bytes).replaceAll('=', '')}',
      );
    } catch (_) {
      throw const SecurityFailure('无法识别主机公钥，请检查完整公钥内容及所选类型');
    }
  }

  final String host;
  final int port;
  final String algorithm;

  /// Full canonical SSH public-key blob, including its embedded algorithm.
  final String publicKey;
  final String fingerprint;
}

class _PublicKeyReader {
  _PublicKeyReader(this.bytes);

  final Uint8List bytes;
  int offset = 0;

  bool get isDone => offset == bytes.length;

  Uint8List field() {
    if (bytes.length - offset < 4) throw const FormatException();
    final length = ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);
    offset += 4;
    if (length > bytes.length - offset) throw const FormatException();
    final value = Uint8List.sublistView(bytes, offset, offset + length);
    offset += length;
    return value;
  }

  String text() => utf8.decode(field());

  BigInt positiveMpint() {
    final value = field();
    if (value.isEmpty ||
        value.length > 1025 ||
        value.first >= 128 ||
        (value.first == 0 && (value.length == 1 || value[1] < 128))) {
      throw const FormatException();
    }
    var result = BigInt.zero;
    for (final byte in value) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }
}

String _ipv6Text(List<int> bytes) {
  final groups = List<int>.generate(
    8,
    (index) => (bytes[index * 2] << 8) | bytes[index * 2 + 1],
  );
  var longestStart = -1;
  var longestLength = 1;
  for (var index = 0; index < groups.length;) {
    if (groups[index] != 0) {
      index++;
      continue;
    }
    final start = index;
    while (index < groups.length && groups[index] == 0) {
      index++;
    }
    if (index - start > longestLength) {
      longestStart = start;
      longestLength = index - start;
    }
  }
  String join(Iterable<int> values) =>
      values.map((part) => part.toRadixString(16)).join(':');
  if (longestStart < 0) return join(groups);
  return '${join(groups.take(longestStart))}::'
      '${join(groups.skip(longestStart + longestLength))}';
}
