import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Static achievement definitions. Stored as a record list at seed time
/// and re-evaluated whenever the user crosses a threshold.
class AchievementDef {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  /// Criterion descriptor — used by AchievementService to decide when this
  /// unlocks. Not a full expression engine; just a tagged-union.
  final AchievementCriterion criterion;

  const AchievementDef({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.criterion,
  });
}

/// Simple tagged union for criterion matching.
sealed class AchievementCriterion {
  const AchievementCriterion();
}

class TotalSavedAtLeast extends AchievementCriterion {
  final double amount;
  const TotalSavedAtLeast(this.amount);
}

class SavingStreakAtLeast extends AchievementCriterion {
  final int days;
  const SavingStreakAtLeast(this.days);
}

class LoggingStreakAtLeast extends AchievementCriterion {
  final int days;
  const LoggingStreakAtLeast(this.days);
}

class EmergencyFundProgressAtLeast extends AchievementCriterion {
  final double percent;
  const EmergencyFundProgressAtLeast(this.percent);
}

class GoalsCompletedAtLeast extends AchievementCriterion {
  final int count;
  const GoalsCompletedAtLeast(this.count);
}

class JournalEntriesAtLeast extends AchievementCriterion {
  final int count;
  const JournalEntriesAtLeast(this.count);
}

class AchievementDefs {
  AchievementDefs._();

  static const List<AchievementDef> all = [
    AchievementDef(
      id: 'first_1k',
      name: 'First ₱1,000 Saved',
      description: 'Save your first ₱1,000',
      icon: Icons.savings,
      color: AppColors.primary,
      criterion: TotalSavedAtLeast(1000),
    ),
    AchievementDef(
      id: 'first_5k',
      name: 'First ₱5,000 Saved',
      description: 'Save your first ₱5,000',
      icon: Icons.savings,
      color: AppColors.primary,
      criterion: TotalSavedAtLeast(5000),
    ),
    AchievementDef(
      id: 'first_10k',
      name: 'First ₱10,000 Saved',
      description: 'Save your first ₱10,000',
      icon: Icons.account_balance,
      color: AppColors.primary,
      criterion: TotalSavedAtLeast(10000),
    ),
    AchievementDef(
      id: 'lifetime_100k',
      name: 'Saved ₱100,000 Lifetime',
      description: 'Lifetime savings reach ₱100,000',
      icon: Icons.workspace_premium,
      color: Color(0xFFEAB308),
      criterion: TotalSavedAtLeast(100000),
    ),
    AchievementDef(
      id: 'saving_streak_7',
      name: '7-Day Savings Streak',
      description: 'Save money for 7 days straight',
      icon: Icons.local_fire_department,
      color: Color(0xFFF97316),
      criterion: SavingStreakAtLeast(7),
    ),
    AchievementDef(
      id: 'saving_streak_30',
      name: '30-Day Savings Streak',
      description: 'Save money for 30 days straight',
      icon: Icons.local_fire_department,
      color: Color(0xFFEF4444),
      criterion: SavingStreakAtLeast(30),
    ),
    AchievementDef(
      id: 'logging_streak_30',
      name: '30-Day Logging Streak',
      description: 'Log a transaction every day for 30 days',
      icon: Icons.event_repeat,
      color: Color(0xFF3B82F6),
      criterion: LoggingStreakAtLeast(30),
    ),
    AchievementDef(
      id: 'emergency_builder',
      name: 'Emergency Fund Builder',
      description: 'Reach 50% of an emergency fund',
      icon: Icons.shield,
      color: AppColors.primary,
      criterion: EmergencyFundProgressAtLeast(50),
    ),
    AchievementDef(
      id: 'emergency_complete',
      name: 'Emergency Fund Complete',
      description: 'Fully fund an emergency goal',
      icon: Icons.shield,
      color: AppColors.primary,
      criterion: EmergencyFundProgressAtLeast(100),
    ),
    AchievementDef(
      id: 'first_goal_done',
      name: 'Goal Crusher',
      description: 'Complete your first goal',
      icon: Icons.flag,
      color: Color(0xFFEAB308),
      criterion: GoalsCompletedAtLeast(1),
    ),
    AchievementDef(
      id: 'three_goals_done',
      name: 'Triple Threat',
      description: 'Complete three goals',
      icon: Icons.emoji_events,
      color: Color(0xFFEAB308),
      criterion: GoalsCompletedAtLeast(3),
    ),
    AchievementDef(
      id: 'reflector',
      name: 'Reflector',
      description: 'Write 10 journal entries',
      icon: Icons.menu_book,
      color: Color(0xFF8B5CF6),
      criterion: JournalEntriesAtLeast(10),
    ),
  ];

  static AchievementDef byId(String id) =>
      all.firstWhere((a) => a.id == id, orElse: () => all.first);
}
