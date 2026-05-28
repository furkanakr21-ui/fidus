import '../utils/currency_utils.dart';
import 'portfolio_value_snapshot_model.dart';

class DailyPortfolioChange {
  final bool hasSnapshot;
  final double currentValue;
  final double baselineValue;
  final double amount;
  final double percent;
  final String displayCurrency;

  const DailyPortfolioChange({
    required this.hasSnapshot,
    required this.currentValue,
    required this.baselineValue,
    required this.amount,
    required this.percent,
    required this.displayCurrency,
  });

  bool get isProfit => amount >= 0;

  String formatAmount({bool signed = true, bool absolute = false}) {
    final value = absolute ? amount.abs() : amount;
    final prefix = signed ? (amount >= 0 ? '+' : (absolute ? '-' : '')) : '';
    return '$prefix${CurrencyUtils.symbol(displayCurrency)}'
        '${CurrencyUtils.formatRaw(value)}';
  }

  static DailyPortfolioChange calculate({
    required double currentValueTry,
    required PortfolioValueSnapshot? snapshot,
    required String displayCurrency,
  }) {
    final currentValue = CurrencyUtils.fromTry(
      currentValueTry,
      displayCurrency,
    );
    if (snapshot == null) {
      return DailyPortfolioChange(
        hasSnapshot: false,
        currentValue: currentValue,
        baselineValue: 0,
        amount: 0,
        percent: 0,
        displayCurrency: displayCurrency,
      );
    }

    final baselineValue = displayCurrency == 'USD'
        ? snapshot.valueUsd
        : CurrencyUtils.fromTry(snapshot.valueTry, displayCurrency);
    final amount = currentValue - baselineValue;
    final percent = baselineValue == 0 ? 0.0 : (amount / baselineValue) * 100;
    return DailyPortfolioChange(
      hasSnapshot: true,
      currentValue: currentValue,
      baselineValue: baselineValue,
      amount: amount,
      percent: percent,
      displayCurrency: displayCurrency,
    );
  }
}
