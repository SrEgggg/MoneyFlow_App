import 'package:intl/intl.dart';

/// Date helpers used across calendar, reviews, and analytics.
class D {
  D._();

  static String monthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);

  static String shortMonthYear(DateTime d) => DateFormat('MMM yyyy').format(d);

  static String shortDate(DateTime d) => DateFormat('MMM d, yyyy').format(d);

  static String fullDate(DateTime d) => DateFormat('MMMM d, yyyy').format(d);

  static String dayOfWeek(DateTime d) => DateFormat('EEE').format(d);

  static String dayMonth(DateTime d) => DateFormat('MMM d').format(d);

  static String time(DateTime d) => DateFormat('h:mm a').format(d);

  static String dateTime(DateTime d) =>
      '${DateFormat('MMM d, yyyy').format(d)} • ${DateFormat('h:mm a').format(d)}';

  /// First day of the calendar month containing [d].
  static DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  /// Number of days in [d]'s month.
  static int daysInMonth(DateTime d) {
    final next = (d.month == 12)
        ? DateTime(d.year + 1, 1, 1)
        : DateTime(d.year, d.month + 1, 1);
    return next.subtract(const Duration(days: 1)).day;
  }

  /// Weekday of the 1st of [d]'s month (Mon=1..Sun=7).
  static int firstWeekday(DateTime d) {
    final first = firstOfMonth(d);
    return first.weekday; // Mon=1 .. Sun=7
  }

  /// Returns the leading grid offset (empty cells before day 1) for a Mon-first
  /// calendar layout.
  static int leadingOffset(DateTime monthAnchor) {
    // Mon-first: Sunday at end of week. Dart's DateTime.weekday: Mon=1..Sun=7.
    // We want Monday=0, Sunday=6.
    return firstWeekday(monthAnchor) - 1;
  }

  static String relativeDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff > 1 && diff < 7) return '$diff days ago';
    if (diff == -1) return 'Tomorrow';
    return DateFormat('MMM d').format(d);
  }
}
