import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers.dart';

/// Compact horizontal pill row showing the current saving/logging/goal
/// streak counts. Tapping a pill (or the whole row) routes to the
/// dedicated Streaks screen.
class StreaksSummaryRow extends ConsumerWidget {
  const StreaksSummaryRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streaksAsync = ref.watch(streaksProvider);
    return streaksAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (streaks) {
        return SectionCard(
          title: 'Streaks',
          subtitle: 'Keep the chain going',
          titleIcon: Icons.local_fire_department_rounded,
          titleIconColor: const Color(0xFFF97316),
          trailing: _SeeAllPill(
            onTap: () => context.go(Routes.performanceStreaks),
          ),
          onTap: () => context.go(Routes.performanceStreaks),
          child: Row(
            children: [
              for (final kind in StreakKind.values) ...[
                Expanded(
                  child: _StreakPill(
                    kind: kind,
                    current: _currentFor(streaks, kind),
                    best: _bestFor(streaks, kind),
                  ),
                ),
                if (kind != StreakKind.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
        );
      },
    );
  }

  int _currentFor(List<StreakRecord> list, StreakKind kind) => list
      .firstWhere(
        (s) => s.id == kind.id,
        orElse: () => StreakRecord(id: kind.id, currentCount: 0, bestCount: 0),
      )
      .currentCount;

  int _bestFor(List<StreakRecord> list, StreakKind kind) => list
      .firstWhere(
        (s) => s.id == kind.id,
        orElse: () => StreakRecord(id: kind.id, currentCount: 0, bestCount: 0),
      )
      .bestCount;
}

class _StreakPill extends StatelessWidget {
  final StreakKind kind;
  final int current;
  final int best;
  const _StreakPill({
    required this.kind,
    required this.current,
    required this.best,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(context, kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconFor(kind), color: color, size: 16),
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$current',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                TextSpan(
                  text: ' days',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            kind.label.replaceAll(' Streak', ''),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(BuildContext context, StreakKind k) {
    switch (k) {
      case StreakKind.saving:
        return Theme.of(context).colorScheme.primary;
      case StreakKind.logging:
        return const Color(0xFF3B82F6);
      case StreakKind.goal:
        return const Color(0xFFEAB308);
    }
  }

  IconData _iconFor(StreakKind k) {
    switch (k) {
      case StreakKind.saving:
        return Icons.savings_rounded;
      case StreakKind.logging:
        return Icons.event_repeat_rounded;
      case StreakKind.goal:
        return Icons.flag_rounded;
    }
  }
}

class _SeeAllPill extends StatelessWidget {
  final VoidCallback onTap;
  const _SeeAllPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'See all',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(width: 2),
          Icon(
            Icons.chevron_right_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 14,
          ),
        ],
      ),
    );
  }
}
