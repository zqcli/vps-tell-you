import '../l10n/localized_message.dart';
import '../l10n/locale_preference.dart';
import '../l10n/generated/app_localizations.dart';

import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import '../security/host_trust.dart';
import '../security/key_import.dart';
import '../security/security_controller.dart';
import '../security/security_models.dart';
import 'sftp_session.dart';
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
    this.isTemporary = false,
  });
  final String name, host, username, credentialId;
  final bool isTemporary;
  String displayNameFor(AppLocalizations l10n) =>
      isTemporary ? l10n.connectionTemporary : name;
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
      throw SecurityFailure(LocalizedText((l10n) => l10n.sshCheckTarget));
    }
    return SshTarget(
      name: name,
      host: normalizedHost(host),
      port: port,
      username: username,
      credentialId: credentialId,
      serverId: serverId,
      isTemporary: isTemporary,
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
  String? errorFor(AppLocalizations l10n) => error;
  SshTarget? get target;
  int get generation;
  bool get connected => status == SshStatus.connected;

  /// Local input readiness, not proof that a remote command has executed.
  bool get acceptsInput => connected;
  Stream<String> get output;
  Future<void> connect(
    SshTarget target, {
    required HostVerifier verifyHost,
    KeyPassphraseRequester? requestKeyPassphrase,
  });

  /// Opens the SFTP subsystem as another channel on this service's live SSH
  /// connection (no re-authentication, nothing written to the shell). Closing
  /// the returned session closes only that channel.
  Future<SftpSession> openSftpOnClient() async =>
      throw const SftpException(SftpErrorKind.unavailable);

  /// Connects without a shell and returns an SFTP session. Host verification,
  /// credential loading and authentication are exactly those of [connect].
  /// Closing the session closes the connection. Failures throw the same
  /// [SecurityFailure] messages as [connect] (also readable from [error]).
  Future<SftpSession> connectSftp(
    SshTarget requested, {
    required HostVerifier verifyHost,
    KeyPassphraseRequester? requestKeyPassphrase,
  }) async => throw const SftpException(SftpErrorKind.unavailable);
  void write(String value);
  void resize(int columns, int rows);
  void disconnect();
  Future<PowerResult> power(
    SshPowerAction action, {
    required int expectedGeneration,
  });
}

