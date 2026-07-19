import 'dart:async';

import 'package:fidus/core/constants/app_constants.dart';
import 'package:fidus/shared/models/portfolio_model.dart';
import 'package:fidus/shared/providers.dart';
import 'package:fidus/shared/services/portfolio_service.dart';
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

class _MemoryPortfolioDataSource implements PortfolioDataSource {
  List<PortfolioModel> portfolios;
  final Map<String, dynamic> settings;
  bool failIncludeWrite = false;
  Completer<void>? totalViewWriteGate;
  int totalViewActiveWrites = 0;

  _MemoryPortfolioDataSource({
    required this.portfolios,
    required String? activePortfolioId,
    required bool totalViewActive,
  }) : settings = {
         'theme': 'system',
         'currency': 'TRY',
         'active_portfolio_id': activePortfolioId,
         'total_view_active': totalViewActive,
       };

  @override
  Future<List<PortfolioModel>> getAll() async => [...portfolios];

  @override
  Future<PortfolioModel> create(String name, String emoji) async {
    final portfolio = _portfolio('created-${portfolios.length + 1}');
    portfolios = [...portfolios, portfolio];
    return portfolio;
  }

  @override
  Future<void> delete(String id) async {
    portfolios = portfolios.where((portfolio) => portfolio.id != id).toList();
  }

  @override
  Future<Map<String, dynamic>> getSettings() async => {...settings};

  @override
  Future<void> saveSettings({String? theme, String? currency}) async {
    if (theme != null) settings['theme'] = theme;
    if (currency != null) settings['currency'] = currency;
  }

  @override
  Future<void> setActivePortfolio(String portfolioId) async {
    settings['active_portfolio_id'] = portfolioId;
    settings['total_view_active'] = false;
  }

  @override
  Future<void> setIncludeInTotal(String portfolioId, bool value) async {
    if (failIncludeWrite) throw StateError('include write failed');
    portfolios = [
      for (final portfolio in portfolios)
        if (portfolio.id == portfolioId)
          portfolio.copyWith(includeInTotal: value)
        else
          portfolio,
    ];
  }

  @override
  Future<void> setTotalViewActive() async {
    totalViewActiveWrites++;
    await totalViewWriteGate?.future;
    settings['total_view_active'] = true;
  }

  @override
  Future<void> setTotalViewInactive() async {
    settings['total_view_active'] = false;
  }
}

ProviderContainer _container(_MemoryPortfolioDataSource dataSource) {
  return ProviderContainer(
    overrides: [portfolioDataSourceProvider.overrideWithValue(dataSource)],
  );
}

Future<void> _loadPortfolioState(ProviderContainer container) async {
  container.read(portfoliosProvider);
  container.read(activePortfolioProvider);
  await pumpEventQueue(times: 20);
}

