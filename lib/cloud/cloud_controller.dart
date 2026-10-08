import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/ledger_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_preference.dart';
import '../l10n/localized_message.dart';
import '../security/secret_store.dart';
import '../servers/server_record.dart';
import '../servers/server_resources.dart';
import 'cloud_account.dart';
import 'cloud_models.dart';
import 'cloud_import.dart';
import 'solusvm_adapter.dart';
import 'provider_record.dart';

export 'cloud_account.dart';
export 'provider_record.dart';
export 'cloud_import.dart';

typedef CloudAdapterFactory = CloudAdapter Function(
  CloudProvider provider,
  CloudEndpoint endpoint,
  CloudCredentials credentials,
);

/// The UI can review only the sanitized snapshot. Credentials remain private,
/// short-lived and are released on cancellation, success or disposal.
class CloudVerification {
  CloudVerification._({
    required this.provider,
    required this.businessProvider,
    required this.endpoint,
    required this.snapshot,
    required CloudCredentials this._credentials,
    required this.existingAccount,
    required this.cancellation,
  });
  final CloudProvider provider;
  final ProviderRecord businessProvider;
  final CloudEndpoint endpoint;
  final CloudSnapshot snapshot;
  final CloudAccount? existingAccount;
  final CloudCancellation cancellation;
  CloudCredentials? _credentials;
  bool _consumed = false;
  bool get isCommitted => _consumed;
  String keyFor(CloudInstance instance) => cloudInstanceKey(snapshot, instance);
}

class CloudController extends ChangeNotifier {
  CloudController({
    required this.store,
    SecretStore? secrets,
    CloudAdapterFactory? adapterFactory,
  }) : secrets = secrets ?? NativeSecretStore(),
       adapterFactory = adapterFactory ?? _nativeAdapter;
  final LedgerStore store;
  final SecretStore secrets;
  final CloudAdapterFactory adapterFactory;
  List<CloudAccount> accounts = const [];
  List<ProviderRecord> providers = const [];
  List<CloudBinding> bindings = const [];
  Map<String, Map<String, String>> _identityUuids = const {};
  LocalizedMessage? localizedError;
  String? get error => errorFor(defaultLocalizations);
  String? errorFor(AppLocalizations l10n) => localizedError?.messageFor(l10n);
  bool needsReload = false;
  int cleanupCount = 0;
  bool get cleanupPending => cleanupCount > 0;
  final _reads = <String, CloudCancellation>{};
  CloudCancellation? _verificationCancellation;
  String? _verificationAccountId;
  CloudVerification? _verification;
  CloudInventory? _lastSavedInventory;

  /// The committed instance snapshot, available even if the metadata reread
  /// fails. It contains no credentials and is fenced by the persisted epoch.
  CloudInventory? get lastSavedInventory => _lastSavedInventory;
  bool _verifying = false, _mutating = false, _disposed = false;
  bool get busy => _verifying || _mutating || _reads.isNotEmpty;
  int _metadataEpoch = 0;

  static CloudAdapter _nativeAdapter(
    CloudProvider provider,
    CloudEndpoint endpoint,
    CloudCredentials credentials,
  ) => switch (provider) {
    CloudProvider.solusVm1 => SolusVm1Adapter(
      endpoint: endpoint,
      credentials: credentials as SolusVm1Credentials,
    ),
    CloudProvider.solusVm2 => SolusVm2Adapter(
      endpoint: endpoint,
      credentials: credentials as SolusVm2Credentials,
    ),
  };
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _active(CloudCancellation cancellation) {
    if (_disposed) throw const CloudFailure(CloudFailureKind.cancelled);
    cancellation.throwIfCancelled();
  }

  void _platform() {
    if (kIsWeb) throw const CloudFailure(CloudFailureKind.unsupportedPlatform);
  }

  static void _validateCredentials(
    CloudProvider provider,
    CloudCredentials credentials,
  ) {
    if ((provider == CloudProvider.solusVm1 &&
            credentials is! SolusVm1Credentials) ||
        (provider == CloudProvider.solusVm2 &&
            credentials is! SolusVm2Credentials)) {
      throw const CloudFailure(CloudFailureKind.invalidCredentials);
    }
  }

  CloudBinding? bindingFor(String serverId) {
    for (final binding in bindings) {
      if (binding.serverId == serverId) return binding;
    }
    return null;
  }

