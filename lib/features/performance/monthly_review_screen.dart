import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final cutoff = ref.watch(settingsProvider).valueOrNull?.cutoffHour ?? 3;
    final cacheAsync = ref.watch(
      dailyCacheForMonthProvider((month: month, cutoffHour: cutoff)),
    );
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
                  final start = FinancialDay.startOfMonth(
                    month,
                    cutoffHour: cutoff,
                  );
                  final end = FinancialDay.endOfMonth(
                    month,
                    cutoffHour: cutoff,
                  );
                  final monthTxs = txs
                      .where(
                        (t) =>
                            !t.occurredAt.isBefore(start) &&
                            !t.occurredAt.isAfter(end),
                      )
                      .toList();
                  // Spending by category
                  final byCat = <String, double>{};
                  for (final t in monthTxs) {
                    if (t.type != TxType.expense) continue;
                    byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
                  }
                  // Most improved vs last month
                  final lastStart = FinancialDay.startOfMonth(
                    lastMonthStart,
                    cutoffHour: cutoff,
                  );
                  final lastEnd = FinancialDay.endOfMonth(
                    lastMonthStart,
                    cutoffHour: cutoff,
                  );
                  final lastTxs = txs
                      .where(
                        (t) =>
                            !t.occurredAt.isBefore(lastStart) &&
                            !t.occurredAt.isAfter(lastEnd),
                      )
                      .toList();
                  final lastByCat = <String, double>{};
                  for (final t in lastTxs) {
                    if (t.type != TxType.expense) continue;
                    lastByCat[t.category] =
                        (lastByCat[t.category] ?? 0) + t.amount;
                  }
                  String? mostImproved;
                  double bestDelta = 0;
                  for (final c
                      in byCat.keys.toList() + lastByCat.keys.toList()) {
                    final diff = (byCat[c] ?? 0) - (lastByCat[c] ?? 0);
                    if (diff < bestDelta) {
                      bestDelta = diff;
                      mostImproved = c;
                    }
                  }
                  // Goals started/completed in month
                  final started = goals
                      .where(
                        (g) =>
                            g.startedAt.year == month.year &&
                            g.startedAt.month == month.month,
                      )
                      .length;
                  final completed = goals
                      .where(
                        (g) =>
                            g.completedAt != null &&
                            g.completedAt!.year == month.year &&
                            g.completedAt!.month == month.month,
                      )
                      .length;

                  final highestEntry = byCat.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  final lowestEntry =
                      byCat.entries.where((e) => e.value > 0).toList()
                        ..sort((a, b) => a.value.compareTo(b.value));

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Savings performance
                      SectionCard(
                        title: 'Savings Performance',
                        child: Column(
                          children: [
                            _Row(
                              label: 'Income',
                              value: Money.of(context).format(income),
                              valueColor: Theme.of(context).colorScheme.primary,
                            ),
                            _Row(
                              label: 'Expenses',
                              value: Money.of(context).format(expenses),
                              valueColor: Theme.of(context).colorScheme.error,
                            ),
                            const Divider(height: 16),
                            _Row(
                              label: 'Net cash flow',
                              value: Money.of(context).format(saved),
                              valueColor: Theme.of(context).colorScheme.primary,
                              bold: true,
                            ),
                            _Row(
                              label: 'Income retained',
                              value: '${rate.toStringAsFixed(1)}%',
                            ),
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
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
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
                                  value: Money.of(
                                    context,
                                  ).format(highestEntry.first.value),
                                  sublabel: highestEntry.first.key,
                                ),
                              if (lowestEntry.isNotEmpty)
                                _Row(
                                  label: 'Lowest category',
                                  value: Money.of(
                                    context,
                                  ).format(lowestEntry.first.value),
                                  sublabel: lowestEntry.first.key,
                                ),
                              if (mostImproved != null)
                                _Row(
                                  label: 'Most improved',
                                  value: Money.of(
                                    context,
                                  ).format(bestDelta.abs()),
                                  sublabel: mostImproved,
                                  valueColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
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
                            context,
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
                loading: () => const Center(child: CircularProgressIndicator()),
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

  List<Widget> _insights(
    BuildContext context, {
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
      insights.add(
        _Insight(
          icon: Icons.savings,
          color: Theme.of(context).colorScheme.primary,
          text: 'You saved ${Money.of(context).format(saved)} this month.',
        ),
      );
    }
    if (byCat['food_dining'] != null &&
        lastByCat['food_dining'] != null &&
        (byCat['food_dining']! - lastByCat['food_dining']!).abs() >= 100) {
      final diff = byCat['food_dining']! - lastByCat['food_dining']!;
      insights.add(
        _Insight(
          icon: Icons.restaurant_menu,
          color: diff > 0
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
          text:
              'Food spending ${diff > 0 ? "increased" : "decreased"} ${Money.of(context).format(diff.abs())} vs last month.',
        ),
      );
    }
    if (rate >= 20) {
      insights.add(
        _Insight(
          icon: Icons.trending_up,
          color: Theme.of(context).colorScheme.primary,
          text: 'Strong ${rate.toStringAsFixed(0)}% savings rate this month.',
        ),
      );
    } else if (rate < 10 && income > 0) {
      insights.add(
        _Insight(
          icon: Icons.warning_amber,
          color: Theme.of(context).colorScheme.error,
          text:
              'Income retained is ${rate.toStringAsFixed(0)}% — consider tightening expenses.',
        ),
      );
    }
    if (insights.isEmpty) {
      insights.add(
        _Insight(
          icon: Icons.info_outline,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          text: 'Keep tracking — insights will appear as you log activity.',
        ),
      );
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
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (sublabel != null)
                  Text(
                    sublabel!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
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
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
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
