part of 'ledger_store.dart';

extension LedgerFinance on LedgerStore {
  Future<List<ServicePeriod>> servicePeriods() async => (await _db.query(
    'service_periods',
    orderBy: 'start_date, end_date, id',
  )).map(ServicePeriod.fromMap).toList(growable: false);
  Future<List<PaymentRecord>> payments() async => (await _db.query(
    'payments',
    orderBy: 'paid_date DESC, created_at DESC, id',
  )).map(PaymentRecord.fromMap).toList(growable: false);
  Future<FxSettings> fxSettings() async => FxSettings.fromMap(
    (await _db.query('finance_settings', where: 'id = 1')).single,
  );
  Future<void> saveFx(FxSettings settings) async {
    final error = settings.validate();
    if (error != null) {
      throw LocalizedArgumentError((l10n) => settings.validate(l10n: l10n)!);
    }
    if (settings.rateDate != null &&
        settings.rateDate!.compareTo(LedgerDate.today(clock())) > 0) {
      throw LocalizedArgumentError((l10n) => l10n.futureRateDate);
    }
    await _db.update('finance_settings', settings.toMap(), where: 'id = 1');
  }

  void _validatePayment(
    String id,
    Money amount,
    LedgerDate paidDate,
    String note,
  ) {
    if (id.isEmpty || id.length > 128) {
      throw LocalizedArgumentError((l10n) => l10n.invalidPaymentId);
    }
    if (!Money.currencies.contains(amount.currency) ||
        amount.minor < 0 ||
        amount.minor > Money.maxMinor) {
      throw LocalizedArgumentError((l10n) => l10n.invalidPaidAmount);
    }
    if (!paidDate.isValid ||
        paidDate.compareTo(LedgerDate.today(clock())) > 0) {
      throw LocalizedArgumentError((l10n) => l10n.futurePaymentDate);
    }
    if (note.length > 4000) {
      throw LocalizedArgumentError((l10n) => l10n.notesTooLong);
    }
  }

  Future<PaymentRecord?> _existingPayment(
    Transaction txn,
    String id,
    String fingerprint,
  ) async {
    final rows = await txn.query('payments', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) {
      return null;
    }
    final existing = PaymentRecord.fromMap(rows.single);
    if (existing.voided) {
      throw LocalizedArgumentError((l10n) => l10n.paymentAlreadyVoided);
    }
    if (existing.requestFingerprint != fingerprint) {
      throw LocalizedArgumentError((l10n) => l10n.paymentIdContentMismatch);
    }
    return existing;
  }

