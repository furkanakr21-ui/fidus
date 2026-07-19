import 'package:fidus/core/constants/app_constants.dart';
import 'package:fidus/shared/models/portfolio_model.dart';
import 'package:fidus/shared/models/portfolio_scope.dart';
import 'package:fidus/shared/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PortfolioModel _portfolio(String id, {bool included = true}) {
  return PortfolioModel(
    id: id,
    userId: 'user-1',
    name: id,
    emoji: 'P',
    includeInTotal: included,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

ProviderContainer _container({
  required String activePortfolioId,
  required List<PortfolioModel> portfolios,
}) {
  return ProviderContainer(
    overrides: [
      activePortfolioProvider.overrideWithBuild(
        (ref, notifier) => activePortfolioId,
      ),
      portfoliosProvider.overrideWithBuild((ref, notifier) => portfolios),
    ],
  );
}

void main() {
  test('includedPortfolioIdsProvider excludes opted-out portfolios', () {
    final container = _container(
      activePortfolioId: 'portfolio-1',
      portfolios: [
        _portfolio('portfolio-1'),
        _portfolio('portfolio-2', included: false),
        _portfolio('portfolio-3'),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(includedPortfolioIdsProvider), [
      'portfolio-1',
      'portfolio-3',
    ]);
  });

  test('normal mode keeps exactly the active real portfolio in scope', () {
    final container = _container(
      activePortfolioId: 'portfolio-2',
      portfolios: [_portfolio('portfolio-1'), _portfolio('portfolio-2')],
    );
    addTearDown(container.dispose);

    final scope = container.read(portfolioScopeProvider);
    expect(container.read(isTotalViewProvider), isFalse);
    expect(scope.kind, PortfolioScopeKind.single);
    expect(scope.portfolioIds, ['portfolio-2']);
    expect(scope.singlePortfolioId, 'portfolio-2');
  });

  test('total mode contains only included portfolios', () {
    final container = _container(
      activePortfolioId: kTotalPortfolioId,
      portfolios: [
        _portfolio('portfolio-3'),
        _portfolio('portfolio-1'),
        _portfolio('portfolio-2', included: false),
      ],
    );
    addTearDown(container.dispose);

    final scope = container.read(portfolioScopeProvider);
    expect(container.read(isTotalViewProvider), isTrue);
    expect(scope.kind, PortfolioScopeKind.total);
    expect(scope.portfolioIds, ['portfolio-1', 'portfolio-3']);
  });

  test('empty total selection remains a total scope without fake UUIDs', () {
    final container = _container(
      activePortfolioId: kTotalPortfolioId,
      portfolios: [_portfolio('portfolio-1', included: false)],
    );
    addTearDown(container.dispose);

    final scope = container.read(portfolioScopeProvider);
    expect(scope.kind, PortfolioScopeKind.total);
    expect(scope.isEmpty, isTrue);
    expect(scope.portfolioIds, isEmpty);
    expect(scope.singlePortfolioId, isNull);
  });

  test('scope equality is order independent and detects stale requests', () {
    final requested = PortfolioScope.total(['portfolio-2', 'portfolio-1']);
    final sameScope = PortfolioScope.total(['portfolio-1', 'portfolio-2']);
    final newerScope = PortfolioScope.total(['portfolio-1']);

    expect(requested, sameScope);
    expect(requested.hashCode, sameScope.hashCode);
    expect(requested, isNot(newerScope));
  });

  test('sentinel can never become a real single-portfolio scope', () {
    final scope = PortfolioScope.single(kTotalPortfolioId);

    expect(scope.kind, PortfolioScopeKind.empty);
    expect(scope.portfolioIds, isEmpty);
  });

  test('startup readiness accepts a fully loaded total scope', () {
    final portfolio = _portfolio('portfolio-1');
    final container = ProviderContainer(
      overrides: [
        activePortfolioProvider.overrideWithBuild(
          (ref, notifier) => kTotalPortfolioId,
        ),
        portfoliosProvider.overrideWithBuild((ref, notifier) => [portfolio]),
        pricesProvider.overrideWithBuild(
          (ref, notifier) => const {'AAA_manual': PriceRecord(100, 'TRY')},
        ),
        exchangeRatesProvider.overrideWithBuild(
          (ref, notifier) => const {'TRY': 40},
        ),
        todayAssetSnapshotsProvider.overrideWithBuild(
          (ref, notifier) => const {},
        ),
        initialDataLoadTrackerProvider.overrideWithBuild(
          (ref, notifier) => InitialDataLoadTracker.requiredSections,
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(initialDataReadyProvider), isTrue);
  });
}
