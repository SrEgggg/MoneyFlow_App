/// Storage stays compatible with existing SQLite REAL columns. All arithmetic
/// is performed in bounded integer centavos before returning to storage.
abstract final class MoneyAmount {
  static const double max = 999999999.99;
  static int cents(num value) => (value * 100).round();
  static double round(num value) => cents(value) / 100;
  static bool valid(num value, {bool signed = false, bool zero = false}) =>
      value.isFinite &&
      value.abs() <= max &&
      (signed || (zero ? value >= 0 : value > 0)) &&
      (value * 100 - cents(value)).abs() <= .00002;
  static void require(num value, {bool signed = false, bool zero = false}) {
    if (!valid(value, signed: signed, zero: zero)) {
      throw ArgumentError(
        'Enter an amount up to 999,999,999.99 with at most two decimal places.',
      );
    }
  }
}
