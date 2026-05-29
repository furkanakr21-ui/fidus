import '../utils/currency_utils.dart';
import 'portfolio_asset_value_snapshot_model.dart';

class DailyAssetChange {
  final bool hasPortfolioSnapshot;
  final bool hasAssetSnapshot;
  final double currentValue;
  final double baselineValue;
  final double amount;
  final double percent;
  final String displayCurrency;

  const DailyAssetChange({
    required this.hasPortfolioSnapshot,
    required this.hasAssetSnapshot,
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

  static DailyAssetChange calculate({
    required double currentValueTry,
    required PortfolioAssetValueSnapshot? snapshot,
    required bool hasPortfolioSnapshot,
    required String displayCurrency,
  }) {
    final currentValue = CurrencyUtils.fromTry(
      currentValueTry,
      displayCurrency,
    );
    if (!hasPortfolioSnapshot) {
      return DailyAssetChange(
        hasPortfolioSnapshot: false,
        hasAssetSnapshot: false,
        currentValue: currentValue,
        baselineValue: 0,
        amount: 0,
        percent: 0,
        displayCurrency: displayCurrency,
      );
    }

    final baselineValue = snapshot == null
        ? 0.0
        : displayCurrency == 'USD'
        ? snapshot.valueUsd
        : CurrencyUtils.fromTry(snapshot.valueTry, displayCurrency);
    final amount = currentValue - baselineValue;
    final percent = baselineValue == 0 ? 0.0 : (amount / baselineValue) * 100;
    return DailyAssetChange(
      hasPortfolioSnapshot: true,
      hasAssetSnapshot: snapshot != null,
      currentValue: currentValue,
      baselineValue: baselineValue,
      amount: amount,
      percent: percent,
      displayCurrency: displayCurrency,
    );
  }
}
