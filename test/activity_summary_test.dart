import 'package:flutter_test/flutter_test.dart';
import 'package:savings_app/core/utils/activity_summary.dart';
import 'package:savings_app/data/models/models.dart';
import 'package:savings_app/data/models/enums.dart';

void main() {
  final today = DateTime(2026, 9, 14);
  TxRecord tx(
    DateTime date, {
    double amount = 1000,
    TxType type = TxType.income,
  }) => TxRecord(
    amount: amount,
    type: type,
    category: 'allowance',
    account: 'Cash',
    occurredAt: date,
    createdAt: date,
    updatedAt: date,
  );
  test('streak deduplicates dates, breaks at gaps, excludes future dates', () {
    final result = consecutiveStreak('logging', [
      DateTime(2026, 9, 10),
      DateTime(2026, 9, 11),
      DateTime(2026, 9, 13),
      today,
      today,
      DateTime(2026, 9, 15),
    ], today);
    expect(result.currentCount, 2);
    expect(result.bestCount, 2);
    expect(consecutiveStreak('logging', [], today).currentCount, 0);
    expect(
      consecutiveStreak('logging', [DateTime(2026, 9, 11)], today).currentCount,
      0,
    );
    expect(
      consecutiveStreak('logging', [DateTime(2026, 9, 13)], today).currentCount,
      1,
    );
  });
  test(
    'month and day totals use entered local date; savings are not income',
    () {
      final all = ActivitySummary(
        [
          tx(DateTime(2026, 9, 14, 1)),
          tx(today, amount: 350, type: TxType.expense),
          tx(DateTime(2026, 10, 1)),
        ],
        [GoalContribution(goalId: 1, amount: 200, contributedAt: today)],
      );
      final day = all.on(today);
      expect(day.income, 1000);
      expect(day.expenses, 350);
      expect(day.saved, 200);
      expect(day.net, 650);
      expect(day.activeDays.length, 1);
      expect(all.between(DateTime(2026, 9), DateTime(2026, 10)).income, 1000);
    },
  );
  test(
    'contribution-only activity counts, unallocated income is not saving',
    () {
      final all = ActivitySummary(
        [tx(DateTime(2026, 9, 14, 23))],
        [
          GoalContribution(
            goalId: 1,
            amount: 20,
            contributedAt: DateTime(2026, 9, 13, 12),
          ),
        ],
      );
      final streaks = all.streaks(DateTime(2026, 9, 14, 12));
      expect(streaks.firstWhere((s) => s.id == 'logging').currentCount, 1);
      expect(streaks.firstWhere((s) => s.id == 'saving').currentCount, 1);
      expect(
        ActivitySummary([tx(today)], []).streaks(today).first.currentCount,
        0,
      );
    },
  );
  test('moving or deleting the only activity changes streak and calendar', () {
    final first = tx(DateTime(2026, 9, 13));
    final second = tx(today);
    expect(
      ActivitySummary([first, second], []).streaks(today)[1].currentCount,
      2,
    );
    final moved = second.copyWith(occurredAt: DateTime(2026, 9, 10));
    expect(ActivitySummary([first, moved], []).on(today).activeDays, isEmpty);
    expect(
      ActivitySummary([first, moved], []).streaks(today)[1].currentCount,
      1,
    );
    expect(
      ActivitySummary(
        [],
        [],
      ).streaks(today).every((s) => s.currentCount == 0 && s.bestCount == 0),
      isTrue,
    );
  });
  test('consecutive dates cross year and leap day boundaries', () {
    expect(
      consecutiveStreak('logging', [
        DateTime(2025, 12, 31),
        DateTime(2026, 1, 1),
      ], DateTime(2026, 1, 1)).currentCount,
      2,
    );
    expect(
      consecutiveStreak('logging', [
        DateTime(2024, 2, 28),
        DateTime(2024, 2, 29),
        DateTime(2024, 3, 1),
      ], DateTime(2024, 3, 1)).currentCount,
      3,
    );
  });
}