  Future<PaymentRecord> recordPayment({
    required String id,
    required ServerRecord server,
    required Money amount,
    required LedgerDate paidDate,
    required int cycleCount,
    required LedgerDate until,
    required bool confirmed,
    String note = '',
  }) async {
    if (!confirmed) {
      throw LocalizedArgumentError((l10n) => l10n.confirmProviderPayment);
    }
    final fingerprint = jsonEncode([
      'server',
      server.id,
      amount.currency,
      amount.minor,
      paidDate.toString(),
      cycleCount,
      until.toString(),
      note,
    ]);
    return _db.transaction((txn) async {
      final existing = await _existingPayment(txn, id, fingerprint);
      if (existing != null) {
        return existing;
      }
      _validatePayment(id, amount, paidDate, note);
      if (!const [1, 2, 3].contains(cycleCount) || !until.isValid) {
        throw LocalizedArgumentError((l10n) => l10n.invalidRenewalCycleCount);
      }
      final rows = await txn.query(
        'servers',
        where: 'id = ?',
        whereArgs: [server.id],
      );
      if (rows.isEmpty) {
        throw const LedgerConflict();
      }
      final current = ServerRecord.fromMap(rows.single);
      if (current.archived || current.revision != server.revision) {
        throw const LedgerConflict();
      }
      if (current.billing != BillingKind.prepaid || current.dueDate == null) {
        throw LocalizedArgumentError((l10n) => l10n.renewalNeedsPrepaidDate);
      }
      if (renewalDate(current, cycleCount) != until) {
        throw LocalizedArgumentError((l10n) => l10n.renewalDateMismatch);
      }
      if ((await txn.query(
        'payments',
        where: 'server_id = ? AND until_date = ? AND voided_at IS NULL',
        whereArgs: [current.id, until.toString()],
      )).isNotEmpty) {
        throw LocalizedArgumentError((l10n) => l10n.duplicateExpiryPayment);
      }
      final now = clock().toUtc();
      final payment = PaymentRecord(
        id: id,
        serverId: current.id,
        targetName: current.name,
        amount: amount,
        paidDate: paidDate,
        from: current.dueDate,
        until: until,
        cycleCount: cycleCount,
        note: note,
        previousDue: current.dueDate,
        appliedServerRevision: current.revision + 1,
        createdAt: now,
        requestFingerprint: fingerprint,
      );
      await txn.insert('payments', payment.toMap());
      for (var i = 0; i < cycleCount; i++) {
        await txn.insert(
          'service_periods',
          ServicePeriod(
            id: '$id-$i',
            serverId: current.id,
            start: renewalDate(current, i),
            end: renewalDate(current, i + 1),
            paymentId: id,
          ).toMap(),
        );
      }
      final count = await txn.update(
        'servers',
        {
          'due_date': until.toString(),
          'revision': current.revision + 1,
          'renewal_anchor_date': (current.renewalAnchorDate ?? current.dueDate)
              .toString(),
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ? AND revision = ? AND archived_at IS NULL',
        whereArgs: [current.id, current.revision],
      );
      if (count != 1) {
        throw const LedgerConflict();
      }
      return payment;
    });
  }

  Future<PaymentRecord> recordAccountPayment({
    required String id,
    required String accountLabel,
    required Money amount,
    required LedgerDate paidDate,
    LedgerDate? from,
    LedgerDate? until,
    String note = '',
  }) async {
    final label = accountLabel.trim();
    final fingerprint = jsonEncode([
      'account',
      label,
      amount.currency,
      amount.minor,
      paidDate.toString(),
      from?.toString(),
      until?.toString(),
      note,
    ]);
    return _db.transaction((txn) async {
      final existing = await _existingPayment(txn, id, fingerprint);
      if (existing != null) {
        return existing;
      }
      _validatePayment(id, amount, paidDate, note);
      if (label.isEmpty || label.length > 80) {
        throw LocalizedArgumentError((l10n) => l10n.invalidAccountName);
      }
      if ((from == null) != (until == null) ||
          (from != null &&
              (!from.isValid ||
                  !until!.isValid ||
                  from.compareTo(until) >= 0))) {
        throw LocalizedArgumentError(
          (l10n) => l10n.invalidOptionalBillingPeriod,
        );
      }
      final payment = PaymentRecord(
        id: id,
        targetName: label,
        accountLabel: label,
        amount: amount,
        paidDate: paidDate,
        from: from,
        until: until,
        note: note,
        createdAt: clock().toUtc(),
        requestFingerprint: fingerprint,
      );
      await txn.insert('payments', payment.toMap());
      return payment;
    });
  }

  Future<void> undoPayment(String id) async {
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'payments',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) {
        throw const LedgerConflict();
      }
      final payment = PaymentRecord.fromMap(rows.single);
      if (payment.voided) {
        return;
      }
      await _voidPayment(txn, payment, rollbackRenewal: !payment.isAccount);
    });
  }

  /// Marks [payment] voided (a tombstone: the row and its idempotency key stay,
  /// so neither an old undo nor a repeated request can revive it; every total
  /// already excludes voided rows).
  ///
  /// With [rollbackRenewal] the term is rolled back as well (see
  /// [_rollbackTail]). Without it the periods stay linked to the (voided)
  /// payment so the term history is unchanged; the backup validator accepts
  /// that shape and [rollbackOrphanTerm] can still remove them later.
  Future<void> _voidPayment(
    Transaction txn,
    PaymentRecord payment, {
    required bool rollbackRenewal,
    int? expectedServerRevision,
  }) async {
    final now = clock().toUtc().toIso8601String();
    if (rollbackRenewal && !payment.isAccount) {
      await _rollbackTail(
        txn,
        serverId: payment.serverId!,
        expectedRevision: expectedServerRevision,
        paymentId: payment.id,
        now: now,
      );
    }
    await txn.update(
      'payments',
      {'voided_at': now},
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  /// Removes the tail of a server's term and restores the due date to the
  /// start of the removed span, in the caller's transaction.
  ///
  /// The rule is about the **term**, not the whole record: the server must be
  /// active and prepaid, its last period must end at the due date and belong to
  /// [paymentId] (for a live payment: be exactly the periods that payment
  /// created; for a deleted one: be periods still linked to the voided
  /// payment), and the run must follow the cycle from the renewal anchor. Edits
  /// unrelated to the term (name, favourite, notes, hardware …) bump the
  /// revision but never block it. [expectedRevision] is the revision the caller
  /// displayed; any difference is a [LedgerConflict], as is every failed term
  /// condition. The renewal anchor is left alone: the restored due date is the
  /// anchor plus whole cycles, so `renewalDate()` keeps working.
  Future<LedgerDate> _rollbackTail(
    Transaction txn, {
    required String serverId,
    required int? expectedRevision,
    required String paymentId,
    required String now,
  }) async {
    final rows = await txn.query(
      'servers',
      where: 'id = ?',
      whereArgs: [serverId],
    );
    if (rows.isEmpty) throw const LedgerConflict();
    final server = ServerRecord.fromMap(rows.single);
    if (expectedRevision != null && server.revision != expectedRevision) {
      throw const LedgerConflict();
    }
    final periods = (await txn.query(
      'service_periods',
      where: 'server_id = ?',
      whereArgs: [serverId],
    )).map(ServicePeriod.fromMap).toList();
    final tail = tailTerm(server, periods);
    if (tail == null || tail.paymentId != paymentId) {
      throw const LedgerConflict();
    }
    // A live payment must own exactly the tail; the periods are the proof.
    final paymentRows = await txn.query(
      'payments',
      where: 'id = ?',
      whereArgs: [paymentId],
    );
    if (paymentRows.isEmpty) throw const LedgerConflict();
    final payment = PaymentRecord.fromMap(paymentRows.single);
    if (!payment.voided &&
        (tail.periods.length != payment.cycleCount ||
            tail.start != payment.from ||
            tail.end != payment.until ||
            payment.previousDue != payment.from)) {
      throw const LedgerConflict();
    }
    final restored = tail.start;
    final count = await txn.update(
      'servers',
      {
        'due_date': restored.toString(),
        'revision': server.revision + 1,
        'updated_at': now,
      },
      where: 'id = ? AND revision = ? AND due_date = ? AND archived_at IS NULL',
      whereArgs: [serverId, server.revision, server.dueDate.toString()],
    );
    if (count != 1) throw const LedgerConflict();
    await txn.delete(
      'service_periods',
      where: 'payment_id = ? AND server_id = ?',
      whereArgs: [paymentId, serverId],
    );
    return restored;
  }

  /// Repairs a term left behind by a deleted payment: when the tail of the
  /// server's term still belongs to a voided payment (delete-record-only, or
  /// data from before rollbacks followed the term rule), removes that payment's
  /// periods and restores the due date to their start. One payment per call;
  /// call again for older ones. Never touches periods of live payments or the
  /// initial / inferred period. Returns the restored due date.
  /// [expectedRevision] is the revision the user saw; any difference, or no
  /// such tail, is a [LedgerConflict].
  Future<LedgerDate> rollbackOrphanTerm({
    required String serverId,
    required int expectedRevision,
  }) => _db.transaction((txn) async {
    final rows = await txn.query(
      'servers',
      where: 'id = ?',
      whereArgs: [serverId],
    );
    if (rows.isEmpty) throw const LedgerConflict();
    final server = ServerRecord.fromMap(rows.single);
    final periods = (await txn.query(
      'service_periods',
      where: 'server_id = ?',
      whereArgs: [serverId],
    )).map(ServicePeriod.fromMap).toList();
    final tail = tailTerm(server, periods);
    if (tail == null) throw const LedgerConflict();
    final owner = await txn.query(
      'payments',
      where: 'id = ? AND voided_at IS NOT NULL',
      whereArgs: [tail.paymentId],
    );
    if (owner.isEmpty) throw const LedgerConflict();
    return _rollbackTail(
      txn,
      serverId: serverId,
      expectedRevision: expectedRevision,
      paymentId: tail.paymentId,
      now: clock().toUtc().toIso8601String(),
    );
  });

  /// Loads the stored row of [original] and requires it to be unchanged.
  /// Payments have no revision column, so the whole row is the version token.
  Future<PaymentRecord> _currentPayment(
    Transaction txn,
    PaymentRecord original,
  ) async {
    final rows = await txn.query(
      'payments',
      where: 'id = ?',
      whereArgs: [original.id],
    );
    if (rows.isEmpty) {
      throw const LedgerConflict();
    }
    final current = PaymentRecord.fromMap(rows.single);
    if (jsonEncode(current.toMap()) != jsonEncode(original.toMap())) {
      throw const LedgerConflict();
    }
    return current;
  }

  /// Edits the bookkeeping fields of a payment: amount, currency, paid date,
  /// note and (account bills) the account name. Never touches the due date,
  /// cycle count, from/until or service periods. [original] is the row the
  /// caller loaded; any change since then raises [LedgerConflict].
  Future<PaymentRecord> editPayment({
    required PaymentRecord original,
    required Money amount,
    required LedgerDate paidDate,
    String note = '',
    String? accountLabel,
  }) async {
    final label = accountLabel?.trim();
    return _db.transaction((txn) async {
      final current = await _currentPayment(txn, original);
      if (current.voided) {
        throw LocalizedArgumentError((l10n) => l10n.paymentAlreadyVoided);
      }
      _validatePayment(current.id, amount, paidDate, note);
      final values = <String, Object?>{
        'amount_minor': amount.minor,
        'currency': amount.currency,
        'paid_date': paidDate.toString(),
        'note': note,
      };
      if (current.isAccount) {
        if (label == null || label.isEmpty || label.length > 80) {
          throw LocalizedArgumentError((l10n) => l10n.invalidAccountName);
        }
        // The backup format requires target_name == account_label.
        values['account_label'] = label;
        values['target_name'] = label;
      }
      final count = await txn.update(
        'payments',
        values,
        where: 'id = ? AND voided_at IS NULL',
        whereArgs: [current.id],
      );
      if (count != 1) {
        throw const LedgerConflict();
      }
      return PaymentRecord.fromMap(
        (await txn.query(
          'payments',
          where: 'id = ?',
          whereArgs: [current.id],
        )).single,
      );
    });
  }

  /// Deletes a payment record (soft: a voided tombstone, see [_voidPayment]).
  ///
  /// [rollbackRenewal] additionally restores the server's previous due date and
  /// removes the periods this payment added. That requires the payment to be
  /// the tail of the server's term (see [_rollbackTail]); unrelated server
  /// edits do not matter. [expectedServerRevision] is the server revision shown
  /// to the user; a different revision is a [LedgerConflict]. Without
  /// [rollbackRenewal] the term stays as it is. Deleting an already deleted
  /// payment is a no-op.
  Future<void> deletePayment({
    required PaymentRecord original,
    bool rollbackRenewal = false,
    int? expectedServerRevision,
  }) async {
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'payments',
        where: 'id = ?',
        whereArgs: [original.id],
      );
      if (rows.isEmpty) {
        throw const LedgerConflict();
      }
      if (PaymentRecord.fromMap(rows.single).voided) {
        return;
      }
      final current = await _currentPayment(txn, original);
      await _voidPayment(
        txn,
        current,
        rollbackRenewal: rollbackRenewal,
        expectedServerRevision: expectedServerRevision,
      );
    });
  }
}

Future<void> _replaceInitialPeriod(
  DatabaseExecutor db,
  ServerRecord record,
) async {
  await db.delete(
    'service_periods',
    where: 'server_id = ? AND payment_id IS NULL',
    whereArgs: [record.id],
  );
  final due = record.dueDate;
  if (record.billing != BillingKind.prepaid ||
      due == null ||
      !due.isValid ||
      !validCycle(record.cycleMonths)) {
    return;
  }
  final knownStart = record.startDate;
  final hasStart =
      knownStart != null && knownStart.isValid && knownStart.compareTo(due) < 0;
  final start = hasStart ? knownStart : due.addMonths(-record.cycleMonths);
  if (!start.isValid || start.compareTo(due) >= 0) {
    return;
  }
  await db.insert(
    'service_periods',
    ServicePeriod(
      id: 'initial-${record.id}',
      serverId: record.id,
      start: start,
      end: due,
      inferred: !hasStart,
    ).toMap(),
  );
}
