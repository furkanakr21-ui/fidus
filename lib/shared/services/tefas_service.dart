import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
import '../models/tefas_fund_model.dart';
import 'supabase_service.dart';

enum FundSortOption {
  nameAsc,
  codeAsc,
  priceDesc,
  return1YearDesc,
  totalSizeDesc,
}

/// TEFAS / BEFAS veri servisi
///
/// Endpoint: /api/v1/funds/returns/{page}?size=200
/// TEFAS: fundType 1,3,4,5 | BEFAS: fundType 2
/// Cache: Hive'da 24 saat saklanır, uygulama açılışında hemen yüklenir.
class TefasService {
  static const String _baseUrl =
      'https://ighutbzdcqvhjwqvsrzg.supabase.co/functions/v1/proxy-tefas';
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlnaHV0YnpkY3F2aGp3cXZzcnpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY3Njc5MjYsImV4cCI6MjA5MjM0MzkyNn0.hW22b1L9kKnIXoQm9mnoPzsjFwSX-HY_an2qvbt5sCw';
  static const int _pageSize = 200;
  static const int _maxPages = 20;

  static Map<String, String> get _headers => {
        'Authorization': 'Bearer $_anonKey',
        'Content-Type': 'application/json',
      };

  // ──────────────────── In-Memory Cache ────────────────────

  static List<TefasFund> _allFunds = [];
  static bool _fundsLoadedToMemory = false;
  static bool isSyncing = false;
  static DateTime? _lastFullSyncTime;

  // In-memory cache: key → (value, timestamp)
  static final Map<String, (String, DateTime)> _cache = {};

  static final _syncController = StreamController<bool>.broadcast();
  static Stream<bool> get onSyncComplete => _syncController.stream;

  static String? lastError;

  static void _cacheWrite(String key, String value) {
    _cache[key] = (value, DateTime.now());
  }

  static String? _cacheRead(String key) => _cache[key]?.$1;

  static const int _listCacheTtlMinutes = 10;
  static const int _detailCacheTtlHours = 2;
  static const int _historyCacheTtlHours = 1;

  static bool _isCacheValid() {
    final entry = _cache['tefas_all_funds'];
    if (entry == null) return false;
    return DateTime.now().difference(entry.$2).inMinutes < _listCacheTtlMinutes;
  }

  static bool _isMemoryStale() {
    if (_lastFullSyncTime == null || !_fundsLoadedToMemory || _allFunds.isEmpty) {
      return true;
    }
    return DateTime.now().difference(_lastFullSyncTime!).inMinutes >= _listCacheTtlMinutes;
  }

  static bool _isDetailValid(String key) {
    final entry = _cache['tefas_$key'];
    if (entry == null) return false;
    return DateTime.now().difference(entry.$2).inHours < _detailCacheTtlHours;
  }

  // ──────────────────── Başlangıç Yüklemesi ────────────────────

  /// Uygulama açılışında çağrılır (fire-and-forget).
  /// Bellek güncel (< $_listCacheTtlMinutes dk) ise hiçbir şey yapmaz.
  /// Bellek bayat ama Hive geçerliyse Hive'dan yükler (API yok).
  /// Her ikisi de bayatsa API'den çeker.
  static void scheduleOrRefreshIfNeeded() {
    if (isSyncing) return;
    if (!_isMemoryStale()) {
      developer.log(
          'TefasService: bellek güncel (< $_listCacheTtlMinutes dk), yenileme atlandı.');
      return;
    }
    if (_isCacheValid()) {
      developer.log('TefasService: Hive cache geçerli, bellekten yükleniyor.');
      getAllFunds().catchError((e) {
        developer.log('TefasService: Hive yükleme hatası: $e');
        return <TefasFund>[];
      });
      return;
    }
    refreshAllFunds().catchError((e) {
      developer.log('TefasService: başlangıç yüklemesi hatası: $e');
    });
  }

