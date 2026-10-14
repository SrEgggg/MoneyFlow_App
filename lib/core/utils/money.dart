import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Money formatting helpers. Default currency is Philippine Peso (₱).
class Money {
  Money._();
  static MoneyFormatter of(BuildContext context) => MoneyFormatter(
    context.dependOnInheritedWidgetOfExactType<CurrencyScope>()?.currency ??
        'PHP',
  );

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

  /// Format with currency symbol, showing two decimals only for fractional amounts: `₱52,480` or `-₱500` for negative.
  static String format(num value, {bool withSymbol = true}) {
    final negative = value < 0;
    final rounded = (value.abs() * 100).round() / 100;
    final body = rounded % 1 == 0
        ? _whole.format(rounded)
        : _decimal.format(rounded);
    final signed = negative ? '-$symbol$body' : '$symbol$body';
    if (!withSymbol) {
      return negative ? '-$body' : body;
    }
    return signed;
  }

  /// Format with decimals: `₱52,480.50`
  static String formatDecimal(num value, {bool withSymbol = true}) {
    final body = _decimal.format(value.abs());
    return '${value < 0 ? '-' : ''}${withSymbol ? symbol : ''}$body';
  }

  /// Compact format for large amounts: `₱52.5K`, `₱1.2M`
  static String compact(num value) {
    final abs = value.abs();
    String body;
    if (abs >= 1000000) {
      body = '${(abs / 1000000).toStringAsFixed(1)}M';
    } else if (abs >= 1000) {
      body = '${(abs / 1000).toStringAsFixed(1)}K';
    } else {
      return format(value);
    }
    return '${value < 0 ? '-' : ''}$symbol$body';
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

/// Display preference only: changing currency never converts stored amounts.
class CurrencyScope extends InheritedWidget {
  final String currency;
  const CurrencyScope({
    super.key,
    required this.currency,
    required super.child,
  });
  @override
  bool updateShouldNotify(CurrencyScope oldWidget) =>
      currency != oldWidget.currency;
}

class MoneyFormatter {
  final String currency;
  const MoneyFormatter(this.currency);
  String get symbol => currency == 'USD' ? '\$' : '₱';
  String _replace(String text) => text.replaceAll(Money.symbol, symbol);
  String format(num value, {bool withSymbol = true}) =>
      _replace(Money.format(value, withSymbol: withSymbol));
  String formatDecimal(num value, {bool withSymbol = true}) =>
      _replace(Money.formatDecimal(value, withSymbol: withSymbol));
  String compact(num value) => _replace(Money.compact(value));
  String formatSigned(num value) => _replace(Money.formatSigned(value));
}
