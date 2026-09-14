import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/utils/activity_summary.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/section_card.dart';
import '../../providers.dart';
import 'widgets/activity_details.dart';

class CalendarTab extends ConsumerStatefulWidget {
  const CalendarTab({super.key});
  @override
  ConsumerState<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<CalendarTab> {
  DateTime _selected = ActivitySummary.day(DateTime.now());
  late DateTime _month = DateTime(_selected.year, _selected.month);
  void _move(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta);
    _selected = _month;
  });
  @override
  Widget build(BuildContext context) {
    final now = ref.watch(activityClockProvider).valueOrNull ?? DateTime.now();
    return ref
        .watch(activityProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(activityProvider),
              child: const Text('Could not load calendar. Retry'),
            ),
          ),
          data: (all) {
            final month = all.between(
              _month,
              DateTime(_month.year, _month.month + 1),
            );
            final streak = all
                .streaks(now)
                .firstWhere((s) => s.id == 'logging');
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: () => _move(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        D.monthYear(_month),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: () => _move(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _selected = ActivitySummary.day(now);
                    _month = DateTime(now.year, now.month);
                  }),
                  child: const Text('Today'),
                ),
                GridView(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    mainAxisExtent: 56,
                  ),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final day in [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun',
                    ])
                      Center(
                        child: Text(
                          day,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    for (var i = 1; i < _month.weekday; i++)
                      const SizedBox.shrink(),
                    for (
                      var d = 1;
                      d <= DateTime(_month.year, _month.month + 1, 0).day;
                      d++
                    )
                      _cell(DateTime(_month.year, _month.month, d), month),
                  ],
                ),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    Text('🟢 Income'),
                    Text('🔴 Expense'),
                    Text('🎯 Goal savings'),
                  ],
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: '${D.monthYear(_month)} Summary',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ActivityTotals(activity: month),
                      const SizedBox(height: 12),
                      Text('${month.activeDays.length} days with activity'),
                      Text(
                        'Tracking: ${streak.currentCount} days · Best: ${streak.bestCount} days',
                      ),
                      const Text(
                        'Activity follows local calendar dates. Today stays open until midnight.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: D.fullDate(_selected),
                  child: ActivityDetails(
                    date: _selected,
                    activity: month.on(_selected),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.push(Routes.performanceStreaks),
                      child: const Text('Streaks'),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          context.push(Routes.performanceAchievements),
                      child: const Text('Achievements'),
                    ),
                    OutlinedButton(
                      onPressed: () => context.push(Routes.performanceAdvanced),
                      child: const Text('Advanced Analytics'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
  }

  Widget _cell(DateTime date, ActivitySummary month) {
    final day = month.on(date);
    final selected = date == _selected;
    return Semantics(
      label:
          '${D.fullDate(date)}, ${day.transactions.length} transactions, ${day.contributions.length} contributions',
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.2)
            : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => setState(() => _selected = date),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (day.income > 0)
                    const Icon(Icons.circle, color: AppColors.primary, size: 7),
                  if (day.expenses > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        Icons.circle,
                        color: AppColors.error,
                        size: 7,
                      ),
                    ),
                  if (day.saved > 0)
                    const Icon(Icons.flag, color: Colors.amber, size: 11),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
