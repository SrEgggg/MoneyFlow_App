import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/date_utils.dart';
import '../../providers.dart';
import 'widgets/activity_details.dart';

class DayDetailScreen extends ConsumerWidget {
  final DateTime date;
  final DateTime financialDay;
  const DayDetailScreen({
    super.key,
    required this.date,
    required this.financialDay,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: Text(D.fullDate(date))),
    body: ref
        .watch(activityProvider)
        .when(
          data: (all) => ListView(
            padding: const EdgeInsets.all(16),
            children: [ActivityDetails(date: date, activity: all.on(date))],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(activityProvider),
              child: const Text('Could not load this day. Retry'),
            ),
          ),
        ),
  );
}
