import '../models/transaction_model.dart';
import 'supabase_service.dart';

class TransactionService {
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
      String portfolioId) async {
    final assetIds = await _assetIdsForPortfolio(portfolioId);
    if (assetIds.isEmpty) return [];
    final data = await supabase
        .from('transactions')
        .select()
        .inFilter('asset_id', assetIds)
        .order('date', ascending: false);
    return (data as List).map((e) => TransactionModel.fromJson(e)).toList();
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

  static Future<List<String>> _assetIdsForPortfolio(
      String portfolioId) async {
    final data = await supabase
        .from('assets')
        .select('id')
        .eq('portfolio_id', portfolioId);
    return (data as List).map((e) => e['id'] as String).toList();
  }
}
