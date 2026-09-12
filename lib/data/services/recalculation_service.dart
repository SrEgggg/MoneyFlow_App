import 'dart:math' as math;

import '../../core/utils/financial_day.dart';
import '../models/enums.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';

/// Recomputes the daily performance cache, streaks, achievements, and goals
/// from raw transactions.
///
/// Called after every transaction write or delete. Designed so it can be
/// invoked from anywhere — providers, settings, seed.
class RecalculationService {
  final TransactionRepo tx;
  final CacheRepo cache;
  final StreakRepo streaks;
  final GoalRepo goals;
  final AchievementRepo achievements;
  final AccountRepo accounts;

  RecalculationService({
    required this.tx,
    required this.cache,
    required this.streaks,
    required this.goals,
    required this.achievements,
    required this.accounts,
  });

  /// Full recompute from [from] to today (inclusive).
  Future<void> recomputeFrom(DateTime from, {int cutoffHour = 3}) async {
    final today = FinancialDay.today(cutoffHour: cutoffHour);
    final padStart = from.subtract(const Duration(hours: 6));
    final padEnd = today.add(const Duration(days: 1));
    final txs = await tx.range(padStart, padEnd);

    final byDay = <DateTime, _DayBucket>{};
    for (final t in txs) {
      final k = FinancialDay.key(t.occurredAt, cutoffHour: cutoffHour);
      if (k.isBefore(FinancialDay.key(from, cutoffHour: cutoffHour))) continue;
      if (k.isAfter(today)) continue;
      final bucket = byDay.putIfAbsent(k, () => _DayBucket(k));
      if (t.type == TxType.income) {
        bucket.income += t.amount;
      } else {
        bucket.expenses += t.amount;
      }
    }

    await (await cache.db.database).delete(
      'daily_performance_cache',
      where: 'date >= ?',
      whereArgs: [
        FinancialDay.key(from, cutoffHour: cutoffHour).toIso8601String(),
      ],
    );
    final allowance = await _computeAllowance(cutoffHour: cutoffHour);

    for (final entry in byDay.entries) {
      final k = entry.key;
      final b = entry.value;
      final saved = b.income - b.expenses;
      final status = _scoreStatus(
        income: b.income,
        expenses: b.expenses,
        allowance: allowance,
      );
      await cache.upsert(
        DailyPerformance(
          date: DateTime(k.year, k.month, k.day),
          income: b.income,
          expenses: b.expenses,
          savedAmount: saved,
          allowance: allowance,
          status: status,
          computedAt: DateTime.now(),
        ),
      );
    }

    await _updateStreaks(cutoffHour: cutoffHour);
    await _evaluateAchievements();
  }

  Future<void> recomputeAll({int cutoffHour = 3}) async {
    final today = FinancialDay.today(cutoffHour: cutoffHour);
    final all = await tx.all();
    final earliest = all.isEmpty
        ? today
        : all.map((t) => t.occurredAt).reduce((a, b) => a.isBefore(b) ? a : b);
    await (await cache.db.database).delete('daily_performance_cache');
    await recomputeFrom(earliest, cutoffHour: cutoffHour);
  }

  Future<double> _computeAllowance({int cutoffHour = 3}) async {
    final today = FinancialDay.today(cutoffHour: cutoffHour);
    final start = today.subtract(const Duration(days: 30));
    final txs = await tx.range(start, today.add(const Duration(days: 1)));
    final expensesByDay = <DateTime, double>{};
    for (final t in txs) {
      if (t.type != TxType.expense) continue;
      final k = FinancialDay.key(t.occurredAt, cutoffHour: cutoffHour);
      expensesByDay[k] = (expensesByDay[k] ?? 0) + t.amount;
    }
    if (expensesByDay.isEmpty) return 0;
    final total = expensesByDay.values.fold<double>(0, (a, b) => a + b);
    return total / expensesByDay.length;
  }

  String _scoreStatus({
    required double income,
    required double expenses,
    required double allowance,
  }) {
    final saved = income - expenses;
    if (allowance <= 0) {
      if (saved > 0) return 'green';
      if (saved < 0) return 'red';
      return 'yellow';
    }
    final overspendRatio = (expenses - allowance) / allowance;
    if (saved > 0 && expenses <= allowance * 0.5) return 'dark_green';
    if (saved > 0) return 'green';
    if (saved.abs() < allowance * 0.05) return 'yellow';
    if (overspendRatio > 0.5) return 'dark_red';
    return 'red';
  }

