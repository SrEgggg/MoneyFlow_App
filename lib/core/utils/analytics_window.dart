import 'activity_summary.dart';

/// Local-calendar reporting windows; comparisons never invent missing history.
class AnalyticsWindow {
  final DateTime start, end, previousStart, previousEnd;
  final bool month;
  AnalyticsWindow(DateTime now, int days)
    : month = days == 0,
      start = days == 0
          ? DateTime(now.year, now.month)
          : DateTime(now.year, now.month, now.day - days + 1),
      end = DateTime(now.year, now.month, now.day + 1),
      previousStart = days == 0
          ? DateTime(now.year, now.month - 1)
          : DateTime(now.year, now.month, now.day - 2 * days + 1),
      previousEnd = days == 0
          ? DateTime(
              now.year,
              now.month - 1,
              now.day.clamp(1, DateTime(now.year, now.month, 0).day) + 1,
            )
          : DateTime(now.year, now.month, now.day - days + 1);
  ActivitySummary current(ActivitySummary all) => all.between(start, end);
  ActivitySummary previous(ActivitySummary all) =>
      all.between(previousStart, previousEnd);
  String get comparisonLabel =>
      month ? 'previous month to the same day' : 'previous equal-length period';
}
