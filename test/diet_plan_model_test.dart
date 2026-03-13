import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/models/diet_plan_model.dart';

void main() {
  test('DietPlan.fromAiJson parses compact diet response and computes totals',
      () {
    final dietPlan = DietPlan.fromAiJson(
      {
        'm': [
          [
            'breakfast',
            '08:00',
            [
              ['Pão francês', 100, 'g', 300, 9, 58, 3],
              ['Ovo mexido', 2, 'un', 180, 12, 1, 14],
            ],
          ],
          [
            'lunch',
            '12:30',
            [
              ['Arroz branco', 200, 'g', 260, 5, 56, 1],
              ['Frango grelhado', 150, 'g', 245, 45, 0, 6],
            ],
          ],
        ],
      },
      date: '2026-03-12',
      mealNames: const {
        'breakfast': 'Café da Manhã',
        'lunch': 'Almoço',
      },
    );

    expect(dietPlan.date, '2026-03-12');
    expect(dietPlan.meals, hasLength(2));
    expect(dietPlan.meals.first.name, 'Café da Manhã');
    expect(dietPlan.meals.first.mealTotals.calories, 480);
    expect(dietPlan.meals.first.mealTotals.protein, 21);
    expect(dietPlan.meals.first.foods.first.emoji, '🥖');
    expect(dietPlan.meals[1].foods[1].emoji, '🍗');
    expect(dietPlan.totalNutrition.calories, 985);
    expect(dietPlan.totalNutrition.protein, 71);
    expect(dietPlan.totalNutrition.carbs, 115);
    expect(dietPlan.totalNutrition.fat, 24);
  });

  test('PlannedMeal.fromAiJson keeps legacy format compatibility', () {
    final meal = PlannedMeal.fromAiJson({
      'type': 'dinner',
      'time': '19:00',
      'name': 'Jantar',
      'foods': [
        {
          'name': 'Macarrão',
          'amount': 200,
          'unit': 'g',
          'calories': 300,
          'protein': 10,
          'carbs': 60,
          'fat': 2,
        },
      ],
      'mealTotals': {
        'calories': 300,
        'protein': 10,
        'carbs': 60,
        'fat': 2,
      },
    });

    expect(meal.name, 'Jantar');
    expect(meal.foods.single.name, 'Macarrão');
    expect(meal.mealTotals.calories, 300);
  });
}
