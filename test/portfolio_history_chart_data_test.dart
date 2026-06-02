import 'package:fidus/shared/models/portfolio_history_chart_data.dart';
import 'package:fidus/shared/models/portfolio_value_snapshot_model.dart';
import 'package:fidus/shared/utils/currency_utils.dart';
import 'package:flutter_test/flutter_test.dart';

PortfolioValueSnapshot _snapshot({
  required int day,
  required double valueTry,
  required double valueUsd,
}) {
  final date = DateTime(2026, 5, day);
  return PortfolioValueSnapshot(
    id: 'snapshot-$day',
    userId: 'user-1',
    portfolioId: 'portfolio-1',
    snapshotDate: date,
    valueTry: valueTry,
    valueUsd: valueUsd,
    usdTryRate: valueTry / valueUsd,
    assetCount: 2,
    capturedAt: date.add(const Duration(minutes: 5)),
    createdAt: date.add(const Duration(minutes: 5)),
  );
}

void main() {
  test('filters history range and uses static USD values', () {
    CurrencyUtils.updateRates({'TRY': 50});

    final data = PortfolioHistoryChartData.fromSnapshots(
      [
        _snapshot(day: 18, valueTry: 3000, valueUsd: 100),
        _snapshot(day: 22, valueTry: 4000, valueUsd: 120),
        _snapshot(day: 28, valueTry: 5000, valueUsd: 125),
      ],
      range: PortfolioHistoryRange.days7,
      displayCurrency: 'USD',
      now: DateTime(2026, 5, 28, 12),
    );

    expect(data.points.map((p) => p.date.day), [22, 28]);
    expect(data.points.map((p) => p.value), [120, 125]);
    expect(data.minValue, 120);
    expect(data.maxValue, 125);
  });

  test('keeps empty state until enough snapshots exist', () {
    final data = PortfolioHistoryChartData.fromSnapshots(
      [_snapshot(day: 28, valueTry: 5000, valueUsd: 125)],
      range: PortfolioHistoryRange.all,
      displayCurrency: 'TRY',
      now: DateTime(2026, 5, 28),
    );

    expect(data.hasEnoughData, isFalse);
  });

  test('builds professional axis scale with rounded money ticks', () {
    final data = PortfolioHistoryChartData.fromSnapshots(
      [
        _snapshot(day: 20, valueTry: 96400, valueUsd: 2400),
        _snapshot(day: 21, valueTry: 100250, valueUsd: 2500),
        _snapshot(day: 22, valueTry: 103200, valueUsd: 2580),
      ],
      range: PortfolioHistoryRange.all,
      displayCurrency: 'TRY',
      now: DateTime(2026, 5, 22),
    );

    expect(data.axis.minY, 94000);
    expect(data.axis.maxY, 104000);
    expect(data.axis.interval, 2000);
    expect(data.formatCompactMoney(data.axis.maxY, 'TRY'), '₺104K');
  });

  test('calculates range change against the first visible snapshot', () {
    final data = PortfolioHistoryChartData.fromSnapshots(
      [
        _snapshot(day: 20, valueTry: 100000, valueUsd: 2500),
        _snapshot(day: 21, valueTry: 101000, valueUsd: 2525),
        _snapshot(day: 22, valueTry: 104500, valueUsd: 2612.5),
      ],
      range: PortfolioHistoryRange.all,
      displayCurrency: 'TRY',
      now: DateTime(2026, 5, 22),
    );

    expect(data.periodChange.amount, 4500);
    expect(data.periodChange.percent, 4.5);
    expect(data.periodChange.isPositive, isTrue);
    expect(data.formatSignedMoney(data.periodChange.amount, 'TRY'), '+₺4.500');
  });
}
