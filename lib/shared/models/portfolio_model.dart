class PortfolioModel {
  final String id;
  final String userId;
  final String name;
  final String emoji;
  final DateTime createdAt;

  PortfolioModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.emoji,
    required this.createdAt,
  });

  factory PortfolioModel.fromJson(Map<String, dynamic> json) {
    return PortfolioModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String? ?? '💼',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'emoji': emoji,
      };
}
