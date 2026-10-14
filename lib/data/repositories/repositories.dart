import '../../core/utils/goal_photo_data.dart';
import '../../core/utils/money_amount.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database.dart';
import '../models/enums.dart';
import '../models/models.dart';
import '../../core/utils/financial_day.dart';
import '../../providers.dart';

class SettingsRepo {
  final AppDatabase db;
  SettingsRepo(this.db);

  Future<SettingsRecord> load() async {
    final raw = await (await db.database).query('settings', where: 'id = 1');
    if (raw.isEmpty) {
      // First-run safety net. The FirstRunInitializer normally inserts this
      // row, but if the DB was wiped mid-session, recreate the default.
      const defaultRec = SettingsRecord(
        displayName: 'there',
        cutoffHour: 3,
        currency: 'PHP',
      );
      await save(defaultRec);
      return defaultRec;
    }
    return SettingsRecord.fromRow(raw.first);
  }

  Future<void> save(SettingsRecord r) async {
    await (await db.database).insert(
      'settings',
      r.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

class SettingsNotifier extends AsyncNotifier<SettingsRecord> {
  @override
  Future<SettingsRecord> build() async {
    final repo = ref.watch(settingsRepoProvider);
    return repo.load();
  }

  Future<void> save(SettingsRecord r) async {
    if (r.displayName.trim().isEmpty) {
      throw ArgumentError('Display name is required');
    }
    final repo = ref.read(settingsRepoProvider);
    final previous = state.valueOrNull;
    await repo.save(r);
    state = AsyncData(r);
    if (previous?.cutoffHour != r.cutoffHour) await refreshDerivedData(ref);
  }
}

class AccountRepo {
  final AppDatabase db;
  AccountRepo(this.db);

  Future<List<AccountRecord>> all() async {
    final rows = await (await db.database).query(
      'accounts',
      orderBy: 'sort_order, id',
    );
    return rows.map(AccountRecord.fromRow).toList();
  }

  Future<List<AccountRecord>> byType(String type) async {
    final rows = await (await db.database).query(
      'accounts',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'sort_order, id',
    );
    return rows.map(AccountRecord.fromRow).toList();
  }

  Future<double> totalBalance() async {
    final rows = await (await db.database).rawQuery(
      'SELECT COALESCE(SUM(balance), 0) AS total FROM accounts',
    );
    final v = rows.first['total'];
    if (v == null) return 0;
    return (v as num).toDouble();
  }

  Future<int> insert(AccountRecord r) async {
    MoneyAmount.require(r.balance, signed: true);
    if (r.name.trim().isEmpty) throw ArgumentError('Account name is required');
    final row = Map<String, Object?>.from(r.toRow())..remove('id');
    row['name'] = r.name.trim();
    return (await db.database).transaction((txn) async {
      final accounts = await txn.query('accounts', columns: ['name']);
      if (accounts.any(
        (a) =>
            (a['name'] as String).trim().toLowerCase() ==
            r.name.trim().toLowerCase(),
      )) {
        throw StateError('Account names must be unique');
      }
      return txn.insert('accounts', row);
    });
  }

  Future<bool> hasLinkedRecords(String name) async {
    final database = await db.database;
    final tx = await database.query(
      'transactions',
      columns: ['id'],
      where: 'account = ? OR destination_account = ?',
      whereArgs: [name, name],
      limit: 1,
    );
    final rules = await database.query(
      'recurring_transactions',
      columns: ['id'],
      where: 'account = ?',
      whereArgs: [name],
      limit: 1,
    );
    return tx.isNotEmpty || rules.isNotEmpty;
  }

  Future<void> update(AccountRecord r, {double? expectedBalance}) async {
    MoneyAmount.require(r.balance, signed: true);
    if (r.name.trim().isEmpty || !r.balance.isFinite) {
      throw ArgumentError('Enter a valid account name and balance');
    }
    await (await db.database).transaction((txn) async {
      final old = await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [r.id],
      );
      if (old.isEmpty) throw StateError('Account no longer exists');
      final liveBalance = (old.single['balance'] as num).toDouble();
      if (expectedBalance != null &&
          r.balance != expectedBalance &&
          liveBalance != expectedBalance) {
        throw StateError(
          'The balance changed while editing. Reopen the account before correcting it.',
        );
      }
      final others = await txn.query(
        'accounts',
        where: 'id != ?',
        whereArgs: [r.id],
      );
      if (others.any(
        (a) =>
            (a['name'] as String).trim().toLowerCase() ==
            r.name.trim().toLowerCase(),
      )) {
        throw StateError('Account names must be unique');
      }
      final sameOldName = await txn.query(
        'accounts',
        where: 'name = ?',
        whereArgs: [old.single['name']],
      );
      // Legacy duplicates cannot be attributed retrospectively. Keep historical
      // references on the original name until the remaining account is renamed.
      if (sameOldName.length == 1) {
        await txn.update(
          'transactions',
          {'account': r.name.trim()},
          where: 'account = ?',
          whereArgs: [old.single['name']],
        );
        await txn.update(
          'transactions',
          {'destination_account': r.name.trim()},
          where: 'destination_account = ?',
          whereArgs: [old.single['name']],
        );
        await txn.update(
          'recurring_transactions',
          {'account': r.name.trim()},
          where: 'account = ?',
          whereArgs: [old.single['name']],
        );
      }
      await txn.update(
        'accounts',
        r.toRow()
          ..['name'] = r.name.trim()
          ..['balance'] =
              expectedBalance != null && r.balance == expectedBalance
              ? liveBalance
              : r.balance,
        where: 'id = ?',
        whereArgs: [r.id],
      );
    });
  }

  Future<void> delete(int id) async {
    await (await db.database).transaction((txn) async {
      final old = await txn.query('accounts', where: 'id = ?', whereArgs: [id]);
      if (old.isEmpty) return;
      for (final table in ['transactions', 'recurring_transactions']) {
        final linked = await txn.query(
          table,
          where: table == 'transactions'
              ? 'account = ? OR destination_account = ?'
              : 'account = ?',
          whereArgs: table == 'transactions'
              ? [old.single['name'], old.single['name']]
              : [old.single['name']],
          limit: 1,
        );
        if (linked.isNotEmpty) {
          throw StateError(
            'This account has linked transactions or recurring rules and cannot be deleted. Your history has been kept.',
          );
        }
      }
      await txn.delete('accounts', where: 'id = ?', whereArgs: [id]);
    });
  }
}

class AccountsNotifier extends AsyncNotifier<List<AccountRecord>> {
  @override
  Future<List<AccountRecord>> build() async {
    final repo = ref.watch(accountRepoProvider);
    return repo.all();
  }

  Future<void> refresh() async {
    final repo = ref.read(accountRepoProvider);
    state = AsyncData(await repo.all());
  }

  Future<void> add(AccountRecord a) async {
    final repo = ref.read(accountRepoProvider);
    await repo.insert(a);
    await refresh();
  }

  Future<void> edit(AccountRecord a, {double? expectedBalance}) async {
    final repo = ref.read(accountRepoProvider);
    await repo.update(a, expectedBalance: expectedBalance);
    ref.invalidate(transactionsProvider);
    ref.invalidate(recurringProvider);
    await refresh();
  }

  Future<void> remove(int id) async {
    final repo = ref.read(accountRepoProvider);
    await repo.delete(id);
    await refresh();
  }
}

class TransactionRepo {
  final AppDatabase db;
  TransactionRepo(this.db);

  Future<List<TxRecord>> all({int? limit}) async {
    final rows = await (await db.database).query(
      'transactions',
      orderBy: 'occurred_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(TxRecord.fromRow).toList();
  }

  Future<TxRecord?> byId(int id) async {
    final rows = await (await db.database).query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return TxRecord.fromRow(rows.first);
  }

  Future<void> _adjustBalance(
    Transaction txn,
    TxRecord tx,
    double direction,
  ) async {
    MoneyAmount.require(tx.amount);
    if (tx.type == TxType.transfer) {
      final destination = tx.destinationAccount;
      if (destination == null || destination == tx.account) {
        throw ArgumentError('Choose two different accounts.');
      }
      final source = direction > 0 ? tx.account : destination;
      final target = direction > 0 ? destination : tx.account;
      final targets = await txn.query(
        'accounts',
        where: 'name = ?',
        whereArgs: [target],
      );
      if (targets.length != 1) {
        throw StateError('Choose two uniquely named accounts.');
      }
      MoneyAmount.require(
        MoneyAmount.round((targets.single['balance'] as num) + tx.amount),
        signed: true,
      );
      final rows = await txn.query(
        'accounts',
        where: 'name = ?',
        whereArgs: [source],
      );
      if (rows.length != 1 ||
          (rows.single['balance'] as num).toDouble() + 0.000001 < tx.amount) {
        throw StateError('Insufficient available balance.');
      }
      MoneyAmount.require(rows.single['balance'] as num, signed: true);
      final debited = await txn.rawUpdate(
        'UPDATE accounts SET balance = ROUND(balance - ?, 2) WHERE name = ?',
        [tx.amount, source],
      );
      final credited = await txn.rawUpdate(
        'UPDATE accounts SET balance = ROUND(balance + ?, 2) WHERE name = ?',
        [tx.amount, target],
      );
      if (debited != 1 || credited != 1) {
        throw StateError('Choose two existing accounts.');
      }
      return;
    }
    final delta = tx.amount * (tx.type == TxType.income ? 1 : -1) * direction;
    final accounts = await txn.query(
      'accounts',
      where: 'name = ?',
      whereArgs: [tx.account],
    );
    if (accounts.length != 1) {
      throw StateError('Rename duplicate accounts before recording money.');
    }
    MoneyAmount.require(
      MoneyAmount.round((accounts.single['balance'] as num) + delta),
      signed: true,
    );
    final changed = await txn.rawUpdate(
      'UPDATE accounts SET balance = ROUND(balance + ?, 2) WHERE name = ?',
      [delta, tx.account],
    );
    if (changed != 1) {
      throw StateError('Choose an existing, uniquely named account');
    }
  }

  Future<int> insert(TxRecord tx) async {
    return (await db.database).transaction(
      (txn) => insertInTransaction(txn, tx),
    );
  }

  /// Share the ordinary balance update with atomic multi-record operations.
  /// The caller owns the database transaction and its commit/rollback.
  Future<int> insertInTransaction(Transaction txn, TxRecord tx) async {
    await _adjustBalance(txn, tx, 1);
    final row = Map<String, Object?>.from(tx.toRow())..remove('id');
    return txn.insert('transactions', row);
  }

  Future<int> moveMoney(TxRecord tx) async {
    return (await db.database).transaction((txn) async {
      if (tx.type == TxType.expense) {
        final rows = await txn.query(
          'accounts',
          where: 'name = ?',
          whereArgs: [tx.account],
        );
        if (rows.length != 1 ||
            (rows.single['balance'] as num).toDouble() + 0.000001 < tx.amount) {
          throw StateError('Insufficient available balance.');
        }
      }
      return insertInTransaction(txn, tx);
    });
  }

  Future<void> update(TxRecord tx) async {
    await (await db.database).transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [tx.id],
      );
      if (rows.isEmpty) throw StateError('Transaction no longer exists');
      await _adjustBalance(txn, TxRecord.fromRow(rows.single), -1);
      await _adjustBalance(txn, tx, 1);
      await txn.insert('transaction_revisions', {
        'transaction_id': tx.id,
        'old_values': jsonEncode(rows.single),
        'new_values': jsonEncode(tx.toRow()),
        'changed_at': DateTime.now().toIso8601String(),
      });
      await txn.update(
        'transactions',
        tx.toRow(),
        where: 'id = ?',
        whereArgs: [tx.id],
      );
    });
  }

