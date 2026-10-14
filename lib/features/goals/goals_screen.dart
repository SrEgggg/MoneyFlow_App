import '../../core/widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/enums.dart';
import '../../providers.dart';
import 'widgets/goal_card.dart';

/// Goals tab with Active / Completed sub-tabs.
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
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
                Tab(text: 'Active'),
                Tab(text: 'Completed'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.onPrimary,
        onPressed: () => context.push(Routes.createGoal),
        icon: const Icon(Icons.add),
        label: const Text('New Goal'),
      ),
      body: goalsAsync.when(
        data: (goals) {
          final active = goals
              .where((g) => g.status == GoalStatus.active)
              .toList();
          final completed = goals
              .where((g) => g.status == GoalStatus.completed)
              .toList();
          return TabBarView(
            controller: _tab,
            children: [
              _GoalList(
                goals: active,
                emptyTitle: 'No active goals',
                emptySubtitle:
                    'Tap "New Goal" to start tracking your first savings goal.',
              ),
              _GoalList(
                goals: completed,
                emptyTitle: 'No completed goals yet',
                emptySubtitle: 'Finish funding an active goal to see it here.',
              ),
            ],
          );
        },
        loading: () => const LoadingPlaceholder(lines: 4),
        error: (_, __) => InlineNotice(
          message: 'Could not load this screen. Your saved data is unchanged.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(goalsProvider),
        ),
      ),
    );
  }
}

class _GoalList extends StatelessWidget {
  final List goals;
  final String emptyTitle;
  final String emptySubtitle;
  const _GoalList({
    required this.goals,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return EmptyState(
        icon: Icons.flag_outlined,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: goals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final g = goals[i];
        return GoalCard(
          goal: g,
          onTap: () {
            if (g.id != null) context.push(Routes.goalDetail(g.id!));
          },
        );
      },
    );
  }
}
