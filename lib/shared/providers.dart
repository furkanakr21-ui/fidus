import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import 'models/asset_model.dart';
import 'models/daily_asset_change.dart';
import 'models/daily_portfolio_change.dart';
import 'models/income_expense_model.dart';
import 'models/goal_model.dart';
import 'models/portfolio_asset_value_snapshot_model.dart';
import 'models/portfolio_model.dart';
import 'models/portfolio_scope.dart';
import 'models/portfolio_value_snapshot_model.dart';
import 'models/total_view_aggregation.dart';
import 'models/transaction_model.dart';
import 'services/asset_service.dart';
import 'services/cashflow_service.dart';
import 'services/goal_service.dart';
import 'services/portfolio_asset_snapshot_service.dart';
import 'services/portfolio_service.dart';
import 'services/portfolio_snapshot_service.dart';
import 'services/supabase_service.dart';
import 'services/transaction_service.dart';
import 'utils/asset_price_lookup.dart';
import 'utils/currency_utils.dart';

class InitialDataLoadTracker extends Notifier<Set<String>> {
  static const portfolios = 'portfolios';
  static const assets = 'assets';
  static const cashflows = 'cashflows';
  static const goals = 'goals';
  static const currency = 'currency';

  static const requiredSections = {
    portfolios,
    assets,
    cashflows,
    goals,
    currency,
  };

  @override
  Set<String> build() => {};

  void markLoading(String section) {
    if (!state.contains(section)) return;
    state = {...state}..remove(section);
  }

  void markReady(String section) {
    if (state.contains(section)) return;
    state = {...state, section};
  }
}

final initialDataLoadTrackerProvider =
    NotifierProvider<InitialDataLoadTracker, Set<String>>(
      InitialDataLoadTracker.new,
    );

final portfolioDataSourceProvider = Provider<PortfolioDataSource>(
  (_) => const SupabasePortfolioDataSource(),
);

// ─────────────────────────────────────────
// Portföyler
// ─────────────────────────────────────────

class PortfoliosNotifier extends Notifier<List<PortfolioModel>> {
  Future<void> _includeWriteQueue = Future.value();

  @override
  List<PortfolioModel> build() {
    Future.microtask(load);
    return [];
  }

  Future<void> load() async {
    ref
        .read(initialDataLoadTrackerProvider.notifier)
        .markLoading(InitialDataLoadTracker.portfolios);
    state = await ref.read(portfolioDataSourceProvider).getAll();
    ref
        .read(initialDataLoadTrackerProvider.notifier)
        .markReady(InitialDataLoadTracker.portfolios);
  }

  Future<PortfolioModel> create(String name, String emoji) async {
    final p = await ref.read(portfolioDataSourceProvider).create(name, emoji);
    state = [...state, p];
    return p;
  }

  Future<void> delete(String id) async {
    await ref.read(portfolioDataSourceProvider).delete(id);
    state = state.where((p) => p.id != id).toList();
    if (ref.read(isTotalViewProvider) &&
        !state.any((portfolio) => portfolio.includeInTotal)) {
      await ref.read(activePortfolioProvider.notifier).leaveTotalView();
    }
  }

  Future<void> setIncludeInTotal(String id, bool value) async {
    final previous = state;
    state = [
      for (final portfolio in state)
        if (portfolio.id == id)
          portfolio.copyWith(includeInTotal: value)
        else
          portfolio,
    ];
    try {
      await _queueIncludeWrite(
        () =>
            ref.read(portfolioDataSourceProvider).setIncludeInTotal(id, value),
      );
    } catch (_) {
      final current = state.where((portfolio) => portfolio.id == id);
      if (current.isNotEmpty && current.first.includeInTotal == value) {
        final previousPortfolio = previous.where(
          (portfolio) => portfolio.id == id,
        );
        if (previousPortfolio.isNotEmpty) {
          state = [
            for (final portfolio in state)
              if (portfolio.id == id)
                portfolio.copyWith(
                  includeInTotal: previousPortfolio.first.includeInTotal,
                )
              else
                portfolio,
          ];
        }
      }
      rethrow;
    }

    if (!value &&
        ref.read(isTotalViewProvider) &&
        !state.any((portfolio) => portfolio.includeInTotal)) {
      await ref.read(activePortfolioProvider.notifier).leaveTotalView();
    }
  }

