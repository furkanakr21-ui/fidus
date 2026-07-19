class PortfolioModel {
  final String id;
  final String userId;
  final String name;
  final String emoji;
  final bool includeInTotal;
  final DateTime createdAt;

  PortfolioModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.emoji,
    this.includeInTotal = true,
    required this.createdAt,
  });

  factory PortfolioModel.fromJson(Map<String, dynamic> json) {
    return PortfolioModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String? ?? '💼',
      includeInTotal: json['include_in_total'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  PortfolioModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? emoji,
    bool? includeInTotal,
    DateTime? createdAt,
  }) {
    return PortfolioModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      includeInTotal: includeInTotal ?? this.includeInTotal,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'name': name,
    'emoji': emoji,
    'include_in_total': includeInTotal,
  };
}
