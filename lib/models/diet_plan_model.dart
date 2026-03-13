/// Modo de dieta: diária (cada dia diferente) ou semanal única (mesma dieta todos os dias)
enum DietMode {
  daily, // Cada dia tem refeições diferentes
  weekly, // Uma única dieta para toda a semana
}

String? _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null) {
      return value.toString();
    }
  }
  return null;
}

String _normalizeFoodName(String value) {
  const replacements = {
    'á': 'a',
    'à': 'a',
    'ã': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'õ': 'o',
    'ô': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
  };

  var normalized = value.toLowerCase();
  replacements.forEach((from, to) {
    normalized = normalized.replaceAll(from, to);
  });
  return normalized;
}

String resolveFoodEmoji(String name, {String? preferred}) {
  if (preferred != null &&
      preferred.trim().isNotEmpty &&
      preferred.trim() != '🍽️') {
    return preferred.trim();
  }

  final normalized = _normalizeFoodName(name);
  const emojiMatchers = <MapEntry<List<String>, String>>[
    MapEntry(['ovo', 'omelete'], '🍳'),
    MapEntry(['frango', 'sobrecoxa', 'peito de frango'], '🍗'),
    MapEntry(['carne', 'bife', 'alcatra', 'patinho', 'picanha'], '🥩'),
    MapEntry(['hamburguer', 'burger'], '🍔'),
    MapEntry(
        ['peixe', 'salmao', 'atum', 'tilapia', 'sardinha', 'bacalhau'], '🐟'),
    MapEntry(['camarao', 'lula', 'polvo', 'marisco'], '🍤'),
    MapEntry(['porco', 'bacon', 'presunto', 'linguica', 'salsicha'], '🥓'),
    MapEntry(['arroz', 'risoto'], '🍚'),
    MapEntry(['feijao', 'lentilha', 'grao-de-bico', 'grao de bico'], '🫘'),
    MapEntry(['macarrao', 'massa', 'espaguete', 'lasanha', 'nhoque', 'ravioli'],
        '🍝'),
    MapEntry(['pizza'], '🍕'),
    MapEntry(
        ['pao', 'torrada', 'croissant', 'bagel', 'sanduiche', 'toast'], '🥖'),
    MapEntry(['queijo', 'mussarela', 'muçarela', 'parmesao', 'ricota'], '🧀'),
    MapEntry(['leite', 'iogurte', 'coalhada'], '🥛'),
    MapEntry(['cafe', 'capuccino', 'espresso'], '☕'),
    MapEntry(['cha', 'tea'], '🫖'),
    MapEntry(['suco', 'juice', 'vitamina'], '🧃'),
    MapEntry(['agua', 'water'], '💧'),
    MapEntry(['banana'], '🍌'),
    MapEntry(['maca', 'maçã'], '🍎'),
    MapEntry(['laranja', 'tangerina', 'mexerica'], '🍊'),
    MapEntry(['uva'], '🍇'),
    MapEntry(['morango'], '🍓'),
    MapEntry(['abacaxi'], '🍍'),
    MapEntry(['mamao', 'mamão'], '🥭'),
    MapEntry(['manga'], '🥭'),
    MapEntry(['abacate'], '🥑'),
    MapEntry(['tomate'], '🍅'),
    MapEntry(['alface', 'salada', 'couve', 'espinafre', 'brocolis', 'brócolis'],
        '🥗'),
    MapEntry(['batata', 'mandioca', 'inhame'], '🥔'),
    MapEntry(['batata doce'], '🍠'),
    MapEntry(['cenoura'], '🥕'),
    MapEntry(['milho', 'cuscuz'], '🌽'),
    MapEntry(['sopa', 'caldo'], '🍲'),
    MapEntry(['bolo', 'torta', 'cupcake'], '🍰'),
    MapEntry(['biscoito', 'bolacha', 'cookie'], '🍪'),
    MapEntry(['chocolate', 'cacau', 'brigadeiro'], '🍫'),
    MapEntry(['castanha', 'amendoim', 'noz', 'nuts'], '🥜'),
    MapEntry(['sushi'], '🍣'),
  ];

  for (final entry in emojiMatchers) {
    if (entry.key.any(normalized.contains)) {
      return entry.value;
    }
  }

  return '🍽️';
}

double _readDouble(Map<String, dynamic> json, List<String> keys,
    [double fallback = 0]) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return fallback;
}

int _readInt(Map<String, dynamic> json, List<String> keys, [int fallback = 0]) {
  return _readDouble(json, keys, fallback.toDouble()).round();
}

DailyNutrition _sumFoods(List<PlannedFood> foods) {
  var calories = 0;
  var protein = 0.0;
  var carbs = 0.0;
  var fat = 0.0;

  for (final food in foods) {
    calories += food.calories;
    protein += food.protein;
    carbs += food.carbs;
    fat += food.fat;
  }

  return DailyNutrition(
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
  );
}

