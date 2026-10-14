import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../providers.dart';
import '../../performance/widgets/activity_details.dart';

/// A useful check-in based only on recorded activity, without streak pressure.
class TodayCheckIn extends ConsumerWidget {
  const TodayCheckIn({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(activityProvider).valueOrNull;
    if (all == null ||
        (ref.watch(accountsProvider).valueOrNull ?? []).isEmpty) {
      return const SizedBox.shrink();
    }
    final now = ref.watch(activityClockProvider).valueOrNull ?? DateTime.now();
    final today = all.on(now);
    final count = today.transactions.length + today.contributions.length;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.md),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          Icons.today_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          count == 0
              ? 'Your day, at a glance'
              : 'Today · $count ${count == 1 ? 'entry' : 'entries'}',
        ),
        subtitle: Text(
          count == 0
              ? 'Nothing recorded today. Add an entry whenever you’re ready.'
              : '${Money.of(context).format(today.expenses)} spent · ${Money.of(context).format(today.saved)} net goal savings',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (context) => SizedBox(
            height: MediaQuery.sizeOf(context).height * .8,
            child: Consumer(
              builder: (context, ref, _) {
                final current = ref.watch(activityProvider).valueOrNull ?? all;
                return ListView(
                  padding: const EdgeInsets.all(AppSpace.md),
                  children: [
                    Text(
                      'Today’s activity',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpace.md),
                    ActivityDetails(date: now, activity: current.on(now)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
