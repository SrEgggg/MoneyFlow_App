import 'goal_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/goal_plan.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/models/models.dart';

class GoalCard extends ConsumerWidget {
  final GoalRecord goal;
  final double? avgMonthlySavings;
  final VoidCallback onTap;
  const GoalCard({
    super.key,
    required this.goal,
    this.avgMonthlySavings,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(activityClockProvider).valueOrNull ?? DateTime.now();
    final plan = GoalPlan.forGoal(goal, now);
    final remaining = (goal.targetAmount - goal.currentAmount).clamp(
      0,
      double.infinity,
    );
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                child: Row(
                  children: [
                    GoalImage(photo: goal.photo, icon: goal.kind.icon),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        goal.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              Money.of(context).format(goal.currentAmount),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpace.xs),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.xs,
              children: [
                Text(
                  'of ${Money.of(context).format(goal.targetAmount)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${(goal.progress * 100).round()}% saved',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            TweenAnimationBuilder<double>(
              tween: Tween(end: goal.progress),
              duration: AppMotion.duration(context),
              builder: (context, progress, _) => LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
                semanticsLabel: '${goal.name} progress',
                semanticsValue: '${(goal.progress * 100).round()} percent',
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              '${Money.of(context).format(remaining)} remaining${goal.targetDate == null ? '' : ' · Target ${D.dayMonth(goal.targetDate!)}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (plan.message != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.sm),
                child: Text(
                  plan.message!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: AppSpace.sm),
                title: Text(
                  'About ${Money.of(context).format(plan.daily.ceilToDouble().clamp(0, plan.remaining))}/day',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: AppSpace.lg,
                      runSpacing: AppSpace.md,
                      children: [
                        for (final pace in [
                          ('Per day', plan.daily),
                          ('Per week', plan.weekly),
                          ('Per month', plan.monthly),
                        ])
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                pace.$1,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: AppSpace.xs),
                              Text(
                                Money.of(context).format(pace.$2),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose one pace. Monthly amounts are approximate.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