DailyNutrition _sumMeals(List<PlannedMeal> meals) {
  var calories = 0;
  var protein = 0.0;
  var carbs = 0.0;
  var fat = 0.0;

  for (final meal in meals) {
    calories += meal.mealTotals.calories;
    protein += meal.mealTotals.protein;
    carbs += meal.mealTotals.carbs;
    fat += meal.mealTotals.fat;
  }

  return DailyNutrition(
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
  );
}

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

  factory DietPlan.fromAiJson(
    Map<String, dynamic> json, {
    required String date,
    Map<String, String> mealNames = const {},
  }) {
    if (json.containsKey('m')) {
      final meals = (json['m'] as List<dynamic>? ?? const [])
          .map((meal) => PlannedMeal.fromAiJson(meal, mealNames: mealNames))
          .toList();

      return DietPlan(
        date: date,
        totalNutrition: _sumMeals(meals),
        meals: meals,
      );
    }

    final plan = DietPlan.fromJson(json);
    final totalNutrition = plan.totalNutrition.calories == 0 &&
            plan.totalNutrition.protein == 0 &&
            plan.totalNutrition.carbs == 0 &&
            plan.totalNutrition.fat == 0
        ? _sumMeals(plan.meals)
        : plan.totalNutrition;

    return plan.copyWith(
      date: date,
      totalNutrition: totalNutrition,
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

  factory PlannedMeal.fromAiJson(
    dynamic raw, {
    Map<String, String> mealNames = const {},
    String? fallbackType,
    String? fallbackTime,
    String? fallbackName,
  }) {
    if (raw is List<dynamic>) {
      final type = raw.isNotEmpty ? raw[0].toString() : fallbackType ?? 'snack';
      final time = raw.length > 1 ? raw[1].toString() : fallbackTime ?? '12:00';
      final foods = (raw.length > 2 && raw[2] is List
              ? raw[2] as List<dynamic>
              : const <dynamic>[])
          .map(PlannedFood.fromAiJson)
          .toList();

      return PlannedMeal(
        type: type,
        time: time,
        name: fallbackName ?? mealNames[type] ?? type,
        foods: foods,
        mealTotals: _sumFoods(foods),
      );
    }

    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Formato de refeição inválido');
    }

    if (raw.containsKey('foods') || raw.containsKey('mealTotals')) {
      final meal = PlannedMeal.fromJson(raw);
      final totals = meal.mealTotals.calories == 0 &&
              meal.mealTotals.protein == 0 &&
              meal.mealTotals.carbs == 0 &&
              meal.mealTotals.fat == 0
          ? _sumFoods(meal.foods)
          : meal.mealTotals;
      return meal.copyWith(mealTotals: totals);
    }

    final type = _readString(raw, ['t']) ?? fallbackType ?? 'snack';
    final time = _readString(raw, ['h']) ?? fallbackTime ?? '12:00';
    final foods = (raw['f'] as List<dynamic>? ?? const [])
        .map(PlannedFood.fromAiJson)
        .toList();

    return PlannedMeal(
      type: type,
      time: time,
      name: fallbackName ?? mealNames[type] ?? type,
      foods: foods,
      mealTotals: _sumFoods(foods),
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
    final name = json['name'] ?? 'Alimento';
    return PlannedFood(
      name: name,
      emoji: resolveFoodEmoji(name, preferred: json['emoji']?.toString()),
      amount: (json['amount'] ?? 0).toDouble(),
      unit: json['unit'] ?? 'g',
      calories: (json['calories'] ?? 0).toInt(),
      protein: (json['protein'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
    );
  }

  factory PlannedFood.fromAiJson(dynamic raw) {
    if (raw is List<dynamic>) {
      final name = raw.isNotEmpty ? raw[0].toString() : 'Alimento';
      return PlannedFood(
        name: name,
        emoji: resolveFoodEmoji(name),
        amount: raw.length > 1 && raw[1] is num
            ? (raw[1] as num).toDouble()
            : double.tryParse(raw.length > 1 ? raw[1].toString() : '') ?? 0,
        unit: raw.length > 2 ? raw[2].toString() : 'g',
        calories: raw.length > 3 && raw[3] is num
            ? (raw[3] as num).round()
            : int.tryParse(raw.length > 3 ? raw[3].toString() : '') ?? 0,
        protein: raw.length > 4 && raw[4] is num
            ? (raw[4] as num).toDouble()
            : double.tryParse(raw.length > 4 ? raw[4].toString() : '') ?? 0,
        carbs: raw.length > 5 && raw[5] is num
            ? (raw[5] as num).toDouble()
            : double.tryParse(raw.length > 5 ? raw[5].toString() : '') ?? 0,
        fat: raw.length > 6 && raw[6] is num
            ? (raw[6] as num).toDouble()
            : double.tryParse(raw.length > 6 ? raw[6].toString() : '') ?? 0,
      );
    }

    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Formato de alimento inválido');
    }

    if (raw.containsKey('name')) {
      return PlannedFood.fromJson(raw);
    }

    return PlannedFood(
      name: _readString(raw, ['n']) ?? 'Alimento',
      emoji: resolveFoodEmoji(
        _readString(raw, ['n']) ?? 'Alimento',
        preferred: _readString(raw, ['e']),
      ),
      amount: _readDouble(raw, ['a']),
      unit: _readString(raw, ['u']) ?? 'g',
      calories: _readInt(raw, ['k']),
      protein: _readDouble(raw, ['p']),
      carbs: _readDouble(raw, ['c']),
      fat: _readDouble(raw, ['g']),
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
  final List<String> avoidedFoods;
  final List<String> routineConsiderations;
  final bool hasReviewedRestrictions;
  final bool hasReviewedFoodPreferences;
  final bool hasReviewedRoutineNeeds;
  final DietMode dietMode; // daily ou weekly

  DietPreferences({
    this.mealsPerDay = 3,
    this.hungriestMealTime = 'lunch',
    this.foodRestrictions = const [],
    this.favoriteFoods = const [],
    this.avoidedFoods = const [],
    this.routineConsiderations = const [],
    this.hasReviewedRestrictions = false,
    this.hasReviewedFoodPreferences = false,
    this.hasReviewedRoutineNeeds = false,
    this.dietMode = DietMode.weekly, // Padrão: dieta semanal única
  });

  factory DietPreferences.fromJson(Map<String, dynamic> json) {
    final restrictions = (json['foodRestrictions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final favorites = (json['favoriteFoods'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final avoided = (json['avoidedFoods'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final routine = (json['routineConsiderations'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return DietPreferences(
      mealsPerDay: json['mealsPerDay'] ?? 3,
      hungriestMealTime: json['hungriestMealTime'] ?? 'lunch',
      foodRestrictions: restrictions,
      favoriteFoods: favorites,
      avoidedFoods: avoided,
      routineConsiderations: routine,
      hasReviewedRestrictions:
          json['hasReviewedRestrictions'] ?? restrictions.isNotEmpty,
      hasReviewedFoodPreferences: json['hasReviewedFoodPreferences'] ??
          (favorites.isNotEmpty || avoided.isNotEmpty),
      hasReviewedRoutineNeeds:
          json['hasReviewedRoutineNeeds'] ?? routine.isNotEmpty,
      dietMode: DietMode.values.firstWhere(
        (e) => e.name == json['dietMode'],
        orElse: () => DietMode.weekly,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mealsPerDay': mealsPerDay,
      'hungriestMealTime': hungriestMealTime,
      'foodRestrictions': foodRestrictions,
      'favoriteFoods': favoriteFoods,
      'avoidedFoods': avoidedFoods,
      'routineConsiderations': routineConsiderations,
      'hasReviewedRestrictions': hasReviewedRestrictions,
      'hasReviewedFoodPreferences': hasReviewedFoodPreferences,
      'hasReviewedRoutineNeeds': hasReviewedRoutineNeeds,
      'dietMode': dietMode.name,
    };
  }

  DietPreferences copyWith({
    int? mealsPerDay,
    String? hungriestMealTime,
    List<String>? foodRestrictions,
    List<String>? favoriteFoods,
    List<String>? avoidedFoods,
    List<String>? routineConsiderations,
    bool? hasReviewedRestrictions,
    bool? hasReviewedFoodPreferences,
    bool? hasReviewedRoutineNeeds,
    DietMode? dietMode,
  }) {
    return DietPreferences(
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      hungriestMealTime: hungriestMealTime ?? this.hungriestMealTime,
      foodRestrictions: foodRestrictions ?? this.foodRestrictions,
      favoriteFoods: favoriteFoods ?? this.favoriteFoods,
      avoidedFoods: avoidedFoods ?? this.avoidedFoods,
      routineConsiderations:
          routineConsiderations ?? this.routineConsiderations,
      hasReviewedRestrictions:
          hasReviewedRestrictions ?? this.hasReviewedRestrictions,
      hasReviewedFoodPreferences:
          hasReviewedFoodPreferences ?? this.hasReviewedFoodPreferences,
      hasReviewedRoutineNeeds:
          hasReviewedRoutineNeeds ?? this.hasReviewedRoutineNeeds,
      dietMode: dietMode ?? this.dietMode,
    );
  }
}
