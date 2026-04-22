enum AssetType {
  stock,
  crypto,
  currency,
  commodity,
  fund,
  cash,
  realEstate,
}

class AssetModel {
  final String id;
  final String portfolioId;
  final String name;
  final String symbol;
  final AssetType type;
  final double quantity;
  final double buyPrice;
  final double? currentPrice;
  final DateTime buyDate;
  final String? platform;
  final double? commission;
  final String? note;
  final String? apiSource;
  final String? apiId;
  final String currency; // 'TRY' veya 'USD'
  final double? usdToTry;

  AssetModel({
    required this.id,
    required this.portfolioId,
    required this.name,
    required this.symbol,
    required this.type,
    required this.quantity,
    required this.buyPrice,
    this.currentPrice,
    required this.buyDate,
    this.platform,
    this.commission,
    this.note,
    this.apiSource,
    this.apiId,
    this.currency = 'TRY',
    this.usdToTry,
  });

  // Anlık değer — TRY cinsinden
  double get currentValue {
    final price = currentPrice ?? buyPrice;
    if (type == AssetType.currency) return price * quantity;
    if (currency == 'USD') {
      final rate = usdToTry ?? 0;
      if (rate > 0) return price * quantity * rate;
      return buyPrice * quantity;
    }
    return price * quantity;
  }

  // Toplam maliyet — TRY cinsinden
  double get totalCost {
    final baseCost = buyPrice * quantity + (commission ?? 0);
    if (currency == 'USD') {
      final rate = usdToTry ?? 0;
      if (rate > 0) return baseCost * rate;
    }
    return baseCost;
  }

  double get profitLoss => currentValue - totalCost;
  double get profitLossPercent =>
      totalCost == 0 ? 0 : (profitLoss / totalCost) * 100;

  String get currentPriceDisplay {
    final price = currentPrice ?? buyPrice;
    if (type == AssetType.currency) return '₺${price.toStringAsFixed(2)}';
    if (currency == 'USD') return '\$${price.toStringAsFixed(2)}';
    return '₺${price.toStringAsFixed(2)}';
  }

  AssetModel copyWith({
    double? currentPrice,
    double? usdToTry,
    double? quantity,
    double? buyPrice,
    double? commission,
  }) {
    return AssetModel(
      id: id,
      portfolioId: portfolioId,
      name: name,
      symbol: symbol,
      type: type,
      quantity: quantity ?? this.quantity,
      buyPrice: buyPrice ?? this.buyPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      buyDate: buyDate,
      platform: platform,
      commission: commission ?? this.commission,
      note: note,
      apiSource: apiSource,
      apiId: apiId,
      currency: currency,
      usdToTry: usdToTry ?? this.usdToTry,
    );
  }

  static AssetType typeFromString(String? s) {
    return AssetType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => AssetType.stock,
    );
  }

  factory AssetModel.fromJson(Map<String, dynamic> json) {
    return AssetModel(
      id: json['id'] as String,
      portfolioId: json['portfolio_id'] as String,
      name: json['name'] as String,
      symbol: json['symbol'] as String,
      type: typeFromString(json['type'] as String?),
      quantity: (json['quantity'] as num).toDouble(),
      buyPrice: (json['buy_price'] as num).toDouble(),
      buyDate: DateTime.parse(json['buy_date'] as String),
      platform: json['platform'] as String?,
      commission: (json['commission'] as num?)?.toDouble(),
      note: json['note'] as String?,
      apiSource: json['api_source'] as String?,
      apiId: json['api_id'] as String?,
      currency: json['currency'] as String? ?? 'TRY',
    );
  }

  Map<String, dynamic> toInsertJson(String userId) => {
        'portfolio_id': portfolioId,
        'user_id': userId,
        'name': name,
        'symbol': symbol,
        'type': type.name,
        'quantity': quantity,
        'buy_price': buyPrice,
        'buy_date': buyDate.toIso8601String().split('T').first,
        'platform': platform,
        'commission': commission ?? 0,
        'note': note,
        'currency': currency,
        'api_source': apiSource,
        'api_id': apiId,
      };
}
