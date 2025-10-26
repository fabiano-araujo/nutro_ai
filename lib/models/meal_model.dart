import 'food_model.dart';

enum MealType {
  breakfast,
  lunch,
  dinner,
  snack,
  freeMeal,
}

class MealTypeOption {
  final MealType type;
  final String name;
  final String emoji;

  const MealTypeOption({
    required this.type,
    required this.name,
    required this.emoji,
  });
}

class Meal {
  final String id;
  final MealType type;
  final List<Food> foods;
  final DateTime dateTime;

  Meal({
    required this.id,
    required this.type,
    required this.foods,
    DateTime? dateTime,
  }) : dateTime = dateTime ?? DateTime.now();

  int get totalCalories => foods.fold(0, (sum, food) => sum + food.calories);

  double get totalProtein => foods.fold(0.0, (sum, food) => sum + food.protein);

  double get totalCarbs => foods.fold(0.0, (sum, food) => sum + food.carbs);

  double get totalFat => foods.fold(0.0, (sum, food) => sum + food.fat);

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'] ?? '',
      type: MealType.values.firstWhere(
        (e) => e.toString() == 'MealType.${json['type']}',
        orElse: () => MealType.freeMeal,
      ),
      foods: (json['foods'] as List<dynamic>?)
              ?.map((foodJson) => Food.fromJson(foodJson))
              .toList() ??
          [],
      dateTime: json['dateTime'] != null
          ? DateTime.parse(json['dateTime'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'foods': foods.map((food) => food.toJson()).toList(),
      'dateTime': dateTime.toIso8601String(),
    };
  }

  Meal copyWith({
    String? id,
    MealType? type,
    List<Food>? foods,
    DateTime? dateTime,
  }) {
    return Meal(
      id: id ?? this.id,
      type: type ?? this.type,
      foods: foods ?? this.foods,
      dateTime: dateTime ?? this.dateTime,
    );
  }
}
