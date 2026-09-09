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
    state = const AsyncLoading();
    final repo = ref.read(settingsRepoProvider);
    await repo.save(r);
    state = AsyncData(r);
  }
}

class AccountRepo {
  final AppDatabase db;
  AccountRepo(this.db);

  Future<List<AccountRecord>> all() async {
    final rows =
        await (await db.database).query('accounts', orderBy: 'sort_order, id');
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
    final row = Map<String, Object?>.from(r.toRow())..remove('id');
    return (await db.database).insert('accounts', row);
  }

  Future<void> update(AccountRecord r) async {
    await (await db.database).update(
      'accounts',
      r.toRow(),
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }

  Future<void> delete(int id) async {
    await (await db.database)
        .delete('accounts', where: 'id = ?', whereArgs: [id]);
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

  Future<void> edit(AccountRecord a) async {
    final repo = ref.read(accountRepoProvider);
    await repo.update(a);
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

  Future<List<TxRecord>> all({int limit = 500}) async {
    final rows = await (await db.database).query(
      'transactions',
      orderBy: 'occurred_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(TxRecord.fromRow).toList();
  }

  Future<TxRecord?> byId(int id) async {
    final rows = await (await db.database)
        .query('transactions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return TxRecord.fromRow(rows.first);
  }

  Future<int> insert(TxRecord tx) async {
    final row = Map<String, Object?>.from(tx.toRow())..remove('id');
    return (await db.database).insert('transactions', row);
  }

  Future<void> update(TxRecord tx) async {
    await (await db.database).update(
      'transactions',
      tx.toRow(),
      where: 'id = ?',
      whereArgs: [tx.id],
    );
  }

  Future<void> delete(int id) async {
    await (await db.database)
        .delete('transactions', where: 'id = ?', whereArgs: [id]);
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

  /// Audit-trail: append a revision before mutating a transaction.
  Future<void> writeRevision(int txId, TxRecord old, TxRecord new_) async {
    await (await db.database).insert('transaction_revisions', {
      'transaction_id': txId,
      'old_values': jsonEncode(old.toRow()),
      'new_values': jsonEncode(new_.toRow()),
      'changed_at': DateTime.now().toIso8601String(),
    });
  }
}

class TransactionsNotifier extends AsyncNotifier<List<TxRecord>> {
  @override
  Future<List<TxRecord>> build() async {
    final repo = ref.watch(transactionRepoProvider);
    return repo.all();
  }

  Future<void> refresh() async {
    final repo = ref.read(transactionRepoProvider);
    state = AsyncData(await repo.all());
  }

  Future<void> add(TxRecord tx) async {
    final repo = ref.read(transactionRepoProvider);
    await repo.insert(tx);
    await refresh();
    ref.invalidate(dailyCacheForMonthProvider);
    ref.invalidate(dailyCacheForDayProvider);
    ref.invalidate(streaksProvider);
    ref.invalidate(earnedAchievementsProvider);
  }

  Future<void> edit(TxRecord old, TxRecord new_) async {
    final repo = ref.read(transactionRepoProvider);
    if (old.id != null) {
      await repo.writeRevision(old.id!, old, new_);
    }
    await repo.update(new_);
    await refresh();
    ref.invalidate(dailyCacheForMonthProvider);
    ref.invalidate(dailyCacheForDayProvider);
    ref.invalidate(streaksProvider);
  }

  Future<void> remove(int id) async {
    final repo = ref.read(transactionRepoProvider);
    await repo.delete(id);
    await refresh();
    ref.invalidate(dailyCacheForMonthProvider);
    ref.invalidate(dailyCacheForDayProvider);
    ref.invalidate(streaksProvider);
  }
}

class GoalRepo {
  final AppDatabase db;
  GoalRepo(this.db);

  Future<List<GoalRecord>> all() async {
    final rows = await (await db.database)
        .query('goals', orderBy: 'sort_order, id');
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

  Future<int> insert(GoalRecord g) async {
    final row = Map<String, Object?>.from(g.toRow())..remove('id');
    return (await db.database).insert('goals', row);
  }

  Future<void> update(GoalRecord g) async {
    await (await db.database).update(
      'goals',
      g.toRow(),
      where: 'id = ?',
      whereArgs: [g.id],
    );
  }

  Future<void> delete(int id) async {
    await (await db.database).delete('goals', where: 'id = ?', whereArgs: [id]);
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

  Future<int> addContribution(GoalContribution c) async {
    final row = Map<String, Object?>.from(c.toRow())..remove('id');
    return (await db.database).insert('goal_contributions', row);
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
    await repo.addContribution(GoalContribution(
      goalId: g.id!,
      amount: amount,
      contributedAt: DateTime.now(),
      notes: notes,
    ));
    final newCurrent = g.currentAmount + amount;
    final completed = newCurrent >= g.targetAmount;
    await repo.update(g.copyWith(
      currentAmount: newCurrent,
      status: completed ? GoalStatus.completed : g.status,
      completedAt:
          completed && g.completedAt == null ? DateTime.now() : g.completedAt,
    ));
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
    await (await db.database)
        .delete('journal_entries', where: 'id = ?', whereArgs: [id]);
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

  Future<List<DailyPerformance>> forMonth(DateTime month,
      {int cutoffHour = 3}) async {
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
    final rows = await (await db.database)
        .query('streaks', where: 'id = ?', whereArgs: [id]);
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
    final repo = ref.watch(streakRepoProvider);
    return repo.all();
  }

  Future<void> refresh() async {
    final repo = ref.read(streakRepoProvider);
    state = AsyncData(await repo.all());
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