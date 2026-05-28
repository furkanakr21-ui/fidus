import '../models/portfolio_value_snapshot_model.dart';
import 'supabase_service.dart';

class PortfolioSnapshotService {
  static String _dateOnly(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static DateTime todayInTurkey() {
    return DateTime.now().toUtc().add(const Duration(hours: 3));
  }

  static Future<PortfolioValueSnapshot?> getToday(String portfolioId) {
    return getForDate(portfolioId, todayInTurkey());
  }

  static Future<PortfolioValueSnapshot?> getForDate(
    String portfolioId,
    DateTime date,
  ) async {
    final data = await supabase
        .from('portfolio_value_snapshots')
        .select()
        .eq('portfolio_id', portfolioId)
        .eq('snapshot_date', _dateOnly(date))
        .maybeSingle();
    if (data == null) return null;
    return PortfolioValueSnapshot.fromJson(data);
  }

  static Future<List<PortfolioValueSnapshot>> getHistory(
    String portfolioId,
  ) async {
    final data = await supabase
        .from('portfolio_value_snapshots')
        .select()
        .eq('portfolio_id', portfolioId)
        .order('snapshot_date', ascending: true)
        .limit(2000);
    return (data as List)
        .map((row) => PortfolioValueSnapshot.fromJson(row))
        .toList(growable: false);
  }
}
