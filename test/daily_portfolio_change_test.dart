import 'package:fidus/shared/models/daily_portfolio_change.dart';
import 'package:fidus/shared/models/portfolio_value_snapshot_model.dart';
import 'package:fidus/shared/utils/currency_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses static USD snapshot value for USD daily change', () {
    CurrencyUtils.updateRates({'TRY': 50});

    final snapshot = PortfolioValueSnapshot(
      id: 'snapshot-1',
      userId: 'user-1',
      portfolioId: 'portfolio-1',
      snapshotDate: DateTime(2026, 5, 28),
      valueTry: 3000,
      valueUsd: 100,
      usdTryRate: 30,
      assetCount: 2,
      capturedAt: DateTime(2026, 5, 28, 0, 5),
      createdAt: DateTime(2026, 5, 28, 0, 5),
    );

    final change = DailyPortfolioChange.calculate(
      currentValueTry: 4000,
      snapshot: snapshot,
      displayCurrency: 'USD',
    );

    expect(change.hasSnapshot, isTrue);
    expect(change.currentValue, 80);
    expect(change.baselineValue, 100);
    expect(change.amount, -20);
    expect(change.percent, -20);
    expect(change.formatAmount(absolute: true), '-\$20');
  });

  test('returns waiting state when there is no snapshot', () {
    final change = DailyPortfolioChange.calculate(
      currentValueTry: 4000,
      snapshot: null,
      displayCurrency: 'TRY',
    );

    expect(change.hasSnapshot, isFalse);
    expect(change.amount, 0);
    expect(change.percent, 0);
  });
}
