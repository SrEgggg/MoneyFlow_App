import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/money.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../providers.dart';

class MoneyMovementDialog extends ConsumerStatefulWidget {
  final List<AccountRecord> accounts;
  const MoneyMovementDialog({super.key, required this.accounts});
  @override
  ConsumerState<MoneyMovementDialog> createState() =>
      _MoneyMovementDialogState();
}

class _MoneyMovementDialogState extends ConsumerState<MoneyMovementDialog> {
  final _amount = TextEditingController();
  TxType _type = TxType.transfer;
  late String _source = widget.accounts.first.name;
  String? _destination;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        amount > 999999999.99) {
      setState(() => _error = 'Enter an amount from 0.01 to 999,999,999.99.');
      return;
    }
    if (_type == TxType.transfer &&
        (_destination == null || _destination == _source)) {
      setState(() => _error = 'Choose two different accounts.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_type != TxType.income) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(
              _type == TxType.transfer
                  ? 'Confirm transfer'
                  : 'Confirm withdrawal',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_source, style: Theme.of(c).textTheme.titleMedium),
                  if (_type == TxType.transfer) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Icon(
                        Icons.arrow_downward,
                        color: Color(0xFF3B82F6),
                        semanticLabel: 'To',
                      ),
                    ),
                    Text(
                      _destination!,
                      style: Theme.of(c).textTheme.titleMedium,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    Money.of(context).format(amount),
                    style: Theme.of(c).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _type == TxType.transfer
                        ? 'Moves money between your accounts. Income and expenses stay unchanged.'
                        : 'This deducts money from your account and records an expense.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          if (mounted) setState(() => _saving = false);
          return;
        }
      }
      final now = DateTime.now();
      await ref
          .read(transactionsProvider.notifier)
          .moveMoney(
            TxRecord(
              amount: amount,
              type: _type,
              category: _type == TxType.transfer
                  ? 'transfer'
                  : _type == TxType.income
                  ? 'other_income'
                  : 'other_expense',
              account: _source,
              destinationAccount: _type == TxType.transfer
                  ? _destination
                  : null,
              occurredAt: now,
              createdAt: now,
              updatedAt: now,
              notes: _type == TxType.income
                  ? 'Account deposit'
                  : _type == TxType.expense
                  ? 'Account withdrawal'
                  : 'Account transfer',
            ),
          );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Money movement recorded.')),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Invalid argument(s): ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.accounts.isEmpty ||
          widget.accounts
                  .map((a) => a.name.trim().toLowerCase())
                  .toSet()
                  .length !=
              widget.accounts.length
      ? AlertDialog(
          title: const Text('Review your accounts'),
          content: const Text(
            'Add an account or rename duplicate accounts before moving money.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        )
      : AlertDialog(
          title: const Text('Move money'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<TxType>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Action'),
                    items: const [
                      DropdownMenuItem(
                        value: TxType.income,
                        child: Text('Deposit'),
                      ),
                      DropdownMenuItem(
                        value: TxType.expense,
                        child: Text('Withdraw'),
                      ),
                      DropdownMenuItem(
                        value: TxType.transfer,
                        child: Text('Transfer / move'),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _source,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _type == TxType.income
                          ? 'To account'
                          : 'From account',
                    ),
                    items: [
                      for (final a in widget.accounts)
                        DropdownMenuItem(
                          value: a.name,
                          child: Text(a.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _source = v!),
                  ),
                  if (_type == TxType.transfer) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _destination,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'To account',
                      ),
                      items: [
                        for (final a in widget.accounts)
                          DropdownMenuItem(
                            value: a.name,
                            child: Text(
                              a.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _destination = v),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amount,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}$'),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '${Money.of(context).symbol} ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Transfers move existing money. Deposits add income; withdrawals record expenses.',
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Continue'),
            ),
          ],
        );
}