  Future<void> _queueIncludeWrite(Future<void> Function() write) {
    final operation = _includeWriteQueue.then((_) => write());
    _includeWriteQueue = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }
}

final portfoliosProvider =
    NotifierProvider<PortfoliosNotifier, List<PortfolioModel>>(
      PortfoliosNotifier.new,
    );

final includedPortfolioIdsProvider = Provider<List<String>>((ref) {
  return ref
      .watch(portfoliosProvider)
      .where((portfolio) => portfolio.includeInTotal)
      .map((portfolio) => portfolio.id)
      .toList(growable: false);
});

// ─────────────────────────────────────────
// Aktif Portföy
// ─────────────────────────────────────────

class ActivePortfolioNotifier extends Notifier<String> {
  int _selectionGeneration = 0;
  Future<void> _serverWriteQueue = Future.value();

  @override
  String build() {
    Future.microtask(_loadFromServer);
    return '';
  }

  Future<void> _loadFromServer() async {
    final generation = _selectionGeneration;
    final dataSource = ref.read(portfolioDataSourceProvider);
    final settings = await dataSource.getSettings();
    final portfolios = await dataSource.getAll();
    if (generation != _selectionGeneration) return;

    final totalViewActive = settings['total_view_active'] as bool? ?? false;
    final included = portfolios.where((portfolio) => portfolio.includeInTotal);
    if (totalViewActive && included.isNotEmpty) {
      state = kTotalPortfolioId;
      return;
    }

    final storedId = settings['active_portfolio_id'] as String?;
    final storedExists =
        storedId != null &&
        portfolios.any((portfolio) => portfolio.id == storedId);
    final fallbackId = storedExists
        ? storedId
        : (portfolios.isEmpty ? null : portfolios.first.id);
    if (fallbackId != null && fallbackId.isNotEmpty) {
      if (generation == _selectionGeneration) state = fallbackId;
      if (totalViewActive || !storedExists) {
        await _queueServerWrite(
          () => dataSource.setActivePortfolio(fallbackId),
        );
      }
    } else {
      if (generation == _selectionGeneration) state = '';
      if (totalViewActive) {
        await _queueServerWrite(dataSource.setTotalViewInactive);
      }
    }
  }

  Future<bool> switchPortfolio(String portfolioId) async {
    final generation = ++_selectionGeneration;
    if (portfolioId == kTotalPortfolioId) {
      var portfolios = ref.read(portfoliosProvider);
      final dataSource = ref.read(portfolioDataSourceProvider);
      if (portfolios.isEmpty) portfolios = await dataSource.getAll();
      if (generation != _selectionGeneration) return false;
      if (!portfolios.any((portfolio) => portfolio.includeInTotal)) {
        return false;
      }
      await _queueServerWrite(dataSource.setTotalViewActive);
      if (generation == _selectionGeneration) state = kTotalPortfolioId;
      return true;
    }

    await _queueServerWrite(
      () =>
          ref.read(portfolioDataSourceProvider).setActivePortfolio(portfolioId),
    );
    if (generation == _selectionGeneration) state = portfolioId;
    return true;
  }

  Future<void> leaveTotalView() async {
    final generation = ++_selectionGeneration;
    final dataSource = ref.read(portfolioDataSourceProvider);
    final settings = await dataSource.getSettings();
    var portfolios = ref.read(portfoliosProvider);
    if (portfolios.isEmpty) portfolios = await dataSource.getAll();
    final storedId = settings['active_portfolio_id'] as String?;
    final storedExists =
        storedId != null &&
        portfolios.any((portfolio) => portfolio.id == storedId);
    final fallbackId = storedExists
        ? storedId
        : (portfolios.isEmpty ? null : portfolios.first.id);
    if (generation != _selectionGeneration) return;
    if (fallbackId == null) {
      state = '';
      await _queueServerWrite(dataSource.setTotalViewInactive);
      return;
    }
    state = fallbackId;
    await _queueServerWrite(() => dataSource.setActivePortfolio(fallbackId));
  }

  Future<void> _queueServerWrite(Future<void> Function() write) {
    final operation = _serverWriteQueue.then((_) => write());
    _serverWriteQueue = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }
}

final activePortfolioProvider =
    NotifierProvider<ActivePortfolioNotifier, String>(
      ActivePortfolioNotifier.new,
    );

