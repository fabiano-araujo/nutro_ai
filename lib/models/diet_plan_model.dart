import 'dart:convert';

class DietPlan {
  final String date;
  final DailyNutrition totalNutrition;
  final List<PlannedMeal> meals;

  DietPlan({
    required this.date,
    required this.totalNutrition,
    required this.meals,
  });

  factory DietPlan.fromJson(Map<String, dynamic> json) {
    return DietPlan(
      date: json['date'] ?? DateTime.now().toIso8601String().split('T')[0],
      totalNutrition: DailyNutrition.fromJson(json['totalNutrition'] ?? {}),
      meals: (json['meals'] as List<dynamic>?)
              ?.map((meal) => PlannedMeal.fromJson(meal))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'totalNutrition': totalNutrition.toJson(),
      'meals': meals.map((meal) => meal.toJson()).toList(),
    };
  }

  DietPlan copyWith({
    String? date,
    DailyNutrition? totalNutrition,
    List<PlannedMeal>? meals,
  }) {
    return DietPlan(
      date: date ?? this.date,
      totalNutrition: totalNutrition ?? this.totalNutrition,
      meals: meals ?? this.meals,
    );
  }
}

class DailyNutrition {
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  DailyNutrition({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory DailyNutrition.fromJson(Map<String, dynamic> json) {
    return DailyNutrition(
      calories: (json['calories'] ?? 0).toInt(),
      protein: (json['protein'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }
}

class PlannedMeal {
  final String type; // breakfast, lunch, dinner, snack
  final String time; // HH:MM format
  final String name;
  final List<PlannedFood> foods;
  final DailyNutrition mealTotals;

  PlannedMeal({
    required this.type,
    required this.time,
    required this.name,
    required this.foods,
    required this.mealTotals,
  });

  factory PlannedMeal.fromJson(Map<String, dynamic> json) {
    return PlannedMeal(
      type: json['type'] ?? 'snack',
      time: json['time'] ?? '12:00',
      name: json['name'] ?? 'Refeição',
      foods: (json['foods'] as List<dynamic>?)
              ?.map((food) => PlannedFood.fromJson(food))
              .toList() ??
          [],
      mealTotals: DailyNutrition.fromJson(json['mealTotals'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'time': time,
      'name': name,
      'foods': foods.map((food) => food.toJson()).toList(),
      'mealTotals': mealTotals.toJson(),
    };
  }

  PlannedMeal copyWith({
    String? type,
    String? time,
    String? name,
    List<PlannedFood>? foods,
    DailyNutrition? mealTotals,
  }) {
    return PlannedMeal(
      type: type ?? this.type,
      time: time ?? this.time,
      name: name ?? this.name,
      foods: foods ?? this.foods,
      mealTotals: mealTotals ?? this.mealTotals,
    );
  }
}

class PlannedFood {
  final String name;
  final String emoji;
  final double amount;
  final String unit; // g, ml, unidade
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  PlannedFood({
    required this.name,
    required this.emoji,
    required this.amount,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory PlannedFood.fromJson(Map<String, dynamic> json) {
    return PlannedFood(
      name: json['name'] ?? 'Alimento',
      emoji: json['emoji'] ?? '🍽️',
      amount: (json['amount'] ?? 0).toDouble(),
      unit: json['unit'] ?? 'g',
      calories: (json['calories'] ?? 0).toInt(),
      protein: (json['protein'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'emoji': emoji,
      'amount': amount,
      'unit': unit,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }
}

class DietPreferences {
  final int mealsPerDay; // 3-6
  final String hungriestMealTime; // breakfast, lunch, dinner, snack
  final List<String> foodRestrictions;
  final List<String> favoriteFoods;

  DietPreferences({
    this.mealsPerDay = 3,
    this.hungriestMealTime = 'lunch',
    this.foodRestrictions = const [],
    this.favoriteFoods = const [],
  });

  factory DietPreferences.fromJson(Map<String, dynamic> json) {
    return DietPreferences(
      mealsPerDay: json['mealsPerDay'] ?? 3,
      hungriestMealTime: json['hungriestMealTime'] ?? 'lunch',
      foodRestrictions: (json['foodRestrictions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      favoriteFoods: (json['favoriteFoods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mealsPerDay': mealsPerDay,
      'hungriestMealTime': hungriestMealTime,
      'foodRestrictions': foodRestrictions,
      'favoriteFoods': favoriteFoods,
    };
  }

  DietPreferences copyWith({
    int? mealsPerDay,
    String? hungriestMealTime,
    List<String>? foodRestrictions,
    List<String>? favoriteFoods,
  }) {
    return DietPreferences(
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      hungriestMealTime: hungriestMealTime ?? this.hungriestMealTime,
      foodRestrictions: foodRestrictions ?? this.foodRestrictions,
      favoriteFoods: favoriteFoods ?? this.favoriteFoods,
    );
  }
}
