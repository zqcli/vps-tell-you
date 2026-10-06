import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/ledger_store.dart';
import '../servers/server_record.dart';
import 'host_trust.dart';
import 'key_import.dart';
import 'secret_store.dart';
import 'security_models.dart';

class SecurityController extends ChangeNotifier {
  SecurityController({
    required this.store,
    SecretStore? secrets,
    DeviceAuthenticator? authenticator,
    this.revealDuration = const Duration(seconds: 20),
  }) : secrets = secrets ?? NativeSecretStore(),
       authenticator = authenticator ?? NativeDeviceAuthenticator();
  final LedgerStore store;
  final SecretStore secrets;
  final DeviceAuthenticator authenticator;
  final Duration revealDuration;
  List<CredentialMetadata> credentials = const [];
  List<SshConfiguration> sshConfigurations = const [];
  List<HostTrustRecord> hostTrusts = const [];
  bool _working = false, _disposed = false, _authenticating = false;
  bool get busy => _working || _authenticating;
  bool get authenticating => _authenticating;
  bool needsReload = false;
  int cleanupCount = 0;
  bool get cleanupPending => cleanupCount > 0;
  String? error;
  String? revealedSecret, revealedPassphrase, revealedCredentialId;
  int _sensitiveEpoch = 0;
  Timer? _revealTimer;
  Future<void> _cancelAuthentication = Future<void>.value();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Startup is metadata-only. A user-initiated retry performs orphan recovery;
  /// opening a page never creates, unlocks or writes a native keyring.
  Future<bool> initialize({bool recoverSecrets = false}) async {
    if (recoverSecrets) return retryCleanup();
    return reload();
  }

  Future<bool> refresh() => reload();
  Future<bool> reload() async {
    if (busy || _disposed) return false;
    _working = true;
    error = null;
    _notify();
    try {
      await readMetadata();
      return true;
    } catch (_) {
      needsReload = true;
      error = '无法读取安全资料，请重试';
      return false;
    } finally {
      _working = false;
      _notify();
    }
  }

  @protected
  Future<void> readMetadata() async {
    final nextCredentials = await store.credentials();
    final nextConfigurations = await store.sshConfigurations();
    final nextTrusts = await store.hostTrusts();
    final cleanup = await store.pendingSecretCleanup();
    if (_disposed) return;
    credentials = List.unmodifiable(nextCredentials);
    sshConfigurations = List.unmodifiable(nextConfigurations);
    hostTrusts = List.unmodifiable(nextTrusts);
    cleanupCount = cleanup.length;
    needsReload = false;
  }

  SshConfiguration? configFor(String serverId) {
    for (final config in sshConfigurations) {
      if (config.serverId == serverId) return config;
    }
    return null;
  }

  List<SshConfiguration> referencesTo(String credentialId) => sshConfigurations
      .where((c) => c.credentialId == credentialId)
      .toList(growable: false);
  List<CredentialMetadata> searchCredentials(String query) {
    final q = query.trim().toLowerCase();
    return credentials
        .where(
          (c) => [
            c.name,
            c.defaultUsername,
            c.keyAlgorithm ?? '',
            c.fingerprint ?? '',
          ].any((value) => value.toLowerCase().contains(q)),
        )
        .toList(growable: false);
  }

  bool _startMutation() {
    if (busy || needsReload || _disposed) return false;
    hideSensitive();
    _working = true;
    error = null;
    _notify();
    return true;
  }

  Future<void> _afterCommit() async {
    try {
      await readMetadata();
    } catch (_) {
      // The mutation already committed. Never invite duplicate submission.
      needsReload = true;
      error = '已保存，但资料重读失败；请重读后再修改';
    }
  }

  void _failed(Object problem) {
    error = problem is SecurityFailure
        ? problem.message
        : problem is LedgerConflict
        ? '资料已变化，请重读后重试'
        : '安全操作未完成，原资料未更改；请重试';
  }

  void _finish() {
    _working = false;
    _notify();
  }

