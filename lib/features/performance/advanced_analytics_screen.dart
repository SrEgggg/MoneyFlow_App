import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/utils/financial_day.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/section_card.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../providers.dart';

/// Advanced analytics: net worth growth, drawdown, category trends, cash flow.
/// Reachable from Performance → Calendar → Advanced Analytics.
class AdvancedAnalyticsScreen extends ConsumerWidget {
  const AdvancedAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Advanced Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _NetWorthCard(),
          SizedBox(height: 12),
          _DrawdownCard(),
          SizedBox(height: 12),
          _CategoryTrendsCard(),
          SizedBox(height: 12),
          _CashFlowCard(),
        ],
      ),
    );
  }
}

/// Range helper for the last N days of cache.
final _recentCacheProvider = FutureProvider.family
    .autoDispose<List<DailyPerformance>, int>((ref, days) async {
  final repo = ref.watch(cacheRepoProvider);
  final end = DateTime.now();
  final start = end.subtract(Duration(days: days));
  return repo.rangeInclusive(start, end, cutoffHour: 3);
});

class _NetWorthCard extends ConsumerWidget {
  const _NetWorthCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheAsync = ref.watch(_recentCacheProvider(90));
    return SectionCard(
      title: 'Net Worth Growth',
      subtitle: 'Last 90 days',
      child: SizedBox(
        height: 180,
        child: cacheAsync.when(
          data: (days) => _buildLine(days),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildLine(List<DailyPerformance> days) {
    if (days.isEmpty) {
      return const Center(
        child: Text('No data yet',
            style: TextStyle(color: AppColors.onSurfaceVariant)),
      );
    }
    final spots = <FlSpot>[];
    double running = 0;
    for (int i = 0; i < days.length; i++) {
      running += days[i].savedAmount;
      spots.add(FlSpot(i.toDouble(), running));
    }
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: AppColors.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawdownCard extends ConsumerWidget {
  const _DrawdownCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheAsync = ref.watch(_recentCacheProvider(90));
    return SectionCard(
      title: 'Drawdown Analysis',
      subtitle: 'Highest vs current cumulative savings',
      child: cacheAsync.when(
        data: (days) {
          if (days.isEmpty) {
            return const Text('No data',
                style: TextStyle(color: AppColors.onSurfaceVariant));
          }
          double running = 0;
          double peak = 0;
          for (final d in days) {
            running += d.savedAmount;
            if (running > peak) peak = running;
          }
          final diff = peak - running;
          return Row(
            children: [
              _DrawdownStat(label: 'Peak', value: Money.format(peak)),
              const SizedBox(width: 12),
              _DrawdownStat(
                  label: 'Current', value: Money.format(running)),
              const SizedBox(width: 12),
              _DrawdownStat(
                label: 'Drawdown',
                value: Money.format(diff),
                color: diff > 0 ? AppColors.error : AppColors.primary,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _DrawdownStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _DrawdownStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                )),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                  color: color ?? AppColors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
    );
  }
}

class _CategoryTrendsCard extends ConsumerWidget {
  const _CategoryTrendsCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(transactionsProvider);
    return SectionCard(
      title: 'Category Trends',
      subtitle: 'This month vs last month',
      child: txsAsync.when(
        data: (txs) => _build(txs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _build(List<TxRecord> txs) {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

    double sumThis(Set<String> ids) {
      return txs
          .where((t) =>
              t.type == TxType.expense &&
              ids.contains(t.category) &&
              FinancialDay.key(t.occurredAt).isAfter(
                  thisMonthStart.subtract(const Duration(days: 1))))
          .where((t) => FinancialDay.key(t.occurredAt).isBefore(
              DateTime(now.year, now.month + 1, 1)))
          .fold<double>(0, (a, t) => a + t.amount);
    }

    double sumLast(Set<String> ids) {
      return txs
          .where((t) =>
              t.type == TxType.expense &&
              ids.contains(t.category) &&
              FinancialDay.key(t.occurredAt)
                  .isAfter(lastMonthStart.subtract(const Duration(days: 1))))
          .where((t) =>
              FinancialDay.key(t.occurredAt).isBefore(thisMonthStart))
          .fold<double>(0, (a, t) => a + t.amount);
    }

    final groups = <String, Set<String>>{
      'Food': {'food_dining'},
      'Transport': {'transportation'},
      'Shopping': {'shopping'},
      'Bills': {'bills'},
    };

    return Column(
      children: [
        for (final entry in groups.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 88,
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: _BarRow(thisVal: sumThis(entry.value), lastVal: sumLast(entry.value))),
              ],
            ),
          ),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  final double thisVal;
  final double lastVal;
  const _BarRow({required this.thisVal, required this.lastVal});

  @override
  Widget build(BuildContext context) {
    final maxV = (thisVal > lastVal ? thisVal : lastVal);
    final denom = maxV == 0 ? 1.0 : maxV;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bar('This', thisVal / denom, Money.format(thisVal), AppColors.primary),
        const SizedBox(height: 4),
        _bar('Last', lastVal / denom, Money.format(lastVal),
            AppColors.onSurfaceVariant),
      ],
    );
  }

  Widget _bar(String label, double fraction, String value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(label,
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              )),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CashFlowCard extends ConsumerWidget {
  const _CashFlowCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheAsync = ref.watch(_recentCacheProvider(30));
    return SectionCard(
      title: 'Cash Flow',
      subtitle: 'Income / Expense / Saved (last 30d)',
      child: SizedBox(
        height: 180,
        child: cacheAsync.when(
          data: (days) {
            double income = 0, expenses = 0;
            for (final d in days) {
              income += d.income;
              expenses += d.expenses;
            }
            final saved = income - expenses;
            final maxV = [income, expenses, saved.abs()]
                .fold<double>(0, (a, b) => a > b ? a : b);
            final denom = maxV == 0 ? 1.0 : maxV;
            return BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: denom * 1.2,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [
                    BarChartRodData(
                        toY: income / denom,
                        color: AppColors.primary,
                        width: 28,
                        borderRadius: BorderRadius.circular(6))
                  ]),
                  BarChartGroupData(x: 1, barRods: [
                    BarChartRodData(
                        toY: expenses / denom,
                        color: AppColors.error,
                        width: 28,
                        borderRadius: BorderRadius.circular(6))
                  ]),
                  BarChartGroupData(x: 2, barRods: [
                    BarChartRodData(
                        toY: saved.abs() / denom,
                        color: saved >= 0
                            ? AppColors.primary
                            : AppColors.error,
                        width: 28,
                        borderRadius: BorderRadius.circular(6))
                  ]),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