  Future<bool> initialize() => reload();
  Future<bool> reload() async {
    if (_disposed) return false;
    localizedError = null;
    try {
      await readMetadata();
      _notify();
      return true;
    } catch (_) {
      needsReload = true;
      localizedError = LocalizedText((l10n) => l10n.cloudMetadataReadFailed);
      _notify();
      return false;
    }
  }

  @protected
  Future<void> readMetadata() async {
    final epoch = ++_metadataEpoch;
    final nextProviders = await store.providers();
    final nextAccounts = await store.cloudAccounts();
    final nextBindings = await store.cloudBindings();
    final nextIdentityUuids = await store.cloudIdentityUuids();
    final pending = await store.pendingSecretCleanup();
    if (_disposed || epoch != _metadataEpoch) return;
    providers = List.unmodifiable(nextProviders);
    accounts = List.unmodifiable(nextAccounts);
    bindings = List.unmodifiable(nextBindings);
    _identityUuids = nextIdentityUuids;
    cleanupCount = pending.length;
    needsReload = false;
  }

  Future<void> _afterCommit() async {
    try {
      await readMetadata();
    } catch (_) {
      needsReload = true;
      localizedError = LocalizedText((l10n) => l10n.cloudSavedReloadFailed);
    }
  }

  void _failed(Object problem) {
    localizedError = problem is CloudFailure
        ? problem
        : problem is CloudAccountFailure
        ? problem
        : problem is LedgerConflict
        ? LocalizedText((l10n) => l10n.cloudAccountConflict)
        : LocalizedText((l10n) => l10n.cloudOperationFailed);
  }

  Future<CloudVerification?> verifyConnection({
    required CloudProvider provider,
    required ProviderRecord businessProvider,
    required String endpoint,
    required CloudCredentials credentials,
    CloudAccount? existing,
  }) async {
    if (_disposed || _mutating || needsReload) return null;
    cancelVerification();
    _lastSavedInventory = null;
    if (existing != null) cancelAccount(existing.id);
    final cancellation = CloudCancellation();
    _verificationCancellation = cancellation;
    _verificationAccountId = existing?.id;
    _verifying = true;
    localizedError = null;
    _notify();
    try {
      _platform();
      _validateCredentials(provider, credentials);
      final selectedProvider = await store.verifiedProvider(
        businessProvider.id,
      );
      if (selectedProvider.revision != businessProvider.revision ||
          existing != null &&
              existing.businessProviderId != businessProvider.id) {
        throw const LedgerConflict();
      }
      _active(cancellation);
      final parsed = CloudEndpoint.parse(
        endpoint,
        allowSolusVm1ConsolePath: provider == CloudProvider.solusVm1,
      );
      CloudAccount? expected;
      if (existing != null) {
        if (existing.provider != provider ||
            existing.endpoint != parsed.toString()) {
          throw CloudAccountFailure.identity;
        }
        expected = await store.beginCloudRead(
          existing,
          isCancelled: () => _disposed || cancellation.isCancelled,
        );
        _active(cancellation);
      }
      final snapshot = await adapterFactory(
        provider,
        parsed,
        credentials,
      ).read(cancellation: cancellation);
      _active(cancellation);
      if (snapshot.provider != provider ||
          (expected != null &&
              snapshot.remoteAccountId != expected.remoteAccountId)) {
        throw CloudAccountFailure.identity;
      }
      if (provider == CloudProvider.solusVm2 &&
              (snapshot.remoteAccountId ?? 0) <= 0 ||
          provider == CloudProvider.solusVm1 &&
              snapshot.instances.length != 1) {
        throw const CloudFailure(CloudFailureKind.invalidResponse);
      }
      final keys = <String>{};
      for (final instance in snapshot.instances) {
        if (!keys.add(cloudInstanceKey(snapshot, instance))) {
          throw const CloudFailure(CloudFailureKind.invalidResponse);
        }
      }
      final verification = CloudVerification._(
        provider: provider,
        businessProvider: selectedProvider,
        endpoint: parsed,
        snapshot: snapshot,
        credentials: credentials,
        existingAccount: expected,
        cancellation: cancellation,
      );
      _verification = verification;
      return verification;
    } catch (problem) {
      if (identical(_verificationCancellation, cancellation) && !_disposed) {
        _failed(problem);
      }
      return null;
    } finally {
      if (identical(_verificationCancellation, cancellation)) {
        _verifying = false;
      }
      _notify();
    }
  }

