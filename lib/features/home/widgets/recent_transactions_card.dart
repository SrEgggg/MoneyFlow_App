import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/section_card.dart';
import '../../../providers.dart';
import '../../transactions/widgets/tx_list_tile.dart';

class RecentTransactionsCard extends ConsumerWidget {
  const RecentTransactionsCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(transactionsProvider)
      .when(
        loading: () => const LoadingPlaceholder(lines: 2),
        error: (_, __) => InlineNotice(
          message: 'Could not load recent transactions.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(transactionsProvider),
        ),
        data: (transactions) {
          if (transactions.isEmpty) {
            return const InlineNotice(
              icon: Icons.receipt_long_outlined,
              message:
                  'No transactions yet. Use Add income or Add expense to start tracking your activity.',
            );
          }
          final recent = transactions.take(3).toList();
          return SectionCard(
            framed: false,
            title: 'Recent transactions',
            trailing: TextButton(
              onPressed: () => context.go('${Routes.transactions}?tab=history'),
              child: const Text('See all'),
            ),
            child: Column(
              children: [
                for (var i = 0; i < recent.length; i++) ...[
                  TxListTile(
                    tx: recent[i],
                    onTap: () =>
                        context.push(Routes.transactionDetail(recent[i].id!)),
                  ),
                ],
              ],
            ),
          );
        },
      );
}
