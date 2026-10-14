import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import 'category_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/categories.dart';
import '../../../core/utils/date_utils.dart';

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
  final DateTime? initialDate;
  final TxType initialType;

  const QuickAddForm({
    super.key,
    required this.accounts,
    required this.onSaved,
    this.initialDate,
    this.initialType = TxType.expense,
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
    _type = widget.initialType;
    _date = widget.initialDate ?? DateTime.now();
    // Default account = first one
    if (widget.accounts.isNotEmpty) {
      _accountId = widget.accounts.first.name;
    }
    // Default category
    _categoryId = Categories.all(kind: _type.name).first.id;
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
      _categoryId =
          (t == TxType.income ? Categories.income : Categories.expense)
              .first
              .id;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        amount > 999999999.99) {
      _showError('Enter an amount from 0.01 to 999,999,999.99.');
      return;
    }
    if (_categoryId == null) {
      _showError('Pick a category');
      return;
    }
    if (_accountId == null ||
        !widget.accounts.any((a) => a.name == _accountId)) {
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
      final notifier = ref.read(transactionsProvider.notifier);
      final id = await notifier.add(tx);
      // Trigger recalc
      if (!mounted) return;
      // Reset for next entry
      _amountCtrl.clear();
      _notesCtrl.clear();
      setState(() {
        _saving = false;
        _date = DateTime.now();
      });
      _amountFocus.unfocus();
      final messenger = ScaffoldMessenger.of(context);
      final categoryName = Categories.resolve(context, tx.category).name;
      final formatted = Money.of(context).format(amount);
      var undoing = false;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${tx.type == TxType.income ? 'Income' : 'Expense'} added\n$formatted • $categoryName',
          ),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              if (undoing) return;
              undoing = true;
              try {
                await notifier.undoAdded(tx.copyWith(id: id));
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Transaction undone. Balance updated.'),
                  ),
                );
              } catch (_) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not undo. The entry may have changed or its funds may be in use. Review History.',
                    ),
                  ),
                );
              }
            },
          ),
        ),
      );
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError('Could not finish saving. Check History before trying again.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
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
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final categories = Categories.available(context, _type.name);
    if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) {
      _categoryId = categories.first.id;
    }

    if (widget.accounts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add an account before recording money.'),
            TextButton(
              onPressed: () => context.push(Routes.accounts),
              child: const Text('Add account'),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // Type toggle
              _TypeToggle(
                value: _type,
                onChanged: (type) {
                  if (!_saving) _setType(type);
                },
              ),
              const SizedBox(height: 16),

              // Amount
              TextField(
                controller: _amountCtrl,
                enabled: !_saving,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _amountFocus.unfocus(),
                focusNode: _amountFocus,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                textAlign: TextAlign.start,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  labelText: 'Amount',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 24, right: 8),
                    child: Text(
                      Money.of(context).symbol,
                      style: TextStyle(
                        color: _type == TxType.income
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Account selector
              const _Label(text: 'Account'),
              const SizedBox(height: 8),
              _AccountChips(
                accounts: widget.accounts,
                selected: _accountId,
                onSelect: (name) {
                  if (!_saving) setState(() => _accountId = name);
                },
              ),
              const SizedBox(height: 24),

              // Date
              const _Label(text: 'Date'),
              const SizedBox(height: 8),
              InkWell(
                onTap: _saving ? null : _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
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
                          D.fullDate(_date),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Category grid
              const _Label(text: 'Category'),
              const SizedBox(height: 8),
              CategoryPicker(
                kind: _type.name,
                selected: _categoryId,
                onChanged: (id) {
                  if (!_saving) setState(() => _categoryId = id);
                },
              ),
              const SizedBox(height: 24),

              ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: EdgeInsets.zero,
                title: const Text('Add a note (optional)'),
                children: [
                  TextField(
                    controller: _notesCtrl,
                    enabled: !_saving,
                    maxLines: 2,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      hintText: 'Add a note…',
                      counterText: '',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
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
                label: Text(
                  _saving
                      ? 'Saving…'
                      : 'Save ${_type == TxType.income ? 'Income' : 'Expense'}',
                ),
              ),
            ),
          ),
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
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'Income',
            icon: Icons.arrow_upward,
            active: value == TxType.income,
            color: Theme.of(context).colorScheme.primary,
            onTap: () => onChanged(TxType.income),
          ),
          _Tab(
            label: 'Expense',
            icon: Icons.arrow_downward,
            active: value == TxType.expense,
            color: Theme.of(context).colorScheme.error,
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
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      selected: active,
      button: true,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: active
              ? color.withValues(alpha: .14)
              : Colors.transparent,
          foregroundColor: active
              ? color
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [Icon(icon, size: 20), Text(label)],
        ),
      ),
    ),
  );
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
      return Text(
        'No accounts yet. Add one in Accounts.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
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
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.18)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
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
                color: active ? color : Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              Money.of(context).compact(account.balance),
              style: TextStyle(
                color: active
                    ? color
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
