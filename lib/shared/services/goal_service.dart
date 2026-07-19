import '../models/goal_model.dart';
import 'supabase_service.dart';
import 'supabase_pagination.dart';

class GoalService {
  static String get _userId => supabase.auth.currentUser!.id;

  static Future<List<GoalModel>> getByPortfolio(String portfolioId) async {
    final data = await supabase
        .from('goals')
        .select()
        .eq('portfolio_id', portfolioId)
        .order('created_at');
    return (data as List).map((e) => GoalModel.fromJson(e)).toList();
  }

  static Future<List<GoalModel>> getByPortfolios(
    List<String> portfolioIds,
  ) async {
    if (portfolioIds.isEmpty) return [];
    return loadAllSupabasePages((from, to) async {
      final data = await supabase
          .from('goals')
          .select()
          .eq('user_id', _userId)
          .inFilter('portfolio_id', portfolioIds)
          .order('created_at')
          .order('id')
          .range(from, to);
      return (data as List)
          .map((row) => GoalModel.fromJson(row))
          .toList(growable: false);
    });
  }

  static Future<GoalModel> save(GoalModel goal) async {
    final row = await supabase
        .from('goals')
        .insert(goal.toInsertJson(_userId))
        .select()
        .single();
    return GoalModel.fromJson(row);
  }

  static Future<void> update(GoalModel goal) async {
    await supabase
        .from('goals')
        .update({
          'title': goal.title,
          'emoji': goal.emoji,
          'type': goal.type.name,
          'target_amount': goal.targetAmount,
          'current_amount': goal.currentAmount,
          'target_date': goal.targetDate?.toIso8601String().split('T').first,
          'currency': goal.currency,
          'note': goal.note,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', goal.id);
  }

  static Future<void> delete(String id) async {
    await supabase.from('goals').delete().eq('id', id);
  }
}
