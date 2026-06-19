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
}

Food _food(String name) {
  return Food(
    id: name.hashCode,
    name: name,
    nutrients: [
      Nutrient(
        idFood: name.hashCode,
        servingSize: 1,
        servingUnit: 'un',
        calories: 100,
        protein: 4,
        carbohydrate: 18,
        fat: 2,
      ),
    ],
  );
}