// Eski kod uyumluluğu için alias
final activeProfileProvider = activePortfolioProvider;

final isTotalViewProvider = Provider<bool>((ref) {
  return ref.watch(activePortfolioProvider) == kTotalPortfolioId;
});

final portfolioScopeProvider = Provider<PortfolioScope>((ref) {
  final activePortfolioId = ref.watch(activePortfolioProvider);
  if (activePortfolioId == kTotalPortfolioId) {
    return PortfolioScope.total(ref.watch(includedPortfolioIdsProvider));
  }
  return PortfolioScope.single(activePortfolioId);
});

PostgresChangeFilter _realtimeFilter(PortfolioScope scope) {
  if (scope.isTotal) {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Authenticated user is required for realtime scope');
    }
    return PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'user_id',
      value: userId,
    );
  }
  return PostgresChangeFilter(
    type: PostgresChangeFilterType.eq,
    column: 'portfolio_id',
    value: scope.singlePortfolioId!,
  );
}

List<PortfolioModel> _portfolioModelsForScope(Ref ref, PortfolioScope scope) {
  final ids = scope.portfolioIds.toSet();
  return ref
      .read(portfoliosProvider)
      .where((portfolio) => ids.contains(portfolio.id))
      .toList(growable: false);
}

// ─────────────────────────────────────────
// Günlük Portföy Snapshot'ı
// ─────────────────────────────────────────

class TodayPortfolioSnapshotNotifier extends Notifier<PortfolioValueSnapshot?> {
  RealtimeChannel? _channel;

  @override
  PortfolioValueSnapshot? build() {
    final scope = ref.watch(portfolioScopeProvider);
    _channel?.unsubscribe();
    if (scope.isEmpty) return null;
    _setupRealtime(scope);
    Future.microtask(() => _load(scope));
    return null;
  }

  void _setupRealtime(PortfolioScope scope) {
    _channel = supabase
        .channel('portfolio_snapshots_${scope.channelKey}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'portfolio_value_snapshots',
          filter: _realtimeFilter(scope),
          callback: (_) => _load(scope),
        )
        .subscribe();
    ref.onDispose(() => _channel?.unsubscribe());
  }

  Future<void> _load(PortfolioScope scope) async {
    final PortfolioValueSnapshot? snapshot;
    if (scope.isTotal) {
      final rows = await PortfolioSnapshotService.getTodayForPortfolios(
        scope.portfolioIds,
      );
      snapshot = aggregateTodaySnapshots(
        rows,
        includedPortfolios: _portfolioModelsForScope(ref, scope),
      );
    } else {
      snapshot = await PortfolioSnapshotService.getToday(
        scope.singlePortfolioId!,
      );
    }
    if (ref.read(portfolioScopeProvider) == scope) state = snapshot;
  }

  Future<void> refresh() async {
    final scope = ref.read(portfolioScopeProvider);
    if (scope.isEmpty) return;
    await _load(scope);
  }
}

final todayPortfolioSnapshotProvider =
    NotifierProvider<TodayPortfolioSnapshotNotifier, PortfolioValueSnapshot?>(
      TodayPortfolioSnapshotNotifier.new,
    );

class PortfolioSnapshotHistoryNotifier
    extends Notifier<List<PortfolioValueSnapshot>> {
  RealtimeChannel? _channel;

  @override
  List<PortfolioValueSnapshot> build() {
    final scope = ref.watch(portfolioScopeProvider);
    _channel?.unsubscribe();
    if (scope.isEmpty) return [];
    _setupRealtime(scope);
    Future.microtask(() => _load(scope));
    return [];
  }

  void _setupRealtime(PortfolioScope scope) {
    _channel = supabase
        .channel('portfolio_snapshot_history_${scope.channelKey}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'portfolio_value_snapshots',
          filter: _realtimeFilter(scope),
          callback: (_) => _load(scope),
        )
        .subscribe();
    ref.onDispose(() => _channel?.unsubscribe());
  }

  Future<void> _load(PortfolioScope scope) async {
    final List<PortfolioValueSnapshot> snapshots;
    if (scope.isTotal) {
      final rows = await PortfolioSnapshotService.getHistoryForPortfolios(
        scope.portfolioIds,
      );
      snapshots = aggregateSnapshotHistory(
        rows,
        includedPortfolios: _portfolioModelsForScope(ref, scope),
      );
    } else {
      snapshots = await PortfolioSnapshotService.getHistory(
        scope.singlePortfolioId!,
      );
    }
    if (ref.read(portfolioScopeProvider) == scope) state = snapshots;
  }

  Future<void> refresh() async {
    final scope = ref.read(portfolioScopeProvider);
    if (scope.isEmpty) return;
    await _load(scope);
  }
}

