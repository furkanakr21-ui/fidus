import '../models/asset_model.dart';
import '../../core/constants/asset_list.dart';
import 'supabase_service.dart';

class SearchResult {
  final String symbol;
  final String name;
  final String apiSource;
  final String apiId;
  final String currency;
  final AssetType type;

  SearchResult({
    required this.symbol,
    required this.name,
    required this.apiSource,
    required this.apiId,
    required this.currency,
    required this.type,
  });
}

class SearchService {
  // Anlık yerel BIST araması — hiç ağ bağlantısı gerektirmez
  static List<SearchResult> filterBistLocal(String query) {
    return _filterLocal(query.trim(), AssetList.popularBist, AssetType.stock);
  }

  static Future<List<SearchResult>> searchBist(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];
    try {
      final data = await supabase
          .from('asset_metadata')
          .select()
          .eq('market', 'bist')
          .or('symbol.ilike.%$q%,name.ilike.%$q%')
          .order('symbol', ascending: true)
          .limit(25);
      final rows = data as List;
      if (rows.isNotEmpty) {
        return rows.map((r) => _rowToResult(r, AssetType.stock)).toList();
      }
    } catch (_) {}
    return _filterLocal(q, AssetList.popularBist, AssetType.stock);
  }

  static Future<List<SearchResult>> searchForeign(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final data = await supabase
          .from('asset_metadata')
          .select()
          .eq('market', 'us')
          .or('symbol.ilike.%$q%,name.ilike.%$q%')
          .order('symbol', ascending: true)
          .limit(20);
      final rows = data as List;
      if (rows.isNotEmpty) {
        return rows.map((r) {
          final type = (r['asset_type'] as String?) == 'etf'
              ? AssetType.fund
              : AssetType.stock;
          return _rowToResult(r, type);
        }).toList();
      }
    } catch (_) {}
    return _filterLocal(q, AssetList.popularForeign, AssetType.stock);
  }

  static Future<List<SearchResult>> searchCrypto(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final data = await supabase
          .from('asset_metadata')
          .select()
          .eq('market', 'crypto')
          .or('symbol.ilike.%$q%,name.ilike.%$q%')
          .order('symbol', ascending: true)
          .limit(20);
      final rows = data as List;
      if (rows.isNotEmpty) {
        return rows.map((r) => _rowToResult(r, AssetType.crypto)).toList();
      }
    } catch (_) {}
    return _filterLocal(q, AssetList.popularCrypto, AssetType.crypto);
  }

  static SearchResult _rowToResult(Map<dynamic, dynamic> r, AssetType type) {
    return SearchResult(
      symbol: r['symbol'] as String,
      name: r['name'] as String,
      apiSource: r['api_source'] as String,
      apiId: r['api_id'] as String,
      currency: r['currency'] as String? ?? 'USD',
      type: type,
    );
  }

  static List<SearchResult> _filterLocal(
    String query,
    List<AssetInfo> list,
    AssetType type,
  ) {
    final q = query.toLowerCase();
    return list
        .where(
          (a) =>
              a.symbol.toLowerCase().contains(q) ||
              a.name.toLowerCase().contains(q),
        )
        .map(
          (a) => SearchResult(
            symbol: a.symbol,
            name: a.name,
            apiSource: a.apiSource,
            apiId: a.apiId,
            currency: a.currency,
            type: type,
          ),
        )
        .toList();
  }
}
