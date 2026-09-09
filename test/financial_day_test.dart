import 'package:flutter_test/flutter_test.dart';
import 'package:savings_app/core/utils/financial_day.dart';

void main() {
  group('FinancialDay.key cutoff (default 3 AM)', () {
    test('00:00 belongs to previous calendar day', () {
      final instant = DateTime(2026, 6, 15, 0, 30);
      expect(FinancialDay.key(instant), DateTime(2026, 6, 14));
    });

    test('02:59 belongs to previous calendar day', () {
      final instant = DateTime(2026, 6, 15, 2, 59, 59);
      expect(FinancialDay.key(instant), DateTime(2026, 6, 14));
    });

    test('03:00 belongs to current calendar day', () {
      final instant = DateTime(2026, 6, 15, 3, 0, 0);
      expect(FinancialDay.key(instant), DateTime(2026, 6, 15));
    });

    test('12:00 belongs to current calendar day', () {
      final instant = DateTime(2026, 6, 15, 12, 0);
      expect(FinancialDay.key(instant), DateTime(2026, 6, 15));
    });

    test('23:59 belongs to current calendar day', () {
      final instant = DateTime(2026, 6, 15, 23, 59);
      expect(FinancialDay.key(instant), DateTime(2026, 6, 15));
    });

    test('midnight at month boundary rolls to last day of previous month', () {
      final instant = DateTime(2026, 7, 1, 0, 0);
      expect(FinancialDay.key(instant), DateTime(2026, 6, 30));
    });

    test('custom cutoff hour 5 shifts the boundary', () {
      final instant = DateTime(2026, 6, 15, 4, 59);
      expect(FinancialDay.key(instant, cutoffHour: 5), DateTime(2026, 6, 14));
      final atCutoff = DateTime(2026, 6, 15, 5, 0);
      expect(FinancialDay.key(atCutoff, cutoffHour: 5), DateTime(2026, 6, 15));
    });
  });

  group('FinancialDay.startOfMonth / endOfMonth', () {
    test('startOfMonth returns day 1 of the financial month', () {
      final instant = DateTime(2026, 6, 15, 12, 0);
      expect(FinancialDay.startOfMonth(instant), DateTime(2026, 6, 1));
    });

    test('endOfMonth returns the last day of the financial month', () {
      final instant = DateTime(2026, 6, 15);
      expect(FinancialDay.endOfMonth(instant), DateTime(2026, 6, 30));
    });

    test('endOfMonth handles December correctly', () {
      final instant = DateTime(2026, 12, 10);
      expect(FinancialDay.endOfMonth(instant), DateTime(2026, 12, 31));
    });

    test('endOfMonth handles February in a non-leap year', () {
      final instant = DateTime(2025, 2, 10);
      expect(FinancialDay.endOfMonth(instant), DateTime(2025, 2, 28));
    });

    test('startOfMonth at exactly 00:00 on day 1 still rolls to previous month (after cutoff)', () {
      // 00:00 on the 1st is BEFORE the 3 AM cutoff, so it belongs to
      // the last day of the previous month. startOfMonth then returns
      // the start of THAT previous month.
      final instant = DateTime(2026, 7, 1, 0, 0);
      expect(FinancialDay.startOfMonth(instant), DateTime(2026, 6, 1));
    });
  });

  group('FinancialDay.daysBetween and range', () {
    test('daysBetween two same-day instants is 0', () {
      final a = DateTime(2026, 6, 15, 9, 0);
      final b = DateTime(2026, 6, 15, 22, 0);
      expect(FinancialDay.daysBetween(a, b), 0);
    });

    test('daysBetween is symmetric', () {
      final a = DateTime(2026, 6, 1);
      final b = DateTime(2026, 6, 10);
      expect(FinancialDay.daysBetween(a, b), 9);
      expect(FinancialDay.daysBetween(b, a), 9);
    });

    test('range inclusive of both endpoints', () {
      final r = FinancialDay.range(
        DateTime(2026, 6, 1, 12, 0),
        DateTime(2026, 6, 3, 12, 0),
      );
      expect(r.length, 3);
      expect(r.first, DateTime(2026, 6, 1));
      expect(r.last, DateTime(2026, 6, 3));
    });

    test('range returns empty when end is before start', () {
      final r = FinancialDay.range(
        DateTime(2026, 6, 10, 12, 0),
        DateTime(2026, 6, 1, 12, 0),
      );
      expect(r, isEmpty);
    });
  });
}