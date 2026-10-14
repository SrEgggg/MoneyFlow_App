import '../../core/constants/categories.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      ref.watch(transactionsProvider);
      final cutoff = ref.watch(settingsProvider).valueOrNull?.cutoffHour ?? 3;
      final repo = ref.watch(cacheRepoProvider);
      final end = DateTime.now();
      final start = end.subtract(Duration(days: days));
      return repo.rangeInclusive(start, end, cutoffHour: cutoff);
    });

class _NetWorthCard extends ConsumerWidget {
  const _NetWorthCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheAsync = ref.watch(_recentCacheProvider(90));
    return SectionCard(
      title: 'Cumulative cash flow',
      subtitle: 'Last 90 days',
      child: SizedBox(
        height: 180,
        child: cacheAsync.when(
          data: (days) => _buildLine(context, days),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildLine(BuildContext context, List<DailyPerformance> days) {
    if (days.length < 2) {
      return Center(
        child: Text(
          'Record activity on two dates to see a trend.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
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
            isCurved: false,
            curveSmoothness: 0.25,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.18),
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
      title: 'Cash flow decline',
      subtitle: 'Peak vs current cash flow · last 90 days',
      child: cacheAsync.when(
        data: (days) {
          if (days.isEmpty) {
            return Text(
              'No data',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            );
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
              _DrawdownStat(
                label: 'Peak',
                value: Money.of(context).format(peak),
              ),
              const SizedBox(width: 12),
              _DrawdownStat(
                label: 'Current',
                value: Money.of(context).format(running),
              ),
              const SizedBox(width: 12),
              _DrawdownStat(
                label: 'Drawdown',
                value: Money.of(context).format(diff),
                color: diff > 0
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
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
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color ?? Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
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
        data: (txs) => _build(context, txs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _build(BuildContext context, List<TxRecord> txs) {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

    double sumThis(Set<String> ids) {
      return txs
          .where(
            (t) =>
                t.type == TxType.expense &&
                ids.contains(t.category) &&
                FinancialDay.key(
                  t.occurredAt,
                ).isAfter(thisMonthStart.subtract(const Duration(days: 1))),
          )
          .where(
            (t) => FinancialDay.key(
              t.occurredAt,
            ).isBefore(DateTime(now.year, now.month + 1, 1)),
          )
          .fold<double>(0, (a, t) => a + t.amount);
    }

    double sumLast(Set<String> ids) {
      return txs
          .where(
            (t) =>
                t.type == TxType.expense &&
                ids.contains(t.category) &&
                FinancialDay.key(
                  t.occurredAt,
                ).isAfter(lastMonthStart.subtract(const Duration(days: 1))),
          )
          .where((t) => FinancialDay.key(t.occurredAt).isBefore(thisMonthStart))
          .fold<double>(0, (a, t) => a + t.amount);
    }

    final ids = txs
        .where((t) => t.type == TxType.expense)
        .map((t) => t.category)
        .toSet();
    final groups = <String, Set<String>>{
      for (final id in ids)
        if (sumThis({id}) > 0 || sumLast({id}) > 0)
          Categories.resolve(context, id).name: {id},
    };
    if (groups.isEmpty) {
      return const Text('No expenses this month or last month.');
    }

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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: _BarRow(
                    thisVal: sumThis(entry.value),
                    lastVal: sumLast(entry.value),
                  ),
                ),
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
        _bar(
          context,
          'This',
          thisVal / denom,
          Money.of(context).format(thisVal),
          Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 4),
        _bar(
          context,
          'Last',
          lastVal / denom,
          Money.of(context).format(lastVal),
          Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }

  Widget _bar(
    BuildContext context,
    String label,
    double fraction,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
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
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
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
            final maxV = [
              income,
              expenses,
              saved.abs(),
            ].fold<double>(0, (a, b) => a > b ? a : b);
            final denom = maxV == 0 ? 1.0 : maxV;
            return BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: denom * 1.2,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: income / denom,
                        color: Theme.of(context).colorScheme.primary,
                        width: 28,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: expenses / denom,
                        color: Theme.of(context).colorScheme.error,
                        width: 28,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [
                      BarChartRodData(
                        toY: saved.abs() / denom,
                        color: saved >= 0
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                        width: 28,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
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
