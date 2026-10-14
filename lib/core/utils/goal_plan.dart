import '../../data/models/models.dart';

class GoalPlan {
  final double remaining;
  final int? days;
  final String? message;
  const GoalPlan(this.remaining, this.days, this.message);
  factory GoalPlan.forGoal(GoalRecord goal, DateTime now) {
    final remaining = (goal.targetAmount - goal.currentAmount).clamp(
      0.0,
      double.infinity,
    );
    if (!remaining.isFinite || !goal.targetAmount.isFinite) {
      return const GoalPlan(0, null, 'Set a valid target amount.');
    }
    if (remaining == 0) {
      return const GoalPlan(
        0,
        0,
        'Target reached. No additional savings needed.',
      );
    }
    final target = goal.targetDate;
    if (target == null) {
      return GoalPlan(
        remaining,
        null,
        'Set a target date to see a savings plan.',
      );
    }
    final today = DateTime.utc(now.year, now.month, now.day);
    final end = DateTime.utc(target.year, target.month, target.day);
    final days = end.difference(today).inDays + 1;
    if (days <= 0) {
      return GoalPlan(
        remaining,
        null,
        'Target date has passed. Choose a new date to refresh your plan.',
      );
    }
    return GoalPlan(remaining, days, null);
  }
  double _amount(double period) {
    if (days == null || days! <= 0) return 0;
    final amount = (remaining * period / days!).clamp(0.0, remaining);
    return (amount * 100).ceil() / 100;
  }

  double get daily => _amount(1);
  double get weekly => _amount(7);
  double get monthly => _amount(365.25 / 12);
}
