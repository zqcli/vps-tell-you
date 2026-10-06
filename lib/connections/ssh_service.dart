import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import '../security/host_trust.dart';
import '../security/key_import.dart';
import '../security/security_controller.dart';
import '../security/security_models.dart';
import 'ssh_host_key_capture.dart';
import 'ssh_session_output.dart';
import 'ssh_socket_connector.dart';

export 'ssh_socket_connector.dart' show supportsNativeSsh;

enum SshStatus {
  idle,
  connecting,
  verifying,
  authenticating,
  connected,
  disconnected,
  failed,
}

enum SshPowerAction { reboot, shutdown }

enum PowerResult { submitted, unknown, failed }

String powerCommand(SshPowerAction action) => switch (action) {
  SshPowerAction.reboot => 'sudo -n shutdown -r now',
  SshPowerAction.shutdown => 'sudo -n shutdown -h now',
};

class SshTarget {
  const SshTarget({
    required this.name,
    required this.host,
    required this.username,
    required this.credentialId,
    this.port = 22,
    this.serverId,
  });
  final String name, host, username, credentialId;
  final int port;
  final String? serverId;
  String get label =>
      '$username@${host.contains(':') ? '[$host]' : host}:$port';

  SshTarget normalized() {
    if (port < 1 ||
        port > 65535 ||
        username.isEmpty ||
        username.length > 128 ||
        RegExp(r'[\x00-\x20\x7f]').hasMatch(username) ||
        credentialId.isEmpty) {
      throw const SecurityFailure('请检查 SSH 端口、用户名与凭据');
    }
    return SshTarget(
      name: name,
      host: normalizedHost(host),
      port: port,
      username: username,
      credentialId: credentialId,
      serverId: serverId,
    );
  }
}

class HostVerificationRequest {
  const HostVerificationRequest({
    required this.identity,
    required this.status,
    this.previous,
  });
  final HostKeyIdentity identity;
  final HostTrustStatus status;
  final HostTrustRecord? previous;
}

typedef HostVerifier = Future<bool> Function(HostVerificationRequest request);

/// Returns a transient local decryption passphrase, or null to cancel.
/// This is never a server-login password and is never persisted by SSH.
typedef KeyPassphraseRequester = Future<String?> Function(
  String credentialName,
);

abstract class SshService extends ChangeNotifier {
  SshStatus get status;
  String? get error;
  SshTarget? get target;
  int get generation;
  bool get connected => status == SshStatus.connected;
  Stream<String> get output;
  Future<void> connect(
    SshTarget target, {
    required HostVerifier verifyHost,
    KeyPassphraseRequester? requestKeyPassphrase,
  });
  void write(String value);
  void resize(int columns, int rows);
  void disconnect();
  Future<PowerResult> power(
    SshPowerAction action, {
    required int expectedGeneration,
  });
}

/// A page owns one service and one target. No retries, input replay, command
/// queue, agent forwarding, SFTP, or persistent/background connection manager.
class NativeSshService extends SshService {
  NativeSshService({
    required this.security,
    this.connectTimeout = const Duration(seconds: 10),
    this.handshakeTimeout = const Duration(seconds: 15),
    this.authTimeout = const Duration(seconds: 20),
    this.verificationTimeout = const Duration(minutes: 2),
    this.sessionTimeout = const Duration(seconds: 15),
  });
  final SecurityController security;
  final Duration connectTimeout,
      handshakeTimeout,
      authTimeout,
      verificationTimeout,
      sessionTimeout;
  final _output = StreamController<String>.broadcast(sync: true);
  @override
  Stream<String> get output => _output.stream;
  @override
  SshStatus status = SshStatus.idle;
  @override
  String? error;
  @override
  SshTarget? target;
  @override
  int generation = 0;
  bool _disposed = false;
  int _columns = 80, _rows = 24;
  int? _powerIssuedGeneration;
  SshSocketConnection? _connection;
  SSHClient? _client;
  SSHSession? _session;
  HostVerificationAttempt? _verification;
  Timer? _phaseTimer;
  SshSessionOutput? _sessionOutput;
  bool _draining = false;

  bool _active(int epoch) => !_disposed && epoch == generation;
  void _guard(int epoch) {
    if (!_active(epoch)) throw const SecurityFailure('SSH 连接已取消');
  }

  void _setStatus(SshStatus value) {
    status = value;
    if (!_disposed) notifyListeners();
  }

  void _deadline(int epoch, Duration duration, String message) {
    _phaseTimer?.cancel();
    _phaseTimer = Timer(duration, () {
      if (_active(epoch)) _fail(message);
    });
  }

