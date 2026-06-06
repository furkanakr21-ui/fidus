import 'package:fidus/core/theme/app_theme.dart';
import 'package:fidus/core/theme/app_colors.dart';
import 'package:fidus/features/budget/budget_screen.dart';
import 'package:fidus/features/portfolio/portfolio_screen.dart';
import 'package:fidus/shared/models/asset_model.dart';
import 'package:fidus/shared/models/daily_portfolio_change.dart';
import 'package:fidus/shared/models/income_expense_model.dart';
import 'package:fidus/shared/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AssetModel _asset(String id, AssetType type) {
  return AssetModel(
    id: id,
    portfolioId: 'portfolio-1',
    name: id,
    symbol: id,
    type: type,
    quantity: 1,
    buyPrice: 100,
    currentPrice: 100,
    buyDate: DateTime(2026, 6, 1),
  );
}

void main() {
  testWidgets('portfolio and cash flow summary cards use semantic gradients', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activePortfolioProvider.overrideWithBuild(
            (ref, notifier) => 'portfolio-1',
          ),
          assetsProvider.overrideWithBuild(
            (ref, notifier) => [_asset('AAA', AssetType.stock)],
          ),
          exchangeRatesProvider.overrideWithBuild((ref, notifier) => const {}),
          portfolioSnapshotHistoryProvider.overrideWithBuild(
            (ref, notifier) => const [],
          ),
          priceLoadingProvider.overrideWithBuild((ref, notifier) => false),
          priceUpdateProvider.overrideWithBuild((ref, notifier) => null),
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
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const PortfolioScreen()),
      ),
    );

    final portfolioCard = tester.widget<Container>(
      find.byKey(const Key('portfolio-summary-card')),
    );
    final portfolioDecoration = portfolioCard.decoration! as BoxDecoration;
    expect(portfolioDecoration.gradient, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cashflowProvider.overrideWithBuild(
            (ref, notifier) => [
              CashFlowModel(
                id: 'deposit',
                portfolioId: 'portfolio-1',
                title: 'Ekleme',
                amount: 100,
                currency: 'TRY',
                type: CashFlowType.deposit,
                date: DateTime(2026, 6, 1),
              ),
            ],
          ),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const BudgetScreen()),
      ),
    );

    final cashFlowCard = tester.widget<Container>(
      find.byKey(const Key('cash-flow-summary-card')),
    );
    final cashFlowDecoration = cashFlowCard.decoration! as BoxDecoration;
    expect(cashFlowDecoration.gradient, isNotNull);
  });

  testWidgets('portfolio distribution percentages stay on one line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activePortfolioProvider.overrideWithBuild(
            (ref, notifier) => 'portfolio-1',
          ),
          assetsProvider.overrideWithBuild(
            (ref, notifier) => [_asset('AAA', AssetType.stock)],
          ),
          exchangeRatesProvider.overrideWithBuild((ref, notifier) => const {}),
          portfolioSnapshotHistoryProvider.overrideWithBuild(
            (ref, notifier) => const [],
          ),
          priceLoadingProvider.overrideWithBuild((ref, notifier) => false),
          priceUpdateProvider.overrideWithBuild((ref, notifier) => null),
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
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const PortfolioScreen()),
      ),
    );

    final percentage = tester.widget<Text>(
      find.byKey(const Key('portfolio-distribution-percentage')).first,
    );
    expect(percentage.maxLines, 1);
    expect(percentage.softWrap, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'light portfolio and cash flow summary cards remain fully colored',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activePortfolioProvider.overrideWithBuild(
              (ref, notifier) => 'portfolio-1',
            ),
            assetsProvider.overrideWithBuild(
              (ref, notifier) => [_asset('AAA', AssetType.stock)],
            ),
            exchangeRatesProvider.overrideWithBuild(
              (ref, notifier) => const {},
            ),
            portfolioSnapshotHistoryProvider.overrideWithBuild(
              (ref, notifier) => const [],
            ),
            priceLoadingProvider.overrideWithBuild((ref, notifier) => false),
            priceUpdateProvider.overrideWithBuild((ref, notifier) => null),
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
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const PortfolioScreen(),
          ),
        ),
      );

      final portfolioCard = tester.widget<Container>(
        find.byKey(const Key('portfolio-summary-card')),
      );
      expect((portfolioCard.decoration! as BoxDecoration).gradient, isNotNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashflowProvider.overrideWithBuild(
              (ref, notifier) => [
                CashFlowModel(
                  id: 'deposit',
                  portfolioId: 'portfolio-1',
                  title: 'Ekleme',
                  amount: 100,
                  currency: 'TRY',
                  type: CashFlowType.deposit,
                  date: DateTime(2026, 6, 1),
                ),
              ],
            ),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const BudgetScreen()),
        ),
      );

      final cashFlowCard = tester.widget<Container>(
        find.byKey(const Key('cash-flow-summary-card')),
      );
      expect((cashFlowCard.decoration! as BoxDecoration).gradient, isNotNull);
    },
  );

  testWidgets('light cash flow values use the readable positive green', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cashflowProvider.overrideWithBuild(
            (ref, notifier) => [
              CashFlowModel(
                id: 'deposit',
                portfolioId: 'portfolio-1',
                title: 'Ekleme',
                amount: 100,
                currency: 'TRY',
                type: CashFlowType.deposit,
                date: DateTime(2026, 6, 1),
              ),
            ],
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const BudgetScreen()),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && widget.style?.color == AppColors.lightProfit,
      ),
      findsWidgets,
    );
    expect(
      tester.widget<Text>(find.text('1 adet')).style?.color,
      AppColors.lightText,
    );
  });
}