void main() {
  test('server total preference restores the virtual total view', () async {
    final dataSource = _MemoryPortfolioDataSource(
      portfolios: [_portfolio('p1'), _portfolio('p2')],
      activePortfolioId: 'p1',
      totalViewActive: true,
    );
    final container = _container(dataSource);
    addTearDown(container.dispose);

    await _loadPortfolioState(container);

    expect(container.read(activePortfolioProvider), kTotalPortfolioId);
    expect(container.read(portfolioScopeProvider).portfolioIds, ['p1', 'p2']);
    expect(dataSource.settings['active_portfolio_id'], 'p1');
  });

  test(
    'startup repairs an invalid total preference with no inclusions',
    () async {
      final dataSource = _MemoryPortfolioDataSource(
        portfolios: [_portfolio('p1', included: false)],
        activePortfolioId: 'p1',
        totalViewActive: true,
      );
      final container = _container(dataSource);
      addTearDown(container.dispose);

      await _loadPortfolioState(container);

      expect(container.read(activePortfolioProvider), 'p1');
      expect(dataSource.settings['total_view_active'], isFalse);
      expect(dataSource.settings['active_portfolio_id'], 'p1');
    },
  );

  test(
    'total selection is rejected when every portfolio is excluded',
    () async {
      final dataSource = _MemoryPortfolioDataSource(
        portfolios: [_portfolio('p1', included: false)],
        activePortfolioId: 'p1',
        totalViewActive: false,
      );
      final container = _container(dataSource);
      addTearDown(container.dispose);
      await _loadPortfolioState(container);

      final selected = await container
          .read(activePortfolioProvider.notifier)
          .switchPortfolio(kTotalPortfolioId);

      expect(selected, isFalse);
      expect(container.read(activePortfolioProvider), 'p1');
      expect(dataSource.totalViewActiveWrites, 0);
    },
  );

  test(
    'total selection never stores the sentinel as the active UUID',
    () async {
      final dataSource = _MemoryPortfolioDataSource(
        portfolios: [_portfolio('p1')],
        activePortfolioId: 'p1',
        totalViewActive: false,
      );
      final container = _container(dataSource);
      addTearDown(container.dispose);
      await _loadPortfolioState(container);

      final selected = await container
          .read(activePortfolioProvider.notifier)
          .switchPortfolio(kTotalPortfolioId);

      expect(selected, isTrue);
      expect(container.read(activePortfolioProvider), kTotalPortfolioId);
      expect(dataSource.settings['total_view_active'], isTrue);
      expect(dataSource.settings['active_portfolio_id'], 'p1');
    },
  );

  test('failed inclusion write restores the previous local value', () async {
    final dataSource = _MemoryPortfolioDataSource(
      portfolios: [_portfolio('p1')],
      activePortfolioId: 'p1',
      totalViewActive: false,
    );
    final container = _container(dataSource);
    addTearDown(container.dispose);
    await _loadPortfolioState(container);
    dataSource.failIncludeWrite = true;

    await expectLater(
      container
          .read(portfoliosProvider.notifier)
          .setIncludeInTotal('p1', false),
      throwsStateError,
    );

    expect(container.read(portfoliosProvider).single.includeInTotal, isTrue);
    expect(dataSource.portfolios.single.includeInTotal, isTrue);
  });

  test(
    'removing the last included portfolio safely exits total view',
    () async {
      final dataSource = _MemoryPortfolioDataSource(
        portfolios: [_portfolio('p1')],
        activePortfolioId: 'p1',
        totalViewActive: true,
      );
      final container = _container(dataSource);
      addTearDown(container.dispose);
      await _loadPortfolioState(container);
      expect(container.read(activePortfolioProvider), kTotalPortfolioId);

      await container
          .read(portfoliosProvider.notifier)
          .setIncludeInTotal('p1', false);

      expect(container.read(includedPortfolioIdsProvider), isEmpty);
      expect(container.read(activePortfolioProvider), 'p1');
      expect(dataSource.settings['total_view_active'], isFalse);
      expect(dataSource.settings['active_portfolio_id'], 'p1');
    },
  );

  test(
    'excluding one of multiple portfolios keeps total view active',
    () async {
      final dataSource = _MemoryPortfolioDataSource(
        portfolios: [_portfolio('p1'), _portfolio('p2')],
        activePortfolioId: 'p1',
        totalViewActive: true,
      );
      final container = _container(dataSource);
      addTearDown(container.dispose);
      await _loadPortfolioState(container);

      await container
          .read(portfoliosProvider.notifier)
          .setIncludeInTotal('p2', false);

      expect(container.read(activePortfolioProvider), kTotalPortfolioId);
      expect(container.read(includedPortfolioIdsProvider), ['p1']);
      expect(dataSource.settings['total_view_active'], isTrue);
    },
  );

  test('a newer real selection wins over a delayed total selection', () async {
    final dataSource = _MemoryPortfolioDataSource(
      portfolios: [_portfolio('p1'), _portfolio('p2')],
      activePortfolioId: 'p1',
      totalViewActive: false,
    );
    final container = _container(dataSource);
    addTearDown(container.dispose);
    await _loadPortfolioState(container);
    dataSource.totalViewWriteGate = Completer<void>();

    final totalSelection = container
        .read(activePortfolioProvider.notifier)
        .switchPortfolio(kTotalPortfolioId);
    await pumpEventQueue();
    final realSelection = container
        .read(activePortfolioProvider.notifier)
        .switchPortfolio('p2');
    dataSource.totalViewWriteGate!.complete();

    await Future.wait([totalSelection, realSelection]);
    expect(container.read(activePortfolioProvider), 'p2');
    expect(dataSource.settings['total_view_active'], isFalse);
    expect(dataSource.settings['active_portfolio_id'], 'p2');
  });

  test(
    'deleting the last included portfolio falls back to a real one',
    () async {
      final dataSource = _MemoryPortfolioDataSource(
        portfolios: [_portfolio('p1'), _portfolio('p2', included: false)],
        activePortfolioId: 'p1',
        totalViewActive: true,
      );
      final container = _container(dataSource);
      addTearDown(container.dispose);
      await _loadPortfolioState(container);

      await container.read(portfoliosProvider.notifier).delete('p1');

      expect(container.read(activePortfolioProvider), 'p2');
      expect(container.read(portfoliosProvider).single.id, 'p2');
      expect(dataSource.settings['total_view_active'], isFalse);
      expect(dataSource.settings['active_portfolio_id'], 'p2');
    },
  );
}
