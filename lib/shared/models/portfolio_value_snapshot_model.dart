class PortfolioValueSnapshot {
  final String id;
  final String userId;
  final String portfolioId;
  final DateTime snapshotDate;
  final double valueTry;
  final double valueUsd;
  final double usdTryRate;
  final DateTime? fxRatesUpdatedAt;
  final int assetCount;
  final DateTime capturedAt;
  final DateTime createdAt;

  const PortfolioValueSnapshot({
    required this.id,
    required this.userId,
    required this.portfolioId,
    required this.snapshotDate,
    required this.valueTry,
    required this.valueUsd,
    required this.usdTryRate,
    this.fxRatesUpdatedAt,
    required this.assetCount,
    required this.capturedAt,
    required this.createdAt,
  });

  factory PortfolioValueSnapshot.fromJson(Map<String, dynamic> json) {
    return PortfolioValueSnapshot(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      portfolioId: json['portfolio_id'] as String,
      snapshotDate: DateTime.parse(json['snapshot_date'] as String),
      valueTry: (json['value_try'] as num).toDouble(),
      valueUsd: (json['value_usd'] as num).toDouble(),
      usdTryRate: (json['usd_try_rate'] as num).toDouble(),
      fxRatesUpdatedAt: json['fx_rates_updated_at'] == null
          ? null
          : DateTime.parse(json['fx_rates_updated_at'] as String),
      assetCount: (json['asset_count'] as num).toInt(),
      capturedAt: DateTime.parse(json['captured_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
