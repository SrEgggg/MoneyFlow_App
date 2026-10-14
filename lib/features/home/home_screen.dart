import 'widgets/today_check_in.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_ui.dart';
import '../../core/widgets/section_card.dart';
import '../../data/models/enums.dart';
import '../../providers.dart';
import '../accounts/money_movement_dialog.dart';
import '../transactions/widgets/quick_add_form.dart';
import 'widgets/active_goals_list.dart';
import 'widgets/recent_transactions_card.dart';
import 'widgets/total_savings_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(activityClockProvider).valueOrNull ?? DateTime.now();
    final name =
        ref.watch(settingsProvider).valueOrNull?.displayName.trim() ?? 'there';
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final issue =
        ref.watch(derivedDataIssueProvider) ??
        ref.watch(recurringIssueProvider);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(accountsProvider);
            ref.invalidate(transactionsProvider);
            ref.invalidate(goalsProvider);
            await ref.read(refreshDerivedDataProvider)();
            await Future.wait([
              ref.read(accountsProvider.future),
              ref.read(transactionsProvider.future),
              ref.read(goalsProvider.future),
            ]);
          },
          child: ListView(
            padding: AppSpace.page,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          name.isEmpty || name == 'there'
                              ? 'Your overview'
                              : name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Notifications',
                    icon: Icon(
                      issue == null
                          ? Icons.notifications_none
                          : Icons.notification_important_outlined,
                    ),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (c) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notifications',
                                style: Theme.of(c).textTheme.titleLarge,
                              ),
                              const SizedBox(height: AppSpace.md),
                              Text(
                                issue ??
                                    'You’re all caught up. No alerts need your attention.',
                              ),
                              if (ref.watch(recurringIssueProvider) != null)
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(c);
                                    context.go(Routes.recurring);
                                  },
                                  child: const Text(
                                    'Review scheduled transactions',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              const TotalSavingsCard(),
              const SizedBox(height: AppSpace.md),
              _QuickActions(),
              const TodayCheckIn(),
              const SizedBox(height: AppSpace.lg),
              const RecentTransactionsCard(),
              const SizedBox(height: AppSpace.lg),
              const ActiveGoalsList(),
              const SizedBox(height: AppSpace.lg),
              ref
                  .watch(activityProvider)
                  .when(
                    loading: () => const LoadingPlaceholder(),
                    error: (_, __) => InlineNotice(
                      message: 'Could not load your monthly summary.',
                      actionLabel: 'Retry',
                      onAction: () => ref.invalidate(activityProvider),
                    ),
                    data: (all) {
                      final month = all.between(
                        DateTime(now.year, now.month),
                        DateTime(now.year, now.month, now.day + 1),
                      );
                      if (month.activeDays.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionCard(
                            title: 'This month',
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final columns =
                                    MediaQuery.textScalerOf(context).scale(14) >
                                        22
                                    ? 1
                                    : 2;
                                final width =
                                    (constraints.maxWidth -
                                        AppSpace.md * (columns - 1)) /
                                    columns;
                                return Wrap(
                                  spacing: AppSpace.md,
                                  runSpacing: AppSpace.md,
                                  children: [
                                    for (final metric in [
                                      ('Income', month.income),
                                      ('Expenses', month.expenses),
                                      ('Goal savings', month.saved),
                                      ('Net cash flow', month.net),
                                    ])
                                      SizedBox(
                                        width: width,
                                        child: StatTile(
                                          label: metric.$1,
                                          value: Money.of(
                                            context,
                                          ).format(metric.$2),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              const SizedBox(height: AppSpace.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).valueOrNull ?? [];
    if (accounts.isEmpty) return const SizedBox.shrink();
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 22;
    final buttons = <Widget>[
      for (final action in [
        (TxType.income, 'Add income', Icons.add),
        (TxType.expense, 'Add expense', Icons.remove),
        (TxType.transfer, 'Transfer', Icons.swap_vert),
      ])
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          ),
          onPressed: accounts.isEmpty
              ? null
              : () {
                  if (action.$1 == TxType.transfer) {
                    showDialog<void>(
                      context: context,
                      builder: (_) => MoneyMovementDialog(accounts: accounts),
                    );
                  } else {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      showDragHandle: true,
                      builder: (c) => SizedBox(
                        height: MediaQuery.sizeOf(c).height * .85,
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.viewInsetsOf(c).bottom,
                          ),
                          child: QuickAddForm(
                            accounts: accounts,
                            initialType: action.$1,
                            onSaved: () => Navigator.pop(c),
                          ),
                        ),
                      ),
                    );
                  }
                },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                action.$3,
                size: 22,
                color: accounts.isEmpty
                    ? null
                    : action.$1 == TxType.income
                    ? Theme.of(context).colorScheme.primary
                    : action.$1 == TxType.expense
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF60A5FA)
                    : const Color(0xFF2563EB),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(action.$2, textAlign: TextAlign.center),
            ],
          ),
        ),
    ];
    if (largeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final button in buttons)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: button),
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: buttons[i]),
          ],
        ],
      ),
    );
  }
}
