import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/utils/goal_history.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/models/models.dart';
import '../../../providers.dart';

final goalActivityProvider = FutureProvider.family<List<GoalContribution>, int>(
  (ref, id) {
    ref.watch(goalsProvider);
    return ref.read(goalRepoProvider).contributionsFor(id);
  },
);

class GoalActivity extends ConsumerWidget {
  final GoalRecord goal;
  const GoalActivity({super.key, required this.goal});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(goalActivityProvider(goal.id!))
      .when(
        loading: () => const LoadingPlaceholder(lines: 3),
        error: (_, __) => InlineNotice(
          message: 'Could not load goal activity. Your savings are unchanged.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(goalActivityProvider(goal.id!)),
        ),
        data: (records) {
          final history = GoalHistory(goal, records);
          final days = history.dailyBalances.entries.toList();
          final newest = history.events.reversed.toList();
          return SectionCard(
            title: 'Your saving journey',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (records.isEmpty)
                  Text(
                    goal.currentAmount > 0
                        ? 'Starting allocation: ${Money.of(context).format(goal.currentAmount)}. Your next savings update will start the activity history.'
                        : 'Your first contribution starts the story. Add savings when you’re ready.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else ...[
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _Metric(label: 'Total added', amount: history.added),
                      _Metric(label: 'Total removed', amount: history.removed),
                    ],
                  ),
                  if (history.openingAmount > .009)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Plus ${Money.of(context).format(history.openingAmount)} starting allocation.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (days.length >= 3 &&
                      history.openingAmount >= -.009 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 20) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Goal balance over time',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      label:
                          'Goal balance from ${Money.of(context).format(days.first.value)} to ${Money.of(context).format(days.last.value)}. Dated amounts are in the activity list below.',
                      child: SizedBox(
                        height: 128,
                        child: LineChart(
                          LineChartData(
                            minX: 0,
                            maxX:
                                DateTime.utc(
                                      days.last.key.year,
                                      days.last.key.month,
                                      days.last.key.day,
                                    )
                                    .difference(
                                      DateTime.utc(
                                        days.first.key.year,
                                        days.first.key.month,
                                        days.first.key.day,
                                      ),
                                    )
                                    .inDays
                                    .toDouble(),
                            titlesData: const FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(show: false),
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                fitInsideHorizontally: true,
                                fitInsideVertically: true,
                                getTooltipColor: (_) => Theme.of(
                                  context,
                                ).colorScheme.inverseSurface,
                                getTooltipItems: (points) => points
                                    .map(
                                      (p) => LineTooltipItem(
                                        '${D.dayMonth(days[p.spotIndex].key)}\n${Money.of(context).format(p.y)}',
                                        TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onInverseSurface,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                isCurved: false,
                                color: Theme.of(context).colorScheme.primary,
                                barWidth: 2.5,
                                dotData: const FlDotData(show: true),
                                spots: [
                                  for (final day in days)
                                    FlSpot(
                                      DateTime.utc(
                                            day.key.year,
                                            day.key.month,
                                            day.key.day,
                                          )
                                          .difference(
                                            DateTime.utc(
                                              days.first.key.year,
                                              days.first.key.month,
                                              days.first.key.day,
                                            ),
                                          )
                                          .inDays
                                          .toDouble(),
                                      day.value,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            D.dayMonth(days.first.key),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          D.dayMonth(days.last.key),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  for (final event in newest.take(4)) _EventTile(event: event),
                  if (newest.length > 4)
                    TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        showDragHandle: true,
                        isScrollControlled: true,
                        builder: (c) => SafeArea(
                          child: SizedBox(
                            height: MediaQuery.sizeOf(c).height * .7,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Goal activity',
                                    style: Theme.of(c).textTheme.titleLarge,
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    itemCount: newest.length,
                                    itemBuilder: (_, i) =>
                                        _EventTile(event: newest[i]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      child: Text('See all ${newest.length} updates'),
                    ),
                ],
              ],
            ),
          );
        },
      );
}

class _Metric extends StatelessWidget {
  final String label;
  final double amount;
  const _Metric({required this.label, required this.amount});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      Text(
        Money.of(context).format(amount),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ],
  );
}

class _EventTile extends StatelessWidget {
  final GoalContribution event;
  const _EventTile({required this.event});
  @override
  Widget build(BuildContext context) {
    final added = event.amount >= 0;
    final color = added
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            added ? Icons.add_circle_outline : Icons.remove_circle_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  added ? 'Savings added' : 'Removed from goal',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  D.dateTime(event.contributedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              Money.of(context).formatSigned(event.amount),
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
