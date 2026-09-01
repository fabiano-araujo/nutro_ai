import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/models/diet_plan_model.dart';
import 'package:nutro_ai/screens/meal_page.dart';

void main() {
  Future<void> pumpMealPage(
    WidgetTester tester, {
    required bool showFiber,
  }) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final meal = PlannedMeal(
      type: 'lunch',
      time: '12:30',
      name: 'Almoço',
      foods: [
        PlannedFood(
          name: 'Feijão',
          emoji: '🫘',
          amount: 100,
          unit: 'g',
          calories: 120,
          protein: 8,
          carbs: 20,
          fat: 1,
          fiber: 6.4,
        ),
      ],
      mealTotals: DailyNutrition(
        calories: 120,
        protein: 8,
        carbs: 20,
        fat: 1,
        fiber: 6.4,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routes: {
          '/subscription': (_) => const Scaffold(
                body: Text('Tela de assinatura'),
              ),
        },
        home: MealPage.fromPlannedMeal(
          meal: meal,
          showFiber: showFiber,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('MealPage shows stored fiber in the macro summary',
      (tester) async {
    await pumpMealPage(tester, showFiber: true);

    final fiberMacro = find.byKey(const ValueKey('meal-fiber-macro'));
    expect(fiberMacro, findsOneWidget);
    expect(
      find.descendant(of: fiberMacro, matching: find.text('6g')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: fiberMacro, matching: find.text('Fibra')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: fiberMacro, matching: find.byIcon(Icons.eco_rounded)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Almoço'), findsWidgets);
    expect(find.text('Alimentos da refeição'), findsOneWidget);
    expect(find.text('Análise da IA'), findsOneWidget);
    expect(find.text('Analisar refeição'), findsOneWidget);
    expect(find.text('Feijão'), findsOneWidget);
  });

  testWidgets('MealPage locks fiber in the macro summary for free users',
      (tester) async {
    await pumpMealPage(tester, showFiber: false);

    final fiberMacro = find.byKey(const ValueKey('meal-fiber-macro'));
    expect(
      find.descendant(of: fiberMacro, matching: find.text('Premium')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: fiberMacro,
        matching: find.byIcon(Icons.workspace_premium_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: fiberMacro,
        matching: find.byIcon(Icons.workspace_premium_rounded),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tela de assinatura'), findsOneWidget);
  });
}