  Future<void> delete(int id) async {
    await (await db.database).transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) return;
      await _adjustBalance(txn, TxRecord.fromRow(rows.single), -1);
      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Undo only the exact entry just saved; never erase a later edit.
  Future<void> undoAdded(TxRecord expected) async {
    await (await db.database).transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [expected.id],
      );
      if (rows.isEmpty ||
          jsonEncode(TxRecord.fromRow(rows.single).toRow()) !=
              jsonEncode(expected.toRow())) {
        throw StateError(
          'This entry changed or was already removed. Review it in History.',
        );
      }
      if (expected.type == TxType.income) {
        final accounts = await txn.query(
          'accounts',
          where: 'name = ?',
          whereArgs: [expected.account],
        );
        if (accounts.length != 1 ||
            (accounts.single['balance'] as num) + .000001 < expected.amount) {
          throw StateError(
            'This income has already been used. Review the account before undoing.',
          );
        }
      }
      await _adjustBalance(txn, expected, -1);
      await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [expected.id],
      );
    });
  }

  Future<List<TxRecord>> range(DateTime from, DateTime to) async {
    final rows = await (await db.database).query(
      'transactions',
      where: 'occurred_at >= ? AND occurred_at <= ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'occurred_at ASC',
    );
    return rows.map(TxRecord.fromRow).toList();
  }
}

