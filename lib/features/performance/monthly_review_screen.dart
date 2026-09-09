import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/financial_day.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/section_card.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../providers.dart';

/// Read-only deep dive for one month. Aggregates:
///  - savings performance (income / expenses / saved / rate)
///  - goal performance (started / completed / progress gained)
///  - spending analysis (highest / lowest / most improved category)
///  - behavioral insights (auto-generated)
class MonthlyReviewScreen extends ConsumerWidget {
  final DateTime month;
  const MonthlyReviewScreen({super.key, required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheAsync = ref.watch(
        dailyCacheForMonthProvider((month: month, cutoffHour: 3)));
    final txsAsync = ref.watch(transactionsProvider);
    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(D.monthYear(month))),
      body: cacheAsync.when(
        data: (days) {
          final income = days.fold<double>(0, (a, d) => a + d.income);
          final expenses = days.fold<double>(0, (a, d) => a + d.expenses);
          final saved = income - expenses;
          final rate = income > 0 ? (saved / income) * 100 : 0.0;
          final lastMonthStart = DateTime(month.year, month.month - 1, 1);
          return txsAsync.when(
            data: (txs) {
              return goalsAsync.when(
                data: (goals) {
                  // Txs in this month
                  final start = FinancialDay.startOfMonth(month);
                  final end = FinancialDay.endOfMonth(month);
                  final monthTxs = txs
                      .where((t) =>
                          !t.occurredAt.isBefore(start) &&
                          !t.occurredAt.isAfter(end))
                      .toList();
                  // Spending by category
                  final byCat = <String, double>{};
                  for (final t in monthTxs) {
                    if (t.type != TxType.expense) continue;
                    byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
                  }
                  // Most improved vs last month
                  final lastStart = FinancialDay.startOfMonth(lastMonthStart);
                  final lastEnd = FinancialDay.endOfMonth(lastMonthStart);
                  final lastTxs = txs
                      .where((t) =>
                          !t.occurredAt.isBefore(lastStart) &&
                          !t.occurredAt.isAfter(lastEnd))
                      .toList();
                  final lastByCat = <String, double>{};
                  for (final t in lastTxs) {
                    if (t.type != TxType.expense) continue;
                    lastByCat[t.category] =
                        (lastByCat[t.category] ?? 0) + t.amount;
                  }
                  String? mostImproved;
                  double bestDelta = 0;
                  for (final c in byCat.keys.toList() + lastByCat.keys.toList()) {
                    final diff = (byCat[c] ?? 0) - (lastByCat[c] ?? 0);
                    if (diff < bestDelta) {
                      bestDelta = diff;
                      mostImproved = c;
                    }
                  }
                  // Goals started/completed in month
                  final started = goals
                      .where((g) =>
                          g.startedAt.year == month.year &&
                          g.startedAt.month == month.month)
                      .length;
                  final completed = goals
                      .where((g) =>
                          g.completedAt != null &&
                          g.completedAt!.year == month.year &&
                          g.completedAt!.month == month.month)
                      .length;

                  final highestEntry = byCat.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  final lowestEntry = byCat.entries
                      .where((e) => e.value > 0)
                      .toList()
                    ..sort((a, b) => a.value.compareTo(b.value));

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Savings performance
                      SectionCard(
                        title: 'Savings Performance',
                        child: Column(
                          children: [
                            _Row(label: 'Income', value: Money.format(income), valueColor: AppColors.primary),
                            _Row(label: 'Expenses', value: Money.format(expenses), valueColor: AppColors.error),
                            const Divider(height: 16),
                            _Row(label: 'Saved', value: Money.format(saved), valueColor: AppColors.primary, bold: true),
                            _Row(label: 'Savings rate', value: '${rate.toStringAsFixed(1)}%'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Goals
                      SectionCard(
                        title: 'Goal Performance',
                        child: Column(
                          children: [
                            _Row(label: 'Goals started', value: '$started'),
                            _Row(
                              label: 'Goals completed',
                              value: '$completed',
                              valueColor: completed > 0
                                  ? AppColors.primary
                                  : AppColors.onSurface,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Spending
                      if (byCat.isNotEmpty)
                        SectionCard(
                          title: 'Spending Analysis',
                          child: Column(
                            children: [
                              if (highestEntry.isNotEmpty)
                                _Row(
                                  label: 'Highest category',
                                  value: Money.format(highestEntry.first.value),
                                  sublabel: highestEntry.first.key,
                                ),
                              if (lowestEntry.isNotEmpty)
                                _Row(
                                  label: 'Lowest category',
                                  value: Money.format(lowestEntry.first.value),
                                  sublabel: lowestEntry.first.key,
                                ),
                              if (mostImproved != null)
                                _Row(
                                  label: 'Most improved',
                                  value: Money.format(bestDelta.abs()),
                                  sublabel: mostImproved,
                                  valueColor: AppColors.primary,
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      // Insights
                      SectionCard(
                        title: 'Behavioral Insights',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _insights(
                            income: income,
                            expenses: expenses,
                            saved: saved,
                            rate: rate,
                            byCat: byCat,
                            lastByCat: lastByCat,
                            goals: goals,
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  List<Widget> _insights({
    required double income,
    required double expenses,
    required double saved,
    required double rate,
    required Map<String, double> byCat,
    required Map<String, double> lastByCat,
    required List<GoalRecord> goals,
  }) {
    final insights = <Widget>[];
    if (saved > 0) {
      insights.add(_Insight(
        icon: Icons.savings,
        color: AppColors.primary,
        text: 'You saved ${Money.format(saved)} this month.',
      ));
    }
    if (byCat['food_dining'] != null &&
        lastByCat['food_dining'] != null &&
        (byCat['food_dining']! - lastByCat['food_dining']!).abs() >= 100) {
      final diff = byCat['food_dining']! - lastByCat['food_dining']!;
      insights.add(_Insight(
        icon: Icons.restaurant_menu,
        color: diff > 0 ? AppColors.error : AppColors.primary,
        text:
            'Food spending ${diff > 0 ? "increased" : "decreased"} ${Money.format(diff.abs())} vs last month.',
      ));
    }
    if (rate >= 20) {
      insights.add(_Insight(
        icon: Icons.trending_up,
        color: AppColors.primary,
        text: 'Strong ${rate.toStringAsFixed(0)}% savings rate this month.',
      ));
    } else if (rate < 10 && income > 0) {
      insights.add(_Insight(
        icon: Icons.warning_amber,
        color: AppColors.error,
        text:
            'Savings rate is ${rate.toStringAsFixed(0)}% — consider tightening expenses.',
      ));
    }
    if (insights.isEmpty) {
      insights.add(const _Insight(
        icon: Icons.info_outline,
        color: AppColors.onSurfaceVariant,
        text: 'Keep tracking — insights will appear as you log activity.',
      ));
    }
    return insights;
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String? sublabel;
  final String value;
  final Color? valueColor;
  final bool bold;
  const _Row({
    required this.label,
    this.sublabel,
    required this.value,
    this.valueColor,
    this.bold = false,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (sublabel != null)
                  Text(
                    sublabel!,
                    style: const TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.onSurface,
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Insight extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Insight({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}