  Future<bool> saveCredential({
    CredentialMetadata? existing,
    required String name,
    required CredentialKind kind,
    required String defaultUsername,
    String? secret,
    String? passphrase,
    bool savePassphrase = false,
  }) async {
    if (!_startMutation()) return false;
    String? reservedRef;
    try {
      final cleanName = name.trim();
      final user = defaultUsername.trim();
      if (cleanName.isEmpty ||
          cleanName.length > 80 ||
          user.length > 128 ||
          (kind == CredentialKind.password && user.isEmpty) ||
          RegExp(r'[\x00-\x20\x7f]').hasMatch(user)) {
        throw const SecurityFailure('请输入 1–80 字名称及有效默认用户名');
      }
      if ((existing == null || existing.kind != kind) && secret == null) {
        throw const SecurityFailure('请提供秘密内容');
      }
      if (secret == null && (passphrase?.isNotEmpty ?? false)) {
        throw const SecurityFailure('修改口令时请同时重新导入私钥');
      }
      if (kind == CredentialKind.password &&
          (passphrase?.isNotEmpty ?? false)) {
        throw const SecurityFailure('密码凭据不使用私钥口令');
      }
      String? algorithm = existing?.keyAlgorithm,
          fingerprint = existing?.fingerprint;
      if (secret != null) {
        if (secret.isEmpty ||
            secret.length > 128 * 1024 ||
            (passphrase?.length ?? 0) > 4096) {
          throw const SecurityFailure('秘密内容为空或超出大小限制');
        }
        if (kind == CredentialKind.privateKey) {
          final info = await compute(_inspectKeyForSave, (secret, passphrase));
          if (_disposed) return false;
          algorithm = info.algorithm;
          fingerprint = info.fingerprint;
        } else {
          algorithm = null;
          fingerprint = null;
        }
      }
      final now = store.clock().toUtc();
      final ref = secret == null
          ? existing!.secretRef
          : 'vps_credential_${newLocalId()}';
      if (secret != null) {
        // A durable reservation precedes the possibly partial/late native write.
        reservedRef = ref;
        await store.reserveSecret(ref, active: true);
        final encoded = jsonEncode({
          'version': 1,
          'kind': kind.name,
          'secret': secret,
          'passphrase': kind == CredentialKind.privateKey && savePassphrase
              ? passphrase
              : null,
        });
        await secrets.write(ref, encoded);
        if (await secrets.read(ref) != encoded) {
          throw const SecurityFailure('秘密写入未能校验，原凭据保持不变');
        }
      }
      await store.saveCredential(
        CredentialMetadata(
          id: existing?.id ?? newLocalId(),
          name: cleanName,
          kind: kind,
          defaultUsername: user,
          secretRef: ref,
          keyAlgorithm: algorithm,
          fingerprint: fingerprint,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
          revision: existing?.revision ?? 0,
        ),
        expectedRevision: existing?.revision,
      );
      if (existing != null && existing.secretRef != ref) {
        await _cleanup([existing.secretRef]);
      }
      await _afterCommit();
      return true;
    } catch (problem) {
      _failed(problem);
      // Reservations remain durable on every failure boundary, including a
      // plugin that partially wrote or has not returned after its timeout.
      if (reservedRef != null) store.releaseSecretReservation(reservedRef);
      try {
        cleanupCount = (await store.pendingSecretCleanup()).length;
      } catch (_) {}
      return false;
    } finally {
      if (reservedRef != null) store.releaseSecretReservation(reservedRef);
      _finish();
    }
  }

  Future<bool> deleteCredential(
    CredentialMetadata record, {
    String? replacementId,
  }) async {
    if (!_startMutation()) return false;
    try {
      await store.deleteCredential(record, replacementId: replacementId);
      await _cleanup([record.secretRef]);
      await _afterCommit();
      return true;
    } catch (problem) {
      _failed(problem);
      return false;
    } finally {
      _finish();
    }
  }

  Future<bool> saveSshConfiguration(SshConfiguration config) async {
    if (!_startMutation()) return false;
    try {
      final host = normalizedHost(config.host);
      await store.saveSshConfiguration(
        SshConfiguration(
          serverId: config.serverId,
          host: host,
          port: config.port,
          username: config.username.trim(),
          credentialId: config.credentialId,
          revision: config.revision,
        ),
      );
      await _afterCommit();
      return true;
    } catch (problem) {
      _failed(problem);
      return false;
    } finally {
      _finish();
    }
  }

  Future<void> _cleanup(List<String> refs) async {
    for (final ref in refs) {
      try {
        if (!(await store.pendingSecretCleanup()).contains(ref)) continue;
        // Defense in depth: even a stale journal entry cannot delete live data.
        if (await store.secretIsReferenced(ref)) {
          await store.finishSecretCleanup(ref);
          continue;
        }
        await secrets.delete(ref);
        await store.finishSecretCleanup(ref);
      } catch (_) {
        // Metadata is already committed. Recovery remains explicit and durable.
      }
    }
  }

  Future<bool> recoverPendingSecrets() => retryCleanup();
  Future<bool> retryCleanup() async {
    if (busy || _disposed) return false;
    _working = true;
    error = null;
    _notify();
    try {
      await _cleanup(await store.pendingSecretCleanup());
      await readMetadata();
      if (cleanupPending) error = '秘密清理尚未完成，可稍后重试';
      return !cleanupPending;
    } catch (_) {
      error = '无法读取待清理资料，请重试';
      return false;
    } finally {
      _finish();
    }
  }