final portfolioSnapshotHistoryProvider =
    NotifierProvider<
      PortfolioSnapshotHistoryNotifier,
      List<PortfolioValueSnapshot>
    >(PortfolioSnapshotHistoryNotifier.new);

class TodayAssetSnapshotsNotifier
    extends Notifier<Map<String, PortfolioAssetValueSnapshot>?> {
  RealtimeChannel? _channel;

  @override
  Map<String, PortfolioAssetValueSnapshot>? build() {
    final scope = ref.watch(portfolioScopeProvider);
    _channel?.unsubscribe();
    if (scope.isEmpty) return {};
    _setupRealtime(scope);
    Future.microtask(() => _load(scope));
    return null;
  }

  void _setupRealtime(PortfolioScope scope) {
    _channel = supabase
        .channel('portfolio_asset_snapshots_${scope.channelKey}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'portfolio_asset_value_snapshots',
          filter: _realtimeFilter(scope),
          callback: (_) => _load(scope),
        )
        .subscribe();
    ref.onDispose(() => _channel?.unsubscribe());
  }

  Future<void> _load(PortfolioScope scope) async {
    final Map<String, PortfolioAssetValueSnapshot> snapshots;
    if (scope.isTotal) {
      final rows = await PortfolioAssetSnapshotService.getTodayForPortfolios(
        scope.portfolioIds,
      );
      snapshots = aggregateAssetSnapshotsBySymbol(rows);
    } else {
      final rows = await PortfolioAssetSnapshotService.getToday(
        scope.singlePortfolioId!,
      );
      snapshots = {for (final snapshot in rows) snapshot.symbol: snapshot};
    }
    if (ref.read(portfolioScopeProvider) == scope) state = snapshots;
  }

  Future<void> refresh() async {
    final scope = ref.read(portfolioScopeProvider);
    if (scope.isEmpty) return;
    await _load(scope);
  }
}

final todayAssetSnapshotsProvider =
    NotifierProvider<
      TodayAssetSnapshotsNotifier,
      Map<String, PortfolioAssetValueSnapshot>?
    >(TodayAssetSnapshotsNotifier.new);

final dailyPortfolioChangeProvider = Provider<DailyPortfolioChange>((ref) {
  ref.watch(exchangeRatesProvider);
  return DailyPortfolioChange.calculate(
    currentValueTry: ref.watch(totalValueProvider),
    snapshot: ref.watch(todayPortfolioSnapshotProvider),
    displayCurrency: ref.watch(currencyProvider),
  );
});

final dailyAssetChangesProvider = Provider<Map<String, DailyAssetChange>>((
  ref,
) {
  ref.watch(exchangeRatesProvider);
  final displayCurrency = ref.watch(currencyProvider);
  final portfolioSnapshot = ref.watch(todayPortfolioSnapshotProvider);
  final snapshots = ref.watch(todayAssetSnapshotsProvider);
  final hasLoadedAssetSnapshots = snapshots != null;
  final hasUsableAssetSnapshotSet =
      portfolioSnapshot != null &&
      hasLoadedAssetSnapshots &&
      (snapshots.isNotEmpty || portfolioSnapshot.assetCount == 0);
  return {
    for (final asset in ref.watch(mergedAssetsProvider))
      asset.symbol: DailyAssetChange.calculate(
        currentValueTry: asset.currentValue,
        snapshot: snapshots?[asset.symbol],
        hasPortfolioSnapshot: hasUsableAssetSnapshotSet,
        displayCurrency: displayCurrency,
      ),
  };
});

// ─────────────────────────────────────────
// Varlıklar (Realtime)
// ─────────────────────────────────────────

class AssetsNotifier extends Notifier<List<AssetModel>> {
  RealtimeChannel? _channel;

  @override
  List<AssetModel> build() {
    final scope = ref.watch(portfolioScopeProvider);
    _channel?.unsubscribe();
    if (scope.isEmpty) {
      Future.microtask(() => _load(scope));
      return [];
    }
    _setupRealtime(scope);
    Future.microtask(() => _load(scope));
    return [];
  }

