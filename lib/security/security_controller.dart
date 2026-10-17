import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/net_address.dart';
import '../data/ledger_store.dart';
import '../servers/server_record.dart';
import 'host_trust.dart';
import 'key_import.dart';
import 'proxy_models.dart';
import 'secret_store.dart';
import 'security_models.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';

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
  List<ProxyRecord> proxies = const [];
  List<HostTrustRecord> hostTrusts = const [];
  bool _working = false, _disposed = false, _authenticating = false;
  bool get busy => _working || _authenticating;
  bool get authenticating => _authenticating;
  bool needsReload = false;
  int cleanupCount = 0;
  bool get cleanupPending => cleanupCount > 0;
  LocalizedMessage? _error;

  /// Stored safe message; resolving it never retries the operation.
  LocalizedMessage? get localizedError => _error;
  String? errorFor(AppLocalizations l10n) => _error?.messageFor(l10n);

  /// Compatibility for contextless callers; intentionally fixed Chinese.
  String? get error => errorFor(defaultLocalizations);
  String? revealedSecret, revealedPassphrase, revealedCredentialId;
  String? revealedProxyPassword, revealedProxyId;
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

  Future<bool> reload() async {
    if (busy || _disposed) return false;
    _working = true;
    _error = null;
    // Pages call this from initState; notifying synchronously would rebuild
    // listeners in the middle of a build.
    await Future<void>.value();
    _notify();
    try {
      await readMetadata();
      return true;
    } catch (_) {
      needsReload = true;
      _error = LocalizedText((l10n) => l10n.securityReadFailed);
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
    final nextProxies = await store.proxies();
    final nextTrusts = await store.hostTrusts();
    final cleanup = await store.pendingSecretCleanup();
    if (_disposed) return;
    credentials = List.unmodifiable(nextCredentials);
    sshConfigurations = List.unmodifiable(nextConfigurations);
    proxies = List.unmodifiable(nextProxies);
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

  ProxyRecord? proxyById(String? id) {
    if (id == null) return null;
    for (final proxy in proxies) {
      if (proxy.id == id) return proxy;
    }
    return null;
  }

  List<SshConfiguration> proxyReferences(String proxyId) => sshConfigurations
      .where((c) => c.proxyId == proxyId)
      .toList(growable: false);

  List<SshConfiguration> referencesTo(String credentialId) => sshConfigurations
      .where((c) => c.credentialId == credentialId)
      .toList(growable: false);

  bool _startMutation() {
    if (busy || needsReload || _disposed) return false;
    hideSensitive();
    _working = true;
    _error = null;
    _notify();
    return true;
  }

  Future<void> _afterCommit() async {
    try {
      await readMetadata();
    } catch (_) {
      // The mutation already committed. Never invite duplicate submission.
      needsReload = true;
      _error = LocalizedText((l10n) => l10n.securitySavedReloadFailed);
    }
  }

  void _failed(Object problem) {
    _error = problem is SecurityFailure
        ? problem
        : problem is LedgerConflict
        ? LocalizedText((l10n) => l10n.securityDataChanged)
        : LocalizedText((l10n) => l10n.securityMutationFailed);
  }

  void _finish() {
    _working = false;
    _notify();
  }

  /// Durably reserves [ref], writes [encoded] to the native store and reads it
  /// back; an unverified write fails. The caller owns the reservation.
  Future<void> _storeSecret(String ref, String encoded) async {
    await store.reserveSecret(ref, active: true);
    await secrets.write(ref, encoded);
    if (await secrets.read(ref) != encoded) {
      throw SecurityFailure(
        LocalizedText((l10n) => l10n.securitySecretWriteUnverified),
      );
    }
  }

  /// Reservations remain durable on every failure boundary, including a
  /// plugin that partially wrote or has not returned after its timeout.
  Future<void> _failedAfterSecretWrite(
    Object problem,
    String? reservedRef,
  ) async {
    _failed(problem);
    if (reservedRef != null) store.releaseSecretReservation(reservedRef);
    try {
      cleanupCount = (await store.pendingSecretCleanup()).length;
    } catch (_) {}
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
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.securityInvalidCredentialIdentity),
        );
      }
      if ((existing == null || existing.kind != kind) && secret == null) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.securitySecretRequired),
        );
      }
      if (secret == null && (passphrase?.isNotEmpty ?? false)) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.securityReimportForPassphrase),
        );
      }
      if (kind == CredentialKind.password &&
          (passphrase?.isNotEmpty ?? false)) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.securityPasswordNoPassphrase),
        );
      }
      String? algorithm = existing?.keyAlgorithm,
          fingerprint = existing?.fingerprint;
      if (secret != null) {
        if (secret.isEmpty ||
            secret.length > 128 * 1024 ||
            (passphrase?.length ?? 0) > 4096) {
          throw SecurityFailure(
            LocalizedText((l10n) => l10n.securitySecretSizeInvalid),
          );
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
        await _storeSecret(
          ref,
          jsonEncode({
            'version': 1,
            'kind': kind.name,
            'secret': secret,
            'passphrase': kind == CredentialKind.privateKey && savePassphrase
                ? passphrase
                : null,
          }),
        );
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
      await _failedAfterSecretWrite(problem, reservedRef);
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
          proxyId: config.proxyId,
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

  /// Creates or edits a saved proxy; returns its id, or null on failure.
  ///
  /// [password] replaces the stored one; null keeps it. It is only meaningful
  /// with a [username]; clearing the user name drops the stored password
  /// (queued for cleanup like every superseded secret).
  Future<String?> saveProxy({
    ProxyRecord? existing,
    required String name,
    required ProxyKind kind,
    required String host,
    required int port,
    String? username,
    String? password,
  }) async {
    if (!_startMutation()) return null;
    String? reservedRef;
    try {
      final user = (username ?? '').trim();
      final now = store.clock().toUtc();
      final address = NetAddress.tryParse(host.trim(), allowBrackets: true);
      if (address == null || address.zone != null) {
        throw SecurityFailure(LocalizedText((l10n) => l10n.r13ProxyInvalid));
      }
      final keepsPassword = user.isNotEmpty && existing?.hasCredentials == true;
      if (user.isNotEmpty && password == null && !keepsPassword) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.r13ProxyPasswordRequired),
        );
      }
      if (user.isEmpty && (password?.isNotEmpty ?? false)) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.r13ProxyUsernameRequired),
        );
      }
      if (user.isNotEmpty &&
          (!validProxyCredential(user, allowColon: kind == ProxyKind.socks5) ||
              (password != null &&
                  !validProxyCredential(password, allowColon: true)))) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.r13ProxyCredentialInvalid),
        );
      }
      String? ref = user.isEmpty ? null : existing?.secretRef;
      if (user.isNotEmpty && password != null) {
        ref = 'vps_proxy_${newLocalId()}';
        reservedRef = ref;
        await _storeSecret(
          ref,
          jsonEncode({'version': 1, 'password': password}),
        );
      }
      final id = existing?.id ?? newLocalId();
      await store.saveProxy(
        ProxyRecord(
          id: id,
          name: name.trim(),
          kind: kind,
          host: address.host,
          port: port,
          username: user.isEmpty ? null : user,
          secretRef: ref,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
          revision: existing?.revision ?? 0,
        ),
        expectedRevision: existing?.revision,
      );
      final old = existing?.secretRef;
      if (old != null && old != ref) await _cleanup([old]);
      await _afterCommit();
      return id;
    } catch (problem) {
      await _failedAfterSecretWrite(problem, reservedRef);
      return null;
    } finally {
      if (reservedRef != null) store.releaseSecretReservation(reservedRef);
      _finish();
    }
  }

  /// Refused while a connection setting uses the proxy (see the store).
  Future<bool> deleteProxy(ProxyRecord record) async {
    if (!_startMutation()) return false;
    try {
      await store.deleteProxy(record);
      final ref = record.secretRef;
      if (ref != null) await _cleanup([ref]);
      await _afterCommit();
      return true;
    } catch (problem) {
      _failed(problem);
      return false;
    } finally {
      _finish();
    }
  }

  /// Connection-only read of a saved proxy and its password. Fails closed:
  /// a missing proxy or secret is an error, never a silent direct connection.
  Future<ProxyEndpoint> loadProxyEndpoint(
    String id, {
    required bool Function() isCancelled,
  }) async {
    void guard() {
      if (_disposed || needsReload || isCancelled()) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.securitySshCancelled),
        );
      }
    }

    try {
      guard();
      final record = (await store.proxies())
          .where((p) => p.id == id)
          .firstOrNull;
      guard();
      if (record == null) {
        throw SecurityFailure(LocalizedText((l10n) => l10n.r13ProxyMissing));
      }
      String? password;
      if (record.hasCredentials) {
        password = await _readProxyPassword(record);
        guard();
        if (password == null) {
          throw SecurityFailure(
            LocalizedText((l10n) => l10n.r13ProxyPasswordMissing),
          );
        }
        final current = (await store.proxies())
            .where((p) => p.id == id)
            .firstOrNull;
        guard();
        if (current == null ||
            current.revision != record.revision ||
            current.secretRef != record.secretRef) {
          throw SecurityFailure(LocalizedText((l10n) => l10n.r13ProxyChanged));
        }
      }
      return ProxyEndpoint(
        kind: record.kind,
        host: record.host,
        port: record.port,
        username: record.username,
        password: password,
      );
    } on SecurityFailure {
      rethrow;
    } catch (_) {
      throw SecurityFailure(LocalizedText((l10n) => l10n.r13ProxyReadFailed));
    }
  }

  Future<String?> _readProxyPassword(ProxyRecord record) async {
    final ref = record.secretRef;
    if (ref == null) return null;
    final encoded = await secrets.read(ref);
    if (encoded == null) return null;
    final envelope = jsonDecode(encoded);
    if (envelope is! Map<String, dynamic> ||
        envelope['version'] != 1 ||
        envelope['password'] is! String ||
        (envelope['password'] as String).isEmpty) {
      throw SecurityFailure(
        LocalizedText((l10n) => l10n.securityStoredSecretUnreadable),
      );
    }
    return envelope['password'] as String;
  }

  /// Shows a saved proxy password for [revealDuration] after device
  /// authentication, exactly like [reveal] for credentials.
  Future<bool> revealProxy(ProxyRecord record, {AppLocalizations? l10n}) async {
    if (busy || needsReload || _disposed || !record.hasCredentials) {
      return false;
    }
    return _authenticatedReveal(l10n, (stale) async {
      final current = (await store.proxies())
          .where((p) => p.id == record.id)
          .firstOrNull;
      if (stale()) return false;
      if (current == null ||
          current.revision != record.revision ||
          current.secretRef != record.secretRef) {
        throw SecurityFailure(LocalizedText((l10n) => l10n.r13ProxyChanged));
      }
      final password = await _readProxyPassword(record);
      if (stale()) return false;
      if (password == null) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.r13ProxyPasswordMissing),
        );
      }
      revealedProxyPassword = password;
      revealedProxyId = record.id;
      return true;
    });
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
    _error = null;
    _notify();
    try {
      await _cleanup(await store.pendingSecretCleanup());
      await readMetadata();
      if (cleanupPending) {
        _error = LocalizedText((l10n) => l10n.securityCleanupIncomplete);
      }
      return !cleanupPending;
    } catch (_) {
      _error = LocalizedText((l10n) => l10n.securityCleanupReadFailed);
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
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.securitySshCancelled),
        );
      }
    }

    try {
      guard();
      final records = await store.credentials();
      guard();
      final record = records.where((c) => c.id == id).firstOrNull;
      if (record == null) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.securityChooseAvailableCredential),
        );
      }
      final encoded = await secrets.read(record.secretRef);
      guard();
      if (encoded == null || encoded.length > 1024 * 1024) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.securityCredentialSecretMissing),
        );
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
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.securityStoredSecretUnreadable),
        );
      }
      if (!await isCredentialCurrent(record)) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.securityCredentialChanged),
        );
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
      throw SecurityFailure(
        LocalizedText((l10n) => l10n.securitySshCredentialReadFailed),
      );
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

  /// Shows a credential's secret for [revealDuration] after device
  /// authentication; it is re-checked against the stored metadata before and
  /// after the native read.
  Future<bool> reveal(
    CredentialMetadata record, {
    AppLocalizations? l10n,
  }) async {
    if (busy || needsReload || _disposed) return false;
    bool sameRecord(List<CredentialMetadata> all) => all.any(
      (c) =>
          c.id == record.id &&
          c.revision == record.revision &&
          c.secretRef == record.secretRef,
    );
    return _authenticatedReveal(l10n, (stale) async {
      final current = await store.credentials();
      if (stale()) return false;
      if (!sameRecord(current)) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.securityCredentialChanged),
        );
      }
      final encoded = await secrets.read(record.secretRef);
      if (stale()) return false;
      if (encoded == null) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.securitySavedPasswordMissing),
        );
      }
      final envelope = jsonDecode(encoded);
      if (envelope is! Map<String, dynamic> ||
          envelope['version'] != 1 ||
          envelope['kind'] != record.kind.name ||
          envelope['secret'] is! String ||
          (envelope['passphrase'] != null &&
              envelope['passphrase'] is! String)) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.securityStoredSecretUnreadable),
        );
      }
      final latest = await store.credentials();
      if (stale()) return false;
      if (!sameRecord(latest)) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.securityCredentialChanged),
        );
      }
      revealedSecret = envelope['secret'] as String;
      revealedPassphrase = envelope['passphrase'] as String?;
      revealedCredentialId = record.id;
      return true;
    });
  }

  /// The protocol both reveal flows share: device authentication (in the
  /// language captured now, so a locale change never restarts it), then
  /// [load] reads and publishes the secret and returns false when [stale].
  /// Hiding or cancelling bumps the epoch and abandons the attempt.
  Future<bool> _authenticatedReveal(
    AppLocalizations? l10n,
    Future<bool> Function(bool Function() stale) load,
  ) async {
    hideSensitive();
    final epoch = _sensitiveEpoch;
    bool stale() => _disposed || epoch != _sensitiveEpoch;
    _authenticating = true;
    _error = null;
    _notify();
    try {
      await _cancelAuthentication;
      if (stale()) return false;
      final attemptLocalizations = l10n ?? defaultLocalizations;
      final deviceAuth = authenticator;
      final authenticated = deviceAuth is LocalizedDeviceAuthenticator
          ? await (deviceAuth as LocalizedDeviceAuthenticator)
                .authenticateWithLocalizations(attemptLocalizations)
          : await deviceAuth.authenticate();
      if (!authenticated) {
        if (epoch == _sensitiveEpoch) {
          _error = LocalizedText((l10n) => l10n.securityAuthenticationHidden);
        }
        return false;
      }
      if (stale() || !await load(stale)) return false;
      _revealTimer = Timer(revealDuration, hideSensitive);
      return true;
    } catch (problem) {
      if (!stale()) {
        _error = problem is SecurityFailure
            ? problem
            : LocalizedText((l10n) => l10n.securityRevealFailed);
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
    revealedProxyPassword = null;
    revealedProxyId = null;
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
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.securityHostTargetMismatch),
        );
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
      throw SecurityFailure(
        LocalizedText((l10n) => l10n.securityHostAuthenticationIncomplete),
      );
    }
  }
}

KeyImportResult _inspectKeyForSave((String, String?) input) =>
    inspectPrivateKey(input.$1, passphrase: input.$2);
