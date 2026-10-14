import '../../core/widgets/app_ui.dart';
import 'widgets/category_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/categories.dart';
import '../../core/utils/date_utils.dart';

import '../../core/utils/money.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../providers.dart';

/// Read-only detail view for a single transaction, with edit + delete actions.
/// Editing an existing transaction appends a row to `transaction_revisions`.
class TransactionDetailScreen extends ConsumerWidget {
  final int transactionId;
  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: [
          txsAsync.maybeWhen(
            data: (list) {
              final tx = list.where((t) => t.id == transactionId).firstOrNull;
              if (tx == null) return const SizedBox.shrink();
              return Row(
                children: [
                  if (tx.type != TxType.transfer)
                    AsyncAction(
                      action: () => _editTx(context, ref, tx),
                      builder: (busy, run) => IconButton(
                        tooltip: 'Edit transaction',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: busy ? null : run,
                      ),
                    ),
                  AsyncAction(
                    action: () => _confirmDelete(context, ref, tx),
                    builder: (busy, run) => IconButton(
                      tooltip: 'Delete transaction',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: busy ? null : run,
                    ),
                  ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: txsAsync.when(
        data: (list) {
          final tx = list.where((t) => t.id == transactionId).firstOrNull;
          if (tx == null) {
            return const Center(child: Text('Transaction not found'));
          }
          return _DetailBody(tx: tx);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _editTx(BuildContext context, WidgetRef ref, TxRecord tx) async {
    final newTx = await showModalBottomSheet<TxRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditTransactionSheet(tx: tx),
    );
    if (newTx == null) return;
    final old = tx;
    try {
      await ref.read(transactionsProvider.notifier).edit(old, newTx);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update transaction. Please try again.'),
          ),
        );
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transaction updated')));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TxRecord tx,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: const Text('Delete transaction?'),
        content: Text(
          tx.type == TxType.transfer
              ? 'Reverse this transfer in both accounts? The receiving account must still have enough money.'
              : 'This reverses the balance change and updates your totals.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || tx.id == null) return;

    try {
      await ref.read(transactionsProvider.notifier).remove(tx.id!);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not reverse this transaction. Check available funds.',
            ),
          ),
        );
      }
      return;
    }
    if (context.mounted) {
      context.pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transaction deleted')));
    }
  }
}

class _DetailBody extends StatelessWidget {
  final TxRecord tx;
  const _DetailBody({required this.tx});

  @override
  Widget build(BuildContext context) {
    final cat = Categories.resolve(context, tx.category);
    final isIncome = tx.type == TxType.income;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (tx.type == TxType.transfer)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '${tx.account} → ${tx.destinationAccount}\nTransfers move money between your accounts without changing income or expenses. Delete to reverse both sides, then record a replacement if needed.',
            ),
          ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(cat.icon, color: cat.color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                tx.type == TxType.transfer ? 'Transfer' : cat.name,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${tx.type == TxType.transfer
                    ? '↔ '
                    : isIncome
                    ? '+'
                    : '-'}${Money.of(context).format(tx.amount)}',
                style: TextStyle(
                  color: tx.type == TxType.transfer
                      ? const Color(0xFF3B82F6)
                      : isIncome
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _DetailRow(label: 'Type', value: tx.type.label),
        _DetailRow(label: 'Category', value: cat.name),
        _DetailRow(label: 'Account', value: tx.account),
        _DetailRow(label: 'Date', value: D.fullDate(tx.occurredAt)),
        _DetailRow(label: 'Time', value: D.time(tx.occurredAt)),
        if ((tx.notes ?? '').isNotEmpty)
          _DetailRow(label: 'Notes', value: tx.notes!),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight edit sheet — quick way to update amount/notes.
class _EditTransactionSheet extends StatefulWidget {
  final TxRecord tx;
  const _EditTransactionSheet({required this.tx});
  @override
  State<_EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<_EditTransactionSheet> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _tagsCtrl;
  late DateTime _date;
  late String _categoryId;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.tx.amount.toStringAsFixed(2),
    );
    _notesCtrl = TextEditingController(text: widget.tx.notes ?? '');
    _tagsCtrl = TextEditingController(text: widget.tx.tags ?? '');
    _date = widget.tx.occurredAt;
    _categoryId = widget.tx.category;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        amount > 999999999.99 ||
        (amount * 100 - (amount * 100).round()).abs() > .00001) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a positive amount with at most two decimal places',
          ),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      widget.tx.copyWith(
        amount: amount,
        category: _categoryId,
        occurredAt: _date,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        tags: _tagsCtrl.text.trim().isEmpty ? null : _tagsCtrl.text.trim(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Edit Transaction',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 12),
              CategoryPicker(
                kind: widget.tx.type.name,
                selected: _categoryId,
                onChanged: (id) => setState(() => _categoryId = id),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tagsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma separated)',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: const Text('Save Changes')),
            ],
          ),
        ),
      ),
    );
  }
}
