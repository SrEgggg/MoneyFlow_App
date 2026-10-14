import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money.dart';
import '../../providers.dart';

/// Reviews tab: list of recent months, each tappable to drill into the
/// monthly review screen.
class ReviewsTab extends ConsumerStatefulWidget {
  const ReviewsTab({super.key});

  @override
  ConsumerState<ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends ConsumerState<ReviewsTab> {
  @override
  Widget build(BuildContext context) {
    // Build a list of last 6 months
    final months = List.generate(6, (i) => _monthsAgo(i));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [for (final m in months) _MonthReviewCard(month: m)],
    );
  }

  DateTime _monthsAgo(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month - n, 1);
  }
}

class _MonthReviewCard extends ConsumerWidget {
  final DateTime month;
  const _MonthReviewCard({required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheAsync = ref.watch(
      dailyCacheForMonthProvider((
        month: month,
        cutoffHour: ref.watch(settingsProvider).valueOrNull?.cutoffHour ?? 3,
      )),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: cacheAsync.when(
        data: (days) {
          final income = days.fold<double>(0, (a, d) => a + d.income);
          final expenses = days.fold<double>(0, (a, d) => a + d.expenses);
          final saved = income - expenses;
          final rate = income > 0 ? (saved / income) * 100 : 0.0;
          return Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => context.push(
                Routes.performanceMonth(month.year, month.month),
              ),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_month,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            D.monthYear(month),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Net ${Money.of(context).compact(saved)} • ${rate.toStringAsFixed(0)}% retained',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
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
}
