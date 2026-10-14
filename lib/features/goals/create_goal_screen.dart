import 'goal_photo_service.dart';
import 'widgets/goal_image.dart';
import '../../core/utils/money.dart';
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
  final GoalRecord? goal;
  const CreateGoalScreen({super.key, this.goal});

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
  bool _picking = false;
  String? _photo;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    if (goal != null) {
      _photo = goal.photo;
      _nameCtrl.text = goal.name;
      _targetCtrl.text = goal.targetAmount.toStringAsFixed(2);
      _monthlyCtrl.text = goal.monthlyTarget?.toStringAsFixed(2) ?? '';
      _kind = goal.kind;
      _targetDate = goal.targetDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _monthlyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_picking || _saving) return;
    setState(() => _picking = true);
    try {
      final photo = await ref.read(goalPhotoServiceProvider).pick();
      if (mounted && photo != null) setState(() => _photo = photo);
    } catch (_) {
      if (mounted) {
        _err('Could not open this photo. Choose another image and try again.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _picking) return;
    final name = _nameCtrl.text.trim();
    final target = double.tryParse(_targetCtrl.text.trim());
    if (name.isEmpty) {
      _err('Enter a goal name');
      return;
    }
    if (target == null ||
        !target.isFinite ||
        target <= 0 ||
        target > 999999999.99) {
      _err('Enter a valid target amount');
      return;
    }
    final monthly = double.tryParse(_monthlyCtrl.text.trim());
    if (_monthlyCtrl.text.trim().isNotEmpty &&
        (monthly == null ||
            !monthly.isFinite ||
            monthly <= 0 ||
            monthly > 999999999.99)) {
      _err('Enter a positive monthly target, or leave it empty.');
      return;
    }
    final saved = widget.goal?.currentAmount ?? 0;
    setState(() => _saving = true);
    final goal = GoalRecord(
      id: widget.goal?.id,
      name: name,
      photo: _photo,
      kind: _kind,
      icon: _kind.id,
      targetAmount: target,
      currentAmount: saved,
      monthlyTarget: monthly,
      startedAt: widget.goal?.startedAt ?? DateTime.now(),
      targetDate: _targetDate,
      status: saved >= target ? GoalStatus.completed : GoalStatus.active,
      completedAt: saved >= target
          ? widget.goal?.completedAt ?? DateTime.now()
          : null,
      sortOrder:
          widget.goal?.sortOrder ?? DateTime.now().millisecondsSinceEpoch,
    );
    try {
      if (widget.goal == null) {
        await ref.read(goalsProvider.notifier).add(goal);
      } else {
        await ref.read(goalsProvider.notifier).edit(goal);
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.goal == null
                ? 'Goal successfully created.'
                : 'Goal updated successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _err('Could not save: $e');
    }
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.goal == null ? 'New Goal' : 'Edit Goal'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GoalImage(photo: _photo, icon: _kind.icon, size: 80),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Make it yours',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add a photo of what you’re saving for.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    TextButton.icon(
                      onPressed: _picking || _saving ? null : _pickPhoto,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        _picking
                            ? 'Preparing photo…'
                            : _photo == null
                            ? 'Choose photo'
                            : 'Change photo',
                      ),
                    ),
                    if (_photo != null)
                      TextButton(
                        onPressed: _picking || _saving
                            ? null
                            : () => setState(() => _photo = null),
                        child: const Text('Remove photo'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (ref.watch(recoveredGoalPhotoProvider).valueOrNull != null)
            TextButton(
              onPressed: _saving || _picking
                  ? null
                  : () {
                      setState(
                        () => _photo = ref
                            .read(recoveredGoalPhotoProvider)
                            .valueOrNull,
                      );
                      ref.invalidate(recoveredGoalPhotoProvider);
                    },
              child: const Text('Use recovered photo selection'),
            ),
          const SizedBox(height: 24),
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
            decoration: InputDecoration(hintText: 'e.g. Emergency Fund'),
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
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: '${Money.of(context).symbol} ',
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
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: '${Money.of(context).symbol} ',
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
                    _targetDate ??
                    DateTime.now().add(const Duration(days: 180)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: Theme.of(context).colorScheme.primary,
                      onPrimary: AppColors.onPrimary,
                      surface: Theme.of(context).colorScheme.surfaceContainer,
                      onSurface: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _targetDate = picked);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _targetDate == null
                          ? 'No target date'
                          : '${_targetDate!.year}-${_targetDate!.month.toString().padLeft(2, '0')}-${_targetDate!.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (_targetDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _targetDate = null),
                      child: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving || _picking ? null : _save,
            child: Text(
              _saving
                  ? 'Saving…'
                  : widget.goal == null
                  ? 'Create Goal'
                  : 'Save Changes',
            ),
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
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 13,
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
    return ChoiceChip(
      selected: active,
      onSelected: (_) => onTap(),
      avatar: Icon(
        kind.icon,
        size: 18,
        color: active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      label: Text(kind.label),
    );
  }
}
