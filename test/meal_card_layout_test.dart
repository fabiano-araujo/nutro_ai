import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/models/Nutrient.dart';
import 'package:nutro_ai/models/food_model.dart';
import 'package:nutro_ai/models/meal_model.dart';
import 'package:nutro_ai/providers/daily_meals_provider.dart';
import 'package:nutro_ai/providers/meal_types_provider.dart';
import 'package:nutro_ai/services/auth_service.dart';
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

  testWidgets('food can be added from editor and meal card options',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Meal? updatedMeal;
    var barcodeScanRequested = false;

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
            body: SizedBox(
              width: 360,
              child: MealCard(
                meal: _overflowRegressionMeal(),
                onMealUpdated: (meal) => updatedMeal = meal,
                onBarcodeScan: () => barcodeScanRequested = true,
                foodNutritionResolver: (_, __) async => _food(
                  name: 'banana',
                  amount: '1 unidade',
                  emoji: '🍌',
                  calories: 89,
                  protein: 1.1,
                  carbs: 23,
                  fat: 0.3,
                ),
                onDelete: () {},
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

    expect(find.text('Adicionar alimento'), findsOneWidget);
    expect(find.text('Código de Barras'), findsOneWidget);
    await tester.tap(find.text('Código de Barras'));
    await tester.pumpAndSettle();
    expect(barcodeScanRequested, isTrue);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar alimentos'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(OutlinedButton, 'Adicionar alimento'),
      findsOneWidget,
    );
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Adicionar alimento'),
    );
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(4));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar alimento'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(4));
    await tester.enterText(find.byType(TextField).last, '1 banana');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar'));
    await tester.pump();
    await tester.pump();

    expect(updatedMeal, isNotNull);
    expect(updatedMeal!.foods, hasLength(4));
    expect(updatedMeal!.foods.last.name, 'banana');
    expect(updatedMeal!.foods.last.amount, '1 unidade');
    expect(updatedMeal!.foods.last.calories, 89);
  });

  testWidgets('failed nutrition lookup never persists a zero-calorie draft',
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
            body: SizedBox(
              width: 360,
              child: MealCard(
                meal: _overflowRegressionMeal(),
                onMealUpdated: (meal) => updatedMeal = meal,
                foodNutritionResolver: (_, __) async => null,
                onDelete: () {},
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
    await tester.tap(find.text('Adicionar alimento'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Ovo');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(updatedMeal, isNotNull);
    expect(updatedMeal!.foods, hasLength(3));
    expect(
      updatedMeal!.foods.any((food) => food.name.toLowerCase() == 'ovo'),
      isFalse,
    );
    expect(find.text('0 kcal'), findsNothing);
    expect(
      find.text(
        'Não foi possível calcular os nutrientes. '
        'O alimento não foi adicionado. Tente novamente.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('card resyncs when its parent changes only the food amount',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mealNotifier = ValueNotifier<Meal>(_amountSyncMeal());
    addTearDown(mealNotifier.dispose);

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
            body: ValueListenableBuilder<Meal>(
              valueListenable: mealNotifier,
              builder: (context, meal, _) {
                return SizedBox(
                  width: 360,
                  child: MealCard(meal: meal, onDelete: () {}),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver detalhes'));
    await tester.pumpAndSettle();
    expect(find.text('100'), findsOneWidget);

    final original = mealNotifier.value;
    final updatedFood = original.foods.first.copyWith(amount: '160 g');
    mealNotifier.value = original.copyWith(foods: [updatedFood]);
    await tester.pump();

    expect(find.text('160 g'), findsOneWidget);
  });

  testWidgets('individual editor persists a 160 g egg serving immediately',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Meal? updatedMeal;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthService()),
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
            body: SizedBox(
              width: 360,
              child: MealCard(
                meal: _amountSyncMeal(),
                onMealUpdated: (meal) => updatedMeal = meal,
                onDelete: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver detalhes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ovo').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.edit_note_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Editar Alimento'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '160 g de ovos');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(updatedMeal, isNotNull);
    expect(updatedMeal!.foods.single.name, 'ovos');
    expect(updatedMeal!.foods.single.amount, '160 g');
    expect(updatedMeal!.foods.single.source, FoodSource.manual);
    expect(updatedMeal!.foods.single.calories, 448);
    expect(find.text('160 g'), findsOneWidget);
  });

  testWidgets('AI source option shows the food portion', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthService()),
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
                  meal: _aiPortionMeal(),
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

    await tester.tap(find.text('goiaba').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final aiOption = find.ancestor(
      of: find.text('Estimativa da IA'),
      matching: find.byType(InkWell),
    );

    expect(aiOption, findsOneWidget);
    expect(
      find.descendant(
        of: aiOption,
        matching: find.text('1 unidade média'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('switching from recent to AI updates daily totals',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dailyMealsProvider = DailyMealsProvider();
    await dailyMealsProvider.ready;
    dailyMealsProvider.setSelectedDate(DateTime(2026, 7, 8));
    dailyMealsProvider.addMeal(_recentGoiabaMeal());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthService()),
          ChangeNotifierProvider(create: (_) => MealTypesProvider()),
          ChangeNotifierProvider.value(value: dailyMealsProvider),
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
            body: Consumer<DailyMealsProvider>(
              builder: (context, mealsProvider, _) {
                final meal = mealsProvider.todayMeals.first;
                return Column(
                  children: [
                    Text('total:${mealsProvider.totalCalories}'),
                    SizedBox(
                      width: 360,
                      child: MealCard(
                        meal: meal,
                        onMealUpdated: mealsProvider.updateMeal,
                        onDelete: () {},
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('total:136'), findsOneWidget);

    await tester.tap(find.text('Ver detalhes'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('goiaba').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Estimativa da IA'));
    await tester.pumpAndSettle();

    expect(find.text('total:68'), findsOneWidget);
    expect(dailyMealsProvider.totalProtein, 2.6);
    expect(dailyMealsProvider.totalCarbs, 14);
    expect(dailyMealsProvider.totalFat, 0.6);
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

Meal _aiPortionMeal() {
  return Meal(
    id: 'meal-ai-portion',
    type: MealType.snack,
    foods: [
      _food(
        name: 'goiaba',
        amount: '1 unidade média',
        emoji: '*',
        calories: 68,
        protein: 2.6,
        carbs: 14,
        fat: 0.6,
      ),
    ],
  );
}

Meal _amountSyncMeal() {
  return Meal(
    id: 'meal-amount-sync',
    type: MealType.breakfast,
    foods: [
      _food(
        name: 'ovo',
        amount: '100',
        emoji: '*',
        calories: 280,
        protein: 20,
        carbs: 2,
        fat: 20,
      ),
    ],
  );
}

Meal _recentGoiabaMeal() {
  return Meal(
    id: 'meal-recent-goiaba',
    type: MealType.snack,
    foods: [
      _food(
        name: 'goiaba',
        amount: '1 unidade média',
        emoji: '*',
        calories: 136,
        protein: 5.2,
        carbs: 28,
        fat: 1.8,
        source: FoodSource.recent,
        aiNutrients: [
          Nutrient(
            idFood: 0,
            servingSize: 1,
            servingUnit: 'unidade',
            calories: 68,
            protein: 2.6,
            carbohydrate: 14,
            fat: 0.6,
          ),
        ],
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
  List<Nutrient>? aiNutrients,
}) {
  return Food(
    name: name,
    amount: amount,
    emoji: emoji,
    source: source,
    aiNutrients: aiNutrients,
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
