import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../data/models/models.dart';

/// Card representation of a goal: icon, name, progress ring, amount, ETA.
class GoalCard extends StatelessWidget {
  final GoalRecord goal;
  final double? avgMonthlySavings;
  final VoidCallback onTap;

  const GoalCard({
    super.key,
    required this.goal,
    this.avgMonthlySavings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = goal.kind.color;
    final pct = goal.progress;
    final remaining = goal.targetAmount - goal.currentAmount;
    int? etaMonths;
    if (avgMonthlySavings != null &&
        avgMonthlySavings! > 0 &&
        remaining > 0) {
      etaMonths = (remaining / avgMonthlySavings!).ceil();
    }

    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ProgressRing(
                progress: pct,
                centerText: '${(pct * 100).toInt()}%',
                size: 64,
                stroke: 6,
                progressColor: color,
                trackColor: AppColors.surfaceContainerHigh,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(goal.kind.icon, size: 16, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            goal.name,
                            style: const TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${Money.compact(goal.currentAmount)} / ${Money.compact(goal.targetAmount)}',
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (etaMonths != null)
                          Row(
                            children: [
                              const Icon(Icons.schedule,
                                  size: 12,
                                  color: AppColors.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                '~${etaMonths}mo',
                                style: const TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        if (goal.monthlyTarget != null)
                          Row(
                            children: [
                              const Icon(Icons.trending_up,
                                  size: 12,
                                  color: AppColors.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                '${Money.compact(goal.monthlyTarget!)}/mo',
                                style: const TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}