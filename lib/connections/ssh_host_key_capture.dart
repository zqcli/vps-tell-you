import '../l10n/localized_message.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../security/host_trust.dart';
import '../security/security_models.dart';

/// dartssh2 4.1.0 exposes a signature-verified SHA256 fingerprint, but no full
/// host-key blob. Observe only the initial cleartext SSH framing; never change
/// bytes or implement cryptography. Candidates become identities ONLY when
/// bound to the library's verified fingerprint in [verifiedIdentity].
///
/// Bounded to 256 KiB before NEWKEYS, 64 KiB packets, 32 KiB key fields, and 8
/// candidates. Handles DH/ECDH reply 31 and group-exchange reply 33. Stops before
/// encrypted traffic, including all rekeys (which dartssh2 pins internally).
class SshHostKeyCapture {
  final List<int> _buffer = [];
  final List<Uint8List> _candidates = [];
  bool _versionSeen = false, _finished = false;
  int _total = 0;

  void add(Uint8List data) {
    if (_finished) {
      return;
    }
    for (final byte in data) {
      if (_finished) {
        break;
      }
      if (++_total > 256 * 1024) {
        _invalid();
      }
      _buffer.add(byte);
      if (!_versionSeen) {
        if (_buffer.length > 8192) {
          _invalid();
        }
        if (byte != 10) {
          continue;
        }
        if (_buffer.length >= 4 &&
            _buffer[0] == 83 &&
            _buffer[1] == 83 &&
            _buffer[2] == 72 &&
            _buffer[3] == 45) {
          if (_buffer.length > 255) {
            _invalid();
          }
          _versionSeen = true;
        }
        _buffer.clear();
        continue;
      }
      if (_buffer.length < 4) {
        continue;
      }
      final length = _uint32(_buffer, 0);
      if (length < 6 || length > 64 * 1024) {
        _invalid();
      }
      if (_buffer.length < length + 4) {
        continue;
      }
      final padding = _buffer[4];
      final payloadEnd = length + 4 - padding;
      if (padding < 4 || payloadEnd <= 5 || (length + 4) % 8 != 0) {
        _invalid();
      }
      final message = _buffer[5];
      if (message == 21) {
        _finished = true;
      } else if (message == 31 || message == 33) {
        if (payloadEnd < 10) {
          _invalid();
        }
        final keyLength = _uint32(_buffer, 6);
        if (keyLength > 32 * 1024 || keyLength > payloadEnd - 10) {
          _invalid();
        }
        if (_candidates.length >= 8) {
          _invalid();
        }
        // For group-exchange message 31 this is a DH prime, not a key. It
        // cannot pass full key parsing + the verified SHA256 binding below.
        _candidates.add(
          Uint8List.fromList(_buffer.sublist(10, 10 + keyLength)),
        );
      }
      _buffer.clear();
    }
  }

  HostKeyIdentity verifiedIdentity({
    required String host,
    required int port,
    required String negotiatedType,
    required Uint8List fingerprint,
  }) {
    final expected = utf8.decode(fingerprint, allowMalformed: false);
    final wireType = negotiatedType.startsWith('rsa-sha2-')
        ? 'ssh-rsa'
        : negotiatedType;
    for (final bytes in _candidates) {
      try {
        final key = HostKeyIdentity.validated(
          host: host,
          port: port,
          algorithm: wireType,
          publicKey: base64Encode(bytes),
        );
        if (key.fingerprint == expected) {
          return key;
        }
      } on SecurityFailure {
        // A guessed KEX packet or group prime is never accepted as a key.
      }
    }
    throw SecurityFailure(
      LocalizedText((l10n) => l10n.connectionHostKeyUnverified),
    );
  }

  static int _uint32(List<int> bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
  Never _invalid() {
    _finished = true;
    _buffer.clear();
    _candidates.clear();
    throw SecurityFailure(
      LocalizedText((l10n) => l10n.connectionHandshakeUnsupported),
    );
  }
}

class CapturedSshSocket implements SSHSocket {
  CapturedSshSocket(this.socket);
  final SSHSocket socket;
  final capture = SshHostKeyCapture();
  @override
  Stream<Uint8List> get stream => socket.stream.map((bytes) {
    try {
      capture.add(bytes);
    } catch (_) {
      socket.destroy();
      rethrow;
    }
    return bytes;
  });
  @override
  StreamSink<List<int>> get sink => socket.sink;
  @override
  Future<void> get done => socket.done;
  @override
  Future<void> close() => socket.close();
  @override
  void destroy() => socket.destroy();
  @override
  Future<void> flush() => socket.flush();
}
