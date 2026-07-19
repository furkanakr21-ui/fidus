import 'package:fidus/core/constants/app_constants.dart';
import 'package:fidus/features/budget/add_cashflow_screen.dart';
import 'package:fidus/features/goals/add_goal_sheet.dart';
import 'package:fidus/features/portfolio/add_buy_sheet.dart';
import 'package:fidus/shared/models/asset_model.dart';
import 'package:fidus/shared/models/portfolio_model.dart';
import 'package:fidus/shared/models/portfolio_write_target.dart';
import 'package:fidus/shared/providers.dart';
import 'package:fidus/shared/widgets/portfolio_picker.dart';
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
  required String symbol,
  required double quantity,
  required DateTime buyDate,
  DateTime? createdAt,
}) {
  return AssetModel(
    id: id,
    portfolioId: portfolioId,
    name: symbol,
    symbol: symbol,
    type: AssetType.stock,
    quantity: quantity,
    buyPrice: 100,
    buyDate: buyDate,
    createdAt: createdAt,
  );
}

ProviderScope _scope({
  required String activePortfolioId,
  required List<PortfolioModel> portfolios,
  List<AssetModel> assets = const [],
  required Widget child,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      activePortfolioProvider.overrideWithBuild(
        (ref, notifier) => activePortfolioId,
      ),
      portfoliosProvider.overrideWithBuild((ref, notifier) => portfolios),
      assetsProvider.overrideWithBuild((ref, notifier) => assets),
    ],
    child: MaterialApp(home: Material(child: child)),
  );
}

