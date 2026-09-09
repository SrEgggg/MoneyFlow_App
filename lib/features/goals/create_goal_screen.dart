import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../providers.dart';

/// Form to create a new savings goal.
class CreateGoalScreen extends ConsumerStatefulWidget {
  const CreateGoalScreen({super.key});

  @override
  ConsumerState<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends ConsumerState<CreateGoalScreen> {
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();
  GoalKind _kind = GoalKind.emergency;
  DateTime? _targetDate;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _monthlyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final target = double.tryParse(_targetCtrl.text.trim());
    if (name.isEmpty) {
      _err('Enter a goal name');
      return;
    }
    if (target == null || target <= 0) {
      _err('Enter a valid target amount');
      return;
    }
    final monthly = double.tryParse(_monthlyCtrl.text.trim());
    setState(() => _saving = true);
    final goal = GoalRecord(
      name: name,
      kind: _kind,
      icon: _kind.id,
      targetAmount: target,
      currentAmount: 0,
      monthlyTarget: monthly,
      startedAt: DateTime.now(),
      targetDate: _targetDate,
      status: GoalStatus.active,
      sortOrder: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      await ref.read(goalsProvider.notifier).add(goal);
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal created')),
      );
    } catch (e) {
      setState(() => _saving = false);
      _err('Could not save: $e');
    }
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Goal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Label(text: 'Goal Type'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in GoalKind.values)
                _KindChip(
                  kind: k,
                  active: _kind == k,
                  onTap: () => setState(() {
                    _kind = k;
                    if (_nameCtrl.text.isEmpty) {
                      _nameCtrl.text = k.label;
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const _Label(text: 'Name'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(hintText: 'e.g. Emergency Fund'),
          ),
          const SizedBox(height: 20),
          const _Label(text: 'Target Amount'),
          const SizedBox(height: 8),
          TextField(
            controller: _targetCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              hintText: '0.00',
              prefixText: '₱ ',
            ),
          ),
          const SizedBox(height: 20),
          const _Label(text: 'Monthly Target (optional)'),
          const SizedBox(height: 8),
          TextField(
            controller: _monthlyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              hintText: '0.00',
              prefixText: '₱ ',
            ),
          ),
          const SizedBox(height: 20),
          const _Label(text: 'Target Date (optional)'),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate:
                    _targetDate ?? DateTime.now().add(const Duration(days: 180)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                builder: (context, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.primary,
                      onPrimary: AppColors.onPrimary,
                      surface: AppColors.surfaceContainer,
                      onSurface: AppColors.onSurface,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _targetDate = picked);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 18, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _targetDate == null
                          ? 'No target date'
                          : '${_targetDate!.year}-${_targetDate!.month.toString().padLeft(2, '0')}-${_targetDate!.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (_targetDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _targetDate = null),
                      child: const Icon(Icons.close,
                          color: AppColors.onSurfaceVariant, size: 18),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Create Goal'),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppColors.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      );
}

class _KindChip extends StatelessWidget {
  final GoalKind kind;
  final bool active;
  final VoidCallback onTap;
  const _KindChip({
    required this.kind,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? kind.color.withValues(alpha: 0.18)
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? kind.color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(kind.icon,
                size: 16,
                color: active ? kind.color : AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              kind.label,
              style: TextStyle(
                color: active ? kind.color : AppColors.onSurface,
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}