  void _setupRealtime(PortfolioScope scope) {
    _channel = supabase
        .channel('assets_${scope.channelKey}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'assets',
          filter: _realtimeFilter(scope),
          callback: (_) => _load(scope),
        )
        .subscribe();
    ref.onDispose(() => _channel?.unsubscribe());
  }

  Future<void> _load(PortfolioScope scope) async {
    ref
        .read(initialDataLoadTrackerProvider.notifier)
        .markLoading(InitialDataLoadTracker.assets);
    final raw = scope.isEmpty
        ? <AssetModel>[]
        : scope.isTotal
        ? await AssetService.getByPortfolios(scope.portfolioIds)
        : await AssetService.getByPortfolio(scope.singlePortfolioId!);
    final prices = ref.read(pricesProvider);
    final rate = ref.read(exchangeRatesProvider)['TRY'] ?? 1.0;
    if (ref.read(portfolioScopeProvider) != scope) return;
    state = _applyPrices(raw, prices, rate);
    ref
        .read(initialDataLoadTrackerProvider.notifier)
        .markReady(InitialDataLoadTracker.assets);
  }

  List<AssetModel> _applyPrices(
    List<AssetModel> assets,
    Map<String, PriceRecord> prices,
    double usdToTry,
  ) {
    return assets.map((a) {
      final rec = firstPriceForAsset(a, prices);
      if (rec == null || rec.price <= 0) {
        return a.copyWith(usdToTry: usdToTry);
      }
      double price;
      if (rec.priceCurrency == 'USD' && a.currency == 'TRY') {
        price = rec.price * usdToTry;
      } else {
        price = rec.price;
      }
      return a.copyWith(currentPrice: price, usdToTry: usdToTry);
    }).toList();
  }

  void applyCurrentPrices() {
    final scope = ref.read(portfolioScopeProvider);
    if (scope.isEmpty && ref.read(activePortfolioProvider).isEmpty) return;
    _load(scope);
  }

  Future<void> load() async {
    final scope = ref.read(portfolioScopeProvider);
    if (scope.isEmpty && ref.read(activePortfolioProvider).isEmpty) return;
    await _load(scope);
  }

  Future<void> add(AssetModel asset) async {
    await AssetService.save(asset);
    // Realtime tetikler, load'a gerek yok
  }

  Future<void> update(AssetModel asset) async {
    await AssetService.update(asset);
  }

  Future<void> delete(String id) async {
    await AssetService.delete(id);
  }

  Future<void> deleteAll(List<String> ids) async {
    for (final id in ids) {
      await AssetService.delete(id);
    }
  }
}

final assetsProvider = NotifierProvider<AssetsNotifier, List<AssetModel>>(
  AssetsNotifier.new,
);

// ─────────────────────────────────────────
// Fiyatlar (Realtime — sunucu yazar)
// ─────────────────────────────────────────

class PriceRecord {
  final double price;
  final String priceCurrency;
  const PriceRecord(this.price, this.priceCurrency);
}

class PricesNotifier extends Notifier<Map<String, PriceRecord>> {
  RealtimeChannel? _channel;
  Timer? _debounce;

  @override
  Map<String, PriceRecord> build() {
    _setupRealtime();
    Future.microtask(_load);
    ref.onDispose(() {
      _debounce?.cancel();
      _channel?.unsubscribe();
    });
    return {};
  }

  void _setupRealtime() {
    _channel = supabase
        .channel('prices_global')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'prices',
          callback: (_) => _scheduleLoad(),
        )
        .subscribe();
  }

  // Çok sayıda Realtime eventi art arda geldiğinde (toplu güncelleme sırasında)
  // hepsini tek bir _load() çağrısına indirgeyerek race condition'ı önler.
  void _scheduleLoad() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _load);
  }

  Future<void> _load() async {
    // prices tablosu 3000+ satır — PostgREST default 1000 limitini aşmamak için
    // sayfalandırarak tüm fiyatları çek.
    final List<dynamic> allData = [];
    int from = 0;
    const int pageSize = 1000;
    while (true) {
      final page = await supabase
          .from('prices')
          .select()
          .range(from, from + pageSize - 1);
      allData.addAll(page as List);
      if ((page as List).length < pageSize) break;
      from += pageSize;
    }
    final map = <String, PriceRecord>{};
    for (final row in allData) {
      final rawPrice = (row['price'] as num).toDouble();
      if (rawPrice <= 0) continue;
      final key = '${row['symbol']}_${row['api_source']}';
      map[key] = PriceRecord(
        rawPrice,
        row['price_currency'] as String? ?? 'TRY',
      );
    }
    ref
        .read(initialDataLoadTrackerProvider.notifier)
        .markLoading(InitialDataLoadTracker.assets);
    state = map;
    ref.read(assetsProvider.notifier).applyCurrentPrices();
  }

  Future<void> refresh() => _load();
}

