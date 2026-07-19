import '../models/asset_model.dart';
import 'supabase_service.dart';
import 'supabase_pagination.dart';

class AssetService {
  static String get _userId => supabase.auth.currentUser!.id;

  static Future<List<AssetModel>> getByPortfolio(String portfolioId) async {
    final data = await supabase
        .from('assets')
        .select()
        .eq('portfolio_id', portfolioId)
        .order('created_at');
    return (data as List).map((e) => AssetModel.fromJson(e)).toList();
  }

  static Future<List<AssetModel>> getByPortfolios(
    List<String> portfolioIds,
  ) async {
    if (portfolioIds.isEmpty) return [];
    return loadAllSupabasePages((from, to) async {
      final data = await supabase
          .from('assets')
          .select()
          .eq('user_id', _userId)
          .inFilter('portfolio_id', portfolioIds)
          .order('created_at')
          .order('id')
          .range(from, to);
      return (data as List)
          .map((row) => AssetModel.fromJson(row))
          .toList(growable: false);
    });
  }

  static Future<AssetModel> save(AssetModel asset) async {
    final row = await supabase
        .from('assets')
        .insert(asset.toInsertJson(_userId))
        .select()
        .single();
    return AssetModel.fromJson(row);
  }

  static Future<void> update(AssetModel asset) async {
    await supabase
        .from('assets')
        .update({
          'name': asset.name,
          'symbol': asset.symbol,
          'type': asset.type.name,
          'quantity': asset.quantity,
          'buy_price': asset.buyPrice,
          'buy_date': asset.buyDate.toIso8601String().split('T').first,
          'platform': asset.platform,
          'commission': asset.commission ?? 0,
          'note': asset.note,
          'currency': asset.currency,
          'api_source': asset.apiSource,
          'api_id': asset.apiId,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', asset.id);
  }

  static Future<void> delete(String id) async {
    await supabase.from('assets').delete().eq('id', id);
  }

  static Future<void> deleteAllInPortfolio(String portfolioId) async {
    await supabase.from('assets').delete().eq('portfolio_id', portfolioId);
  }
}
