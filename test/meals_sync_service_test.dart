import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/models/food_model.dart';
import 'package:nutro_ai/services/meals_sync_service.dart';

void main() {
  test('DailySummary.fromJson rebuilds food macros from server meals', () {
    final summary = DailySummary.fromJson({
      'id': 1,
      'userId': 7,
      'date': '2026-05-29T00:00:00.000Z',
      'totalCalories': 80,
      'totalProtein': '2.50',
      'totalCarbs': '15.00',
      'totalFat': '1.00',
      'totalFiber': '1.20',
      'calorieGoal': 3165,
      'proteinGoal': 142,
      'carbsGoal': 458,
      'fatGoal': 85,
      'waterGlasses': 0,
      'waterGoal': 8,
      'hitProtein': false,
      'hitCalories': false,
      'meals': [
        {
          'id': 10,
          'type': 'breakfast',
          'mealTime': '2026-05-29T08:00:00.000Z',
          'messageId': 'msg-123',
          'foods': [
            {
              'foodId': null,
              'name': 'pão',
              'emoji': '🥖',
              'amount': '1.00',
              'unit': 'fatia',
              'calories': 80,
              'protein': '2.50',
              'carbs': '15.00',
              'fat': '1.00',
              'fiber': '1.20',
            },
          ],
        },
      ],
    });

    final meal = summary.meals.single;
    final food = meal.foods.single;

    expect(summary.totalCalories, 80);
    expect(meal.totalCalories, 80);
    expect(meal.totalProtein, 2.5);
    expect(meal.totalCarbs, 15);
    expect(meal.totalFat, 1);
    expect(food.calories, 80);
    expect(food.protein, 2.5);
    expect(food.carbs, 15);
    expect(food.fat, 1);
    expect(food.primaryNutrient?.servingSize, 1);
    expect(food.primaryNutrient?.servingUnit, 'fatia');
    expect(food.primaryNutrient?.dietaryFiber, 1.2);
  });

  test('copyWithMacros creates a nutrient-backed food', () {
    final food = Food(name: 'pão').copyWithMacros(
      calories: 80,
      protein: 2.5,
      carbs: 15,
      fat: 1,
      fiber: 1.2,
      servingSize: 1,
      servingUnit: 'fatia',
    );

    expect(food.calories, 80);
    expect(food.protein, 2.5);
    expect(food.carbs, 15);
    expect(food.fat, 1);
    expect(food.primaryNutrient?.servingUnit, 'fatia');
  });
}
