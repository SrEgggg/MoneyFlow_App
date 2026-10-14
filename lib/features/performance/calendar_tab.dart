import '../../data/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                    _Legend(
                      icon: Icons.south_west,
                      label: 'Income',
                      color: Color(0xFF15803D),
                    ),
                    _Legend(
                      icon: Icons.north_east,
                      label: 'Expense',
                      color: Color(0xFFEF4444),
                    ),
                    _Legend(
                      icon: Icons.flag_outlined,
                      label: 'Goal savings',
                      color: Color(0xFFB45309),
                    ),
                    _Legend(
                      icon: Icons.swap_vert,
                      label: 'Transfer',
                      color: Color(0xFF3B82F6),
                    ),
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
                      const ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text('About calendar days'),
                        children: [
                          Text(
                            'Activity follows local calendar dates. Today stays open until midnight.',
                          ),
                        ],
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
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
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
                  if (day.transactions.any((t) => t.type == TxType.transfer))
                    const Icon(Icons.swap_horiz, color: Colors.blue, size: 11),
                  if (day.income > 0)
                    Icon(
                      Icons.south_west,
                      color: Theme.of(context).colorScheme.primary,
                      size: 10,
                    ),
                  if (day.expenses > 0)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        Icons.north_east,
                        color: Theme.of(context).colorScheme.error,
                        size: 10,
                      ),
                    ),
                  if (day.contributions.isNotEmpty)
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

class _Legend extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Legend({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
