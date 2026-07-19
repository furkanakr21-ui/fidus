import '../models/income_expense_model.dart';
import 'supabase_service.dart';
import 'supabase_pagination.dart';

class CashFlowService {
  static String get _userId => supabase.auth.currentUser!.id;

  static Future<List<CashFlowModel>> getByPortfolio(String portfolioId) async {
    final data = await supabase
        .from('cashflows')
        .select()
        .eq('portfolio_id', portfolioId)
        .order('date', ascending: false);
    return (data as List).map((e) => CashFlowModel.fromJson(e)).toList();
  }

  static Future<List<CashFlowModel>> getByPortfolios(
    List<String> portfolioIds,
  ) async {
    if (portfolioIds.isEmpty) return [];
    return loadAllSupabasePages((from, to) async {
      final data = await supabase
          .from('cashflows')
          .select()
          .eq('user_id', _userId)
          .inFilter('portfolio_id', portfolioIds)
          .order('date', ascending: false)
          .order('id')
          .range(from, to);
      return (data as List)
          .map((row) => CashFlowModel.fromJson(row))
          .toList(growable: false);
    });
  }

  static Future<CashFlowModel> save(CashFlowModel cashflow) async {
    final row = await supabase
        .from('cashflows')
        .insert(cashflow.toInsertJson(_userId))
        .select()
        .single();
    return CashFlowModel.fromJson(row);
  }

  static Future<void> delete(String id) async {
    await supabase.from('cashflows').delete().eq('id', id);
  }
}
