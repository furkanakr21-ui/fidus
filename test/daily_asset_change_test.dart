import 'package:fidus/shared/models/daily_asset_change.dart';
import 'package:fidus/shared/models/portfolio_asset_value_snapshot_model.dart';
import 'package:fidus/shared/utils/currency_utils.dart';
import 'package:flutter_test/flutter_test.dart';

PortfolioAssetValueSnapshot _snapshot({
  double valueTry = 3000,
  double valueUsd = 100,
}) {
  return PortfolioAssetValueSnapshot(
    id: 'asset-snapshot-1',
    userId: 'user-1',
    portfolioId: 'portfolio-1',
    snapshotDate: DateTime(2026, 5, 29),
    symbol: 'AAPL',
    name: 'Apple',
    type: 'stock',
    quantity: 2,
    valueTry: valueTry,
    valueUsd: valueUsd,
    usdTryRate: 30,
    assetRowCount: 1,
    capturedAt: DateTime(2026, 5, 29, 0, 5),
    createdAt: DateTime(2026, 5, 29, 0, 5),
  );
}

void main() {
  test('parses portfolio asset snapshot json', () {
    final snapshot = PortfolioAssetValueSnapshot.fromJson({
      'id': 'asset-snapshot-1',
      'user_id': 'user-1',
      'portfolio_id': 'portfolio-1',
      'snapshot_date': '2026-05-29',
      'symbol': 'BTC',
      'name': 'Bitcoin',
      'type': 'crypto',
      'api_source': 'coingecko',
      'api_id': 'bitcoin',
      'quantity': 0.5,
      'value_try': 1000,
      'value_usd': 25,
      'usd_try_rate': 40,
      'fx_rates_updated_at': '2026-05-29T00:01:00Z',
      'asset_row_count': 2,
      'captured_at': '2026-05-29T00:05:00Z',
      'created_at': '2026-05-29T00:05:00Z',
    });

    expect(snapshot.symbol, 'BTC');
    expect(snapshot.apiId, 'bitcoin');
    expect(snapshot.quantity, 0.5);
    expect(snapshot.valueTry, 1000);
    expect(snapshot.valueUsd, 25);
    expect(snapshot.assetRowCount, 2);
    expect(snapshot.fxRatesUpdatedAt, isNotNull);
  });

  test('uses static USD snapshot value for USD asset daily change', () {
    CurrencyUtils.updateRates({'TRY': 50});

    final change = DailyAssetChange.calculate(
      currentValueTry: 4000,
      snapshot: _snapshot(),
      hasPortfolioSnapshot: true,
      displayCurrency: 'USD',
    );

    expect(change.hasPortfolioSnapshot, isTrue);
    expect(change.currentValue, 80);
    expect(change.baselineValue, 100);
    expect(change.amount, -20);
    expect(change.percent, -20);
  });

  test('returns waiting state when portfolio snapshot is missing', () {
    final change = DailyAssetChange.calculate(
      currentValueTry: 4000,
      snapshot: null,
      hasPortfolioSnapshot: false,
      displayCurrency: 'TRY',
    );

    expect(change.hasPortfolioSnapshot, isFalse);
    expect(change.hasAssetSnapshot, isFalse);
    expect(change.amount, 0);
    expect(change.percent, 0);
  });

  test(
    'uses zero baseline when portfolio snapshot exists but asset is new',
    () {
      final change = DailyAssetChange.calculate(
        currentValueTry: 4000,
        snapshot: null,
        hasPortfolioSnapshot: true,
        displayCurrency: 'TRY',
      );

      expect(change.hasPortfolioSnapshot, isTrue);
      expect(change.hasAssetSnapshot, isFalse);
      expect(change.baselineValue, 0);
      expect(change.amount, 4000);
      expect(change.percent, 0);
    },
  );

  test('formats amount and percent separately for asset row badges', () {
    final change = DailyAssetChange.calculate(
      currentValueTry: 4250,
      snapshot: _snapshot(valueTry: 4000),
      hasPortfolioSnapshot: true,
      displayCurrency: 'TRY',
    );

    expect(change.formatPercent(), '+6.25%');
    expect(change.formatAmount(), '+₺250');
  });
}