class TransactionsNotifier extends AsyncNotifier<List<TxRecord>> {
  final _requests = Expando<Future<int>>();
  @override
  Future<List<TxRecord>> build() => ref.watch(transactionRepoProvider).all();
  Future<void> refresh() async {
    state = AsyncData(await ref.read(transactionRepoProvider).all());
  }

  Future<void> _afterWrite() async {
    // A derived-state failure must never report a committed write as unsaved.
    var refreshFailed = false;
    for (final refresh in <Future<void> Function()>[
      this.refresh,
      () => ref.read(accountsProvider.notifier).refresh(),
    ]) {
      try {
        await refresh();
      } catch (_) {
        refreshFailed = true;
      }
    }
    await refreshDerivedData(ref);
    if (refreshFailed) {
      ref.read(derivedDataIssueProvider.notifier).state =
          'Your changes were saved. Refresh the overview to reload totals.';
    }
  }

  Future<int> add(TxRecord tx) => _requests[tx] ??= _add(tx);
  Future<int> _add(TxRecord tx) async {
    int id;
    try {
      id = await ref.read(transactionRepoProvider).insert(tx);
    } catch (_) {
      _requests[tx] = null;
      rethrow;
    }
    await _afterWrite();
    return id;
  }

  Future<void> undoAdded(TxRecord expected) async {
    await ref.read(transactionRepoProvider).undoAdded(expected);
    await _afterWrite();
  }