  /// 10 dk TTL'e göre yeniler — PriceService.updateAllPrices() tarafından çağrılır.
  /// Bellek güncel ise atlar. Senkronizasyon devam ediyorsa tamamlanmasını bekler.
  /// Hive cache geçerliyse API'ye gitmeden bellekten yükler.
  static Future<void> refreshIfStale() async {
    if (!_isMemoryStale()) {
      developer.log('TefasService: refreshIfStale — bellek güncel, atlandı.');
      return;
    }
    if (isSyncing) {
      developer.log('TefasService: refreshIfStale — senkronizasyon devam ediyor, bekleniyor...');
      await onSyncComplete.first;
      return;
    }
    if (_isCacheValid()) {
      developer.log('TefasService: refreshIfStale — Hive cache geçerli, belleğe yükleniyor...');
      await getAllFunds();
      return;
    }
    await refreshAllFunds();
  }

  // ──────────────────── Tam Liste Çekimi (API) ────────────────────

  /// Tüm fonları /api/v1/funds/returns/{page} üzerinden çeker.
  static Future<void> refreshAllFunds() async {
    if (isSyncing) return;
    isSyncing = true;
    lastError = null;
    developer.log('TefasService: fon listesi yenileniyor...');

    try {
      final allRaw = <Map<String, dynamic>>[];

      for (int page = 1; page <= _maxPages; page++) {
        final url =
            '$_baseUrl/api/v1/funds/returns/$page?size=$_pageSize';
        try {
          final res = await http
              .get(Uri.parse(url), headers: _headers)
              .timeout(const Duration(seconds: 25));

          if (res.statusCode != 200) {
            lastError = 'HTTP ${res.statusCode}: ${res.body}';
            break;
          }

          dynamic body;
          try {
            body = jsonDecode(res.body);
          } catch (e) {
            lastError = 'JSON parse hatası: $e';
            break;
          }

          List<dynamic> rawList;
          if (body is Map && body['data'] is List) {
            rawList = body['data'] as List;
          } else if (body is List) {
            rawList = body;
          } else {
            // İlk sayfada bile veri yoksa hata ver
            if (page == 1) {
              lastError = 'Beklenmeyen yanıt formatı: ${res.body.substring(0, (res.body.length).clamp(0, 200))}';
            }
            break;
          }

          if (rawList.isEmpty) break;

          final pageItems = rawList.whereType<Map<String, dynamic>>().toList();
          allRaw.addAll(pageItems);

          developer.log('TefasService: sayfa $page → ${pageItems.length} fon');

          // Son sayfa: pageSize'dan az geldi
          if (rawList.length < _pageSize) break;

          await Future.delayed(const Duration(milliseconds: 400));
        } catch (e) {
          lastError = 'Bağlantı hatası (sayfa $page): $e';
          break;
        }
      }

      if (allRaw.isNotEmpty) {
        final validFunds = <TefasFund>[];
        final seen = <String>{};
        for (final j in allRaw) {
          try {
            final fund = TefasFund.fromJson(j);
            if (fund.code.isNotEmpty && seen.add(fund.code)) {
              validFunds.add(fund);
            }
          } catch (_) {}
        }

        if (validFunds.isNotEmpty) {
          _cacheWrite('tefas_all_funds', jsonEncode(allRaw));
          _allFunds = validFunds;
          _fundsLoadedToMemory = true;
          _lastFullSyncTime = DateTime.now();
          lastError = null;
          developer.log(
              'TefasService: ${_allFunds.length} fon yüklendi '
              '(${_allFunds.where((f) => !f.isBefas).length} TEFAS, '
              '${_allFunds.where((f) => f.isBefas).length} BEFAS)');
        } else {
          lastError =
              'Veri alındı (${allRaw.length} kayıt) ancak fon modeline dönüştürülemedi. '
              'Örnek: ${jsonEncode(allRaw.first)}';
        }
      } else {
        lastError ??= 'API boş liste döndürdü.';
      }
    } catch (e) {
      lastError = 'Beklenmeyen hata: $e';
    } finally {
      isSyncing = false;
      _syncController.add(lastError == null);
    }
  }

  // ──────────────────── Yerel Veri Erişimi ────────────────────