  Future<bool> saveAccount(
    CloudVerification verification, {
    required String alias,
    Set<String> selectedInstanceKeys = const {},
    String? v1DisplayName,
    ServerResources? v1Resources,
    bool confirmV1Rebind = false,
  }) async {
    if (_disposed ||
        _mutating ||
        needsReload ||
        !identical(_verification, verification) ||
        verification._consumed) {
      return false;
    }
    final cancellation = verification.cancellation;
    final selection = Set<String>.of(selectedInstanceKeys);
    String? reservedRef;
    _mutating = true;
    localizedError = null;
    _notify();
    try {
      _active(cancellation);
      final clean = alias.trim();
      if (clean.isEmpty || clean.length > 80) throw CloudAccountFailure.alias;
      final existing = verification.existingAccount;
      if (existing != null &&
          verification.provider == CloudProvider.solusVm1 &&
          !confirmV1Rebind) {
        throw CloudAccountFailure.v1Rebind;
      }
      final available = verification.snapshot.instances
          .map(verification.keyFor)
          .toSet();
      if (!available.containsAll(selection)) {
        throw CloudAccountFailure.selection;
      }
      if (verification.provider == CloudProvider.solusVm1 &&
          selection.isNotEmpty) {
        if (v1Resources == null ||
            v1Resources.validate(requireComplete: true) != null) {
          throw CloudAccountFailure(
            LocalizedText(
              (l10n) =>
                  v1Resources?.validate(requireComplete: true, l10n: l10n) ??
                  l10n.cloudCompleteResources,
            ),
          );
        }
      }
      final currentProvider = await store.verifiedProvider(
        verification.businessProvider.id,
      );
      if (currentProvider.revision != verification.businessProvider.revision) {
        throw const LedgerConflict();
      }
      _active(cancellation);
      final credentials = verification._credentials;
      if (credentials == null) {
        throw const CloudFailure(CloudFailureKind.cancelled);
      }
      final ref = 'vps_cloud_${newLocalId()}';
      reservedRef = ref;
      await store.reserveSecret(ref, active: true);
      _active(cancellation);
      final encoded = _encodeSecret(credentials);
      try {
        await secrets.write(ref, encoded);
        _active(cancellation);
        if (await secrets.read(ref) != encoded) {
          throw CloudAccountFailure.secret;
        }
      } on CloudFailure {
        rethrow;
      } catch (_) {
        throw CloudAccountFailure.secret;
      }
      _active(cancellation);
      final savedAccount = CloudAccount(
        id: existing?.id ?? newLocalId(),
        provider: verification.provider,
        businessProviderId: verification.businessProvider.id,
        authScope: adapterScope(verification.provider),
        alias: clean,
        endpoint: verification.endpoint.toString(),
        secretRef: ref,
        remoteAccountId: verification.snapshot.remoteAccountId,
        createdAt: existing?.createdAt ?? store.clock().toUtc(),
        revision: existing == null ? 0 : existing.revision + 1,
        generation: existing == null ? 0 : existing.generation + 1,
        lastAttemptAt: verification.snapshot.completedAt,
      );
      await store.saveCloudAccount(
        account: savedAccount,
        snapshot: verification.snapshot,
        expected: existing,
        expectedProvider: verification.businessProvider,
        selectedInstanceKeys: selection,
        v1DisplayName: v1DisplayName,
        v1Resources: v1Resources,
        confirmV1Rebind: confirmV1Rebind,
        isCancelled: () => _disposed || cancellation.isCancelled,
      );
      // Commit is final even if reload or old-secret cleanup subsequently fails.
      verification._consumed = true;
      verification._credentials = null;
      _lastSavedInventory = CloudInventory(
        account: savedAccount,
        snapshot: verification.snapshot,
      );
      if (identical(_verification, verification)) _verification = null;
      if (existing != null) await _cleanup([existing.secretRef]);
      await _afterCommit();
      return true;
    } catch (problem) {
      if (!_disposed) _failed(problem);
      if (reservedRef != null) store.releaseSecretReservation(reservedRef);
      try {
        cleanupCount = (await store.pendingSecretCleanup()).length;
      } catch (_) {}
      return false;
    } finally {
      if (reservedRef != null) store.releaseSecretReservation(reservedRef);
      _mutating = false;
      _notify();
    }
  }

