import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/section_card.dart';
import '../providers/home_providers.dart';

class SmartInsightsList extends ConsumerWidget {
  const SmartInsightsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(homeSummaryProvider);
    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) {
        if (s.insights.isEmpty) {
          return SectionCard(
            title: 'Smart Insights',
            subtitle: 'Log a few transactions to unlock insights',
            titleIcon: Icons.auto_awesome_rounded,
            titleIconColor: const Color(0xFFEAB308),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'No insights yet — keep logging your activity and we will surface trends here.',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.9),
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
          );
        }
        return SectionCard(
          title: 'Smart Insights',
          subtitle: 'Personalized for your activity',
          titleIcon: Icons.auto_awesome_rounded,
          titleIconColor: const Color(0xFFEAB308),
          child: Column(
            children: [
              for (int i = 0; i < s.insights.length; i++) ...[
                _InsightRow(insight: s.insights[i]),
                if (i < s.insights.length - 1)
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

class _InsightRow extends StatelessWidget {
  final SmartInsight insight;
  const _InsightRow({required this.insight});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: insight.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: insight.color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(insight.icon, color: insight.color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              insight.message,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
                letterSpacing: -0.1,
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.onSurfaceVariant, size: 16),
        ],
      ),
    );
  }
}