final pricesProvider =
    NotifierProvider<PricesNotifier, Map<String, PriceRecord>>(
      PricesNotifier.new,
    );

// ─────────────────────────────────────────
// Döviz Kurları (Realtime)
// ─────────────────────────────────────────

class ExchangeRatesNotifier extends Notifier<Map<String, double>> {
  RealtimeChannel? _channel;

  @override
  Map<String, double> build() {
    _setupRealtime();
    Future.microtask(_load);
    return {};
  }

  void _setupRealtime() {
    _channel = supabase
        .channel('exchange_rates_global')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'exchange_rates',
          callback: (_) => _load(),
        )
        .subscribe();
    ref.onDispose(() => _channel?.unsubscribe());
  }

  Future<void> _load() async {
    final data = await supabase.from('exchange_rates').select();
    final map = <String, double>{};
    for (final row in data as List) {
      map[row['currency'] as String] = (row['rate_per_usd'] as num).toDouble();
    }
    ref
        .read(initialDataLoadTrackerProvider.notifier)
        .markLoading(InitialDataLoadTracker.assets);
    state = map;
    CurrencyUtils.updateRates(map);
    ref.read(assetsProvider.notifier).applyCurrentPrices();
  }

  Future<void> refresh() => _load();

  double get usdToTry => state['TRY'] ?? 1.0;
}

final exchangeRatesProvider =
    NotifierProvider<ExchangeRatesNotifier, Map<String, double>>(
      ExchangeRatesNotifier.new,
    );

// ─────────────────────────────────────────
// Nakit Akışı (Realtime)
// ─────────────────────────────────────────

class CashFlowNotifier extends Notifier<List<CashFlowModel>> {
  RealtimeChannel? _channel;

  @override
  List<CashFlowModel> build() {
    final scope = ref.watch(portfolioScopeProvider);
    _channel?.unsubscribe();
    if (scope.isEmpty) {
      Future.microtask(() => _load(scope));
      return [];
    }
    _setupRealtime(scope);
    Future.microtask(() => _load(scope));
    return [];
  }

  void _setupRealtime(PortfolioScope scope) {
    _channel = supabase
        .channel('cashflows_${scope.channelKey}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cashflows',
          filter: _realtimeFilter(scope),
          callback: (_) => _load(scope),
        )
        .subscribe();
    ref.onDispose(() => _channel?.unsubscribe());
  }

  Future<void> _load(PortfolioScope scope) async {
    ref
        .read(initialDataLoadTrackerProvider.notifier)
        .markLoading(InitialDataLoadTracker.cashflows);
    final cashflows = scope.isEmpty
        ? <CashFlowModel>[]
        : scope.isTotal
        ? await CashFlowService.getByPortfolios(scope.portfolioIds)
        : await CashFlowService.getByPortfolio(scope.singlePortfolioId!);
    if (ref.read(portfolioScopeProvider) != scope) return;
    state = cashflows;
    ref
        .read(initialDataLoadTrackerProvider.notifier)
        .markReady(InitialDataLoadTracker.cashflows);
  }

  Future<void> load() async {
    final scope = ref.read(portfolioScopeProvider);
    if (scope.isEmpty && ref.read(activePortfolioProvider).isEmpty) return;
    await _load(scope);
  }

  Future<void> add(CashFlowModel cash) async {
    await CashFlowService.save(cash);
  }

  Future<void> delete(String id) async {
    await CashFlowService.delete(id);
  }
}

final cashflowProvider =
    NotifierProvider<CashFlowNotifier, List<CashFlowModel>>(
      CashFlowNotifier.new,
    );

// ─────────────────────────────────────────
// Hedefler (Realtime)
// ─────────────────────────────────────────

class GoalsNotifier extends Notifier<List<GoalModel>> {
  RealtimeChannel? _channel;

