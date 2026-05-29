class PortfolioAssetValueSnapshot {
  final String id;
  final String userId;
  final String portfolioId;
  final DateTime snapshotDate;
  final String symbol;
  final String name;
  final String type;
  final String? apiSource;
  final String? apiId;
  final double quantity;
  final double valueTry;
  final double valueUsd;
  final double usdTryRate;
  final DateTime? fxRatesUpdatedAt;
  final int assetRowCount;
  final DateTime capturedAt;
  final DateTime createdAt;

  const PortfolioAssetValueSnapshot({
    required this.id,
    required this.userId,
    required this.portfolioId,
    required this.snapshotDate,
    required this.symbol,
    required this.name,
    required this.type,
    this.apiSource,
    this.apiId,
    required this.quantity,
    required this.valueTry,
    required this.valueUsd,
    required this.usdTryRate,
    this.fxRatesUpdatedAt,
    required this.assetRowCount,
    required this.capturedAt,
    required this.createdAt,
  });

  factory PortfolioAssetValueSnapshot.fromJson(Map<String, dynamic> json) {
    return PortfolioAssetValueSnapshot(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      portfolioId: json['portfolio_id'] as String,
      snapshotDate: DateTime.parse(json['snapshot_date'] as String),
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      apiSource: json['api_source'] as String?,
      apiId: json['api_id'] as String?,
      quantity: (json['quantity'] as num).toDouble(),
      valueTry: (json['value_try'] as num).toDouble(),
      valueUsd: (json['value_usd'] as num).toDouble(),
      usdTryRate: (json['usd_try_rate'] as num).toDouble(),
      fxRatesUpdatedAt: json['fx_rates_updated_at'] == null
          ? null
          : DateTime.parse(json['fx_rates_updated_at'] as String),
      assetRowCount: (json['asset_row_count'] as num).toInt(),
      capturedAt: DateTime.parse(json['captured_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