/// A page owns one service and one target. No retries, input replay, command
/// queue, agent forwarding, or persistent/background connection manager. SFTP
/// is either a channel on the live connection ([openSftpOnClient]) or a
/// shell-less connection of its own ([connectSftp]); both reuse this class's
/// single verification/authentication path.
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
  String? get error => localizedError?.messageFor(defaultLocalizations);
  LocalizedMessage? localizedError;
  @override
  String? errorFor(AppLocalizations l10n) => localizedError?.messageFor(l10n);
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
  final _sftpSessions = <SftpSession>{};

  bool _active(int epoch) => !_disposed && epoch == generation;
  void _guard(int epoch) {
    if (!_active(epoch)) {
      throw SecurityFailure(
        LocalizedText((l10n) => l10n.sshConnectionCancelled),
      );
    }
  }

  void _setStatus(SshStatus value) {
    status = value;
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _deadline(int epoch, Duration duration, LocalizedMessage message) {
    _phaseTimer?.cancel();
    _phaseTimer = Timer(duration, () {
      if (_active(epoch)) {
        _fail(message);
      }
    });
  }

  @override
  Future<void> connect(
    SshTarget requested, {
    required HostVerifier verifyHost,
    KeyPassphraseRequester? requestKeyPassphrase,
  }) => _connect<void>(requested, verifyHost, requestKeyPassphrase, _openShell);

  @override
  Future<SftpSession> connectSftp(
    SshTarget requested, {
    required HostVerifier verifyHost,
    KeyPassphraseRequester? requestKeyPassphrase,
  }) async {
    final session = await _connect<SftpSession>(
      requested,
      verifyHost,
      requestKeyPassphrase,
      (epoch, client) async {
        _deadline(
          epoch,
          sessionTimeout + const Duration(seconds: 2),
          LocalizedText((l10n) => l10n.r3SftpOpenTimeout),
        );
        late final DartSshSftpSession opened;
        try {
          opened = await DartSshSftpSession.open(
            client,
            ownsClient: true,
            openTimeout: sessionTimeout,
            onClose: () {
              _sftpSessions.remove(opened);
              // User-initiated close of a standalone SFTP connection.
              if (!_disposed && connected) {
                disconnect();
              }
            },
          );
        } on SftpException catch (problem) {
          throw SecurityFailure(
            LocalizedText(
              (l10n) => problem.kind == SftpErrorKind.timeout
                  ? l10n.r3SftpOpenTimeout
                  : problem.kind == SftpErrorKind.unavailable
                  ? l10n.r3SftpUnavailable
                  : l10n.sshConnectionIncomplete,
            ),
          );
        }
        if (!_active(epoch)) {
          await opened.close();
          return null;
        }
        _sftpSessions.add(opened);
        _phaseTimer?.cancel();
        _setStatus(SshStatus.connected);
        return opened;
      },
    );
    if (session == null) {
      throw localizedError == null
          ? SecurityFailure(
              LocalizedText((l10n) => l10n.sshConnectionCancelled),
            )
          : SecurityFailure(localizedError);
    }
    return session;
  }

  @override
  Future<SftpSession> openSftpOnClient() async {
    final client = _client;
    final epoch = generation;
    if (!connected ||
        _disposed ||
        _draining ||
        client == null ||
        client.isClosed) {
      throw const SftpException(SftpErrorKind.connectionLost);
    }
    late final DartSshSftpSession opened;
    opened = await DartSshSftpSession.open(
      client,
      openTimeout: sessionTimeout,
      onClose: () => _sftpSessions.remove(opened),
    );
    if (!_active(epoch) || client.isClosed) {
      await opened.close();
      throw const SftpException(SftpErrorKind.connectionLost);
    }
    _sftpSessions.add(opened);
    return opened;
  }

  Future<T?> _connect<T>(
    SshTarget requested,
    HostVerifier verifyHost,
    KeyPassphraseRequester? requestKeyPassphrase,
    Future<T?> Function(int epoch, SSHClient client) openChannel,
  ) async {
    if (_disposed) {
      return null;
    }
    _release();
    final epoch = ++generation;
    localizedError = null;
    target = null;
    _setStatus(SshStatus.connecting);
    try {
      if (!supportsNativeSsh) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.sshBrowserUnsupported),
        );
      }
      final next = requested.normalized();
      target = next;
      _deadline(
        epoch,
        authTimeout,
        LocalizedText((l10n) => l10n.sshCredentialReadTimeout),
      );
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
            throw SecurityFailure(
              LocalizedText((l10n) => l10n.sshKeyNeedsPassphrase),
            );
          }
          _deadline(
            epoch,
            verificationTimeout,
            LocalizedText((l10n) => l10n.sshPassphraseInputTimeout),
          );
          passphrase = await requestKeyPassphrase(credential.metadata.name);
          _guard(epoch);
          if (passphrase == null || passphrase.isEmpty) {
            throw SecurityFailure(
              LocalizedText((l10n) => l10n.sshPassphraseCancelled),
            );
          }
          if (passphrase.length > 4096) {
            throw SecurityFailure(
              LocalizedText((l10n) => l10n.sshPassphraseTooLong),
            );
          }
        }
        _deadline(
          epoch,
          authTimeout,
          LocalizedText((l10n) => l10n.sshKeyDecryptionTimeout),
        );
        key = await compute(_parseCredentialKey, (credential, passphrase));
        passphrase = null;
      }
      _guard(epoch);
      _deadline(
        epoch,
        connectTimeout,
        LocalizedText((l10n) => l10n.sshTcpTimeout),
      );
      final connection = SshSocketConnection(next.host, next.port);
      _connection = connection;
      final native = await connection.socket;
      if (!_active(epoch)) {
        native.destroy();
        return null;
      }
      final socket = CapturedSshSocket(native);
      _deadline(
        epoch,
        handshakeTimeout,
        LocalizedText((l10n) => l10n.sshHandshakeTimeout),
      );
      final signingKey = key;
      var authAllowed = false;
      Future<void> authGuard() async {
        _guard(epoch);
        if (!authAllowed ||
            _verification?.cancelled != false ||
            !await security.isCredentialCurrent(credential.metadata)) {
          throw SecurityFailure(
            LocalizedText((l10n) => l10n.sshIdentityChanged),
          );
        }
        _guard(epoch);
        if (_verification?.cancelled != false) {
          throw SecurityFailure(
            LocalizedText((l10n) => l10n.sshVerificationCancelled),
          );
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
          if (attempt.cancelled) {
            return false;
          }
          if (trust != HostTrustStatus.trusted) {
            final previous = await security.store.hostTrust(
              next.host,
              next.port,
            );
            _guard(epoch);
            _setStatus(SshStatus.verifying);
            _deadline(
              epoch,
              verificationTimeout,
              LocalizedText((l10n) => l10n.sshVerificationTimeout),
            );
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
            if (!await attempt.confirm(expected: previous)) {
              return false;
            }
            _guard(epoch);
          }
          final permitted = await attempt.authenticate(() async {
            if (!await security.isCredentialCurrent(credential.metadata)) {
              throw SecurityFailure(
                LocalizedText((l10n) => l10n.sshCredentialChanged),
              );
            }
            _guard(epoch);
            if (attempt.cancelled) {
              throw SecurityFailure(
                LocalizedText((l10n) => l10n.sshVerificationCancelled),
              );
            }
            authAllowed = true;
          });
          _guard(epoch);
          if (!permitted || attempt.cancelled) {
            return false;
          }
          _setStatus(SshStatus.authenticating);
          _deadline(
            epoch,
            authTimeout,
            LocalizedText((l10n) => l10n.sshAuthenticationTimeout),
          );
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
      return await openChannel(epoch, client);
    } catch (problem) {
      if (_active(epoch)) {
        _fail(
          problem is SecurityFailure
              ? problem
              : status == SshStatus.authenticating
              ? LocalizedText((l10n) => l10n.sshAuthenticationFailed)
              : status == SshStatus.verifying
              ? LocalizedText((l10n) => l10n.sshHostNotTrusted)
              : LocalizedText((l10n) => l10n.sshConnectionIncomplete),
        );
      }
    }
    return null;
  }

  Future<void> _openShell(int epoch, SSHClient client) async {
    _deadline(
      epoch,
      sessionTimeout,
      LocalizedText((l10n) => l10n.sshTerminalOpenTimeout),
    );
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
        if (_active(epoch)) {
          _output.add(text);
        }
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
  }

  Future<void> _finishRemoteClose(int epoch) async {
    if (!_active(epoch) || !connected) {
      return;
    }
    _draining = true;
    await _sessionOutput?.done;
    if (_active(epoch)) {
      _remoteClosed(epoch);
    }
  }

  void _remoteClosed(int epoch) {
    if (!_active(epoch)) {
      return;
    }
    _release();
    generation++;
    localizedError = LocalizedText((l10n) => l10n.sshSessionEnded);
    _setStatus(SshStatus.disconnected);
  }

  void _fail(LocalizedMessage message) {
    _release();
    generation++;
    localizedError = message;
    _setStatus(SshStatus.failed);
  }

  @override
  bool get acceptsInput =>
      connected &&
      !_disposed &&
      !_draining &&
      _client?.isClosed == false &&
      _session != null;

  @override
  void write(String value) {
    if (!acceptsInput || value.isEmpty) {
      return;
    }
    try {
      _session?.write(Uint8List.fromList(utf8.encode(value)));
    } catch (_) {
      _fail(LocalizedText((l10n) => l10n.sshInputUnconfirmed));
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
        _fail(LocalizedText((l10n) => l10n.sshResizeFailed));
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
      if (_active(expectedGeneration)) {
        disconnect();
      }
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
    final sftpSessions = _sftpSessions.toList();
    _sftpSessions.clear();
    for (final sftp in sftpSessions) {
      unawaited(sftp.close());
    }
    final client = _client;
    _client = null;
    if (client != null) {
      unawaited(client.close().catchError((Object _) {}));
    }
    _connection?.cancel();
    _connection = null;
  }

  @override
  void disconnect() {
    if (_disposed) {
      return;
    }
    _release();
    generation++;
    localizedError = null;
    _setStatus(SshStatus.disconnected);
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
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
    throw SecurityFailure(
      LocalizedText((l10n) => l10n.sshPrivatePublicMismatch),
    );
  }
  return key;
}
