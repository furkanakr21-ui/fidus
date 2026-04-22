import 'package:intl/intl.dart';

class CurrencyUtils {
  // Supabase'den gelen kurlar buraya yazılır
  static double _usdToTry = 0;
  static double _eurToTry = 0;

  static void updateRates(Map<String, double> ratesPerUsd) {
    final tryRate = ratesPerUsd['TRY'] ?? 0;
    final eurRate = ratesPerUsd['EUR'] ?? 0;
    _usdToTry = tryRate;
    if (eurRate > 0 && tryRate > 0) _eurToTry = tryRate / eurRate;
  }

  static String symbol(String currency) {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      default:
        return '₺';
    }
  }

  static double _tryPerUnit(String targetCurrency) {
    if (targetCurrency == 'TRY') return 1.0;
    if (targetCurrency == 'USD' && _usdToTry > 0) return _usdToTry;
    if (targetCurrency == 'EUR' && _eurToTry > 0) return _eurToTry;
    return 0;
  }

  static double? currentRateForCurrency(String currency) {
    if (currency == 'TRY') return null;
    final rate = _tryPerUnit(currency);
    return rate > 0 ? rate : null;
  }

  static double fromTry(double tryAmount, String displayCurrency) {
    if (displayCurrency == 'TRY') return tryAmount;
    final rate = _tryPerUnit(displayCurrency);
    if (rate <= 0) return tryAmount;
    return tryAmount / rate;
  }

  static String formatRaw(double amount) {
    final abs = amount.abs();
    if (abs >= 1000) {
      return NumberFormat('#,###', 'tr_TR').format(amount.round());
    }
    return amount.round().toString();
  }

  static String format(double tryAmount, String displayCurrency) {
    final converted = fromTry(tryAmount, displayCurrency);
    return '${symbol(displayCurrency)}${formatRaw(converted)}';
  }

  static String formatHero(double tryAmount, String displayCurrency) =>
      format(tryAmount, displayCurrency);

  static String formatCashFlow(double amount, String currency) =>
      '${symbol(currency)}${formatRaw(amount)}';

  static double cashFlowToTry(
    double amount,
    String currency, {
    double? rateAtEntry,
  }) {
    if (currency == 'TRY') return amount;
    if (rateAtEntry != null && rateAtEntry > 0) return amount * rateAtEntry;
    final rate = _tryPerUnit(currency);
    if (rate <= 0) return amount;
    return amount * rate;
  }
}
