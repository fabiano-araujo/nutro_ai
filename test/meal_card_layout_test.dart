import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/models/Nutrient.dart';
import 'package:nutro_ai/models/food_model.dart';
import 'package:nutro_ai/models/meal_model.dart';
import 'package:nutro_ai/providers/meal_types_provider.dart';
import 'package:nutro_ai/widgets/meal_card.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('expanded macro row fits narrow chat cards', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MealTypesProvider()),
        ],
        child: MaterialApp(
          locale: const Locale('pt', 'BR'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 344,
                child: MealCard(
                  meal: _overflowRegressionMeal(),
                  onDelete: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Ver detalhes'));
    await tester.pumpAndSettle();

    expect(find.text('35.0'), findsOneWidget);
    expect(find.text('102.0'), findsOneWidget);
    expect(find.text('23.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing all foods applies typed food name immediately',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Meal? updatedMeal;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MealTypesProvider()),
        ],
        child: MaterialApp(
          locale: const Locale('pt', 'BR'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 360,
                child: MealCard(
                  meal: _overflowRegressionMeal(),
                  onMealUpdated: (meal) => updatedMeal = meal,
                  onDelete: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver detalhes'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Editar alimentos'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextField).first, '200 g arroz integral');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar'));
    await tester.pump();
    await tester.pump();

    expect(updatedMeal, isNotNull);
    expect(updatedMeal!.foods.first.name, 'arroz integral');
    expect(updatedMeal!.foods.first.amount, '200 g');
  });
}

Meal _overflowRegressionMeal() {
  return Meal(
    id: 'meal-overflow-regression',
    type: MealType.lunch,
    foods: [
      _food(
        name: 'feijao',
        amount: '300 g',
        emoji: '*',
        calories: 360,
        protein: 21,
        carbs: 60,
        fat: 8,
        source: FoodSource.recent,
      ),
      _food(
        name: 'leite',
        amount: '1 copo',
        emoji: '*',
        calories: 150,
        protein: 8,
        carbs: 12,
        fat: 5,
      ),
      _food(
        name: 'acai',
        amount: '1 copo',
        emoji: '*',
        calories: 250,
        protein: 6,
        carbs: 30,
        fat: 10,
      ),
    ],
  );
}

Food _food({
  required String name,
  required String amount,
  required String emoji,
  required double calories,
  required double protein,
  required double carbs,
  required double fat,
  FoodSource source = FoodSource.ai,
}) {
  return Food(
    name: name,
    amount: amount,
    emoji: emoji,
    source: source,
    nutrients: [
      Nutrient(
        idFood: 0,
        servingSize: 100,
        servingUnit: 'g',
        calories: calories,
        protein: protein,
        carbohydrate: carbs,
        fat: fat,
      ),
    ],
  );
}
