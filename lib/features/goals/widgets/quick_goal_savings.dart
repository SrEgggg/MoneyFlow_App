import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/models/models.dart';
import '../../../providers.dart';
import 'contribution_dialog.dart';

class QuickGoalSavings extends ConsumerWidget {
  final GoalRecord goal;
  const QuickGoalSavings({super.key, required this.goal});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncAction(
    action: () async {
      final amount = await showContributionDialog(context, goal: goal);
      if (amount == null) return;
      try {
        await ref.read(goalsProvider.notifier).contribute(goal, amount);
        if (!context.mounted) return;
        final saved = ref
            .read(goalsProvider)
            .valueOrNull
            ?.where((g) => g.id == goal.id)
            .firstOrNull;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved?.isCompleted == true
                  ? 'Goal reached: ${goal.name}'
                  : 'Added ${Money.of(context).format(amount)} to ${goal.name}',
            ),
          ),
        );
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not add savings. Review the goal balance and try again.',
            ),
          ),
        );
      }
    },
    builder: (busy, run) => TextButton.icon(
      onPressed: busy || goal.isCompleted ? null : run,
      icon: const Icon(Icons.add, size: 18),
      label: Text(busy ? 'Saving…' : 'Add savings'),
    ),
  );
}
