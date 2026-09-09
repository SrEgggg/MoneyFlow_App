// Lightweight smoke tests for the financial correctness helpers. The full
// UI flow is verified manually; these tests guard the date/cutoff logic.

import 'package:flutter_test/flutter_test.dart';

import 'package:savings_app/core/utils/financial_day.dart';
import 'package:savings_app/core/utils/money.dart';

void main() {
  test('financial day boundary at 03:00', () {
    expect(
      FinancialDay.key(DateTime(2026, 6, 15, 2, 59)),
      DateTime(2026, 6, 14),
    );
    expect(
      FinancialDay.key(DateTime(2026, 6, 15, 3, 0)),
      DateTime(2026, 6, 15),
    );
  });

  test('money formatter adds peso symbol and thousands separators', () {
    expect(Money.format(52480), '₱52,480');
  });
}