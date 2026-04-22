import '../models/portfolio_model.dart';
import 'supabase_service.dart';

class PortfolioService {
  static String get _userId => supabase.auth.currentUser!.id;

  static Future<List<PortfolioModel>> getAll() async {
    final data = await supabase
        .from('portfolios')
        .select()
        .eq('user_id', _userId)
        .order('created_at');
    return (data as List).map((e) => PortfolioModel.fromJson(e)).toList();
  }

  static Future<PortfolioModel> create(String name, String emoji) async {
    final row = await supabase
        .from('portfolios')
        .insert({'user_id': _userId, 'name': name, 'emoji': emoji})
        .select()
        .single();
    return PortfolioModel.fromJson(row);
  }

  static Future<void> delete(String id) async {
    await supabase.from('portfolios').delete().eq('id', id);
  }

  static Future<String?> getActivePortfolioId() async {
    final data = await supabase
        .from('user_settings')
        .select('active_portfolio_id')
        .eq('user_id', _userId)
        .maybeSingle();
    return data?['active_portfolio_id'] as String?;
  }

  static Future<void> setActivePortfolio(String portfolioId) async {
    await supabase.from('user_settings').upsert({
      'user_id': _userId,
      'active_portfolio_id': portfolioId,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<String?> getSyncCode() async {
    final data = await supabase
        .from('profiles')
        .select('sync_code')
        .eq('id', _userId)
        .maybeSingle();
    return data?['sync_code'] as String?;
  }

  static Future<Map<String, String>> getSettings() async {
    final data = await supabase
        .from('user_settings')
        .select('theme, currency')
        .eq('user_id', _userId)
        .maybeSingle();
    return {
      'theme': data?['theme'] as String? ?? 'system',
      'currency': data?['currency'] as String? ?? 'TRY',
    };
  }

  static Future<void> saveSettings({String? theme, String? currency}) async {
    final update = <String, dynamic>{
      'user_id': _userId,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (theme != null) update['theme'] = theme;
    if (currency != null) update['currency'] = currency;
    await supabase.from('user_settings').upsert(update);
  }
}
