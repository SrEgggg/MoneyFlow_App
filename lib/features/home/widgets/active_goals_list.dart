import '../../goals/widgets/quick_goal_savings.dart';
import '../../goals/widgets/goal_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/models/enums.dart';
import '../../../providers.dart';

class ActiveGoalsList extends ConsumerWidget {
  const ActiveGoalsList({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(goalsProvider)
      .when(
        loading: () => const LoadingPlaceholder(lines: 2),
        error: (_, __) => InlineNotice(
          message: 'Could not load goals.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(goalsProvider),
        ),
        data: (goals) {
          final active =
              goals.where((g) => g.status == GoalStatus.active).toList()..sort(
                (a, b) => (a.targetDate ?? DateTime(9999)).compareTo(
                  b.targetDate ?? DateTime(9999),
                ),
              );
          if (active.isEmpty) {
            return InlineNotice(
              icon: Icons.flag_outlined,
              message: goals.isEmpty
                  ? 'Give your savings a purpose. Set your first goal.'
                  : 'No active goals. Your completed goals are saved.',
              actionLabel: goals.isEmpty ? 'Create goal' : 'See goals',
              onAction: () =>
                  context.go(goals.isEmpty ? Routes.createGoal : Routes.goals),
            );
          }
          return SectionCard(
            framed: false,
            title: 'Savings goals',
            trailing: TextButton(
              onPressed: () => context.go(Routes.goals),
              child: const Text('See all'),
            ),
            child: Column(
              children: [
                for (final goal in active.take(2))
                  InkWell(
                    onTap: () => context.push(Routes.goalDetail(goal.id!)),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpace.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GoalImage(
                                photo: goal.photo,
                                icon: goal.kind.icon,
                                size: 48,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  goal.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              const Icon(Icons.chevron_right, size: 20),
                            ],
                          ),
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            '${Money.of(context).format(goal.currentAmount)} of ${Money.of(context).format(goal.targetAmount)} · ${(goal.progress * 100).round()}%',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpace.xs),
                          LinearProgressIndicator(
                            value: goal.progress,
                            minHeight: 6,
                            semanticsLabel: '${goal.name} progress',
                            semanticsValue:
                                '${(goal.progress * 100).round()} percent',
                            borderRadius: BorderRadius.circular(4),
                          ),
                          QuickGoalSavings(key: ValueKey(goal.id), goal: goal),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}
