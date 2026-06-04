import '../utils/currency_utils.dart';
import 'asset_model.dart';
import 'daily_asset_change.dart';
import 'income_expense_model.dart';

class MonthlyNetCashFlow {
  final double depositTry;
  final double withdrawalTry;
  final int count;

  const MonthlyNetCashFlow({
    required this.depositTry,
    required this.withdrawalTry,
    required this.count,
  });

  double get netTry => depositTry - withdrawalTry;
  bool get isPositive => netTry >= 0;

  static MonthlyNetCashFlow calculate({
    required List<CashFlowModel> cashflows,
    required DateTime month,
  }) {
    var depositTry = 0.0;
    var withdrawalTry = 0.0;
    var count = 0;

    for (final cashflow in cashflows) {
      if (cashflow.date.year != month.year ||
          cashflow.date.month != month.month) {
        continue;
      }

      count++;
      final amountTry = CurrencyUtils.cashFlowToTry(
        cashflow.amount,
        cashflow.currency,
        rateAtEntry: cashflow.rateAtEntry,
      );
      if (cashflow.type == CashFlowType.deposit) {
        depositTry += amountTry;
      } else {
        withdrawalTry += amountTry;
      }
    }

    return MonthlyNetCashFlow(
      depositTry: depositTry,
      withdrawalTry: withdrawalTry,
      count: count,
    );
  }
}

class DailyTopAssetGainer {
  final AssetModel asset;
  final DailyAssetChange change;

  const DailyTopAssetGainer({required this.asset, required this.change});

  static DailyTopAssetGainer? select({
    required List<AssetModel> assets,
    required Map<String, DailyAssetChange> changes,
  }) {
    DailyTopAssetGainer? leader;

    for (final asset in assets) {
      final change = changes[asset.symbol];
      if (change == null ||
          !change.hasPortfolioSnapshot ||
          change.percent <= 0 ||
          change.amount <= 0) {
        continue;
      }

      final candidate = DailyTopAssetGainer(asset: asset, change: change);
      if (leader == null ||
          candidate.change.percent > leader.change.percent ||
          (candidate.change.percent == leader.change.percent &&
              candidate.change.amount > leader.change.amount)) {
        leader = candidate;
      }
    }

    return leader;
  }
}
