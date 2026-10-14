import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/money.dart';
import '../../../core/utils/goal_plan.dart';
import '../../../data/models/models.dart';

/// Modal dialog for adding a contribution to a goal.
Future<double?> showContributionDialog(
  BuildContext context, {
  required GoalRecord goal,
}) {
  return showDialog<double>(
    context: context,
    builder: (_) => _ContributionDialog(goal: goal),
  );
}

class _ContributionDialog extends StatefulWidget {
  final GoalRecord goal;
  const _ContributionDialog({required this.goal});
  @override
  State<_ContributionDialog> createState() => _ContributionDialogState();
}

class _ContributionDialogState extends State<_ContributionDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = double.tryParse(_ctrl.text.trim());
    if (v == null || !v.isFinite || v <= 0 || v > 999999999.99) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (v > widget.goal.targetAmount - widget.goal.currentAmount) {
      setState(
        () => _error =
            'Amount exceeds the remaining ${Money.of(context).compact(widget.goal.targetAmount - widget.goal.currentAmount)}',
      );
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.goal.targetAmount - widget.goal.currentAmount;
    final plan = GoalPlan.forGoal(widget.goal, DateTime.now());
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      title: Text('Add savings to ${widget.goal.name}'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remaining: ${Money.of(context).format(remaining)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          if (plan.message == null) ...[
            Text(
              'Choose a pace or enter your own amount.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pace in [
                  ('A day', plan.daily),
                  ('A week', plan.weekly),
                ])
                  ActionChip(
                    label: Text(
                      '${pace.$1} · ${Money.of(context).format(pace.$2)}',
                    ),
                    onPressed: () {
                      _ctrl.text = pace.$2.toStringAsFixed(2);
                      _ctrl.selection = TextSelection.collapsed(
                        offset: _ctrl.text.length,
                      );
                      setState(() => _error = null);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              labelText: 'Amount to save',
              hintText: '0.00',
              prefixText: '${Money.of(context).symbol} ',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add savings')),
      ],
    );
  }
}
