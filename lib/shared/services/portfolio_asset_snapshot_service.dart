import '../models/portfolio_asset_value_snapshot_model.dart';
import 'portfolio_snapshot_service.dart';
import 'supabase_service.dart';
import 'supabase_pagination.dart';

class PortfolioAssetSnapshotService {
  static String get _userId => supabase.auth.currentUser!.id;

  static String _dateOnly(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static Future<List<PortfolioAssetValueSnapshot>> getToday(
    String portfolioId,
  ) {
    return getForDate(portfolioId, PortfolioSnapshotService.todayInTurkey());
  }

  static Future<List<PortfolioAssetValueSnapshot>> getForDate(
    String portfolioId,
    DateTime date,
  ) async {
    final data = await supabase
        .from('portfolio_asset_value_snapshots')
        .select()
        .eq('portfolio_id', portfolioId)
        .eq('snapshot_date', _dateOnly(date))
        .order('symbol');
    return (data as List)
        .map((row) => PortfolioAssetValueSnapshot.fromJson(row))
        .toList(growable: false);
  }

  static Future<List<PortfolioAssetValueSnapshot>> getTodayForPortfolios(
    List<String> portfolioIds,
  ) {
    return getForDateForPortfolios(
      portfolioIds,
      PortfolioSnapshotService.todayInTurkey(),
    );
  }

  static Future<List<PortfolioAssetValueSnapshot>> getForDateForPortfolios(
    List<String> portfolioIds,
    DateTime date,
  ) {
    if (portfolioIds.isEmpty) return Future.value(const []);
    return loadAllSupabasePages((from, to) async {
      final data = await supabase
          .from('portfolio_asset_value_snapshots')
          .select()
          .eq('user_id', _userId)
          .inFilter('portfolio_id', portfolioIds)
          .eq('snapshot_date', _dateOnly(date))
          .order('symbol')
          .order('portfolio_id')
          .order('id')
          .range(from, to);
      return (data as List)
          .map((row) => PortfolioAssetValueSnapshot.fromJson(row))
          .toList(growable: false);
    });
  }
}
