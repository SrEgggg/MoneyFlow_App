import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/constants/achievements.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_card.dart';
import '../../providers.dart';

/// Achievements screen. Three sub-tabs: All, Earned, Locked.
class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final earnedAsync = ref.watch(earnedAchievementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tab,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.onSurface,
              unselectedLabelColor: AppColors.onSurfaceVariant,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Earned'),
                Tab(text: 'Locked'),
              ],
            ),
          ),
        ),
      ),
      body: earnedAsync.when(
        data: (earned) {
          final earnedIds = earned.map((e) => e.achievementId).toSet();
          final earnedDefs = AchievementDefs.all
              .where((a) => earnedIds.contains(a.id))
              .toList();
          final lockedDefs = AchievementDefs.all
              .where((a) => !earnedIds.contains(a.id))
              .toList();
          return TabBarView(
            controller: _tab,
            children: [
              _AchievementGrid(
                defs: AchievementDefs.all,
                earnedMap: {for (final e in earned) e.achievementId: e.earnedAt},
              ),
              earnedDefs.isEmpty
                  ? const EmptyState(
                      icon: Icons.emoji_events_outlined,
                      title: 'No achievements yet',
                      subtitle:
                          'Save consistently and log transactions to unlock badges.',
                    )
                  : _AchievementGrid(
                      defs: earnedDefs,
                      earnedMap:
                          {for (final e in earned) e.achievementId: e.earnedAt},
                    ),
              _AchievementGrid(
                defs: lockedDefs,
                earnedMap: const {},
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _AchievementGrid extends StatelessWidget {
  final List<AchievementDef> defs;
  final Map<String, DateTime> earnedMap;
  const _AchievementGrid({required this.defs, required this.earnedMap});

  @override
  Widget build(BuildContext context) {
    if (defs.isEmpty) {
      return const EmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'Nothing here yet',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: defs.length,
      itemBuilder: (context, i) {
        final def = defs[i];
        final earnedAt = earnedMap[def.id];
        final earned = earnedAt != null;
        return _AchievementTile(def: def, earnedAt: earnedAt, earned: earned);
      },
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final AchievementDef def;
  final DateTime? earnedAt;
  final bool earned;
  const _AchievementTile({
    required this.def,
    required this.earnedAt,
    required this.earned,
  });

  @override
  Widget build(BuildContext context) {
    final color = earned ? def.color : AppColors.onSurfaceVariant;
    return SectionCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: earned ? 0.18 : 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(def.icon,
                  color: earned ? color : AppColors.onSurfaceMuted, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              def.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: earned ? AppColors.onSurface : AppColors.onSurfaceMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              def.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 11,
                height: 1.3,
              ),
            ),
            const Spacer(),
            Text(
              earned
                  ? 'Earned ${D.shortDate(earnedAt!)}'
                  : 'Locked',
              style: TextStyle(
                color: earned ? def.color : AppColors.onSurfaceMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
