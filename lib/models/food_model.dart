class Food {
  final String name;
  final String amount;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final String emoji;
  final String? imageUrl;

  Food({
    required this.name,
    required this.amount,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.emoji = '🍽️',
    this.imageUrl,
  });

  factory Food.fromJson(Map<String, dynamic> json) {
    return Food(
      name: json['name'] ?? '',
      amount: json['amount'] ?? '',
      calories: json['calories'] ?? 0,
      protein: (json['protein'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
      emoji: json['emoji'] ?? '🍽️',
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'emoji': emoji,
      'imageUrl': imageUrl,
    };
  }

  Food copyWith({
    String? name,
    String? amount,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    String? emoji,
    String? imageUrl,
  }) {
    return Food(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      emoji: emoji ?? this.emoji,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
