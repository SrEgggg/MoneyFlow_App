import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../core/utils/money.dart';
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
    if (v == null || v <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (v > widget.goal.targetAmount - widget.goal.currentAmount) {
      setState(() => _error =
          'Amount exceeds the remaining ${Money.compact(widget.goal.targetAmount - widget.goal.currentAmount)}');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final remaining =
        widget.goal.targetAmount - widget.goal.currentAmount;
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainer,
      title: Text('Contribute to ${widget.goal.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remaining: ${Money.format(remaining)}',
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: '₱ ',
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
        FilledButton(
          onPressed: _submit,
          child: const Text('Contribute'),
        ),
      ],
    );
  }
}