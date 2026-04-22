class GoalModel {
  final String id;
  final String portfolioId;
  final String title;
  final String emoji;
  final GoalType type;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final String currency;
  final String? note;

  GoalModel({
    required this.id,
    required this.portfolioId,
    required this.title,
    required this.emoji,
    required this.type,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    required this.currency,
    this.note,
  });

  double get progressPercent => (currentAmount / targetAmount) * 100;
  double get remaining => targetAmount - currentAmount;
  bool get isCompleted => currentAmount >= targetAmount;

  static GoalType _typeFromString(String? s) {
    switch (s) {
      case 'retirement':
        return GoalType.retirement;
      case 'savings':
        return GoalType.savings;
      case 'portfolio':
        return GoalType.portfolio;
      default:
        return GoalType.other;
    }
  }

  static String _typeToString(GoalType t) {
    switch (t) {
      case GoalType.retirement:
        return 'retirement';
      case GoalType.savings:
        return 'savings';
      case GoalType.portfolio:
        return 'portfolio';
      case GoalType.other:
        return 'other';
    }
  }

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'] as String,
      portfolioId: json['portfolio_id'] as String,
      title: json['title'] as String,
      emoji: json['emoji'] as String? ?? '🎯',
      type: _typeFromString(json['type'] as String?),
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num? ?? 0).toDouble(),
      targetDate: json['target_date'] != null
          ? DateTime.parse(json['target_date'] as String)
          : null,
      currency: json['currency'] as String? ?? 'TRY',
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson(String userId) => {
        'portfolio_id': portfolioId,
        'user_id': userId,
        'title': title,
        'emoji': emoji,
        'type': _typeToString(type),
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        'target_date': targetDate?.toIso8601String().split('T').first,
        'currency': currency,
        'note': note,
      };

  GoalModel copyWith({double? currentAmount}) => GoalModel(
        id: id,
        portfolioId: portfolioId,
        title: title,
        emoji: emoji,
        type: type,
        targetAmount: targetAmount,
        currentAmount: currentAmount ?? this.currentAmount,
        targetDate: targetDate,
        currency: currency,
        note: note,
      );
}

enum GoalType { retirement, savings, portfolio, other }
