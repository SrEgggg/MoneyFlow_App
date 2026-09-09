import 'package:flutter_test/flutter_test.dart';
import 'package:savings_app/core/utils/money.dart';

void main() {
  group('Money.format', () {
    test('formats positive whole numbers with peso symbol', () {
      expect(Money.format(52480), '₱52,480');
    });

    test('formats zero as peso 0', () {
      expect(Money.format(0), '₱0');
    });

    test('formats decimals rounded to whole', () {
      expect(Money.format(1234.5), '₱1,235');
    });

    test('formats negative as -peso', () {
      expect(Money.format(-500), '-₱500');
    });
  });

  group('Money.formatDecimal', () {
    test('keeps two decimal places', () {
      expect(Money.formatDecimal(1234.5), '₱1,234.50');
    });
  });

  group('Money.compact', () {
    test('uses K suffix for thousands', () {
      expect(Money.compact(1500), '₱1.5K');
    });

    test('uses M suffix for millions', () {
      expect(Money.compact(2500000), '₱2.5M');
    });

    test('keeps plain format below 1000', () {
      expect(Money.compact(420), '₱420');
    });

    test('formats zero compactly', () {
      expect(Money.compact(0), '₱0');
    });
  });

  group('Savings rate formula', () {
    double savingsRate({required double income, required double expenses}) {
      if (income <= 0) return 0;
      return (income - expenses) / income;
    }

    test('positive savings rate when expenses < income', () {
      expect(savingsRate(income: 20000, expenses: 15000), 0.25);
    });

    test('zero savings rate at break-even', () {
      expect(savingsRate(income: 20000, expenses: 20000), 0.0);
    });

    test('negative savings rate when expenses > income', () {
      expect(savingsRate(income: 20000, expenses: 25000), -0.25);
    });

    test('returns 0 when income is zero (no division by zero)', () {
      expect(savingsRate(income: 0, expenses: 100), 0);
    });

    test('returns 0 when income is negative (defensive)', () {
      expect(savingsRate(income: -1000, expenses: 0), 0);
    });
  });
}