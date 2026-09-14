import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/financial_day.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../../../providers.dart';

/// Aggregated home-screen data: hero number, monthly progress, savings rate,
/// goals, recent insights. Built as a single object so the UI can `watch` it
/// in one go.
class HomeSummary {
  final double totalSavings; // sum of all account balances
  final double lastMonthSavings; // for delta %
  final double monthlyIncome;
  final double monthlyExpenses;
  final double monthlySaved;
  final double monthlyGoal; // user's mental target — derived from average saved
  final double savingsRate; // 0..1
  final List<GoalRecord> activeGoals;
  final List<SmartInsight> insights;
  final int savingStreak;
  final int loggingStreak;
  final double netWorthChangePercent;

  const HomeSummary({
    required this.totalSavings,
    required this.lastMonthSavings,
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.monthlySaved,
    required this.monthlyGoal,
    required this.savingsRate,
    required this.activeGoals,
    required this.insights,
    required this.savingStreak,
    required this.loggingStreak,
    required this.netWorthChangePercent,
  });
}

/// One smart insight card.
class SmartInsight {
  final String id;
  final String message;
  final IconData icon;
  final Color color;
  SmartInsight({
    required this.id,
    required this.message,
    required this.icon,
    required this.color,
  });
}

class SmartInsightsRuleEngine {
  SmartInsightsRuleEngine._();

  /// Build insights from transactions, goals, and streaks.
  static List<SmartInsight> build({
    required List<TxRecord> txs,
    required List<DailyPerformance> thisMonthCache,
    required List<DailyPerformance> lastMonthCache,
    required List<GoalRecord> activeGoals,
    required int savingStreak,
    required int loggingStreak,
    required double avgMonthlySavings,
  }) {
    final insights = <SmartInsight>[];

    // 1. Savings up/down vs last month
    final thisMonthSaved = thisMonthCache.fold<double>(
      0,
      (a, d) => a + d.savedAmount,
    );
    final lastMonthSaved = lastMonthCache.fold<double>(
      0,
      (a, d) => a + d.savedAmount,
    );
    if (lastMonthSaved > 0) {
      final pct = ((thisMonthSaved - lastMonthSaved) / lastMonthSaved) * 100;
      if (pct >= 1) {
        insights.add(
          SmartInsight(
            id: 'savings_up',
            message: 'You saved ${pct.toStringAsFixed(0)}% more this month.',
            icon: Icons.trending_up,
            color: const Color(0xFF22C55E),
          ),
        );
      } else if (pct <= -1) {
        insights.add(
          SmartInsight(
            id: 'savings_down',
            message:
                'You saved ${pct.abs().toStringAsFixed(0)}% less this month.',
            icon: Icons.trending_down,
            color: const Color(0xFFEF4444),
          ),
        );
      }
    }

    // 2. Food spending change
    final thisFood = _sumForCategory(txs, 'food_dining', thisMonthCache);
    final lastFood = _sumForCategory(txs, 'food_dining', lastMonthCache);
    if (lastFood > 0) {
      final diff = thisFood - lastFood;
      if (diff.abs() >= 100) {
        final verb = diff > 0 ? 'increased' : 'decreased';
        insights.add(
          SmartInsight(
            id: 'food_change',
            message: 'Food spending $verb ${_peso(diff.abs().round())}.',
            icon: Icons.restaurant_menu,
            color: diff > 0 ? const Color(0xFFF97316) : const Color(0xFF22C55E),
          ),
        );
      }
    }

    // 3. Goal ETA
    if (avgMonthlySavings > 0) {
      for (final g in activeGoals.take(2)) {
        if (g.status != GoalStatus.active) continue;
        final remaining = g.targetAmount - g.currentAmount;
        if (remaining <= 0) continue;
        final months = (remaining / avgMonthlySavings).ceil();
        if (months <= 24) {
          insights.add(
            SmartInsight(
              id: 'goal_eta_${g.id}',
              message:
                  "You're projected to reach '${g.name}' in $months ${months == 1 ? "month" : "months"}.",
              icon: g.kind.icon,
              color: g.kind.color,
            ),
          );
        }
      }
    }

    // 4. Streak at risk
    if (loggingStreak > 0) {
      final lastTxDay = txs.isEmpty
          ? null
          : FinancialDay.key(txs.first.occurredAt);
      if (lastTxDay != null) {
        final diff = FinancialDay.today().difference(lastTxDay).inDays;
        if (diff >= 1) {
          insights.add(
            SmartInsight(
              id: 'streak_at_risk',
              message:
                  'Record any real activity today. No spending is needed to keep track.',
              icon: Icons.local_fire_department,
              color: const Color(0xFFEF4444),
            ),
          );
        } else {
          insights.add(
            SmartInsight(
              id: 'streak_active',
              message:
                  "🔥 $loggingStreak-day logging streak — keep it going today!",
              icon: Icons.local_fire_department,
              color: const Color(0xFFF97316),
            ),
          );
        }
      }
    }

    // Limit to 3 insights to keep the card clean.
    return insights.take(3).toList();
  }

