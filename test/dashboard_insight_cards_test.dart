import 'package:fidus/features/dashboard/dashboard_screen.dart';
import 'package:fidus/core/theme/app_colors.dart';
import 'package:fidus/shared/models/asset_model.dart';
import 'package:fidus/shared/models/daily_asset_change.dart';
import 'package:fidus/shared/models/daily_portfolio_change.dart';
import 'package:fidus/shared/models/income_expense_model.dart';
import 'package:fidus/shared/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

CashFlowModel _cashflow({
  required String id,
  required CashFlowType type,
  required double amount,
  required DateTime date,
}) {
  return CashFlowModel(
    id: id,
    portfolioId: 'portfolio-1',
    title: id,
    amount: amount,
    currency: 'TRY',
    type: type,
    date: date,
  );
}

DailyAssetChange _change({required double amount, required double percent}) {
  return DailyAssetChange(
    hasPortfolioSnapshot: true,
    hasAssetSnapshot: true,
    currentValue: 0,
    baselineValue: 0,
    amount: amount,
    percent: percent,
    displayCurrency: 'TRY',
  );
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  final pushedRouteNames = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    pushedRouteNames.add(route.settings.name);
  }
}

void main() {
  testWidgets('dashboard shows monthly net flow and daily top gainer cards', (
    tester,
  ) async {
    final now = DateTime.now();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activePortfolioProvider.overrideWithBuild(
            (ref, notifier) => 'portfolio-1',
          ),
          assetsProvider.overrideWithBuild(
            (ref, notifier) => [_asset('AAA'), _asset('BBB')],
          ),
          priceLoadingProvider.overrideWithBuild((ref, notifier) => false),
          priceUpdateProvider.overrideWithBuild((ref, notifier) => null),
          cashflowProvider.overrideWithBuild(
            (ref, notifier) => [
              _cashflow(
                id: 'deposit',
                type: CashFlowType.deposit,
                amount: 5000,
                date: DateTime(now.year, now.month, 5),
              ),
              _cashflow(
                id: 'withdrawal',
                type: CashFlowType.withdrawal,
                amount: 2000,
                date: DateTime(now.year, now.month, 6),
              ),
              _cashflow(
                id: 'previous-month',
                type: CashFlowType.deposit,
                amount: 9000,
                date: DateTime(now.year, now.month - 1, 20),
              ),
            ],
          ),
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
          dailyAssetChangesProvider.overrideWithValue({
            'AAA': _change(amount: 300, percent: 2),
            'BBB': _change(amount: 100, percent: 5),
          }),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    expect(find.text('Bu Ay Net Akış'), findsOneWidget);
    expect(find.text('+₺3.000'), findsOneWidget);
    expect(find.text('Bugünün Lideri'), findsOneWidget);
    expect(find.text('BBB'), findsOneWidget);
    expect(find.textContaining('+5.00%'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Tümünü gör →'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.widget<Text>(find.text('Tümünü gör →')).style?.color,
      AppColors.lightPrimary,
    );
  });

  testWidgets('dashboard insight cards show stable empty states', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activePortfolioProvider.overrideWithBuild(
            (ref, notifier) => 'portfolio-1',
          ),
          assetsProvider.overrideWithBuild((ref, notifier) => [_asset('AAA')]),
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

    expect(find.text('Bu Ay Net Akış'), findsOneWidget);
    expect(find.text('₺0'), findsOneWidget);
    expect(find.text('Bugünün Lideri'), findsOneWidget);
    expect(find.text('Bekleniyor'), findsWidgets);
  });

  testWidgets('dashboard top area avoids duplicated cost and daily stats', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activePortfolioProvider.overrideWithBuild(
            (ref, notifier) => 'portfolio-1',
          ),
          assetsProvider.overrideWithBuild((ref, notifier) => [_asset('AAA')]),
          priceLoadingProvider.overrideWithBuild((ref, notifier) => false),
          priceUpdateProvider.overrideWithBuild((ref, notifier) => null),
          cashflowProvider.overrideWithBuild((ref, notifier) => const []),
          goalsProvider.overrideWithBuild((ref, notifier) => const []),
          currencyProvider.overrideWithBuild((ref, notifier) => 'TRY'),
          dailyPortfolioChangeProvider.overrideWithValue(
            const DailyPortfolioChange(
              hasSnapshot: true,
              currentValue: 10500,
              baselineValue: 10000,
              amount: 500,
              percent: 5,
              displayCurrency: 'TRY',
            ),
          ),
          dailyAssetChangesProvider.overrideWithValue(const {}),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    expect(find.text('Maliyet'), findsNothing);
    expect(find.text('Yatırım'), findsNothing);
    expect(find.text('Varlık'), findsNothing);
    expect(find.text('+₺500'), findsOneWidget);
    expect(find.text('+5.00%'), findsOneWidget);
  });

  testWidgets(
    'dashboard feature cards clip decorative layers to rounded edges',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activePortfolioProvider.overrideWithBuild(
              (ref, notifier) => 'portfolio-1',
            ),
            assetsProvider.overrideWithBuild(
              (ref, notifier) => [_asset('AAA')],
            ),
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

      final hero = tester.widget<Container>(
        find.byKey(const Key('dashboard-hero-card')),
      );
      expect(hero.clipBehavior, Clip.antiAlias);

      final insightCards = tester.widgetList<Container>(
        find.byKey(const Key('dashboard-insight-card')),
      );
      expect(insightCards, hasLength(2));
      expect(
        insightCards.every((card) => card.clipBehavior == Clip.antiAlias),
        isTrue,
      );

      final discovery = tester.widget<Material>(
        find.byKey(const Key('dashboard-fund-discovery-card')),
      );
      expect(discovery.clipBehavior, Clip.antiAlias);
    },
  );

  testWidgets('light dashboard hero uses the graphite jade identity gradient', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activePortfolioProvider.overrideWithBuild(
            (ref, notifier) => 'portfolio-1',
          ),
          assetsProvider.overrideWithBuild((ref, notifier) => [_asset('AAA')]),
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

    final hero = tester.widget<Container>(
      find.byKey(const Key('dashboard-hero-card')),
    );
    final decoration = hero.decoration! as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors, const [
      Color(0xFF203B45),
      Color(0xFF176B65),
      Color(0xFF13917C),
    ]);
  });

  testWidgets('light dashboard hero keeps positive daily values readable', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activePortfolioProvider.overrideWithBuild(
            (ref, notifier) => 'portfolio-1',
          ),
          assetsProvider.overrideWithBuild((ref, notifier) => [_asset('AAA')]),
          priceLoadingProvider.overrideWithBuild((ref, notifier) => false),
          priceUpdateProvider.overrideWithBuild((ref, notifier) => null),
          cashflowProvider.overrideWithBuild((ref, notifier) => const []),
          goalsProvider.overrideWithBuild((ref, notifier) => const []),
          currencyProvider.overrideWithBuild((ref, notifier) => 'TRY'),
          dailyPortfolioChangeProvider.overrideWithValue(
            const DailyPortfolioChange(
              hasSnapshot: true,
              currentValue: 10500,
              baselineValue: 10000,
              amount: 500,
              percent: 5,
              displayCurrency: 'TRY',
            ),
          ),
          dailyAssetChangesProvider.overrideWithValue(const {}),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    expect(
      tester.widget<Text>(find.text('+5.00%')).style?.color,
      AppColors.profit,
    );
    expect(
      tester.widget<Text>(find.text('+₺500')).style?.color,
      AppColors.profit,
    );
  });

  testWidgets(
    'dark dashboard hero uses the deeper electric identity gradient',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activePortfolioProvider.overrideWithBuild(
              (ref, notifier) => 'portfolio-1',
            ),
            assetsProvider.overrideWithBuild(
              (ref, notifier) => [_asset('AAA')],
            ),
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
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const DashboardScreen(),
          ),
        ),
      );

      final hero = tester.widget<Container>(
        find.byKey(const Key('dashboard-hero-card')),
      );
      final decoration = hero.decoration! as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;
      expect(gradient.colors, const [
        Color(0xFF0B334B),
        Color(0xFF005A4B),
        Color(0xFF008A67),
      ]);
    },
  );

  testWidgets('fund discovery card opens the TEFAS browser route', (
    tester,
  ) async {
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activePortfolioProvider.overrideWithBuild(
            (ref, notifier) => 'portfolio-1',
          ),
          assetsProvider.overrideWithBuild((ref, notifier) => [_asset('AAA')]),
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
        child: MaterialApp(
          navigatorObservers: [observer],
          home: const DashboardScreen(),
        ),
      ),
    );

    expect(find.text('TEFAS ve BES Fonlarını Keşfet'), findsOneWidget);
    expect(
      find.text('3.000+ fonu getiri ve riske göre karşılaştır'),
      findsOneWidget,
    );

    await tester.tap(find.text('TEFAS ve BES Fonlarını Keşfet'));

    expect(observer.pushedRouteNames, contains('/tefas-browser'));
  });
}
