import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/categories.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/financial_day.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers.dart';

/// Quick-Add form. Optimized for under-3-second entry:
/// - Type toggle is a single tap
/// - Amount is auto-focused on open
/// - Category is a wrap of large tap targets
/// - Save is one tap, then the form resets for the next entry
class QuickAddForm extends ConsumerStatefulWidget {
  final List<AccountRecord> accounts;
  final VoidCallback onSaved;

  const QuickAddForm({
    super.key,
    required this.accounts,
    required this.onSaved,
  });

  @override
  ConsumerState<QuickAddForm> createState() => _QuickAddFormState();
}

class _QuickAddFormState extends ConsumerState<QuickAddForm> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _amountFocus = FocusNode();
  TxType _type = TxType.expense;
  String? _categoryId;
  String? _accountId;
  bool _saving = false;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Default account = first one
    if (widget.accounts.isNotEmpty) {
      _accountId = widget.accounts.first.name;
    }
    // Default category
    _categoryId = Categories.expense.first.id;
    // Focus amount field on next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _amountFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _setType(TxType t) {
    setState(() {
      _type = t;
      _categoryId = (t == TxType.income ? Categories.income : Categories.expense)
          .first
          .id;
    });
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _showError('Enter a valid amount');
      return;
    }
    if (_categoryId == null) {
      _showError('Pick a category');
      return;
    }
    if (_accountId == null) {
      _showError('Pick an account');
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final tx = TxRecord(
      amount: amount,
      type: _type,
      category: _categoryId!,
      account: _accountId!,
      occurredAt: _date,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      tags: null,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await ref.read(transactionsProvider.notifier).add(tx);
      // Trigger recalc
      await ref.read(recalcServiceProvider).recomputeFrom(FinancialDay.key(_date));
      if (!mounted) return;
      // Reset for next entry
      _amountCtrl.clear();
      _notesCtrl.clear();
      setState(() {
        _saving = false;
        _date = DateTime.now();
      });
      _amountFocus.requestFocus();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${_type == TxType.income ? 'Income' : 'Expense'} saved: ${Money.compact(amount)}'),
          duration: const Duration(seconds: 1),
          backgroundColor: AppColors.surfaceContainerHigh,
        ),
      );
    } catch (e) {
      setState(() => _saving = false);
      _showError('Could not save: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
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
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        _type == TxType.income ? Categories.income : Categories.expense;
    if (_categoryId != null &&
        !categories.any((c) => c.id == _categoryId)) {
      _categoryId = categories.first.id;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Type toggle
        _TypeToggle(
          value: _type,
          onChanged: _setType,
        ),
        const SizedBox(height: 16),

        // Amount
        TextField(
          controller: _amountCtrl,
          focusNode: _amountFocus,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.onSurface,
            fontSize: 36,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          decoration: InputDecoration(
            hintText: '0.00',
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 24, right: 8),
              child: Text(
                '₱',
                style: TextStyle(
                  color: _type == TxType.income
                      ? AppColors.primary
                      : AppColors.error,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
          ),
        ),
        const SizedBox(height: 20),

        // Category grid
        const _Label(text: 'Category'),
        const SizedBox(height: 8),
        _CategoryGrid(
          categories: categories,
          selected: _categoryId,
          onSelect: (id) => setState(() => _categoryId = id),
        ),
        const SizedBox(height: 20),

        // Account selector
        const _Label(text: 'Account'),
        const SizedBox(height: 8),
        _AccountChips(
          accounts: widget.accounts,
          selected: _accountId,
          onSelect: (name) => setState(() => _accountId = name),
        ),
        const SizedBox(height: 20),

        // Date
        const _Label(text: 'Date'),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDate,
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
                Text(
                  D.fullDate(_date),
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right,
                    color: AppColors.onSurfaceVariant),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Notes
        const _Label(text: 'Notes (optional)'),
        const SizedBox(height: 8),
        TextField(
          controller: _notesCtrl,
          maxLines: 2,
          maxLength: 200,
          decoration: const InputDecoration(
            hintText: 'Add a note…',
            counterText: '',
          ),
        ),
        const SizedBox(height: 24),

        // Save
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              : const Icon(Icons.check, size: 20),
          label: Text(_saving
              ? 'Saving…'
              : 'Save ${_type == TxType.income ? 'Income' : 'Expense'}'),
        ),
      ],
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

class _TypeToggle extends StatelessWidget {
  final TxType value;
  final ValueChanged<TxType> onChanged;
  const _TypeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'Income',
            icon: Icons.arrow_upward,
            active: value == TxType.income,
            color: AppColors.primary,
            onTap: () => onChanged(TxType.income),
          ),
          _Tab(
            label: 'Expense',
            icon: Icons.arrow_downward,
            active: value == TxType.expense,
            color: AppColors.error,
            onTap: () => onChanged(TxType.expense),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _Tab({
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: active ? color : AppColors.onSurfaceVariant, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? color : AppColors.onSurfaceVariant,
                  fontSize: 14,
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

class _CategoryGrid extends StatelessWidget {
  final List<TxCategory> categories;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _CategoryGrid({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in categories)
          _CategoryChip(
            cat: c,
            active: c.id == selected,
            onTap: () => onSelect(c.id),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final TxCategory cat;
  final bool active;
  final VoidCallback onTap;
  const _CategoryChip({
    required this.cat,
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
          color: active ? cat.color.withValues(alpha: 0.18) : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? cat.color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cat.icon,
                color: active ? cat.color : AppColors.onSurfaceVariant,
                size: 16),
            const SizedBox(width: 6),
            Text(
              cat.name,
              style: TextStyle(
                color: active ? cat.color : AppColors.onSurface,
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

class _AccountChips extends StatelessWidget {
  final List<AccountRecord> accounts;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _AccountChips({
    required this.accounts,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return const Text(
        'No accounts yet. Add one in Settings.',
        style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in accounts)
          _AccountChip(
            account: a,
            active: a.name == selected,
            onTap: () => onSelect(a.name),
          ),
      ],
    );
  }
}

class _AccountChip extends StatelessWidget {
  final AccountRecord account;
  final bool active;
  final VoidCallback onTap;
  const _AccountChip({
    required this.account,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final color = _parseHex(account.color);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.18)
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account.name,
              style: TextStyle(
                color: active ? color : AppColors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              Money.compact(account.balance),
              style: TextStyle(
                color: active ? color : AppColors.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}
