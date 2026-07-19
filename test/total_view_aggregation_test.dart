import 'package:fidus/core/constants/app_constants.dart';
import 'package:fidus/shared/models/portfolio_asset_value_snapshot_model.dart';
import 'package:fidus/shared/models/portfolio_model.dart';
import 'package:fidus/shared/models/portfolio_value_snapshot_model.dart';
import 'package:fidus/shared/models/total_view_aggregation.dart';
import 'package:flutter_test/flutter_test.dart';

PortfolioModel _portfolio(
  String id, {
  DateTime? createdAt,
  bool includeInTotal = true,
}) {
  return PortfolioModel(
    id: id,
    userId: 'user-1',
    name: id,
    emoji: 'P',
    includeInTotal: includeInTotal,
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
  );
}

PortfolioValueSnapshot _portfolioSnapshot({
  required String portfolioId,
  required DateTime date,
  double valueTry = 1000,
  double valueUsd = 25,
  double usdTryRate = 40,
  int assetCount = 1,
  String userId = 'user-1',
}) {
  return PortfolioValueSnapshot(
    id: '$portfolioId-${date.toIso8601String()}',
    userId: userId,
    portfolioId: portfolioId,
    snapshotDate: date,
    valueTry: valueTry,
    valueUsd: valueUsd,
    usdTryRate: usdTryRate,
    fxRatesUpdatedAt: DateTime.utc(2026, 7, 18, 20, 55),
    assetCount: assetCount,
    capturedAt: DateTime.utc(2026, 7, 18, 21, 5),
    createdAt: DateTime.utc(2026, 7, 18, 21, 5),
  );
}

PortfolioAssetValueSnapshot _assetSnapshot({
  required String portfolioId,
  required String symbol,
  required double quantity,
  required double valueTry,
  required double valueUsd,
  int assetRowCount = 1,
}) {
  return PortfolioAssetValueSnapshot(
    id: '$portfolioId-$symbol',
    userId: 'user-1',
    portfolioId: portfolioId,
    snapshotDate: DateTime(2026, 7, 19),
    symbol: symbol,
    name: symbol == 'AAPL' ? 'Apple' : 'Bitcoin',
    type: symbol == 'AAPL' ? 'stock' : 'crypto',
    apiSource: symbol == 'AAPL' ? 'finnhub' : 'coingecko',
    apiId: symbol.toLowerCase(),
    quantity: quantity,
    valueTry: valueTry,
    valueUsd: valueUsd,
    usdTryRate: 40,
    fxRatesUpdatedAt: DateTime.utc(2026, 7, 18, 20, 55),
    assetRowCount: assetRowCount,
    capturedAt: DateTime.utc(2026, 7, 18, 21, 5),
    createdAt: DateTime.utc(2026, 7, 18, 21, 5),
  );
}

