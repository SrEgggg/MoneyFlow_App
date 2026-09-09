import 'package:intl/intl.dart';

/// Money formatting helpers. Default currency is Philippine Peso (₱).
class Money {
  Money._();

  static const String symbol = '₱';
  static final NumberFormat _whole = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '',
    decimalDigits: 0,
  );
  static final NumberFormat _decimal = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '',
    decimalDigits: 2,
  );

  /// Format with peso symbol and no decimals: `₱52,480` or `-₱500` for negative.
  static String format(num value, {bool withSymbol = true}) {
    final negative = value < 0;
    final body = _whole.format(value.abs());
    final signed = negative ? '-$symbol$body' : '$symbol$body';
    if (!withSymbol) {
      return negative ? '-$body' : body;
    }
    return signed;
  }

  /// Format with decimals: `₱52,480.50`
  static String formatDecimal(num value, {bool withSymbol = true}) {
    final body = _decimal.format(value);
    return withSymbol ? '$symbol$body' : body;
  }

  /// Compact format for large amounts: `₱52.5K`, `₱1.2M`
  static String compact(num value) {
    final abs = value.abs();
    String body;
    if (abs >= 1000000) {
      body = '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (abs >= 1000) {
      body = '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      body = value.toStringAsFixed(0);
    }
    return '$symbol$body';
  }

  /// Format with sign indicator: `+₱15,000` or `-₱250`
  static String formatSigned(num value) {
    final prefix = value >= 0 ? '+' : '-';
    return '$prefix${format(value.abs())}';
  }

  /// Parse a user-entered amount string. Strips commas, currency symbol, spaces.
  static double parse(String raw) {
    final cleaned = raw.replaceAll(',', '').replaceAll(symbol, '').trim();
    if (cleaned.isEmpty) return 0;
    return double.tryParse(cleaned) ?? 0;
  }
}
