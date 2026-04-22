class TransactionModel {
  final String id;
  final String assetId;
  final TransactionType type;
  final double quantity;
  final double price;
  final double? commission;
  final DateTime date;
  final String? note;
  final String symbol;
  final String assetName;

  TransactionModel({
    required this.id,
    required this.assetId,
    required this.type,
    required this.quantity,
    required this.price,
    this.commission,
    required this.date,
    this.note,
    required this.symbol,
    required this.assetName,
  });

  double get total => (price * quantity) + (commission ?? 0);

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      assetId: json['asset_id'] as String,
      type: json['type'] == 'buy' ? TransactionType.buy : TransactionType.sell,
      quantity: (json['quantity'] as num).toDouble(),
      price: (json['price'] as num).toDouble(),
      commission: (json['commission'] as num?)?.toDouble(),
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
      symbol: json['symbol'] as String,
      assetName: json['asset_name'] as String,
    );
  }

  Map<String, dynamic> toInsertJson(String userId) => {
        'asset_id': assetId,
        'user_id': userId,
        'type': type == TransactionType.buy ? 'buy' : 'sell',
        'quantity': quantity,
        'price': price,
        'commission': commission ?? 0,
        'note': note,
        'symbol': symbol,
        'asset_name': assetName,
        'date': date.toIso8601String(),
      };
}

enum TransactionType { buy, sell }
