part of 'ledger_store.dart';

extension LedgerSecurity on LedgerStore {
  Future<List<CredentialMetadata>> credentials() async => (await _db.query(
    'credentials',
    orderBy: 'name COLLATE NOCASE, id',
  )).map(CredentialMetadata.fromMap).toList(growable: false);

  Future<CredentialMetadata?> credentialById(String id) async {
    final rows = await _db.query('credentials', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : CredentialMetadata.fromMap(rows.single);
  }

  Future<bool> isCredentialCurrent(CredentialMetadata record) async =>
      (await _db.query(
        'credentials',
        columns: ['id'],
        where: 'id = ? AND revision = ? AND secret_ref = ? AND kind = ?',
        whereArgs: [record.id, record.revision, record.secretRef, record.kind.name],
        limit: 1,
      )).isNotEmpty;

  Future<List<SshConfiguration>> sshConfigurations() async =>
      (await _db.query('ssh_configurations'))
          .map(SshConfiguration.fromMap)
          .toList(growable: false);

  Future<List<HostTrustRecord>> hostTrusts() async => (await _db.query(
    'host_trust',
    orderBy: 'host, port',
  )).map(HostTrustRecord.fromMap).toList(growable: false);

  Future<HostTrustRecord?> hostTrust(String host, int port) async {
    final rows = await _db.query(
      'host_trust',
      where: 'host = ? AND port = ?',
      whereArgs: [host, port],
    );
    return rows.isEmpty ? null : HostTrustRecord.fromMap(rows.single);
  }

  /// Must commit before native storage write. References are fresh and immutable.
  Future<void> reserveSecret(String ref, {bool active = false}) async {
    if (active && !_activeSecretReservations.add(ref)) {
      throw const LedgerConflict();
    }
    try {
      await _db.transaction((txn) async {
        if (await _secretIsReferenced(txn, ref)) {
          throw const LedgerConflict();
        }
        await txn.insert('secret_cleanup', {
          'secret_ref': ref,
          'created_at': clock().toUtc().toIso8601String(),
        });
      });
    } catch (_) {
      if (active) {
        _activeSecretReservations.remove(ref);
      }
      rethrow;
    }
  }

  void releaseSecretReservation(String ref) =>
      _activeSecretReservations.remove(ref);

  Future<List<String>> pendingSecretCleanup() async =>
      (await _db.query('secret_cleanup'))
          .map((row) => row['secret_ref'] as String)
          .where((ref) => !_activeSecretReservations.contains(ref))
          .toList(growable: false);

  Future<bool> secretIsReferenced(String ref) => _secretIsReferenced(_db, ref);

  Future<void> finishSecretCleanup(String ref) async {
    await _db.delete(
      'secret_cleanup',
      where: 'secret_ref = ?',
      whereArgs: [ref],
    );
  }

  Future<void> saveCredential(
    CredentialMetadata record, {
    required int? expectedRevision,
  }) async {
    if (record.name.trim().isEmpty ||
        record.name.length > 80 ||
        record.defaultUsername.length > 128 ||
        (record.kind == CredentialKind.password &&
            record.defaultUsername.isEmpty) ||
        record.secretRef.isEmpty) {
      throw SecurityFailure(
        LocalizedText((l10n) => l10n.invalidCredentialDetails),
      );
    }
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'credentials',
        where: 'id = ?',
        whereArgs: [record.id],
      );
      final previous = rows.isEmpty
          ? null
          : CredentialMetadata.fromMap(rows.single);
      if ((expectedRevision == null && previous != null) ||
          (expectedRevision != null &&
              previous?.revision != expectedRevision)) {
        throw const LedgerConflict();
      }
      await _requireSecretReservation(
        txn,
        previous?.secretRef,
        record.secretRef,
      );
      final map = record.toMap();
      map['revision'] = expectedRevision == null ? 0 : expectedRevision + 1;
      map['updated_at'] = clock().toUtc().toIso8601String();
      if (previous == null) {
        await txn.insert('credentials', map);
      } else {
        map.remove('id');
        map.remove('created_at');
        final count = await txn.update(
          'credentials',
          map,
          where: 'id = ? AND revision = ?',
          whereArgs: [record.id, expectedRevision],
        );
        if (count != 1) {
          throw const LedgerConflict();
        }
      }
      await _finishSecretChange(txn, previous?.secretRef, record.secretRef);
    });
  }

  /// Replace or detach all references in the same metadata transaction. Explicit
  /// usernames remain untouched, including those equal to an old default.
  Future<void> deleteCredential(
    CredentialMetadata record, {
    String? replacementId,
  }) async {
    if (replacementId == record.id) {
      throw SecurityFailure(
        LocalizedText((l10n) => l10n.chooseOtherCredential),
      );
    }
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'credentials',
        where: 'id = ? AND revision = ?',
        whereArgs: [record.id, record.revision],
      );
      if (rows.length != 1) {
        throw const LedgerConflict();
      }
      final current = CredentialMetadata.fromMap(rows.single);
      if (replacementId != null &&
          (await txn.query(
            'credentials',
            where: 'id = ?',
            whereArgs: [replacementId],
          )).isEmpty) {
        throw const LedgerConflict();
      }
      await txn.rawUpdate(
        '''UPDATE ssh_configurations
          SET credential_id = ?, revision = revision + 1 WHERE credential_id = ?''',
        [replacementId, record.id],
      );
      await txn.delete(
        'credentials',
        where: 'id = ? AND revision = ?',
        whereArgs: [record.id, record.revision],
      );
      await _queueSecretCleanup(txn, current.secretRef);
    });
  }

  Future<void> saveSshConfiguration(SshConfiguration config) async {
    if (config.host.isEmpty ||
        !ServerRecord.validHost(config.host) ||
        config.port < 1 ||
        config.port > 65535 ||
        config.username.trim().isEmpty ||
        config.username.length > 128 ||
        RegExp(r'[\x00-\x20\x7f]').hasMatch(config.username)) {
      throw SecurityFailure(
        LocalizedText((l10n) => l10n.invalidSshConfiguration),
      );
    }
    await _db.transaction((txn) async {
      if ((await txn.query(
            'servers',
            where: 'id = ?',
            whereArgs: [config.serverId],
          )).isEmpty ||
          (config.credentialId != null &&
              (await txn.query(
                'credentials',
                where: 'id = ?',
                whereArgs: [config.credentialId],
              )).isEmpty) ||
          (config.proxyId != null &&
              (await txn.query(
                'proxies',
                where: 'id = ?',
                whereArgs: [config.proxyId],
              )).isEmpty)) {
        throw const LedgerConflict();
      }
      final map = config.toMap();
      map['revision'] = config.revision + 1;
      if (config.revision < 0) {
        if ((await txn.query(
          'ssh_configurations',
          where: 'server_id = ?',
          whereArgs: [config.serverId],
        )).isNotEmpty) {
          throw const LedgerConflict();
        }
        await txn.insert('ssh_configurations', map);
      } else {
        map.remove('server_id');
        final count = await txn.update(
          'ssh_configurations',
          map,
          where: 'server_id = ? AND revision = ?',
          whereArgs: [config.serverId, config.revision],
        );
        if (count != 1) {
          throw const LedgerConflict();
        }
      }
    });
  }

  Future<List<ProxyRecord>> proxies() async => (await _db.query(
    'proxies',
    orderBy: 'name COLLATE NOCASE, id',
  )).map(ProxyRecord.fromMap).toList(growable: false);

  Future<ProxyRecord?> proxyById(String id) async {
    final rows = await _db.query('proxies', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : ProxyRecord.fromMap(rows.single);
  }

  Future<bool> isProxyCurrent(ProxyRecord record) async => (await _db.query(
    'proxies',
    columns: ['id'],
    where: 'id = ? AND revision = ? AND secret_ref IS ?',
    whereArgs: [record.id, record.revision, record.secretRef],
    limit: 1,
  )).isNotEmpty;

  /// Same contract as [saveCredential]: a changed [ProxyRecord.secretRef] must
  /// have been reserved first; the superseded reference is queued for cleanup
  /// in the same transaction.
  Future<void> saveProxy(
    ProxyRecord record, {
    required int? expectedRevision,
  }) async {
    if (!_validProxyRecord(record)) {
      throw SecurityFailure(LocalizedText((l10n) => l10n.r13ProxyInvalid));
    }
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'proxies',
        where: 'id = ?',
        whereArgs: [record.id],
      );
      final previous = rows.isEmpty ? null : ProxyRecord.fromMap(rows.single);
      if ((expectedRevision == null && previous != null) ||
          (expectedRevision != null &&
              previous?.revision != expectedRevision)) {
        throw const LedgerConflict();
      }
      await _requireSecretReservation(
        txn,
        previous?.secretRef,
        record.secretRef,
      );
      final map = record.toMap();
      map['revision'] = expectedRevision == null ? 0 : expectedRevision + 1;
      map['updated_at'] = clock().toUtc().toIso8601String();
      if (previous == null) {
        await txn.insert('proxies', map);
      } else {
        map.remove('id');
        map.remove('created_at');
        final count = await txn.update(
          'proxies',
          map,
          where: 'id = ? AND revision = ?',
          whereArgs: [record.id, expectedRevision],
        );
        if (count != 1) {
          throw const LedgerConflict();
        }
      }
      await _finishSecretChange(txn, previous?.secretRef, record.secretRef);
    });
  }

  /// Refused while any SSH configuration uses the proxy. The password
  /// reference is queued for cleanup in the same transaction.
  Future<void> deleteProxy(ProxyRecord record) async {
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'proxies',
        where: 'id = ? AND revision = ?',
        whereArgs: [record.id, record.revision],
      );
      if (rows.length != 1) {
        throw const LedgerConflict();
      }
      if ((await txn.query(
        'ssh_configurations',
        where: 'proxy_id = ?',
        whereArgs: [record.id],
        limit: 1,
      )).isNotEmpty) {
        throw SecurityFailure(LocalizedText((l10n) => l10n.r13ProxyInUse));
      }
      final current = ProxyRecord.fromMap(rows.single);
      await txn.delete(
        'proxies',
        where: 'id = ? AND revision = ?',
        whereArgs: [record.id, record.revision],
      );
      final ref = current.secretRef;
      if (ref != null) {
        await _queueSecretCleanup(txn, ref);
      }
    });
  }

  Future<void> saveHostTrust(
    HostTrustRecord record, {
    required HostTrustRecord? expected,
    bool Function()? isCancelled,
  }) async {
    await _db.transaction((txn) async {
      if (isCancelled?.call() ?? false) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.verificationCancelled),
        );
      }
      final rows = await txn.query(
        'host_trust',
        where: 'host = ? AND port = ?',
        whereArgs: [record.host, record.port],
      );
      final previous = rows.isEmpty
          ? null
          : HostTrustRecord.fromMap(rows.single);
      if ((expected == null && previous != null) ||
          (expected != null &&
              (previous == null || !_sameTrustSnapshot(previous, expected)))) {
        throw const LedgerConflict();
      }
      if (isCancelled?.call() ?? false) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.verificationCancelled),
        );
      }
      final map = record.toMap();
      map['generation'] = previous?.generation ?? newLocalId();
      map['revision'] = previous == null ? 0 : previous.revision + 1;
      if (previous == null) {
        await txn.insert('host_trust', map);
      } else {
        await txn.update(
          'host_trust',
          map,
          where: 'host = ? AND port = ?',
          whereArgs: [record.host, record.port],
        );
      }
      if (isCancelled?.call() ?? false) {
        throw SecurityFailure(
          LocalizedText((l10n) => l10n.verificationCancelled),
        );
      }
    });
  }

  Future<void> deleteHostTrust(HostTrustRecord record) async {
    final count = await _db.delete(
      'host_trust',
      where:
          'host = ? AND port = ? AND revision = ? AND generation = ? '
          'AND algorithm = ? AND public_key = ? AND fingerprint = ? AND verified_at = ?',
      whereArgs: [
        record.host,
        record.port,
        record.revision,
        record.generation,
        record.algorithm,
        record.publicKey,
        record.fingerprint,
        record.verifiedAt.toUtc().toIso8601String(),
      ],
    );
    if (count != 1) {
      throw const LedgerConflict();
    }
  }

  Future<void> _requireSecretReservation(
    DatabaseExecutor db,
    String? oldRef,
    String? newRef,
  ) async {
    if (oldRef == newRef || newRef == null) return;
    if ((await db.query(
      'secret_cleanup',
      columns: ['secret_ref'],
      where: 'secret_ref = ?',
      whereArgs: [newRef],
    )).isEmpty) {
      throw SecurityFailure(
        LocalizedText((l10n) => l10n.secretWriteNotPrepared),
      );
    }
  }

  Future<void> _finishSecretChange(
    DatabaseExecutor db,
    String? oldRef,
    String? newRef,
  ) async {
    if (oldRef == newRef) return;
    if (newRef != null) {
      await db.delete(
        'secret_cleanup',
        where: 'secret_ref = ?',
        whereArgs: [newRef],
      );
    }
    if (oldRef != null) await _queueSecretCleanup(db, oldRef);
  }

  Future<void> _queueSecretCleanup(DatabaseExecutor db, String ref) async {
    await db.insert('secret_cleanup', {
      'secret_ref': ref,
      'created_at': clock().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}

Future<bool> _secretIsReferenced(
  DatabaseExecutor db,
  String ref,
) async {
  return (await db.query(
        'credentials',
        where: 'secret_ref = ?',
        whereArgs: [ref],
        limit: 1,
      )).isNotEmpty ||
      (await db.query(
        'proxies',
        where: 'secret_ref = ?',
        whereArgs: [ref],
        limit: 1,
      )).isNotEmpty;
}

bool _validProxyRecord(ProxyRecord record) {
  final host = NetAddress.tryParse(record.host, allowBrackets: false);
  return record.name.trim().isNotEmpty &&
      record.name.length <= 80 &&
      host != null &&
      host.host == record.host &&
      host.zone == null &&
      record.port >= 1 &&
      record.port <= 65535 &&
      (record.username == null
          ? record.secretRef == null
          : validProxyCredential(
                  record.username!,
                  allowColon: record.kind == ProxyKind.socks5,
                ) &&
                record.secretRef != null);
}

bool _sameTrustSnapshot(HostTrustRecord a, HostTrustRecord b) =>
    a.host == b.host &&
    a.port == b.port &&
    a.generation == b.generation &&
    a.revision == b.revision &&
    a.algorithm == b.algorithm &&
    a.publicKey == b.publicKey &&
    a.fingerprint == b.fingerprint &&
    a.verifiedAt == b.verifiedAt;
