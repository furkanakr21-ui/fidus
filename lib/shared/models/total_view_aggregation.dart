import '../../core/constants/app_constants.dart';
import 'portfolio_asset_value_snapshot_model.dart';
import 'portfolio_model.dart';
import 'portfolio_value_snapshot_model.dart';

const Duration _turkeyUtcOffset = Duration(hours: 3);

PortfolioValueSnapshot? aggregateTodaySnapshots(
  List<PortfolioValueSnapshot> rows, {
  required List<PortfolioModel> includedPortfolios,
}) {
  if (rows.isEmpty || includedPortfolios.isEmpty) return null;

  final snapshotDate = _dateOnly(rows.first.snapshotDate);
  if (rows.any((row) => _dateOnly(row.snapshotDate) != snapshotDate)) {
    return null;
  }

  return _aggregateSnapshotGroup(
    rows,
    snapshotDate: snapshotDate,
    includedPortfolios: includedPortfolios,
  );
}

List<PortfolioValueSnapshot> aggregateSnapshotHistory(
  List<PortfolioValueSnapshot> rows, {
  required List<PortfolioModel> includedPortfolios,
}) {
  if (rows.isEmpty || includedPortfolios.isEmpty) return const [];

  final grouped = <DateTime, List<PortfolioValueSnapshot>>{};
  for (final row in rows) {
    final date = _dateOnly(row.snapshotDate);
    grouped.putIfAbsent(date, () => []).add(row);
  }

  final dates = grouped.keys.toList()..sort();
  return dates
      .map(
        (date) => _aggregateSnapshotGroup(
          grouped[date]!,
          snapshotDate: date,
          includedPortfolios: includedPortfolios,
        ),
      )
      .whereType<PortfolioValueSnapshot>()
      .toList(growable: false);
}

Map<String, PortfolioAssetValueSnapshot> aggregateAssetSnapshotsBySymbol(
  List<PortfolioAssetValueSnapshot> rows,
) {
  if (rows.isEmpty) return const {};

  final grouped = <String, List<PortfolioAssetValueSnapshot>>{};
  for (final row in rows) {
    grouped.putIfAbsent(row.symbol, () => []).add(row);
  }

  return {
    for (final entry in grouped.entries)
      entry.key: _aggregateAssetSnapshotGroup(entry.value),
  };
}

PortfolioValueSnapshot? _aggregateSnapshotGroup(
  List<PortfolioValueSnapshot> rows, {
  required DateTime snapshotDate,
  required List<PortfolioModel> includedPortfolios,
}) {
  final eligiblePortfolioIds = _eligiblePortfolioIds(
    includedPortfolios,
    rows,
    snapshotDate,
  );
  if (eligiblePortfolioIds.isEmpty) return null;

  final eligibleRows = rows
      .where((row) => eligiblePortfolioIds.contains(row.portfolioId))
      .toList(growable: false);
  final rowCounts = <String, int>{};
  for (final row in eligibleRows) {
    rowCounts.update(row.portfolioId, (count) => count + 1, ifAbsent: () => 1);
  }
  final hasCompleteCoverage = eligiblePortfolioIds.every(
    (portfolioId) => rowCounts[portfolioId] == 1,
  );
  if (!hasCompleteCoverage || eligibleRows.isEmpty) return null;

  final first = eligibleRows.first;
  if (eligibleRows.any((row) => row.userId != first.userId)) return null;

  return PortfolioValueSnapshot(
    id: 'total-${_dateKey(snapshotDate)}',
    userId: first.userId,
    portfolioId: kTotalPortfolioId,
    snapshotDate: snapshotDate,
    valueTry: eligibleRows.fold(0, (sum, row) => sum + row.valueTry),
    valueUsd: eligibleRows.fold(0, (sum, row) => sum + row.valueUsd),
    usdTryRate: first.usdTryRate,
    fxRatesUpdatedAt: _latestNullableDate(
      eligibleRows.map((row) => row.fxRatesUpdatedAt),
    ),
    assetCount: eligibleRows.fold(0, (sum, row) => sum + row.assetCount),
    capturedAt: _latestDate(eligibleRows.map((row) => row.capturedAt)),
    createdAt: _latestDate(eligibleRows.map((row) => row.createdAt)),
  );
}

Set<String> _eligiblePortfolioIds(
  List<PortfolioModel> portfolios,
  List<PortfolioValueSnapshot> rows,
  DateTime snapshotDate,
) {
  final capturesOnSnapshotDate = rows
      .where((row) => _dateInTurkey(row.capturedAt) == snapshotDate)
      .map((row) => row.capturedAt.toUtc());
  final captureCutoff = capturesOnSnapshotDate.isEmpty
      ? null
      : _earliestDate(capturesOnSnapshotDate);

  return {
    for (final portfolio in portfolios)
      if (_portfolioExistedAtSnapshot(portfolio, snapshotDate, captureCutoff))
        portfolio.id,
  };
}

bool _portfolioExistedAtSnapshot(
  PortfolioModel portfolio,
  DateTime snapshotDate,
  DateTime? captureCutoff,
) {
  final createdDate = _dateInTurkey(portfolio.createdAt);
  if (createdDate.isBefore(snapshotDate)) return true;
  if (createdDate.isAfter(snapshotDate)) return false;
  return captureCutoff == null ||
      !portfolio.createdAt.toUtc().isAfter(captureCutoff);
}

PortfolioAssetValueSnapshot _aggregateAssetSnapshotGroup(
  List<PortfolioAssetValueSnapshot> rows,
) {
  final first = rows.first;
  return PortfolioAssetValueSnapshot(
    id: 'total-${_dateKey(first.snapshotDate)}-${first.symbol}',
    userId: first.userId,
    portfolioId: kTotalPortfolioId,
    snapshotDate: _dateOnly(first.snapshotDate),
    symbol: first.symbol,
    name: first.name,
    type: first.type,
    apiSource: first.apiSource,
    apiId: first.apiId,
    quantity: rows.fold(0, (sum, row) => sum + row.quantity),
    valueTry: rows.fold(0, (sum, row) => sum + row.valueTry),
    valueUsd: rows.fold(0, (sum, row) => sum + row.valueUsd),
    usdTryRate: first.usdTryRate,
    fxRatesUpdatedAt: _latestNullableDate(
      rows.map((row) => row.fxRatesUpdatedAt),
    ),
    assetRowCount: rows.fold(0, (sum, row) => sum + row.assetRowCount),
    capturedAt: _latestDate(rows.map((row) => row.capturedAt)),
    createdAt: _latestDate(rows.map((row) => row.createdAt)),
  );
}

DateTime _dateInTurkey(DateTime value) {
  return _dateOnly(value.toUtc().add(_turkeyUtcOffset));
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String _dateKey(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime _latestDate(Iterable<DateTime> values) {
  return values.reduce(
    (latest, value) => value.isAfter(latest) ? value : latest,
  );
}

DateTime _earliestDate(Iterable<DateTime> values) {
  return values.reduce(
    (earliest, value) => value.isBefore(earliest) ? value : earliest,
  );
}

DateTime? _latestNullableDate(Iterable<DateTime?> values) {
  DateTime? latest;
  for (final value in values) {
    if (value != null && (latest == null || value.isAfter(latest))) {
      latest = value;
    }
  }
  return latest;
}
