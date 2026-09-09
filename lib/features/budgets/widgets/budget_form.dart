import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/categories.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/budget.dart';
import '../../../providers.dart';

/// Add / edit a per-category budget. The scope toggle lets the user pin the
/// cap to a specific month or leave it rolling (every month).
class BudgetForm extends ConsumerStatefulWidget {
  final BudgetRecord? existing;

  const BudgetForm({super.key, this.existing});

  @override
  ConsumerState<BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends ConsumerState<BudgetForm> {
  late String _categoryId;
  late TextEditingController _amountCtrl;
  bool _pinnedToMonth = false;
  String? _monthKey; // 'YYYY-MM' if pinned
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _categoryId = e?.category ?? Categories.expense.first.id;
    _amountCtrl = TextEditingController(
      text: e == null ? '' : e.amount.toStringAsFixed(0),
    );
    if (e?.monthKey != null) {
      _pinnedToMonth = true;
      _monthKey = e!.monthKey;
    } else {
      final now = DateTime.now();
      _monthKey = '${now.year.toString().padLeft(4, '0')}'
          '-${now.month.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_saving) return false;
    final amount = Money.parse(_amountCtrl.text);
    if (amount <= 0) return false;
    return true;
  }

  Future<void> _save() async {
    final amount = Money.parse(_amountCtrl.text);
    if (amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final notifier = ref.read(budgetsProvider.notifier);
      if (widget.existing == null) {
        await notifier.add(BudgetRecord(
          category: _categoryId,
          amount: amount,
          monthKey: _pinnedToMonth ? _monthKey : null,
          createdAt: now,
          updatedAt: now,
        ));
      } else {
        await notifier.edit(widget.existing!.copyWith(
          category: _categoryId,
          amount: amount,
          monthKey: _pinnedToMonth ? _monthKey : null,
          updatedAt: now,
        ));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null || existing.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: const Text('Delete budget?'),
        content: const Text(
            'This removes the cap for the category. Your transactions stay.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _saving = true);
    try {
      await ref.read(budgetsProvider.notifier).remove(existing.id!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  Future<void> _pickMonth() async {
    final init = _parseMonthKey(_monthKey) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select month',
    );
    if (picked == null) return;
    setState(() {
      _monthKey = '${picked.year.toString().padLeft(4, '0')}'
          '-${picked.month.toString().padLeft(2, '0')}';
    });
  }

  DateTime? _parseMonthKey(String? key) {
    if (key == null) return null;
    final parts = key.split('-');
    if (parts.length != 2) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null) return null;
    return DateTime(y, m, 1);
  }

  String _formatMonthKey(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null) return key;
    final d = DateTime(y, m, 1);
    return '${_monthName(d.month)} $y';
  }

  String _monthName(int m) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[(m - 1).clamp(0, 11)];
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + insets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            editing ? 'Edit budget' : 'New budget',
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 18),
          const _FieldLabel('Category'),
          SizedBox(
            height: 40,
            child: DropdownButtonFormField<String>(
              initialValue: _categoryId,
              dropdownColor: AppColors.surfaceContainerHigh,
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: AppColors.surfaceContainerHigh,
              ),
              items: [
                for (final c in Categories.expense)
                  DropdownMenuItem(
                    value: c.id,
                    child: Row(
                      children: [
                        Icon(c.icon, size: 16, color: c.color),
                        const SizedBox(width: 8),
                        Text(c.name,
                            style: const TextStyle(color: AppColors.onSurface)),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _categoryId = v);
              },
            ),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Monthly cap'),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: const TextStyle(
                color: AppColors.onSurface, fontSize: 18),
            decoration: const InputDecoration(
              hintText: '0',
              prefixText: '₱ ',
              prefixStyle: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Applies to'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _ScopeRow(
                  label: 'Every month (rolling)',
                  subtitle: 'Applies regardless of the calendar month.',
                  value: false,
                  selected: _pinnedToMonth,
                  onSelect: () =>
                      setState(() => _pinnedToMonth = false),
                ),
                _ScopeRow(
                  label: 'Specific month',
                  subtitle: 'Only counts toward the picked calendar month.',
                  value: true,
                  selected: _pinnedToMonth,
                  onSelect: () => setState(() => _pinnedToMonth = true),
                ),
                if (_pinnedToMonth)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 14, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 6),
                        TextButton(
                          onPressed: _pickMonth,
                          child: Text(
                            _monthKey == null
                                ? 'Choose month'
                                : _formatMonthKey(_monthKey!),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(
                    color: AppColors.error, fontSize: 12)),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              if (editing)
                IconButton(
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.error),
                  tooltip: 'Delete',
                ),
              const Spacer(),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _canSave ? _save : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(120, 46),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: AppColors.onPrimary),
                      )
                    : Text(editing ? 'Save' : 'Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ScopeRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final bool selected;
  final VoidCallback onSelect;
  const _ScopeRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.selected,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? AppColors.primary
                    : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : AppColors.outline,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.onSurfaceVariant, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
