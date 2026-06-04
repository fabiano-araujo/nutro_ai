import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/utils/food_json_parser.dart';

void main() {
  group('FoodJsonParser.parseFoodJson', () {
    test('uses grams from the AI portion as the nutrient serving', () {
      const payload = '''
      {
        "mealType": "lunch",
        "foods": [
          {
            "name": "feijao",
            "portion": "300 g",
            "macros": {
              "calories": 360,
              "protein": 21,
              "carbohydrate": 60,
              "fat": 3
            }
          }
        ]
      }
      ''';

      final foods = FoodJsonParser.parseFoodJson(payload);

      expect(foods, isNotNull);
      final nutrient = foods!.single.primaryNutrient;
      expect(nutrient?.servingSize, 300);
      expect(nutrient?.servingUnit, 'g');
      expect(foods.single.calories, 360);
    });

    test('keeps count-based portions scalable for recents', () {
      const payload = '''
      {
        "mealType": "snack",
        "foods": [
          {
            "name": "acai",
            "portion": "2 copos",
            "macros": {
              "calories": 500,
              "protein": 4,
              "carbohydrate": 80,
              "fat": 18
            }
          }
        ]
      }
      ''';

      final foods = FoodJsonParser.parseFoodJson(payload);

      expect(foods, isNotNull);
      final nutrient = foods!.single.primaryNutrient;
      expect(nutrient?.servingSize, 2);
      expect(nutrient?.servingUnit, 'copo');
      expect(foods.single.calories, 500);
    });

    test('parses multiple explicit meals as separate entries', () {
      const message = '''
      {
        "meals": [
          {
            "mealType": "lunch",
            "foods": [
              {
                "name": "pao",
                "portion": "1 unidade",
                "macros": {
                  "calories": 90,
                  "protein": 3,
                  "carbohydrate": 18,
                  "fat": 1
                }
              },
              {
                "name": "feijao",
                "portion": "1 concha",
                "macros": {
                  "calories": 120,
                  "protein": 8,
                  "carbohydrate": 20,
                  "fat": 1
                }
              }
            ]
          },
          {
            "mealType": "dinner",
            "foods": [
              {
                "name": "cuscuz",
                "portion": "1 prato",
                "macros": {
                  "calories": 180,
                  "protein": 5,
                  "carbohydrate": 38,
                  "fat": 1
                }
              },
              {
                "name": "leite",
                "portion": "1 copo",
                "macros": {
                  "calories": 120,
                  "protein": 6,
                  "carbohydrate": 10,
                  "fat": 6
                }
              }
            ]
          }
        ]
      }
      ''';

      expect(FoodJsonParser.containsFoodJson(message), isTrue);

      final entries = FoodJsonParser.parseMealEntriesFromMessage(message);

      expect(entries, hasLength(2));
      expect(entries[0].mealType.name, 'lunch');
      expect(entries[0].foods.map((food) => food.name), ['pao', 'feijao']);
      expect(entries[1].mealType.name, 'dinner');
      expect(entries[1].foods.map((food) => food.name), ['cuscuz', 'leite']);
    });
  });

  group('FoodJsonParser.parseServingFromPortion', () {
    test('normalizes larger metric units to grams or milliliters', () {
      final grams = FoodJsonParser.parseServingFromPortion('0,5 kg');
      final milliliters = FoodJsonParser.parseServingFromPortion('1 litro');

      expect(grams?.amount, 500);
      expect(grams?.unit, 'g');
      expect(milliliters?.amount, 1000);
      expect(milliliters?.unit, 'ml');
    });
  });
}