  /// Connection-only read. It does not expose secrets through reveal state or
  /// bypass the device-authenticated UI. Recheck immutable reference + revision
  /// on both sides of the native read and stop after any cancellation.
  Future<SshCredential> loadSshCredential(
    String id, {
    required bool Function() isCancelled,
  }) async {
    void guard() {
      if (_disposed || needsReload || isCancelled()) {
        throw const SecurityFailure('SSH 连接已取消或资料需重读');
      }
    }

    try {
      guard();
      final records = await store.credentials();
      guard();
      final record = records.where((c) => c.id == id).firstOrNull;
      if (record == null) throw const SecurityFailure('请选择可用凭据');
      final encoded = await secrets.read(record.secretRef);
      guard();
      if (encoded == null || encoded.length > 1024 * 1024) {
        throw const SecurityFailure('设备中未找到可用秘密，请重新导入');
      }
      final envelope = jsonDecode(encoded);
      if (envelope is! Map<String, dynamic> ||
          envelope['version'] != 1 ||
          envelope['kind'] != record.kind.name ||
          envelope['secret'] is! String ||
          (envelope['secret'] as String).isEmpty ||
          (envelope['secret'] as String).length > 128 * 1024 ||
          (envelope['passphrase'] != null &&
              (envelope['passphrase'] is! String ||
                  (envelope['passphrase'] as String).length > 4096))) {
        throw const SecurityFailure('安全存储资料无法读取');
      }
      if (!await isCredentialCurrent(record)) {
        throw const SecurityFailure('凭据已变化，请重读后重试');
      }
      guard();
      return SshCredential(
        metadata: record,
        secret: envelope['secret'] as String,
        passphrase: envelope['passphrase'] as String?,
      );
    } on SecurityFailure {
      rethrow;
    } catch (_) {
      throw const SecurityFailure('无法读取 SSH 凭据，请重试');
    }
  }

  Future<bool> isCredentialCurrent(CredentialMetadata record) async {
    if (_disposed || needsReload) return false;
    final current = await store.credentials();
    return !_disposed &&
        !needsReload &&
        current.any(
          (c) =>
              c.id == record.id &&
              c.revision == record.revision &&
              c.secretRef == record.secretRef &&
              c.kind == record.kind,
        );
  }

  Future<bool> reveal(CredentialMetadata record) async {
    if (busy || needsReload || _disposed) return false;
    hideSensitive();
    final epoch = _sensitiveEpoch;
    _authenticating = true;
    error = null;
    _notify();
    try {
      await _cancelAuthentication;
      if (_disposed || epoch != _sensitiveEpoch) return false;
      if (!await authenticator.authenticate()) {
        if (epoch == _sensitiveEpoch) error = '设备认证未完成，秘密仍隐藏';
        return false;
      }
      if (_disposed || epoch != _sensitiveEpoch) return false;
      final current = await store.credentials();
      if (_disposed || epoch != _sensitiveEpoch) return false;
      if (!current.any(
        (c) =>
            c.id == record.id &&
            c.revision == record.revision &&
            c.secretRef == record.secretRef,
      )) {
        throw const SecurityFailure('凭据已变化，请重读后重试');
      }
      final encoded = await secrets.read(record.secretRef);
      if (_disposed || epoch != _sensitiveEpoch) return false;
      if (encoded == null) throw const SecurityFailure('设备中未找到秘密，请重新导入');
      final envelope = jsonDecode(encoded);
      if (envelope is! Map<String, dynamic> ||
          envelope['version'] != 1 ||
          envelope['kind'] != record.kind.name ||
          envelope['secret'] is! String ||
          (envelope['passphrase'] != null &&
              envelope['passphrase'] is! String)) {
        throw const SecurityFailure('安全存储资料无法读取');
      }
      final latest = await store.credentials();
      if (_disposed || epoch != _sensitiveEpoch) return false;
      if (!latest.any(
        (c) =>
            c.id == record.id &&
            c.revision == record.revision &&
            c.secretRef == record.secretRef,
      )) {
        throw const SecurityFailure('凭据已变化，请重读后重试');
      }
      revealedSecret = envelope['secret'] as String;
      revealedPassphrase = envelope['passphrase'] as String?;
      revealedCredentialId = record.id;
      _revealTimer = Timer(revealDuration, hideSensitive);
      return true;
    } catch (problem) {
      if (!_disposed && epoch == _sensitiveEpoch) {
        error = problem is SecurityFailure ? problem.message : '无法显示秘密，请重试';
      }
      return false;
    } finally {
      if (epoch == _sensitiveEpoch) _authenticating = false;
      _notify();
    }
  }

