class CashFlowModel {
  final String id;
  final String portfolioId;
  final String title;
  final double amount;
  final String currency;
  final CashFlowType type;
  final DateTime date;
  final String? note;
  final double? rateAtEntry;

  CashFlowModel({
    required this.id,
    required this.portfolioId,
    required this.title,
    required this.amount,
    required this.currency,
    required this.type,
    required this.date,
    this.note,
    this.rateAtEntry,
  });

  /// İşlem tutarını TRY'ye çevirir — giriş anındaki kuru kullanır.
  double? get amountInTry {
    if (currency == 'TRY') return amount;
    if (rateAtEntry != null && rateAtEntry! > 0) return amount * rateAtEntry!;
    return null;
  }

  factory CashFlowModel.fromJson(Map<String, dynamic> json) {
    return CashFlowModel(
      id: json['id'] as String,
      portfolioId: json['portfolio_id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'TRY',
      type: json['type'] == 'deposit'
          ? CashFlowType.deposit
          : CashFlowType.withdrawal,
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
      rateAtEntry: (json['rate_at_entry'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toInsertJson(String userId) => {
        'portfolio_id': portfolioId,
        'user_id': userId,
        'title': title,
        'amount': amount,
        'currency': currency,
        'type': type == CashFlowType.deposit ? 'deposit' : 'withdrawal',
        'date': date.toIso8601String(),
        'note': note,
        if (rateAtEntry != null) 'rate_at_entry': rateAtEntry,
      };
}

enum CashFlowType { deposit, withdrawal }
