import '../../data/models/enums.dart';
import '../../data/models/models.dart';

/// Calendar activity uses the local date shown on the transaction form.
/// Goal contributions earmark existing money; they are not income or expenses.
class ActivitySummary {
  final List<TxRecord> transactions;
  final List<GoalContribution> contributions;
  ActivitySummary(this.transactions, this.contributions);

  static DateTime day(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  ActivitySummary between(DateTime start, DateTime end) => ActivitySummary(
    transactions
        .where(
          (t) =>
              !day(t.occurredAt).isBefore(start) &&
              day(t.occurredAt).isBefore(end),
        )
        .toList(),
    contributions
        .where(
          (c) =>
              !day(c.contributedAt).isBefore(start) &&
              day(c.contributedAt).isBefore(end),
        )
        .toList(),
  );
  ActivitySummary on(DateTime date) =>
      between(day(date), DateTime(date.year, date.month, date.day + 1));
  double get income => transactions
      .where((t) => t.type == TxType.income)
      .fold(0, (sum, t) => sum + t.amount);
  double get expenses => transactions
      .where((t) => t.type == TxType.expense)
      .fold(0, (sum, t) => sum + t.amount);
  double get saved => contributions.fold(0, (sum, c) => sum + c.amount);
  double get net => income - expenses;
  Set<DateTime> get activeDays => {
    ...transactions.map((t) => day(t.occurredAt)),
    ...contributions.map((c) => day(c.contributedAt)),
  };

  List<StreakRecord> streaks(DateTime now) {
    final validTx = transactions.where(
      (t) => t.amount.isFinite && t.amount > 0 && !t.occurredAt.isAfter(now),
    );
    final savingDays = contributions
        .where(
          (c) =>
              c.amount.isFinite &&
              c.amount > 0 &&
              !c.contributedAt.isAfter(now),
        )
        .map((c) => day(c.contributedAt))
        .toSet();
    return [
      consecutiveStreak('saving', savingDays, day(now)),
      consecutiveStreak('logging', {
        ...validTx.map((t) => day(t.occurredAt)),
        ...savingDays,
      }, day(now)),
      consecutiveStreak('goal', savingDays, day(now)),
    ];
  }
}

/// Counts distinct consecutive dates; today remains open until it ends.
StreakRecord consecutiveStreak(
  String id,
  Iterable<DateTime> dates,
  DateTime today,
) {
  final days =
      dates
          .map(ActivitySummary.day)
          .where((d) => !d.isAfter(today))
          .toSet()
          .toList()
        ..sort();
  var run = 0;
  var best = 0;
  DateTime? last;
  for (final date in days) {
    run = last != null && date == DateTime(last.year, last.month, last.day + 1)
        ? run + 1
        : 1;
    if (run > best) best = run;
    last = date;
  }
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  return StreakRecord(
    id: id,
    currentCount: last != null && !last.isBefore(yesterday) ? run : 0,
    bestCount: best,
    lastQualifiedDay: last,
  );
}
