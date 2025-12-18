import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/meal_model.dart';
import '../models/food_model.dart';
import '../models/Nutrient.dart';

class DailyMealsProvider extends ChangeNotifier {
  DateTime _selectedDate = DateTime.now();
  final Map<String, List<Meal>> _mealsByDate = {};
  bool _isLoaded = false;

  // Goals (can be customized by user later)
  int caloriesGoal = 2000;
  int proteinGoal = 150;
  int carbsGoal = 250;
  int fatsGoal = 67;

  DailyMealsProvider() {
    _loadFromPreferences();
  }

  DateTime get selectedDate => _selectedDate;

  List<Meal> get todayMeals {
    final dateKey = _formatDate(_selectedDate);
    return _mealsByDate[dateKey] ?? [];
  }

  // Get meals by type
  Meal? getMealByType(MealType type) {
    return todayMeals.firstWhere(
      (meal) => meal.type == type,
      orElse: () => Meal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        foods: [],
      ),
    );
  }

  // Daily totals
  int get totalCalories => todayMeals.fold(0, (sum, meal) => sum + meal.totalCalories);
  double get totalProtein => todayMeals.fold(0.0, (sum, meal) => sum + meal.totalProtein);
  double get totalCarbs => todayMeals.fold(0.0, (sum, meal) => sum + meal.totalCarbs);
  double get totalFat => todayMeals.fold(0.0, (sum, meal) => sum + meal.totalFat);

  // Remaining values
  int get caloriesRemaining => caloriesGoal - totalCalories;
  int get proteinRemaining => proteinGoal - totalProtein.toInt();
  int get carbsRemaining => carbsGoal - totalCarbs.toInt();
  int get fatsRemaining => fatsGoal - totalFat.toInt();

  // Load meals from SharedPreferences
  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load meals by date
      final mealsJson = prefs.getString('daily_meals');
      if (mealsJson != null) {
        final Map<String, dynamic> decodedMap = jsonDecode(mealsJson);
        _mealsByDate.clear();

        decodedMap.forEach((dateKey, mealsListJson) {
          final List<dynamic> mealsList = mealsListJson as List<dynamic>;
          _mealsByDate[dateKey] = mealsList
              .map((mealJson) => Meal.fromJson(mealJson as Map<String, dynamic>))
              .toList();
        });
      }

      // Load goals
      caloriesGoal = prefs.getInt('meals_calories_goal') ?? 2000;
      proteinGoal = prefs.getInt('meals_protein_goal') ?? 150;
      carbsGoal = prefs.getInt('meals_carbs_goal') ?? 250;
      fatsGoal = prefs.getInt('meals_fats_goal') ?? 67;

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      print('Error loading daily meals: $e');
      _isLoaded = true;
    }
  }

  // Save meals to SharedPreferences
  Future<void> _saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert meals map to JSON
      final Map<String, dynamic> mealsToSave = {};
      _mealsByDate.forEach((dateKey, mealsList) {
        mealsToSave[dateKey] = mealsList.map((meal) => meal.toJson()).toList();
      });

      await prefs.setString('daily_meals', jsonEncode(mealsToSave));

      // Save goals
      await prefs.setInt('meals_calories_goal', caloriesGoal);
      await prefs.setInt('meals_protein_goal', proteinGoal);
      await prefs.setInt('meals_carbs_goal', carbsGoal);
      await prefs.setInt('meals_fats_goal', fatsGoal);
    } catch (e) {
      print('Error saving daily meals: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  /// Adiciona uma refeição completa ao dia selecionado
  void addMeal(Meal meal) {
    final dateKey = _formatDate(_selectedDate);
    _mealsByDate[dateKey] ??= [];

    final meals = _mealsByDate[dateKey]!;

    // Verificar se já existe uma refeição do mesmo tipo
    final existingIndex = meals.indexWhere((m) => m.type == meal.type);

    if (existingIndex != -1) {
      // Se já existe, mesclar os alimentos
      final existingMeal = meals[existingIndex];
      final mergedFoods = List<Food>.from(existingMeal.foods)..addAll(meal.foods);
      meals[existingIndex] = existingMeal.copyWith(foods: mergedFoods);
    } else {
      // Senão, adicionar a nova refeição
      meals.add(meal.copyWith(dateTime: _selectedDate));
    }

    _saveToPreferences();
    notifyListeners();
  }

  void addFoodToMeal(MealType type, Food food) {
    final dateKey = _formatDate(_selectedDate);
    _mealsByDate[dateKey] ??= [];

    final meals = _mealsByDate[dateKey]!;
    final mealIndex = meals.indexWhere((m) => m.type == type);

    if (mealIndex != -1) {
      // Meal exists, add food to it
      final updatedFoods = List<Food>.from(meals[mealIndex].foods)..add(food);
      meals[mealIndex] = meals[mealIndex].copyWith(foods: updatedFoods);
    } else {
      // Create new meal with this food
      meals.add(Meal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        foods: [food],
      ));
    }

    _saveToPreferences();
    notifyListeners();
  }

  void removeFoodFromMeal(MealType type, Food food) {
    final dateKey = _formatDate(_selectedDate);
    final meals = _mealsByDate[dateKey];
    if (meals == null) return;

    final mealIndex = meals.indexWhere((m) => m.type == type);
    if (mealIndex == -1) return;

    final updatedFoods = List<Food>.from(meals[mealIndex].foods)
      ..removeWhere((f) => f.id == food.id);

    if (updatedFoods.isEmpty) {
      // Remove meal if no foods left
      meals.removeAt(mealIndex);
    } else {
      meals[mealIndex] = meals[mealIndex].copyWith(foods: updatedFoods);
    }

    _saveToPreferences();
    notifyListeners();
  }

  void updateGoals({
    int? calories,
    int? protein,
    int? carbs,
    int? fats,
  }) {
    if (calories != null) caloriesGoal = calories;
    if (protein != null) proteinGoal = protein;
    if (carbs != null) carbsGoal = carbs;
    if (fats != null) fatsGoal = fats;
    _saveToPreferences();
    notifyListeners();
  }

  // Get meal type display info
  static MealTypeOption getMealTypeOption(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return const MealTypeOption(
          type: MealType.breakfast,
          name: 'Café da Manhã',
          emoji: '🍳',
        );
      case MealType.lunch:
        return const MealTypeOption(
          type: MealType.lunch,
          name: 'Almoço',
          emoji: '🍽️',
        );
      case MealType.dinner:
        return const MealTypeOption(
          type: MealType.dinner,
          name: 'Jantar',
          emoji: '🍝',
        );
      case MealType.snack:
        return const MealTypeOption(
          type: MealType.snack,
          name: 'Lanche',
          emoji: '🥤',
        );
      case MealType.freeMeal:
        return const MealTypeOption(
          type: MealType.freeMeal,
          name: 'Refeição Livre',
          emoji: '🍴',
        );
    }
  }

  // Load sample data for testing
  void loadSampleData() {
    final dateKey = _formatDate(_selectedDate);

    // Create sample foods with complete nutrient data
    final eggs = Food(
      id: 1,
      name: 'Ovos Mexidos',
      emoji: '🍳',
      nutrients: [
        Nutrient(
          idFood: 1,
          servingSize: 100,
          servingUnit: 'g',
          calories: 148,
          protein: 10.0,
          carbohydrate: 1.1,
          fat: 11.0,
          saturatedFat: 3.3,
          cholesterol: 373,
          sodium: 142,
          potassium: 138,
          dietaryFiber: 0,
          sugars: 0.4,
          vitaminA: 160,
          vitaminD: 2.0,
          vitaminB12: 0.9,
          calcium: 56,
          iron: 1.2,
        ),
      ],
    );

    final rice = Food(
      id: 2,
      name: 'Arroz Integral',
      emoji: '🍚',
      nutrients: [
        Nutrient(
          idFood: 2,
          servingSize: 100,
          servingUnit: 'g',
          calories: 112,
          protein: 2.6,
          carbohydrate: 23.5,
          fat: 0.9,
          saturatedFat: 0.2,
          cholesterol: 0,
          sodium: 1,
          potassium: 43,
          dietaryFiber: 1.8,
          sugars: 0.4,
          vitaminB6: 0.15,
          calcium: 10,
          iron: 0.4,
        ),
      ],
    );

    final chicken = Food(
      id: 3,
      name: 'Peito de Frango Grelhado',
      emoji: '🍗',
      nutrients: [
        Nutrient(
          idFood: 3,
          servingSize: 100,
          servingUnit: 'g',
          calories: 165,
          protein: 31.0,
          carbohydrate: 0,
          fat: 3.6,
          saturatedFat: 1.0,
          cholesterol: 85,
          sodium: 74,
          potassium: 256,
          dietaryFiber: 0,
          sugars: 0,
          vitaminB6: 0.6,
          vitaminB12: 0.3,
          calcium: 15,
          iron: 1.0,
        ),
      ],
    );

    final beans = Food(
      id: 4,
      name: 'Feijão Preto',
      emoji: '🫘',
      nutrients: [
        Nutrient(
          idFood: 4,
          servingSize: 100,
          servingUnit: 'g',
          calories: 132,
          protein: 8.9,
          carbohydrate: 23.7,
          fat: 0.5,
          saturatedFat: 0.1,
          cholesterol: 0,
          sodium: 1,
          potassium: 355,
          dietaryFiber: 8.7,
          sugars: 0.3,
          vitaminB6: 0.1,
          calcium: 27,
          iron: 2.1,
        ),
      ],
    );

    final banana = Food(
      id: 5,
      name: 'Banana',
      emoji: '🍌',
      nutrients: [
        Nutrient(
          idFood: 5,
          servingSize: 100,
          servingUnit: 'g',
          calories: 89,
          protein: 1.1,
          carbohydrate: 22.8,
          fat: 0.3,
          saturatedFat: 0.1,
          cholesterol: 0,
          sodium: 1,
          potassium: 358,
          dietaryFiber: 2.6,
          sugars: 12.2,
          vitaminC: 8.7,
          vitaminB6: 0.4,
          calcium: 5,
          iron: 0.3,
        ),
      ],
    );

    final salmon = Food(
      id: 6,
      name: 'Salmão Grelhado',
      emoji: '🐟',
      nutrients: [
        Nutrient(
          idFood: 6,
          servingSize: 100,
          servingUnit: 'g',
          calories: 206,
          protein: 22.0,
          carbohydrate: 0,
          fat: 13.0,
          saturatedFat: 3.1,
          cholesterol: 55,
          sodium: 59,
          potassium: 363,
          dietaryFiber: 0,
          sugars: 0,
          vitaminD: 11.0,
          vitaminB6: 0.6,
          vitaminB12: 3.2,
          calcium: 9,
          iron: 0.3,
        ),
      ],
    );

    final broccoli = Food(
      id: 7,
      name: 'Brócolis',
      emoji: '🥦',
      nutrients: [
        Nutrient(
          idFood: 7,
          servingSize: 100,
          servingUnit: 'g',
          calories: 34,
          protein: 2.8,
          carbohydrate: 6.6,
          fat: 0.4,
          saturatedFat: 0.1,
          cholesterol: 0,
          sodium: 33,
          potassium: 316,
          dietaryFiber: 2.6,
          sugars: 1.7,
          vitaminC: 89.2,
          vitaminA: 31,
          vitaminB6: 0.2,
          calcium: 47,
          iron: 0.7,
        ),
      ],
    );

    // Create meals with these foods
    _mealsByDate[dateKey] = [
      // Breakfast
      Meal(
        id: '1',
        type: MealType.breakfast,
        foods: [eggs, banana],
        dateTime: DateTime.now().copyWith(hour: 8, minute: 0),
      ),
      // Lunch
      Meal(
        id: '2',
        type: MealType.lunch,
        foods: [rice, beans, chicken, broccoli],
        dateTime: DateTime.now().copyWith(hour: 12, minute: 30),
      ),
      // Dinner
      Meal(
        id: '3',
        type: MealType.dinner,
        foods: [salmon, rice, broccoli],
        dateTime: DateTime.now().copyWith(hour: 19, minute: 0),
      ),
    ];

    notifyListeners();
  }

  void clearAllMeals() {
    final dateKey = _formatDate(_selectedDate);
    _mealsByDate[dateKey] = [];
    _saveToPreferences();
    notifyListeners();
  }
}
