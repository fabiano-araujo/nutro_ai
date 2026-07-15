import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/models/Nutrient.dart';
import 'package:nutro_ai/models/food_model.dart';
import 'package:nutro_ai/utils/food_edit_helper.dart';

void main() {
  group('FoodEditHelper', () {
    test('parses a metric serving followed by a Portuguese preposition', () {
      final parsed = FoodEditHelper.parseDescription(
        '160 g de ovos',
        _eggFood(),
      );

      expect(parsed.amount, '160 g');
      expect(parsed.name, 'ovos');
      expect(
        FoodEditHelper.sameFoodNameForServingEdit(parsed.name, 'ovo'),
        isTrue,
      );
    });

    test('scales an amount-only egg edit without waiting for AI', () {
      final original = _eggFood();
      final scaled = FoodEditHelper.applyMetricServing(
        food: original,
        name: 'ovos',
        amount: '160 g',
      );

      expect(scaled, isNotNull);
      expect(scaled!.name, 'ovos');
      expect(scaled.amount, '160 g');
      expect(scaled.source, FoodSource.manual);
      expect(scaled.primaryNutrient?.servingSize, 160);
      expect(scaled.primaryNutrient?.servingUnit, 'g');
      expect(scaled.calories, 448);
      expect(scaled.protein, 32);
      expect(scaled.carbs, 3.2);
      expect(scaled.fat, 32);
      expect(scaled.aiNutrients, same(original.nutrients));
    });

    test('does not scale incompatible metric units', () {
      final scaled = FoodEditHelper.applyMetricServing(
        food: _eggFood(),
        name: 'ovo',
        amount: '160 ml',
      );

      expect(scaled, isNull);
    });
  });
}

Food _eggFood() {
  return Food(
    name: 'ovo',
    amount: '100',
    emoji: '🥚',
    nutrients: [
      Nutrient(
        idFood: 0,
        servingSize: 100,
        servingUnit: 'g',
        calories: 280,
        protein: 20,
        carbohydrate: 2,
        fat: 20,
      ),
    ],
  );
}
