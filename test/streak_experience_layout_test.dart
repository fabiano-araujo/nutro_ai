import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutro_ai/controllers/navigation_controller.dart';
import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/models/Nutrient.dart';
import 'package:nutro_ai/models/food_model.dart';
import 'package:nutro_ai/models/meal_model.dart';
import 'package:nutro_ai/providers/daily_meals_provider.dart';
import 'package:nutro_ai/providers/friends_provider.dart';
import 'package:nutro_ai/providers/nutrition_goals_provider.dart';
import 'package:nutro_ai/providers/streak_provider.dart';
import 'package:nutro_ai/screens/streak_screen.dart';
import 'package:nutro_ai/screens/streak_widget_onboarding_screen.dart';
import 'package:nutro_ai/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('first-day and widget intro fit a compact phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _localizedApp(
        const StreakWidgetOnboardingScreen(
          calories: 420,
          calorieGoal: 2000,
          streak: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Consegue chegar a 3 dias?'), findsOneWidget);
    expect(find.text('Eu consigo'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Eu consigo'));
    await tester.pumpAndSettle();

    expect(find.text('Tem receio de perder sua sequência?'), findsOneWidget);
    expect(find.text('420 kcal'), findsOneWidget);
    expect(find.text('Sim, adicionar o widget'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('redesigned streak overview and details fit a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mealsProvider = DailyMealsProvider();
    await mealsProvider.ready;
    mealsProvider.addFoodToMeal(
      MealType.breakfast,
      Food(
        id: 1,
        name: 'banana',
        nutrients: [
          Nutrient(
            idFood: 1,
            servingSize: 1,
            servingUnit: 'un',
            calories: 90,
            protein: 1,
            carbohydrate: 23,
            fat: 0.3,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: mealsProvider),
          ChangeNotifierProvider(create: (_) => StreakProvider()),
          ChangeNotifierProvider(create: (_) => FriendsProvider()),
          ChangeNotifierProvider(create: (_) => NutritionGoalsProvider()),
        ],
        child: _localizedApp(const StreakScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Meu desafio'), findsOneWidget);
    expect(find.text('Visão geral'), findsOneWidget);
    expect(find.text('Estou comprometido'), findsOneWidget);
    final commitmentButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Estou comprometido'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(
      commitmentButton.style?.backgroundColor?.resolve({}),
      AppTheme.primaryColor,
    );

    final initialFlameTransform = List<double>.from(
      tester
          .widget<Transform>(
            find.byKey(const ValueKey('streak-animated-flame')),
          )
          .transform
          .storage,
    );
    await tester.pump(const Duration(milliseconds: 280));
    final animatedFlameTransform = List<double>.from(
      tester
          .widget<Transform>(
            find.byKey(const ValueKey('streak-animated-flame')),
          )
          .transform
          .storage,
    );
    expect(animatedFlameTransform, isNot(equals(initialFlameTransform)));
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Resumo'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Resumo'), findsOneWidget);
    expect(find.text('Maior sequência'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Mais detalhes'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Mais detalhes'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Calendário da sequência'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('commitment returns to the first app tab and closes the streak',
      (tester) async {
    final mealsProvider = DailyMealsProvider();
    await mealsProvider.ready;
    int? requestedTab;
    navigationController.tabChangeCallback = (index) => requestedTab = index;
    addTearDown(() => navigationController.tabChangeCallback = null);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: mealsProvider),
          ChangeNotifierProvider(create: (_) => StreakProvider()),
          ChangeNotifierProvider(create: (_) => FriendsProvider()),
          ChangeNotifierProvider(create: (_) => NutritionGoalsProvider()),
        ],
        child: _localizedApp(const _StreakNavigationHost()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abrir sequência'));
    await tester.pumpAndSettle();
    expect(find.byType(StreakScreen), findsOneWidget);

    await tester.tap(find.text('Estou comprometido'));
    await tester.pumpAndSettle();

    expect(requestedTab, 0);
    expect(find.text('Tela inicial'), findsOneWidget);
    expect(find.byType(StreakScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _StreakNavigationHost extends StatelessWidget {
  const _StreakNavigationHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const StreakScreen()),
          ),
          child: const Text('Abrir sequência'),
        ),
      ),
      appBar: AppBar(title: const Text('Tela inicial')),
    );
  }
}

Widget _localizedApp(Widget home) {
  return MaterialApp(
    locale: const Locale('pt', 'BR'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    home: home,
  );
}
