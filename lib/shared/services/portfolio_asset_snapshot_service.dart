import '../models/portfolio_asset_value_snapshot_model.dart';
import 'portfolio_snapshot_service.dart';
import 'supabase_service.dart';

class PortfolioAssetSnapshotService {
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
}
