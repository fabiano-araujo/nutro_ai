import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutro_ai/models/meal_model.dart';
import 'package:nutro_ai/widgets/meal_type_icon.dart';

void main() {
  test('maps known meal types to distinct line icons', () {
    expect(mealTypeIconData('breakfast'), Icons.coffee_outlined);
    expect(mealTypeIconData('lunch'), Icons.restaurant_outlined);
    expect(mealTypeIconData('dinner'), Icons.dinner_dining_outlined);
    expect(mealTypeIconData('afternoon_snack'), Icons.cookie_outlined);
    expect(mealTypeIconData('snack'), Icons.cookie_outlined);
    expect(mealTypeIconData('morning_snack'), Icons.bakery_dining_outlined);
    expect(mealTypeIconData('supper'), Icons.nightlife_outlined);
    expect(mealTypeIconData('free_meal'), Icons.restaurant_menu_outlined);
    expect(mealTypeIconData('freeMeal'), Icons.restaurant_menu_outlined);
  });

  test('maps MealType enum to the same icon ids used on meal rows', () {
    expect(
      mealTypeIdFromMealType(MealType.breakfast),
      'breakfast',
    );
    expect(mealTypeIdFromMealType(MealType.lunch), 'lunch');
    expect(mealTypeIdFromMealType(MealType.dinner), 'dinner');
    expect(mealTypeIdFromMealType(MealType.snack), 'snack');
    expect(mealTypeIdFromMealType(MealType.freeMeal), 'free_meal');
  });

  testWidgets('renders the mint squircle for breakfast', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MealTypeIcon(mealTypeId: 'breakfast'),
        ),
      ),
    );

    expect(find.byIcon(Icons.coffee_outlined), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.coffee_outlined));
    expect(icon.color, kMealTypeIconForeground);

    final container = tester.widget<Container>(
      find.ancestor(
        of: find.byIcon(Icons.coffee_outlined),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, kMealTypeIconBackground);
  });
}