  Future<CloudInventory?> refreshAccount(CloudAccount account) async {
    if (_disposed || _mutating || needsReload) return null;
    cancelAccount(account.id);
    final cancellation = CloudCancellation();
    _reads[account.id] = cancellation;
    localizedError = null;
    _notify();
    CloudAccount? expected;
    try {
      _platform();
      expected = await store.beginCloudRead(
        account,
        isCancelled: () => _disposed || cancellation.isCancelled,
      );
      _active(cancellation);
      final credentials = await _readSecret(expected);
      _active(cancellation);
      final endpoint = CloudEndpoint.parse(expected.endpoint);
      final snapshot = await adapterFactory(
        expected.provider,
        endpoint,
        credentials,
      ).read(cancellation: cancellation);
      _active(cancellation);
      final saved = await store.commitCloudSnapshot(
        expected,
        snapshot,
        isCancelled: () => _disposed || cancellation.isCancelled,
      );
      await _afterCommit();
      _active(cancellation);
      return CloudInventory(account: saved, snapshot: snapshot);
    } catch (problem) {
      if (identical(_reads[account.id], cancellation) && !_disposed) {
        _failed(problem);
        if (expected != null && !cancellation.isCancelled) {
          try {
            await store.recordCloudFailure(
              expected,
              problem is CloudFailure
                  ? problem.kind
                  : CloudFailureKind.invalidResponse,
            );
            await _afterCommit();
          } catch (_) {
            /* A newer generation/unlink is authoritative. */
          }
        }
      }
      return null;
    } finally {
      if (identical(_reads[account.id], cancellation)) {
        _reads.remove(account.id);
      }
      _notify();
    }
  }

  Future<bool> importInstances(
    CloudInventory inventory, {
    required Set<String> selectedInstanceKeys,
    String? v1DisplayName,
    ServerResources? v1Resources,
  }) async {
    if (_disposed || _mutating || needsReload) return false;
    _mutating = true;
    localizedError = null;
    _notify();
    final cancellation = CloudCancellation();
    cancelAccount(inventory.account.id);
    _reads[inventory.account.id] = cancellation;
    try {
      await store.importCloudInstances(
        inventory,
        selectedInstanceKeys: Set.of(selectedInstanceKeys),
        v1DisplayName: v1DisplayName,
        v1Resources: v1Resources,
        isCancelled: () => _disposed || cancellation.isCancelled,
      );
      await _afterCommit();
      return true;
    } catch (problem) {
      if (!_disposed) _failed(problem);
      return false;
    } finally {
      if (identical(_reads[inventory.account.id], cancellation)) {
        _reads.remove(inventory.account.id);
      }
      _mutating = false;
      _notify();
    }
  }

  /// Partial local import with exact committed outcomes. A cancellation or
  /// authority/storage failure stops the remainder; it never refreshes and
  /// silently continues a now-different authorization.
  Future<CloudImportBatchResult?> importBatch(
    CloudInventory inventory,
    List<CloudImportDraft> drafts,
  ) async {
    if (_disposed || _mutating || needsReload) return null;
    final selected = List<CloudImportDraft>.unmodifiable(drafts);
    if (selected.map((d) => d.instanceKey).toSet().length != selected.length) {
      _failed(CloudAccountFailure.selection);
      _notify();
      return null;
    }
    _mutating = true;
    localizedError = null;
    final cancellation = CloudCancellation();
    cancelAccount(inventory.account.id, notify: false);
    _reads[inventory.account.id] = cancellation;
    final items = <CloudImportItemResult>[];
    final failures = <String, LocalizedMessage>{};
    final unprocessed = <String>{};
    LocalizedMessage? interruption;
    _notify();
    try {
      for (var i = 0; i < selected.length; i++) {
        final draft = selected[i];
        try {
          _active(cancellation);
          items.add(await importDraft(inventory, draft, cancellation));
        } catch (problem) {
          _failed(problem);
          final safe =
              localizedError ??
              LocalizedText((l10n) => l10n.cloudOperationFailed);
          failures[draft.instanceKey] = safe;
          if (problem is! CloudImportDraftFailure) {
            interruption = safe;
            unprocessed.addAll(selected.skip(i + 1).map((d) => d.instanceKey));
            break;
          }
        }
      }
      await _afterCommit();
      return CloudImportBatchResult(
        items: items,
        failures: failures,
        unprocessed: unprocessed,
        interruption: interruption,
      );
    } finally {
      if (identical(_reads[inventory.account.id], cancellation)) {
        _reads.remove(inventory.account.id);
      }
      _mutating = false;
      _notify();
    }
  }