  @override
  Future<void> connect(
    SshTarget requested, {
    required HostVerifier verifyHost,
    KeyPassphraseRequester? requestKeyPassphrase,
  }) async {
    if (_disposed) return;
    _release();
    final epoch = ++generation;
    error = null;
    target = null;
    _setStatus(SshStatus.connecting);
    try {
      if (!supportsNativeSsh) {
        throw const SecurityFailure('浏览器不支持原生 SSH，请使用原生应用');
      }
      final next = requested.normalized();
      target = next;
      _deadline(epoch, authTimeout, '读取 SSH 凭据超时');
      final credential = await security.loadSshCredential(
        next.credentialId,
        isCancelled: () => !_active(epoch),
      );
      _guard(epoch);
      SSHKeyPair? key;
      if (credential.metadata.kind == CredentialKind.privateKey) {
        var passphrase = credential.passphrase;
        if (SSHKeyPair.isEncryptedPem(credential.secret) &&
            (passphrase == null || passphrase.isEmpty)) {
          if (requestKeyPassphrase == null) {
            throw const SecurityFailure('此私钥需要解密口令，请重新连接并输入');
          }
          _deadline(epoch, verificationTimeout, '输入私钥口令超时，未进行连接');
          passphrase = await requestKeyPassphrase(credential.metadata.name);
          _guard(epoch);
          if (passphrase == null || passphrase.isEmpty) {
            throw const SecurityFailure('已取消私钥口令输入，未进行连接');
          }
          if (passphrase.length > 4096) {
            throw const SecurityFailure('私钥口令超出长度限制');
          }
        }
        _deadline(epoch, authTimeout, '私钥解密超时，未进行连接');
        key = await compute(_parseCredentialKey, (credential, passphrase));
        passphrase = null;
      }
      _guard(epoch);
      _deadline(epoch, connectTimeout, 'SSH TCP 连接超时');
      final connection = SshSocketConnection(next.host, next.port);
      _connection = connection;
      final native = await connection.socket;
      if (!_active(epoch)) {
        native.destroy();
        return;
      }
      final socket = CapturedSshSocket(native);
      _deadline(epoch, handshakeTimeout, 'SSH 握手超时');
      final signingKey = key;
      var authAllowed = false;
      Future<void> authGuard() async {
        _guard(epoch);
        if (!authAllowed ||
            _verification?.cancelled != false ||
            !await security.isCredentialCurrent(credential.metadata)) {
          throw const SecurityFailure('主机核验或凭据已变化，认证已阻止');
        }
        _guard(epoch);
        if (_verification?.cancelled != false) {
          throw const SecurityFailure('SSH 核验已取消');
        }
      }

      final client = SSHClient(
        socket,
        username: next.username,
        // Library signature verification stays enabled. Logs/trace never see
        // passwords, keys, commands, terminal output or native exceptions.
        handshakeTimeout: handshakeTimeout + verificationTimeout + authTimeout,
        authTimeout: authTimeout,
        keepAliveInterval: const Duration(seconds: 15),
        onVerifyHostKey: (type, fingerprint) async {
          _guard(epoch);
          final identity = socket.capture.verifiedIdentity(
            host: next.host,
            port: next.port,
            negotiatedType: type,
            fingerprint: fingerprint,
          );
          final attempt = security.beginHostVerification(identity);
          _verification = attempt;
          final trust = await attempt.check();
          _guard(epoch);
          if (attempt.cancelled) return false;
          if (trust != HostTrustStatus.trusted) {
            final previous = await security.store.hostTrust(
              next.host,
              next.port,
            );
            _guard(epoch);
            _setStatus(SshStatus.verifying);
            _deadline(epoch, verificationTimeout, '主机核验超时，未进行认证');
            final accepted = await verifyHost(
              HostVerificationRequest(
                identity: identity,
                status: trust,
                previous: previous,
              ),
            );
            _guard(epoch);
            if (!accepted || attempt.cancelled) {
              attempt.reject();
              return false;
            }
            if (!await attempt.confirm(expected: previous)) return false;
            _guard(epoch);
          }
          final permitted = await attempt.authenticate(() async {
            if (!await security.isCredentialCurrent(credential.metadata)) {
              throw const SecurityFailure('凭据已变化，请重新连接');
            }
            _guard(epoch);
            if (attempt.cancelled) throw const SecurityFailure('SSH 核验已取消');
            authAllowed = true;
          });
          _guard(epoch);
          if (!permitted || attempt.cancelled) return false;
          _setStatus(SshStatus.authenticating);
          _deadline(epoch, authTimeout, 'SSH 认证超时');
          return true;
        },
        identities: signingKey == null
            ? null
            : [
                SSHIdentity.custom(
                  type: signingKey.type,
                  publicKey: signingKey.toPublicKey(),
                  signer: (data) async {
                    await authGuard();
                    return signingKey.sign(data);
                  },
                ),
              ],
        onPasswordRequest: signingKey != null
            ? null
            : () async {
                await authGuard();
                return credential.secret;
              },
      );
      _client = client;
      unawaited(
        client.done.then(
          (_) => _finishRemoteClose(epoch),
          onError: (Object _) => _finishRemoteClose(epoch),
        ),
      );
      await client.authenticated;
      _guard(epoch);
      _deadline(epoch, sessionTimeout, 'SSH 终端开启超时');
      final session = await client.shell(
        pty: SSHPtyConfig(width: _columns, height: _rows),
      );
      if (!_active(epoch)) {
        session.close();
        return;
      }
      _session = session;
      _phaseTimer?.cancel();
      _sessionOutput = SshSessionOutput(
        session.stdout,
        session.stderr,
        onData: (text) {
          if (_active(epoch)) _output.add(text);
        },
      );
      unawaited(
        session.done.then(
          (_) => _finishRemoteClose(epoch),
          onError: (Object _) => _finishRemoteClose(epoch),
        ),
      );
      _setStatus(SshStatus.connected);
      // A resize may have arrived while the PTY request was awaiting its reply.
      session.resizeTerminal(_columns, _rows);
    } catch (problem) {
      if (_active(epoch)) {
        _fail(
          problem is SecurityFailure
              ? problem.message
              : status == SshStatus.authenticating
              ? 'SSH 认证失败，请检查用户名和凭据'
              : status == SshStatus.verifying
              ? '主机未获信任，未进行认证'
              : 'SSH 连接未完成，请检查地址、网络与服务',
        );
      }
    }
  }

