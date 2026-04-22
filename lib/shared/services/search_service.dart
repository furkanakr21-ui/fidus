import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/asset_model.dart';
import '../../core/constants/asset_list.dart';

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
  /// Anlık yerel BIST araması — ağ bağlantısı gerektirmez.
  /// Kullanıcı yazdıkça arayüzde hemen sonuç göstermek için kullanılır.
  static List<SearchResult> filterBistLocal(String query) {
    return _filterPopular(query.trim(), 'bist', AssetType.stock);
  }

  static Future<List<SearchResult>> searchBist(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];

    // 1. Yerel liste — anında, güvenilir (62 hisse)
    final local = _filterPopular(q, 'bist', AssetType.stock);

    // 2. Yahoo Finance API — yerel listede olmayan hisseler için
    try {
      // q=$symbol (nokta-IS eklenmeden): Yahoo hem kısmi hem tam eşleşme döndürür
      final url =
          'https://query1.finance.yahoo.com/v1/finance/search?q=$q&lang=tr&region=TR&quotesCount=15&newsCount=0';
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final quotes = data['quotes'] as List? ?? [];
        final apiResults = quotes
            .where(
              (q) =>
                  q['symbol'] != null &&
                  (q['symbol'] as String).endsWith('.IS'),
            )
            .map(
              (q) => SearchResult(
                symbol: (q['symbol'] as String).replaceAll('.IS', ''),
                name: q['longname'] ?? q['shortname'] ?? q['symbol'],
                apiSource: 'yahoo',
                apiId: q['symbol'] as String,
                currency: 'TRY',
                type: AssetType.stock,
              ),
            )
            .toList();

        if (apiResults.isNotEmpty) {
          // Önce yerel, sonra API'den gelen (local'da olmayanlar) — dedup
          final merged = [...local];
          for (final r in apiResults) {
            if (!merged.any((l) => l.symbol == r.symbol)) {
              merged.add(r);
            }
          }
          return merged;
        }
      }
    } catch (_) {}

    // API başarısız → sadece yerel sonuçlar
    return local;
  }

  static Future<List<SearchResult>> searchForeign(String query) async {
    if (query.isEmpty) return [];
    try {
      final url =
          'https://query1.finance.yahoo.com/v1/finance/search?q=$query&lang=en&region=US&quotesCount=10&newsCount=0';
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final quotes = data['quotes'] as List? ?? [];
        final results = quotes
            .where(
              (q) =>
                  q['symbol'] != null &&
                  !(q['symbol'] as String).endsWith('.IS') &&
                  ['EQUITY', 'ETF'].contains(q['quoteType']),
            )
            .map(
              (q) => SearchResult(
                symbol: q['symbol'],
                name: q['longname'] ?? q['shortname'] ?? q['symbol'],
                apiSource: 'yahoo',
                apiId: q['symbol'],
                currency: (q['currency'] as String?) ?? 'USD',
                type: q['quoteType'] == 'ETF'
                    ? AssetType.fund
                    : AssetType.stock,
              ),
            )
            .take(8)
            .toList();
        if (results.isNotEmpty) return results;
      }
    } catch (_) {}
    return _filterPopular(query, 'foreign', AssetType.stock);
  }

  static Future<List<SearchResult>> searchCrypto(String query) async {
    if (query.isEmpty) return [];
    try {
      final url = 'https://api.coingecko.com/api/v3/search?query=$query';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final coins = data['coins'] as List? ?? [];
        final results = coins
            .take(8)
            .map(
              (c) => SearchResult(
                symbol: (c['symbol'] as String).toUpperCase(),
                name: c['name'],
                apiSource: 'coingecko',
                apiId: c['id'],
                currency: 'USD',
                type: AssetType.crypto,
              ),
            )
            .toList();
        if (results.isNotEmpty) return results;
      }
    } catch (_) {}
    return _filterPopular(query, 'crypto', AssetType.crypto);
  }

  static List<SearchResult> _filterPopular(
    String query,
    String key,
    AssetType type,
  ) {
    final list = AssetList.getPopular(key);
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
