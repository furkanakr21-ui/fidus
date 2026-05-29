import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/asset_model.dart';
import 'models/daily_asset_change.dart';
import 'models/daily_portfolio_change.dart';
import 'models/income_expense_model.dart';
import 'models/goal_model.dart';
import 'models/portfolio_asset_value_snapshot_model.dart';
import 'models/portfolio_value_snapshot_model.dart';
import 'models/portfolio_model.dart';
import 'models/transaction_model.dart';
import 'services/asset_service.dart';
import 'services/cashflow_service.dart';
import 'services/goal_service.dart';
import 'services/portfolio_asset_snapshot_service.dart';
import 'services/portfolio_service.dart';
import 'services/portfolio_snapshot_service.dart';
import 'services/supabase_service.dart';
import 'services/transaction_service.dart';
import 'utils/currency_utils.dart';

// ─────────────────────────────────────────
// Portföyler
// ─────────────────────────────────────────

class PortfoliosNotifier extends Notifier<List<PortfolioModel>> {
  @override
  List<PortfolioModel> build() {
    Future.microtask(load);
    return [];
  }

  Future<void> load() async {
    state = await PortfolioService.getAll();
  }

  Future<PortfolioModel> create(String name, String emoji) async {
    final p = await PortfolioService.create(name, emoji);
    state = [...state, p];
    return p;
  }

  Future<void> delete(String id) async {
    await PortfolioService.delete(id);
    state = state.where((p) => p.id != id).toList();
  }
}

final portfoliosProvider =
    NotifierProvider<PortfoliosNotifier, List<PortfolioModel>>(
      PortfoliosNotifier.new,
    );

// ─────────────────────────────────────────
// Aktif Portföy
// ─────────────────────────────────────────

class ActivePortfolioNotifier extends Notifier<String> {
  @override
  String build() {
    Future.microtask(_loadFromServer);
    return '';
  }

  Future<void> _loadFromServer() async {
    final id = await PortfolioService.getActivePortfolioId();
    if (id != null && id.isNotEmpty) {
      state = id;
    } else {
      // Sunucuda kayıtlı portföy yoksa ilk portföyü al
      final portfolios = await PortfolioService.getAll();
      if (portfolios.isNotEmpty) {
        await switchPortfolio(portfolios.first.id);
      }
    }
  }

  Future<void> switchPortfolio(String portfolioId) async {
    await PortfolioService.setActivePortfolio(portfolioId);
    state = portfolioId;
  }
}

final activePortfolioProvider =
    NotifierProvider<ActivePortfolioNotifier, String>(
      ActivePortfolioNotifier.new,
    );

// Eski kod uyumluluğu için alias
final activeProfileProvider = activePortfolioProvider;

// ─────────────────────────────────────────
// Günlük Portföy Snapshot'ı
// ─────────────────────────────────────────

class TodayPortfolioSnapshotNotifier extends Notifier<PortfolioValueSnapshot?> {
  RealtimeChannel? _channel;

  @override
  PortfolioValueSnapshot? build() {
    final portfolioId = ref.watch(activePortfolioProvider);
    _channel?.unsubscribe();
    if (portfolioId.isEmpty) return null;
    _setupRealtime(portfolioId);
    Future.microtask(() => _load(portfolioId));
    return null;
  }

