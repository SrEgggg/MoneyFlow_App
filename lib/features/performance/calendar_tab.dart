import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/section_card.dart';
import '../../providers.dart';
import 'widgets/calendar_grid.dart';

/// Calendar tab: monthly grid + month navigation + legend + drill-down links.
class CalendarTab extends ConsumerStatefulWidget {
  const CalendarTab({super.key});

  @override
  ConsumerState<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<CalendarTab> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  void _prev() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1, 1);
    });
  }

  void _next() {
    setState(() {
      _month = DateTime(_month.year, _month.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cacheAsync = ref.watch(dailyCacheForMonthProvider(
        (month: _month, cutoffHour: 3)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Month nav
        Row(
          children: [
            IconButton(
              onPressed: _prev,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(
                child: Text(
                  D.monthYear(_month),
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: _next,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        cacheAsync.when(
          data: (days) => CalendarGrid(
            month: _month,
            days: days,
          ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
        const SizedBox(height: 16),
        const SectionCard(
          title: 'Legend',
          child: _LegendList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.push(Routes.performanceAchievements),
                icon: const Icon(Icons.emoji_events_outlined, size: 18),
                label: const Text('Achievements'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(Routes.performanceStreaks),
                icon: const Icon(Icons.local_fire_department_outlined,
                    size: 18),
                label: const Text('Streaks'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push(Routes.performanceAdvanced),
          icon: const Icon(Icons.analytics_outlined, size: 18),
          label: const Text('Advanced Analytics'),
        ),
      ],
    );
  }
}

class _LegendList extends StatelessWidget {
  const _LegendList();
  @override
  Widget build(BuildContext context) {
    const items = [
      ('Excellent Saving Day', AppColors.dayDarkGreen),
      ('Saved Money', AppColors.dayGreen),
      ('Break-even', AppColors.dayYellow),
      ('Overspent', AppColors.dayRed),
      ('Heavy Overspending', AppColors.dayDarkRed),
    ];
    return Wrap(
      spacing: 16,
      runSpacing: 10,
      children: [
        for (final e in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: e.$2,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                e.$1,
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
      ],
    );
  }
}