  @protected
  Future<CloudImportItemResult> importDraft(
    CloudInventory inventory,
    CloudImportDraft draft,
    CloudCancellation cancellation,
  ) => store.importCloudDraft(
    inventory,
    draft,
    isCancelled: () => _disposed || cancellation.isCancelled,
  );

  /// Read-only display hints from current local metadata. The transaction
  /// repeats these checks against stable IDs before any import or link.
  String? lockedIdentityFor({
    String? accountId,
    required String instanceKey,
    String? uuid,
  }) => _identityUuids[accountId]?[instanceKey] ?? uuid;

  bool hasSourceIdentityConflict({
    String? accountId,
    required String instanceKey,
    String? uuid,
  }) {
    final locked = _identityUuids[accountId]?[instanceKey];
    return uuid != null && locked != null && uuid != locked;
  }

  List<CloudBinding> matchingDevices({
    required CloudProvider type,
    required String endpoint,
    required int? remoteAccountId,
    required String instanceKey,
    String? accountId,
    String? uuid,
  }) {
    final candidates = _deviceCandidates(
      type: type,
      endpoint: endpoint,
      remoteAccountId: remoteAccountId,
      instanceKey: instanceKey,
      accountId: accountId,
    );
    final locked = lockedIdentityFor(
      accountId: accountId,
      instanceKey: instanceKey,
      uuid: uuid,
    );
    if (hasSourceIdentityConflict(
          accountId: accountId,
          instanceKey: instanceKey,
          uuid: uuid,
        ) ||
        candidates.any((binding) => _uuidConflicts(binding, locked))) {
      return const [];
    }
    return candidates;
  }

  List<CloudBinding> conflictingDevices({
    required CloudProvider type,
    required String endpoint,
    required int? remoteAccountId,
    required String instanceKey,
    required String? uuid,
    String? accountId,
  }) {
    final candidates = _deviceCandidates(
      type: type,
      endpoint: endpoint,
      remoteAccountId: remoteAccountId,
      instanceKey: instanceKey,
      accountId: accountId,
    );
    if (hasSourceIdentityConflict(
      accountId: accountId,
      instanceKey: instanceKey,
      uuid: uuid,
    )) {
      return candidates;
    }
    final locked = lockedIdentityFor(
      accountId: accountId,
      instanceKey: instanceKey,
      uuid: uuid,
    );
    return candidates
        .where((binding) => _uuidConflicts(binding, locked))
        .toList(growable: false);
  }

  static bool _uuidConflicts(CloudBinding binding, String? uuid) =>
      uuid != null && binding.stableUuid != null && binding.stableUuid != uuid;

  List<CloudBinding> _deviceCandidates({
    required CloudProvider type,
    required String endpoint,
    required int? remoteAccountId,
    required String instanceKey,
    String? accountId,
  }) => bindings
      .where((binding) {
        if (binding.instanceKey != instanceKey) return false;
        if (binding.accountId == accountId) return true;
        if (type != CloudProvider.solusVm2) return false;
        final source = accounts
            .where((a) => a.id == binding.accountId)
            .firstOrNull;
        return source?.provider == type &&
            source?.endpoint == endpoint &&
            source?.remoteAccountId == remoteAccountId;
      })
      .toList(growable: false);

  Future<bool> renameAccount(CloudAccount account, String alias) async {
    if (_disposed || _mutating || needsReload) return false;
    cancelAccount(account.id);
    _mutating = true;
    localizedError = null;
    _notify();
    try {
      await store.renameCloudAccount(account, alias);
      await _afterCommit();
      return true;
    } catch (problem) {
      _failed(problem);
      return false;
    } finally {
      _mutating = false;
      _notify();
    }
  }

