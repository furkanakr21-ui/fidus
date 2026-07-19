import '../models/portfolio_model.dart';
import 'supabase_service.dart';

abstract interface class PortfolioDataSource {
  Future<List<PortfolioModel>> getAll();
  Future<PortfolioModel> create(String name, String emoji);
  Future<void> delete(String id);
  Future<void> setActivePortfolio(String portfolioId);
  Future<void> setTotalViewActive();
  Future<void> setTotalViewInactive();
  Future<void> setIncludeInTotal(String portfolioId, bool value);
  Future<Map<String, dynamic>> getSettings();
  Future<void> saveSettings({String? theme, String? currency});
}

class SupabasePortfolioDataSource implements PortfolioDataSource {
  const SupabasePortfolioDataSource();

  @override
  Future<List<PortfolioModel>> getAll() => PortfolioService.getAll();

  @override
  Future<PortfolioModel> create(String name, String emoji) =>
      PortfolioService.create(name, emoji);

  @override
  Future<void> delete(String id) => PortfolioService.delete(id);

  @override
  Future<void> setActivePortfolio(String portfolioId) =>
      PortfolioService.setActivePortfolio(portfolioId);

  @override
  Future<void> setTotalViewActive() => PortfolioService.setTotalViewActive();

  @override
  Future<void> setTotalViewInactive() =>
      PortfolioService.setTotalViewInactive();

  @override
  Future<void> setIncludeInTotal(String portfolioId, bool value) =>
      PortfolioService.setIncludeInTotal(portfolioId, value);

  @override
  Future<Map<String, dynamic>> getSettings() => PortfolioService.getSettings();

  @override
  Future<void> saveSettings({String? theme, String? currency}) =>
      PortfolioService.saveSettings(theme: theme, currency: currency);
}

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
      'total_view_active': false,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> setTotalViewActive() async {
    await supabase.from('user_settings').upsert({
      'user_id': _userId,
      'total_view_active': true,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> setTotalViewInactive() async {
    await supabase.from('user_settings').upsert({
      'user_id': _userId,
      'total_view_active': false,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> setIncludeInTotal(String portfolioId, bool value) async {
    await supabase
        .from('portfolios')
        .update({'include_in_total': value})
        .eq('id', portfolioId)
        .eq('user_id', _userId);
  }

  static Future<String?> getSyncCode() async {
    final data = await supabase
        .from('profiles')
        .select('sync_code')
        .eq('id', _userId)
        .maybeSingle();
    return data?['sync_code'] as String?;
  }

  static Future<Map<String, dynamic>> getSettings() async {
    final data = await supabase
        .from('user_settings')
        .select('theme, currency, active_portfolio_id, total_view_active')
        .eq('user_id', _userId)
        .maybeSingle();
    return {
      'theme': data?['theme'] as String? ?? 'system',
      'currency': data?['currency'] as String? ?? 'TRY',
      'active_portfolio_id': data?['active_portfolio_id'] as String?,
      'total_view_active': data?['total_view_active'] as bool? ?? false,
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