  @override
  List<GoalModel> build() {
    final scope = ref.watch(portfolioScopeProvider);
    _channel?.unsubscribe();
    if (scope.isEmpty) {
      Future.microtask(() => _load(scope));
      return [];
    }
    _setupRealtime(scope);
    Future.microtask(() => _load(scope));
    return [];
  }

  void _setupRealtime(PortfolioScope scope) {
    _channel = supabase
        .channel('goals_${scope.channelKey}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'goals',
          filter: _realtimeFilter(scope),
          callback: (_) => _load(scope),
        )
        .subscribe();
    ref.onDispose(() => _channel?.unsubscribe());
  }

  Future<void> _load(PortfolioScope scope) async {
    ref
        .read(initialDataLoadTrackerProvider.notifier)
        .markLoading(InitialDataLoadTracker.goals);
    final goals = scope.isEmpty
        ? <GoalModel>[]
        : scope.isTotal
        ? await GoalService.getByPortfolios(scope.portfolioIds)
        : await GoalService.getByPortfolio(scope.singlePortfolioId!);
    if (ref.read(portfolioScopeProvider) != scope) return;
    state = goals;
    ref
        .read(initialDataLoadTrackerProvider.notifier)
        .markReady(InitialDataLoadTracker.goals);
  }

  Future<void> load() async {
    final scope = ref.read(portfolioScopeProvider);
    if (scope.isEmpty && ref.read(activePortfolioProvider).isEmpty) return;
    await _load(scope);
  }

  Future<void> add(GoalModel goal) async {
    await GoalService.save(goal);
  }

  Future<void> update(GoalModel goal) async {
    await GoalService.update(goal);
    await load();
  }

  Future<void> delete(String id) async {
    await GoalService.delete(id);
  }
}

final goalsProvider = NotifierProvider<GoalsNotifier, List<GoalModel>>(
  GoalsNotifier.new,
);

// ─────────────────────────────────────────
// İşlem Geçmişi (Realtime)
// ─────────────────────────────────────────

class TransactionsNotifier extends Notifier<List<TransactionModel>> {
  RealtimeChannel? _channel;

  @override
  List<TransactionModel> build() {
    final scope = ref.watch(portfolioScopeProvider);
    _channel?.unsubscribe();
    if (scope.isEmpty) return [];
    _setupRealtime(scope);
    Future.microtask(() => _load(scope));
    return [];
  }

  void _setupRealtime(PortfolioScope scope) {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    _channel = supabase
        .channel('transactions_${scope.channelKey}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _load(scope),
        )
        .subscribe();
    ref.onDispose(() => _channel?.unsubscribe());
  }

  Future<void> _load(PortfolioScope scope) async {
    final transactions = scope.isTotal
        ? await TransactionService.getByPortfolios(scope.portfolioIds)
        : await TransactionService.getByPortfolio(scope.singlePortfolioId!);
    if (ref.read(portfolioScopeProvider) == scope) state = transactions;
  }

  Future<void> load() async {
    final scope = ref.read(portfolioScopeProvider);
    if (scope.isEmpty) return;
    await _load(scope);
  }

  Future<void> add(TransactionModel tx) async {
    await TransactionService.save(tx);
  }

  Future<void> delete(String id) async {
    await TransactionService.delete(id);
  }

  List<TransactionModel> forSymbol(String symbol) =>
      state.where((t) => t.symbol == symbol).toList();
}

final transactionsProvider =
    NotifierProvider<TransactionsNotifier, List<TransactionModel>>(
      TransactionsNotifier.new,
    );

// ─────────────────────────────────────────
// Hesaplamalar (computed)
// ─────────────────────────────────────────

final mergedAssetsProvider = Provider<List<AssetModel>>((ref) {
  final assets = ref.watch(assetsProvider);
  final Map<String, AssetModel> merged = {};
  for (final asset in assets) {
    if (merged.containsKey(asset.symbol)) {
      final existing = merged[asset.symbol]!;
      final totalQty = existing.quantity + asset.quantity;
      final avgPrice =
          (existing.buyPrice * existing.quantity +
              asset.buyPrice * asset.quantity) /
          totalQty;
      merged[asset.symbol] = existing.copyWith(
        quantity: totalQty,
        buyPrice: avgPrice,
        commission: (existing.commission ?? 0) + (asset.commission ?? 0),
        currentPrice: existing.currentPrice,
        usdToTry: existing.usdToTry,
      );
    } else {
      merged[asset.symbol] = asset;
    }
  }
  return merged.values.toList();
});

