import '../../core/utils/money_amount.dart';
import '../../core/widgets/app_ui.dart';
import 'money_movement_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});
  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _busy = false;
  Future<void> _open(
    BuildContext context,
    WidgetRef ref, {
    AccountRecord? existing,
    AccountType? presetType,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _openAccountDialog(
        context,
        ref,
        existing: existing,
        presetType: presetType,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this account. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add account',
            onPressed: _busy ? null : () => _open(context, ref),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const LoadingPlaceholder(lines: 4),
        error: (_, __) => InlineNotice(
          message:
              'Could not load accounts. Your saved balances have not been changed.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(accountsProvider),
        ),
        data: (accounts) {
          if (accounts.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No accounts yet',
              subtitle:
                  'Use the + button above to add a bank account, e-wallet or cash wallet.',
            );
          }

          final totalBalance = accounts.fold<double>(
            0,
            (acc, a) => acc + a.balance,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (accounts
                      .map((a) => a.name.trim().toLowerCase())
                      .toSet()
                      .length !=
                  accounts.length)
                const InlineNotice(
                  message:
                      'Some accounts share a name. Rename them before recording money. Existing history keeps the original name; no accounts are merged.',
                ),
              _TotalCard(accounts: accounts, totalBalance: totalBalance),
              const SizedBox(height: 12),
              AsyncAction(
                action: () => showDialog<void>(
                  context: context,
                  builder: (_) => MoneyMovementDialog(accounts: accounts),
                ),
                builder: (busy, run) => FilledButton.icon(
                  onPressed: busy ? null : run,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Move money'),
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Your accounts',
                child: Column(
                  children: [
                    for (var i = 0; i < accounts.length; i++) ...[
                      AccountTile(
                        account: accounts[i],
                        onTap: _busy
                            ? null
                            : () => _open(context, ref, existing: accounts[i]),
                      ),
                      if (i < accounts.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
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
      background: Theme.of(context).colorScheme.surfaceContainer,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Balance',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Money.of(context).format(totalBalance),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
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
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
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
  final linked =
      existing != null &&
      await ref.read(accountRepoProvider).hasLinkedRecords(existing.name);
  if (!context.mounted) return;
  final result = await showDialog<_AccountDialogResult>(
    context: context,
    builder: (_) => _AccountDialog(
      existing: existing,
      presetType: presetType,
      accounts: ref.read(accountsProvider).valueOrNull ?? [],
      hasLinkedRecords: linked,
    ),
  );
  if (result == null) return;

  if (!context.mounted) return;
  try {
    final notifier = ref.read(accountsProvider.notifier);
    if (result is _AccountUpsert) {
      if (existing == null) {
        await notifier.add(result.record);
      } else {
        await notifier.edit(result.record, expectedBalance: existing.balance);
      }
    } else if (result is _AccountDelete) {
      await notifier.remove(result.id);
    }
    // Recompute the home summary so streaks and insights stay in sync.
    ref.invalidate(homeSummaryProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result is _AccountDelete
                ? 'Account deleted'
                : existing == null
                ? 'Account added'
                : 'Account updated',
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save account: $e')));
    }
  }
}

/// Add/edit dialog. Pure UI — returns an [_AccountDialogResult] the caller
/// applies (upsert or delete). Validation is enforced here.
class _AccountDialog extends StatefulWidget {
  final AccountRecord? existing;
  final AccountType? presetType;
  final List<AccountRecord> accounts;
  final bool hasLinkedRecords;
  const _AccountDialog({
    this.existing,
    this.presetType,
    required this.accounts,
    required this.hasLinkedRecords,
  });

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
  bool _confirming = false;
  bool _submitted = false;

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

  Future<void> _save() async {
    if (_confirming || _submitted) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account name is required')));
      return;
    }
    if (widget.accounts.any(
      (a) =>
          a.id != widget.existing?.id &&
          a.name.trim().toLowerCase() == name.toLowerCase(),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a unique account name.')),
      );
      return;
    }
    final raw = _balanceCtrl.text.replaceAll(',', '').trim();
    final balance = raw.isEmpty ? 0.0 : double.tryParse(raw);
    if (balance == null || !MoneyAmount.valid(balance, signed: true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use up to 999,999,999.99 and at most two decimal places',
          ),
        ),
      );
      return;
    }
    if (widget.existing != null && balance != widget.existing!.balance) {
      setState(() => _confirming = true);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Correct account balance?'),
          content: const Text(
            'This replaces the recorded balance without adding income or expenses. Use Move money for normal deposits, withdrawals and transfers.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Correct balance'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() => _confirming = false);
      if (confirmed != true) return;
    }
    final record = AccountRecord(
      id: widget.existing?.id,
      name: name,
      type: _type.id,
      balance: balance,
      color: '#${_toHex(_color)}',
      sortOrder: widget.existing?.sortOrder ?? 0,
    );
    _submitted = true;
    Navigator.pop(context, _AccountUpsert(record));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
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
              dropdownColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
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
                prefixText: '${Money.of(context).symbol} ',
              ),
            ),
            const SizedBox(height: 16),
            if (widget.hasLinkedRecords)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'This account has linked history or recurring rules. Deletion is unavailable; your records are kept.',
                ),
              ),
            Text(
              'Color',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < _swatches.length; i++)
                  Semantics(
                    label: const [
                      'Green',
                      'Blue',
                      'Purple',
                      'Teal',
                      'Yellow',
                      'Red',
                      'Pink',
                      'Gray',
                    ][i],
                    button: true,
                    selected: _color.toARGB32() == _swatches[i].toARGB32(),
                    child: InkWell(
                      onTap: () => setState(() => _color = _swatches[i]),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _swatches[i],
                              shape: BoxShape.circle,
                            ),
                            child: _color.toARGB32() == _swatches[i].toARGB32()
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.black,
                                    size: 22,
                                  )
                                : null,
                          ),
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
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: widget.hasLinkedRecords
                ? null
                : () => _confirmDelete(context),
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
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: const Text('Delete account?'),
        content: Text(
          '"${widget.existing!.name}" will be removed. '
          'Deletion is blocked when transactions or recurring rules still reference this account. Your history will not be deleted.',
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
    if (ok != true) return;
    if (!context.mounted) return;
    Navigator.pop(context, _AccountDelete(widget.existing!.id!));
  }
}