  /// Tüm fon listesini döner.
  /// Bellek → Hive → API öncelik sırasını izler.
  static Future<List<TefasFund>> getAllFunds() async {
    // 1. Bellek — yalnızca güncel (< 10 dk) ise kullan
    if (!_isMemoryStale()) return _allFunds;

    // 2. In-memory cache
    final raw = _cacheRead('tefas_all_funds');
    if (raw != null && _isCacheValid()) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        final seenCodes = <String>{};
        final funds = list
            .map((j) => TefasFund.fromJson(j))
            .where((f) => f.code.isNotEmpty && seenCodes.add(f.code))
            .toList();
        final befasCount = funds.where((f) => f.isBefas).length;
        if (funds.isNotEmpty && befasCount > 0) {
          _allFunds = funds;
          _fundsLoadedToMemory = true;
          _lastFullSyncTime = DateTime.now(); // Hive'dan yüklendi, bellek taze sayılır
          developer.log(
              'TefasService: ${funds.length} fon Hive\'dan yüklendi '
              '(${funds.length - befasCount} TEFAS, $befasCount BEFAS)');
          return _allFunds;
        }
        // BEFAS fon yoksa cache muhtemelen eski/bozuk — API'den yenile.
        developer.log('TefasService: Hive cache\'de BEFAS fon yok, API\'den yenileniyor...');
      } catch (e) {
        developer.log('TefasService: Hive parse hatası: $e');
      }
    }

    // 3. Senkronizasyon devam ediyorsa bekle, yoksa API'den çek
    if (isSyncing) {
      await onSyncComplete.first;
    } else {
      await refreshAllFunds();
    }

    // 4. Bellekte veri varsa döndür (API başarısız olsa bile önceki veri korunur)
    if (_allFunds.isNotEmpty) {
      _lastFullSyncTime ??= DateTime.now();
      return _allFunds;
    }

    // 5. Son çare: süresi dolmuş cache
    final staleFallback = _cacheRead('tefas_all_funds');
    if (staleFallback != null) {
      try {
        final list = (jsonDecode(staleFallback) as List).cast<Map<String, dynamic>>();
        final seenCodes = <String>{};
        final funds = list
            .map((j) => TefasFund.fromJson(j))
            .where((f) => f.code.isNotEmpty && seenCodes.add(f.code))
            .toList();
        if (funds.isNotEmpty) {
          _allFunds = funds;
          _fundsLoadedToMemory = true;
          _lastFullSyncTime = DateTime.now();
          developer.log(
              'TefasService: API başarısız, süresi dolmuş Hive cache kullanılıyor '
              '(${funds.length} fon)');
        }
      } catch (e) {
        developer.log('TefasService: süresi dolmuş Hive fallback hatası: $e');
      }
    }
    return _allFunds;
  }

  /// Sayfalı fon listesi — Supabase tefas_funds tablosundan okur.
  static Future<({List<TefasFund> funds, bool hasMore})> getFunds({
    int page = 1,
    int size = 50,
    bool isBefas = false,
    FundSortOption sortBy = FundSortOption.nameAsc,
  }) async {
    try {
      final from = (page - 1) * size;
      final to = from + size; // +1 extra to detect hasMore

      final (col, asc) = _sortColumn(sortBy);
      final data = await supabase
          .from('tefas_funds')
          .select()
          .eq('is_befas', isBefas)
          .order(col, ascending: asc, nullsFirst: false)
          .range(from, to);

      final list = (data as List).cast<Map<String, dynamic>>();
      final hasMore = list.length > size;
      final funds = list.take(size).map(TefasFund.fromSupabase).toList();
      return (funds: funds, hasMore: hasMore);
    } catch (e) {
      developer.log('TefasService.getFunds Supabase hata: $e');
      return (funds: <TefasFund>[], hasMore: false);
    }
  }

  static (String, bool) _sortColumn(FundSortOption sortBy) {
    return switch (sortBy) {
      FundSortOption.nameAsc => ('name', true),
      FundSortOption.codeAsc => ('code', true),
      FundSortOption.priceDesc => ('price', false),
      FundSortOption.return1YearDesc => ('return_1y', false),
      FundSortOption.totalSizeDesc => ('total_size', false),
    };
  }

  /// Arama — Supabase tefas_funds tablosunda arar.
  static Future<List<TefasFund>> searchFunds(
    String query, {
    bool isBefas = false,
  }) async {
    if (query.trim().length < 2) return [];
    try {
      final q = query.trim();
      final data = await supabase
          .from('tefas_funds')
          .select()
          .eq('is_befas', isBefas)
          .or('code.ilike.%$q%,name.ilike.%$q%')
          .order('name', ascending: true)
          .limit(30);

      return (data as List)
          .cast<Map<String, dynamic>>()
          .map(TefasFund.fromSupabase)
          .toList();
    } catch (e) {
      developer.log('TefasService.searchFunds Supabase hata: $e');
      return [];
    }
  }

  // ──────────────────── Fon Detayı ────────────────────

  /// Fon detayını döner. Hive cache'li.
  static Future<TefasFundDetail?> getFundDetail(
    String code, {
    bool isBefas = false,
  }) async {
    final hiveKey = 'detail_$code';

    if (_isDetailValid(hiveKey)) {
      final raw = _cacheRead('tefas_$hiveKey');
      if (raw != null) {
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          return TefasFundDetail.fromMerged(json, code, isBefas: isBefas);
        } catch (_) {}
      }
    }

    try {
      final results = await Future.wait([
        http
            .get(Uri.parse('$_baseUrl/api/v1/funds/$code'), headers: _headers)
            .timeout(const Duration(seconds: 12)),
        http
            .get(
              Uri.parse('$_baseUrl/api/v1/funds/$code/info'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 12)),
      ], eagerError: false);

      final merged = <String, dynamic>{};

      // Önce temel listeden fon verisini ekle (return1w vb. alanlar için)
      final base = _allFunds.where((f) => f.code == code).firstOrNull;
      if (base != null) {
        // Bellekteki veriyi başlangıç olarak ekle
        merged['fundCode'] = base.code;
        merged['fundName'] = base.name;
        merged['fundType'] = base.isBefas ? '2' : '1';
        if (base.price != null) merged['price'] = base.price;
        if (base.return1Week != null) merged['return1w'] = base.return1Week;
        if (base.return1Month != null) merged['return1m'] = base.return1Month;
        if (base.return3Month != null) merged['return3m'] = base.return3Month;
        if (base.return6Month != null) merged['return6m'] = base.return6Month;
        if (base.return1Year != null) merged['return1y'] = base.return1Year;
        if (base.returnYtd != null) merged['returnYtd'] = base.returnYtd;
        if (base.totalSize != null) merged['total_size'] = base.totalSize;
      }

      for (final res in results) {
        if (res.statusCode == 200) {
          try {
            final body = jsonDecode(res.body);
            final list = extractFundList(body);
            if (list.isNotEmpty && list.first is Map<String, dynamic>) {
              merged.addAll(list.first as Map<String, dynamic>);
            } else if (body is Map<String, dynamic>) {
              merged.addAll(body);
            }
          } catch (_) {}
        }
      }

      if (merged.isNotEmpty) {
        _cacheWrite('tefas_$hiveKey', jsonEncode(merged));
        return TefasFundDetail.fromMerged(merged, code, isBefas: isBefas);
      }
    } catch (e, s) {
      developer.log('TefasService.getFundDetail hatası', error: e, stackTrace: s);
    }
    return null;
  }

  // ──────────────────── Fiyat Güncellemesi ────────────────────

  static Future<double?> getFundCurrentPrice(String code) async {
    // 1. Bellek
    if (_fundsLoadedToMemory) {
      final fund = _allFunds.where((f) => f.code == code).firstOrNull;
      if (fund?.price != null) return fund!.price;
    }

    // 2. Hive cache
    final hiveKey = 'detail_$code';
    if (_isDetailValid(hiveKey)) {
      final raw = _cacheRead('tefas_$hiveKey');
      if (raw != null) {
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          final price = TefasFund.fromJson(json).price;
          if (price != null) return price;
        } catch (_) {}
      }
    }

    // 3. API: /api/v1/funds/{code} — detaylı fon verisi
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/v1/funds/$code'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        developer.log('TefasService.getFundCurrentPrice [$code] raw: '
            '${res.body.length > 300 ? res.body.substring(0, 300) : res.body}');
        final body = jsonDecode(res.body);
        final list =
            extractFundList(body).whereType<Map<String, dynamic>>().toList();
        if (list.isNotEmpty) {
          final price = TefasFund.fromJson(list.first).price;
          if (price != null && price > 0) {
            _cacheWrite('tefas_$hiveKey', jsonEncode(list.first));
            return price;
          }
        }
      } else {
        developer.log('TefasService.getFundCurrentPrice [$code] HTTP ${res.statusCode}');
      }
    } catch (e) {
      developer.log('TefasService.getFundCurrentPrice [$code] hata: $e');
    }

    // 4. Fallback: /api/v1/fund-info-history/{code}?page=1&size=1 — tarihsel NAV (son kayıt = güncel)
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/v1/fund-info-history/$code?page=1&size=1'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        developer.log('TefasService.fundInfoHistory [$code] raw: '
            '${res.body.length > 300 ? res.body.substring(0, 300) : res.body}');
        final body = jsonDecode(res.body);
        final list =
            extractFundList(body).whereType<Map<String, dynamic>>().toList();
        if (list.isNotEmpty) {
          final price = TefasFund.fromJson(list.first).price;
          if (price != null && price > 0) {
            developer.log('TefasService.fundInfoHistory [$code] fiyat: $price');
            _cacheWrite('tefas_$hiveKey', jsonEncode(list.first));
            return price;
          }
        }
      }
    } catch (e) {
      developer.log('TefasService.fundInfoHistory [$code] hata: $e');
    }

    return null;
  }

  // ──────────────────── Tarihsel Fiyat Geçmişi ────────────────────

  /// Belirtilen fon için tarihsel fiyat verisi döner.
  /// Endpoint: /api/v1/fund-info-history/{code}?page=1&size={size}
  /// Cache: 4 saat
  static Future<List<TefasFundHistoryEntry>> getFundHistory(
    String code, {
    int size = 30,
  }) async {
    final cacheKey = 'history_${code}_$size';

    final cacheEntry = _cache['tefas_$cacheKey'];
    final cacheValid = cacheEntry != null &&
        DateTime.now().difference(cacheEntry.$2).inHours < _historyCacheTtlHours;
    if (cacheValid) {
      final cached = cacheEntry.$1;
      try {
        final list = (jsonDecode(cached) as List)
            .cast<Map<String, dynamic>>()
            .map(TefasFundHistoryEntry.fromJson)
            .where((e) => e.price > 0)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }

    try {
      final url = '$_baseUrl/api/v1/fund-info-history/$code?page=1&size=$size';
      final res = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        developer.log('TefasService.getFundHistory [$code/$size] raw: '
            '${res.body.length > 300 ? res.body.substring(0, 300) : res.body}');
        final body = jsonDecode(res.body);
        final rawList =
            extractFundList(body).whereType<Map<String, dynamic>>().toList();

        if (rawList.isNotEmpty) {
          _cacheWrite('tefas_$cacheKey', jsonEncode(rawList));

          final entries = rawList
              .map(TefasFundHistoryEntry.fromJson)
              .where((e) => e.price > 0)
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));
          return entries;
        }
      } else {
        developer.log(
            'TefasService.getFundHistory [$code] HTTP ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      developer.log('TefasService.getFundHistory [$code] hata: $e');
    }

    return [];
  }

  /// Bellekteki fon listesinden doğrudan fiyat döner (API isteği yapmaz).
  /// refreshIfStale() sonrası _allFunds doluysa hızlıca fiyat bulur.
  static double? getPriceFromMemory(String code) {
    if (!_fundsLoadedToMemory || _allFunds.isEmpty) return null;
    return _allFunds.where((f) => f.code == code).firstOrNull?.price;
  }

  // ──────────────────── Durum Bilgisi ────────────────────

  static DateTime? lastFullSync() => _lastFullSyncTime;

  static int get loadedFundCount => _allFunds.length;

  static void clearMemoryCache() {
    _allFunds = [];
    _fundsLoadedToMemory = false;
    _lastFullSyncTime = null;
  }

  /// Kullanıcının açık isteğiyle tam yenileme — TTL kısıtı yok.
  /// Tüm cache'i siler ve API'den yeniden çeker.
  static Future<void> forceRefresh() async {
    isSyncing = false;
    clearMemoryCache();
    _cache.removeWhere((key, _) => key.startsWith('tefas_'));
    await refreshAllFunds();
  }
}
