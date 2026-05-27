import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/models/Nutrient.dart';
import 'package:nutro_ai/models/food_model.dart';

void main() {
  test('primaryNutrient handles missing and empty nutrient lists', () {
    final withoutNutrients = Food(name: 'Agua');
    final emptyNutrients = Food(name: 'Cafe', nutrients: const []);

    expect(withoutNutrients.primaryNutrient, isNull);
    expect(emptyNutrients.primaryNutrient, isNull);
    expect(emptyNutrients.calories, 0);
    expect(emptyNutrients.protein, 0);
    expect(emptyNutrients.carbs, 0);
    expect(emptyNutrients.fat, 0);
  });

  test('primaryNutrient returns first nutrient when available', () {
    final nutrient = Nutrient(
      idFood: 1,
      servingSize: 100,
      servingUnit: 'g',
      calories: 120,
      protein: 8,
      carbohydrate: 14,
      fat: 3,
    );
    final food = Food(name: 'Iogurte', nutrients: [nutrient]);

    expect(food.primaryNutrient, same(nutrient));
    expect(food.calories, 120);
    expect(food.protein, 8);
    expect(food.carbs, 14);
    expect(food.fat, 3);
  });

  test('manual source serializes and copyWith can clear source id', () {
    final aiNutrient = Nutrient(
      idFood: 1,
      servingSize: 100,
      servingUnit: 'g',
      calories: 90,
    );
    final food = Food(
      name: 'Pao',
      source: FoodSource.favorite,
      sourceId: 42,
      aiNutrients: [aiNutrient],
    );

    final manualFood = food.copyWith(
      source: FoodSource.manual,
      clearSourceId: true,
      clearAiNutrients: true,
    );

    expect(manualFood.source, FoodSource.manual);
    expect(manualFood.sourceId, isNull);
    expect(manualFood.aiNutrients, isNull);
    expect(foodSourceFromString('manual'), FoodSource.manual);
    expect(foodSourceFromString('custom'), FoodSource.manual);
    expect(foodSourceToString(FoodSource.manual), 'manual');

    final decoded = Food.fromJson(manualFood.toJson());
    expect(decoded.source, FoodSource.manual);
    expect(decoded.sourceId, isNull);
  });
}
