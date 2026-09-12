import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_card.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../providers.dart';
import '../home/providers/home_providers.dart';
import 'widgets/account_tile.dart';

/// Result returned by [_AccountDialog]. Either an upsert payload
/// ([record]) or a delete intent ([deleteId]).
sealed class _AccountDialogResult {
  const _AccountDialogResult();
}

class _AccountUpsert extends _AccountDialogResult {
  final AccountRecord record;
  const _AccountUpsert(this.record);
}

class _AccountDelete extends _AccountDialogResult {
  final int id;
  const _AccountDelete(this.id);
}

/// Full CRUD view for the user's financial accounts. Grouped by
/// [AccountType] so the page mirrors the Home overview layout.
///
/// Adding/editing an account happens through a single [_AccountDialog]
/// that handles validation. All balances are entered manually — there is
/// no integration with banking APIs.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add account',
            onPressed: () => _openAccountDialog(context, ref),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Failed to load accounts: $e',
            style: const TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ),
        data: (accounts) {
          if (accounts.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No accounts yet',
              subtitle:
                  'Add your first account — bank, e-wallet, or cash — to start tracking your savings.',
              action: FilledButton.icon(
                onPressed: () => _openAccountDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add account'),
              ),
            );
          }

          // Group by AccountType, preserving a stable ordering.
          final groups = <AccountType, List<AccountRecord>>{};
          for (final t in AccountType.values) {
            groups[t] = [];
          }
          for (final a in accounts) {
            groups[AccountType.fromId(a.type)]!.add(a);
          }
          // Drop empty groups.
          groups.removeWhere((_, v) => v.isEmpty);

          final totalBalance = accounts.fold<double>(
            0,
            (acc, a) => acc + a.balance,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _TotalCard(accounts: accounts, totalBalance: totalBalance),
              const SizedBox(height: 12),
              for (final entry in groups.entries) ...[
                SectionCard(
                  title: entry.key.label,
                  subtitle:
                      '${entry.value.length} '
                      '${entry.value.length == 1 ? 'account' : 'accounts'}',
                  trailing: IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    color: AppColors.primary,
                    onPressed: () =>
                        _openAccountDialog(context, ref, presetType: entry.key),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < entry.value.length; i++) ...[
                        AccountTile(
                          account: entry.value[i],
                          onTap: () => _openAccountDialog(
                            context,
                            ref,
                            existing: entry.value[i],
                          ),
                        ),
                        if (i < entry.value.length - 1)
                          const Divider(
                            color: AppColors.outline,
                            height: 1,
                            thickness: 1,
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
      floatingActionButton: accountsAsync.maybeWhen(
        data: (accounts) => accounts.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _openAccountDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add account'),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
        orElse: () => null,
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final List<AccountRecord> accounts;
  final double totalBalance;
  const _TotalCard({required this.accounts, required this.totalBalance});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      background: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Savings',
                  style: TextStyle(
                    color: Color(0xFFC7F0D3),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Money.format(totalBalance),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Across ${accounts.length} '
                  '${accounts.length == 1 ? 'account' : 'accounts'}',
                  style: const TextStyle(
                    color: Color(0xFFC7F0D3),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF15803D),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.account_balance_wallet,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the add/edit account dialog. Persists the result via the
/// [accountsProvider] notifier and invalidates the home summary so the
/// total savings figure stays in sync.
Future<void> _openAccountDialog(
  BuildContext context,
  WidgetRef ref, {
  AccountRecord? existing,
  AccountType? presetType,
}) async {
  final result = await showDialog<_AccountDialogResult>(
    context: context,
    builder: (_) => _AccountDialog(existing: existing, presetType: presetType),
  );
  if (result == null) return;

  if (!context.mounted) return;
  try {
  final notifier = ref.read(accountsProvider.notifier);
  if (result is _AccountUpsert) {
    if (existing == null) {
      await notifier.add(result.record);
    } else {
      await notifier.edit(result.record);
    }
  } else if (result is _AccountDelete) {
    await notifier.remove(result.id);
  }
  // Recompute the home summary so streaks and insights stay in sync.
  ref.invalidate(homeSummaryProvider);
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save account: $e')));
  }
}

/// Add/edit dialog. Pure UI — returns an [_AccountDialogResult] the caller
/// applies (upsert or delete). Validation is enforced here.
class _AccountDialog extends StatefulWidget {
  final AccountRecord? existing;
  final AccountType? presetType;
  const _AccountDialog({this.existing, this.presetType});

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  static const _swatches = <Color>[
    Color(0xFF22C55E), // green
    Color(0xFF3B82F6), // blue
    Color(0xFFA855F7), // purple
    Color(0xFF14B8A6), // teal
    Color(0xFFEAB308), // yellow
    Color(0xFFEF4444), // red
    Color(0xFFEC4899), // pink
    Color(0xFF6B7280), // grey
  ];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _balanceCtrl;
  late AccountType _type;
  late Color _color;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _balanceCtrl = TextEditingController(
      text: e != null && e.balance != 0 ? e.balance.toStringAsFixed(2) : '',
    );
    _type = e != null
        ? AccountType.fromId(e.type)
        : (widget.presetType ?? AccountType.cash);
    _color = e != null ? _parseHex(e.color) : _type.color;
  }

  Color _parseHex(String raw) {
    final r = raw.replaceAll('#', '');
    final v = int.tryParse('FF$r', radix: 16);
    return v == null ? _type.color : Color(v);
  }

  String _toHex(Color c) {
    final argb = c.toARGB32() & 0xFFFFFF; // drop the alpha channel
    return argb.toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account name is required')));
      return;
    }
    final raw = _balanceCtrl.text.replaceAll(',', '').trim();
    final balance = raw.isEmpty ? 0.0 : double.tryParse(raw);
    if (balance == null || !balance.isFinite) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid balance')));
      return;
    }
    final record = AccountRecord(
      id: widget.existing?.id,
      name: name,
      type: _type.id,
      balance: balance,
      color: '#${_toHex(_color)}',
      sortOrder: widget.existing?.sortOrder ?? 0,
    );
    Navigator.pop(context, _AccountUpsert(record));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainer,
      title: Text(isEdit ? 'Edit account' : 'Add account'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: !isEdit,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Account name',
                hintText: 'e.g. GCash, Maya, BPI Savings',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AccountType>(
              initialValue: _type,
              dropdownColor: AppColors.surfaceContainerHigh,
              decoration: const InputDecoration(labelText: 'Account type'),
              items: [
                for (final t in AccountType.values)
                  DropdownMenuItem(
                    value: t,
                    child: Row(
                      children: [
                        Icon(t.icon, size: 18, color: t.color),
                        const SizedBox(width: 8),
                        Text(t.label),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _balanceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Current balance',
                hintText: '0',
                prefixText: '${Money.symbol} ',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Color',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final swatch in _swatches)
                  GestureDetector(
                    onTap: () => setState(() => _color = swatch),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: swatch,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color.toARGB32() == swatch.toARGB32()
                              ? Colors.white
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (isEdit)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => _confirmDelete(context),
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: Text(isEdit ? 'Save' : 'Add')),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: const Text('Delete account?'),
        content: Text(
          '"${widget.existing!.name}" will be removed. '
          'Existing transactions that reference it will keep the name '
          'as plain text.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    Navigator.pop(context, _AccountDelete(widget.existing!.id!));
  }
}