  static double _sumForCategory(
    List<TxRecord> txs,
    String category,
    List<DailyPerformance> cacheDays,
  ) {
    if (cacheDays.isEmpty) return 0;
    final dayKeys = cacheDays.map((d) => d.date).toSet();
    double total = 0;
    for (final t in txs) {
      if (t.category != category) continue;
      if (t.type != TxType.expense) continue;
      if (dayKeys.contains(FinancialDay.key(t.occurredAt))) {
        total += t.amount;
      }
    }
    return total;
  }

  static String _peso(int v) {
    final s = v.toString();
    if (s.length <= 3) return '₱$s';
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '₱$buf';
  }
}

/// The main Home data provider.
final homeSummaryProvider = FutureProvider<HomeSummary>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final cutoffHour = (await ref.watch(settingsProvider.future)).cutoffHour;

  final cacheRepo = CacheRepo(db);

  final accounts = await ref.watch(accountsProvider.future);
  final allTx = await ref.watch(transactionsProvider.future);
  final goals = (await ref.watch(
    goalsProvider.future,
  )).where((g) => g.status == GoalStatus.active).toList();
  final streaks = await ref.watch(streaksProvider.future);

  // Compute current month range
  final now = FinancialDay.today(cutoffHour: cutoffHour);
  final thisMonthStart = DateTime(now.year, now.month, 1, cutoffHour);
  final thisMonthEnd = DateTime(
    now.year,
    now.month + 1,
    1,
  ).subtract(const Duration(days: 1));
  final lastMonthStart = DateTime(now.year, now.month - 1, 1, cutoffHour);
  final lastMonthEnd = thisMonthStart.subtract(const Duration(days: 1));

  final thisMonthCache = await cacheRepo.rangeInclusive(
    thisMonthStart,
    thisMonthEnd,
    cutoffHour: cutoffHour,
  );
  final lastMonthCache = await cacheRepo.rangeInclusive(
    lastMonthStart,
    lastMonthEnd,
    cutoffHour: cutoffHour,
  );

  // Last 90 days for forecasting
  final ninetyStart = now.subtract(const Duration(days: 90));
  final recentCache = await cacheRepo.rangeInclusive(
    ninetyStart,
    now,
    cutoffHour: cutoffHour,
  );
  final recentSaved = recentCache.fold<double>(0, (a, d) => a + d.savedAmount);
  final avgMonthlySavings = recentSaved / 3.0;

  // Calendar and dashboard share actual records and local calendar dates.
  final activity = await ref.watch(activityProvider.future);
  final calendarNow = DateTime.now();
  final monthActivity = activity.between(
    DateTime(calendarNow.year, calendarNow.month),
    DateTime(calendarNow.year, calendarNow.month + 1),
  );
  // Monthly numbers
  final monthlyIncome = monthActivity.income;
  final monthlyExpenses = monthActivity.expenses;
  final monthlySaved = monthActivity.saved;
  final plannedSavings = goals.fold<double>(
    0,
    (sum, goal) => sum + (goal.monthlyTarget ?? 0),
  );
  final double monthlyGoal = plannedSavings;

  final savingsRate = monthlyIncome > 0
      ? ((monthlyIncome - monthlyExpenses) / monthlyIncome)
      : 0.0;

  // Net worth change vs last month (use balances of accounts - all-time saved
  // approximation). For simplicity, use lastMonthSaved as a proxy.
  final lastMonthSaved = lastMonthCache.fold<double>(
    0,
    (a, d) => a + d.savedAmount,
  );
  final thisMonthSaved = thisMonthCache.fold<double>(
    0,
    (a, d) => a + d.savedAmount,
  );
  final netWorthChangePercent = lastMonthSaved > 0
      ? ((thisMonthSaved - lastMonthSaved) / lastMonthSaved) * 100
      : 0.0;

  // Total savings across all accounts
  final totalSavings = accounts.fold<double>(0, (a, acc) => a + acc.balance);

  // Streaks
  final savingStreak = streaks
      .firstWhere(
        (s) => s.id == StreakKind.saving.id,
        orElse: () =>
            const StreakRecord(id: 'saving', currentCount: 0, bestCount: 0),
      )
      .currentCount;
  final loggingStreak = streaks
      .firstWhere(
        (s) => s.id == StreakKind.logging.id,
        orElse: () =>
            const StreakRecord(id: 'logging', currentCount: 0, bestCount: 0),
      )
      .currentCount;

  final insights = SmartInsightsRuleEngine.build(
    txs: allTx,
    thisMonthCache: thisMonthCache,
    lastMonthCache: lastMonthCache,
    activeGoals: goals,
    savingStreak: savingStreak,
    loggingStreak: loggingStreak,
    avgMonthlySavings: avgMonthlySavings,
  );

  return HomeSummary(
    totalSavings: totalSavings,
    lastMonthSavings: lastMonthSaved,
    monthlyIncome: monthlyIncome,
    monthlyExpenses: monthlyExpenses,
    monthlySaved: monthlySaved,
    monthlyGoal: monthlyGoal,
    savingsRate: savingsRate,
    activeGoals: goals,
    insights: insights,
    savingStreak: savingStreak,
    loggingStreak: loggingStreak,
    netWorthChangePercent: netWorthChangePercent,
  );
});
