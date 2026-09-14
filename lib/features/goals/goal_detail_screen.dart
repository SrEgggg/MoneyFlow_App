import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import 'create_goal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/section_card.dart';
import '../../data/models/models.dart';
import '../../providers.dart';
import 'widgets/contribution_dialog.dart';

/// Detail view for one goal: header with progress, monthly stats,
/// contribution log, and "Add Contribution" CTA.
class GoalDetailScreen extends ConsumerWidget {
  final int goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Goal')),
      body: goalsAsync.when(
        data: (goals) {
          final goal = goals.where((g) => g.id == goalId).firstOrNull;
          if (goal == null) {
            return const Center(child: Text('Goal not found'));
          }
          return _Body(goal: goal);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final GoalRecord goal;
  const _Body({required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = goal.kind.color;
    final pct = goal.progress;
    final remaining = (goal.targetAmount - goal.currentAmount).clamp(
      0,
      double.infinity,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Goal'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CreateGoalScreen(goal: goal),
                ),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete Goal'),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Delete Goal?'),
                    content: const Text(
                      'This permanently deletes the goal and its contribution log. Account balances and income/expense transactions are unchanged. This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                try {
                  await ref.read(goalsProvider.notifier).remove(goal.id!);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Goal successfully deleted.')),
                  );
                  context.go(Routes.goals);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not delete the goal. Please try again.',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Header
        SectionCard(
          child: Column(
            children: [
              ProgressRing(
                progress: pct,
                centerText: '${(pct * 100).toStringAsFixed(1)}%',
                size: 96,
                stroke: 10,
                progressColor: color,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(goal.kind.icon, color: color, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      goal.name,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 20,
                runSpacing: 12,
                children: [
                  _Stat(
                    label: 'Current',
                    value: Money.format(goal.currentAmount),
                    color: color,
                  ),
                  _Stat(
                    label: 'Target',
                    value: Money.format(goal.targetAmount),
                    color: AppColors.onSurface,
                  ),
                  _Stat(
                    label: 'Remaining',
                    value: Money.format(remaining),
                    color: AppColors.error,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Monthly target / ETA
        if (goal.monthlyTarget != null || goal.targetDate != null)
          SectionCard(
            title: 'Plan',
            child: Column(
              children: [
                if (goal.monthlyTarget != null)
                  _DetailRow(
                    label: 'Monthly target',
                    value: Money.format(goal.monthlyTarget!),
                  ),
                if (goal.targetDate != null)
                  _DetailRow(
                    label: 'Target date',
                    value: D.fullDate(goal.targetDate!),
                  ),
                if (goal.completedAt != null)
                  _DetailRow(
                    label: 'Completed',
                    value: D.dateTime(goal.completedAt!),
                    valueColor: AppColors.primary,
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Contribution log
        SectionCard(
          title: 'Contributions',
          trailing: TextButton.icon(
            onPressed: () async {
              if (goal.isCompleted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This goal is already completed'),
                  ),
                );
                return;
              }
              final amount = await showContributionDialog(context, goal: goal);
              if (amount == null) return;
              try {
                await ref.read(goalsProvider.notifier).contribute(goal, amount);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not add contribution. Check the remaining target and try again.',
                      ),
                    ),
                  );
                }
                return;
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Added ${Money.format(amount)} to ${goal.name}',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
          ),
          child: FutureBuilder<List<GoalContribution>>(
            future: ref.read(goalRepoProvider).contributionsFor(goal.id!),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Text(
                  'Could not load contributions. Reopen this goal to retry.',
                );
              }
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final list = snap.data!;
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No contributions yet — tap "Add" to start.',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                );
              }
              return Column(
                children: [
                  for (final c in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.add, color: color, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  Money.format(c.amount),
                                  style: const TextStyle(
                                    color: AppColors.onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  D.dateTime(c.contributedAt),
                                  style: const TextStyle(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow({required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
              color: valueColor ?? AppColors.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
