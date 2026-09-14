import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/categories.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/budget.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers.dart';

/// Add / edit a recurring transaction rule.
class RecurringForm extends ConsumerStatefulWidget {
  final RecurringTransactionRecord? existing;
  final List<AccountRecord> accounts;

  const RecurringForm({super.key, this.existing, required this.accounts});

  @override
  ConsumerState<RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends ConsumerState<RecurringForm> {
  late TextEditingController _nameCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _intervalCtrl;
  late TextEditingController _notesCtrl;

  late TxType _type;
  late String _categoryId;
  String? _accountId;
  late RecurringFrequency _frequency;
  late DateTime _startDate;
  DateTime? _endDate;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _amountCtrl = TextEditingController(
      text: e == null ? '' : e.amount.toStringAsFixed(2),
    );
    _intervalCtrl = TextEditingController(
      text: (e?.intervalCount ?? 1).toString(),
    );
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _type = e?.type ?? TxType.expense;
    _categoryId = e?.category ?? Categories.expense.first.id;
    _accountId =
        e?.account ??
        (widget.accounts.isNotEmpty ? widget.accounts.first.name : null);
    _frequency = e?.frequency ?? RecurringFrequency.monthly;
    _startDate = e?.startDate ?? DateTime.now();
    _endDate = e?.endDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _intervalCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_saving) return false;
    if (_nameCtrl.text.trim().isEmpty) return false;
    final amount = Money.parse(_amountCtrl.text);
    if (!amount.isFinite || amount <= 0 || amount > 999999999.99) return false;
    if (_accountId == null) return false;
    final interval = int.tryParse(_intervalCtrl.text.trim()) ?? 0;
    if (interval < 1 || interval > 120) return false;
    return true;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_canSave) {
      setState(
        () => _error =
            'Enter a name, a valid positive amount, an account and an interval from 1 to 120.',
      );
      return;
    }
    final amount = Money.parse(_amountCtrl.text);
    final interval = int.tryParse(_intervalCtrl.text.trim()) ?? 1;
    if (_accountId == null) {
      setState(() => _error = 'Pick an account.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final notifier = ref.read(recurringProvider.notifier);
      if (widget.existing == null) {
        await notifier.add(
          RecurringTransactionRecord(
            name: _nameCtrl.text.trim(),
            amount: amount,
            type: _type,
            category: _categoryId,
            account: _accountId!,
            frequency: _frequency,
            intervalCount: interval,
            startDate: _startDate,
            endDate: _endDate,
            nextRunAt: _startDate,
            lastRunAt: null,
            isActive: true,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await notifier.edit(
          widget.existing!.copyWith(
            name: _nameCtrl.text.trim(),
            amount: amount,
            type: _type,
            category: _categoryId,
            account: _accountId,
            frequency: _frequency,
            intervalCount: interval,
            startDate: _startDate,
            endDate: _endDate,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
            updatedAt: now,
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
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
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: const Text('Delete rule?'),
        content: const Text(
          'Removes the rule. Past transactions it created stay in your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(recurringProvider.notifier).remove(existing.id!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  Future<void> _toggleActive() async {
    final existing = widget.existing;
    if (existing == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(recurringProvider.notifier).toggle(existing);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not update the rule: $error';
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final init = isStart ? _startDate : (_endDate ?? _startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: isStart ? 'Start date' : 'End date (optional)',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      } else {
        _endDate = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final editing = widget.existing != null;
    final categories = _type == TxType.income
        ? Categories.income
        : Categories.expense;
    if (!categories.any((c) => c.id == _categoryId)) {
      _categoryId = categories.first.id;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + insets.bottom),
      child: SingleChildScrollView(
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
              editing ? 'Edit recurring rule' : 'New recurring rule',
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 18),

            // Name
            const _Label(text: 'Name'),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Salary, Netflix, Rent',
              ),
              style: const TextStyle(color: AppColors.onSurface),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Type toggle
            const _Label(text: 'Type'),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _MiniToggle(
                    label: 'Income',
                    icon: Icons.arrow_upward,
                    active: _type == TxType.income,
                    color: AppColors.primary,
                    onTap: () => setState(() {
                      _type = TxType.income;
                      _categoryId = Categories.income.first.id;
                    }),
                  ),
                  _MiniToggle(
                    label: 'Expense',
                    icon: Icons.arrow_downward,
                    active: _type == TxType.expense,
                    color: AppColors.error,
                    onTap: () => setState(() {
                      _type = TxType.expense;
                      _categoryId = Categories.expense.first.id;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Amount
            const _Label(text: 'Amount'),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: const TextStyle(color: AppColors.onSurface, fontSize: 18),
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

            // Category
            const _Label(text: 'Category'),
            SizedBox(
              height: 40,
              child: DropdownButtonFormField<String>(
                initialValue: _categoryId,
                dropdownColor: AppColors.surfaceContainerHigh,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceContainerHigh,
                ),
                items: [
                  for (final c in categories)
                    DropdownMenuItem(
                      value: c.id,
                      child: Row(
                        children: [
                          Icon(c.icon, size: 16, color: c.color),
                          const SizedBox(width: 8),
                          Text(
                            c.name,
                            style: const TextStyle(color: AppColors.onSurface),
                          ),
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

            // Account
            const _Label(text: 'Account'),
            SizedBox(
              height: 40,
              child: DropdownButtonFormField<String>(
                initialValue: _accountId,
                dropdownColor: AppColors.surfaceContainerHigh,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceContainerHigh,
                ),
                items: [
                  for (final a in widget.accounts)
                    DropdownMenuItem(
                      value: a.name,
                      child: Text(
                        a.name,
                        style: const TextStyle(color: AppColors.onSurface),
                      ),
                    ),
                ],
                onChanged: widget.accounts.isEmpty
                    ? null
                    : (v) => setState(() => _accountId = v),
              ),
            ),
            const SizedBox(height: 16),

            // Frequency + interval
            const _Label(text: 'Cadence'),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<RecurringFrequency>(
                    initialValue: _frequency,
                    dropdownColor: AppColors.surfaceContainerHigh,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceContainerHigh,
                    ),
                    items: [
                      for (final f in RecurringFrequency.values)
                        DropdownMenuItem(
                          value: f,
                          child: Text(
                            f.label,
                            style: const TextStyle(color: AppColors.onSurface),
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _frequency = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _intervalCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: AppColors.onSurface),
                    decoration: const InputDecoration(hintText: '1'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Start + end date
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Starts',
                    value: D.fullDate(_startDate),
                    onTap: () => _pickDate(isStart: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateField(
                    label: 'Ends (optional)',
                    value: _endDate == null ? 'No end' : D.fullDate(_endDate!),
                    onTap: () => _pickDate(isStart: false),
                    onClear: _endDate == null
                        ? null
                        : () => setState(() => _endDate = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Notes
            const _Label(text: 'Notes (optional)'),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'Add a note…',
                counterText: '',
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (editing)
                  IconButton(
                    onPressed: _saving ? null : _delete,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                    tooltip: 'Delete',
                  ),
                if (editing)
                  IconButton(
                    onPressed: _saving ? null : _toggleActive,
                    icon: Icon(
                      widget.existing!.isActive
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: AppColors.primary,
                    ),
                    tooltip: widget.existing!.isActive
                        ? 'Pause rule'
                        : 'Resume rule',
                  ),
                const Spacer(),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.pop(context, false),
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
                            strokeWidth: 2.4,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : Text(editing ? 'Save' : 'Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});
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

class _MiniToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _MiniToggle({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active ? color : AppColors.onSurfaceVariant,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? color : AppColors.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
