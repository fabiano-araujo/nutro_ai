import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/models/Nutrient.dart';
import 'package:nutro_ai/models/food_model.dart';
import 'package:nutro_ai/models/meal_model.dart';
import 'package:nutro_ai/providers/daily_meals_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('tracks explicit local meal additions without firing on date changes',
      () async {
    final provider = DailyMealsProvider();
    await provider.ready;

    provider.setSelectedDate(DateTime(2026, 6, 18));

    expect(provider.mealAdditionVersion, 0);
    expect(provider.lastMealAdditionDate, isNull);

    provider.addMeal(
      Meal(
        id: 'meal-1',
        type: MealType.breakfast,
        foods: [_food('pao')],
      ),
    );

    expect(provider.mealAdditionVersion, 1);
    expect(provider.lastMealAdditionDate, DateTime(2026, 6, 18));

    provider.setSelectedDate(DateTime(2026, 6, 17));

    expect(provider.mealAdditionVersion, 1);
    expect(provider.lastMealAdditionDate, DateTime(2026, 6, 18));

    provider.addFoodToMeal(MealType.lunch, _food('arroz'));

    expect(provider.mealAdditionVersion, 2);
    expect(provider.lastMealAdditionDate, DateTime(2026, 6, 17));
  });

  test('does not count stored meals as new additions', () async {
    final storedMeal = Meal(
      id: 'stored-meal',
      type: MealType.lunch,
      foods: [_food('feijao')],
      dateTime: DateTime(2026, 6, 17, 12),
    );

    SharedPreferences.setMockInitialValues({
      'daily_meals': jsonEncode({
        '2026-06-17': [storedMeal.toJson()],
      }),
    });

    final provider = DailyMealsProvider();
    await provider.ready;
    provider.setSelectedDate(DateTime(2026, 6, 17));

    expect(provider.todayMeals, hasLength(1));
    expect(provider.mealAdditionVersion, 0);
    expect(provider.lastMealAdditionDate, isNull);
  });

  test('updates chat meal totals by message id when card id changes', () async {
    final provider = DailyMealsProvider();
    await provider.ready;
    provider.setSelectedDate(DateTime(2026, 7, 8));

    provider.addMeal(
      Meal(
        id: 'stored-meal-id',
        type: MealType.snack,
        messageId: 'chat-message-1',
        foods: [
          _food('goiaba', calories: 136, protein: 5.2, carbs: 28, fat: 1.8)
        ],
      ),
    );

    expect(provider.totalCalories, 136);
    expect(provider.totalProtein, 5.2);

    provider.updateMeal(
      Meal(
        id: 'reparsed-card-id',
        type: MealType.snack,
        messageId: 'chat-message-1',
        foods: [
          _food('goiaba', calories: 68, protein: 2.6, carbs: 14, fat: 0.6)
        ],
      ),
    );

    expect(provider.totalCalories, 68);
    expect(provider.totalProtein, 2.6);
    expect(provider.totalCarbs, 14);
    expect(provider.totalFat, 0.6);
    expect(provider.todayMeals.single.id, 'stored-meal-id');
  });

  test('matches chat meals when message index changes', () async {
    final provider = DailyMealsProvider();
    await provider.ready;
    provider.setSelectedDate(DateTime(2026, 7, 8));

    provider.addMeal(
      Meal(
        id: 'stored-meal-id',
        type: MealType.snack,
        messageId: 'msg-1800000000000000-4#meal-0',
        foods: [
          _food('goiaba', calories: 136, protein: 5.2, carbs: 28, fat: 1.8)
        ],
      ),
    );

    expect(provider.getMealsByMessageId('msg-1800000000000000'), hasLength(1));
    expect(provider.getMealsByMessageId('msg-1800000000000000').single.id,
        'stored-meal-id');

    provider.addMeal(
      Meal(
        id: 'reparsed-card-id',
        type: MealType.snack,
        messageId: 'msg-1800000000000000#meal-0',
        foods: [
          _food('goiaba', calories: 68, protein: 2.6, carbs: 14, fat: 0.6)
        ],
      ),
    );

    expect(provider.todayMeals, hasLength(1));
    expect(provider.totalCalories, 68);
    expect(provider.todayMeals.single.id, 'reparsed-card-id');
  });

  test('deletes chat meal by message id when card id changes', () async {
    final provider = DailyMealsProvider();
    await provider.ready;
    provider.setSelectedDate(DateTime(2026, 7, 8));

    provider.addMeal(
      Meal(
        id: 'stored-meal-id',
        type: MealType.snack,
        messageId: 'msg-1800000000000001-4#meal-0',
        foods: [
          _food('goiaba', calories: 136, protein: 5.2, carbs: 28, fat: 1.8)
        ],
      ),
    );

    provider.deleteMeal(
      'reparsed-card-id',
      messageId: 'msg-1800000000000001#meal-0',
    );

    expect(provider.todayMeals, isEmpty);
    expect(provider.totalCalories, 0);
    expect(provider.totalProtein, 0);
    expect(provider.hasMealsOn(DateTime(2026, 7, 8)), isFalse);
  });

  test('does not match a different meal ordinal in the same chat message',
      () async {
    final provider = DailyMealsProvider();
    await provider.ready;
    provider.setSelectedDate(DateTime(2026, 7, 8));

    provider.addMeal(
      Meal(
        id: 'stored-meal-id',
        type: MealType.snack,
        messageId: 'msg-1800000000000002-4#meal-1',
        foods: [
          _food('banana', calories: 105, protein: 1.3, carbs: 27, fat: 0.4)
        ],
      ),
    );

    provider.deleteMeal(
      'reparsed-card-id',
      messageId: 'msg-1800000000000002#meal-0',
    );

    expect(provider.todayMeals, hasLength(1));
    expect(provider.todayMeals.single.id, 'stored-meal-id');
    expect(provider.totalCalories, 105);
  });
}

Food _food(
  String name, {
  double calories = 100,
  double protein = 4,
  double carbs = 18,
  double fat = 2,
}) {
  return Food(
    id: name.hashCode,
    name: name,
    nutrients: [
      Nutrient(
        idFood: name.hashCode,
        servingSize: 1,
        servingUnit: 'un',
        calories: calories,
        protein: protein,
        carbohydrate: carbs,
        fat: fat,
      ),
    ],
  );
}