  void hideDisplayedSensitive() => hideSensitive(cancelAuthentication: false);
  void hideSensitive({bool cancelAuthentication = true}) {
    _revealTimer?.cancel();
    _revealTimer = null;
    revealedSecret = null;
    revealedPassphrase = null;
    revealedCredentialId = null;
    if (cancelAuthentication) {
      _sensitiveEpoch++;
      if (_authenticating) {
        _authenticating = false;
        _cancelAuthentication = authenticator.cancel().catchError(
          (Object _) {},
        );
      }
    }
    _notify();
  }

  Future<HostTrustStatus> checkHost(HostKeyIdentity identity) async {
    final pin = await store.hostTrust(identity.host, identity.port);
    if (pin == null) return HostTrustStatus.firstUse;
    return pin.algorithm == identity.algorithm &&
            pin.publicKey == identity.publicKey
        ? HostTrustStatus.trusted
        : HostTrustStatus.changed;
  }

  Future<bool> verifyHost(
    HostKeyIdentity identity, {
    HostTrustRecord? expected,
  }) => _verifyHost(identity, expected: expected);

  Future<bool> _verifyHost(
    HostKeyIdentity identity, {
    HostTrustRecord? expected,
    bool Function()? isCancelled,
  }) async {
    if (!_startMutation()) return false;
    try {
      if (expected != null &&
          (expected.host != identity.host || expected.port != identity.port)) {
        throw const SecurityFailure('主机核验目标不一致');
      }
      await store.saveHostTrust(
        HostTrustRecord(
          host: identity.host,
          port: identity.port,
          algorithm: identity.algorithm,
          publicKey: identity.publicKey,
          fingerprint: identity.fingerprint,
          verifiedAt: store.clock().toUtc(),
        ),
        expected: expected,
        isCancelled: isCancelled,
      );
      await _afterCommit();
      return true;
    } catch (problem) {
      _failed(problem);
      return false;
    } finally {
      _finish();
    }
  }

  Future<bool> removeHostTrust(HostTrustRecord record) async {
    if (!_startMutation()) return false;
    try {
      await store.deleteHostTrust(record);
      await _afterCommit();
      return true;
    } catch (problem) {
      _failed(problem);
      return false;
    } finally {
      _finish();
    }
  }

  HostVerificationAttempt beginHostVerification(HostKeyIdentity identity) =>
      HostVerificationAttempt._(this, identity, _sensitiveEpoch);

  @override
  void dispose() {
    _disposed = true;
    hideSensitive();
    super.dispose();
  }
}

/// One connection attempt. A rejected/cancelled attempt is permanently unusable.
/// The SSH adapter calls this gate before releasing authentication data.
class HostVerificationAttempt {
  HostVerificationAttempt._(this._controller, this.identity, this._epoch);
  final SecurityController _controller;
  final HostKeyIdentity identity;
  int _epoch;
  bool _cancelled = false, _used = false;
  bool get cancelled =>
      _cancelled ||
      _controller._disposed ||
      _epoch != _controller._sensitiveEpoch;
  void cancel() {
    _cancelled = true;
  }

  void reject() => cancel();
  Future<HostTrustStatus> check() => _controller.checkHost(identity);

  /// Call only after the user explicitly verifies the shown complete key.
  Future<bool> confirm({HostTrustRecord? expected}) async {
    if (cancelled || _used) return false;
    final previousEpoch = _epoch;
    final confirmed = await _controller._verifyHost(
      identity,
      expected: expected,
      isCancelled: () =>
          _cancelled ||
          _controller._disposed ||
          _controller._sensitiveEpoch != previousEpoch + 1,
    );
    // verifyHost invalidates prior attempts once; background/cancel invalidates
    // again. Only this still-active explicitly confirmed attempt may resume.
    if (!confirmed ||
        _cancelled ||
        _controller._disposed ||
        _controller._sensitiveEpoch != previousEpoch + 1) {
      return false;
    }
    _epoch = _controller._sensitiveEpoch;
    return true;
  }

  Future<bool> authenticate(Future<void> Function() authentication) async {
    if (cancelled || _used) return false;
    _used = true;
    try {
      if (await check() != HostTrustStatus.trusted || cancelled) return false;
      // No await may be introduced between cancellation check and invocation.
      await authentication();
      return true;
    } catch (_) {
      throw const SecurityFailure('主机核验或认证未完成');
    }
  }
}

KeyImportResult _inspectKeyForSave((String, String?) input) =>
    inspectPrivateKey(input.$1, passphrase: input.$2);
