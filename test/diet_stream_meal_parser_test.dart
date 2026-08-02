import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/utils/diet_stream_meal_parser.dart';

void main() {
  group('DietStreamMealParser', () {
    test('reveals a compact meal only after its JSON row is complete', () {
      const incomplete = '{"m":[["breakfast","08:00",[["Eggs",2,"unit",140,12';
      expect(
        DietStreamMealParser.extractCompleteMeals(incomplete),
        isEmpty,
      );

      const complete =
          '{"m":[["breakfast","08:00",[["Eggs",2,"unit",140,12,1,10]]]';
      final meals = DietStreamMealParser.extractCompleteMeals(complete);

      expect(meals, hasLength(1));
      expect(meals.single[0], 'breakfast');
      expect(meals.single[2][0][0], 'Eggs');
    });

    test('keeps completed compact meals while the next one is partial', () {
      const streamed = '''
{"m":[
  ["breakfast","08:00",[["Iogurte [natural]",170,"g",110,8,12,3]]],
  ["lunch","12:30",[["Chicken",150,"g",248,46
''';

      final meals = DietStreamMealParser.extractCompleteMeals(streamed);

      expect(meals, hasLength(1));
      expect(meals.single[0], 'breakfast');
    });

    test('extracts successive compact meals from a root array', () {
      const streamed = '''[
  ["breakfast","08:00",[["Oats",50,"g",190,7,32,4]]],
  ["lunch","12:00",[["Rice",120,"g",156,3,34,0.4]]]
]''';

      final meals = DietStreamMealParser.extractCompleteMeals(streamed);

      expect(meals, hasLength(2));
      expect(meals.map((meal) => meal[0]), ['breakfast', 'lunch']);
    });

    test('supports legacy object meals with nested food objects', () {
      const streamed = '''
{"meals":[
  {
    "type":"breakfast",
    "time":"08:00",
    "foods":[{"name":"Eggs","amount":2,"unit":"unit"}],
    "mealTotals":{"calories":140,"protein":12,"carbs":1,"fat":10}
  },
  {"type":"lunch","foods":[{"name":"Rice"
''';

      final meals = DietStreamMealParser.extractCompleteMeals(streamed);

      expect(meals, hasLength(1));
      expect(meals.single['type'], 'breakfast');
      expect(meals.single['foods'], hasLength(1));
    });

    test('handles escaped quotes and brackets inside strings', () {
      const streamed =
          r'{"m":[["snack","16:00",[["Mix \"A]B\"",30,"g",120,4,10,7]]],[';

      final meals = DietStreamMealParser.extractCompleteMeals(streamed);

      expect(meals, hasLength(1));
      expect(meals.single[2][0][0], 'Mix "A]B"');
    });
  });
}
