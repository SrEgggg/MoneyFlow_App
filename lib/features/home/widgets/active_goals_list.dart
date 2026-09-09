import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/models/models.dart';
import '../providers/home_providers.dart';

class ActiveGoalsList extends ConsumerWidget {
  const ActiveGoalsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(homeSummaryProvider);
    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) {
        if (s.activeGoals.isEmpty) {
          return SectionCard(
            title: 'Active Goals',
            subtitle: 'No goals yet — set your first target',
            titleIcon: Icons.flag_rounded,
            titleIconColor: AppColors.primary,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go(Routes.goals),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_circle_outline_rounded,
                          color: AppColors.primary, size: 18),
                      SizedBox(width: 10),
                      Text(
                        'Create your first goal',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return SectionCard(
          title: 'Active Goals',
          subtitle:
              '${s.activeGoals.length} ${s.activeGoals.length == 1 ? "goal" : "goals"} in progress',
          titleIcon: Icons.flag_rounded,
          titleIconColor: AppColors.primary,
          trailing: _SeeAllPill(onTap: () => context.go(Routes.goals)),
          child: Column(
            children: [
              for (int i = 0; i < s.activeGoals.length && i < 3; i++) ...[
                _GoalRow(goal: s.activeGoals[i]),
                if (i < s.activeGoals.length - 1 && i < 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.outline.withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _GoalRow extends StatelessWidget {
  final GoalRecord goal;
  const _GoalRow({required this.goal});

  @override
  Widget build(BuildContext context) {
    final pct = goal.progress;
    final pctLabel = '${(pct * 100).round()}%';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(Routes.goalDetail(goal.id!)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: goal.kind.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: goal.kind.color.withValues(alpha: 0.32),
                        width: 1,
                      ),
                    ),
                    child:
                        Icon(goal.kind.icon, color: goal.kind.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: const TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${Money.format(goal.currentAmount)} / ${Money.format(goal.targetAmount)}',
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    pctLabel,
                    style: TextStyle(
                      color: goal.kind.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    children: [
                      Container(color: AppColors.surfaceContainerHigh),
                      FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                goal.kind.color.withValues(alpha: 0.7),
                                goal.kind.color,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeeAllPill extends StatelessWidget {
  final VoidCallback onTap;
  const _SeeAllPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'See all',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.primary, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}