import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/utils/activity_summary.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/section_card.dart';
import '../../../providers.dart';
import '../../transactions/widgets/tx_list_tile.dart';
import '../../transactions/widgets/quick_add_form.dart';

class ActivityTotals extends StatelessWidget {
  final ActivitySummary activity;
  const ActivityTotals({super.key, required this.activity});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 24,
    runSpacing: 16,
    children: [
      for (final item in [
        ('Income', activity.income),
        ('Expenses', activity.expenses),
        ('Goal savings', activity.saved),
        ('Net cash flow', activity.net),
      ])
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.$1, style: Theme.of(context).textTheme.bodySmall),
            Text(
              Money.format(item.$2),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
    ],
  );
}

class ActivityDetails extends ConsumerWidget {
  final DateTime date;
  final ActivitySummary activity;
  const ActivityDetails({
    super.key,
    required this.date,
    required this.activity,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider).valueOrNull ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActivityTotals(activity: activity),
        const SizedBox(height: 12),
        const Text(
          'Goal savings earmark existing money. Net cash flow is income minus expenses.',
        ),
        const SizedBox(height: 16),
        if (activity.activeDays.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No activity on this day. Record money received or spent when it happens; there is no need to spend to keep a streak.',
            ),
          ),
        for (final tx in activity.transactions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TxListTile(
              tx: tx,
              onTap: () => context.push(Routes.transactionDetail(tx.id!)),
            ),
          ),
        for (final c in activity.contributions)
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(
              goals.where((g) => g.id == c.goalId).firstOrNull?.name ??
                  'Goal contribution',
            ),
            subtitle: const Text('Added to goal savings'),
            trailing: Text(Money.format(c.amount)),
            onTap: () => context.push(Routes.goalDetail(c.goalId)),
          ),
        FilledButton.icon(
          onPressed: () => _add(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Add Transaction'),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    try {
      final accounts = await ref.read(accountsProvider.future);
      if (!context.mounted) return;
      if (accounts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Create an account before adding a transaction.'),
          ),
        );
        context.push(Routes.accounts);
        return;
      }
      final now = DateTime.now();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: QuickAddForm(
                accounts: accounts,
                initialDate: DateTime(
                  date.year,
                  date.month,
                  date.day,
                  now.hour,
                  now.minute,
                ),
                onSaved: () => Navigator.pop(sheetContext),
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the form. Please try again.'),
          ),
        );
      }
    }
  }
}

class FinancialActivityCard extends ConsumerWidget {
  const FinancialActivityCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(activityClockProvider).valueOrNull ?? DateTime.now();
    return ref
        .watch(activityProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => TextButton(
            onPressed: () => ref.invalidate(activityProvider),
            child: const Text('Could not load activity. Retry'),
          ),
          data: (all) {
            final month = all.between(
              DateTime(now.year, now.month),
              DateTime(now.year, now.month + 1),
            );
            final streak = all
                .streaks(now)
                .firstWhere((s) => s.id == 'logging');
            return SectionCard(
              title: 'Financial Activity',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '🔥 ${streak.currentCount} day tracking streak · Best ${streak.bestCount}',
                  ),
                  const SizedBox(height: 12),
                  ActivityTotals(activity: month),
                  const SizedBox(height: 12),
                  Text(
                    '${month.activeDays.where((d) => !d.isAfter(ActivitySummary.day(now))).length} / ${DateTime(now.year, now.month + 1, 0).day} active days this month',
                  ),
                  TextButton.icon(
                    onPressed: () => context.go(Routes.performance),
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('View Calendar'),
                  ),
                ],
              ),
            );
          },
        );
  }
}
