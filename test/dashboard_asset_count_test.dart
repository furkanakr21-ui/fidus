import 'package:fidus/features/dashboard/dashboard_screen.dart';
import 'package:fidus/shared/models/asset_model.dart';
import 'package:fidus/shared/models/daily_portfolio_change.dart';
import 'package:fidus/shared/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AssetModel _asset({
  required String id,
  required double quantity,
  required double buyPrice,
}) {
  return AssetModel(
    id: id,
    portfolioId: 'portfolio-1',
    name: 'Türk Hava Yolları',
    symbol: 'THYAO',
    type: AssetType.stock,
    quantity: quantity,
    buyPrice: buyPrice,
    currentPrice: 300,
    buyDate: DateTime(2026, 6, 1),
    apiSource: 'yahoo',
    apiId: 'THYAO.IS',
  );
}

void main() {
  testWidgets('dashboard asset statistic counts merged assets', (tester) async {
    final rawLots = [
      _asset(id: 'asset-1', quantity: 1, buyPrice: 250),
      _asset(id: 'asset-2', quantity: 2, buyPrice: 275),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activePortfolioProvider.overrideWithBuild(
            (ref, notifier) => 'portfolio-1',
          ),
          assetsProvider.overrideWithBuild((ref, notifier) => rawLots),
          priceLoadingProvider.overrideWithBuild((ref, notifier) => false),
          priceUpdateProvider.overrideWithBuild((ref, notifier) => null),
          cashflowProvider.overrideWithBuild((ref, notifier) => const []),
          goalsProvider.overrideWithBuild((ref, notifier) => const []),
          currencyProvider.overrideWithBuild((ref, notifier) => 'TRY'),
          dailyPortfolioChangeProvider.overrideWithValue(
            const DailyPortfolioChange(
              hasSnapshot: false,
              currentValue: 0,
              baselineValue: 0,
              amount: 0,
              percent: 0,
              displayCurrency: 'TRY',
            ),
          ),
          dailyAssetChangesProvider.overrideWithValue(const {}),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    expect(find.text('1 adet'), findsOneWidget);
    expect(find.text('2 adet'), findsNothing);
  });
}