void main() {
  group('PortfolioModel total view field', () {
    test('defaults missing server field to included', () {
      final portfolio = PortfolioModel.fromJson({
        'id': 'portfolio-1',
        'user_id': 'user-1',
        'name': 'Ana',
        'emoji': 'P',
        'created_at': '2026-07-19T10:00:00Z',
      });

      expect(portfolio.includeInTotal, isTrue);
    });

    test('parses, serializes and copies explicit exclusion', () {
      final portfolio = PortfolioModel.fromJson({
        'id': 'portfolio-1',
        'user_id': 'user-1',
        'name': 'Ana',
        'emoji': 'P',
        'include_in_total': false,
        'created_at': '2026-07-19T10:00:00Z',
      });

      expect(portfolio.includeInTotal, isFalse);
      expect(portfolio.toJson()['include_in_total'], isFalse);
      expect(portfolio.copyWith(includeInTotal: true).includeInTotal, isTrue);
    });
  });

  group('aggregateTodaySnapshots', () {
    test('sums static TRY and USD values without recalculating currency', () {
      final date = DateTime(2026, 7, 19);
      final result = aggregateTodaySnapshots(
        [
          _portfolioSnapshot(
            portfolioId: 'portfolio-1',
            date: date,
            valueTry: 4000,
            valueUsd: 100,
            assetCount: 2,
          ),
          _portfolioSnapshot(
            portfolioId: 'portfolio-2',
            date: date,
            valueTry: 9000,
            valueUsd: 200,
            usdTryRate: 45,
            assetCount: 3,
          ),
        ],
        includedPortfolios: [
          _portfolio('portfolio-1'),
          _portfolio('portfolio-2'),
        ],
      );

      expect(result, isNotNull);
      expect(result!.portfolioId, kTotalPortfolioId);
      expect(result.valueTry, 13000);
      expect(result.valueUsd, 300);
      expect(result.assetCount, 5);
    });

    test('returns null for an empty snapshot set', () {
      expect(
        aggregateTodaySnapshots(
          const [],
          includedPortfolios: [_portfolio('portfolio-1')],
        ),
        isNull,
      );
    });

    test('returns null instead of exposing an incomplete total', () {
      final date = DateTime(2026, 7, 19);
      final result = aggregateTodaySnapshots(
        [_portfolioSnapshot(portfolioId: 'portfolio-1', date: date)],
        includedPortfolios: [
          _portfolio('portfolio-1'),
          _portfolio('portfolio-2'),
        ],
      );

      expect(result, isNull);
    });

    test('does not expect or include a portfolio created after the date', () {
      final date = DateTime(2026, 7, 18);
      final result = aggregateTodaySnapshots(
        [
          _portfolioSnapshot(
            portfolioId: 'portfolio-1',
            date: date,
            valueTry: 1000,
          ),
          _portfolioSnapshot(
            portfolioId: 'portfolio-2',
            date: date,
            valueTry: 9000,
          ),
        ],
        includedPortfolios: [
          _portfolio('portfolio-1'),
          _portfolio('portfolio-2', createdAt: DateTime.utc(2026, 7, 19, 8)),
        ],
      );

      expect(result, isNotNull);
      expect(result!.valueTry, 1000);
      expect(result.assetCount, 1);
    });

    test('treats a portfolio created after capture as a same-day addition', () {
      final date = DateTime(2026, 7, 19);
      final result = aggregateTodaySnapshots(
        [
          _portfolioSnapshot(
            portfolioId: 'portfolio-1',
            date: date,
            valueTry: 1000,
          ),
        ],
        includedPortfolios: [
          _portfolio('portfolio-1'),
          _portfolio('portfolio-2', createdAt: DateTime.utc(2026, 7, 19, 9)),
        ],
      );

      expect(result, isNotNull);
      expect(result!.valueTry, 1000);
    });

    test('still requires a same-day portfolio created before capture', () {
      final date = DateTime(2026, 7, 19);
      final result = aggregateTodaySnapshots(
        [_portfolioSnapshot(portfolioId: 'portfolio-1', date: date)],
        includedPortfolios: [
          _portfolio('portfolio-1'),
          _portfolio('portfolio-2', createdAt: DateTime.utc(2026, 7, 18, 21)),
        ],
      );

      expect(result, isNull);
    });

    test('rejects mixed dates and mixed users', () {
      final portfolios = [_portfolio('portfolio-1'), _portfolio('portfolio-2')];
      expect(
        aggregateTodaySnapshots([
          _portfolioSnapshot(
            portfolioId: 'portfolio-1',
            date: DateTime(2026, 7, 18),
          ),
          _portfolioSnapshot(
            portfolioId: 'portfolio-2',
            date: DateTime(2026, 7, 19),
          ),
        ], includedPortfolios: portfolios),
        isNull,
      );
      expect(
        aggregateTodaySnapshots([
          _portfolioSnapshot(
            portfolioId: 'portfolio-1',
            date: DateTime(2026, 7, 19),
          ),
          _portfolioSnapshot(
            portfolioId: 'portfolio-2',
            date: DateTime(2026, 7, 19),
            userId: 'user-2',
          ),
        ], includedPortfolios: portfolios),
        isNull,
      );
    });
  });

  group('aggregateSnapshotHistory', () {
    test('sorts complete dates and omits incomplete dates', () {
      final portfolios = [_portfolio('portfolio-1'), _portfolio('portfolio-2')];
      final result = aggregateSnapshotHistory([
        _portfolioSnapshot(
          portfolioId: 'portfolio-2',
          date: DateTime(2026, 7, 19),
          valueTry: 2500,
        ),
        _portfolioSnapshot(
          portfolioId: 'portfolio-1',
          date: DateTime(2026, 7, 18),
          valueTry: 1000,
        ),
        _portfolioSnapshot(
          portfolioId: 'portfolio-1',
          date: DateTime(2026, 7, 19),
          valueTry: 1500,
        ),
      ], includedPortfolios: portfolios);

      expect(result, hasLength(1));
      expect(result.single.snapshotDate, DateTime(2026, 7, 19));
      expect(result.single.valueTry, 4000);
    });

    test('keeps an old date complete before a newer portfolio existed', () {
      final result = aggregateSnapshotHistory(
        [
          _portfolioSnapshot(
            portfolioId: 'portfolio-1',
            date: DateTime(2026, 7, 18),
          ),
        ],
        includedPortfolios: [
          _portfolio('portfolio-1'),
          _portfolio('portfolio-2', createdAt: DateTime.utc(2026, 7, 19, 8)),
        ],
      );

      expect(result, hasLength(1));
      expect(result.single.valueTry, 1000);
    });
  });

  group('aggregateAssetSnapshotsBySymbol', () {
    test('merges matching symbols and preserves separate assets', () {
      final result = aggregateAssetSnapshotsBySymbol([
        _assetSnapshot(
          portfolioId: 'portfolio-1',
          symbol: 'AAPL',
          quantity: 2,
          valueTry: 8000,
          valueUsd: 200,
          assetRowCount: 2,
        ),
        _assetSnapshot(
          portfolioId: 'portfolio-2',
          symbol: 'BTC',
          quantity: 0.1,
          valueTry: 12000,
          valueUsd: 300,
        ),
        _assetSnapshot(
          portfolioId: 'portfolio-2',
          symbol: 'AAPL',
          quantity: 1,
          valueTry: 5000,
          valueUsd: 125,
        ),
      ]);

      expect(result.keys, containsAll(['AAPL', 'BTC']));
      final apple = result['AAPL']!;
      expect(apple.portfolioId, kTotalPortfolioId);
      expect(apple.name, 'Apple');
      expect(apple.quantity, 3);
      expect(apple.valueTry, 13000);
      expect(apple.valueUsd, 325);
      expect(apple.assetRowCount, 3);
      expect(result['BTC']!.valueTry, 12000);
    });

    test('returns an immutable empty map for no rows', () {
      final result = aggregateAssetSnapshotsBySymbol(const []);

      expect(result, isEmpty);
      expect(
        () => result['AAPL'] = _assetSnapshot(
          portfolioId: 'portfolio-1',
          symbol: 'AAPL',
          quantity: 1,
          valueTry: 1,
          valueUsd: 1,
        ),
        throwsUnsupportedError,
      );
    });
  });
}
