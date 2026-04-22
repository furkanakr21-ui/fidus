import '../models/income_expense_model.dart';
import 'supabase_service.dart';

class CashFlowService {
  static String get _userId => supabase.auth.currentUser!.id;

  static Future<List<CashFlowModel>> getByPortfolio(
      String portfolioId) async {
    final data = await supabase
        .from('cashflows')
        .select()
        .eq('portfolio_id', portfolioId)
        .order('date', ascending: false);
    return (data as List).map((e) => CashFlowModel.fromJson(e)).toList();
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
