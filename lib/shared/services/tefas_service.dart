import 'dart:developer' as developer;
import '../models/tefas_fund_model.dart';
import 'supabase_service.dart';

double? _readPositiveDouble(dynamic value) {
  double? parsed;
  if (value is num) {
    parsed = value.toDouble();
  } else if (value is String) {
    parsed = double.tryParse(value.replaceAll(',', '.'));
  }
  return parsed != null && parsed > 0 ? parsed : null;
}

enum FundSortOption {
  nameAsc,
  codeAsc,
  priceDesc,
  return1YearDesc,
  totalSizeDesc,
}

/// TEFAS / BEFAS veri servisi — tüm veriler Supabase'den gelir.
/// Dış API çağrısı yoktur; sunucu tarafındaki zamanlanmış görevler günceller.
class TefasService {
  static String? lastError;

  // ──────────────────── Sayfalı Liste ────────────────────

  static Future<({List<TefasFund> funds, bool hasMore})> getFunds({
    int page = 1,
    int size = 50,
    bool isBefas = false,
    FundSortOption sortBy = FundSortOption.nameAsc,
  }) async {
    try {
      final from = (page - 1) * size;
      final (col, asc) = _sortColumn(sortBy);
      final data = await supabase
          .from('tefas_funds')
          .select()
          .eq('is_befas', isBefas)
          .eq('is_active', true)
          .order(col, ascending: asc, nullsFirst: false)
          .range(from, from + size);

      final list = (data as List).cast<Map<String, dynamic>>();
      final hasMore = list.length > size;
      final funds = list.take(size).map(TefasFund.fromSupabase).toList();
      lastError = null;
      return (funds: funds, hasMore: hasMore);
    } catch (e) {
      lastError = 'Supabase bağlantı hatası: $e';
      developer.log('TefasService.getFunds hata: $e');
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

  // ──────────────────── Arama ────────────────────

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
          .eq('is_active', true)
          .or('code.ilike.%$q%,name.ilike.%$q%')
          .order('name', ascending: true)
          .limit(30);

      return (data as List)
          .cast<Map<String, dynamic>>()
          .map(TefasFund.fromSupabase)
          .toList();
    } catch (e) {
      developer.log('TefasService.searchFunds hata: $e');
      return [];
    }
  }

  // ──────────────────── Fon Detayı ────────────────────

  /// Fon detayını tefas_funds tablosundan okur.
  /// isin, riskLevel, founder, assetDistribution alanları sunucu
  /// tarafından doldurulmadığı sürece null olacaktır.
  static Future<TefasFundDetail?> getFundDetail(
    String code, {
    bool isBefas = false,
  }) async {
    try {
      final data = await supabase
          .from('tefas_funds')
          .select()
          .eq('code', code)
          .eq('is_befas', isBefas)
          .maybeSingle();

      if (data == null) return null;
      final fund = TefasFundDetail.fromSupabase(data);

      double? price = fund.price;
      if (price == null) {
        final priceRow = await supabase
            .from('prices')
            .select('price')
            .eq('symbol', code)
            .eq('api_source', isBefas ? 'befas' : 'tefas')
            .maybeSingle();
        if (priceRow != null) {
          price = _readPositiveDouble(priceRow['price']) ?? price;
        }
      }

      return TefasFundDetail(
        code: fund.code,
        name: fund.name,
        price: price,
        type: fund.type,
        category: fund.category,
        return1Week: fund.return1Week,
        return1Month: fund.return1Month,
        return3Month: fund.return3Month,
        return6Month: fund.return6Month,
        return1Year: fund.return1Year,
        returnYtd: fund.returnYtd,
        return3Year: fund.return3Year,
        return5Year: fund.return5Year,
        totalSize: fund.totalSize,
        shareCount: fund.shareCount,
        investorCount: fund.investorCount,
        exchangeBulletinPrice: fund.exchangeBulletinPrice,
        priceDate: fund.priceDate,
        sourceFundType: fund.sourceFundType,
        fundFamilyLabel: fund.fundFamilyLabel,
        isBefas: fund.isBefas,
        riskLevel: fund.riskLevel,
        date: fund.date,
      );
    } catch (e) {
      developer.log('TefasService.getFundDetail hata: $e');
      return null;
    }
  }

  // ──────────────────── Güncel Fiyat ────────────────────

  /// Fon birim pay değerini döner.
  /// 1. tefas_funds tablosu  2. prices tablosu.
  /// Kullanıcı istemcisi dış market API çağrısı yapmaz.
  static Future<double?> getFundCurrentPrice(
    String code, {
    bool isBefas = false,
  }) async {
    try {
      // 1. tefas_funds
      final data = await supabase
          .from('tefas_funds')
          .select('price')
          .eq('code', code)
          .eq('is_befas', isBefas)
          .maybeSingle();
      if (data != null) {
        final price = (data as Map)['price'];
        final p = _readPositiveDouble(price);
        if (p != null) return p;
      }
      // 2. prices tablosu
      final priceRow = await supabase
          .from('prices')
          .select('price')
          .eq('symbol', code)
          .eq('api_source', isBefas ? 'befas' : 'tefas')
          .maybeSingle();
      if (priceRow != null) {
        return _readPositiveDouble(priceRow['price']);
      }
      return null;
    } catch (e) {
      developer.log('TefasService.getFundCurrentPrice hata: $e');
      return null;
    }
  }
}