  void _setupRealtime(String portfolioId) {
    _channel = supabase
        .channel('portfolio_snapshots_$portfolioId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'portfolio_value_snapshots',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'portfolio_id',
            value: portfolioId,
          ),
          callback: (_) => _load(portfolioId),
        )
        .subscribe();
    ref.onDispose(() => _channel?.unsubscribe());
  }

  Future<void> _load(String portfolioId) async {
    state = await PortfolioSnapshotService.getToday(portfolioId);
  }

  Future<void> refresh() async {
    final portfolioId = ref.read(activePortfolioProvider);
    if (portfolioId.isEmpty) return;
    await _load(portfolioId);
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
    final portfolioId = ref.watch(activePortfolioProvider);
    _channel?.unsubscribe();
    if (portfolioId.isEmpty) return [];
    _setupRealtime(portfolioId);
    Future.microtask(() => _load(portfolioId));
    return [];
  }

  void _setupRealtime(String portfolioId) {
    _channel = supabase
        .channel('portfolio_snapshot_history_$portfolioId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'portfolio_value_snapshots',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'portfolio_id',
            value: portfolioId,
          ),
          callback: (_) => _load(portfolioId),
        )
        .subscribe();
    ref.onDispose(() => _channel?.unsubscribe());
  }

  Future<void> _load(String portfolioId) async {
    state = await PortfolioSnapshotService.getHistory(portfolioId);
  }

  Future<void> refresh() async {
    final portfolioId = ref.read(activePortfolioProvider);
    if (portfolioId.isEmpty) return;
    await _load(portfolioId);
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
    final portfolioId = ref.watch(activePortfolioProvider);
    _channel?.unsubscribe();
    if (portfolioId.isEmpty) return {};
    _setupRealtime(portfolioId);
    Future.microtask(() => _load(portfolioId));
    return null;
  }

  void _setupRealtime(String portfolioId) {
    _channel = supabase
        .channel('portfolio_asset_snapshots_$portfolioId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'portfolio_asset_value_snapshots',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'portfolio_id',
            value: portfolioId,
          ),
          callback: (_) => _load(portfolioId),
        )
        .subscribe();
    ref.onDispose(() => _channel?.unsubscribe());
  }

  Future<void> _load(String portfolioId) async {
    final snapshots = await PortfolioAssetSnapshotService.getToday(portfolioId);
    state = {for (final snapshot in snapshots) snapshot.symbol: snapshot};
  }

  Future<void> refresh() async {
    final portfolioId = ref.read(activePortfolioProvider);
    if (portfolioId.isEmpty) return;
    await _load(portfolioId);
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
    final portfolioId = ref.watch(activePortfolioProvider);
    _channel?.unsubscribe();
    if (portfolioId.isEmpty) return [];
    _setupRealtime(portfolioId);
    Future.microtask(() => _load(portfolioId));
    return [];
  }

  void _setupRealtime(String portfolioId) {
    _channel = supabase
        .channel('assets_$portfolioId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'assets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'portfolio_id',
            value: portfolioId,
          ),
          callback: (_) => _load(portfolioId),
        )
        .subscribe();
    ref.onDispose(() => _channel?.unsubscribe());
  }

  Future<void> _load(String portfolioId) async {
    final raw = await AssetService.getByPortfolio(portfolioId);
    final prices = ref.read(pricesProvider);
    final rate = ref.read(exchangeRatesProvider)['TRY'] ?? 1.0;
    state = _applyPrices(raw, prices, rate);
  }

  List<AssetModel> _applyPrices(
    List<AssetModel> assets,
    Map<String, PriceRecord> prices,
    double usdToTry,
  ) {
    return assets.map((a) {
      final baseKey = a.apiId ?? a.symbol;
      final src = a.apiSource ?? 'manual';
      // Önce asıl key'e bak; bulamazsan karşı tarafı dene (tefas↔befas sınıflandırma
      // değişimi sonucu oluşan api_source uyumsuzluğunu giderir).
      final altSrc = src == 'tefas'
          ? 'befas'
          : (src == 'befas' ? 'tefas' : null);
      final rec =
          prices['${baseKey}_$src'] ??
          (altSrc != null ? prices['${baseKey}_$altSrc'] : null);
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
    final portfolioId = ref.read(activePortfolioProvider);
    if (portfolioId.isEmpty) return;
    _load(portfolioId);
  }

  Future<void> load() async {
    final portfolioId = ref.read(activePortfolioProvider);
    if (portfolioId.isEmpty) return;
    await _load(portfolioId);
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
    final portfolioId = ref.watch(activePortfolioProvider);
    _channel?.unsubscribe();
    if (portfolioId.isEmpty) return [];
    _setupRealtime(portfolioId);
    Future.microtask(() => _load(portfolioId));
    return [];
  }

  void _setupRealtime(String portfolioId) {
    _channel = supabase
        .channel('cashflows_$portfolioId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cashflows',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'portfolio_id',
            value: portfolioId,
          ),
          callback: (_) => _load(portfolioId),
        )
        .subscribe();
    ref.onDispose(() => _channel?.unsubscribe());
  }

  Future<void> _load(String portfolioId) async {
    state = await CashFlowService.getByPortfolio(portfolioId);
  }

  Future<void> load() async {
    final portfolioId = ref.read(activePortfolioProvider);
    if (portfolioId.isEmpty) return;
    await _load(portfolioId);
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
    final portfolioId = ref.watch(activePortfolioProvider);
    _channel?.unsubscribe();
    if (portfolioId.isEmpty) return [];
    _setupRealtime(portfolioId);
    Future.microtask(() => _load(portfolioId));
    return [];
  }

  void _setupRealtime(String portfolioId) {
    _channel = supabase
        .channel('goals_$portfolioId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'goals',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'portfolio_id',
            value: portfolioId,
          ),
          callback: (_) => _load(portfolioId),
        )
        .subscribe();
    ref.onDispose(() => _channel?.unsubscribe());
  }

  Future<void> _load(String portfolioId) async {
    state = await GoalService.getByPortfolio(portfolioId);
  }

  Future<void> load() async {
    final portfolioId = ref.read(activePortfolioProvider);
    if (portfolioId.isEmpty) return;
    await _load(portfolioId);
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
    final portfolioId = ref.watch(activePortfolioProvider);
    _channel?.unsubscribe();
    if (portfolioId.isEmpty) return [];
    _setupRealtime(portfolioId);
    Future.microtask(() => _load(portfolioId));
    return [];
  }

  void _setupRealtime(String portfolioId) {
    _channel = supabase
        .channel('transactions_$portfolioId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          callback: (_) => _load(portfolioId),
        )
        .subscribe();
    ref.onDispose(() => _channel?.unsubscribe());
  }

  Future<void> _load(String portfolioId) async {
    state = await TransactionService.getByPortfolio(portfolioId);
  }

  Future<void> load() async {
    final portfolioId = ref.read(activePortfolioProvider);
    if (portfolioId.isEmpty) return;
    await _load(portfolioId);
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
    final s = await PortfolioService.getSettings();
    state = s['currency'] ?? 'TRY';
  }

  Future<void> setCurrency(String currency) async {
    await PortfolioService.saveSettings(currency: currency);
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
    final s = await PortfolioService.getSettings();
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
    await PortfolioService.saveSettings(theme: key);
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

// Alt navigasyon
class TabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setTab(int index) => state = index;
}

final tabIndexProvider = NotifierProvider<TabIndexNotifier, int>(
  TabIndexNotifier.new,
);