  /// Uses only the saved local snapshot; it never creates an adapter or reads
  /// API credentials. The caller must explicitly refresh from the account page.
  Future<ServerCloudBindingOptions?> serverBindingOptions(
    String serverId,
  ) async {
    if (_disposed || busy || needsReload) return null;
    localizedError = null;
    try {
      return await store.serverCloudBindingOptions(serverId);
    } catch (problem) {
      _failed(problem);
      _notify();
      return null;
    }
  }

  /// A null choice unlinks only this server, retaining the account and secret.
  Future<bool> setServerBinding(
    ServerCloudBindingOptions expected, {
    CloudBindingChoice? choice,
    bool Function()? isCancelled,
  }) async {
    if (_disposed || busy || needsReload) return false;
    _mutating = true;
    localizedError = null;
    _notify();
    try {
      await store.setServerCloudBinding(
        expected,
        choice: choice,
        isCancelled: () => _disposed || (isCancelled?.call() ?? false),
      );
      await _afterCommit();
      return true;
    } catch (problem) {
      if (!_disposed) _failed(problem);
      return false;
    } finally {
      _mutating = false;
      _notify();
    }
  }

  /// Allowed while a read/save is pending: cancellation is synchronous, and the
  /// DB transaction fence prevents either operation restoring a removed link.
  Future<bool> unbindAccount(CloudAccount account) async {
    if (_disposed || needsReload) return false;
    cancelAccount(account.id);
    localizedError = null;
    try {
      await store.unbindCloudAccount(account);
      await _cleanup([account.secretRef]);
      await _afterCommit();
      _notify();
      return true;
    } catch (problem) {
      _failed(problem);
      _notify();
      return false;
    }
  }

  void cancelVerification({bool notify = true}) {
    _verificationCancellation?.cancel();
    _verificationCancellation = null;
    _verificationAccountId = null;
    _verification?._credentials = null;
    _verification = null;
    _verifying = false;
    if (notify) _notify();
  }

  void cancelAccount(String accountId, {bool notify = true}) {
    _reads.remove(accountId)?.cancel();
    if (_verificationAccountId == accountId) cancelVerification(notify: false);
    if (notify) _notify();
  }

  void cancelAll() {
    cancelVerification();
    for (final read in _reads.values) {
      read.cancel();
    }
    _reads.clear();
    _notify();
  }

  Future<CloudCredentials> _readSecret(CloudAccount account) async {
    try {
      final raw = await secrets.read(account.secretRef);
      if (raw == null) throw CloudAccountFailure.secretRead;
      final value = jsonDecode(raw) as Map<String, dynamic>;
      if (value['version'] != 1 || value['provider'] != account.provider.name) {
        throw CloudAccountFailure.secretRead;
      }
      return switch (account.provider) {
        CloudProvider.solusVm1 => SolusVm1Credentials(
          key: value['key'] as String,
          hash: value['hash'] as String,
        ),
        CloudProvider.solusVm2 => SolusVm2Credentials(value['token'] as String),
      };
    } catch (_) {
      throw CloudAccountFailure.secretRead;
    }
  }

  static String _encodeSecret(CloudCredentials credentials) =>
      switch (credentials) {
        SolusVm1Credentials() => jsonEncode({
          'version': 1,
          'provider': CloudProvider.solusVm1.name,
          'key': credentials.key,
          'hash': credentials.hash,
        }),
        SolusVm2Credentials() => jsonEncode({
          'version': 1,
          'provider': CloudProvider.solusVm2.name,
          'token': credentials.token,
        }),
      };
  Future<void> _cleanup(List<String> refs) async {
    for (final ref in refs) {
      try {
        if (!(await store.pendingSecretCleanup()).contains(ref)) continue;
        if (!await store.secretIsReferenced(ref)) await secrets.delete(ref);
        await store.finishSecretCleanup(ref);
      } catch (_) {
        /* The durable journal retains every unfinished deletion. */
      }
    }
  }

  Future<bool> retryCleanup() async {
    if (_disposed || busy) return false;
    _mutating = true;
    localizedError = null;
    _notify();
    try {
      await _cleanup(await store.pendingSecretCleanup());
      await readMetadata();
      if (cleanupPending) {
        localizedError = LocalizedText((l10n) => l10n.cloudCleanupIncomplete);
      }
      return !cleanupPending;
    } catch (_) {
      localizedError = LocalizedText((l10n) => l10n.cloudCleanupStatusFailed);
      return false;
    } finally {
      _mutating = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    cancelAll();
    super.dispose();
  }
}
