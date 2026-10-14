import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/widgets/app_ui.dart';
import '../../providers.dart';
import 'widgets/quick_add_form.dart';
import 'widgets/transaction_list.dart';

/// Main Transactions tab with Quick Add and History sub-tabs.
class TransactionsScreen extends ConsumerStatefulWidget {
  final bool showHistory;
  const TransactionsScreen({super.key, this.showHistory = false});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      initialIndex: widget.showHistory ? 1 : 0,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant TransactionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showHistory != oldWidget.showHistory) {
      _tab.index = widget.showHistory ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txsAsync = ref.watch(transactionsProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tab,
              indicatorColor: Theme.of(context).colorScheme.primary,
              labelColor: Theme.of(context).colorScheme.onSurface,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: Theme.of(context).textTheme.labelLarge,
              tabs: const [
                Tab(text: 'Quick Add'),
                Tab(text: 'History'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // Quick Add: needs accounts for the account dropdown.
          accountsAsync.when(
            data: (accounts) => QuickAddForm(
              accounts: accounts,
              onSaved: () => _tab.animateTo(1),
            ),
            loading: () => const LoadingPlaceholder(lines: 4),
            error: (_, __) => InlineNotice(
              message:
                  'Could not load accounts. Your saved data has not been changed.',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(accountsProvider),
            ),
          ),
          // History
          txsAsync.when(
            data: (txs) => TransactionList(
              txs: txs,
              onTap: (tx) {
                if (tx.id != null) {
                  context.push(Routes.transactionDetail(tx.id!));
                }
              },
            ),
            loading: () => const LoadingPlaceholder(lines: 4),
            error: (_, __) => InlineNotice(
              message:
                  'Could not load transactions. Your saved data has not been changed.',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(transactionsProvider),
            ),
          ),
        ],
      ),
    );
  }
}
