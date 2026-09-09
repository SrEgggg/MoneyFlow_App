import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/section_card.dart';
import '../../data/models/models.dart';
import '../../providers.dart';

/// Streaks screen. Three types: saving, logging, goal.
class StreaksScreen extends ConsumerWidget {
  const StreaksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streaksAsync = ref.watch(streaksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Streaks')),
      body: streaksAsync.when(
        data: (streaks) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final s in streaks) _StreakCard(streak: s),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final StreakRecord streak;
  const _StreakCard({required this.streak});

  ({String label, IconData icon, Color color, String hint}) _meta() {
    switch (streak.id) {
      case 'saving':
        return (
          label: 'Saving Streak',
          icon: Icons.savings,
          color: AppColors.primary,
          hint: 'Days in a row where you saved money',
        );
      case 'logging':
        return (
          label: 'Logging Streak',
          icon: Icons.event_repeat,
          color: const Color(0xFF3B82F6),
          hint: 'Days in a row where you logged a transaction',
        );
      case 'goal':
        return (
          label: 'Goal Streak',
          icon: Icons.flag,
          color: const Color(0xFFEAB308),
          hint: 'Days in a row where you contributed to a goal',
        );
      default:
        return (
          label: streak.id,
          icon: Icons.local_fire_department,
          color: AppColors.primary,
          hint: '',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _meta();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: m.color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(m.icon, color: m.color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.label,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m.hint,
                    style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Pill(
                        label: 'Current',
                        value: '${streak.currentCount} d',
                        color: m.color,
                      ),
                      const SizedBox(width: 8),
                      _Pill(
                        label: 'Best',
                        value: '${streak.bestCount} d',
                        color: AppColors.onSurfaceVariant,
                      ),
                    ],
                  ),
                  if (streak.lastQualifiedDay != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Last qualified: ${D.shortDate(streak.lastQualifiedDay!)}',
                      style: const TextStyle(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Pill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