final totalValueProvider = Provider<double>((ref) {
  return ref
      .watch(mergedAssetsProvider)
      .fold(0.0, (sum, a) => sum + a.currentValue);
});

final totalCostProvider = Provider<double>((ref) {
  return ref.watch(assetsProvider).fold(0.0, (sum, a) => sum + a.totalCost);
});

final totalPLProvider = Provider<double>((ref) {
  return ref.watch(totalValueProvider) - ref.watch(totalCostProvider);
});

// ─────────────────────────────────────────
// Ayarlar
// ─────────────────────────────────────────

class CurrencyNotifier extends Notifier<String> {
  @override
  String build() {
    Future.microtask(_load);
    return 'TRY';
  }

  Future<void> _load() async {
    ref
        .read(initialDataLoadTrackerProvider.notifier)
        .markLoading(InitialDataLoadTracker.currency);
    final s = await ref.read(portfolioDataSourceProvider).getSettings();
    state = s['currency'] ?? 'TRY';
    ref
        .read(initialDataLoadTrackerProvider.notifier)
        .markReady(InitialDataLoadTracker.currency);
  }

  Future<void> setCurrency(String currency) async {
    await ref
        .read(portfolioDataSourceProvider)
        .saveSettings(currency: currency);
    state = currency;
  }
}

final currencyProvider = NotifierProvider<CurrencyNotifier, String>(
  CurrencyNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    Future.microtask(_load);
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final s = await ref.read(portfolioDataSourceProvider).getSettings();
    state = _parse(s['theme']);
  }

  ThemeMode _parse(String? v) => switch (v) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setThemeMode(ThemeMode mode) async {
    final key = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await ref.read(portfolioDataSourceProvider).saveSettings(theme: key);
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

// ─────────────────────────────────────────
// Yükleme durumu
// ─────────────────────────────────────────

class PriceLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setLoading(bool v) => state = v;
}

final priceLoadingProvider = NotifierProvider<PriceLoadingNotifier, bool>(
  PriceLoadingNotifier.new,
);

// Fiyat güncellemesi sunucu tarafında zamanlanmış görevlerle olur.
// Bu provider yalnızca Supabase tablolarından okuyarak UI'ı yeniler.
class PriceUpdateNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  Future<void> updatePrices() async {
    ref.read(priceLoadingProvider.notifier).setLoading(true);
    try {
      await ref.read(pricesProvider.notifier).refresh();
      await ref.read(exchangeRatesProvider.notifier).refresh();
      state = DateTime.now();
    } finally {
      ref.read(priceLoadingProvider.notifier).setLoading(false);
    }
  }
}

final priceUpdateProvider = NotifierProvider<PriceUpdateNotifier, DateTime?>(
  PriceUpdateNotifier.new,
);

// İlk açılışta anasayfanın boş başlangıç değerleriyle görünmesini engeller.
// Sağlayıcılar mevcut otomatik yükleme düzenlerini korur; ek API çağrısı yapılmaz.
final initialDataReadyProvider = Provider<bool>((ref) {
  final completedSections = ref.watch(initialDataLoadTrackerProvider);
  final portfolios = ref.watch(portfoliosProvider);
  if (!completedSections.contains(InitialDataLoadTracker.portfolios)) {
    return false;
  }

  final activePortfolioId = ref.watch(activePortfolioProvider);
  if (activePortfolioId.isEmpty) return portfolios.isEmpty;

  final pricesReady = ref.watch(pricesProvider).isNotEmpty;
  final exchangeRatesReady = ref.watch(exchangeRatesProvider).isNotEmpty;
  final assetSnapshotsReady = ref.watch(todayAssetSnapshotsProvider) != null;
  final dashboardSectionsReady = completedSections.containsAll(
    InitialDataLoadTracker.requiredSections,
  );

  return pricesReady &&
      exchangeRatesReady &&
      assetSnapshotsReady &&
      dashboardSectionsReady;
});

// Alt navigasyon
class TabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setTab(int index) => state = index;
}

final tabIndexProvider = NotifierProvider<TabIndexNotifier, int>(
  TabIndexNotifier.new,
);
