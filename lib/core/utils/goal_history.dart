import '../../data/models/models.dart';

class GoalHistory {
  final List<GoalContribution> events;
  final double openingAmount;
  GoalHistory(GoalRecord goal, List<GoalContribution> records)
    : events = [...records]
        ..sort((a, b) => a.contributedAt.compareTo(b.contributedAt)),
      openingAmount =
          goal.currentAmount -
          records.fold<double>(0, (sum, c) => sum + c.amount);
  double get added =>
      events.where((c) => c.amount > 0).fold(0, (sum, c) => sum + c.amount);
  double get removed => -events
      .where((c) => c.amount < 0)
      .fold<double>(0, (sum, c) => sum + c.amount);
  Map<DateTime, double> get dailyBalances {
    var balance = openingAmount;
    final result = <DateTime, double>{};
    for (final event in events) {
      balance += event.amount;
      result[DateTime(
            event.contributedAt.year,
            event.contributedAt.month,
            event.contributedAt.day,
          )] =
          balance;
    }
    return result;
  }
}
