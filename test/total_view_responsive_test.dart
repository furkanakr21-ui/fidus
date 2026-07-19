import 'package:fidus/core/constants/app_constants.dart';
import 'package:fidus/core/theme/app_theme.dart';
import 'package:fidus/features/dashboard/dashboard_screen.dart';
import 'package:fidus/features/portfolio/position_sheet.dart';
import 'package:fidus/shared/models/asset_model.dart';
import 'package:fidus/shared/models/daily_asset_change.dart';
import 'package:fidus/shared/models/daily_portfolio_change.dart';
import 'package:fidus/shared/models/portfolio_model.dart';
import 'package:fidus/shared/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PortfolioModel _portfolio(String id, String name) {
  return PortfolioModel(
    id: id,
    userId: 'user-1',
    name: name,
    emoji: 'P',
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

AssetModel _asset({
  required String id,
  required String portfolioId,
  required String name,
  required String symbol,
  required AssetType type,
  required double quantity,
  required double buyPrice,
  required double currentPrice,
}) {
  return AssetModel(
    id: id,
    portfolioId: portfolioId,
    name: name,
    symbol: symbol,
    type: type,
    quantity: quantity,
    buyPrice: buyPrice,
    currentPrice: currentPrice,
    buyDate: DateTime(2026, 1, 1),
    currency: 'TRY',
  );
}

void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('total dashboard category metadata wraps without overflow', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final portfolios = [
      _portfolio('portfolio-1', 'Ana'),
      _portfolio('portfolio-2', 'Uzun Vade'),
    ];
    final assets = [
      _asset(
        id: 'asset-1',
        portfolioId: 'portfolio-1',
        name: 'Aselsan',
        symbol: 'ASELS',
        type: AssetType.stock,
        quantity: 5000,
        buyPrice: 72,
        currentPrice: 81.4,
      ),
      _asset(
        id: 'asset-2',
        portfolioId: 'portfolio-2',
        name: 'Aselsan',
        symbol: 'ASELS',
        type: AssetType.stock,
        quantity: 2500,
        buyPrice: 76,
        currentPrice: 81.4,
      ),
      _asset(
        id: 'asset-3',
        portfolioId: 'portfolio-2',
        name: 'Ak Portföy Teknoloji Fonu',
        symbol: 'AFT',
        type: AssetType.fund,
        quantity: 2200,
        buyPrice: 1.85,
        currentPrice: 2.14,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activePortfolioProvider.overrideWithBuild(
            (ref, notifier) => kTotalPortfolioId,
          ),
          portfoliosProvider.overrideWithBuild((ref, notifier) => portfolios),
          assetsProvider.overrideWithBuild((ref, notifier) => assets),
          priceLoadingProvider.overrideWithBuild((ref, notifier) => false),
          priceUpdateProvider.overrideWithBuild((ref, notifier) => null),
          cashflowProvider.overrideWithBuild((ref, notifier) => const []),
          goalsProvider.overrideWithBuild((ref, notifier) => const []),
          currencyProvider.overrideWithBuild((ref, notifier) => 'TRY'),
          dailyPortfolioChangeProvider.overrideWithValue(
            const DailyPortfolioChange(
              hasSnapshot: true,
              currentValue: 16930,
              baselineValue: 16480,
              amount: 450,
              percent: 2.73,
              displayCurrency: 'TRY',
            ),
          ),
          dailyAssetChangesProvider.overrideWithValue({
            'ASELS': const DailyAssetChange(
              hasPortfolioSnapshot: true,
              hasAssetSnapshot: true,
              currentValue: 12210,
              baselineValue: 11840,
              amount: 370,
              percent: 3.13,
              displayCurrency: 'TRY',
            ),
            'AFT': const DailyAssetChange(
              hasPortfolioSnapshot: true,
              hasAssetSnapshot: true,
              currentValue: 4720,
              baselineValue: 4640,
              amount: 80,
              percent: 1.72,
              displayCurrency: 'TRY',
            ),
          }),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 varlık'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared position and sale picker stay clear on a phone', (
    tester,
  ) async {
    _setPhoneSize(tester);
    final portfolios = [
      _portfolio('portfolio-1', 'Ana Portföy'),
      _portfolio('portfolio-2', 'Uzun Vade'),
    ];
    final lots = [
      _asset(
        id: 'asset-1',
        portfolioId: 'portfolio-1',
        name: 'Aselsan Elektronik',
        symbol: 'ASELS',
        type: AssetType.stock,
        quantity: 100,
        buyPrice: 72,
        currentPrice: 81.4,
      ),
      _asset(
        id: 'asset-2',
        portfolioId: 'portfolio-2',
        name: 'Aselsan Elektronik',
        symbol: 'ASELS',
        type: AssetType.stock,
        quantity: 50,
        buyPrice: 76,
        currentPrice: 81.4,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activePortfolioProvider.overrideWithBuild(
            (ref, notifier) => kTotalPortfolioId,
          ),
          portfoliosProvider.overrideWithBuild((ref, notifier) => portfolios),
          assetsProvider.overrideWithBuild((ref, notifier) => lots),
          currencyProvider.overrideWithBuild((ref, notifier) => 'TRY'),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PositionSheet(
                mergedAsset: lots.first.copyWith(
                  quantity: 150,
                  buyPrice: 73.33,
                ),
                allLots: lots,
                portfolioWeight: 63.4,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 alım lotu · 2 portföy'), findsOneWidget);
    expect(find.text('Toplam içindeki payı %63.4'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Satış Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Satış Portföyü'), findsOneWidget);
    expect(find.text('100 adet kullanılabilir'), findsOneWidget);
    expect(find.text('50 adet kullanılabilir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