  Future<void> moveMoney(TxRecord tx) async {
    await ref.read(transactionRepoProvider).moveMoney(tx);
    await _afterWrite();
  }

  Future<void> edit(TxRecord old, TxRecord updated) async {
    await ref.read(transactionRepoProvider).update(updated);
    await _afterWrite();
  }

  Future<void> remove(int id) async {
    await ref.read(transactionRepoProvider).delete(id);
    await _afterWrite();
  }
}

/// Rebuild recoverable analytics without changing the outcome of a saved edit.
Future<void> refreshDerivedData(Ref ref) async {
  try {
    await ref
        .read(recalcServiceProvider)
        .recomputeAll(
          cutoffHour: (await ref.read(settingsRepoProvider).load()).cutoffHour,
        );
    ref.read(derivedDataIssueProvider.notifier).state = null;
  } catch (error, stack) {
    ref
        .read(appLoggerProvider)
        .error(
          'Saved data retained; analytics refresh failed.',
          error: error,
          stack: stack,
        );
    ref.read(derivedDataIssueProvider.notifier).state =
        'Your data is saved. Analytics need a refresh. Pull down on Home to retry.';
  }
  ref.invalidate(dailyCacheForMonthProvider);
  ref.invalidate(dailyCacheForDayProvider);
  ref.invalidate(earnedAchievementsProvider);
}

class GoalRepo {
  final AppDatabase db;
  GoalRepo(this.db);

  Future<List<GoalRecord>> all() async {
    final rows = await (await db.database).query(
      'goals',
      orderBy: 'sort_order, id',
    );
    return rows.map(GoalRecord.fromRow).toList();
  }

