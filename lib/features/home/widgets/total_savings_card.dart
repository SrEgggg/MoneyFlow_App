import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/section_card.dart';
import '../../../providers.dart';

/// Account balances are current snapshots. Historical balance changes are not
/// inferred from cash flow: manual reconciliations are not a balance ledger.
class TotalSavingsCard extends ConsumerWidget {
  const TotalSavingsCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(accountsProvider)
      .when(
        loading: () => const LoadingPlaceholder(),
        error: (_, __) => InlineNotice(
          message:
              'Could not load balances. Your saved accounts are unchanged.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(accountsProvider),
        ),
        data: (accounts) => SectionCard(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Current Balance',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(Routes.accounts),
                    child: Text(accounts.isEmpty ? 'Add account' : 'Accounts'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                Money.of(
                  context,
                ).format(accounts.fold<double>(0, (sum, a) => sum + a.balance)),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontSize: 36,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                accounts.isEmpty
                    ? 'Add an account to start tracking your balance.'
                    : 'Across ${accounts.length} ${accounts.length == 1 ? 'account' : 'accounts'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}
