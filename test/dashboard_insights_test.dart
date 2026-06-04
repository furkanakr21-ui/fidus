import 'package:fidus/shared/models/asset_model.dart';
import 'package:fidus/shared/models/dashboard_insights.dart';
import 'package:fidus/shared/models/daily_asset_change.dart';
import 'package:fidus/shared/models/income_expense_model.dart';
import 'package:flutter_test/flutter_test.dart';

CashFlowModel _cashflow({
  required String id,
  required CashFlowType type,
  required double amount,
  required DateTime date,
  String currency = 'TRY',
  double? rateAtEntry,
}) {
  return CashFlowModel(
    id: id,
    portfolioId: 'portfolio-1',
    title: id,
    amount: amount,
    currency: currency,
    type: type,
    date: date,
    rateAtEntry: rateAtEntry,
  );
}

AssetModel _asset(String symbol) {
  return AssetModel(
    id: symbol,
    portfolioId: 'portfolio-1',
    name: symbol,
    symbol: symbol,
    type: AssetType.stock,
    quantity: 1,
    buyPrice: 100,
    currentPrice: 100,
    buyDate: DateTime(2026, 6, 1),
  );
}

DailyAssetChange _change({
  required double amount,
  required double percent,
  bool hasPortfolioSnapshot = true,
}) {
  return DailyAssetChange(
    hasPortfolioSnapshot: hasPortfolioSnapshot,
    hasAssetSnapshot: hasPortfolioSnapshot,
    currentValue: 0,
    baselineValue: 0,
    amount: amount,
    percent: percent,
    displayCurrency: 'TRY',
  );
}

void main() {
  group('MonthlyNetCashFlow', () {
    test('calculates deposits minus withdrawals for the selected month', () {
      final insight = MonthlyNetCashFlow.calculate(
        cashflows: [
          _cashflow(
            id: 'deposit',
            type: CashFlowType.deposit,
            amount: 5000,
            date: DateTime(2026, 6, 2),
          ),
          _cashflow(
            id: 'withdrawal',
            type: CashFlowType.withdrawal,
            amount: 1250,
            date: DateTime(2026, 6, 15),
          ),
        ],
        month: DateTime(2026, 6, 30),
      );

      expect(insight.depositTry, 5000);
      expect(insight.withdrawalTry, 1250);
      expect(insight.netTry, 3750);
      expect(insight.count, 2);
    });

    test('ignores cashflows outside the selected month', () {
      final insight = MonthlyNetCashFlow.calculate(
        cashflows: [
          _cashflow(
            id: 'current-month',
            type: CashFlowType.deposit,
            amount: 1000,
            date: DateTime(2026, 6, 10),
          ),
          _cashflow(
            id: 'previous-month',
            type: CashFlowType.deposit,
            amount: 9000,
            date: DateTime(2026, 5, 31),
          ),
        ],
        month: DateTime(2026, 6, 1),
      );

      expect(insight.netTry, 1000);
      expect(insight.count, 1);
    });

    test('converts foreign currency cashflows with rateAtEntry', () {
      final insight = MonthlyNetCashFlow.calculate(
        cashflows: [
          _cashflow(
            id: 'usd-deposit',
            type: CashFlowType.deposit,
            amount: 100,
            currency: 'USD',
            rateAtEntry: 32,
            date: DateTime(2026, 6, 5),
          ),
          _cashflow(
            id: 'eur-withdrawal',
            type: CashFlowType.withdrawal,
            amount: 50,
            currency: 'EUR',
            rateAtEntry: 35,
            date: DateTime(2026, 6, 6),
          ),
        ],
        month: DateTime(2026, 6, 7),
      );

      expect(insight.depositTry, 3200);
      expect(insight.withdrawalTry, 1750);
      expect(insight.netTry, 1450);
    });

    test('returns zero when there are no cashflows', () {
      final insight = MonthlyNetCashFlow.calculate(
        cashflows: const [],
        month: DateTime(2026, 6, 1),
      );

      expect(insight.depositTry, 0);
      expect(insight.withdrawalTry, 0);
      expect(insight.netTry, 0);
      expect(insight.count, 0);
    });
  });

  group('DailyTopAssetGainer', () {
    test('selects the asset with the highest positive daily percent', () {
      final leader = DailyTopAssetGainer.select(
        assets: [_asset('AAA'), _asset('BBB'), _asset('CCC')],
        changes: {
          'AAA': _change(amount: 500, percent: 3),
          'BBB': _change(amount: 150, percent: 7),
          'CCC': _change(amount: 1000, percent: 5),
        },
      );

      expect(leader?.asset.symbol, 'BBB');
      expect(leader?.change.percent, 7);
    });

    test('ignores negative and unchanged assets', () {
      final leader = DailyTopAssetGainer.select(
        assets: [_asset('AAA'), _asset('BBB')],
        changes: {
          'AAA': _change(amount: -100, percent: -2),
          'BBB': _change(amount: 0, percent: 0),
        },
      );

      expect(leader, isNull);
    });

    test('does not select a leader before portfolio snapshot is ready', () {
      final leader = DailyTopAssetGainer.select(
        assets: [_asset('AAA')],
        changes: {
          'AAA': _change(amount: 100, percent: 4, hasPortfolioSnapshot: false),
        },
      );

      expect(leader, isNull);
    });

    test('breaks equal percent ties by the higher amount', () {
      final leader = DailyTopAssetGainer.select(
        assets: [_asset('AAA'), _asset('BBB')],
        changes: {
          'AAA': _change(amount: 100, percent: 5),
          'BBB': _change(amount: 250, percent: 5),
        },
      );

      expect(leader?.asset.symbol, 'BBB');
      expect(leader?.change.amount, 250);
    });
  });
}