  Future<void> _updateStreaks({int cutoffHour = 3}) async {
    final days = await cache.all(cutoffHour: cutoffHour);
    if (days.isEmpty) return;

    days.sort((a, b) => a.date.compareTo(b.date));
    final today = FinancialDay.today(cutoffHour: cutoffHour);

    int savingCurrent = 0;
    int savingBest = 0;
    DateTime? savingLast;
    int savingRun = 0;
    for (final d in days) {
      if (d.savedAmount > 0) {
        savingRun++;
        if (savingRun > savingBest) savingBest = savingRun;
        savingLast = d.date;
      } else {
        savingRun = 0;
      }
    }
    if (savingRun > 0 && savingLast != null) {
      final diff = today.difference(savingLast).inDays;
      if (diff <= 1) savingCurrent = savingRun;
    }

    int loggingCurrent = 0;
    int loggingBest = 0;
    DateTime? loggingLast;
    int loggingRun = 0;
    for (final d in days) {
      if (d.income > 0 || d.expenses > 0) {
        loggingRun++;
        if (loggingRun > loggingBest) loggingBest = loggingRun;
        loggingLast = d.date;
      } else {
        loggingRun = 0;
      }
    }
    if (loggingRun > 0 && loggingLast != null) {
      final diff = today.difference(loggingLast).inDays;
      if (diff <= 1) loggingCurrent = loggingRun;
    }

    int goalCurrent = 0;
    int goalBest = 0;
    DateTime? goalLast;
    int goalRun = 0;
    for (final d in days.reversed) {
      final hasForDay = await _goalContributionOn(d.date);
      if (hasForDay) {
        goalRun++;
        if (goalRun > goalBest) goalBest = goalRun;
        goalLast = d.date;
      } else {
        goalRun = 0;
      }
    }
    if (goalRun > 0 && goalLast != null) {
      final diff = today.difference(goalLast).inDays;
      if (diff <= 1) goalCurrent = goalRun;
    }

    await streaks.upsert(
      StreakRecord(
        id: StreakKind.saving.id,
        currentCount: savingCurrent,
        bestCount: math.max(savingBest, savingCurrent),
        lastQualifiedDay: savingLast,
      ),
    );
    await streaks.upsert(
      StreakRecord(
        id: StreakKind.logging.id,
        currentCount: loggingCurrent,
        bestCount: math.max(loggingBest, loggingCurrent),
        lastQualifiedDay: loggingLast,
      ),
    );
    await streaks.upsert(
      StreakRecord(
        id: StreakKind.goal.id,
        currentCount: goalCurrent,
        bestCount: math.max(goalBest, goalCurrent),
        lastQualifiedDay: goalLast,
      ),
    );
  }

  Future<bool> _goalContributionOn(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final db = await (cache.db.database);
    final result = await db.query(
      'goal_contributions',
      where: 'contributed_at >= ? AND contributed_at < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> _evaluateAchievements() async {
    final days = await cache.all();
    final lifetimeSaved = days.fold<double>(0, (a, d) => a + d.savedAmount);
    final allGoals = await goals.all();
    final completedGoals = allGoals
        .where((g) => g.status == GoalStatus.completed)
        .length;
    final journalCount = await _journalCount();
    final streakList = await streaks.all();
    final savingStreak = streakList
        .firstWhere(
          (s) => s.id == StreakKind.saving.id,
          orElse: () =>
              const StreakRecord(id: 'saving', currentCount: 0, bestCount: 0),
        )
        .currentCount;
    final loggingStreak = streakList
        .firstWhere(
          (s) => s.id == StreakKind.logging.id,
          orElse: () =>
              const StreakRecord(id: 'logging', currentCount: 0, bestCount: 0),
        )
        .currentCount;
    final emergencyProgress =
        allGoals
            .where((g) => g.kind == GoalKind.emergency)
            .map((g) => g.progress)
            .fold<double>(0, (a, p) => a > p ? a : p) *
        100;

    final checks = <String, bool>{
      'first_1k': lifetimeSaved >= 1000,
      'first_5k': lifetimeSaved >= 5000,
      'first_10k': lifetimeSaved >= 10000,
      'lifetime_100k': lifetimeSaved >= 100000,
      'saving_streak_7': savingStreak >= 7,
      'saving_streak_30': savingStreak >= 30,
      'logging_streak_30': loggingStreak >= 30,
      'emergency_builder': emergencyProgress >= 50,
      'emergency_complete': emergencyProgress >= 100,
      'first_goal_done': completedGoals >= 1,
      'three_goals_done': completedGoals >= 3,
      'reflector': journalCount >= 10,
    };

    final now = DateTime.now();
    for (final entry in checks.entries) {
      if (entry.value && !(await achievements.has(entry.key))) {
        await achievements.award(entry.key, now);
      }
    }
  }

  Future<int> _journalCount() async {
    final db = await (cache.db.database);
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM journal_entries');
    return (rows.first['c'] as int?) ?? 0;
  }
}

class _DayBucket {
  final DateTime day;
  double income = 0;
  double expenses = 0;
  _DayBucket(this.day);
}
