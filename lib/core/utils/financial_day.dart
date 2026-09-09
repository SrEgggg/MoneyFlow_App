/// Financial-day cutoff logic.
///
/// A "financial day" is the unit that defines when one day's transactions
/// end and the next begin. MoneyFlow uses 03:00 by default: any instant
/// between 00:00 and 02:59 still belongs to the previous calendar date.
///
/// All calendar coloring, streak evaluation, monthly aggregation, and
/// historical recalculation use this function.
class FinancialDay {
  FinancialDay._();

  /// Returns the financial-day key for [instant] (a UTC-naive DateTime).
  ///
  /// The returned DateTime has year/month/day set and hour/min/sec zeroed.
  static DateTime key(DateTime instant, {int cutoffHour = 3}) {
    final adjusted = instant.subtract(Duration(hours: cutoffHour));
    return DateTime(adjusted.year, adjusted.month, adjusted.day);
  }

  /// Today's financial-day key.
  static DateTime today({int cutoffHour = 3}) => key(DateTime.now());

  /// Start of the financial month containing [date].
  static DateTime startOfMonth(DateTime date, {int cutoffHour = 3}) {
    final k = key(date, cutoffHour: cutoffHour);
    return DateTime(k.year, k.month, 1);
  }

  /// End of the financial month (inclusive). Returns the day before [nextMonthStart].
  static DateTime endOfMonth(DateTime date, {int cutoffHour = 3}) {
    final start = startOfMonth(date, cutoffHour: cutoffHour);
    final next = (start.month == 12)
        ? DateTime(start.year + 1, 1, 1)
        : DateTime(start.year, start.month + 1, 1);
    return next.subtract(const Duration(days: 1));
  }

  /// Number of financial days between two keys (inclusive of both ends).
  static int daysBetween(DateTime a, DateTime b) {
    final ka = key(a);
    final kb = key(b);
    return kb.difference(ka).inDays.abs();
  }

  /// All financial-day keys from [start] to [end] inclusive.
  static List<DateTime> range(DateTime start, DateTime end) {
    final s = key(start);
    final e = key(end);
    if (e.isBefore(s)) return [];
    final out = <DateTime>[];
    for (var d = s; !d.isAfter(e); d = d.add(const Duration(days: 1))) {
      out.add(d);
    }
    return out;
  }
}