  Future<List<GoalRecord>> byStatus(GoalStatus status) async {
    final rows = await (await db.database).query(
      'goals',
      where: 'status = ?',
      whereArgs: [status.id],
      orderBy: 'sort_order, id',
    );
    return rows.map(GoalRecord.fromRow).toList();
  }

  void _validateGoal(GoalRecord g) {
    MoneyAmount.require(g.targetAmount);
    MoneyAmount.require(g.currentAmount, zero: true);
    if (g.monthlyTarget != null) MoneyAmount.require(g.monthlyTarget!);
    GoalPhotoData.decode(g.photo);
    if (g.name.trim().isEmpty ||
        !g.targetAmount.isFinite ||
        g.targetAmount <= 0 ||
        g.targetAmount > 999999999.99 ||
        !g.currentAmount.isFinite ||
        g.currentAmount < 0) {
      throw ArgumentError('Enter a goal name and a valid positive target.');
    }
    if (g.monthlyTarget != null &&
        (!g.monthlyTarget!.isFinite ||
            g.monthlyTarget! <= 0 ||
            g.monthlyTarget! > 999999999.99)) {
      throw ArgumentError('Monthly target must be a valid positive amount.');
    }
  }

  Future<int> insert(GoalRecord g) async {
    _validateGoal(g);
    final row = Map<String, Object?>.from(g.toRow())..remove('id');
    return (await db.database).insert('goals', row);
  }

  Future<void> update(GoalRecord g) async {
    _validateGoal(g);
    await (await db.database).transaction((txn) async {
      final existing = await txn.query(
        'goals',
        where: 'id = ?',
        whereArgs: [g.id],
      );
      if (existing.isEmpty) throw StateError('Goal no longer exists.');
      final saved = MoneyAmount.round(existing.single['current_amount'] as num);
      final row = g.toRow();
      row['current_amount'] = saved;
      row['status'] = saved >= g.targetAmount ? 'completed' : 'active';
      row['completed_at'] = saved >= g.targetAmount
          ? existing.single['completed_at'] ?? DateTime.now().toIso8601String()
          : null;
      await txn.update('goals', row, where: 'id = ?', whereArgs: [g.id]);
    });
  }