void main() {
  group('write portfolio resolution', () {
    test('never returns the virtual total id as a write target', () {
      expect(
        resolveWritePortfolioId(activePortfolioId: kTotalPortfolioId),
        isNull,
      );
      expect(
        resolveWritePortfolioId(
          activePortfolioId: kTotalPortfolioId,
          selectedPortfolioId: kTotalPortfolioId,
        ),
        isNull,
      );
    });

    test('normal mode preserves the real active portfolio', () {
      expect(
        resolveWritePortfolioId(
          activePortfolioId: 'portfolio-1',
          selectedPortfolioId: 'portfolio-2',
        ),
        'portfolio-1',
      );
    });

    test('total mode requires and returns an explicit real portfolio', () {
      expect(
        resolveWritePortfolioId(
          activePortfolioId: kTotalPortfolioId,
          selectedPortfolioId: 'portfolio-2',
        ),
        'portfolio-2',
      );
    });
  });

  group('symbol holdings', () {
    final portfolios = [
      _portfolio('portfolio-1', 'Ana'),
      _portfolio('portfolio-2', 'Uzun Vade'),
    ];
    final assets = [
      _asset(
        id: 'lot-1',
        portfolioId: 'portfolio-1',
        symbol: 'AAA',
        quantity: 2,
        buyDate: DateTime(2026, 1, 1),
      ),
      _asset(
        id: 'lot-2',
        portfolioId: 'portfolio-1',
        symbol: 'AAA',
        quantity: 3,
        buyDate: DateTime(2026, 1, 2),
      ),
      _asset(
        id: 'lot-3',
        portfolioId: 'portfolio-2',
        symbol: 'AAA',
        quantity: 7,
        buyDate: DateTime(2026, 1, 3),
      ),
      _asset(
        id: 'other',
        portfolioId: 'portfolio-2',
        symbol: 'BBB',
        quantity: 99,
        buyDate: DateTime(2026, 1, 3),
      ),
    ];

    test('keeps quantities and lot counts separated by portfolio', () {
      final holdings = portfolioHoldingsForSymbol(
        assets: assets,
        portfolios: portfolios,
        symbol: 'AAA',
      );

      expect(holdings, hasLength(2));
      expect(holdings[0].portfolio.id, 'portfolio-1');
      expect(holdings[0].quantity, 5);
      expect(holdings[0].lotCount, 2);
      expect(holdings[1].portfolio.id, 'portfolio-2');
      expect(holdings[1].quantity, 7);
      expect(holdings[1].lotCount, 1);
    });

    test('auto-selects one holding and requires selection for multiple', () {
      final allHoldings = portfolioHoldingsForSymbol(
        assets: assets,
        portfolios: portfolios,
        symbol: 'AAA',
      );
      final oneHolding = [allHoldings.first];

      expect(
        resolveSymbolWritePortfolioId(
          activePortfolioId: kTotalPortfolioId,
          holdings: oneHolding,
        ),
        'portfolio-1',
      );
      expect(
        resolveSymbolWritePortfolioId(
          activePortfolioId: kTotalPortfolioId,
          holdings: allHoldings,
        ),
        isNull,
      );
      expect(
        resolveSymbolWritePortfolioId(
          activePortfolioId: kTotalPortfolioId,
          holdings: allHoldings,
          selectedPortfolioId: 'portfolio-2',
        ),
        'portfolio-2',
      );
      expect(
        resolveSymbolWritePortfolioId(
          activePortfolioId: kTotalPortfolioId,
          holdings: allHoldings,
          selectedPortfolioId: 'not-a-holding',
        ),
        isNull,
      );
    });
  });

  test('FIFO order uses buy date, creation time and id', () {
    final lots = [
      _asset(
        id: 'c',
        portfolioId: 'portfolio-1',
        symbol: 'AAA',
        quantity: 1,
        buyDate: DateTime(2026, 1, 2),
        createdAt: DateTime.utc(2026, 1, 2, 9),
      ),
      _asset(
        id: 'b',
        portfolioId: 'portfolio-1',
        symbol: 'AAA',
        quantity: 1,
        buyDate: DateTime(2026, 1, 1),
        createdAt: DateTime.utc(2026, 1, 1, 10),
      ),
      _asset(
        id: 'a',
        portfolioId: 'portfolio-1',
        symbol: 'AAA',
        quantity: 1,
        buyDate: DateTime(2026, 1, 1),
        createdAt: DateTime.utc(2026, 1, 1, 9),
      ),
    ]..sort(compareAssetLotsForFifo);

    expect(lots.map((lot) => lot.id), ['a', 'b', 'c']);
  });

  testWidgets('target field returns the selected real portfolio', (
    tester,
  ) async {
    final portfolios = [
      _portfolio('portfolio-1', 'Ana'),
      _portfolio('portfolio-2', 'Uzun Vade'),
    ];
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TargetPortfolioField(
            portfolios: portfolios,
            selectedPortfolioId: null,
            onChanged: (id) => selected = id,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('target_portfolio_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uzun Vade'));
    await tester.pumpAndSettle();

    expect(selected, 'portfolio-2');
  });

  testWidgets('cash flow and goal target fields appear only in total mode', (
    tester,
  ) async {
    final portfolios = [_portfolio('portfolio-1', 'Ana')];
    await tester.pumpWidget(
      _scope(
        activePortfolioId: 'portfolio-1',
        portfolios: portfolios,
        child: const AddCashFlowScreen(isDeposit: true),
      ),
    );
    expect(find.byKey(const ValueKey('target_portfolio_field')), findsNothing);

    await tester.pumpWidget(
      _scope(
        activePortfolioId: kTotalPortfolioId,
        portfolios: portfolios,
        child: const AddCashFlowScreen(isDeposit: true),
      ),
    );
    expect(
      find.byKey(const ValueKey('target_portfolio_field')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _scope(
        activePortfolioId: kTotalPortfolioId,
        portfolios: portfolios,
        child: const Scaffold(body: AddGoalSheet()),
      ),
    );
    expect(
      find.byKey(const ValueKey('target_portfolio_field')),
      findsOneWidget,
    );
  });

  testWidgets('buy target field appears for a symbol in two portfolios', (
    tester,
  ) async {
    final portfolios = [
      _portfolio('portfolio-1', 'Ana'),
      _portfolio('portfolio-2', 'Uzun Vade'),
    ];
    final lots = [
      _asset(
        id: 'lot-1',
        portfolioId: 'portfolio-1',
        symbol: 'AAA',
        quantity: 1,
        buyDate: DateTime(2026, 1, 1),
      ),
      _asset(
        id: 'lot-2',
        portfolioId: 'portfolio-2',
        symbol: 'AAA',
        quantity: 1,
        buyDate: DateTime(2026, 1, 1),
      ),
    ];
    await tester.pumpWidget(
      _scope(
        activePortfolioId: kTotalPortfolioId,
        portfolios: portfolios,
        assets: lots,
        child: AddBuySheet(mergedAsset: lots.first),
      ),
    );

    expect(
      find.byKey(const ValueKey('target_portfolio_field')),
      findsOneWidget,
    );
  });
}
