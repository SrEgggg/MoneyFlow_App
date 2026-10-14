import 'widgets/goal_activity.dart';
import 'widgets/goal_image.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/utils/goal_plan.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import 'create_goal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/money.dart';
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
    final current = goalsAsync.valueOrNull
        ?.where((g) => g.id == goalId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal'),
        actions: [if (current != null) _GoalOptions(goal: current)],
      ),
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

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    var amountText = '';
    String? error;
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: const Text('Remove savings from goal?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This releases money allocated to this goal. Account balances stay unchanged.',
                ),
                TextField(
                  onChanged: (value) => amountText = value,
                  enabled: !saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    errorText: error,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final amount = double.tryParse(amountText.trim());
                      if (amount == null ||
                          !amount.isFinite ||
                          amount <= 0 ||
                          amount > goal.currentAmount) {
                        update(
                          () => error =
                              'Enter an amount within your saved balance.',
                        );
                        return;
                      }
                      update(() => saving = true);
                      try {
                        await ref
                            .read(goalRepoProvider)
                            .withdraw(goal.id!, amount);
                        await ref.read(goalsProvider.notifier).refresh();
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (_) {
                        if (dialogContext.mounted) {
                          update(() {
                            saving = false;
                            error =
                                'Could not withdraw. Check your saved balance.';
                          });
                        }
                      }
                    },
              child: const Text('Remove savings'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(activityClockProvider).valueOrNull ?? DateTime.now();
    final plan = GoalPlan.forGoal(goal, now);
    final color = Theme.of(context).colorScheme.primary;
    final pct = goal.progress;
    final remaining = (goal.targetAmount - goal.currentAmount).clamp(
      0,
      double.infinity,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        // Header
        SectionCard(
          child: Column(
            children: [
              Row(
                children: [
                  GoalImage(photo: goal.photo, icon: goal.kind.icon, size: 80),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(pct * 100).round()}% saved',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(color: color),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
                semanticsLabel: '${goal.name} progress',
                semanticsValue: '${(pct * 100).round()} percent',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: AppSpace.lg,
                runSpacing: 12,
                children: [
                  _Stat(
                    label: 'Current',
                    value: Money.of(context).format(goal.currentAmount),
                    color: color,
                  ),
                  _Stat(
                    label: 'Target',
                    value: Money.of(context).format(goal.targetAmount),
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  _Stat(
                    label: 'Remaining',
                    value: Money.of(context).format(remaining),
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        AsyncAction(
          action: () async {
            if (goal.isCompleted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('This goal is already completed')),
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
                    'Added ${Money.of(context).format(amount)} to ${goal.name}',
                  ),
                ),
              );
            }
          },
          builder: (busy, run) => FilledButton.icon(
            onPressed: busy || goal.isCompleted ? null : run,
            icon: const Icon(Icons.add, size: 18),
            label: Text(goal.isCompleted ? 'Goal completed' : 'Add savings'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onPressed: goal.currentAmount > 0
              ? () => _withdraw(context, ref)
              : null,
          icon: const Icon(Icons.remove_circle_outline),
          label: const Text('Remove from goal'),
        ),
        const SizedBox(height: 16),
        Text(
          'Goal savings are allocations within your existing money, not bank transfers.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Suggested savings',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (goal.targetDate != null)
                _DetailRow(
                  label: 'Target date',
                  value: D.fullDate(goal.targetDate!),
                ),
              if (goal.monthlyTarget != null)
                _DetailRow(
                  label: 'Monthly target',
                  value: Money.of(context).format(goal.monthlyTarget!),
                ),
              if (goal.completedAt != null)
                _DetailRow(
                  label: 'Completed',
                  value: D.dateTime(goal.completedAt!),
                ),
              if (goal.targetDate != null ||
                  goal.monthlyTarget != null ||
                  goal.completedAt != null)
                const SizedBox(height: AppSpace.sm),
              plan.message != null
                  ? Text(plan.message!)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About ${Money.of(context).format(plan.daily.ceilToDouble().clamp(0, plan.remaining))}/day',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(color: color),
                        ),
                        ExpansionTile(
                          shape: const Border(),
                          collapsedShape: const Border(),
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Other saving paces'),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Exact daily pace: ${Money.of(context).format(plan.daily)}. ${Money.of(context).format(plan.weekly)}/week or ${Money.of(context).format(plan.monthly)}/month.',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${plan.days} days including today and the target date. Choose one pace. Amounts round up to cents; a month is approximately 30.44 days.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        GoalActivity(goal: goal),
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
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
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
  final String label, value;
  const _DetailRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

class _GoalOptions extends ConsumerWidget {
  final GoalRecord goal;
  const _GoalOptions({required this.goal});
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
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
            content: Text('Could not delete the goal. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncAction(
    action: () async {
      final choice = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit goal'),
                onTap: () => Navigator.pop(c, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete goal'),
                onTap: () => Navigator.pop(c, 'delete'),
              ),
            ],
          ),
        ),
      );
      if (!context.mounted) return;
      if (choice == 'delete') await _delete(context, ref);
      if (choice == 'edit' && context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => CreateGoalScreen(goal: goal)),
        );
      }
    },
    builder: (busy, run) => IconButton(
      tooltip: 'Goal options',
      onPressed: busy ? null : run,
      icon: const Icon(Icons.more_horiz),
    ),
  );
}
