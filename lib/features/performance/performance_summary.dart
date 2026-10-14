import '../../core/utils/analytics_window.dart';
import '../../core/widgets/app_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import '../../core/constants/categories.dart';
import '../../core/utils/activity_summary.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/section_card.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../providers.dart';
import '../transactions/widgets/tx_list_tile.dart';

class PerformanceSummary extends ConsumerStatefulWidget {
  const PerformanceSummary({super.key});
  @override
  ConsumerState<PerformanceSummary> createState() => _PerformanceSummaryState();
}

class _PerformanceSummaryState extends ConsumerState<PerformanceSummary> {
  int _days = 0;
  bool _showAll = false;
  @override
  Widget build(BuildContext context) {
    final now = ref.watch(activityClockProvider).valueOrNull ?? DateTime.now();
    final window = AnalyticsWindow(now, _days);
    final goals = ref.watch(goalsProvider).valueOrNull ?? [];
    return ref
        .watch(activityProvider)
        .when(
          loading: () => const LoadingPlaceholder(lines: 5),
          error: (_, __) => InlineNotice(
            message:
                'Could not load analytics. Your recorded data is unchanged.',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(activityProvider),
          ),
          data: (all) {
            final activity = window.current(all);
            final previous = window.previous(all);
            final cashDays = activity.transactions
                .where((t) => t.type != TxType.transfer)
                .map((t) => ActivitySummary.day(t.occurredAt))
                .toSet();
            final hasPrevious = previous.transactions.any(
              (t) => t.type != TxType.transfer,
            );
            final byCategory = <String, double>{};
            for (final tx in activity.transactions.where(
              (t) => t.type == TxType.expense,
            )) {
              byCategory.update(
                tx.category,
                (v) => v + tx.amount,
                ifAbsent: () => tx.amount,
              );
            }
            final categories = byCategory.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final colors = Theme.of(context).colorScheme;
            final difference = activity.net - previous.net;
            final rate = activity.income > 0
                ? activity.net / activity.income
                : null;
            return ListView(
              padding: AppSpace.page,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final range in [
                        (7, '7D'),
                        (30, '30D'),
                        (90, '90D'),
                        (0, 'Month'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(range.$2),
                            tooltip: range.$1 == 0
                                ? 'This month'
                                : 'Last ${range.$1} days',
                            selected: _days == range.$1,
                            onSelected: (_) => setState(() {
                              _days = range.$1;
                              _showAll = false;
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '${D.dayMonth(window.start)} – ${D.dayMonth(window.end.subtract(const Duration(days: 1)))}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpace.lg),
                if (activity.activeDays.isEmpty)
                  InlineNotice(
                    icon: Icons.insights_outlined,
                    message:
                        'No activity in this period. Record a transaction or choose a different range.',
                    actionLabel: 'Add transaction',
                    onAction: () => context.go(Routes.transactions),
                  )
                else ...[
                  SectionCard(
                    title: 'Net cash flow',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Money.of(context).formatSigned(activity.net),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: activity.net < 0
                                    ? colors.error
                                    : colors.primary,
                              ),
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          hasPrevious
                              ? '${Money.of(context).formatSigned(difference)} vs ${window.comparisonLabel}'
                              : 'No comparison data yet.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (hasPrevious && previous.net > 0)
                          Text(
                            '${difference >= 0 ? '+' : ''}${(difference / previous.net * 100).toStringAsFixed(1)}% change',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (cashDays.length < 5)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpace.sm),
                            child: Text(
                              '${cashDays.length} activity ${cashDays.length == 1 ? 'day' : 'days'} · trend needs 5.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        if (cashDays.length >= 5) ...[
                          const SizedBox(height: AppSpace.md),
                          _CashFlowChart(
                            activity: activity,
                            start: window.start,
                            end: window.end,
                          ),
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            'Cumulative cash flow · touch a point for details',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  SectionCard(
                    title: 'Income vs expenses',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in [
                          ('Income', activity.income, colors.primary),
                          ('Expenses', activity.expenses, colors.error),
                        ]) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.$1,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              const SizedBox(width: AppSpace.sm),
                              Flexible(
                                fit: FlexFit.tight,
                                child: Text(
                                  Money.of(context).format(item.$2),
                                  textAlign: TextAlign.end,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.xs),
                          LinearProgressIndicator(
                            value: activity.income + activity.expenses == 0
                                ? 0
                                : item.$2 /
                                      (activity.income > activity.expenses
                                          ? activity.income
                                          : activity.expenses),
                            color: item.$3,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(4),
                            semanticsLabel: item.$1,
                            semanticsValue: Money.of(context).format(item.$2),
                          ),
                          const SizedBox(height: AppSpace.md),
                        ],
                        Text(
                          rate == null
                              ? 'Income retained unavailable without income.'
                              : 'Income retained · ${(rate * 100).toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          rate != null && rate < 0
                              ? 'Expenses exceed recorded income.'
                              : 'Income minus recorded expenses. Goal allocations are shown separately.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  if (categories.isNotEmpty)
                    SectionCard(
                      title: 'Spending by category',
                      subtitle: 'Tap to view transactions',
                      child: Column(
                        children: [
                          for (final entry
                              in (_showAll ? categories : categories.take(5)))
                            _CategoryBar(
                              category: Categories.resolve(context, entry.key),
                              amount: entry.value,
                              total: activity.expenses,
                              onTap: () => _showCategory(
                                context,
                                entry.key,
                                activity.transactions,
                              ),
                            ),
                          if (categories.length > 5)
                            TextButton(
                              onPressed: () =>
                                  setState(() => _showAll = !_showAll),
                              child: Text(
                                _showAll ? 'Show less' : 'Show all categories',
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    const InlineNotice(message: 'No expenses in this period.'),
                  const SizedBox(height: AppSpace.md),
                  if (goals.isNotEmpty)
                    SectionCard(
                      title: 'Goal savings',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${Money.of(context).format(activity.saved)} allocated in this period',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('Overall goal progress'),
                            children: [
                              for (final goal in goals)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(goal.name),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${Money.of(context).format(goal.currentAmount)} of ${Money.of(context).format(goal.targetAmount)} · ${(goal.progress * 100).round()}%',
                                      ),
                                      const SizedBox(height: 8),
                                      LinearProgressIndicator(
                                        value: goal.progress,
                                        semanticsLabel: '${goal.name} progress',
                                      ),
                                    ],
                                  ),
                                  onTap: () =>
                                      context.push(Routes.goalDetail(goal.id!)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (hasPrevious)
                    InlineNotice(
                      icon: Icons.lightbulb_outline,
                      message: activity.expenses == previous.expenses
                          ? 'Spending is unchanged from the comparison period.'
                          : 'Spending is ${Money.of(context).format((activity.expenses - previous.expenses).abs())} ${activity.expenses > previous.expenses ? 'higher' : 'lower'} than the comparison period.',
                    )
                  else if (categories.isNotEmpty)
                    InlineNotice(
                      icon: Icons.lightbulb_outline,
                      message:
                          '${Categories.resolve(context, categories.first.key).name} accounts for ${(categories.first.value / activity.expenses * 100).round()}% of recorded spending.',
                    ),
                ],
                const SizedBox(height: AppSpace.md),
                const ExpansionTile(
                  title: Text('About these numbers'),
                  leading: Icon(Icons.info_outline),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Ranges use local calendar dates and include today. Month compares with the same elapsed days of the previous month, capped at that month’s end; other ranges use the preceding equal-length period. Net cash flow is income minus expenses, not your account balance. Transfers are excluded. Goal savings are allocations of existing funds. Goal progress is current overall progress.',
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
  }

  void _showCategory(
    BuildContext context,
    String id,
    List<TxRecord> transactions,
  ) {
    final category = Categories.resolve(context, id);
    final matching =
        transactions
            .where((t) => t.type == TxType.expense && t.category == id)
            .toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  category.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: matching.length,
                  itemBuilder: (_, i) => TxListTile(
                    tx: matching[i],
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.push(Routes.transactionDetail(matching[i].id!));
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final TxCategory category;
  final double amount, total;
  final VoidCallback onTap;
  const _CategoryBar({
    required this.category,
    required this.amount,
    required this.total,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${category.name}, ${Money.of(context).format(amount)}, ${(amount / total * 100).round()} percent of spending',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: [
            Row(
              children: [
                Icon(category.icon, color: category.color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(Money.of(context).format(amount)),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: total > 0 ? amount / total : 0,
              color: category.color,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              minHeight: 6,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CashFlowChart extends StatelessWidget {
  final ActivitySummary activity;
  final DateTime start, end;
  const _CashFlowChart({
    required this.activity,
    required this.start,
    required this.end,
  });
  @override
  Widget build(BuildContext context) {
    final dates = <DateTime>[];
    for (
      var day = start;
      day.isBefore(end);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      dates.add(day);
    }
    double running = 0;
    final spots = <FlSpot>[];
    for (var i = 0; i < dates.length; i++) {
      running += activity.on(dates[i]).net;
      spots.add(FlSpot(i.toDouble(), running));
    }
    if (activity.transactions.every((t) => t.type == TxType.transfer)) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Add income or expenses to see your cash flow trend.'),
      );
    }
    final textScale = (MediaQuery.textScalerOf(context).scale(13) / 13).clamp(
      1.0,
      2.0,
    );
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label:
          'Cash flow trend. End of period ${Money.of(context).format(running)}. Touch a point for its date and value.',
      child: SizedBox(
        height: 190 * textScale,
        child: Padding(
          padding: const EdgeInsets.only(top: 16, right: 12),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: dates.length == 1 ? 1 : (dates.length - 1).toDouble(),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) =>
                      Theme.of(context).colorScheme.inverseSurface,
                  getTooltipItems: (points) => points.map((point) {
                    final i = point.x.toInt().clamp(0, dates.length - 1);
                    return LineTooltipItem(
                      '${D.dayMonth(dates[i])}\n${Money.of(context).format(point.y)}',
                      TextStyle(
                        color: Theme.of(context).colorScheme.onInverseSurface,
                      ),
                    );
                  }).toList(),
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 68 * textScale,
                    getTitlesWidget: (v, _) => Text(
                      Money.of(context).compact(v),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: (dates.length / 3).ceilToDouble().clamp(1, 90),
                    reservedSize: 40 * textScale,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (textScale > 1.3 && i != 0 && i != dates.length - 1) {
                        return const SizedBox.shrink();
                      }
                      return i >= 0 && i < dates.length
                          ? Text(
                              D.dayMonth(dates[i]),
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          : const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  color: color,
                  barWidth: 2.5,
                  isCurved: false,
                  dotData: FlDotData(show: dates.length == 1),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: .1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