  Future<void> delete(int id) async {
    await (await db.database).transaction((txn) async {
      await txn.delete(
        'goal_contributions',
        where: 'goal_id = ?',
        whereArgs: [id],
      );
      await txn.delete('goals', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<GoalContribution>> contributionsFor(int goalId) async {
    final rows = await (await db.database).query(
      'goal_contributions',
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'contributed_at DESC',
    );
    return rows.map(GoalContribution.fromRow).toList();
  }

  Future<List<GoalContribution>> allContributions() async {
    final rows = await (await db.database).query(
      'goal_contributions',
      orderBy: 'contributed_at DESC',
    );
    return rows.map(GoalContribution.fromRow).toList();
  }

  Future<void> withdraw(int goalId, double amount) async {
    MoneyAmount.require(amount);
    await (await db.database).transaction((txn) async {
      final rows = await txn.query(
        'goals',
        where: 'id = ?',
        whereArgs: [goalId],
      );
      if (rows.isEmpty) throw StateError('Goal no longer exists.');
      final g = GoalRecord.fromRow(rows.single);
      if (MoneyAmount.cents(amount) > MoneyAmount.cents(g.currentAmount)) {
        throw StateError('Amount exceeds saved money.');
      }
      await txn.insert(
        'goal_contributions',
        GoalContribution(
          goalId: goalId,
          amount: -amount,
          contributedAt: DateTime.now(),
          notes: 'Withdrawal from goal allocation',
        ).toRow(),
      );
      await txn.update(
        'goals',
        {
          'current_amount':
              (MoneyAmount.cents(g.currentAmount) - MoneyAmount.cents(amount)) /
              100,
          'status':
              MoneyAmount.cents(g.currentAmount) - MoneyAmount.cents(amount) >=
                  MoneyAmount.cents(g.targetAmount)
              ? 'completed'
              : 'active',
          'completed_at':
              MoneyAmount.cents(g.currentAmount) - MoneyAmount.cents(amount) >=
                  MoneyAmount.cents(g.targetAmount)
              ? g.completedAt?.toIso8601String()
              : null,
        },
        where: 'id = ?',
        whereArgs: [goalId],
      );
    });
  }

  Future<int> addContribution(GoalContribution c) async {
    MoneyAmount.require(c.amount);
    return (await db.database).transaction((txn) async {
      final rows = await txn.query(
        'goals',
        where: 'id = ?',
        whereArgs: [c.goalId],
      );
      if (rows.isEmpty) throw StateError('Goal no longer exists.');
      final goal = GoalRecord.fromRow(rows.single);
      final current =
          (MoneyAmount.cents(goal.currentAmount) +
              MoneyAmount.cents(c.amount)) /
          100;
      if (current > goal.targetAmount + 0.000001) {
        throw StateError('Amount exceeds the remaining goal target.');
      }
      final id = await txn.insert(
        'goal_contributions',
        Map<String, Object?>.from(c.toRow())..remove('id'),
      );
      await txn.update(
        'goals',
        {
          'current_amount': current,
          'status': current >= goal.targetAmount
              ? GoalStatus.completed.id
              : goal.status.id,
          'completed_at': current >= goal.targetAmount
              ? c.contributedAt.toIso8601String()
              : goal.completedAt?.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [c.goalId],
      );
      return id;
    });
  }
}

class GoalsNotifier extends AsyncNotifier<List<GoalRecord>> {
  @override
  Future<List<GoalRecord>> build() async {
    final repo = ref.watch(goalRepoProvider);
    return repo.all();
  }

  Future<void> refresh() async {
    final repo = ref.read(goalRepoProvider);
    state = AsyncData(await repo.all());
  }

  Future<void> add(GoalRecord g) async {
    final repo = ref.read(goalRepoProvider);
    await repo.insert(g);
    await refresh();
  }

  Future<void> edit(GoalRecord g) async {
    final repo = ref.read(goalRepoProvider);
    await repo.update(g);
    await refresh();
  }

  Future<void> remove(int id) async {
    final repo = ref.read(goalRepoProvider);
    await repo.delete(id);
    await refresh();
  }

  Future<void> contribute(GoalRecord g, double amount, {String? notes}) async {
    final repo = ref.read(goalRepoProvider);
    if (g.id == null) return;
    await repo.addContribution(
      GoalContribution(
        goalId: g.id!,
        amount: amount,
        contributedAt: DateTime.now(),
        notes: notes,
      ),
    );
    await refresh();
  }
}

class JournalRepo {
  final AppDatabase db;
  JournalRepo(this.db);

  Future<List<JournalRecord>> all() async {
    final rows = await (await db.database).query(
      'journal_entries',
      orderBy: 'entry_date DESC, id DESC',
    );
    return rows.map(JournalRecord.fromRow).toList();
  }

  Future<int> insert(JournalRecord j) async {
    final row = Map<String, Object?>.from(j.toRow())..remove('id');
    return (await db.database).insert('journal_entries', row);
  }

  Future<void> update(JournalRecord j) async {
    await (await db.database).update(
      'journal_entries',
      j.toRow(),
      where: 'id = ?',
      whereArgs: [j.id],
    );
  }

  Future<void> delete(int id) async {
    await (await db.database).delete(
      'journal_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class JournalNotifier extends AsyncNotifier<List<JournalRecord>> {
  @override
  Future<List<JournalRecord>> build() async {
    final repo = ref.watch(journalRepoProvider);
    return repo.all();
  }

  Future<void> refresh() async {
    final repo = ref.read(journalRepoProvider);
    state = AsyncData(await repo.all());
  }

  Future<void> add(JournalRecord j) async {
    final repo = ref.read(journalRepoProvider);
    await repo.insert(j);
    await refresh();
  }

  Future<void> remove(int id) async {
    final repo = ref.read(journalRepoProvider);
    await repo.delete(id);
    await refresh();
  }
}

class CacheRepo {
  final AppDatabase db;
  CacheRepo(this.db);

  Future<DailyPerformance?> forDay(DateTime date, {int cutoffHour = 3}) async {
    final k = FinancialDay.key(date, cutoffHour: cutoffHour);
    final rows = await (await db.database).query(
      'daily_performance_cache',
      where: 'date = ?',
      whereArgs: [DateTime(k.year, k.month, k.day).toIso8601String()],
    );
    if (rows.isEmpty) return null;
    return DailyPerformance.fromRow(rows.first);
  }

  Future<List<DailyPerformance>> forMonth(
    DateTime month, {
    int cutoffHour = 3,
  }) async {
    final start = FinancialDay.startOfMonth(month, cutoffHour: cutoffHour);
    final end = FinancialDay.endOfMonth(month, cutoffHour: cutoffHour);
    final rows = await (await db.database).query(
      'daily_performance_cache',
      where: 'date >= ? AND date <= ?',
      whereArgs: [
        DateTime(start.year, start.month, start.day).toIso8601String(),
        DateTime(end.year, end.month, end.day).toIso8601String(),
      ],
      orderBy: 'date ASC',
    );
    return rows.map(DailyPerformance.fromRow).toList();
  }

  Future<void> upsert(DailyPerformance d) async {
    await (await db.database).insert(
      'daily_performance_cache',
      d.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DailyPerformance>> rangeInclusive(
    DateTime start,
    DateTime end, {
    int cutoffHour = 3,
  }) async {
    final s = FinancialDay.key(start, cutoffHour: cutoffHour);
    final e = FinancialDay.key(end, cutoffHour: cutoffHour);
    final rows = await (await db.database).query(
      'daily_performance_cache',
      where: 'date >= ? AND date <= ?',
      whereArgs: [s.toIso8601String(), e.toIso8601String()],
      orderBy: 'date ASC',
    );
    return rows.map(DailyPerformance.fromRow).toList();
  }

  Future<List<DailyPerformance>> all({int cutoffHour = 3}) async {
    final rows = await (await db.database).query('daily_performance_cache');
    return rows.map(DailyPerformance.fromRow).toList();
  }
}

class StreakRepo {
  final AppDatabase db;
  StreakRepo(this.db);

  Future<List<StreakRecord>> all() async {
    final rows = await (await db.database).query('streaks');
    return rows.map(StreakRecord.fromRow).toList();
  }

  Future<StreakRecord?> byId(String id) async {
    final rows = await (await db.database).query(
      'streaks',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return StreakRecord.fromRow(rows.first);
  }

  Future<void> upsert(StreakRecord s) async {
    await (await db.database).insert(
      'streaks',
      s.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

class StreaksNotifier extends AsyncNotifier<List<StreakRecord>> {
  @override
  Future<List<StreakRecord>> build() async {
    final now = ref.watch(activityClockProvider).valueOrNull ?? DateTime.now();
    final activity = await ref.watch(activityProvider.future);
    return activity.streaks(now);
  }

  Future<void> refresh() async {
    state = AsyncData(
      (await ref.read(activityProvider.future)).streaks(DateTime.now()),
    );
  }
}

class AchievementRepo {
  final AppDatabase db;
  AchievementRepo(this.db);

  Future<List<EarnedAchievement>> all() async {
    final rows = await (await db.database).query(
      'user_achievements',
      orderBy: 'earned_at DESC',
    );
    return rows.map(EarnedAchievement.fromRow).toList();
  }

  Future<bool> has(String id) async {
    final rows = await (await db.database).query(
      'user_achievements',
      where: 'achievement_id = ?',
      whereArgs: [id],
    );
    return rows.isNotEmpty;
  }

  Future<void> award(String id, DateTime at) async {
    await (await db.database).insert('user_achievements', {
      'achievement_id': id,
      'earned_at': at.toIso8601String(),
    });
  }
}

class EarnedAchievementsNotifier
    extends AsyncNotifier<List<EarnedAchievement>> {
  @override
  Future<List<EarnedAchievement>> build() async {
    final repo = ref.watch(achievementRepoProvider);
    return repo.all();
  }

  Future<void> refresh() async {
    final repo = ref.read(achievementRepoProvider);
    state = AsyncData(await repo.all());
  }
}
