import '../utils/currency_utils.dart';
import 'portfolio_value_snapshot_model.dart';

enum PortfolioHistoryRange {
  days7('7G', Duration(days: 7)),
  month1('1A', Duration(days: 30)),
  month3('3A', Duration(days: 90)),
  year1('1Y', Duration(days: 365)),
  all('Tümü', null);

  final String label;
  final Duration? duration;

  const PortfolioHistoryRange(this.label, this.duration);
}

class PortfolioHistoryChartPoint {
  final DateTime date;
  final double value;

  const PortfolioHistoryChartPoint({required this.date, required this.value});
}

class PortfolioHistoryChartData {
  final List<PortfolioHistoryChartPoint> points;
  final double minValue;
  final double maxValue;

  const PortfolioHistoryChartData({
    required this.points,
    required this.minValue,
    required this.maxValue,
  });

  bool get hasEnoughData => points.length >= 2;

  static PortfolioHistoryChartData fromSnapshots(
    List<PortfolioValueSnapshot> snapshots, {
    required PortfolioHistoryRange range,
    required String displayCurrency,
    required DateTime now,
  }) {
    final sorted = List<PortfolioValueSnapshot>.from(snapshots)
      ..sort((a, b) => a.snapshotDate.compareTo(b.snapshotDate));
    final cutoff = range.duration == null
        ? null
        : DateTime(now.year, now.month, now.day).subtract(range.duration!);
    final filtered = cutoff == null
        ? sorted
        : sorted
              .where((s) => !s.snapshotDate.isBefore(cutoff))
              .toList(growable: false);
    final points = filtered
        .map(
          (snapshot) => PortfolioHistoryChartPoint(
            date: snapshot.snapshotDate,
            value: _valueFor(snapshot, displayCurrency),
          ),
        )
        .toList(growable: false);
    if (points.isEmpty) {
      return const PortfolioHistoryChartData(
        points: [],
        minValue: 0,
        maxValue: 0,
      );
    }
    final values = points.map((p) => p.value);
    return PortfolioHistoryChartData(
      points: points,
      minValue: values.reduce((a, b) => a < b ? a : b),
      maxValue: values.reduce((a, b) => a > b ? a : b),
    );
  }

  static double _valueFor(
    PortfolioValueSnapshot snapshot,
    String displayCurrency,
  ) {
    if (displayCurrency == 'USD') return snapshot.valueUsd;
    return CurrencyUtils.fromTry(snapshot.valueTry, displayCurrency);
  }
}