  Future<void> _finishRemoteClose(int epoch) async {
    if (!_active(epoch) || !connected) return;
    _draining = true;
    await _sessionOutput?.done;
    if (_active(epoch)) _remoteClosed(epoch);
  }

  void _remoteClosed(int epoch) {
    if (!_active(epoch)) return;
    _release();
    generation++;
    error = 'SSH 会话已结束；命令是否完成请在重连后核实';
    _setStatus(SshStatus.disconnected);
  }

  void _fail(String message) {
    _release();
    generation++;
    error = message;
    _setStatus(SshStatus.failed);
  }

  @override
  void write(String value) {
    if (!connected ||
        _disposed ||
        _draining ||
        _client?.isClosed != false ||
        value.isEmpty) {
      return;
    }
    try {
      _session?.write(Uint8List.fromList(utf8.encode(value)));
    } catch (_) {
      _fail('SSH 输入未能发送；请重连后核实');
    }
  }

  @override
  void resize(int columns, int rows) {
    _columns = columns.clamp(1, 1000);
    _rows = rows.clamp(1, 1000);
    if (connected && !_draining && _client?.isClosed == false) {
      try {
        _session?.resizeTerminal(_columns, _rows);
      } catch (_) {
        _fail('SSH 终端大小调整失败，请重连');
      }
    }
  }

  @override
  Future<PowerResult> power(
    SshPowerAction action, {
    required int expectedGeneration,
  }) async {
    if (!connected ||
        _draining ||
        !_active(expectedGeneration) ||
        _client?.isClosed != false ||
        _powerIssuedGeneration == generation) {
      return PowerResult.failed;
    }
    _powerIssuedGeneration = generation;
    final client = _client!;
    SSHSession? command;
    try {
      // Reservation precedes the first await; never retry an uncertain send.
      command = await client
          .execute(powerCommand(action))
          .timeout(sessionTimeout);
      if (!_active(expectedGeneration)) {
        command.close();
        return PowerResult.unknown;
      }
      command.stdout.listen((_) {}, onError: (Object _) {});
      command.stderr.listen((_) {}, onError: (Object _) {});
      await command.done.timeout(sessionTimeout);
      return command.exitCode == 0
          ? PowerResult.submitted
          : command.exitCode == null
          ? PowerResult.unknown
          : PowerResult.failed;
    } catch (_) {
      // A timed-out channel must never submit a delayed exec later.
      if (_active(expectedGeneration)) disconnect();
      return PowerResult.unknown;
    } finally {
      command?.close();
    }
  }

  void _release() {
    _phaseTimer?.cancel();
    _phaseTimer = null;
    _verification?.cancel();
    _verification = null;
    _sessionOutput?.cancel();
    _sessionOutput = null;
    _draining = false;
    _session?.close();
    _session = null;
    final client = _client;
    _client = null;
    if (client != null) unawaited(client.close().catchError((Object _) {}));
    _connection?.cancel();
    _connection = null;
  }

  @override
  void disconnect() {
    if (_disposed) return;
    _release();
    generation++;
    error = null;
    _setStatus(SshStatus.disconnected);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    generation++;
    _release();
    unawaited(_output.close());
    super.dispose();
  }
}

SSHKeyPair _parseCredentialKey((SshCredential, String?) input) {
  final credential = input.$1;
  final key = parseValidatedPrivateKey(credential.secret, passphrase: input.$2);
  final identity = HostKeyIdentity.validated(
    host: 'localhost',
    algorithm: key.name,
    publicKey: base64Encode(key.toPublicKey().encode()),
  );
  if (identity.algorithm != credential.metadata.keyAlgorithm ||
      identity.fingerprint != credential.metadata.fingerprint) {
    throw const SecurityFailure('密钥与已保存的公开资料不一致');
  }
  return key;
}
