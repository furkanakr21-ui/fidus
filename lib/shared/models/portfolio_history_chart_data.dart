import 'dart:math' as math;

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

class PortfolioHistoryAxisScale {
  final double minY;
  final double maxY;
  final double interval;

  const PortfolioHistoryAxisScale({
    required this.minY,
    required this.maxY,
    required this.interval,
  });

  static PortfolioHistoryAxisScale fromValues(
    double minValue,
    double maxValue,
  ) {
    if (!minValue.isFinite || !maxValue.isFinite) {
      return const PortfolioHistoryAxisScale(minY: 0, maxY: 1, interval: 1);
    }

    final rawRange = maxValue - minValue;
    final baseRange = rawRange == 0
        ? math.max(maxValue.abs() * 0.08, 1)
        : rawRange;
    final paddedMin = rawRange == 0
        ? minValue - (baseRange / 2)
        : minValue - (baseRange * 0.10);
    final paddedMax = rawRange == 0
        ? maxValue + (baseRange / 2)
        : maxValue + (baseRange * 0.10);
    final interval = _niceNumber((paddedMax - paddedMin) / 4);
    final minY = math.max(0, (paddedMin / interval).floor() * interval);
    final maxY = (paddedMax / interval).ceil() * interval;

    return PortfolioHistoryAxisScale(
      minY: minY.toDouble(),
      maxY: maxY <= minY ? minY + interval : maxY.toDouble(),
      interval: interval.toDouble(),
    );
  }

  static double _niceNumber(double value) {
    if (value <= 0 || !value.isFinite) return 1;
    final exponent = math.pow(10, (math.log(value) / math.ln10).floor());
    final fraction = value / exponent;
    final niceFraction = fraction <= 1
        ? 1
        : fraction <= 2.5
        ? 2
        : fraction <= 5
        ? 5
        : 10;
    return (niceFraction * exponent).toDouble();
  }
}

class PortfolioHistoryPeriodChange {
  final double amount;
  final double? percent;

  const PortfolioHistoryPeriodChange({
    required this.amount,
    required this.percent,
  });

  bool get isPositive => amount > 0;
  bool get isNegative => amount < 0;
}

class PortfolioHistoryChartData {
  final List<PortfolioHistoryChartPoint> points;
  final double minValue;
  final double maxValue;
  final PortfolioHistoryAxisScale axis;
  final PortfolioHistoryPeriodChange periodChange;

  const PortfolioHistoryChartData({
    required this.points,
    required this.minValue,
    required this.maxValue,
    required this.axis,
    required this.periodChange,
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
        axis: PortfolioHistoryAxisScale(minY: 0, maxY: 1, interval: 1),
        periodChange: PortfolioHistoryPeriodChange(amount: 0, percent: null),
      );
    }
    final values = points.map((p) => p.value);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final firstValue = points.first.value;
    final lastValue = points.last.value;
    final changeAmount = lastValue - firstValue;
    return PortfolioHistoryChartData(
      points: points,
      minValue: minValue,
      maxValue: maxValue,
      axis: PortfolioHistoryAxisScale.fromValues(minValue, maxValue),
      periodChange: PortfolioHistoryPeriodChange(
        amount: changeAmount,
        percent: firstValue == 0 ? null : (changeAmount / firstValue) * 100,
      ),
    );
  }

  static double _valueFor(
    PortfolioValueSnapshot snapshot,
    String displayCurrency,
  ) {
    if (displayCurrency == 'USD') return snapshot.valueUsd;
    return CurrencyUtils.fromTry(snapshot.valueTry, displayCurrency);
  }

  String formatCompactMoney(double value, String displayCurrency) {
    final sign = value < 0 ? '-' : '';
    final abs = value.abs();
    final prefix = CurrencyUtils.symbol(displayCurrency);
    if (abs >= 1000000000) {
      return '$sign$prefix${_compactNumber(abs / 1000000000)}B';
    }
    if (abs >= 1000000) {
      return '$sign$prefix${_compactNumber(abs / 1000000)}M';
    }
    if (abs >= 1000) {
      return '$sign$prefix${_compactNumber(abs / 1000)}K';
    }
    return '$sign$prefix${abs.round()}';
  }

  String formatSignedMoney(double value, String displayCurrency) {
    final sign = value >= 0 ? '+' : '-';
    return '$sign${CurrencyUtils.symbol(displayCurrency)}'
        '${CurrencyUtils.formatRaw(value.abs())}';
  }

  static String _compactNumber(double value) {
    final formatted = value >= 10
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return formatted.endsWith('.0')
        ? formatted.substring(0, formatted.length - 2)
        : formatted;
  }
}
