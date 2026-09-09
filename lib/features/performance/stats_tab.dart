import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/constants/categories.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/section_card.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../providers.dart';

/// Stats tab: net worth trend, category trends, drawdown, cash flow.
class StatsTab extends ConsumerWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: const [
        _NetWorthChart(),
        SizedBox(height: 16),
        _CategoryTrendsChart(),
        SizedBox(height: 16),
        _DrawdownCard(),
        SizedBox(height: 16),
        _CashFlowCard(),
      ],
    );
  }
}

/// Net worth line: cumulative saved over the last 90 days.
class _NetWorthChart extends ConsumerWidget {
  const _NetWorthChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheAsync = ref.watch(_recentCacheProvider(90));
    return SectionCard(
      title: 'Net Worth Growth',
      child: SizedBox(
        height: 180,
        child: cacheAsync.when(
          data: (days) => _buildLine(days, _cumulativeSaved(days)),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  List<FlSpot> _cumulativeSaved(List<DailyPerformance> days) {
    final spots = <FlSpot>[];
    double running = 0;
    for (int i = 0; i < days.length; i++) {
      running += days[i].savedAmount;
      spots.add(FlSpot(i.toDouble(), running));
    }
    return spots;
  }

  Widget _buildLine(List<DailyPerformance> days, List<FlSpot> spots) {
    if (spots.isEmpty) {
      return const Center(
        child: Text('No data yet',
            style: TextStyle(color: AppColors.onSurfaceVariant)),
      );
    }
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final range = (maxY - minY).abs();
    return LineChart(
      LineChartData(
        minY: minY - range * 0.05,
        maxY: maxY + range * 0.05,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.outline,
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (spots.length / 4).floorToDouble().clamp(1, 1000),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= days.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    D.dayMonth(days[i].date),
                    style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 9,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, _) {
                return Text(
                  Money.compact(v),
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 9,
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

/// Spending by category — last 30 days, top 5.
class _CategoryTrendsChart extends ConsumerWidget {
  const _CategoryTrendsChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(transactionsProvider);
    return SectionCard(
      title: 'Category Trends (30d)',
      child: SizedBox(
        height: 220,
        child: txsAsync.when(
          data: (txs) {
            final start = DateTime.now().subtract(const Duration(days: 30));
            final lastStart = start.subtract(const Duration(days: 30));
            final byCat = <String, double>{};
            final lastByCat = <String, double>{};
            for (final t in txs) {
              if (t.type != TxType.expense) continue;
              if (t.occurredAt.isAfter(start)) {
                byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
              } else if (t.occurredAt.isAfter(lastStart)) {
                lastByCat[t.category] = (lastByCat[t.category] ?? 0) + t.amount;
              }
            }
            final entries = byCat.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final top = entries.take(5).toList();
            if (top.isEmpty) {
              return const Center(
                child: Text('No expenses in the last 30 days',
                    style: TextStyle(color: AppColors.onSurfaceVariant)),
              );
            }
            return BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: top.first.value * 1.2,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= top.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            top[i].key.split('_').first,
                            style: const TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 9,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        Money.compact(v),
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  for (int i = 0; i < top.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: top[i].value,
                          color: Categories.byId(top[i].key).color,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
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

/// Drawdown: highest saved vs current.
class _DrawdownCard extends ConsumerWidget {
  const _DrawdownCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheAsync = ref.watch(_recentCacheProvider(90));
    return SectionCard(
      title: 'Drawdown Analysis',
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
          final current = running;
          final diff = peak - current;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stat('Peak saved', Money.format(peak), AppColors.primary),
              _stat('Current saved', Money.format(current), AppColors.onSurface),
              const SizedBox(height: 8),
              _stat(
                'Drawdown',
                Money.format(diff),
                diff > 0 ? AppColors.error : AppColors.onSurfaceVariant,
              ),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text('Error: $e'),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cash flow: income, expenses, savings over last 30 days.
class _CashFlowCard extends ConsumerWidget {
  const _CashFlowCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheAsync = ref.watch(_recentCacheProvider(30));
    return SectionCard(
      title: 'Cash Flow (30d)',
      child: SizedBox(
        height: 180,
        child: cacheAsync.when(
          data: (days) {
            final income = days.fold<double>(0, (a, d) => a + d.income);
            final expenses = days.fold<double>(0, (a, d) => a + d.expenses);
            final saved = income - expenses;
            return Row(
              children: [
                Expanded(
                  child: _BigStat(
                    label: 'Income',
                    value: Money.format(income),
                    color: AppColors.primary,
                    icon: Icons.arrow_upward,
                  ),
                ),
                Expanded(
                  child: _BigStat(
                    label: 'Expenses',
                    value: Money.format(expenses),
                    color: AppColors.error,
                    icon: Icons.arrow_downward,
                  ),
                ),
                Expanded(
                  child: _BigStat(
                    label: 'Saved',
                    value: Money.format(saved),
                    color: AppColors.primary,
                    icon: Icons.savings,
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _BigStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// Helper provider: returns the daily cache for the last N days.
final _recentCacheProvider = FutureProvider.family
    .autoDispose<List<DailyPerformance>, int>(
  (ref, days) async {
    final repo = ref.watch(cacheRepoProvider);
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days));
    return repo.rangeInclusive(start, end, cutoffHour: 3);
  },
);