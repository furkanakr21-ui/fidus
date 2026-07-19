import '../models/transaction_model.dart';
import 'supabase_service.dart';
import 'supabase_pagination.dart';

class TransactionService {
  static const int _assetIdChunkSize = 100;
  static String get _userId => supabase.auth.currentUser!.id;

  static Future<List<TransactionModel>> getByAsset(String assetId) async {
    final data = await supabase
        .from('transactions')
        .select()
        .eq('asset_id', assetId)
        .order('date', ascending: false);
    return (data as List).map((e) => TransactionModel.fromJson(e)).toList();
  }

  static Future<List<TransactionModel>> getByPortfolio(
    String portfolioId,
  ) async {
    final assetIds = await _assetIdsForPortfolio(portfolioId);
    if (assetIds.isEmpty) return [];
    final data = await supabase
        .from('transactions')
        .select()
        .inFilter('asset_id', assetIds)
        .order('date', ascending: false);
    return (data as List).map((e) => TransactionModel.fromJson(e)).toList();
  }

  static Future<List<TransactionModel>> getByPortfolios(
    List<String> portfolioIds,
  ) async {
    if (portfolioIds.isEmpty) return [];
    final assetIds = await _assetIdsForPortfolios(portfolioIds);
    if (assetIds.isEmpty) return [];

    final transactions = <TransactionModel>[];
    for (final assetIdChunk in chunked(assetIds, _assetIdChunkSize)) {
      final chunkRows = await loadAllSupabasePages((from, to) async {
        final data = await supabase
            .from('transactions')
            .select()
            .eq('user_id', _userId)
            .inFilter('asset_id', assetIdChunk)
            .order('date', ascending: false)
            .order('id')
            .range(from, to);
        return (data as List)
            .map((row) => TransactionModel.fromJson(row))
            .toList(growable: false);
      });
      transactions.addAll(chunkRows);
    }
    transactions.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
    return transactions;
  }

  static Future<TransactionModel> save(TransactionModel tx) async {
    final row = await supabase
        .from('transactions')
        .insert(tx.toInsertJson(_userId))
        .select()
        .single();
    return TransactionModel.fromJson(row);
  }

  static Future<void> delete(String id) async {
    await supabase.from('transactions').delete().eq('id', id);
  }

  static Future<List<String>> _assetIdsForPortfolio(String portfolioId) async {
    final data = await supabase
        .from('assets')
        .select('id')
        .eq('portfolio_id', portfolioId);
    return (data as List).map((e) => e['id'] as String).toList();
  }

  static Future<List<String>> _assetIdsForPortfolios(
    List<String> portfolioIds,
  ) {
    return loadAllSupabasePages((from, to) async {
      final data = await supabase
          .from('assets')
          .select('id')
          .eq('user_id', _userId)
          .inFilter('portfolio_id', portfolioIds)
          .order('created_at')
          .order('id')
          .range(from, to);
      return (data as List)
          .map((row) => row['id'] as String)
          .toList(growable: false);
    });
  }
}
